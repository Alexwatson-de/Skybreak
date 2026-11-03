#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/engine.sh"
mkdir -p "$TASK_ROOT/builds/web"
TASK_PRESET_BACKUP="$(mktemp)"
cp "$TASK_ROOT/game/export_presets.cfg" "$TASK_PRESET_BACKUP"
trap 'cp "$TASK_PRESET_BACKUP" "$TASK_ROOT/game/export_presets.cfg"; rm -f "$TASK_PRESET_BACKUP"' EXIT
# Use local templates when present, otherwise Godot's installed standard templates.
python3 - "$TASK_ROOT" <<'PY'
import sys,pathlib,re
root=pathlib.Path(sys.argv[1]);cfg=root/'game/export_presets.cfg';text=cfg.read_text()
def template(m):
 path=m.group(2)
 return m.group(1)+'"'+str((root/'game'/path).resolve())+'"' if (root/'game'/path).exists() else m.group(1)+'""'
text=re.sub(r'(custom_template/(?:debug|release)=)"([^"]+)"',template,text)
cfg.write_text(text)
PY
"$GODOT_BIN" --headless --path "$TASK_ROOT/game" --editor --import --quit
"$GODOT_BIN" --headless --path "$TASK_ROOT/game" --export-release macOS "$TASK_ROOT/builds/Skybreak Arena.app"
"$GODOT_BIN" --headless --path "$TASK_ROOT/game" --export-release 'Browser Online' "$TASK_ROOT/builds/web/index.html"
"$GODOT_BIN" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/scripts/export_licenses.gd" -- "$TASK_ROOT/docs/licenses"
cp -R "$TASK_ROOT/docs/licenses" "$TASK_ROOT/builds/Skybreak Arena.app/Contents/Resources/"
cp -R "$TASK_ROOT/docs/licenses" "$TASK_ROOT/builds/web/"
python3 "$TASK_ROOT/scripts/prepare_web.py"
if [ "$(uname -s)" = "Darwin" ]; then
  codesign --force --deep --sign - --timestamp=none "$TASK_ROOT/builds/Skybreak Arena.app"
  codesign --verify --all-architectures --deep --strict --verbose=2 "$TASK_ROOT/builds/Skybreak Arena.app"
fi
echo "Built and sealed native macOS app and browser online files in builds/."
