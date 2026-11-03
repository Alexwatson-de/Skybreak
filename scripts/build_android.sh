#!/usr/bin/env bash
set -euo pipefail

TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_ENGINE="${GODOT_BIN:-godot}"
TASK_OUT="$TASK_ROOT/builds/android/Skybreak-Arena.apk"
mkdir -p "$(dirname "$TASK_OUT")"

# Use Godot's configured debug keystore so the result can be sideloaded
# immediately. A Play Store release should use a separately protected release
# signing key, never this reproducible development key.
"$TASK_ENGINE" --headless --path "$TASK_ROOT/game" --export-debug Android "$TASK_OUT"
test -s "$TASK_OUT"
echo "APK_READY $TASK_OUT"
