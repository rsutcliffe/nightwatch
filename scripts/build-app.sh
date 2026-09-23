#!/bin/zsh
# Builds Nightwatch.app with SwiftPM only, signs it ad hoc, installs to /Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Nightwatch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Sources/Nightwatch/Info.plist "$APP/Contents/Info.plist"
cp .build/release/Nightwatch "$APP/Contents/MacOS/Nightwatch"
cp -R .build/release/Nightwatch_SkyCore.bundle "$APP/Contents/Resources/"
cp NOTICE "$APP/Contents/Resources/NOTICE"
codesign --force --sign - "$APP"
if [[ "${1:-}" == "--no-install" ]]; then echo "Built $APP"; exit 0; fi
pkill -x Nightwatch || true
rm -rf /Applications/Nightwatch.app
cp -R "$APP" /Applications/Nightwatch.app
open /Applications/Nightwatch.app
echo "Installed and launched /Applications/Nightwatch.app"
