#!/bin/sh
# Builds the iPad and iPhone app for the simulator, installs it and starts it.
#
# DEVICE_KIND     iPad (the default) or iPhone
# IPAD_SIMULATOR  name of the simulator to use (default: a device of that kind on the newest iOS installed)
set -eu

cd "$(dirname "$0")/.."
mkdir -p Generated

DEVICE="$(IOS_SIMULATOR="${IPAD_SIMULATOR:-}" scripts/ios-simulator-id.sh)"
[ -n "$DEVICE" ] || { echo "Starting the simulator failed: no such simulator is installed." >&2; exit 1; }

xcodebuild -project ios/Turnkeeper.xcodeproj -scheme Turnkeeper-iPad \
    -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath ios/build \
    CODE_SIGNING_ALLOWED=NO TABLESIDE_SYNC_CONTAINER= build | tail -n 3

APP="ios/build/Build/Products/Debug-iphonesimulator/Turnkeeper.app"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
# Xcode 27 shows simulators in Device Hub; earlier versions in the Simulator app.
open -b com.apple.dt.Devices 2>/dev/null || open -a Simulator
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" io.github.scooper4711.Turnkeeper
