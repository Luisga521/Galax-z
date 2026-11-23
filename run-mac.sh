#!/bin/zsh
# Build Galax-z for the Mac (Mac Catalyst) and open it. On the Mac the hub can flash the OP-Z (USB, update mode).
#
#   ./run-mac.sh            build (Release: the screen is drawn in Swift) and open
#   ./run-mac.sh -hub       ... straight into the hub
set -e
cd "$(dirname "$0")"

DD="${DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Galaxz-mac}"
LOG="$DD/build.log"
mkdir -p "$DD"

Tools/sync-firmware.sh >/dev/null                       # the app ships Firmware/builds and Firmware/patches
[ project.yml -nt Galaxz.xcodeproj/project.pbxproj ] && xcodegen generate

# your own team and app id, kept in this clone and not in the code
TEAM="$(git config galaxz.team || true)" ID="$(git config galaxz.id || true)" BY="$(git config galaxz.byline || true)"
MINE=(${TEAM:+DEVELOPMENT_TEAM=$TEAM} ${ID:+GALAXZ_ID=$ID} ${BY:+"GALAXZ_BYLINE=$BY"})

echo "▸ building for the Mac… log: $LOG"
xcodebuild -project Galaxz.xcodeproj -scheme Galaxz -configuration Release \
  -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath "$DD" \
  -allowProvisioningUpdates $MINE build > "$LOG" 2>&1 || true
grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" "$LOG" | sort -u
grep -q "BUILD SUCCEEDED" "$LOG" || { echo "build failed" >&2; exit 1; }

APP="$DD/Build/Products/Release-maccatalyst/Galaxz.app"
pkill -f "$APP/Contents/MacOS/Galaxz" 2>/dev/null && sleep 1 || true
DUMPS="$(dirname "$(git rev-parse --git-common-dir 2>/dev/null || echo .)")/Firmware/dumps"      # your own OS, if the repository has it
[ -d "$DUMPS" ] && set -- "$@" -dumps "$DUMPS"
open "$APP" --args "$@"
echo "✓ Galax-z is open: $APP"
