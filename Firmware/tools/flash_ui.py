#!/usr/bin/env python3
"""flash_ui — a small local page for flash.py: check what is on the OP-Z, flash an image, go back to the original.

    python3 Firmware/tools/flash_ui.py [--port 8642]     then open http://127.0.0.1:8642 (Firmware/flash does both)

Everything goes through flash.py's Console, with the same refusals; the page only picks a label. It listens on
127.0.0.1 only, runs one job at a time, and asks you to type the label before it writes.
"""

from __future__ import annotations

import argparse
import json
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import flash  # noqa: E402

STATE = {"busy": None, "log": [], "installed": None, "progress": None, "result": None}
LOCK = threading.Lock()


def out(line: str) -> None:
    print(line)
    with LOCK:
        STATE["log"].append(line)


def run(job: str, label: str | None = None) -> None:
    folder = None
    try:
        images = flash.load_images()
        folder = flash.run_dir()
        port = flash.open_serial(None)
        con = flash.Console(port, flash.allowed(images), out)
        try:
            if job == "check":
                STATE["installed"] = flash.check(con, images, folder)
            else:
                out(f"== flash {label}")
                flash.flash(con, images, label, folder,
                            progress=lambda name, i, n: STATE.update(progress={"name": name, "done": i, "of": n}))
                STATE["installed"] = label
            STATE["result"] = {"ok": True, "text": "done"}
        finally:
            port.close()
    except (flash.Refused, flash.Stalled) as e:
        out(f"STOPPED: {e}")
        STATE["result"] = {"ok": False, "text": str(e)}
    except Exception as e:  # noqa: BLE001 - shown to the user, not swallowed
        out(f"ERROR: {type(e).__name__}: {e}")
        STATE["result"] = {"ok": False, "text": str(e)}
    finally:
        if folder:
            (folder / "log.txt").write_text("\n".join(STATE["log"]) + "\n")
            out(f"log and backups: {folder}")
        STATE["busy"] = None


