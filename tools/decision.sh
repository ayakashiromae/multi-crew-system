#!/usr/bin/env bash
# tools/decision.sh — 判断待ち / クルー裁定 の台帳
#   add "<内容>" [既定値で先行した内容]   … 判断待ち(kind: block。殿の判断まで作業が止まる)を登録(id を表示)
#   rule "<内容>" [既定値]                 … クルー裁定(kind: rule。作業は止めず、既定値で先行し後追い確認)を登録
#   done <id> ["<決定内容>"]               … 決着を記録
#   list                                   … 未決一覧(区分見出し付き)
# 保存先: state/decisions.jsonl(拠点ローカル・git管理外)。ダッシュボードの「判断待ち」「クルー裁定」に表示される。
# kind フィールドの無い既存レコードは "block"(判断待ち)として扱う(後方互換)。
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/state/decisions.jsonl"
mkdir -p "$ROOT/state"; touch "$FILE"
export FILE
add_record(){
  KIND="$1" ITEM="$2" DEFAULT="$3" python3 - <<'PY'
import json, os, time
f=os.environ["FILE"]; n=sum(1 for _ in open(f, encoding="utf-8")) if os.path.getsize(f) else 0
rec={"id":n+1,"ts":time.strftime("%Y-%m-%dT%H:%M:%S"),"kind":os.environ["KIND"],"item":os.environ["ITEM"],"default":os.environ["DEFAULT"],"status":"open"}
open(f,"a",encoding="utf-8").write(json.dumps(rec,ensure_ascii=False)+"\n")
label="判断待ち" if rec["kind"]=="block" else "クルー裁定"
print(f"[decision] #{rec['id']} 登録({label}): {rec['item']}")
PY
}
case "${1:-list}" in
  add)
    [ -z "${2:-}" ] && { echo "usage: decision.sh add \"<内容>\" [先行した既定値]"; exit 1; }
    add_record "block" "$2" "${3:-}"
    ;;
  rule)
    [ -z "${2:-}" ] && { echo "usage: decision.sh rule \"<内容>\" [既定値]"; exit 1; }
    add_record "rule" "$2" "${3:-}"
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
blocks=[r for r in st.values() if r.get("kind","block")=="block"]
rules=[r for r in st.values() if r.get("kind")=="rule"]
def line(r):
    return f"#{r['id']} {r['ts']} {r['item']}" + (f"  (既定値: {r['default']})" if r.get('default') else "")
print("== 判断待ち(作業停止中) ==")
if not blocks: print("  なし")
for r in blocks: print("  "+line(r))
print("== クルー裁定(先行中・後追い確認) ==")
if not rules: print("  なし")
for r in rules: print("  "+line(r))
PY
    ;;
esac
