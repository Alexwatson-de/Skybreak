#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$TASK_ROOT/.runtime" "$TASK_ROOT/.cache/npm"
case "$(uname -s)" in
  Darwin) ARCHIVE="Godot_v4.5.1-stable_macos.universal.zip"; GODOT_LOCAL="$TASK_ROOT/.runtime/Godot.app/Contents/MacOS/Godot" ;;
  Linux) ARCHIVE="Godot_v4.5.1-stable_linux.x86_64.zip"; GODOT_LOCAL="$TASK_ROOT/.runtime/Godot_v4.5.1-stable_linux.x86_64" ;;
  *) echo "Install Godot 4.5.1+ and Node.js 22+, then open game/project.godot. See README."; exit 1 ;;
esac
if [ ! -x "$GODOT_LOCAL" ]; then
  curl --fail -L --retry 2 "https://github.com/godotengine/godot/releases/download/4.5.1-stable/$ARCHIVE" -o "$TASK_ROOT/.runtime/engine.zip"
  unzip -oq "$TASK_ROOT/.runtime/engine.zip" -d "$TASK_ROOT/.runtime"
  rm "$TASK_ROOT/.runtime/engine.zip"
fi
command -v node >/dev/null || { echo "Install free Node.js 22+ from nodejs.org first."; exit 1; }
cd "$TASK_ROOT/backend"
npm ci --cache "$TASK_ROOT/.cache/npm" --no-audit --no-fund
npm run build
printf '\nReady. Run ./scripts/play.sh and ./scripts/lobby.sh\n'
