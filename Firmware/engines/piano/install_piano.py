#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Derived in part from OP-FREE: it uses tools/opz.py's code and follows its steps
# Copyright (c) 2026 Lourens Smit and the op-z-engines contributors (OP-FREE)
# Copyright (c) 2026 Luis Tosado (this version of it)
"""Put the piano on the OP-Z (or take it off), with op-free's own session, backup, plan and read-back code.

    install_piano.py --dry-run                  backup and plan; writes nothing to the OP-Z
    install_piano.py                            asks before writing: lead, arp and chord, sound slot 10 (black key 0)
    install_piano.py --uninstall [--dry-run]    unassign and remove the plug (the OP-Z deletes the pack with it)
    ... --fake [BACKUP_DIR]                     an in-memory OP-Z, with that backup's settings if given
    ... --track lead --track chord --slot 10    other tracks or slot

op-free's `opz.py install` wants a sample plug of ours on the OP-Z before an engine may name its pack, which would
leave a second plug that plays the coded pack as noise. This does the same checks in the same order without it:
  1. backup of plugs.json and slotConfiguration.json, op-free's plan and refusals, the pack and engine checked;
  2. sync 1: the pack alone (no plug names it yet); sync 2: the same file again, which the OP-Z must skip: proof that
     it holds exactly these bytes (a plug must never name a missing pack, SAFETY.md rule 4);
  3. sync 3: engine, patch.json, slot map; both settings read back and checked, the slot map put back if they differ.
It never uses --replace: an occupied slot is refused. OPFREE names the op-free folder (default ~/Desktop/op-free-main).
"""
import argparse, contextlib, hashlib, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OPFREE = os.environ.get("OPFREE", os.path.expanduser("~/Desktop/op-free-main"))
sys.path.insert(0, os.path.join(OPFREE, "tools"))
import opz  # noqa: E402
import opz_samples as smp  # noqa: E402
import opz_verify  # noqa: E402


def load():
    engine = opz.load_engine(HERE, os.path.join(HERE, "piano.engine"))
    with open(os.path.join(HERE, "opzk_piano.aif"), "rb") as f:
        pack = f.read()
    return engine, pack


def verify_engine(engine):
    """op-free's loader checks on the built file; an exception or a failed check refuses the install."""
    path = os.path.join(HERE, "piano.engine")
    import subprocess
    r = subprocess.run([sys.executable, "-I", os.path.join(OPFREE, "tools", "opz_verify.py"), path, "--slot",
                        str(engine["manifest"]["memoryslot"])], capture_output=True, text=True)
    return [] if r.returncode == 0 else ["opz_verify: " + (r.stdout + r.stderr).strip()[-300:]]


def install(o, engine, pack, tracks, slot, dry_run, yes):
    bdir, plugs, slots = o.backup("install-piano")
    path = engine["manifest"]["plug"]["samples"]
    info = smp.parse(pack)
    errors = list(info["errors"]) + verify_engine(engine)
    if smp.upload_path_error(path):
        errors.append(smp.upload_path_error(path))
    pid = int(engine["manifest"]["plug"]["id"])
    for p in plugs.get("plugs", []):
        if p["id"] == pid:
            continue
        if p.get("samples") == path:
            errors.append("%s is already named by plug %d" % (path, p["id"]))
        elif p.get("samples") and smp.pack_id(p["samples"]) == smp.pack_id(path):
            errors.append("plug %d's pack has the same id" % p["id"])
    # the plan, as if the pack's plug were there (step 2 proves the pack itself before anything names it)
    stand_in = dict(plugs, plugs=plugs.get("plugs", []) + [{"id": smp.OUR_PLUG_IDS[0], "samples": path, "flags": 0,
                                                            "engine": "", "version": 1}])
    e2, warnings, plan = opz.plan_install(stand_in, slots, engine, tracks, slot, False)
    errors += e2
    for w in warnings:
        o.log("warning: " + w)
    for e in errors:
        o.log("error:   " + e)
    if errors:
        o.log("nothing written.")
        return False
    files = [(engine["device_path"], engine["data"]), (opz.PATCH, opz.build_patch(engine, plan["tracks"]))]
    if plan["slot_map"] is not None:
        files.append((opz.SLOTS, json.dumps(plan["slot_map"], separators=(",", ":")).encode()))
    o.log("plan: %s (%d bytes, %.2f s as a drum pack), then %s (%d bytes, memory slot %d) as plug %d -> %s" % (
        path, len(pack), info["frames"] / smp.SAMPLE_RATE, engine["device_path"], len(engine["data"]),
        engine["manifest"]["memoryslot"], pid,
        ", ".join("%s slot %d" % (opz.TRACK_NAMES[t], s) for t, s in plan["assign"]) or "no track"))
    if dry_run:
        o.log("dry run: nothing written.")
        return True
    if not yes and not o.confirm("Upload the piano pack (about 2 minutes) and install plug %d?" % pid):
        o.log("cancelled.")
        return False
    r = o.push([(path, pack)])
    o.log("sync 1 (pack): requested %s; skipped (already there) %s" % (r["requested"], r["skipped"]))
    if path not in o.push([(path, pack)])["skipped"]:
        o.log("error:   the OP-Z asked for the pack again, so it does not hold these bytes. Nothing names it; stopped.")
        return False
    o.log("sync 2 (probe): the OP-Z holds the pack")
    r = o.push(files)
    o.log("sync 3: requested %s; skipped %s" % (r["requested"], r["skipped"]))
    plugs2, slots2 = (json.loads(x) for x in o.read_settings())
    problems = opz.verify_install(plugs2, slots2, engine, plan["assign"])
    rec = next((p for p in plugs2.get("plugs", []) if p["id"] == pid), {})
    if rec.get("samples") != path:
        problems.append("plug %d does not name the pack: %s" % (pid, rec))
    if problems:
        for p in problems:
            o.log("verify:  " + p)
        o.log("restoring the slot map from %s" % bdir)
        o.restore(bdir, yes=True)
        return False
    with open(os.path.join(bdir, "install.json"), "w") as f:
        json.dump({"engine": engine["device_path"], "sha256": hashlib.sha256(engine["data"]).hexdigest(),
                   "pack": path, "pack_sha256": hashlib.sha256(pack).hexdigest(), "plug": pid,
                   "assigned": plan["assign"]}, f, indent=2)
    o.log("installed and verified.")
    if plan["restart"]:
        o.log("RESTART THE OP-Z: an older piano engine was already loaded.")
    return True


