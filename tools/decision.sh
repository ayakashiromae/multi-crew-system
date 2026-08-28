#!/usr/bin/env bash
# tools/decision.sh — オペレーター判断待ち(非ブロッキング)の台帳
#   add "<内容>" [既定値で先行した内容]   … 判断待ちを登録(id を表示)
#   done <id> ["<決定内容>"]               … 決着を記録
#   list                                   … 未決一覧
# 保存先: state/decisions.jsonl(拠点ローカル・git管理外)。ダッシュボードの「判断待ち」に表示される。
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/state/decisions.jsonl"
mkdir -p "$ROOT/state"; touch "$FILE"
export FILE
case "${1:-list}" in
  add)
    [ -z "${2:-}" ] && { echo "usage: decision.sh add \"<内容>\" [先行した既定値]"; exit 1; }
    ITEM="$2" DEFAULT="${3:-}" python3 - <<'PY'
import json, os, time
f=os.environ["FILE"]; n=sum(1 for _ in open(f, encoding="utf-8")) if os.path.getsize(f) else 0
rec={"id":n+1,"ts":time.strftime("%Y-%m-%dT%H:%M:%S"),"item":os.environ["ITEM"],"default":os.environ["DEFAULT"],"status":"open"}
open(f,"a",encoding="utf-8").write(json.dumps(rec,ensure_ascii=False)+"\n"); print(f"[decision] #{rec['id']} 登録: {rec['item']}")
PY
    ;;
  done)
    [ -z "${2:-}" ] && { echo "usage: decision.sh done <id> [\"<決定内容>\"]"; exit 1; }
    ID="$2" RESULT="${3:-}" python3 - <<'PY'
import json, os, time
f=os.environ["FILE"]; rec={"id":int(os.environ["ID"]),"ts":time.strftime("%Y-%m-%dT%H:%M:%S"),"status":"done","result":os.environ["RESULT"]}
open(f,"a",encoding="utf-8").write(json.dumps(rec,ensure_ascii=False)+"\n"); print(f"[decision] #{rec['id']} 決着")
PY
    ;;
  list|*)
    python3 - <<'PY'
import json, os
f=os.environ["FILE"]; st={}
for ln in open(f, encoding="utf-8"):
    try: r=json.loads(ln)
    except Exception: continue
    if r.get("status")=="open": st[r["id"]]=r
    elif r.get("status")=="done": st.pop(r["id"],None)
if not st: print("[decision] 未決なし")
for r in st.values(): print(f"#{r['id']} {r['ts']} {r['item']}" + (f"  (先行既定値: {r['default']})" if r.get('default') else ""))
PY
    ;;
esac
