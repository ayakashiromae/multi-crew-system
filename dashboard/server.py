#!/usr/bin/env python3
"""crew ダッシュボードサーバ(標準ライブラリのみ・localhost限定)。
state/events.jsonl(hooks が追記)と state/meta.json を配信する。
実行時データは拠点ローカル: このサーバも各PCで独立に動く。"""
import json
import os
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = int(os.environ.get("CREW_DASH_PORT", "7777"))
EVENTS = os.path.join(ROOT, "state", "events.jsonl")
META = os.path.join(ROOT, "state", "meta.json")
DECISIONS = os.path.join(ROOT, "state", "decisions.jsonl")
CLOSING = os.path.join(ROOT, "state", "closing.json")
CLOSING_SH = os.path.join(ROOT, "tools", "closing.sh")
_shutdown_cache = {"ts": 0.0}
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
    """decisions.jsonl(追記型)から未決のみを返す。kind フィールドの無い既存レコードは
    "block"(判断待ち)として扱う(後方互換)。"""
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
                r.setdefault("kind", "block")
                st[r.get("id")] = r
            elif r.get("status") == "done":
                st.pop(r.get("id"), None)
    return list(st.values())


def crews_status():
    """稼働中クルー一覧(best effort)。events.jsonl の Tool/Agent(spawn。agent フィールドあり)と
    CrewDone(完了)を時系列で突き合わせる。CrewDone に agent 識別が乗っていれば同一 agent 内の
    最古 spawn を完了させ、識別が無い場合のみ全体 FIFO で近似する(異種クルーの並行時、完了順が
    起動順と違うと全体 FIFO は取り違えるため)。対応付けが取れているとは限らないので、
    spawn から2時間経過したものは無条件に稼働中から外す(保険)。"""
    open_spawns = []  # [{agent, task, since, agent_id}]
    for e in tail_events(3000):
        if e.get("event") == "Tool" and e.get("tool") in ("Task", "Agent") and e.get("agent"):
            open_spawns.append({"agent": e["agent"], "task": e.get("task", ""), "since": e.get("ts", ""),
                                "agent_id": e.get("agent_id", "")})
        elif e.get("event") == "CrewDone":
            if not open_spawns:
                continue
            done_id = e.get("agent_id", "")
            done_agent = e.get("agent") or e.get("agent_type", "")
            # 1) agent_id 一致が最優先(起動時に tool_response から控えた ID と突き合わせ)
            if done_id and any(s["agent_id"] == done_id for s in open_spawns):
                open_spawns[:] = [s for s in open_spawns if s["agent_id"] != done_id]
                continue
            # 2) agent_type 一致: 同種の最古 spawn を完了扱い
            if done_agent:
                for i, s in enumerate(open_spawns):
                    if s["agent"] == done_agent:
                        open_spawns.pop(i)
                        break
                continue
            # 3) 識別情報が乗っている(新形式)のに一致しない CrewDone は、auto モードの権限クラシ
            #    ファイア等の内部エージェント由来(agent_type 空・30 秒おきに発火)なので無視する。
            if done_id:
                continue
            # 4) 旧形式(識別情報なし)のみ全体 FIFO で近似
            open_spawns.pop(0)
    now = datetime.now()
    fresh = []
    for s in open_spawns:
        try:
            age = (now - datetime.fromisoformat(s["since"])).total_seconds()
        except Exception:
            age = 0
        if age <= 2 * 3600:
            fresh.append(s)
    return fresh


def closing_status():
    """state/closing.json を返す。shutdown 判定は 30 秒キャッシュで tools/closing.sh status を実行して更新"""
    import subprocess, time
    now = time.time()
    if now - _shutdown_cache["ts"] > 30 and os.path.exists(CLOSING_SH):
        try:
            subprocess.run(["bash", CLOSING_SH, "status"], capture_output=True, timeout=20)
        except Exception:
            pass
        _shutdown_cache["ts"] = now
    if not os.path.exists(CLOSING):
        return {}
    try:
        with open(CLOSING, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


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
        elif path == "/api/crews":
            self._send(json.dumps(crews_status(), ensure_ascii=False))
        elif path == "/api/closing":
            self._send(json.dumps(closing_status(), ensure_ascii=False))
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
