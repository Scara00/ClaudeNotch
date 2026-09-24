#!/bin/zsh
# Compila ClaudeNotch e crea ClaudeNotch.app (in ./build e, con --install, in /Applications)
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/ClaudeNotch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ClaudeNotch "$APP/Contents/MacOS/"
[[ -f Resources/AppIcon.icns ]] || swift Scripts/make_icon.swift
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>ClaudeNotch</string>
  <key>CFBundleIdentifier</key><string>com.italianscodeitbetter.claudenotch</string>
  <key>CFBundleExecutable</key><string>ClaudeNotch</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
if [[ "$1" == "--install" ]]; then
  pkill -x ClaudeNotch || true
  rm -rf /Applications/ClaudeNotch.app
  cp -R "$APP" /Applications/
  open /Applications/ClaudeNotch.app
  echo "Installata e avviata da /Applications"
else
  echo "Creata $APP — avviala con: open $APP"
fi
