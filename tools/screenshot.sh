#!/usr/bin/env bash
# Screenshot a scene headless-ish via Xvfb. Usage: tools/screenshot.sh [scene] [out.png] [frames]
cd "$(dirname "$0")/.." || exit 1
export GODOT_SILENCE_ROOT_WARNING=1
xvfb-run -a -s "-screen 0 720x1280x24" godot --path game --resolution 720x1280 --rendering-driver opengl3 \
  --script res://tests/screenshot.gd -- "${1:-res://scenes/main.tscn}" "${2:-$PWD/build/shot.png}" "${3:-60}" 2>&1 | grep -E 'SAVED|ERROR'
