#!/bin/bash
# Galax-z for Android: the shared Swift packages as one library, then the app around it, as an APK to install by hand.
#
#   Android/build.sh            a test build: Android/build/Galax-z.apk
#   Android/build.sh install    and install it on the phone plugged in (adb)
#
# Needs (BUILDING.md › Android): the swift.org toolchain and its Swift SDK for Android, the Android NDK, the Android SDK,
# a JDK (17 or newer) and Gradle. Where they are is found by itself, or set SWIFT_TOOLCHAIN, ANDROID_NDK_HOME,
# ANDROID_HOME, JAVA_HOME.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"

swift_version=6.4.3
sdk="swift-${swift_version}-RELEASE_android"
toolchain="${SWIFT_TOOLCHAIN:-$HOME/Library/Developer/Toolchains/swift-${swift_version}-RELEASE.xctoolchain/usr/bin}"
[ -x "$toolchain/swift" ] || toolchain="$(dirname "$(command -v swift)")"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    for d in "$HOME/Library/Caches/galaxz-android/android-ndk-r30" "$ANDROID_HOME"/ndk/30.*; do [ -d "$d" ] && ANDROID_NDK_HOME="$d"; done
fi
export ANDROID_NDK_HOME
if [ -z "${JAVA_HOME:-}" ]; then
    for d in /opt/homebrew/opt/openjdk@17 /opt/homebrew/opt/openjdk@21 /opt/homebrew/opt/openjdk; do [ -d "$d" ] && { JAVA_HOME="$d"; break; }; done
    export JAVA_HOME
fi

"$toolchain/swift" sdk list | grep -q "$sdk" || {
    echo "No Swift SDK for Android ($sdk). See docs/BUILDING.md › Android." >&2; exit 1; }
[ -d "${ANDROID_NDK_HOME:-}" ] || { echo "No Android NDK r30: set ANDROID_NDK_HOME." >&2; exit 1; }

echo "› the shared packages, for Android (arm64)"
"$toolchain/swift" build -c release --package-path core --swift-sdk aarch64-unknown-linux-android28 \
    --static-swift-stdlib --scratch-path build/swift
libs=app/build/jniLibs/arm64-v8a
mkdir -p "$libs"
ndk_bin=$(echo "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/bin)
"$ndk_bin/llvm-strip" -o "$libs/libGalaxzAndroid.so" build/swift/release/libGalaxzAndroid.so
cp "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so "$libs/"

echo "› the app"
gradle --quiet assembleRelease
mkdir -p build
cp app/build/outputs/apk/release/app-release.apk build/Galax-z.apk
echo "› build/Galax-z.apk ($(du -h build/Galax-z.apk | cut -f1))"

if [ "${1:-}" = install ]; then
    "$ANDROID_HOME/platform-tools/adb" install -r build/Galax-z.apk
fi
