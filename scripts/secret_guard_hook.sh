#!/usr/bin/env bash
# secret_guard_hook.sh — PreToolUse hook (matcher=Bash|Read): 秘密露出の機械的防止
#
# 入力: stdin に Claude Code が渡す JSON {tool_name, tool_input:{command|file_path}}
# 出力: 危険パターン一致 → stderr へ理由、exit 2(ツール実行を拒否)
#       それ以外/解析不能 → exit 0(fail-open。フック自身の故障で全クルーを止めない。
#       規約(CLAUDE.md 秘匿規則)が第一防御で、本フックは補助網)
# 由来: 旧環境 secret_guard_hook.sh(cmd_019/088/109)の縮約版。
set -u
payload="$(cat 2>/dev/null || true)"
[ -n "${SECRET_GUARD_DISABLE:-}" ] && exit 0

if command -v jq >/dev/null 2>&1; then
  tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null || true)"
  cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
  fp="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
else
  p="$(printf '%s' "$payload" | tr '\n' ' ')"
  tool="$(printf '%s' "$p" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  cmd="$(printf '%s' "$p" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p')"
  fp="$(printf '%s' "$p" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi

block() {
  echo "🛑 [secret-guard] ブロック: $1 — 秘密を解決・展開・表示する操作は禁止(CLAUDE.md 秘匿規則)。件数のみ/ダミー.env/キー名のみの出力など代替手段を使うこと。" >&2
  exit 2
}

SECRET_FILE_RE='(^|/)(\.env(\.[A-Za-z0-9_.-]+)?|machines/[^/]+\.env|[^/]*\.pem|id_rsa[^/]*|[^/]*\.p12|[^/]*\.pfx)$'
SECRET_KEY_RE='(PASSWORD|PASSWD|_PASS|SECRET|TOKEN|API_?KEY|_KEY|CREDENTIAL|PRIVATE_KEY|WEBHOOK_URL)'
BOUND='(^|[|;&[:space:]'"'"'"`(])'

case "$tool" in
  Read)
    [ -n "$fp" ] && printf '%s' "$fp" | grep -Eq "$SECRET_FILE_RE" && block "Read $fp"
    ;;
  Bash)
    [ -z "$cmd" ] && exit 0
    # a) .env 系の内容表示
    printf '%s' "$cmd" | grep -Eq "${BOUND}(cat|less|more|head|tail|bat|strings|nl|tac)[[:space:]]+[^|;&]*(\.env([[:space:]]|$|\.)|machines/[^[:space:]]*\.env)" && block "$cmd"
    # b) 秘密を解決して丸ごと出す config 系
    printf '%s' "$cmd" | grep -Eq "${BOUND}docker([[:space:]]+|-)compose[[:space:]].*[[:space:]]config([[:space:]]|$)" && block "$cmd"
    # c) 環境変数の無条件ダンプ
    printf '%s' "$cmd" | grep -Eq "${BOUND}(env|printenv|export|set)[[:space:]]*($|[|;&])" && block "$cmd"
    # d) 秘密変数の直接 echo / printf
    printf '%s' "$cmd" | grep -Eq "${BOUND}(echo|printf)[[:space:]].*\\$\\{?[A-Za-z0-9_]*${SECRET_KEY_RE}" && block "$cmd"
    # e) grep で秘密キー行をそのまま出す(=KEY=VALUE 行の全文出力)
    printf '%s' "$cmd" | grep -Eq "${BOUND}(grep|rg|ag)[[:space:]].*${SECRET_KEY_RE}.*(\.env|machines/)" && block "$cmd"
    ;;
esac
exit 0
