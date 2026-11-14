#!/bin/bash
# 動画をアニメーション WebP（無限ループ）に変換する。push はしない。
# 使い方: convert.sh <動画ファイル> [--fps 10] [--width 720] [--quality 60]
# 出力:   $TMPDIR/zenn-webp-player/<日時>.webp と、長さ・縦横比を書いた <日時>.meta
set -euo pipefail

MAX_BYTES=$((20 * 1024 * 1024)) # jsDelivr が GitHub のファイルを配信する上限（1 ファイル 20MB）

usage() { echo "使い方: $0 <動画ファイル> [--fps N] [--width PX] [--quality 0-100]" >&2; exit 2; }

[ $# -ge 1 ] || usage
input=$1; shift
fps=10; width=720; quality=60
while [ $# -gt 0 ]; do
  case $1 in
    --fps) fps=$2; shift 2 ;;
    --width) width=$2; shift 2 ;;
    --quality) quality=$2; shift 2 ;;
    *) usage ;;
  esac
done
[ -f "$input" ] || { echo "動画ファイルが見つかりません: $input" >&2; exit 1; }
for cmd in ffmpeg ffprobe img2webp; do
  command -v "$cmd" >/dev/null || { echo "$cmd がありません（brew install ffmpeg webp）" >&2; exit 1; }
done

name=$(date +%Y%m%d-%H%M%S)
tmp=${TMPDIR:-/tmp}; outdir=${tmp%/}/zenn-webp-player
mkdir -p "$outdir"
frames=$(mktemp -d "$outdir/frames.XXXXXX")
trap 'rm -rf "$frames"' EXIT

# 幅は元の動画より大きくしない（拡大しても粗くなるだけなので）
ffmpeg -v error -i "$input" -vf "fps=$fps,scale='min($width,iw)':-1:flags=lanczos" -an "$frames/%06d.png"
count=$(find "$frames" -name '*.png' | wc -l | tr -d ' ')
[ "$count" -gt 0 ] || { echo "コマを 1 枚も取り出せませんでした" >&2; exit 1; }

# img2webp のコマごとのオプションは、指定した位置より後ろのコマすべてに効く
out=$outdir/$name.webp
(cd "$frames" && img2webp -loop 0 -lossy -q "$quality" -m 6 -d $((1000 / fps)) ./*.png -o "$out" >/dev/null)

# 縦横比は変換後のコマから取る（回転やピクセル比の指定があっても見た目どおりになる）
aspect=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=/ "$frames/000001.png")
duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$input")
len=$(awk -v d="$duration" 'BEGIN{s=int(d); if (d>s) s++; h=int(s/3600); m=int(s%3600/60); x=s%60;
  if (h>0) printf "%d:%02d:%02d", h, m, x; else printf "%d:%02d", m, x}')
bytes=$(stat -f %z "$out")

printf 'LEN=%s\nASPECT=%s\n' "$len" "$aspect" > "$outdir/$name.meta"

echo "file=$out"
echo "name=$name"
echo "size=$(awk -v b="$bytes" 'BEGIN{printf "%.2f MB", b/1048576}')"
echo "length=$len"
echo "aspect=$aspect"
echo "frames=$count (fps=$fps, width<=$width, quality=$quality)"
if [ "$bytes" -gt "$MAX_BYTES" ]; then
  echo "20MB を超えています。jsDelivr で配信できないので、--fps / --width / --quality を下げて変換し直してください。" >&2
  exit 3
fi
