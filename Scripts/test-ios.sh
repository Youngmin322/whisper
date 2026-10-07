#!/bin/bash
set -euo pipefail

project_directory="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_directory"

# Select an installed iPhone on iOS 26 or later; local and CI device names may differ.
simulator_id="${WHISPER_SIMULATOR_ID:-}"
if [[ -z "$simulator_id" ]]; then
    simulator_id="$(python3 - <<'PY'
import json
import subprocess
import sys

devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))["devices"]
candidates = []
for runtime, entries in devices.items():
    if ".iOS-" not in runtime:
        continue
    version = tuple(int(part) for part in runtime.split(".iOS-", 1)[1].split("-"))
    if version < (26,):
        continue
    for device in entries:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            candidates.append((version, "Pro" in device["name"], device["name"], device["udid"]))
if not candidates:
    sys.exit("Install an iOS 26 or later iPhone simulator in Xcode before running tests.")
print(max(candidates)[-1])
PY
)"
fi

derived_data="${WHISPER_DERIVED_DATA:-$project_directory/DerivedData}"
xcodebuild test \
    -project Whisper.xcodeproj \
    -scheme Whisper \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$derived_data" \
    SYMROOT="$derived_data/Build/Products" \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    "$@"
