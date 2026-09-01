#!/usr/bin/env python3
"""identity.yaml から拠点ローカル設定を生成する。
生成物(すべて git 管理外):
  .claude/settings.local.json … 読み書き許可フォルダ・環境変数・(crewテーマ時)スピナー文言
  state/identity_context.md   … GMクルーに注入される環境定義(CLAUDE.md が import)
  state/meta.json             … ダッシュボード表示用メタ情報
"""
import json
import os
import socket
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

try:
    import yaml
except ImportError:
    sys.exit("PyYAML がありません: pip3 install --user pyyaml")

if not os.path.exists("identity.yaml"):
    sys.exit("identity.yaml がありません。先に crew init を実行してください。")

with open("identity.yaml", encoding="utf-8") as f:
    ident = yaml.safe_load(f) or {}

op = ident.get("operator") or {}
paths = ident.get("paths") or {}
roster = ident.get("roster") or {}
theme = ident.get("theme") or "plain"
worker_flavor = str(ident.get("worker_flavor") or "none")
notify = (ident.get("notify") or {}).get("enabled", False)
codex_model = str((ident.get("codex") or {}).get("model") or "")

def ex(p):
    return os.path.expanduser(str(p)) if p else ""

outbox = ex(paths.get("outbox", "~/crew-out/review"))
shots = ex(paths.get("screenshots", "~/crew-out/shots"))
workspace = ex(paths.get("workspace", "~/dev/sandbox"))
readable = [ex(p) for p in (paths.get("readable") or [])]

for d in [outbox, shots, workspace, "state", "logs"]:
    if d:
        os.makedirs(d, exist_ok=True)

def read_if(path):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return f.read().strip()
    return ""

# ---- settings.local.json ------------------------------------------
perms = ident.get("permissions") or {}
def _rules(key):
    v = perms.get(key) or []
    return sorted({str(r).strip() for r in v if str(r).strip()})
allow_rules = _rules("allow")
# roster.coder が codex の拠点では、Codex(MCP)呼び出しの承認ダイアログを出さない(殿指示 2026-09-01)。
if str(roster.get("coder") or "") == "codex":
    allow_rules = sorted(set(allow_rules) | {"mcp__codex__codex", "mcp__codex__codex-reply"})

# .mcp.json は git 追跡外(プライベート化方針 2026-09-01)。roster.coder=codex の拠点で
# 存在しなければ生成する(手動編集を尊重し、既存ファイルは上書きしない)。
if str(roster.get("coder") or "") == "codex" and not os.path.exists(".mcp.json"):
    with open(".mcp.json", "w", encoding="utf-8") as f:
        json.dump({"mcpServers": {"codex": {"command": "codex", "args": [
            "mcp-server", "-c", "approval_policy=never", "-c", "sandbox_mode=workspace-write",
        ]}}}, f, ensure_ascii=False, indent=2)
        f.write("\n")
# force push はクルー共通の絶対禁止(CLAUDE.md)。identity で許可を広げても deny 側で必ず塞ぐ。
deny_rules = sorted(set(_rules("deny")) | {"Bash(git push --force:*)", "Bash(git push -f:*)"})

settings = {
    "permissions": {
        "additionalDirectories": sorted(set([outbox, shots, workspace] + readable)),
        **({"allow": allow_rules} if allow_rules else {}),
        "deny": deny_rules,
    },
    "env": {
        "CREW_OUTBOX": outbox,
        "CREW_SCREENSHOTS": shots,
        "CREW_WORKSPACE": workspace,
        "CREW_NOTIFY": "1" if notify else "0",
        "CREW_THEME": theme,
        "CREW_WORKER_FLAVOR": worker_flavor,
    },
}
if codex_model:
    settings["env"]["CREW_CODEX_MODEL"] = codex_model

# スピナー文言(進行中表示 "✶ ○○中…")。テーマに spinner_verbs.json があれば注入。表示のみ・トークン消費ゼロ。
spinner_path = f"themes/{theme}/spinner_verbs.json"
if os.path.exists(spinner_path):
    with open(spinner_path, encoding="utf-8") as f:
        spin = json.load(f)
    if isinstance(spin, dict) and spin.get("verbs"):
        settings["spinnerVerbs"] = {"mode": spin.get("mode", "replace"), "verbs": list(spin["verbs"])}

os.makedirs(".claude", exist_ok=True)
with open(".claude/settings.local.json", "w", encoding="utf-8") as f:
    json.dump(settings, f, ensure_ascii=False, indent=2)

# ---- テーマ読み込み ------------------------------------------------
persona = read_if(f"themes/{theme}/persona.md")
glossary = read_if(f"themes/{theme}/glossary.md")
vocab = read_if(f"themes/{theme}/vocabulary.yaml")

# ---- identity_context.md ------------------------------------------
lines = []
lines.append("# 環境定義(この拠点の自分仕様 — crew init が生成。直接編集しない)")
lines.append("")
lines.append("## オペレーター")
lines.append(f"- 名前: {op.get('name', '')}")
lines.append(f"- 呼び方: **{op.get('address_as', '')}** と呼ぶこと")
lines.append(f"- 所属/役割: {op.get('org', '')}")
lines.append("")
lines.append("## この環境の前提条件")
lines.append(str(ident.get("context", "")).strip())
lines.append("")
lines.append("## パス定義")
lines.append(f"- 成果物レビュー用(outbox): {outbox}")
lines.append(f"- スクリーンショット排出先: {shots}")
lines.append(f"- 新規作成してよいフォルダ(workspace): {workspace}")
lines.append("- 読み取り許可フォルダ:")
for p in readable:
    lines.append(f"  - {p}")
lines.append("")
lines.append("## クルー編成(roster) — 雇用時にこのモデル/AIを指定する")
for role, model in roster.items():
    lines.append(f"- {role}: {model}")
if codex_model:
    lines.append(f"- codex 呼び出し時のモデル: {codex_model}(環境変数 CREW_CODEX_MODEL)")
lines.append("")
lines.append(f"## worker の演出: {worker_flavor}")
lines.append("- `crew` = 各クルーは報告の冒頭1行だけに色クルー/QMクルーの一言を乗せる(環境変数で自動適用。GMが指示文で指定しない)")
lines.append("- `none` = worker は素の口調")
lines.append("")
if persona or vocab or glossary:
    lines.append(f"## テーマ: {theme} (GMクルーであるあなたにのみ適用。workerに配布禁止)")
    if persona:
        lines.append(persona)
    if glossary:
        lines.append("")
        lines.append(glossary)
    if vocab:
        lines.append("")
        lines.append("### 用語変換")
        lines.append("```yaml")
        lines.append(vocab)
        lines.append("```")
with open("state/identity_context.md", "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

# ---- meta.json (ダッシュボード用) ----------------------------------
meta = {
    "operator": op.get("name", ""),
    "address_as": op.get("address_as", ""),
    "org": op.get("org", ""),
    "theme": theme,
    "worker_flavor": worker_flavor,
    "hostname": socket.gethostname(),
    "roster": roster,
}
with open("state/meta.json", "w", encoding="utf-8") as f:
    json.dump(meta, f, ensure_ascii=False, indent=2)

print("generated: .claude/settings.local.json / state/identity_context.md / state/meta.json"
      + (f" (spinner verbs: {len(settings['spinnerVerbs']['verbs'])})" if "spinnerVerbs" in settings else ""))
