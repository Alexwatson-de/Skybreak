#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/engine.sh"
exec "$GODOT_BIN" --path "$TASK_ROOT/game" -- "$@"
