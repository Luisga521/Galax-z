#!/bin/zsh
# Galax-z for the Mac as one zip to hand out: Tools/package-mac.sh [OUT_DIR]
#
# Signed with a "Developer ID Application" identity if this Mac has one, and notarized if NOTARY_PROFILE names a notarytool
# keychain profile; otherwise signed for this Mac only (others then have to allow it in System Settings › Privacy & Security).
# A Developer ID has a person's name in it, for everybody to read: PUBLIC=1 leaves it out, and your app id too.
set -e
cd "$(dirname "$0")/.."
OUT="${1:-build}"
DD="${DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Galaxz-package}"
mkdir -p "$OUT" "$DD"
Tools/sync-firmware.sh >/dev/null
xcodegen generate >/dev/null
MINE=()
if [ -z "$PUBLIC" ]; then ID="$(git config galaxz.id || true)" BY="$(git config galaxz.byline || true)"; MINE=(${ID:+GALAXZ_ID=$ID} ${BY:+"GALAXZ_BYLINE=$BY"}); fi
xcodebuild -project Galaxz.xcodeproj -scheme Galaxz -configuration Release -destination 'generic/platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO $MINE build > "$DD/build.log" 2>&1 || { grep error: "$DD/build.log"; exit 1; }
APP="$OUT/Galax-z.app"
rm -rf "$APP"
ditto "$DD/Build/Products/Release-maccatalyst/Galaxz.app" "$APP"
ID=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
[ -z "$PUBLIC" ] || { ID=""; xcrun strip -S -x "$APP/Contents/MacOS/Galaxz"; }    # no debug symbols: they carry the folders it was built in
if [ -n "$ID" ]; then codesign --force --deep --options runtime --timestamp --entitlements Galaxz-mac.entitlements --sign "$ID" "$APP"; else codesign --force --deep --entitlements Galaxz-mac.entitlements --sign - "$APP"; fi
codesign --verify --deep --strict "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
ZIP="$OUT/Galax-z-$VERSION-mac.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
if [ -n "$ID" ] && [ -n "$NOTARY_PROFILE" ]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  ditto -c -k --keepParent "$APP" "$ZIP"
fi
# the notices are in it, and no file of TE's
for f in THIRD_PARTY.md LICENSE; do [ -n "$(find "$APP" -name "$f")" ] || { echo "$f is not in the app" >&2; exit 1; }; done
if find "$APP" \( -name '*.ldr' -o -name '*.zfw' -o -name 'os.crc32' \) | grep -q .; then echo "TE's files in the app" >&2; exit 1; fi
echo "$ZIP ($(du -h "$ZIP" | cut -f1)), signed by ${ID:-nobody (this Mac only)}"
