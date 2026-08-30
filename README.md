# multi-crew-system — 真マルチクルー環境

Claude Code のネイティブ機能(サブエージェント / スキル / hooks)の上に、
**「自分仕様」を1枚のファイルで着せ替えられる**マルチエージェント環境を作るテンプレート。

かつて tmux + YAML + inotifywait で自作されていたオーケストレーション配管
([multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) 系)は、いまや Claude Code 本体に標準搭載された。
このリポジトリが提供するのは配管ではなく、その上に載る4つのものだけ:

1. **identity 層** — 「誰のクルーとして・どんな前提で・どこを触ってよいか」を定義する1ファイル(git管理外)
2. **運用プロトコル** — 聞き取り→起票→分配→検品→納品のフローと、トークンを守る雇用規則(CLAUDE.md)
3. **教育の型** — オペレーターの却下を記録し、週次で判断原則へ昇格させる仕組み(影武者方式)。
   旧環境で裁定済みの規律20件を初期原則として同梱
4. **クルー文化** — 旧環境の Among Us 風ペルソナ(GM🛸 / PM🚀 / QM🔍🟣 / 色クルー🔴🔵🟢)、用語集、
   進行中表示のスピナー文言183本を `themes/crew` に移植

## はじめかた(GitHub からダウンロード → 起動まで)

### 0. 前提

- Windows なら WSL2(Ubuntu)を入れておく。以降のコマンドは **WSL のターミナル**で打つ
- Claude Code がインストール・ログイン済みであること(`claude --version` が通る)
- git / python3 / tmux があること(無ければ後述の `crew doctor` が入れてくれる)

### 1. ダウンロードして配置する

配置先は固定で `~/projects/multi-crew-system`。どちらかの方法で。

**A) git で取得(おすすめ。`crew up` のたびに origin を確認し、更新があれば取り込んで内容を表示。未 push のコミットがあれば push する — `CREW_AUTO_PUSH=0 crew up` で抑止。force は使わない)**

```bash
mkdir -p ~/projects
git clone https://github.com/ayakashiromae/multi-crew-system.git ~/projects/multi-crew-system
```

**B) GitHub の「Code → Download ZIP」で取得**

1. zip を展開する(Windows なら `C:\Users\<名前>\Downloads\multi-crew-system` など)
2. WSL から `install.sh` を実行すると、固定の配置先へコピーして自己診断まで走る:

```bash
bash /mnt/c/Users/<名前>/Downloads/multi-crew-system/install.sh
```

配置後は Windows 側から `\\wsl.localhost\Ubuntu-24.04\home\<ユーザー名>\projects\multi-crew-system` で中身を見られる
(ディストリ名は `wsl -l` で確認)。

**配置したら、`crew` コマンドを PATH に通す(1回だけ)。** これで**どのフォルダにいても** `crew up` と打てる:

```bash
echo 'export PATH="$HOME/projects/multi-crew-system/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
crew help    # ← 表示されれば OK
```

> PATH を通さない場合は、以降の `crew ○○` を `~/projects/multi-crew-system/bin/crew ○○` と読み替える
> (フルパスで呼べば、どのフォルダからでも動く。`./bin/crew` は配置先フォルダの中でしか動かないので注意)。

### 2. 環境診断(任意だが初回は推奨)

```bash
crew doctor
```

足りないもの(tmux / PyYAML / Codex CLI など)を検出し、その場でインストールを提案する。
Codex CLI を入れた場合は `codex login` でブラウザ認証を済ませておく(実装を Codex に委譲する編成のため)。

### 3. 起動する

```bash
crew up
```

初回はウィザードが走る。質問と答え方:

| 質問 | 答え方 |
|---|---|
| クルー編成 | 検出結果から推奨が出る。そのまま `Y` でよい |
| あなたの名前 / 呼ばれ方 | 呼ばれ方の既定は「殿」。好みで変える |
| この環境の役割・前提 | 「個人開発用」「会社の情報は扱わない」など。空行で終了 |
| フォルダ | 成果物置き場 / スクショ / 作業場 / 読み取り許可。Enter で既定値、無ければ作成される |
| テーマ | `crew`(Among Us 風味+スピナー文言)か `plain`(素) |
| worker の演出 | `crew` なら各クルーが報告の冒頭1行だけ一言添える |
| APIキー・通知先 | 空 Enter でスキップ可。後から `crew keys` で追加できる |

回答は `identity.yaml`(git 管理外)に保存され、`crew init` でいつでも作り直せる。
ウィザードが終わると tmux の中で GMクルー(Claude Code)が立ち上がる。

