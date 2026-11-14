---
name: zenn-webp-player
description: 画面収録などの動画を Zenn の記事に埋め込みたいときに使う。動画をアニメーション WebP に変換してこのリポジトリ（article-images）にタグで push し、jsDelivr 経由で再生・一時停止できるプレイヤー風の html-embed ブロックをチャットに出力する。「動画を Zenn に貼りたい」「画面収録を記事に埋め込みたい」「webp プレイヤーを作って」と言われたら使う。
---

# Zenn 用 WebP プレイヤー

動画ファイルとタイトルを受け取り、Zenn の記事にそのまま貼れる `html-embed` ブロックを返す。
タイトルが無ければ先に聞き、不要と言われたらタイトルの引数を省く。

## 手順

1. 変換する（push はしない）

   ```sh
   .claude/skills/zenn-webp-player/scripts/convert.sh <動画> [--fps 10] [--width 720] [--quality 60] [--poster <画像>]
   ```

   `--poster` は停止中に出す画像。付けると動画と同じコミットで push され、付けなければ停止中は黒い画面になる。
   枠の縦横比は動画に合わせるので、画像の比が違うと左右か上下に黒い帯が出る。

   `file` `name` `size` `length` `aspect` が出力される。終了コード 3 は 20MB 超で、
   このままでは配信できない。`--fps` `--width` `--quality` のどれを下げるかを提案して変換し直す。

2. プレビューを開く

   ```sh
   .claude/skills/zenn-webp-player/scripts/preview.sh <手順 1 の file> ["<タイトル>"]
   ```

   実際のプレイヤーの形でブラウザに開く。push すると取り消しにくいので、先に目で見てもらう。

3. ユーザーに確認する。このリポジトリは公開で、push した動画はすぐ誰でも見られ、jsDelivr にも残る。
   ファイル名（＝タグ名）・サイズ・長さ・タイトルを示し、プレビューの見た目に問題がないかも聞いて、
   承認を得てから次へ進む。スキルを呼ばれたことは push の承認にならない。

4. push してブロックを作る

   ```sh
   .claude/skills/zenn-webp-player/scripts/publish.sh <手順 1 の file> ["<タイトル>"]
   ```

   標準出力がそのまま `html-embed` ブロックになる。標準エラーに「注意:」が出たら内容を伝える。

5. ブロックをチャットに出す。Zenn に貼ったときに崩れないよう、外側を 4 つのバッククォートで囲み、
   中身は一字も変えない。

## 仕組みと理由

- 変換は ffmpeg で連番 PNG を書き出し、`img2webp` でまとめる。Homebrew の ffmpeg には libwebp が
  入っていないことがあり、`-c:v libwebp` に頼れないため
- 必ず無限ループにする。1 回再生の WebP は、同じ URL では再生し直せない
- 動画は main に積まず、動画 1 本だけを含む親なしコミットにタグを付けて push する。jsDelivr は
  1 コミット時点のリポジトリ全体が 50MB、1 ファイルが 20MB を超えると配信しないため
- URL はコミットハッシュで固定する（`@<sha>`）。タグ名やブランチ名の URL はキャッシュされ、差し替えが反映されない
- ファイル名とタグ名は変換時刻（`YYYYMMDD-HHMMSS`）。同じタグがあれば上書きせず止まる
- 幅を 1200px より大きくしても意味がない。Zenn が Cloudinary 経由で 1200px に縮小する

## プレイヤーの制限（聞かれたら伝える）

- 音は出ない。シークもできない。一時停止中は止めたコマではなく、`--poster` の画像（無ければ黒い画面）になる
- 一時停止は「非表示の間はアニメーションが進まない」という Chrome 系の挙動に頼っている。
  Safari / Firefox では未検証
- `html-embed` は Zenn の Beta 機能で、JavaScript・`<video>`・`<button>` は使えない。
  状態は checkbox ひとつと `label` 2 つで持っている。テンプレートを直すときはこの制約の中で行う
