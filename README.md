# article-images

Zenn の記事に埋め込む動画（アニメーション WebP）の置き場です。
動画を変換して push し、記事に貼る `html-embed` ブロックを作る Claude Code のスキルも入っています。

## 仕組み

Zenn の `html-embed` では `<video>` が使えないため、動画をアニメーション WebP に変換し、
checkbox と CSS だけで作った「動画プレイヤー風」の枠に入れて表示します。
画像は jsDelivr 経由で配信します。

- 動画は main ブランチには置きません。動画 1 本だけを含む独立したコミットを作り、タグを付けて push します。
  jsDelivr は、1 コミット時点のリポジトリ全体が 50MB を超えると配信しないためです
- 記事に貼る URL は、コミットハッシュで固定します

```
https://cdn.jsdelivr.net/gh/k-ibaraki/article-images@<コミットハッシュ>/<日時>.webp
```

## 使い方

このリポジトリで Claude Code を起動し、動画ファイルとタイトルを渡します。

```
/zenn-webp-player
```

スキルは次の順に進めます。

1. 動画をアニメーション WebP に変換する
2. プレイヤーの形でブラウザに開く（プレビュー）
3. 内容を確認する
4. タグで push する
5. Zenn に貼る `html-embed` ブロックを出力する

スクリプトを直接使うこともできます。

```sh
S=.claude/skills/zenn-webp-player/scripts
$S/convert.sh input.mov                # [--fps 10] [--width 720] [--quality 60]
$S/preview.sh <出力された .webp> "タイトル"
$S/publish.sh <出力された .webp> "タイトル"
```

## 必要なもの

- ffmpeg / ffprobe
- img2webp（`brew install webp`）
- このリポジトリに push できる git の設定

## 制限

- 音は出ません。シークもできません
- 一時停止中は、止めたコマではなく黒い画面になります
- 一時停止と再開は Chrome 系で確認した挙動です。ほかのブラウザでは確認していません
- 1 ファイルは 20MB までです（jsDelivr の上限）
- `html-embed` は Zenn の Beta 機能なので、仕様が変わる可能性があります
