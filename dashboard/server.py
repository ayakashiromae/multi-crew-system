#!/usr/bin/env python3
"""crew ダッシュボードサーバ(標準ライブラリのみ・localhost限定)。
state/events.jsonl(hooks が追記)と state/meta.json を配信する。
実行時データは拠点ローカル: このサーバも各PCで独立に動く。"""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = int(os.environ.get("CREW_DASH_PORT", "7777"))
EVENTS = os.path.join(ROOT, "state", "events.jsonl")
META = os.path.join(ROOT, "state", "meta.json")
DECISIONS = os.path.join(ROOT, "state", "decisions.jsonl")
INDEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "index.html")


def tail_events(n=300):
    if not os.path.exists(EVENTS):
        return []
    with open(EVENTS, "rb") as f:
        try:
            f.seek(-min(os.path.getsize(EVENTS), 512 * 1024), os.SEEK_END)
        except OSError:
            pass
        lines = f.read().decode("utf-8", "replace").splitlines()
    out = []
    for ln in lines[-n:]:
        try:
            out.append(json.loads(ln))
        except Exception:
            continue
    return out


def open_decisions():
    """decisions.jsonl(追記型)から未決のみを返す"""
    if not os.path.exists(DECISIONS):
        return []
    st = {}
    with open(DECISIONS, encoding="utf-8") as f:
        for ln in f:
            try:
                r = json.loads(ln)
            except Exception:
                continue
            if r.get("status") == "open":
                st[r.get("id")] = r
            elif r.get("status") == "done":
                st.pop(r.get("id"), None)
    return list(st.values())


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, body, ctype="application/json; charset=utf-8", code=200):
        data = body if isinstance(body, bytes) else body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/":
            with open(INDEX, "rb") as f:
                self._send(f.read(), "text/html; charset=utf-8")
        elif path == "/api/events":
            self._send(json.dumps(tail_events(), ensure_ascii=False))
        elif path == "/api/decisions":
            self._send(json.dumps(open_decisions(), ensure_ascii=False))
        elif path == "/api/meta":
            meta = {}
            if os.path.exists(META):
                with open(META, encoding="utf-8") as f:
                    meta = json.load(f)
            self._send(json.dumps(meta, ensure_ascii=False))
        else:
            self._send("not found", "text/plain", 404)


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"crew dashboard: http://localhost:{PORT}")
    srv.serve_forever()