def uninstall(o, pid, path, dry_run, yes):
    bdir, plugs, slots = o.backup("remove-piano")
    rec = next((p for p in plugs.get("plugs", []) if p["id"] == pid), None)
    if rec is None:
        o.log("plug %d is not installed." % pid)
        return True
    others = [p["id"] for p in plugs["plugs"] if p.get("samples") == path and p["id"] != pid]
    if rec.get("engine") != "engines/piano.engine" or rec.get("samples") != path or others:
        o.log("error:   plug %d is not the piano as installed here (%s, others %s); nothing written." % (pid, rec, others))
        return False
    where = opz.assigned_tracks(slots, pid)
    o.log("plan: unassign %s, remove plug %d; the OP-Z deletes %s with it" % (where or "nothing", pid, path))
    if dry_run:
        o.log("dry run: nothing written.")
        return True
    if not yes and not o.confirm("Remove the piano?"):
        return False
    if where:
        o.push([(opz.SLOTS, json.dumps(opz.unassign(slots, pid), separators=(",", ":")).encode())])
        if opz.assigned_tracks(json.loads(o.read_settings()[1]), pid):
            o.log("error:   unassigning failed; plug not removed")
            return False
    o.push([], remove=[pid])
    gone = not any(p["id"] == pid for p in json.loads(o.read_settings()[0]).get("plugs", []))
    o.log("removed." if gone else "verify:  plug %d still present" % pid)
    return gone


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--track", action="append", choices=["bass", "lead", "arp", "chord"])
    ap.add_argument("--slot", type=int, default=10, choices=range(1, 11))
    ap.add_argument("--port", default="OP-Z")
    ap.add_argument("--fake", nargs="?", const="", help="an in-memory OP-Z; optionally with a backup's settings")
    ap.add_argument("--backups", default=os.path.join(OPFREE, "backups"))
    ap.add_argument("--uninstall", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--yes", action="store_true")
    a = ap.parse_args(argv)
    engine, pack = load()
    tracks = [opz.TRACK_NAMES.index(t) if isinstance(opz.TRACK_NAMES, (list, tuple)) else
              next(k for k, v in opz.TRACK_NAMES.items() if v == t) for t in (a.track or ["lead", "arp", "chord"])]
    if a.fake is not None:
        from fake_opz import FakeOpz, default_files
        files = default_files()
        if a.fake:
            for p in (opz.PLUGS, opz.SLOTS):
                with open(os.path.join(a.fake, p), "rb") as f:
                    files[p] = f.read()
        transport = contextlib.nullcontext(FakeOpz(files))
        clock = None
    else:
        transport = opz.MidoTransport(a.port)
    with transport as t:
        kw = {"clock": t.clock} if hasattr(t, "clock") else {}
        o = opz.Opz(t, backups=a.backups, **kw)
        pid, path = int(engine["manifest"]["plug"]["id"]), engine["manifest"]["plug"]["samples"]
        ok = uninstall(o, pid, path, a.dry_run, a.yes) if a.uninstall else install(o, engine, pack, tracks, a.slot, a.dry_run, a.yes)
        if ok and a.fake is not None and not a.dry_run and not a.uninstall:
            ok = uninstall(o, pid, path, False, True)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
