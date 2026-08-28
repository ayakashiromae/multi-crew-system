#!/usr/bin/env bash
# crew test — 1コマンドで環境の自己診断。「テストは1コマンドへ」(初期原則18)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
OK="\033[32m✔\033[0m"; NG="\033[31m✘\033[0m"; fail=0
pass(){ echo -e "  ${OK} $1"; }; ng(){ echo -e "  ${NG} $1"; fail=$((fail+1)); }

echo "[crew test] 自己診断 ($(date '+%Y-%m-%d %H:%M'))"
# 1. 必須ファイル
for f in CLAUDE.md bin/crew scripts/gen_settings.py scripts/secret_guard_hook.sh scripts/log_event.sh \
         .claude/settings.json .claude/agents/coder.md .claude/skills/operator-principles/SKILL.md \
         themes/plain/persona.md themes/crew/persona.md themes/crew/spinner_verbs.json tools/notify.sh tools/decision.sh; do
  [ -f "$f" ] && pass "exists: $f" || ng "missing: $f"
done
# 2. JSON 妥当性
for j in .claude/settings.json .mcp.json themes/crew/spinner_verbs.json; do
  python3 -c "import json,sys; json.load(open('$j'))" 2>/dev/null && pass "json: $j" || ng "json broken: $j"
done
# 3. shell 構文
for s in bin/crew scripts/*.sh tools/*.sh; do
  bash -n "$s" 2>/dev/null && pass "bash -n: $s" || ng "syntax: $s"
done
# 4. gen_settings をサンプル identity で乾式実行(実 identity は触らない)
TMP="$(mktemp -d)"; cp -r . "$TMP/w" 2>/dev/null; (
  cd "$TMP/w" && rm -rf state .claude/settings.local.json && cp identity.example.yaml identity.yaml \
  && sed -i 's/^theme: .*/theme: crew/; s/^worker_flavor: .*/worker_flavor: crew/' identity.yaml \
  && python3 scripts/gen_settings.py >/dev/null 2>&1 \
  && python3 - <<'PY'
import json; s=json.load(open('.claude/settings.local.json'))
assert s['env']['CREW_THEME']=='crew' and s['env']['CREW_WORKER_FLAVOR']=='crew', s['env']
assert len(s.get('spinnerVerbs',{}).get('verbs',[]))>100, 'spinner verbs not injected'
assert 'GMクルー' in open('state/identity_context.md',encoding='utf-8').read()
PY
) && pass "gen_settings (crew theme + spinner verbs 注入)" || ng "gen_settings dry-run failed"
rm -rf "$TMP"
# 5. secret guard: ブロックすべきもの/通すべきもの
sg(){ printf '%s' "$2" | bash scripts/secret_guard_hook.sh >/dev/null 2>&1; echo $?; }
BLOCK='{"tool_name":"Bash","tool_input":{"command":"cat .env"}}'
BLOCK2='{"tool_name":"Bash","tool_input":{"command":"docker compose config"}}'
BLOCK3='{"tool_name":"Bash","tool_input":{"command":"echo \"$OPENAI_API_KEY\""}}'
BLOCK4='{"tool_name":"Read","tool_input":{"file_path":"/home/x/proj/machines/home.env"}}'
ALLOW='{"tool_name":"Bash","tool_input":{"command":"grep -c . .env.example; ls -la"}}'
ALLOW2='{"tool_name":"Read","tool_input":{"file_path":"/home/x/proj/scripts/secret_guard_hook.sh"}}'
ALLOW3='{"tool_name":"Bash","tool_input":{"command":"docker compose build && echo done"}}'
[ "$(sg b "$BLOCK")" = 2 ]  && pass "secret-guard blocks: cat .env" || ng "secret-guard let through: cat .env"
[ "$(sg b "$BLOCK2")" = 2 ] && pass "secret-guard blocks: docker compose config" || ng "secret-guard let through: compose config"
[ "$(sg b "$BLOCK3")" = 2 ] && pass "secret-guard blocks: echo \$OPENAI_API_KEY" || ng "secret-guard let through: echo key"
[ "$(sg b "$BLOCK4")" = 2 ] && pass "secret-guard blocks: Read machines/*.env" || ng "secret-guard let through: Read env"
[ "$(sg a "$ALLOW")" = 0 ]  && pass "secret-guard allows: grep -c .env.example" || ng "secret-guard false positive: grep -c"
[ "$(sg a "$ALLOW2")" = 0 ] && pass "secret-guard allows: Read hook script" || ng "secret-guard false positive: Read .sh"
[ "$(sg a "$ALLOW3")" = 0 ] && pass "secret-guard allows: docker compose build" || ng "secret-guard false positive: compose build"
# 6. 拠点ローカル物が git 管理外か
if git rev-parse --git-dir >/dev/null 2>&1; then
  for p in identity.yaml machines/x.env state/x logs/x .claude/settings.local.json; do
    git check-ignore -q "$p" && pass "gitignored: $p" || ng "NOT ignored: $p"
  done
fi
echo ""
[ "$fail" = 0 ] && echo -e "${OK} all passed" || { echo -e "${NG} ${fail} failed"; exit 1; }
