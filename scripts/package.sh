#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PROFILE=release
if [[ "${1:-}" == "--debug" && "$#" == 1 ]]; then
    PROFILE=debug
elif [[ "$#" != 0 ]]; then
    printf 'Usage: %s [--debug]\n' "$0" >&2
    exit 2
fi
swift build -c "$PROFILE"
BIN_DIR="$(swift build -c "$PROFILE" --show-bin-path)"
APP="$ROOT/dist/Quick Cast.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/quick-cast" "$APP/Contents/MacOS/quick-cast"
xcrun swift "$ROOT/scripts/generate-icon.swift" "$APP/Contents/Resources"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleDisplayName</key><string>Quick Cast</string>
<key>CFBundleExecutable</key><string>quick-cast</string>
<key>CFBundleIdentifier</key><string>dev.cesar.quickcast</string>
<key>CFBundleIconFile</key><string>QuickCast</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>Quick Cast</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSInputMonitoringUsageDescription</key><string>Quick Cast displays your keyboard shortcuts in a floating overlay for demos and recordings.</string>
</dict></plist>
PLIST
plutil -lint "$APP/Contents/Info.plist"
SIGNING_IDENTITY="${SIGN_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ { print $2; exit }')"
fi
if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY=-
    printf 'No Apple Development identity found; using ad-hoc signing. Permissions may need refreshing after rebuilds.\n' >&2
fi
codesign --force --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
printf '\nPackaged: %s\n' "$APP"
