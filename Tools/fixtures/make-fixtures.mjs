// SPDX-License-Identifier: MIT
// Derived in part from OP-FREE: vectorProject() is core/test/project.test.ts's
// Copyright (c) 2026 Lourens Smit and the op-z-engines contributors (OP-FREE)
// Copyright (c) 2026 Luis Tosado (this version of it)

// Writes Galax-z's fixtures from op-free's TypeScript core (the reference implementation):
//   - Tests/.../Fixtures/statesync-vector.json: a whole StateSync opening (hello, $01, $07, $0C, every bank part and
//     its $0B ack) against op-free's fake OP-Z holding op-free's vector project, plus what the core reads from it;
//   - Sources/OPZLink/Resources/OPFree/demo-session.json: the frames a fake OP-Z sends for a small demo song, which the app's
//     demo mode replays: the StateSync opening and the file service serving the two settings files;
//   - Tests/.../Fixtures/file-session.json: the file service pulling both settings files, both directions, and the
//     files as the fake holds them;
//   - Sources/OPZModel/Resources/OPFree/engines.json: op-free's engine catalogue (names, knob names, presets), from the
//     website's own buildCatalogue().
//
//   node --experimental-strip-types Tools/fixtures/make-fixtures.mjs /path/to/op-free-main

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const opfree = process.argv[2];
if (!opfree) throw new Error("usage: make-fixtures.mjs /path/to/op-free-main");
const core = await import(join(opfree, "core/src/index.ts"));
const { buildCatalogue } = await import(join(opfree, "site/scripts/catalogue.ts"));
const op = core.project;
const catalogue = buildCatalogue().catalogue.engines;
const plugOf = (dir) => catalogue.find((e) => e.dir === dir).manifest.plug.id;
const root = join(dirname(fileURLToPath(import.meta.url)), "../..");
const kit = join(root, "Packages/GalaxzKit");

const hex = (b) => Buffer.from(b).toString("hex");

/** The same edits as op-free's core/test/project.test.ts vectorProject(). */
function vectorProject() {
  const pr = new op.Project();
  pr.setTempo(97);
  op.writeRhythm(pr, 0, 0, op.euclid(5, 16), 53, 110);
  op.writeRhythm(pr, 0, 1, op.euclid(3, 8, 2), 55, 100, 0.5);
  const chord = [60, 64, 67, 71, 74, 77, 81, 84];
  const micro = [-12, -4, 0, 3, 5, 8, 10, 11];
  pr.setNotes(0, 6, 3, chord.map((n, i) => ({ note: n, velocity: 64 + (n % 7), duration: 3100, micro: micro[i] })));
  pr.setComponent(0, 4, 2, "glide", 7);
  pr.setComponent(0, 4, 2, "pulse", 4);
  pr.setComponent(0, 4, 2, "pulse", null);
  pr.setLock(0, 5, 0, "filter", 200);
  pr.setLock(0, 5, 1, "filter", 10);
  pr.setLock(0, 5, 1, "filter", null);
  pr.setSound(0, 5, Array.from({ length: 18 }, (_, i) => 100 + i));
  pr.setTrack(0, 4, { step_count: 12, step_length: 2, plug: 61016, note_length: 32, quantize: 255 });
  pr.setMuted(0, 3, true);
  pr.setMuted(0, 7, true, 2);
  op.writePages(pr, 4, Array.from({ length: 40 }, (_, s) => (s % 3 === 0 ? [{ note: 36 + (s % 12) }] : [])), 8, 4);
  pr.setChain(0, [0, 0, 1, 15]);
  return pr;
}