**初回起動時に出る確認画面**

```
New MCP server found in this project: codex
  Use this MCP server
❯ Use this and all future MCP servers in this project
  Continue without using this MCP server
```

これは `.mcp.json` に定義した **Codex MCP サーバー**(coder クルーが実装を Codex に委譲するための接続)を
使うかの確認。想定どおりの表示なので **「Use this MCP server」を選んで Enter**。

| 選択肢 | 意味 |
|---|---|
| Use this MCP server | codex だけ許可(推奨。git pull で同期する運用では1本ずつ確認する方が安全) |
| Use this and all future MCP servers… | 今後 `.mcp.json` に増えたサーバーも無確認で許可 |
| Continue without using this MCP server | Codex 委譲なし。coder クルーが Claude 側で直接実装するフォールバックになる(動くが Claude の使用量を食う) |

Codex 側でログインしていないと委譲が失敗する。その場合はいったん抜けて(`Ctrl+b → d` または `/exit`)、
WSL で `codex login` を済ませてから `crew up` し直す。

あとは普通に話しかけるだけ。

### 4. 日常の操作(どのフォルダからでも可)

```bash
crew up       # 出陣(2回目以降はウィザード無しで即起動)
Ctrl+b → d    # デタッチ(抜けてもクルーは生きている)
crew gm       # 再接続
crew dash     # ダッシュボード(http://localhost:7777)を開く
crew decide   # 判断待ちの一覧
crew test     # 自己診断(設定生成・secret guard・git 管理外チェック)
crew down     # 完全終了
```

### 5. うまくいかないとき

| 症状 | 見るところ |
|---|---|
| `identity.yaml が見つかりません` | `crew init` を実行 |
| GM が環境定義を読めないと言う | `python3 ~/projects/multi-crew-system/scripts/gen_settings.py` を手で実行して `state/identity_context.md` ができるか確認 |
| Codex に委譲されない | `codex login` 済みか、`.mcp.json` の `codex mcp-server` が手元の Codex CLI で動くか(`codex mcp-server --help`) |
| hooks を変えたのに効かない | Claude Code を再起動(`crew down` → `crew up`) |
| `crew: command not found` | PATH が通っていない。上記 1. の `echo … >> ~/.bashrc && source ~/.bashrc` を実行するか、`~/projects/multi-crew-system/bin/crew up` とフルパスで打つ |
| `./bin/crew: No such file or directory` | 配置先フォルダの外で `./bin/crew` と打っている。`crew up`(PATH 設定済み)か `~/projects/multi-crew-system/bin/crew up` にする |
| その他 | `crew test` の ✘ を読む |

## コマンド一覧

`crew` は PATH を通せばどこからでも、通さなければ `~/projects/multi-crew-system/bin/crew` で呼ぶ。

```
crew up       出陣(同期 → 初回はウィザード → サービス起動 → GMクルー起動)
crew gm       GMセッションに再接続
crew dash     ダッシュボードを開く (http://localhost:7777)。WSL2 では Windows の既定ブラウザが立ち上がる
crew dash restart  ダッシュボードのサーバーを再起動してから開く(dashboard/ を更新したとき)
crew down     完全終了
crew init     初期設定ウィザードを(再)実行
crew doctor   環境診断(Codex CLI等の検出・インストール)
crew keys     APIキー・通知先の追加/差し替え
crew sync     スキル・規約の同期 (git pull)
crew test     自己診断(設定生成・secret guard・git管理外チェックを1コマンドで)
crew decide   判断待ち台帳(list / add "<内容>" / done <id>)
デタッチ:      Ctrl+b → d
```

必須: Claude Code / git / python3(+PyYAML) / tmux。任意: Codex CLI(実装委譲)、jq、Docker(VOICEVOX)、ffmpeg。
`crew doctor` が検出し、足りないものはその場でインストールを提案する。

## 設計思想

**常時軍団ではなく、都度雇用+外部委譲。** 9体のエージェントを常駐させる方式は、待機コンテキストの分だけ
使用量を食う。ここでは GM(メインセッション)だけが常駐し、タスク分解して並列化が割に合うときだけ
クルーを雇用する。コード量産は Codex(MCP経由)へ委譲し、Claude 側の使用量を温存する。
旧環境の将軍(統括)と家老(采配)は GM 一人が兼務し、軍師(品質)は qc-tech / qc-final、足軽は coder / research / chore に対応する。

