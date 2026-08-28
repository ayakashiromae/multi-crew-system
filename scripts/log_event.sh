#!/usr/bin/env bash
# Claude Code hooks から呼ばれ、イベントを state/events.jsonl に追記する(ダッシュボード用)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/state"
PAYLOAD="$(cat 2>/dev/null || true)"
export ROOT EVENT="${1:-unknown}" PAYLOAD
python3 - <<'PY' 2>/dev/null
import json, os, time
try:
    d = json.loads(os.environ.get("PAYLOAD") or "{}")
except Exception:
    d = {}
rec = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "event": os.environ.get("EVENT", "unknown"),
    "tool": d.get("tool_name", ""),
}
ti = d.get("tool_input") or {}
for k in ("subagent_type", "description", "file_path", "command", "prompt"):
    v = ti.get(k)
    if v:
        rec["detail"] = str(v).replace("\n", " ")[:160]
        break
if not rec.get("detail") and d.get("prompt"):
    rec["detail"] = str(d["prompt"]).replace("\n", " ")[:160]
with open(os.path.join(os.environ["ROOT"], "state", "events.jsonl"), "a", encoding="utf-8") as f:
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")
PY
exit 0
