#!/usr/bin/env bash
# crew init — 初期設定ウィザード
# 質問に答えるだけで identity.yaml と machines/<hostname>.env を生成する。
# シークレットは非表示入力・chmod 600・書き込み前に git check-ignore で管理外を検証。
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

HOST="$(hostname)"
ENV_FILE="machines/${HOST}.env"
KEYS_ONLY=0
[ "${1:-}" = "--keys-only" ] && KEYS_ONLY=1

OK="\033[32m✔\033[0m"; NG="\033[31m✘\033[0m"

ask() {  # ask <変数名> <質問> <既定値>
  local _var="$1" _q="$2" _def="${3:-}" _in
  if [ -n "$_def" ]; then printf '%s [%s]: ' "$_q" "$_def"; else printf '%s: ' "$_q"; fi
  read -r _in
  eval "$_var=\"\${_in:-\$_def}\""
}

expand_tilde() { echo "${1/#\~/$HOME}"; }

ensure_ignored() {  # 書き込み前検証: git 管理外でなければ中断
  if git rev-parse --git-dir >/dev/null 2>&1; then
    if ! git check-ignore -q "$1"; then
      echo -e "${NG} 中断: $1 が .gitignore の対象になっていません。"
      echo "   このまま書き込むと git に載る恐れがあります。.gitignore を確認してください。"
      exit 1
    fi
  fi
}

test_key() {  # test_key <URL> <ヘッダ(空可)> → 疎通結果表示
  command -v curl >/dev/null 2>&1 || { echo "  (curl なし: 疎通確認スキップ)"; return; }
  local code
  if [ -n "$2" ]; then
    code=$(curl -s -o /dev/null -w '%{http_code}' -H "$2" "$1")
  else
    code=$(curl -s -o /dev/null -w '%{http_code}' "$1")
  fi
  if [ "$code" = "200" ]; then echo -e "  → 疎通確認... ${OK} OK"
  else echo -e "  → 疎通確認... ${NG} NG (HTTP $code) — キーを確認してください"; fi
}

setup_keys() {
  echo ""
  echo "[APIキー・通知先] (空Enterでスキップ。後から crew keys で追加できます)"
  ensure_ignored "$ENV_FILE"
  mkdir -p machines
  touch "$ENV_FILE"; chmod 600 "$ENV_FILE"

  printf 'Gemini API key (非表示入力): '; read -rs GKEY; echo ""
  if [ -n "$GKEY" ]; then
    test_key "https://generativelanguage.googleapis.com/v1beta/models?key=${GKEY}" ""
    grep -q '^GEMINI_API_KEY=' "$ENV_FILE" && sed -i '/^GEMINI_API_KEY=/d' "$ENV_FILE"
    echo "GEMINI_API_KEY=${GKEY}" >> "$ENV_FILE"
  fi

  printf 'OpenAI API key (非表示入力): '; read -rs OKEY; echo ""
  if [ -n "$OKEY" ]; then
    test_key "https://api.openai.com/v1/models" "Authorization: Bearer ${OKEY}"
    grep -q '^OPENAI_API_KEY=' "$ENV_FILE" && sed -i '/^OPENAI_API_KEY=/d' "$ENV_FILE"
    echo "OPENAI_API_KEY=${OKEY}" >> "$ENV_FILE"
  fi

  printf 'Slack Webhook URL (通知用・非表示入力): '; read -rs SURL; echo ""
  if [ -n "$SURL" ]; then
    grep -q '^SLACK_WEBHOOK_URL=' "$ENV_FILE" && sed -i '/^SLACK_WEBHOOK_URL=/d' "$ENV_FILE"
    echo "SLACK_WEBHOOK_URL=${SURL}" >> "$ENV_FILE"
  fi

  printf 'ntfy トピック名 (通知用・推測不可能なランダム名): '; read -r NTOPIC
  if [ -n "$NTOPIC" ]; then
    grep -q '^NTFY_TOPIC=' "$ENV_FILE" && sed -i '/^NTFY_TOPIC=/d' "$ENV_FILE"
    echo "NTFY_TOPIC=${NTOPIC}" >> "$ENV_FILE"
  fi

  chmod 600 "$ENV_FILE"
  echo -e "${OK} ${ENV_FILE} に保存 (git管理外・chmod 600)"
}

if [ "$KEYS_ONLY" = 1 ]; then setup_keys; exit 0; fi

echo "============================================"
echo " crew 初期設定ウィザード"
echo "============================================"

# ---- [0] 環境診断 -------------------------------------------------
echo ""
echo "[0/6] 環境診断"
bash scripts/doctor.sh
HAS_CODEX=0; command -v codex >/dev/null 2>&1 && HAS_CODEX=1

# ---- [0.5] クルー編成 ---------------------------------------------
DEF_CODER=sonnet; DEF_QCT=sonnet
if [ "$HAS_CODEX" = 1 ]; then DEF_CODER=codex; DEF_QCT=cross; fi
R_GM=fable; R_CODER=$DEF_CODER; R_RESEARCH=sonnet; R_CHORE=haiku; R_QCT=$DEF_QCT; R_QCF=opus

