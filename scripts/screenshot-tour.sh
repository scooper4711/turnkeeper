#!/bin/sh
# Saves a picture of each screen of the demo library, for checking layouts on a device size by eye.
#
# SIMULATOR  name of the simulator to use, such as "iPhone 17e" (default: an iPhone on the newest iOS installed)
# OUT        folder for the pictures (default: tmp/screenshots/<simulator name>)
# ONLY       tour tests to run, space-separated, such as "testBoard testSetup" (default: all)
set -eu

cd "$(dirname "$0")/.."

DEVICE="$(DEVICE_KIND=iPhone IOS_SIMULATOR="${SIMULATOR:-}" scripts/ios-simulator-id.sh)"
[ -n "$DEVICE" ] || { echo "The screenshot tour failed: no such simulator is installed." >&2; exit 1; }
NAME="$(xcrun simctl list devices | sed -n "s/^ *\(.*\) ($DEVICE).*/\1/p" | head -n 1)"
OUT="${OUT:-tmp/screenshots/$NAME}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

set -- -project ios/Turnkeeper.xcodeproj -scheme Turnkeeper-iPad \
    -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath ios/build -skipPackageUpdates \
    TABLESIDE_SYNC_CONTAINER=
for test in ${ONLY:-}; do set -- "$@" -only-testing:"TurnkeeperUITests/ScreenshotTour/$test"; done
[ -n "${ONLY:-}" ] || set -- "$@" -only-testing:TurnkeeperUITests/ScreenshotTour

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
STATUS=0
TEST_RUNNER_SCREENSHOT_DIR="$OUT" xcodebuild test "$@" > "$LOG" 2>&1 || STATUS=$?
grep -E " error: |Test Case .*(passed|failed)|\*\* TEST" "$LOG" || tail -n 20 "$LOG"
echo "Pictures are in $OUT"
exit "$STATUS"
