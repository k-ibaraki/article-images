#!/bin/bash
# convert.sh が作った WebP（と、あれば停止中の画像 <日時>-poster.webp）だけを含む親なしコミット＋タグとして push し、
# Zenn に貼る html-embed ブロックを標準出力に出す。
# 使い方: publish.sh <convert.sh が出力した .webp> [タイトル]
#
# main に積まない理由: jsDelivr は 1 コミット時点のリポジトリ全体が 50MB を超えると配信しない。
# 動画ごとに独立したコミットにすれば、どのコミットも動画 1 本分のサイズで済む。
set -euo pipefail

MAX_BYTES=$((20 * 1024 * 1024))

[ $# -ge 1 ] && [ $# -le 2 ] || { echo "使い方: $0 <webp ファイル> [タイトル]" >&2; exit 2; }
webp=$1; title=${2-}
meta=${webp%.webp}.meta
[ -f "$webp" ] && [ -f "$meta" ] || { echo "$webp か $meta がありません。先に convert.sh を実行してください" >&2; exit 1; }
[ "$(stat -f %z "$webp")" -le "$MAX_BYTES" ] || { echo "20MB を超えているので push しません" >&2; exit 3; }

skill_dir=$(cd "$(dirname "$0")/.." && pwd)
repo=$(git -C "$skill_dir" rev-parse --show-toplevel)
slug=$(git -C "$repo" remote get-url origin | sed -E 's#^(https://github\.com/|git@github\.com:)##; s#\.git$##')
name=$(basename "$webp" .webp)
path=$name.webp
LEN=$(sed -n 's/^LEN=//p' "$meta")
ASPECT=$(sed -n 's/^ASPECT=//p' "$meta")

if git -C "$repo" rev-parse -q --verify "refs/tags/$name" >/dev/null ||
   [ -n "$(git -C "$repo" ls-remote --tags origin "refs/tags/$name")" ]; then
  echo "タグ $name はすでにあります。上書きはしません" >&2; exit 1
fi

# 作業ツリーとインデックスには触らずにコミットを作る
poster=${webp%.webp}-poster.webp
tree=$({
  printf '100644 blob %s\t%s\n' "$(git -C "$repo" hash-object -w "$webp")" "$path"
  [ ! -f "$poster" ] || printf '100644 blob %s\t%s\n' "$(git -C "$repo" hash-object -w "$poster")" "$name-poster.webp"
} | git -C "$repo" mktree)
sha=$(git -C "$repo" commit-tree "$tree" -m "add $path")
git -C "$repo" tag "$name" "$sha"
git -C "$repo" push --quiet origin "refs/tags/$name" >&2

src=https://cdn.jsdelivr.net/gh/$slug@$sha/$path
ok=
for _ in 1 2 3 4 5; do
  if [ "$(curl -s -o /dev/null -w '%{http_code}' -I "$src")" = 200 ]; then ok=1; break; fi
  sleep 3
done
[ -n "$ok" ] || echo "注意: jsDelivr がまだ 200 を返しません。少し待ってから $src を確認してください" >&2

TITLE=$(printf '%s' "$title" | sed -e 's/&/\&amp;/g' -e 's/"/\&quot;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
POSTER=
[ ! -f "$poster" ] || POSTER="<img src=\"https://cdn.jsdelivr.net/gh/$slug@$sha/$name-poster.webp\">"
export TITLE SRC=$src LEN ASPECT POSTER
block=$(perl -pe 's/\{\{(TITLE|SRC|LEN|ASPECT|POSTER)\}\}/$ENV{$1}/g' "$skill_dir/template.html-embed")
[ "$(printf '%s' "$block" | wc -c)" -lt 50000 ] || echo "注意: ブロックが 50KB を超えています（Zenn の上限）" >&2
printf '%s\n' "$block"
