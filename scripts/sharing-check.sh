#!/bin/sh
# Checks sharing the player screen across two simulators: an iPad shares the demo fight and an iPhone follows
# it, through a turn, and through a change made while the iPhone had another app in front. Saves pictures of
# both for looking at; it asserts nothing itself.
#
# HOST      name of the sharing simulator (default: an iPad on the newest iOS installed)
# FOLLOWER  name of the following simulator (default: an iPhone on the newest iOS installed)
# OUT       folder for the pictures (default: tmp/screenshots/sharing)
set -eu

cd "$(dirname "$0")/.."

BUNDLE=io.github.scooper4711.Turnkeeper
OUT="${OUT:-tmp/screenshots/sharing}"
rm -rf "$OUT"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
PHONE="$(DEVICE_KIND=iPhone IOS_SIMULATOR="${FOLLOWER:-}" scripts/ios-simulator-id.sh)"
[ -n "$PHONE" ] || { echo "The sharing check failed: no simulator to follow with." >&2; exit 1; }
HOST_ID="$(DEVICE_KIND=iPad IOS_SIMULATOR="${HOST:-}" scripts/ios-simulator-id.sh)"
HOST_NAME="$(xcrun simctl list devices | sed -n "s/^ *\(.*\) ($HOST_ID).*/\1/p" | head -n 1)"

picture() { sleep "$2"; xcrun simctl io "$PHONE" screenshot "$OUT/$1.png" >/dev/null 2>&1; }
wait_for() { while [ ! -f "$OUT/$1" ]; do sleep 1; done; }

# The following simulator needs the app: build it there first.
xcrun simctl boot "$PHONE" 2>/dev/null || true
xcodebuild -project ios/Turnkeeper.xcodeproj -scheme Turnkeeper-iPad \
    -destination "platform=iOS Simulator,id=$PHONE" -derivedDataPath ios/build -skipPackageUpdates \
    CODE_SIGNING_ALLOWED=NO TABLESIDE_SYNC_CONTAINER= build | tail -n 1
xcrun simctl install "$PHONE" ios/build/Build/Products/Debug-iphonesimulator/Turnkeeper.app

SIMULATOR="$HOST_NAME" OUT="$OUT" ONLY=testSharingHost scripts/screenshot-tour.sh > "$OUT/host.log" 2>&1 &
wait_for share-sheet.png

xcrun simctl terminate "$PHONE" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$PHONE" "$BUNDLE" --follow-table "$HOST_NAME" 4321 >/dev/null
picture follower-1-joined 8
touch "$OUT/followed"
wait_for share-host-next.png
picture follower-2-next-turn 3

# Another app in front, a change on the sharing device meanwhile, then back.
xcrun simctl launch "$PHONE" com.apple.mobilesafari >/dev/null
sleep 5
touch "$OUT/away"
wait_for share-host-damage.png
sleep 5
xcrun simctl launch "$PHONE" "$BUNDLE" >/dev/null
picture follower-3-back-from-another-app 5
touch "$OUT/done"
wait
cat "$OUT/host.log"
