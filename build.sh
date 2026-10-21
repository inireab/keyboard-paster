#!/bin/bash
# Builds ~/Applications/KeyboardPaster.app so Accessibility access is granted to the app itself,
# not to Terminal. Launch it from Finder/Spotlight or with: open ~/Applications/KeyboardPaster.app
set -euo pipefail

cd "$(dirname "$0")"
APP="$HOME/Applications/KeyboardPaster.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 KeyboardPaster.swift -o "$APP/Contents/MacOS/KeyboardPaster"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>      <string>local.kbpaster</string>
    <key>CFBundleName</key>            <string>Keyboard Paster</string>
    <key>CFBundleDisplayName</key>     <string>Keyboard Paster</string>
    <key>CFBundleExecutable</key>      <string>KeyboardPaster</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
</dict>
</plist>
PLIST

# Ad-hoc signature: macOS ties the Accessibility grant to it, so re-grant after each rebuild.
codesign --force --sign - --identifier local.kbpaster "$APP"
echo "Built $APP"
