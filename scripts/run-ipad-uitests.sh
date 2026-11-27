#!/bin/sh
# Runs the iPad UI tests in a simulator, or with DEVICE_KIND=iPhone the same tests on an iPhone. They drive the demo fight (--demo board), so they need no
# saved library, only an imported bestiary in Generated/.
#
# Each run drives a simulator of its own: a copy of the one chosen, erased first and deleted afterward. A simulator
# that is used again keeps what earlier runs saved, and the CI Macs run several jobs at once, which would otherwise
# share one simulator. On the CI Macs (toolkit-ci-runner's simulator.sh installed), a run instead borrows one of the
# Mac's simulators, which stays booted between jobs and is reset rather than erased: booting one costs minutes of CPU.
#
# DEVICE_KIND     iPad (the default) or iPhone
# IPAD_SIMULATOR  name of the simulator to use (default: a device of that kind on the newest iOS installed)
# ONLY            tests to run, space-separated, such as "DelayUITests PlanningUITests/testHandoutShownToPlayers"
#                 (default: all of them, which takes several minutes)
set -eu

cd "$(dirname "$0")/.."

SOURCE="$(IOS_SIMULATOR="${IPAD_SIMULATOR:-}" scripts/ios-simulator-id.sh)"
[ -n "$SOURCE" ] || { echo "Running the UI tests failed: no such simulator is installed." >&2; exit 1; }

CI_SIMULATOR=/usr/local/libexec/ci-slots/simulator.sh
LOG="$(mktemp)"
DEVICE=""
[ -x "$CI_SIMULATOR" ] && DEVICE="$("$CI_SIMULATOR" checkout "$SOURCE")"
if [ -n "$DEVICE" ]; then
    give_back() {
        "$CI_SIMULATOR" checkin "$DEVICE" >/dev/null 2>&1 || true
        rm -f "$LOG"
    }
    trap give_back EXIT
    echo "Running the UI tests on simulator $DEVICE, borrowed from the CI Mac (kept booted, reset)..."
else
    DEVICE="$(xcrun simctl clone "$SOURCE" "UI tests $$")" \
        || { echo "Running the UI tests failed: simulator $SOURCE couldn't be copied (is it booted?)." >&2; exit 1; }
    remove_copy() {
        xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
        xcrun simctl delete "$DEVICE" >/dev/null 2>&1 || true
        rm -f "$LOG"
    }
    trap remove_copy EXIT
    xcrun simctl erase "$DEVICE"
    echo "Running the UI tests on simulator $DEVICE, a fresh copy of $SOURCE..."
fi
trap 'exit 1' INT TERM

set -- -project ios/Turnkeeper.xcodeproj -scheme Turnkeeper-iPad \
    -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath ios/build -skipPackageUpdates \
    TABLESIDE_SYNC_CONTAINER=
for test in ${ONLY:-}; do set -- "$@" -only-testing:"TurnkeeperUITests/$test"; done

STATUS=0
xcodebuild test "$@" > "$LOG" 2>&1 || STATUS=$?
grep -E " error: |Test Case .*(passed|failed)|\*\* TEST" "$LOG" || tail -n 20 "$LOG"
exit "$STATUS"
