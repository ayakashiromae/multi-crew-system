#!/usr/bin/env bash
# skill-scout: 導入候補スキルディレクトリの機械検品。
# 使い方: bash vet.sh <skill-dir> [<skill-dir> ...]
# 終了コード: 0=NG なし(WARN はあり得る) / 1=NG あり / 2=使い方エラー
set -u
[[ $# -ge 1 ]] || { echo "usage: vet.sh <skill-dir> [...]" >&2; exit 2; }
overall=0
for dir in "$@"; do
  ng=0; warn=0
  echo "== $dir"
  if [[ ! -f "$dir/SKILL.md" ]]; then echo "  NG  SKILL.md がない(大文字小文字も確認)"; ng=1; overall=1; echo; continue; fi
  # フロントマター
  fm=$(awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1{print}' "$dir/SKILL.md")
  name=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)
  [[ -n "$fm" ]] || { echo "  NG  frontmatter がない"; ng=1; }
  printf '%s\n' "$fm" | grep -q '^description:' || { echo "  NG  description がない"; ng=1; }
  printf '%s\n' "$fm" | grep -q '[<>]' && { echo "  NG  frontmatter に < > がある(インジェクション疑い)"; ng=1; }
  [[ "$name" =~ [Cc]laude|[Aa]nthropic ]] && { echo "  NG  name に予約語(claude/anthropic)"; ng=1; }
  [[ -n "$name" && ! "$name" =~ ^[a-z0-9-]+$ ]] && { echo "  WARN name が kebab-case でない: $name"; warn=1; }
  # 構成
  [[ -f "$dir/README.md" ]] && { echo "  WARN スキルフォルダ内に README.md(仕様上は非推奨。害はない)"; warn=1; }
  words=$(wc -w < "$dir/SKILL.md"); [[ "$words" -gt 5000 ]] && { echo "  WARN SKILL.md が ${words} 語(5,000 語超)"; warn=1; }
  # 実行物
  execs=$(find "$dir" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.mjs' -o -name '*.ts' -o -name '*.rb' -o -perm -u+x \) | grep -v '/SKILL.md$' || true)
  if [[ -n "$execs" ]]; then echo "  WARN 実行スクリプトあり(中身を読むこと):"; printf '%s\n' "$execs" | sed 's/^/       /'; warn=1; fi
  # 危険コマンド・外部送信・秘密
  grep -rnE --exclude=vet.sh 'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "$dir" && { echo "  NG  リモート取得スクリプトのパイプ実行"; ng=1; }
  grep -rnE --exclude=vet.sh '\bsudo\b|rm -rf /|git push --force|mkfs|dd if=' "$dir" | grep -v 'Do NOT\|しない\|禁止' && { echo "  WARN 破壊的/特権コマンドへの言及(文脈を読むこと)"; warn=1; }
  grep -rniE --exclude=vet.sh '(api[_-]?key|secret|token|password)[^\n]{0,40}(paste|貼|provide|enter|入力|export |echo )' "$dir" && { echo "  WARN 秘密の入力/表示を求める文(文脈を読むこと)"; warn=1; }
  grep -rniE --exclude=vet.sh 'ignore (all )?(previous|prior) instructions|以前の指示を無視|system prompt' "$dir" && { echo "  NG  インジェクション定型句"; ng=1; }
  grep -rnoE 'https?://[^ )"'"'"'>]+' "$dir" | grep -vE 'example\.com|competitor[0-9]|localhost|github\.com|anthropic\.com|claude\.(ai|com)' | awk -F: '{print $3":"$4}' | sort -u | head -20 | sed 's/^/  URL  /'
  # ライセンス(スキル dir またはその親 2 階層)
  lic=""; for p in "$dir" "$dir/.." "$dir/../.."; do for f in LICENSE LICENSE.md LICENSE.txt; do [[ -f "$p/$f" ]] && { lic="$p/$f"; break 2; }; done; done
  # 導入済み(.claude/skills 配下)は THIRD_PARTY-<repo>-LICENSE を同梱している
  [[ -z "$lic" ]] && for f in "$dir"/../THIRD_PARTY-*LICENSE*; do [[ -f "$f" ]] && { lic="$f"; break; }; done
  if [[ -n "$lic" ]]; then echo "  OK   ライセンス: $(head -1 "$lic" | cut -c1-60) ($lic)"; else echo "  NG  LICENSE が見つからない"; ng=1; fi
  echo "  RESULT: $([[ $ng -eq 0 ]] && echo PASS || echo FAIL) (warn=$warn)"; echo
  [[ $ng -eq 0 ]] || overall=1
done
exit $overall
