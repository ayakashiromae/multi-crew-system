# 設計メモ

## 3層モデル

| 層 | 置き場 | 共有範囲 |
|---|---|---|
| プロダクト本体(配管の上物) | git | 全拠点・公開 |
| 自分仕様(identity / シークレット) | git管理外 | その拠点のみ |
| 実行時データ(state / logs) | git管理外 | その拠点のみ |

配管そのもの(spawn・エージェント間通信・タスク管理)は Claude Code ネイティブ機能を使い、自作しない。

## フロー

```
オペレーター
  → GM: 聞き取り
  → GM: 起票ゲート(タスク分解一覧を提示 = 取りこぼし検出点)
  → GM: roster に従い雇用・分配(小タスクはチームを組まない)
  → worker: 作業(成果物はファイル渡し・報告は要約のみ)
  → 機械検査(lint/テスト: トークンゼロ)
  → qc-tech: 異種クロスレビュー(Codex製→Claudeが検品、Claude製→Codexが検品)
  → qc-final: operator-principles による「オペレーターなら通すか」判定
  → GM: outbox へ納品・要約報告
```

## トークン設計

- 生成の重い工程(コード)は Codex へ委譲(Claude枠の外)
- worker は sonnet/haiku、最上位モデルは GM(発話少・判断重要)と qc-final のみ
- 常駐ゼロ: 雇用は必要時のみ。待機コンテキストを持たない
- 報告は要約のみ・成果物はファイル経由(shogun のファイルベース通信思想の部分的継承)

## 教育(影武者方式)

却下ログ(logs/reject.jsonl・拠点ローカル)→ 週次で distill-rejections → オペレーター承認 →
operator-principles(git共有)へ汎用化して昇格。会話は越境させず、学習の成果だけを共有する。

## 2拠点運用

会話ログは Claude Code の仕様上そもそもローカル保存で同期されない。よって「ログを分ける」は
デフォルトで満たされ、「スキル・規約・原則を揃える」を git pull(crew up 時に自動)が担う。
ダッシュボードも表示定義のみ共通、データ(state/events.jsonl)は拠点別。

## 既知の注意点

- `codex mcp-server` のサブコマンド名は Codex CLI のバージョンで変わることがある
  (`codex mcp serve` 等)。動かない場合は `.mcp.json` を調整する。
- Agent Teams は雑に使うと使用量を大量に消費する。CLAUDE.md の雇用規則
  (小タスクにチームを組まない・報告は要約のみ)が防波堤。
- hooks の設定(settings.json)を変更した場合は Claude Code の再起動が必要。

## 旧環境(multi-agent-crew)からの移植対応表(2026-08-28)

| 旧環境 | 本環境 | 備考 |
|---|---|---|
| 将軍(GMクルー🛸)+家老(PMクルー🚀) | GM(メインセッション) | 統括と采配を一人で担う。`themes/crew/persona.md` |
| 軍師(QMクルー🩵⚫) | qc-tech / qc-final | 敵対的レビュー+判断原則による納品検品 |
| 足軽1-7(色クルー🔴🔵🟢) | coder🔴 / research🔵 / chore🟢 | `worker_flavor: crew` で報告冒頭1行のみ演出 |
| among_us_glossary.md | themes/crew/glossary.md | 役職の写像を追記 |
| settings.json spinnerVerbs(183本) | themes/crew/spinner_verbs.json | gen_settings が settings.local.json へ注入 |
| CLAUDE.md の殿裁定・将軍裁定群 | operator-principles 初期原則20件 | 固有名詞を除去して汎用化 |
| Destructive Operation Safety Tier1-3 | CLAUDE.md 安全規則 + settings.json deny | 縮約 |
| secret_guard_hook.sh / sudo_guard_hook.sh | scripts/secret_guard_hook.sh + deny | sudo は deny で代替(hook 不要) |
| dashboard.md 🚨要対応 / 殿判断待ち | tools/decision.sh + ダッシュボード判断待ちパネル | 非ブロッキング運用 |
| inbox/YAML/inotifywait 配管 | (廃止) | Claude Code ネイティブのサブエージェントで代替 |
| capability_tiers(Bloom ルーティング) | (廃止・roster のみ) | 常駐なし・都度雇用のため不要。codex.model で Codex 側モデルだけ指定可 |
