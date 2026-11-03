#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/engine.sh"
cd "$TASK_ROOT/backend"
[ -f dist/index.js ] || npm run build
exec node dist/index.js