/** A little song for demo mode: pattern 1 of project 1. */
function demoProject() {
  const pr = new op.Project();
  pr.setTempo(124);
  op.writeRhythm(pr, 0, 0, op.euclid(4, 16), 53, 120);            // kick
  op.writeRhythm(pr, 0, 1, op.euclid(2, 16, 4), 55, 110);         // snare on 2 and 4
  op.writeRhythm(pr, 0, 2, op.euclid(7, 16, 1), 60, 80, 0.5);     // perc
  op.writeRhythm(pr, 0, 3, op.euclid(3, 16, 2), 62, 90);          // sample
  const bass = [36, null, 36, 43, null, 41, null, 36, 34, null, 34, 41, null, 39, 41, null];
  bass.forEach((n, s) => n !== null && pr.setNotes(0, 4, s, [{ note: n, velocity: 100, duration: 4000 }]));
  const lead = [72, null, null, 75, null, 77, null, null, 79, null, 77, null, 75, null, 72, null];
  lead.forEach((n, s) => n !== null && pr.setNotes(0, 5, s, [{ note: n, velocity: 96, duration: 5000 }]));
  for (let s = 0; s < 16; s += 2) pr.setNotes(0, 6, s, [{ note: 60 + ((s * 5) % 12), velocity: 70, duration: 2000 }]);
  [[0, [60, 63, 67, 70]], [8, [58, 62, 65, 69]]].forEach(([s, notes]) =>
    pr.setNotes(0, 7, s, notes.map((n) => ({ note: n, velocity: 84, duration: 6200 * 6 }))));
  pr.setComponent(0, 5, 3, "glide", 4);
  pr.setComponent(0, 6, 8, "random", 4);
  pr.setLock(0, 4, 8, "filter", 60);
  pr.setMuted(0, 3, true);
  // the sound on each track: community engines, as on the author's OP-Z since 2026-11-21
  DEMO_SOUNDS.forEach((dir, t) => pr.setTrack(0, t, { plug: plugOf(dir), ...(t === 2 ? { step_count: 12 } : {}) }));
  return pr;
}

const DEMO_SOUNDS = ["fmperc", "snap", "hats", "mallet", "table", "super", "chip", "modal", "plate", "shimmer"];

/**
 * The demo OP-Z's settings: op-free's fake factory state plus the community engines in the slots they took on
 * the author's OP-Z (drums after the sample packs, synths 1-8, effects after TE's).
 */
function demoSettings() {
  const files = core.defaultFiles();
  const plugs = JSON.parse(new TextDecoder().decode(files.get("settings/plugs.json")));
  const slots = JSON.parse(new TextDecoder().decode(files.get("settings/slotConfiguration.json")));
  const track = (t) => {
    let entry = slots.tracks.find((x) => x.index === t);
    if (!entry) slots.tracks.push((entry = { index: t, packs: [] }));
    return entry.packs;
  };
  const layout = {
    fmperc: [[0, 5], [1, 5], [2, 5], [3, 5]], hats: [[0, 6], [1, 6], [2, 6], [3, 6]],
    snap: [[0, 7], [1, 7], [2, 7], [3, 7]], mallet: [[0, 8], [1, 8], [2, 8], [3, 8]], "8bit": [[0, 9], [1, 9], [2, 9], [3, 9]],
    table: 1, modal: 2, vowel: 3, super: 4, pluck: 5, dx: 6, fm2: 7, chip: 8,
    clouds: [[8, 7]], echo: [[8, 8]], plate: [[8, 9], [9, 6]], shimmer: [[8, 10]],
    swirl: [[9, 7]], filter: [[9, 8]], resonator: [[9, 9]], glue: [[9, 10]],
  };
  for (const [dir, where] of Object.entries(layout)) {
    const e = catalogue.find((x) => x.dir === dir);
    const path = `engines/${dir}.engine`;
    plugs.engines.push({ memoryslot: e.manifest.memoryslot, path, version: e.manifest.engine_version ?? 1 });
    plugs.plugs.push({ engine: path, flags: e.manifest.plug.flags ?? 0, id: e.manifest.plug.id, samples: "",
      version: e.manifest.plug.version });
    const places = typeof where === "number" ? [4, 5, 6, 7].map((t) => [t, where]) : where;
    for (const [t, slot] of places) {
      const packs = track(t);
      const i = packs.findIndex((p) => p.slot === slot);
      if (i >= 0) packs.splice(i, 1);
      packs.push({ id: e.manifest.plug.id, slot });
    }
  }
  slots.tracks.sort((a, b) => a.index - b.index);
  for (const t of slots.tracks) t.packs.sort((a, b) => a.slot - b.slot);
  return { plugs: core.utf8(core.dumps(plugs)), slots: core.utf8(core.dumps(slots)) };
}

/** The file service pulling both settings files after the opening, both directions (the fake streams every part). */
function filePull(fake, transcript) {
  const sid = core.u16le(core.SERVER_ID);
  const host = (frame) => {
    transcript.push({ from: "host", hex: hex(frame) });
    fake.send(frame);
    for (let raw = fake.out.shift(); raw !== undefined; raw = fake.out.shift()) transcript.push({ from: "opz", hex: hex(raw) });
  };
  host(core.frame(0x51, sid));
  host(core.frame(0x52, core.concat(sid, Uint8Array.of(0))));
  for (const fid of [core.PLUGS_ID, core.SLOT_CONFIGURATION_ID]) {
    host(core.frame(0x35, core.concat(sid, core.u32le(fid), core.u16le(0))));
  }
  host(core.frame(0x52, core.concat(sid, Uint8Array.of(0))));
  host(core.frame(0x55, sid));
}

