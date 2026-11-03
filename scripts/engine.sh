#!/usr/bin/env bash
# Sourced by the other scripts. GODOT_BIN may point to any Godot 4.5.1+ binary.
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${GODOT_BIN:-}" ]; then
  if [ -x "$TASK_ROOT/.runtime/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT_BIN="$TASK_ROOT/.runtime/Godot.app/Contents/MacOS/Godot"
  elif [ -x "$TASK_ROOT/.runtime/Godot_v4.5.1-stable_linux.x86_64" ]; then
    GODOT_BIN="$TASK_ROOT/.runtime/Godot_v4.5.1-stable_linux.x86_64"
  elif command -v godot >/dev/null; then GODOT_BIN="$(command -v godot)"
  elif command -v godot4 >/dev/null; then GODOT_BIN="$(command -v godot4)"
  else echo "Godot not found. Run scripts/bootstrap.sh"; exit 1
  fi
fi
export GODOT_BIN
