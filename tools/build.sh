#!/usr/bin/env bash
# Local build on the server: smoke test, then web + Android debug APK into build/.
set -euo pipefail
cd "$(dirname "$0")/.."
export GODOT_SILENCE_ROOT_WARNING=1
mkdir -p build/web build/android
godot --headless --path game --import >/dev/null 2>&1 || true
godot --headless --path game --script res://tests/smoke_test.gd 2>&1 | grep -q "SMOKE OK" || { echo "SMOKE FAILED"; exit 1; }
godot --headless --path game --export-release Web ../build/web/index.html 2>&1 | grep -E "ERROR" || true
godot --headless --path game --export-debug Android ../build/android/emperors-gambit.apk 2>&1 | grep -E "ERROR" || true
ls -lh build/web/index.html build/android/emperors-gambit.apk