def images_json():
    try:
        return [{"label": im.label, "title": im.title, "flashable": im.ldr is not None, "reason": im.reason,
                 "patches": list(im.patches), "sha256": flash.sha(im.ldr) if im.ldr else None,
                 "crc32": im.crc.decode() if im.ldr else None} for im in flash.load_images().values()], None
    except flash.Refused as e:
        return [], str(e)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def reply(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/":
            return self.reply(200, PAGE.encode(), "text/html; charset=utf-8")
        if self.path == "/api/state":
            imgs, err = images_json()
            ports = sorted(Path("/dev").glob("cu.usbmodem*"))
            with LOCK:
                return self.reply(200, {**STATE, "images": imgs, "error": err, "ports": [str(p) for p in ports]})
        self.reply(404, {"error": "not found"})

    def do_POST(self):
        # Only the page itself may start a job (a browser on another site cannot set this header without CORS).
        if self.headers.get("X-Galaxz") != "1":
            return self.reply(403, {"error": "forbidden"})
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
        if STATE["busy"]:
            return self.reply(409, {"error": f"busy: {STATE['busy']}"})
        if self.path == "/api/check":
            job, label = "check", None
        elif self.path == "/api/flash":
            label = body.get("label")
            if not label or body.get("confirm") != label:
                return self.reply(400, {"error": "type the label to confirm"})
            job = "flash"
        else:
            return self.reply(404, {"error": "not found"})
        with LOCK:
            STATE.update(busy=job if job == "check" else f"flash {label}", log=[], progress=None, result=None)
        threading.Thread(target=run, args=(job, label), daemon=True).start()
        self.reply(202, {"started": job})


PAGE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Galax-z Flash</title>
<style>
:root{--bg:#f4f3ef;--card:#fff;--ink:#1b1b1b;--dim:#6b6b6b;--line:#dddad2;--accent:#ff5a1f;--ok:#1f9d55;--bad:#d64545}
@media (prefers-color-scheme:dark){:root{--bg:#121212;--card:#1c1c1c;--ink:#ececec;--dim:#9a9a9a;--line:#2e2e2e}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 -apple-system,system-ui,sans-serif}
main{max-width:760px;margin:0 auto;padding:28px 16px 60px}
h1{font-size:22px;margin:0 0 4px;letter-spacing:.02em}h1 b{color:var(--accent)}
.sub{color:var(--dim);margin:0 0 22px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px;margin-bottom:14px}
.row{display:flex;align-items:center;gap:12px;flex-wrap:wrap}.grow{flex:1;min-width:200px}
.k{color:var(--dim);font-size:13px}.mono{font:12.5px ui-monospace,Menlo,monospace;word-break:break-all}
button{font:inherit;border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:8px;padding:7px 14px;cursor:pointer}
button.go{background:var(--accent);border-color:var(--accent);color:#fff}button:disabled{opacity:.45;cursor:default}
input{font:inherit;padding:6px 10px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--ink);width:150px}
.tag{font-size:12px;padding:2px 8px;border-radius:99px;border:1px solid var(--line);color:var(--dim)}
.tag.ok{color:var(--ok);border-color:var(--ok)}.tag.bad{color:var(--bad);border-color:var(--bad)}
.confirm{display:none;margin-top:12px}.confirm.on{display:flex}
.bar{height:6px;background:var(--line);border-radius:3px;overflow:hidden;margin-top:10px}.bar i{display:block;height:100%;background:var(--accent);width:0}
pre{margin:0;max-height:340px;overflow:auto;font:12px/1.5 ui-monospace,Menlo,monospace;white-space:pre-wrap}
.msg{margin-top:10px;font-weight:600}.msg.ok{color:var(--ok)}.msg.bad{color:var(--bad)}
</style></head><body><main>
<h1>Galax-z <b>Flash</b></h1>
<p class="sub">Puts a known OS image on the OP-Z in update mode (hold SCREEN while switching on). Writes only os.ldr and os.crc32, and reads both back.</p>
<div class="card"><div class="row"><div class="grow"><div class="k">Device</div><div id="dev">…</div>
<div class="k" style="margin-top:6px">Installed</div><div id="inst">not checked</div></div>
<button id="check">Check device</button></div>
<div class="bar"><i id="bar"></i></div><div id="prog" class="k"></div><div id="msg" class="msg"></div></div>
<div id="images"></div>
<div class="card"><div class="k" style="margin-bottom:6px">Log</div><pre id="log">—</pre></div>
</main><script>
const $=id=>document.getElementById(id);let busy=null,open=null;
async function post(path,body){const r=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json','X-Galaxz':'1'},body:JSON.stringify(body||{})});
 if(!r.ok){const e=await r.json().catch(()=>({}));$('msg').className='msg bad';$('msg').textContent=e.error||r.status}}
$('check').onclick=()=>post('/api/check');
function card(im){const d=document.createElement('div');d.className='card';
 d.innerHTML=`<div class="row"><div class="grow"><b>${im.title}</b> <span class="k mono">${im.label}</span>
 <div class="k">${im.flashable?`crc32 ${im.crc32}${im.patches.length?' · '+im.patches.join(', '):''}`:''}</div>
 ${im.sha256?`<div class="mono k">${im.sha256}</div>`:''}</div>
 <span class="tag ${im.flashable?'ok':'bad'}">${im.flashable?'flashable':'not flashable'}</span>
 <button class="go" ${im.flashable?'':'disabled'}>Flash</button></div>
 ${im.flashable?'':`<div class="k" style="margin-top:8px">${im.reason}</div>`}
 <div class="confirm row"><span class="k">Type <b class="mono">${im.label}</b> to write it:</span><input autocomplete="off">
 <button class="go">Write to OP-Z</button><button>Cancel</button></div>`;
 const [flashB]=d.querySelectorAll('.row > button.go'),c=d.querySelector('.confirm'),[inp]=c.querySelectorAll('input'),[w,x]=c.querySelectorAll('button');
 flashB.onclick=()=>{open=im.label;c.classList.add('on');inp.value='';inp.focus()};
 x.onclick=()=>{open=null;c.classList.remove('on')};
 w.onclick=()=>{post('/api/flash',{label:im.label,confirm:inp.value.trim()});open=null;c.classList.remove('on')};
 if(open===im.label)c.classList.add('on');return d}
let shown='';
async function tick(){try{const s=await (await fetch('/api/state')).json();busy=s.busy;
 $('dev').textContent=s.ports.length?s.ports.join(', ')+(s.ports.length>1?' (more than one port: unplug the others)':''):'no OP-Z in update mode found';
 $('inst').textContent=s.installed||'not checked';
 const key=JSON.stringify(s.images)+s.error;if(key!==shown&&!open){shown=key;const box=$('images');box.innerHTML='';
  if(s.error){box.innerHTML=`<div class="card msg bad">${s.error}</div>`}s.images.forEach(im=>box.appendChild(card(im)))}
 document.querySelectorAll('button').forEach(b=>{b.disabled=!!busy||!!(b.classList.contains('go')&&b.closest('.card').querySelector('.tag.bad'))});
 const p=s.progress;$('bar').style.width=p?(100*p.done/p.of)+'%':'0';$('prog').textContent=busy?(busy+(p?` · ${p.name} ${p.done}/${p.of}`:'…')):'';
 if(s.result&&!busy){$('msg').className='msg '+(s.result.ok?'ok':'bad');$('msg').textContent=s.result.ok?'Done.':'Stopped: '+s.result.text}else if(busy){$('msg').textContent=''}
 const log=s.log.join('\n')||'—';if($('log').textContent!==log){$('log').textContent=log;$('log').scrollTop=1e9}}catch(e){$('dev').textContent='flash_ui is not running'}}
setInterval(tick,500);tick();
</script></body></html>"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--port", type=int, default=8642)
    ap.add_argument("--no-browser", action="store_true")
    a = ap.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", a.port), Handler)
    url = f"http://127.0.0.1:{a.port}"
    print(f"Galax-z Flash on {url} (ctrl-C stops it)")
    if not a.no_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
