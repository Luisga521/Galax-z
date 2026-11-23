#!/bin/zsh
# docs/screens/shortcuts.png from shortcuts.html, with Chrome, at twice the size for sharp text.
set -e
cd "$(dirname "$0")"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
"$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=2 --window-size=1400,${HEIGHT:-1040} \
  --virtual-time-budget=4000 --screenshot="$PWD/../../docs/screens/shortcuts.png" "file://$PWD/shortcuts.html" 2>/dev/null
sips -g pixelHeight ../../docs/screens/shortcuts.png | tail -1
