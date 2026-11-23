#!/bin/sh
# Copy Firmware/builds and Firmware/patches into the app (OPZFirmware's resources). The tests fail if they drift.
set -e
cd "$(dirname "$0")/.."
dst=Packages/GalaxzKit/Sources/OPZFirmware/Resources/firmware
rm -rf "$dst"; mkdir -p "$dst"
cp -R Firmware/builds Firmware/patches "$dst/"
cp Firmware/galaxy/layout.json "$dst/"                 # where the LEDs sit, for the animation library
echo "synced $(ls $dst/builds | wc -l | tr -d ' ') builds, $(ls $dst/patches | wc -l | tr -d ' ') patch records into $dst"
