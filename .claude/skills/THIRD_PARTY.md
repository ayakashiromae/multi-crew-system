# 外部由来スキル

| スキル | 出所 | 取り込み日 | ライセンス |
|---|---|---|---|
| customer-research / competitor-profiling / competitors / content-strategy / pricing / offers / copywriting / marketing-ideas | https://github.com/coreyhaines31/marketingskills (commit e55de886fe75) | 2026-08-30 | THIRD_PARTY-marketingskills-LICENSE 参照 |

用途: note 等の有料コンテンツ企画の前段(読者の悩み抽出・競合/価格帯調査・テーマ選定・オファー設計)。
検品: Markdown のみ(スクリプト・外部通信・インストール手順なし)を確認済み。更新は上流を再取得して差し替える(改変しない)。
| sfx-hunt | 内製(殿+チャット側クルー作、本文貼り付けで受領。frontmatter は GM が整形) | 2026-09-02 | 内製(LICENSE 同梱) | vet.sh PASS |
| natural-japanese | https://github.com/coji/natural-japanese (commit 9a78a42964096da509b8f3e011f0085a5f080151, 2026-09-04時点) | 2026-09-13 | MIT。THIRD_PARTY-natural-japanese-LICENSE 参照 |

用途: 仕事の日本語文書(議事録・報告書・マニュアル・note等)の「AI臭さ」除去・読みやすさ改善。lint.py が禁止語・翻訳調・文長リズム・体言止め欠如などを機械的に検出し、直すかどうかはAIが文脈判断する2段構成。
検品: vet.sh PASS(WARN=実行スクリプトあり、目視で内容確認済み)。scripts/*.py は標準ライブラリ+sudachipy/sudachidict-core(形態素解析)のみで、外部通信・秘密要求・インジェクション定型句・sudo/rm等の危険コマンドなし。README内のURL2件(note.com, hyuki.com)は参考文献の出典表記のみで実行対象ではない。ライセンス MIT、コピーのみで無改変。
注意: 拠点に `uv` が無いため `uv run scripts/lint.py ...` はそのまま動かない。venv 代替: `/home/shiromae/dev/sandbox/natural-japanese-venv`(pip install sudachipy sudachidict-core 済み)の python で `scripts/lint.py --json <file>` を直接実行する。SKILL.md のフルモードは判断台帳の統合を「並列のサブエージェント」に割り振る設計だが、この拠点では孫エージェント起動禁止のためクルー単独では使えない(GMがクイックモードのみで運用するか、フルモードのレビュー3点をGM自身が直列で行う)。
