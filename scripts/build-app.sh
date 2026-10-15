#!/bin/bash
# Construiește Dockyard.app în ./dist. Totul rămâne în folderul proiectului.
set -e
cd "$(dirname "$0")/.."

if [[ -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

LOCAL="$PWD/.build/local"
mkdir -p "$LOCAL/tmp" "$LOCAL/module-cache"
export TMPDIR="$LOCAL/tmp"
export CLANG_MODULE_CACHE_PATH="$LOCAL/module-cache"
MARK="$LOCAL/.build-start"; touch "$MARK"
SYS_TMP="$(getconf DARWIN_USER_TEMP_DIR)"
# Compilatorul scrie obligatoriu câteva fișiere în afara proiectului — le ștergem la final.
cleanup_traces() {
  set +e
  find "$SYS_TMP" -maxdepth 1 -name 'TemporaryDirectory.*' -newer "$MARK" -exec rm -rf {} + 2>/dev/null
  find "$SYS_TMP/swift-generated-sources" -maxdepth 1 -name '@__swiftmacro_*Dockyard*' -delete 2>/dev/null
  rmdir "$SYS_TMP/swift-generated-sources" 2>/dev/null
  find "$HOME/.swiftpm" -maxdepth 1 -name security -type l -newer "$MARK" -delete 2>/dev/null
  rm -f "$SYS_TMP"/_Users_*_Dockyard_.build*.lock
  true
}
trap cleanup_traces EXIT
SPM_FLAGS=(--cache-path "$LOCAL/spm-cache" --config-path "$LOCAL/spm-config" --security-path "$LOCAL/spm-security" --manifest-cache local)

echo "▸ Compilez (release)…"
swift build -c release "${SPM_FLAGS[@]}"

APP=dist/Dockyard.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
cp .build/release/Dockyard "$APP/Contents/MacOS/Dockyard"
cp .build/release/DockyardFolder "$APP/Contents/Helpers/DockyardFolder"

echo "▸ Generez iconița…"
ICONSET="$LOCAL/AppIcon.iconset"
rm -rf "$ICONSET"
swift -module-cache-path "$LOCAL/module-cache" scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Dockyard</string>
  <key>CFBundleDisplayName</key><string>Dockyard</string>
  <key>CFBundleIdentifier</key><string>com.andrei.dockyard</string>
  <key>CFBundleExecutable</key><string>Dockyard</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP/Contents/Helpers/DockyardFolder" >/dev/null 2>&1
codesign --force --sign - "$APP" >/dev/null 2>&1
echo "✓ Gata: $APP"
