#!/bin/zsh
# Android's launcher art and Windows' .ico, from the app icon (Tools/icon/make-icon.swift draws it). Needs only what macOS has: sips, python3.
#
#   Tools/icon/derive.sh
set -e
cd "$(dirname "$0")/../.."
SRC=App/Assets.xcassets/AppIcon.appiconset/icon-dark.png
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Android: the whole icon in the adaptive icon's safe circle (288 of 432), on its own background colour (values/styles.xml, "paper")
sips -s format png -z 288 288 "$SRC" --out "$TMP/art.png" >/dev/null
sips --padToHeightWidth 432 432 --padColor 0C0C0D "$TMP/art.png" --out Android/app/src/main/res/drawable-nodpi/ic_launcher_art.png >/dev/null

# Windows: seven sizes, each a PNG inside the .ico (Vista on reads them)
for n in 16 24 32 48 64 128 256; do sips -s format png -z $n $n "$SRC" --out "$TMP/$n.png" >/dev/null; done
python3 -I - "$TMP" Windows/Galax-z.ico <<'EOF'
import struct, sys
d, out = sys.argv[1], sys.argv[2]
sizes = [16, 24, 32, 48, 64, 128, 256]
pngs = [open(f"{d}/{n}.png", "rb").read() for n in sizes]
head = struct.pack("<HHH", 0, 1, len(sizes))
at, entries = 6 + 16 * len(sizes), b""
for n, p in zip(sizes, pngs):
    entries += struct.pack("<BBBBHHII", n % 256, n % 256, 0, 0, 1, 32, len(p), at)
    at += len(p)
open(out, "wb").write(head + entries + b"".join(pngs))
EOF
echo "made Android/app/src/main/res/drawable-nodpi/ic_launcher_art.png and Windows/Galax-z.ico from $SRC"
