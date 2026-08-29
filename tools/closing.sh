#!/usr/bin/env bash
# tools/closing.sh — 「本日の締め」台帳とシャットダウン可否(ダッシュボードの締めパネルに出る)
#   set <closing.md>      … 締め文書(下記フォーマット)を state/closing.json に取り込む
#   status                … シャットダウン可否を判定して表示(JSON は state/closing.json に反映)
#   show                  … 現在の締めを表示
# closing.md のフォーマット(見出しで区切る。表は | 系統 | 成果 | 場所 |):
#   ## やったこと / ## 殿待ち / ## 次に着手 / ## 稼働中(GMが把握している未完了クルー。空なら「なし」)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/state/closing.json"; mkdir -p "$ROOT/state"
export ROOT FILE
case "${1:-status}" in
  set)
    [ -f "${2:-}" ] || { echo "usage: closing.sh set <closing.md>"; exit 1; }
    SRC="$2" python3 - <<'PY'
import json, os, re, time
src=open(os.environ["SRC"],encoding="utf-8").read()
def section(name):
    m=re.search(r"^##\s*"+name+r".*?$(.*?)(?=^##\s|\Z)", src, re.S|re.M)
    return m.group(1).strip() if m else ""
def table(txt):
    rows=[]
    for ln in txt.splitlines():
        if ln.startswith("|") and not re.match(r"^\|\s*-", ln) and "系統" not in ln:
            c=[x.strip() for x in ln.strip("|").split("|")]
            if len(c)>=3: rows.append({"area":c[0],"result":c[1],"where":c[2]})
    return rows
def bullets(txt):
    return [re.sub(r"^\s*(?:\d+\.|[-*])\s*","",ln).strip() for ln in txt.splitlines() if re.match(r"^\s*(?:\d+\.|[-*])\s", ln)]
data={"date":time.strftime("%Y-%m-%d"),"ts":time.strftime("%Y-%m-%dT%H:%M:%S"),
      "done":table(section("やったこと")),"waiting":bullets(section("殿待ち")),
      "next":bullets(section("次に着手")),"running":[b for b in bullets(section("稼働中")) if b and b!="なし"]}
old={}
if os.path.exists(os.environ["FILE"]):
    try: old=json.load(open(os.environ["FILE"],encoding="utf-8"))
    except Exception: old={}
old.update(data); json.dump(old,open(os.environ["FILE"],"w",encoding="utf-8"),ensure_ascii=False,indent=1)
print(f"[closing] {data['date']} 取り込み: やったこと {len(data['done'])} / 殿待ち {len(data['waiting'])} / 次 {len(data['next'])} / 稼働中 {len(data['running'])}")
PY
    ;;
  show)
    python3 -c "import json,os;d=json.load(open(os.environ['FILE'],encoding='utf-8'));print(json.dumps(d,ensure_ascii=False,indent=1))" 2>/dev/null || echo "[closing] まだ無い"
    ;;
  status|*)
    python3 - <<'PY'
import json, os, subprocess, time, datetime
root=os.environ["ROOT"]; f=os.environ["FILE"]
d={}
if os.path.exists(f):
    try: d=json.load(open(f,encoding="utf-8"))
    except Exception: d={}
reasons=[]; ok=True
# 1) GM が把握している稼働中クルー
running=d.get("running",[])
if running: ok=False; reasons.append(f"稼働中クルー {len(running)} 件: "+" / ".join(running))
# 2) 最終ツールイベントからの経過(10 分未満なら作業中の可能性)
ev=os.path.join(root,"state","events.jsonl"); last=None
if os.path.exists(ev):
    for ln in open(ev,encoding="utf-8",errors="replace").readlines()[-400:]:
        try: r=json.loads(ln)
        except Exception: continue
        if r.get("event")=="Tool" and "closing.sh" not in str(r.get("detail","")) and "decision.sh" not in str(r.get("detail","")): last=r.get("ts")
if last:
    try:
        age=(datetime.datetime.now()-datetime.datetime.fromisoformat(last)).total_seconds()/60
        if age<10: ok=False; reasons.append(f"最終ツール実行から {age:.0f} 分(作業中の可能性)")
    except Exception: pass
# 3) 重い処理プロセス(レンダ・文字起こし・合成)
try:
    ps=subprocess.run(["ps","-eo","pid,etimes,cmd"],capture_output=True,text=True).stdout
    heavy=[l.strip()[:90] for l in ps.splitlines() if any(k in l for k in ("remotion render","transcribe.py","render.py","voice.py","postprocess.py","ffmpeg -")) and "grep" not in l]
    if heavy: ok=False; reasons.append(f"実行中の重い処理 {len(heavy)} 件: "+" | ".join(heavy[:3]))
except Exception: pass
# 4) 未コミット(このリポジトリ)
try:
    st=subprocess.run(["git","-C",root,"status","--porcelain"],capture_output=True,text=True).stdout.strip()
    if st: reasons.append(f"未コミット {len(st.splitlines())} 件(実害なし・任意)")
except Exception: pass
# 5) 未決の判断待ち(情報のみ)
dec=os.path.join(root,"state","decisions.jsonl"); opens={}
if os.path.exists(dec):
    for ln in open(dec,encoding="utf-8"):
        try: r=json.loads(ln)
        except Exception: continue
        if r.get("status")=="open": opens[r["id"]]=r
        elif r.get("status")=="done": opens.pop(r["id"],None)
if opens: reasons.append(f"殿判断待ち {len(opens)} 件(止める理由にはならない)")
d["shutdown"]={"ok":ok,"checked":time.strftime("%Y-%m-%dT%H:%M:%S"),"reasons":reasons,
               "note":"OK=クルー稼働なし・重い処理なし。docker の VOICEVOX は止めてよい(次回 crew up で再起動)"}
json.dump(d,open(f,"w",encoding="utf-8"),ensure_ascii=False,indent=1)
print("[shutdown] "+("✅ 落としてよい" if ok else "⛔ まだ待て")); [print("  - "+r) for r in reasons]
PY
    ;;
esac