echo ""
echo "[0.5/6] クルー編成(検出結果からの推奨)"
printf '  gm(窓口・設計):   %s\n  coder(実装):      %s\n  research(調査):   %s\n  chore(雑務):      %s\n  qc_tech(技術検品): %s\n  qc_final(納品検品): %s\n' \
  "$R_GM" "$R_CODER" "$R_RESEARCH" "$R_CHORE" "$R_QCT" "$R_QCF"
ask EDIT "このままでよいですか?" "Y"
if [ "${EDIT^^}" != "Y" ]; then
  ask R_GM       "  gm"       "$R_GM"
  ask R_CODER    "  coder"    "$R_CODER"
  ask R_RESEARCH "  research" "$R_RESEARCH"
  ask R_CHORE    "  chore"    "$R_CHORE"
  ask R_QCT      "  qc_tech"  "$R_QCT"
  ask R_QCF      "  qc_final" "$R_QCF"
fi

# ---- [1-3] 身元 ----------------------------------------------------
echo ""
ask NAME    "[1/6] あなたの名前は?" "$(whoami)"
ask ADDRESS "[2/6] クルーからの呼ばれ方は? (例: 殿 / ボス / ${NAME}さん)" "殿"
ask ORG     "[3/6] この環境の役割は? (例: 個人事業の屋号/会社名)" ""
echo "  前提・注意事項があれば入力 (複数行可、空行で終了):"
CONTEXT=""
while IFS= read -r line; do
  [ -z "$line" ] && break
  CONTEXT="${CONTEXT}${line}"$'\n'
done
[ -z "$CONTEXT" ] && CONTEXT="(特記事項なし)"$'\n'

# ---- [4] フォルダ --------------------------------------------------
echo ""
echo "[4/6] フォルダ設定 (Enterで既定値。存在しなければ作成します)"
ask P_OUTBOX "  成果物レビュー用" "~/crew-out/review"
ask P_SHOTS  "  スクリーンショット" "~/crew-out/shots"
ask P_WS     "  開発サンドボックス" "~/dev/sandbox"
ask P_READ   "  読み取り許可フォルダ(カンマ区切り)" "~/dev"
mkdir -p "$(expand_tilde "$P_OUTBOX")" "$(expand_tilde "$P_SHOTS")" "$(expand_tilde "$P_WS")"

# ---- [5] テーマ ----------------------------------------------------
echo ""
THEMES=$(ls -d themes/*/ 2>/dev/null | sed 's|themes/||; s|/||' | tr '\n' ' ')
ask THEME "[5/6] テーマ (${THEMES}) ※crew=Among Us風味+スピナー文言" "crew"
[ -d "themes/${THEME}" ] || { echo "  themes/${THEME} がないため plain にします"; THEME=plain; }
WF_DEF=none; [ "$THEME" = crew ] && WF_DEF=crew
ask WFLAVOR "  worker の演出 (none=素 / crew=報告冒頭1行だけ色クルーの一言)" "$WF_DEF"
case "$WFLAVOR" in crew|none) ;; *) WFLAVOR=none ;; esac
CODEX_MODEL=""
if [ "$HAS_CODEX" = 1 ]; then
  ask CODEX_MODEL "  Codex 呼び出し時のモデル (空=~/.codex/config.toml の既定)" ""
fi

# ---- identity.yaml 書き出し ---------------------------------------
ensure_ignored identity.yaml
{
  echo "operator:"
  echo "  name: ${NAME}"
  echo "  address_as: ${ADDRESS}"
  echo "  org: \"${ORG}\""
  echo "context: |"
  printf '%s' "$CONTEXT" | sed 's/^/  /'
  echo "paths:"
  echo "  outbox: ${P_OUTBOX}"
  echo "  screenshots: ${P_SHOTS}"
  echo "  workspace: ${P_WS}"
  echo "  readable:"
  echo "$P_READ" | tr ',' '\n' | sed 's/^ *//; s/ *$//; /^$/d; s/^/    - /'
  echo "theme: ${THEME}"
  echo "worker_flavor: ${WFLAVOR}"
  echo "roster:"
  echo "  gm: ${R_GM}"
  echo "  coder: ${R_CODER}"
  echo "  research: ${R_RESEARCH}"
  echo "  chore: ${R_CHORE}"
  echo "  qc_tech: ${R_QCT}"
  echo "  qc_final: ${R_QCF}"
  echo "codex:"
  echo "  model: \"${CODEX_MODEL}\""
  echo "video:"
  echo "  voicevox: false"
  echo "notify:"
  echo "  enabled: false"
} > identity.yaml
echo -e "${OK} identity.yaml を生成 (git管理外を検証済み)"

# ---- [6] キー ------------------------------------------------------
echo ""
echo "[6/6] APIキー・通知先"
setup_keys

# ---- 仕上げ --------------------------------------------------------
python3 scripts/gen_settings.py && echo -e "${OK} .claude/settings.local.json を生成"
echo ""
echo "============================================"
echo -e " ${OK} 出陣準備完了。 ./bin/crew up でGMクルーが起動します。"
echo "============================================"
