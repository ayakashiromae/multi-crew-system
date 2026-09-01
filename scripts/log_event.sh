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
# 稼働中クルー表示(タブ①)用: Task/Agent 呼び出しは agent(subagent_type)と task(description)を
# 既存フィールドとは別に記録する(後方互換維持。この2フィールドが無い旧レコードも従来どおり動く)。
if rec.get("tool") in ("Task", "Agent"):
    agent_v = ti.get("subagent_type")
    if agent_v:
        rec["agent"] = str(agent_v)[:80]
    task_v = ti.get("description") or ti.get("prompt")
    if task_v:
        rec["task"] = str(task_v).replace("\n", " ")[:160]
# SubagentStop(CrewDone)に将来 agent 識別情報が乗る場合に備えた同様の拾い上げ(現状のペイロードには
# 通常含まれない。無ければ何も付与しない=best effort)。
if rec.get("event") == "CrewDone":
    agent_v = d.get("subagent_type") or ti.get("subagent_type") or d.get("agent_name")
    if agent_v:
        rec["agent"] = str(agent_v)[:80]
with open(os.path.join(os.environ["ROOT"], "state", "events.jsonl"), "a", encoding="utf-8") as f:
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")
PY
exit 0
