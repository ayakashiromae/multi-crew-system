# machines/

拠点(マシン)ごとのシークレット置き場。`<hostname>.env` というファイル名で置くと、
`crew up` が自動で読み込む。**このディレクトリの .env は .gitignore 済み**で、
`crew init` は書き込み前に `git check-ignore` で管理外であることを検証する。

```bash
# 例: machines/home-pc.env  (chmod 600)
GEMINI_API_KEY=...
OPENAI_API_KEY=...

# 通知(任意。identity.yaml の notify.enabled: true で使用)
SLACK_WEBHOOK_URL=...
NTFY_TOPIC=...          # 推測不可能なランダム名にすること(トピック名=パスワード)
```

キーの追加・差し替えは `crew keys` で対話的に行える。