**会話は越境させず、学習の成果だけ共有する。** 会話ログ・却下ログ・判断待ち台帳・ダッシュボードの実行時データは
すべて各PCローカル(`state/`, `logs/` は git 管理外)。共有されるのはスキル・規約・昇格済みの判断原則だけ。

**編成は環境が決める。** どのAIをどの役割に使うか(roster)は identity.yaml 側。Codex がない環境では
自動でフォールバックする。推奨編成: gm=fable / coder=codex / research=sonnet / chore=haiku /
qc_tech=cross(異種クロスレビュー) / qc_final=opus。

**規律は仕組みで塞ぐ。** 秘密の表示・破壊的操作は規約(CLAUDE.md)に書くだけでなく、
`.claude/settings.json` の deny と PreToolUse hook(`scripts/secret_guard_hook.sh`)で機械的にブロックする。

## ディレクトリ構成

```
├── bin/crew                 ランチャー
├── install.sh               ~/projects/multi-crew-system への配置 + 自己診断
├── CLAUDE.md                GMクルーの運用プロトコル(雇用規則・検品規則・安全規則・秘匿規則)
├── AGENTS.md                Codex(MCP)側に読ませる規約
├── .claude/
│   ├── agents/              クルー定義(coder🔴 / research🔵 / chore🟢 / qc-tech🔍 / qc-final🟣)
│   ├── skills/              共通スキル(operator-principles: 初期原則20件 / distill-rejections)
│   └── settings.json        deny(秘密・破壊的操作) + hooks(secret guard / ダッシュボード送信)
├── .mcp.json                MCP定義(codex)
├── themes/                  着せ替え(plain=素 / crew=Among Us風味) ※persona/glossary は GM のみに適用
│   └── crew/spinner_verbs.json  進行中表示の文言(「メドベイでスキャン中」等183本)
├── dashboard/               ローカルダッシュボード(イベント流し + 🚨判断待ち)
├── tools/                   notify.sh(Slack/ntfy通知) / decision.sh(判断待ち台帳)
├── scripts/                 init ウィザード・doctor・設定生成・secret guard・selftest
├── identity.example.yaml    ← これをコピーせず crew up で対話生成するのが楽
└── machines/                拠点ごとのシークレット(.env は git 管理外)
```

git 管理外(=自分仕様・拠点ローカル): `identity.yaml` / `machines/*.env` / `state/` / `logs/` /
`.claude/settings.local.json`(identity から自動生成)。

## テーマ(クルーナイズド)

`themes/<name>/` の `persona.md` + `glossary.md` + `vocabulary.yaml` + `spinner_verbs.json` で
GM の口調・用語・進行中表示を着せ替えられる。

| identity の設定 | 効果 |
|---|---|
| `theme: crew` | GM が GMクルー🛸(一人称「私」、殿呼び、Among Us 用語を要所で)。スピナー文言も置換 |
| `theme: plain` | 素の Claude |
| `worker_flavor: crew` | 各クルーが報告の**冒頭1行だけ**に色クルー/QMクルーの一言を乗せる(環境変数経由。コードには混ざらない) |
| `worker_flavor: none` | worker は素の口調 |

ディレクトリをコピーして書き換えれば、戦国でも執事でも自作テーマを追加できる。
persona/glossary の適用は GM のみで、worker には配布されない(トークン節約と検品品質のため)。

## セキュリティ

- ウィザードはシークレット書き込み前に `git check-ignore` で**管理外であることを検証**してから書く
- キー入力は非表示(read -s)、保存先は chmod 600、ログ・identity.yaml には書かない
- `.claude/settings.json` が `.env` / `machines/` の読み取りと、`rm -rf /`・`sudo`・`kill`・`git push --force`・
  `git reset --hard`・`docker compose config` 等を deny
- PreToolUse hook(secret guard)が `cat .env` / `docker compose config` / `printenv` / `echo "$API_KEY"` / 秘密ファイルの Read をブロック
  (fail-open: hook 自身が壊れても全クルーを止めない。規約が第一防御、hook は補助網)
- クルーの読み書き範囲は identity の paths(readable / workspace / outbox)が許可した場所のみ
- 外部AIへ渡すコンテキストは最小限にする規約を CLAUDE.md に明文化

## 謝辞

- [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) — 階層指揮・ファイルベース通信・ダッシュボードという原型
- [影武者/kagemusha](https://zenn.dev/shio_shoppaize/articles/kagemusha-shogun-disband) — 「却下の蓄積だけは誰も出荷できない」という教育の型

## License

MIT
