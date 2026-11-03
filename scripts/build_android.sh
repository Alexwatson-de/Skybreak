#!/usr/bin/env bash
set -euo pipefail

TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_ENGINE="${GODOT_BIN:-godot}"
TASK_OUT="$TASK_ROOT/builds/android/Skybreak-Arena.apk"
mkdir -p "$(dirname "$TASK_OUT")"

"$TASK_ENGINE" --headless --path "$TASK_ROOT/game" --export-release Android "$TASK_OUT"
test -s "$TASK_OUT"
echo "APK_READY $TASK_OUT"
