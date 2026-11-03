#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/engine.sh"
TASK_APP="$TASK_ROOT/builds/Skybreak Arena.app"
TASK_OUT="$(cd "$TASK_ROOT/.." && pwd)"
TASK_DMG="$TASK_OUT/Skybreak-Arena-1.1-macOS.dmg"
TASK_STAGE="$(mktemp -d "$TASK_ROOT/.runtime/dmg-stage.XXXXXX")"
TASK_IMAGE_WORK="$(mktemp -d "$TASK_ROOT/.runtime/dmg-image.XXXXXX")"
trap 'rm -rf "$TASK_STAGE" "$TASK_IMAGE_WORK"' EXIT
[ -x "$TASK_APP/Contents/MacOS/Skybreak Arena" ] || { echo "Run scripts/build.sh first."; exit 1; }
codesign --verify --all-architectures --deep --strict --verbose=2 "$TASK_APP"
ditto "$TASK_APP" "$TASK_STAGE/Skybreak Arena.app"
ln -s /Applications "$TASK_STAGE/Applications"
cat > "$TASK_STAGE/INSTALL.txt" <<'TEXT'
SKYBREAK ARENA 1.1

1. Drag Skybreak Arena.app to the Applications shortcut.
2. Eject this disk image.
3. Open Skybreak Arena from Applications.

This is a free, original indie build. The complete app bundle is ad-hoc
signed and verified for both Apple Silicon and Intel. It is not Apple
notarized. macOS can therefore still show its normal unidentified-developer
prompt; an ad-hoc signature is an integrity seal, not Apple approval.

If the disk image itself will not mount, download it again and compare its
SHA-256 checksum with the supplied SHA256SUMS file. Please share the exact
macOS error message and OS version when reporting a problem.

Controls: A/D move, Space jump, W or right mouse jetpack, mouse aim/fire,
E collect a gun, 1-6 switch collected guns, Q select grenade, G throw,
R reload, Tab score, Escape menu.

Practice works immediately. Multiplayer clients and servers must all use 1.1.
TEXT
if ! hdiutil create -ov -volname "Skybreak Arena 1.1" -fs HFS+ -format UDZO -srcfolder "$TASK_STAGE" "$TASK_DMG"; then
  # Build the HFS+ filesystem without attaching a temporary device. This also
  # works on build hosts where DiskImages cannot allocate a /dev/disk device.
  hdiutil makehybrid -hfs -hfs-volume-name "Skybreak Arena 1.1" -ov -o "$TASK_IMAGE_WORK/filesystem.dmg" "$TASK_STAGE"
  hdiutil convert "$TASK_IMAGE_WORK/filesystem.dmg" -format UDZO -ov -o "$TASK_DMG"
fi
hdiutil verify "$TASK_DMG"
ditto -c -k --sequesterRsrc --keepParent "$TASK_APP" "$TASK_OUT/Skybreak-Arena-1.1-macOS.zip"
echo "PACKAGED $TASK_DMG"
