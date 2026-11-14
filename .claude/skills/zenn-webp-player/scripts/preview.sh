#!/bin/bash
# convert.sh が作った WebP を、プレイヤーのテンプレートに埋め込んでブラウザで開く。push の前の確認用。
# 使い方: preview.sh <convert.sh が出力した .webp> [タイトル]
# 同じ場所に <日時>-poster.webp があれば、停止中の画像として使う。
# Zenn では Cloudinary が画像を変換して配信するので、画質は完全には一致しない。
set -euo pipefail

[ $# -ge 1 ] && [ $# -le 2 ] || { echo "使い方: $0 <webp ファイル> [タイトル]" >&2; exit 2; }
webp=$1; title=${2-}
meta=${webp%.webp}.meta
[ -f "$webp" ] && [ -f "$meta" ] || { echo "$webp か $meta がありません。先に convert.sh を実行してください" >&2; exit 1; }

skill_dir=$(cd "$(dirname "$0")/.." && pwd)
LEN=$(sed -n 's/^LEN=//p' "$meta")
ASPECT=$(sed -n 's/^ASPECT=//p' "$meta")
TITLE=$(printf '%s' "$title" | sed -e 's/&/\&amp;/g' -e 's/"/\&quot;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
# HTML を WebP と同じ場所に置き、画像は相対パスで参照する
POSTER=; poster=${webp%.webp}-poster.webp
[ ! -f "$poster" ] || POSTER="<img src=\"$(basename "$poster")\">"
export TITLE SRC=$(basename "$webp") LEN ASPECT POSTER

html=${webp%.webp}.html
{
  echo '<!doctype html><meta charset="utf-8"><title>preview</title>'
  grep -v '^```' "$skill_dir/template.html-embed" | perl -pe 's/\{\{(TITLE|SRC|LEN|ASPECT|POSTER)\}\}/$ENV{$1}/g'
} > "$html"
open "$html"
echo "preview=$html"
