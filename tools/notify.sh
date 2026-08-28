#!/usr/bin/env bash
# tools/notify.sh — クルーからのお知らせ用。設定済みの通知先すべてに送る。
#   使い方: tools/notify.sh "メッセージ" [タイトル]
# 通知先は machines/<hostname>.env に定義:
#   SLACK_WEBHOOK_URL=...   (Slack Incoming Webhook)
#   NTFY_TOPIC=...          (https://ntfy.sh — トピック名は推測不可能なものに)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MSG="${1:-}"
TITLE="${2:-crew}"
[ -z "$MSG" ] && { echo "usage: notify.sh \"message\" [title]"; exit 1; }

# env 未読込でも単体で動くように、自拠点の env を読む
ENV_FILE="$ROOT/machines/$(hostname).env"
# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && set -a && . "$ENV_FILE" && set +a

sent=0

if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  payload=$(printf '{"text":"[%s] %s"}' "$TITLE" "$MSG" | sed 's/\\/\\\\/g')
  curl -s -o /dev/null -X POST -H 'Content-Type: application/json' \
    -d "$payload" "$SLACK_WEBHOOK_URL" && sent=1
fi

if [ -n "${NTFY_TOPIC:-}" ]; then
  curl -s -o /dev/null -H "Title: $TITLE" -d "$MSG" "https://ntfy.sh/${NTFY_TOPIC}" && sent=1
fi

if [ "$sent" = 0 ]; then
  echo "[notify] 通知先が未設定です (crew keys で SLACK_WEBHOOK_URL / NTFY_TOPIC を設定)"
  exit 0
fi
echo "[notify] sent: $MSG"
