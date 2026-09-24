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
# Signed build when an Apple Development identity and a provisioning profile for this bundle id exist:
# WeatherKit then works. Otherwise ad hoc as before, and the app falls back to Open-Meteo.
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/{print $2; exit}')
PROFILE=""
for p in ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.provisionprofile(N) ~/Library/MobileDevice/Provisioning\ Profiles/*.provisionprofile(N); do
  if security cms -D -i "$p" 2>/dev/null | grep -q "\.$BUNDLE_ID</string>"; then PROFILE="$p"; break; fi
done
if [[ -n "$IDENTITY" && -n "$PROFILE" ]]; then
  security cms -D -i "$PROFILE" > build/profile.plist
  TEAM=$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' build/profile.plist)
  cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
  cat > build/Nightwatch.entitlements <<ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.developer.weatherkit</key><true/>
  <key>com.apple.application-identifier</key><string>$TEAM.$BUNDLE_ID</string>
  <key>com.apple.developer.team-identifier</key><string>$TEAM</string>
</dict></plist>
ENT
  codesign --force --sign "$IDENTITY" --entitlements build/Nightwatch.entitlements --options runtime "$APP"
  echo "Signed as $IDENTITY with the WeatherKit entitlement (profile $(basename "$PROFILE"))"
else
  codesign --force --sign - "$APP"
  echo "Signed ad hoc (no Apple Development identity or profile for $BUNDLE_ID): Open-Meteo only"
fi
if [[ "${1:-}" == "--no-install" ]]; then echo "Built $APP"; exit 0; fi
pkill -x Nightwatch || true
rm -rf /Applications/Nightwatch.app
cp -R "$APP" /Applications/Nightwatch.app
open /Applications/Nightwatch.app
echo "Installed and launched /Applications/Nightwatch.app"