/** Open a StateSync session on op-free's fake OP-Z and ack every part, recording both directions. */
function opening(project, number, settings = null) {
  const files = new Map(core.defaultFiles());
  if (settings) {
    files.set("settings/plugs.json", settings.plugs);
    files.set("settings/slotConfiguration.json", settings.slots);
  }
  files.set(op.projectPath(number), project.toBytes());
  const fake = new core.FakeOpz(files);
  fake.project = number - 1;
  fake.pattern = 0;
  const transcript = [];
  const host = (frame) => { transcript.push({ from: "host", hex: hex(frame) }); fake.send(frame); };
  host(core.stateSyncClientHello(core.SERVER_ID));
  for (let raw = fake.out.shift(); raw !== undefined; raw = fake.out.shift()) {
    transcript.push({ from: "opz", hex: hex(raw) });
    const f = core.decodeFrame(raw);
    if (f.messageId === core.BANK_PART) {
      const v = new DataView(f.payload.buffer, f.payload.byteOffset);
      host(core.bankAckFrame(v.getUint16(2, true), v.getUint16(4, true)));
    }
  }
  // What the OP-Z sent: the project with the fake's live sounds in the active pattern.
  return { address: fake.address(), transcript, sent: fake.activeProject(), fake };
}

/** P1/P2 names from an engine README's parameter table: `| P1 **position** | … |`. */
function knobs(dir) {
  const text = readFileSync(join(opfree, "engines", dir, "README.md"), "utf8");
  const names = {};
  for (const m of text.matchAll(/^\|\s*P([12])\s*\*\*([^*]+)\*\*/gm)) names[`p${m[1]}`] ??= m[2].trim();
  return names;
}

/** One sentence, at most `max` characters. */
function short(text, max = 160) {
  if (!text) return null;
  const first = text.split(/(?<=[.!?])\s/)[0];
  return first.length <= max ? first : first.slice(0, max - 1).replace(/\s+\S*$/, "") + "…";
}

/** What op-free reads from pattern p: every track, step, note and sound, keyed as the TypeScript core keys them. */
function reads(pr, p) {
  const tracks = [];
  for (let t = 0; t < 16; t++) {
    const steps = [];
    for (let s = 0; s < 16; s++) steps.push({ notes: pr.notes(p, t, s), ...pr.step(p, t, s) });
    tracks.push({ record: pr.track(p, t), sound: pr.sound(p, t), muted: pr.muted(p, t), steps });
  }
  return { tempo: pr.tempo, patternInUse: pr.patternInUse(p), patternHasNotes: pr.patternHasNotes(p), tracks };
}

const write = (path, value) => {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(value, null, 1) + "\n");
  console.log(`wrote ${path.slice(root.length + 1)}`);
};

const vector = opening(vectorProject(), 1);
write(join(kit, "Tests/GalaxzKitTests/Fixtures/statesync-vector.json"), {
  source: "op-free core FakeOpz + vectorProject()", address: vector.address, transcript: vector.transcript,
  reads: reads(vector.sent, 0),
});
const settings = demoSettings();
const demo = opening(demoProject(), 1, settings);
const files = [];
filePull(demo.fake, files);
write(join(kit, "Sources/OPZLink/Resources/OPFree/demo-session.json"), {
  source: "op-free core FakeOpz + Galax-z demoProject() and demoSettings()",
  frames: demo.transcript.filter((e) => e.from === "opz").map((e) => e.hex),
  files: files.filter((e) => e.from === "opz").map((e) => e.hex),
});
write(join(kit, "Tests/GalaxzKitTests/Fixtures/file-session.json"), {
  source: "op-free core FakeOpz serving demoSettings(): $51, $52, $35 plugs.json, $35 slotConfiguration.json, close",
  transcript: files,
  plugs: new TextDecoder().decode(settings.plugs),
  slots: new TextDecoder().decode(settings.slots),
});
write(join(kit, "Sources/OPZModel/Resources/OPFree/engines.json"), {
  source: "op-free site/scripts/catalogue.ts buildCatalogue() and each engine's README",
  engines: catalogue.map((e) => {
    const k = knobs(e.dir);
    return {
      dir: e.dir, label: e.label, kind: e.kind, plug: e.manifest.plug.id, summary: short(e.summary),
      p1: k.p1 ? { name: k.p1, help: short(e.help?.p1, 120) } : null,
      p2: k.p2 ? { name: k.p2, help: short(e.help?.p2, 120) } : null,
      presets: e.presets.map((p) => p.name),
    };
  }),
});
