#!/usr/bin/env bash
# install.sh — WSL/Linux に multi-crew-system を配置する
#   固定の配置先: ~/projects/multi-crew-system
#   (Windows からは \\wsl.localhost\<ディストリ名>\home\<ユーザー名>\projects\multi-crew-system)
#
# 使い方:
#   既にこのリポジトリを clone/展開済みのディレクトリで:  ./install.sh
#   別の場所から:  bash /path/to/install.sh   (そのディレクトリを配置先へコピー)
#   リモートから:  git clone <repo> ~/projects/multi-crew-system && cd ~/projects/multi-crew-system && ./bin/crew up
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DST="${CREW_HOME:-$HOME/projects/multi-crew-system}"
log(){ printf '\033[36m[install]\033[0m %s\n' "$*"; }

if [ "$SRC" = "$DST" ]; then
  log "既に配置先にいます: $DST"
else
  if [ -e "$DST" ]; then
    echo "配置先が既に存在します: $DST"
    printf '上書き同期しますか? (identity.yaml / machines / state / logs は保持) [y/N] '; read -r a
    case "$a" in [Yy]*) ;; *) echo "中止"; exit 1 ;; esac
  fi
  mkdir -p "$(dirname "$DST")"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude '.git' --exclude 'identity.yaml' --exclude 'machines/*.env' \
      --exclude 'state' --exclude 'logs' --exclude '.claude/settings.local.json' --exclude '__pycache__' \
      "$SRC/" "$DST/"
  else
    mkdir -p "$DST" && cp -a "$SRC"/. "$DST"/ && rm -rf "$DST/__pycache__"
  fi
  log "配置完了: $DST"
fi
cd "$DST"
chmod +x bin/crew scripts/*.sh tools/*.sh install.sh 2>/dev/null
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init -q && git add -A && git -c user.name=crew -c user.email=crew@localhost commit -qm "init: multi-crew-system" \
    && log "git 初期化(拠点ローカル物は .gitignore 済み)"
fi
if [ -n "${WSL_DISTRO_NAME:-}" ]; then
  log "Windows からのパス: \\\\wsl.localhost\\${WSL_DISTRO_NAME}\\home\\$(whoami)\\projects\\multi-crew-system"
fi
bash scripts/selftest.sh || { echo "自己診断に失敗。上の ✘ を確認してください。"; exit 1; }
echo ""
log "次: cd $DST && ./bin/crew up   (初回はウィザードが identity.yaml を作ります)"
