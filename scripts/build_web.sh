#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$TASK_ROOT/.runtime" "$TASK_ROOT/builds/web"
if [ -n "${GODOT_BIN:-}" ]; then
  TASK_ENGINE="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  TASK_ENGINE="$(command -v godot)"
elif [ "$(uname -s)" = Darwin ]; then
  TASK_ENGINE="$TASK_ROOT/.runtime/Godot.app/Contents/MacOS/Godot"
else
  TASK_ENGINE="$TASK_ROOT/.runtime/Godot_v4.5.1-stable_linux.x86_64"
  if [ ! -x "$TASK_ENGINE" ]; then
    curl --fail --location --retry 3 https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip -o "$TASK_ROOT/.runtime/linux-engine.zip"
    python3 "$TASK_ROOT/scripts/verify_engine.py" "$TASK_ROOT/.runtime/linux-engine.zip"
    unzip -oq "$TASK_ROOT/.runtime/linux-engine.zip" -d "$TASK_ROOT/.runtime"
  fi
fi
TASK_PRESET_BACKUP="$(mktemp)"
cp "$TASK_ROOT/game/export_presets.cfg" "$TASK_PRESET_BACKUP"
trap 'cp "$TASK_PRESET_BACKUP" "$TASK_ROOT/game/export_presets.cfg"; rm -f "$TASK_PRESET_BACKUP"' EXIT
python3 - "$TASK_ROOT" <<'PY'
from pathlib import Path
import sys, re
root=Path(sys.argv[1]);p=root/'game/export_presets.cfg';s=p.read_text()
template=str(root/'vendor/godot-web-4.5.1.zip')
s=re.sub(r'(custom_template/(?:debug|release)=)"[^"\n]*web_nothreads_release.zip"',lambda m:m[1]+'"'+template+'"',s)
p.write_text(s)
PY
"$TASK_ENGINE" --headless --path "$TASK_ROOT/game" --editor --import --quit
"$TASK_ENGINE" --headless --path "$TASK_ROOT/game" --export-release 'Browser Online' "$TASK_ROOT/builds/web/index.html"
"$TASK_ENGINE" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/scripts/export_licenses.gd" -- "$TASK_ROOT/docs/licenses"
cp -R "$TASK_ROOT/docs/licenses" "$TASK_ROOT/builds/web/"
python3 "$TASK_ROOT/scripts/prepare_web.py"
echo "Built browser multiplayer in builds/web/"
