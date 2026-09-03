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
# SessionStart は source(startup/resume/clear/compact)を控える(稼働中クルーの幽霊掃除の判定材料)
if rec.get("event") == "SessionStart" and d.get("source"):
    rec["detail"] = str(d["source"])[:40]
# 稼働中クルー表示(タブ①)用: Task/Agent 呼び出しは agent(subagent_type)と task(description)を
# 既存フィールドとは別に記録する(後方互換維持。この2フィールドが無い旧レコードも従来どおり動く)。
if rec.get("tool") in ("Task", "Agent"):
    agent_v = ti.get("subagent_type")
    if agent_v:
        rec["agent"] = str(agent_v)[:80]
    task_v = ti.get("description") or ti.get("prompt")
    if task_v:
        rec["task"] = str(task_v).replace("\n", " ")[:160]
    # PostToolUse の tool_response に "agentId: <hex>" が含まれる(非同期起動時)。CrewDone の
    # agent_id と突き合わせるために控える。
    import re
    resp = d.get("tool_response")
    try:
        resp_s = resp if isinstance(resp, str) else json.dumps(resp, ensure_ascii=False)
    except Exception:
        resp_s = str(resp)
    m = re.search(r"agentId:\s*([0-9a-f]{8,})", resp_s or "")
    if m:
        rec["agent_id"] = m.group(1)
# SubagentStop(CrewDone)に将来 agent 識別情報が乗る場合に備えた同様の拾い上げ(現状のペイロードには
# 通常含まれない。無ければ何も付与しない=best effort)。
if rec.get("event") == "CrewDone":
    agent_v = d.get("subagent_type") or ti.get("subagent_type") or d.get("agent_name") or d.get("agent_type")
    if agent_v:
        rec["agent"] = str(agent_v)[:80]
    # SubagentStop payload の agent_id / agent_type を控える。auto モードの権限クラシファイア等の
    # 内部エージェントは agent_type が空で頻発するため、server 側で識別不能な CrewDone は無視する。
    for k in ("agent_id", "agent_type"):
        if d.get(k):
            rec[k] = str(d[k])[:80]
# サブエージェント発のツールイベントにも agent_id が乗るなら残す(稼働中判定の材料)
if d.get("agent_id") and "agent_id" not in rec:
    rec["agent_id"] = str(d["agent_id"])[:80]
with open(os.path.join(os.environ["ROOT"], "state", "events.jsonl"), "a", encoding="utf-8") as f:
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")
PY
exit 0
