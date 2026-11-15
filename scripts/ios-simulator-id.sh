#!/bin/sh
# Prints the identifier of a simulator: the one named by IOS_SIMULATOR, or otherwise a device of
# DEVICE_KIND (iPad or iPhone; default iPad) on the newest installed iOS version. Prints nothing
# when there is none.
set -eu

xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json
import os
import sys

wanted = os.environ.get("IOS_SIMULATOR", "")
kind = os.environ.get("DEVICE_KIND") or "iPad"
runtimes = json.load(sys.stdin)["devices"]


def version(runtime):
    digits = runtime.rsplit("iOS-", 1)[-1].split("-")
    return [int(part) for part in digits if part.isdigit()]


candidates = [
    (version(runtime), device)
    for runtime, devices in runtimes.items() if "iOS" in runtime
    for device in devices
    if (device["name"] == wanted if wanted else device["name"].startswith(kind))
]
candidates.sort(key=lambda pair: pair[0])
print(candidates[-1][1]["udid"] if candidates else "")
'
