---
name: imagegen-style
description: |
  Codex の imagegen(built-in image_gen、モデル gpt-image-2)でイラスト・挿絵を生成する際、
  「AIっぽさ」を消す画風プロンプトの型を提供する。日本語で描きたい内容を書き、英語の STYLE
  ブロックで画風を指定し、AVOID ブロックで生成AIが出しがちな特徴を先制的に禁止する手法
  (出典: Qiita記事、詳細は references/source.md)。画風テンプレート38種と、この拠点の既定3種
  (いらすとや風フラット/解説動画の図解向け/サムネ向け)を収録。透過PNGが要る場合のクロマキー
  (#FF00FF)指定と除去スクリプトの使い方も含む。
  「画像生成」「挿絵を生成」「imagegen」「AIっぽさ」「画風」と言われた時に起動。
  Do NOT use for: いらすとや等の既存フリー素材の検索・流用(sfx-hunt を使え)。動画編集・
  演出の指示(kirinuki-direction 等を使え)。
---

# imagegen-style — 画像生成の「AIっぽさ」を消す画風プロンプト

作成日: 2026-09-10。出典: [references/source.md](./references/source.md)(Qiita記事、
著者 前田悟志 @maeda-niku18、投稿日 2026-09-07)。

## 使い方(依頼文の型)

Codex(MCP)へ imagegen を依頼するときは、次の順で1つのプロンプトにまとめる。

```
<日本語で描きたい内容(被写体・構図・用途を具体的に)>

STYLE:
<英語の画風ブロック(下記テンプレートから選ぶ、または組み合わせる)>

AVOID:
<英語の禁止ブロック(下記「追加ブロック」から必要な物を選ぶ)>
```

- 内容は日本語、画風指定(STYLE/AVOID)は英語、の組み合わせが最も安定する(記事の結論)。
- 「hand-drawn」など単語1つだけでは弱い。「slightly irregular」「uneven line pressure」
  「intentional asymmetry」のように**不完全さを具体的に名指し**する。
- 色数は「a few colors」のような曖昧表現でなく、**数字で制限**する
  (例: `three-to-five-color palette`)。放置すると色と物が際限なく増える。
- AVOID ブロックは「〜しないで」ではなく、AIが出しがちな具体的特徴を列挙する
  (例: `glossy gradients`, `perfectly symmetrical faces`)。

### Codex への委譲(coder クルー経由)

coder クルーが Codex MCP(`mcp__codex__codex`)に委譲する際、上記の型で組み立てたプロンプトを
そのまま渡し、「built-in image_gen ツール(model: gpt-image-2)を使って `<出力パス>` に保存せよ」
と明記する。`approval-policy: "never"` / `sandbox: "workspace-write"` は coder の既定方針に従う。

### 透過PNGが必要な場合(chroma-key)

gpt-image-2 は透過PNGを直接出力できない。透過が必要なときは:

1. STYLE/AVOID ブロックに背景指定を追加する: `solid magenta background, flat uniform
   color #FF00FF, no gradient, no texture, no shadow on background`
2. 生成後、`scripts/remove_chroma_key.py` でマゼンタ(#FF00FF)を透明化する。

```
python3 /home/shiromae/projects/multi-crew-system/.claude/skills/imagegen-style/scripts/remove_chroma_key.py \
  <input.png> <output.png> --color FF00FF --tolerance 40
```

被写体自体にマゼンタに近い色(ピンク系の服・肌など)が含まれる場合は誤消去が起きるので、
生成前にAVOIDへ `no magenta or pink tones on the subject` を足すか、生成後に出力を目視確認する。

## この拠点の既定3種(先頭候補)

依頼が漠然としている場合、まずこの3種から選ぶ。

### 既定1: いらすとや風フラット
太めの柔らかい輪郭線、陰影・光沢なし、パステル、3〜5色、余白広め、ロゴ・文字なし。

```
STYLE:
flat vector illustration in the style of a friendly Japanese stock-icon set, bold soft rounded outlines, uniform line weight, no shading, no gloss, no gradients, pastel color palette, limited three-to-five-color palette, simple geometric shapes, generous negative space, no embedded text, no logos, no watermarks
```
```
AVOID:
drop shadows, highlights, glossy gradients, photorealistic rendering, complex textures, small decorative clutter, embedded text or letters, logos, watermarks, colors outside the palette
```

### 既定2: 解説動画の図解向け
フラット、限定色、テキストなし(字幕・テロップは別レイヤーで乗せる前提)。

```
STYLE:
flat diagrammatic illustration for an explainer video, simple geometric shapes, clear readable silhouettes, limited three-to-four-color palette, minimal shading, clean uncluttered composition, generous negative space reserved for text overlay
```
```
AVOID:
embedded text, letters, numbers, labels, captions, glossy gradients, photorealistic rendering, excessive detail, busy backgrounds, watermarks
```

### 既定3: サムネ向け
コントラスト強め、小さいサイズでも視認できる構図。

```
STYLE:
bold high-contrast thumbnail illustration, strong saturated colors, one clear dominant focal subject, exaggerated readable silhouette, simple background, dramatic lighting contrast, minimal clutter, composition designed to read clearly at small size
```
```
AVOID:
low contrast, muted washed-out colors, cluttered background, small illegible details, embedded text, watermarks
```

## 画風テンプレート 全38種(原文引用・英語)

見出しは記事の分類。各 STYLE ブロックは記事からの原文引用。全文と日本語一言は
[references/style-catalog.md](./references/style-catalog.md) にも収録(同内容)。

### 手描き・アナログ画材系(01〜09)

01. 自然な手描き — 汎用の手描き感の基本形
```
STYLE:
natural hand-drawn illustration, imperfect organic linework, subtle variations in line thickness, slightly uneven contours, loose human-made strokes, simplified shapes, restrained details, soft matte colors, subtle paper texture, minimal digital polish, gentle imperfections, natural spacing, understated composition, handcrafted visual character
```
02. ラフな手描き — スケッチ的なラフさ
```
STYLE:
loose hand-drawn illustration, casual sketch-like lines, spontaneous strokes, imperfect proportions, slightly irregular shapes, visible construction-like marks, simple coloring, relaxed composition, human drawing imperfections, understated details, natural visual rhythm
```
03. 鉛筆イラスト — グラファイトの質感
```
STYLE:
traditional pencil illustration, visible graphite strokes, soft pencil shading, varied pencil pressure, slightly rough linework, subtle smudging, natural paper grain, imperfect hand-drawn edges, restrained contrast, authentic sketchbook quality
```
04. 色鉛筆 — 手作り感のある子ども向け書籍風
```
STYLE:
colored pencil illustration on textured paper, visible pencil strokes, layered pigment, uneven hand pressure, slightly imperfect coloring, subtle white paper showing through, soft edges, muted natural colors, handmade children's book quality
```
05. クレヨン — 温かみ・遊び心
```
STYLE:
hand-drawn crayon illustration, visible wax texture, uneven coloring, rough organic edges, overlapping crayon strokes, playful simplified shapes, warm limited color palette, imperfect childlike marks, tactile paper surface
```
06. 水彩 — 柔らかい滲み、エディトリアル向け
```
STYLE:
traditional watercolor illustration, translucent washes, gentle pigment bleeding, uneven watercolor edges, subtle paper texture, soft overlapping colors, restrained highlights, loose brushwork, organic color variations, handmade editorial illustration
```
07. 水彩＋ペン — 線画と水彩の組み合わせ
```
STYLE:
hand-drawn ink and watercolor illustration, loose irregular ink outlines, varied line weight, transparent watercolor washes, subtle pigment bleeding, textured watercolor paper, slightly imperfect registration between line and color, understated handmade finish
```
08. 絵本 — 温かい物語性
```
STYLE:
warm children's book illustration, hand-drawn organic shapes, slightly imperfect outlines, simple expressive characters, soft textured colors, subtle paper grain, gentle visual storytelling, restrained detail, charming handmade quality, traditional picture-book feeling
```
09. 日本の児童書挿絵風 — 静かで柔らかい国内トーン
```
STYLE:
gentle Japanese children's book illustration, clean but slightly irregular hand-drawn lines, soft restrained colors, simplified facial features, friendly proportions, minimal shading, quiet composition, subtle paper-like texture, warm everyday atmosphere
```

### フラット・エディトリアル系(10〜15)

10. シンプルなフラットデザイン — 基本のフラット
```
STYLE:
clean flat illustration, simple geometric shapes, limited color palette, minimal shading, clear silhouettes, balanced negative space, restrained visual details, subtle asymmetry, friendly editorial design, simple vector-like forms without excessive polish
```
11. AI感の弱いフラットデザイン — フラット+不完全さ強調
```
STYLE:
human-designed flat illustration, simple geometric forms with subtle irregularities, slightly imperfect curves, restrained color palette, minimal shading, intentional asymmetry, varied proportions, natural spacing, subtle print-like texture, editorial graphic design, avoid overly polished vector aesthetics
```
12. ミニマルフラット — 余白重視・色数最小
```
STYLE:
minimal editorial flat illustration, very simple shapes, limited three-to-five-color palette, large areas of negative space, minimal facial details, clean silhouettes, restrained composition, subtle handmade irregularities, quiet contemporary graphic design
```
13. 雑誌の挿絵 — コンセプチュアルな編集イラスト
```
STYLE:
contemporary editorial illustration, conceptual simplified forms, expressive proportions, limited sophisticated color palette, bold negative space, subtle texture, slightly imperfect geometric shapes, intelligent visual simplicity, modern magazine illustration
```
14. Webサービス向けイラスト — 親しみやすいプロダクト訴求
```
STYLE:
modern web editorial illustration, friendly simplified characters, clean geometric shapes, restrained palette, minimal shading, subtle organic imperfections, approachable proportions, clear visual hierarchy, generous negative space, professional but not overly polished
```
15. スタートアップ系Webイラスト — 抽象幾何+人物
```
STYLE:
modern product illustration, simplified human characters, abstract geometric forms, restrained contemporary palette, minimal gradients, clean composition, subtle organic line variation, friendly professional appearance, editorial rather than stock-art aesthetics
```

### ポップ・キャラクター系(16〜19)

16. ポップな手描き — 太く元気な線
```
STYLE:
playful hand-drawn graphic illustration, bold irregular outlines, simplified chunky shapes, bright limited colors, intentionally imperfect proportions, energetic handmade strokes, subtle screen-print texture, casual contemporary visual language
```
17. ゆるいイラスト — ゆるキャラ的な柔らかさ
```
STYLE:
loose friendly doodle illustration, simple rounded characters, uneven hand-drawn outlines, minimal facial features, slightly awkward charming proportions, flat muted colors, lots of empty space, casual human-made feeling
```
18. 落書き・ドゥードル — ノートの走り書き感
```
STYLE:
casual doodle illustration, spontaneous pen strokes, uneven line weight, quirky simplified shapes, sparse details, playful visual symbols, imperfect spacing, monochrome or limited colors, authentic notebook drawing quality
```
19. 太線キャラクター — シルエット重視のキャラデザ
```
STYLE:
bold hand-drawn character illustration, thick irregular outlines, rounded simplified shapes, minimal facial features, solid flat colors, playful proportions, subtle line wobble, strong readable silhouette, screen-printed handmade character design
```

### 印刷・版画系(20〜29)

20. レトロ印刷 — 中世紀風の印刷物っぽさ
```
STYLE:
vintage printed illustration, limited ink palette, imperfect print registration, subtle halftone texture, slightly faded colors, rough paper grain, simple graphic shapes, uneven ink coverage, mid-century editorial character
```
21. シルクスクリーン — 版ズレのあるスクリーン印刷風
```
STYLE:
screen-print illustration, limited spot colors, slightly imperfect ink registration, bold simplified forms, textured ink coverage, rough paper surface, strong graphic silhouettes, handmade printmaking character
```
22. リソグラフ — インクの粒状感・版ズレ
```
STYLE:
risograph-style illustration, limited ink colors, visible grain, imperfect color registration, slightly uneven ink density, bold simple shapes, textured paper, playful graphic composition, authentic small-press print character
```
23. 版画 — 彫った質感の線
```
STYLE:
hand-carved printmaking illustration, rough carved lines, irregular ink edges, simplified bold shapes, visible print texture, uneven ink coverage, limited colors, handmade relief-print character
```
24. 木版画 — 伝統的な木版風
```
STYLE:
traditional woodblock-inspired illustration, carved organic outlines, flattened perspective, limited natural colors, visible paper and ink texture, simplified forms, restrained shading, subtle printing imperfections
```
25. インク画 — 筆圧のあるインクブラシ
```
STYLE:
expressive ink illustration, varied brush pressure, broken irregular lines, occasional dry-brush texture, organic silhouettes, restrained detail, strong negative space, handmade paper texture, spontaneous human brushwork
```
26. マーカー — マーカーの重ね塗り感
```
STYLE:
hand-rendered marker illustration, visible marker strokes, overlapping translucent areas, slightly uneven fills, bold simplified shapes, loose outlines, sketchbook presentation style, natural paper texture
```
27. パステル — 粉っぽい柔らかいグラデーション
```
STYLE:
soft pastel illustration, visible chalk texture, powdery blended colors, irregular edges, textured paper, gentle color transitions, loose hand-drawn shapes, restrained fine detail, tactile handmade quality
```
28. 切り絵 — 紙を切った層構造
```
STYLE:
hand-cut paper collage illustration, simple layered paper shapes, slightly irregular cut edges, subtle paper fibers, flat colors, minimal shading, handmade composition, tactile craft aesthetic
```
29. 紙コラージュ — 複数の紙質を重ねる
```
STYLE:
mixed paper collage illustration, torn and hand-cut paper edges, layered colored paper textures, subtle shadows between layers, imperfect handmade shapes, limited palette, playful editorial composition
```

### 漫画・ゲーム系(30〜32)

30. 漫画 — スクリーントーン入りの本格漫画風
```
STYLE:
hand-drawn manga illustration, expressive black ink linework, varied pen pressure, screentone shading, simplified background details, energetic natural strokes, subtle imperfections in linework, authentic printed comic texture
```
31. 漫画・ゆるめ — 連載コマ風の軽い漫画タッチ
```
STYLE:
simple hand-drawn manga illustration, loose black ink outlines, minimal screentone, expressive simplified faces, slightly exaggerated poses, sparse background, casual serialized-comic drawing quality
```
32. インディーゲーム風2D — スタイライズされたゲームアート
```
STYLE:
independent 2D game illustration, stylized simplified characters, hand-drawn outlines, limited atmospheric palette, subtle texture, distinctive imperfect shapes, restrained detail, handcrafted visual identity
```

### 実務・教材系(33〜38)

33. アイコン・ピクトグラム寄り — サムネや図解の記号的表現
```
STYLE:
simple pictographic illustration, bold readable silhouettes, minimal geometric forms, very limited colors, no unnecessary detail, clear spacing, subtle handmade irregularity, functional editorial icon design
```
34. 教材向け — わかりやすさ優先の説明図
```
STYLE:
clear educational illustration, friendly simplified characters, easy-to-read shapes, restrained colors, minimal visual clutter, clear action and body language, subtle hand-drawn quality, accessible textbook illustration
```
35. 教科書挿絵 — 日本の教科書的な実務トーン
```
STYLE:
Japanese textbook-style educational illustration, clean simplified figures, restrained realistic proportions, clear gestures, minimal shading, soft neutral colors, uncluttered background, practical instructional composition
```
36. 一筆書き風 — 連続線ドローイング
```
STYLE:
continuous-line drawing, loose flowing ink stroke, spontaneous hand movement, irregular curves, minimal details, expressive simplified forms, abundant negative space, authentic pen-on-paper quality
```
37. ボールペン — スケッチ帳のラフな線画
```
STYLE:
ballpoint pen illustration, visible pressure variation, thin scratchy lines, repeated sketch strokes, subtle cross-hatching, imperfect contours, plain paper texture, casual notebook drawing aesthetic
```
38. ファッションイラスト — 引き伸ばしたエレガントな人物線画
```
STYLE:
hand-drawn fashion illustration, elongated expressive figures, loose confident linework, selective watercolor or marker washes, unfinished edges, large negative space, elegant spontaneous drawing quality
```

## 追加で使える AVOID / HUMAN-MADE ブロック

STYLE の後に、狙いに応じて足す。全て記事からの原文引用(英語)。全文と用途は
[references/style-catalog.md](./references/style-catalog.md) にも収録。

- **手作り感(HUMAN-MADE CHARACTER)**: 汎用的に効果あり
- **ツルツル回避**: なめらかすぎるベクター曲線・光沢感を禁止
- **盛りすぎ回避**: 余白を保ち装飾物の増加を防ぐ
- **人物自然化**: 不自然な笑顔・マネキン的ポーズを禁止
- **子ども自然化**: 過剰な頭身・表情を抑える
- **背景自然化**: 不自然な繰り返し・矛盾した建築を防ぐ
- **色数制限**: 彩度上昇・虹色化を抑える

## 注意点

- 単に `hand-drawn` と書くだけでは不足。**不完全さを具体的に名指し**すること
  (`slightly irregular`, `uneven line pressure` など)。
- 放置すると **色と物が際限なく増える**。色数は数字で縛り(`three-to-five-color palette`)、
  「余白を保つ」「必要な物だけ」を明示する。
- 生成物は**必ず開いて目視確認**する(色の破綻、意図しない文字・ロゴの混入、chroma-key の
  誤消去・フリンジなど)。申告だけで済ませない。
- 拠点の素材台帳(asset-catalog)へ登録する際、出典欄は **「AI生成(Codex imagegen)」** と書く
  (URLではなくAI生成である旨を明記。ライセンス確認は不要だが、生成に使ったプロンプトの
  画風テンプレート名を控えておくと再現・修正がしやすい)。
- 本スキルはテキストプロンプトの型を提供するのみで、実際の画像生成コマンド実行は
  coder クルー(Codex 経由)が行う。research/GM は画風選定とプロンプト組み立てのみ担当する。

## ディレクトリ構成

```
imagegen-style/
├── SKILL.md                       # 本ファイル
├── references/
│   ├── style-catalog.md           # 38種+追加ブロック+完成形テンプレートの全文
│   └── source.md                  # 出典・取得日・確認できなかった項目
└── scripts/
    └── remove_chroma_key.py       # クロマキー(#FF00FF等)→透過PNG変換
```
