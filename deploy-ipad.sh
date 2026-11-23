#!/bin/zsh
# Build Galax-z for the iPad, register the device with the team profile if needed, install and launch.
# The iPad must be plugged in and unlocked.
#
#   ./deploy-ipad.sh <device-udid>   # a paired device (xcrun devicectl list devices)
#   ./deploy-ipad.sh                 # the one kept in this clone: git config galaxz.ipad <device-udid>
set -e
cd "$(dirname "$0")"

UDID="${1:-$(git config galaxz.ipad || true)}"
[ -n "$UDID" ] || { echo "which device? ./deploy-ipad.sh <device-udid>, or once: git config galaxz.ipad <device-udid>" >&2; exit 1; }
DD="${DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Galaxz-ipad}"
LOG="$DD/deploy.log"
APP="$DD/Build/Products/Release-iphoneos/Galaxz.app"
mkdir -p "$DD"

if ! xcrun devicectl list devices 2>/dev/null | grep "$UDID" | grep -qvE "unavailable"; then
  echo "iPad $UDID is offline. Plug it in with a cable, unlock it, tap Trust, then run this again." >&2
  exit 1
fi

[ project.yml -nt Galaxz.xcodeproj/project.pbxproj ] && xcodegen generate

# your own team and app id, kept in this clone and not in the code
TEAM="$(git config galaxz.team || true)" ID="$(git config galaxz.id || true)" BY="$(git config galaxz.byline || true)"
MINE=(${TEAM:+DEVELOPMENT_TEAM=$TEAM} ${ID:+GALAXZ_ID=$ID} ${BY:+"GALAXZ_BYLINE=$BY"})

rm -rf "$APP"    # built for another device before, Xcode rewrites Assets.car for this one and does not sign again
echo "▸ building (Release, signed, device registration allowed)… log: $LOG"
xcodebuild -project Galaxz.xcodeproj -scheme Galaxz -configuration Release \
  -destination "id=$UDID" -derivedDataPath "$DD" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration $MINE build > "$LOG" 2>&1 || true
grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" "$LOG" | sort -u
grep -q "BUILD SUCCEEDED" "$LOG" || { echo "build failed — nothing installed" >&2; exit 1; }
codesign --verify --deep --strict "$APP" || { echo "the app's signature is not valid, nothing installed" >&2; exit 1; }

echo "▸ installing $APP"
xcrun devicectl device install app --device "$UDID" "$APP"
echo "▸ launching"
xcrun devicectl device process launch --device "$UDID" --terminate-existing "${ID:-org.galax-z.app}"
echo "✓ Galax-z is running on the iPad"
