#!/bin/zsh
# The moving pictures in docs/screens, from the app's own demo and the animation library: Tools/gifs.sh [WORK_FOLDER]
# Needs ffmpeg, and uv for keys-film.py's pillow. No OP-Z, no window.
set -e
cd "$(dirname "$0")/.."
WORK="${1:-$(mktemp -d)}"
K=(swift run -c release --package-path Packages/GalaxzKit)
$K galaxz-shots "$WORK/film" 360x240 -film
mkdir -p "$WORK/frames"
IDS=(galaxy radar comet rain bars snake)
for i in $IDS; do $K galaxz-frames $i "$WORK/frames/$i.bin"; done
uv run -q --with pillow python Tools/keys-film.py "$WORK/frames" "$WORK/keys" $IDS
gif() {   # NAME FOLDER FILTER COLOURS
  ffmpeg -v error -y -framerate 15 -i "${2}/${1}-%03d.png" -filter_complex "[0:v]${3},split[a][b];[a]palettegen=max_colors=${4}:stats_mode=full[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" -loop 0 "docs/screens/${1}.gif"
}
gif connect "$WORK/film" "select=lt(n\,60),fps=10,crop=1440:508:0:180,scale=800:-1:flags=area" 48
for n in track grid chops fx notes sky; do gif $n "$WORK/film" "fps=12,scale=600:400:flags=area" 160; done
gif keys "$WORK/keys" "null" 96
ls -l docs/screens/*.gif | awk '{print $5, $9}'
