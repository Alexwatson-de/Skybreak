#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/engine.sh"
"$GODOT_BIN" --headless --path "$TASK_ROOT/game" --script tests/simulation_test.gd
"$GODOT_BIN" --headless --path "$TASK_ROOT/game" --script tests/prediction_test.gd
cd "$TASK_ROOT/backend"
npm run build
npm test
python3 "$TASK_ROOT/scripts/test_lan.py"

if [ "${1:-}" = "--full" ]; then
  python3 "$TASK_ROOT/scripts/test_native_lobby.py"
  python3 "$TASK_ROOT/scripts/test_capacity.py"
fi
