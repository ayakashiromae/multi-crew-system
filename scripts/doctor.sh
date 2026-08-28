#!/usr/bin/env bash
# crew doctor — 環境診断。CLI・依存の検出と(確認の上での)インストール
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OK="\033[32m✔\033[0m"; NG="\033[31m✘\033[0m"
INTERACTIVE=1; [ -t 0 ] || INTERACTIVE=0

confirm() {  # confirm "<質問>" → 0=yes
  [ "$INTERACTIVE" = 1 ] || return 1
  printf '  → %s [Y/n] ' "$1"; read -r a
  case "${a:-Y}" in [Yy]*|"") return 0 ;; *) return 1 ;; esac
}

check() {  # check <cmd> <表示名>
  if command -v "$1" >/dev/null 2>&1; then
    printf "  %-14s ${OK} %s\n" "$2" "$(command -v "$1")"
    return 0
  else
    printf "  %-14s ${NG} 未インストール\n" "$2"
    return 1
  fi
}

offer_install() {  # offer_install <表示名> <コマンド文字列>
  if confirm "インストールしますか? 実行: $2"; then
    echo "  実行中: $2"
    bash -c "$2" && echo -e "  ${OK} 完了" || echo -e "  ${NG} 失敗(手動で実行してください: $2)"
  fi
}

echo "[crew doctor] 環境診断"
echo "--- 必須 ---"
check claude "claude CLI" || echo "    Claude Code が必要です: https://docs.claude.com/ja/docs/claude-code"
check git    "git"        || offer_install git "sudo apt-get install -y git"
check python3 "python3"   || offer_install python3 "sudo apt-get install -y python3"
if python3 -c 'import yaml' 2>/dev/null; then
  printf "  %-14s ${OK} PyYAML\n" "python3-yaml"
else
  printf "  %-14s ${NG} PyYAML なし\n" "python3-yaml"
  offer_install PyYAML "pip3 install --user pyyaml || pip3 install --break-system-packages pyyaml"
fi
check tmux   "tmux"       || offer_install tmux "sudo apt-get install -y tmux"
check jq     "jq"         || echo "    (任意) secret guard の JSON 解析に使用。無くても sed で代替"

echo "--- クルー候補(任意) ---"
if ! check codex "codex CLI"; then
  if command -v npm >/dev/null 2>&1; then
    offer_install "Codex CLI" "npm install -g @openai/codex"
    command -v codex >/dev/null 2>&1 && echo "    ※ 初回は 'codex login' でブラウザ認証が必要です"
  else
    echo "    npm がないため自動インストール不可(Node.js を導入後に npm install -g @openai/codex)"
  fi
fi

echo "--- 動画工房(任意) ---"
check docker "docker" || echo "    VOICEVOX を使う場合は Docker が必要"
check ffmpeg "ffmpeg" || offer_install ffmpeg "sudo apt-get install -y ffmpeg"

echo "--- 検出サマリ ---"
HAS_CODEX=0; command -v codex >/dev/null 2>&1 && HAS_CODEX=1
echo "  codex=${HAS_CODEX}"
# init_wizard から source された場合に備えて export
export CREW_HAS_CODEX="$HAS_CODEX"
