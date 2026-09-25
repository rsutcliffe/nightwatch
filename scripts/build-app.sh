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
cp -R Resources/Constellations "$APP/Contents/Resources/"   # the owner's artwork; the widget does not need it
cp NOTICE "$APP/Contents/Resources/NOTICE"

# App icon from the Icon Composer document. With Xcode, actool compiles the Liquid Glass icon (Assets.car) plus a classic
# .icns; macOS 26+ then shows the icon itself rather than inside a grey tile. Without Xcode, a classic .icns only.
# actool needs absolute paths: it resolves relative ones against its own long-lived service's working directory.
ICON="$PWD/Resources/AppIcon/Nightwatch.icon"
if xcrun --find actool >/dev/null 2>&1 && xcrun actool "$ICON" --compile "$PWD/$APP/Contents/Resources" --output-format human-readable-text \
     --errors --output-partial-info-plist "$PWD/build/icon-partial.plist" --app-icon Nightwatch --include-all-app-icons \
     --enable-on-demand-resources NO --development-region en --target-device mac --minimum-deployment-target 14.0 --platform macosx >/dev/null; then
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string Nightwatch" -c "Add :CFBundleIconName string Nightwatch" "$APP/Contents/Info.plist"
  echo "Icon: Liquid Glass (actool) plus .icns"
else
  # An icon failure never stops the build: the app still works with the default icon.
  if swift scripts/make-icns.swift "$ICON/Assets/Nightwatch.png" "$APP/Contents/Resources/Nightwatch.icns"; then
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string Nightwatch" "$APP/Contents/Info.plist"
    echo "Icon: classic .icns (no actool)"
  else
    echo "Icon: none (make-icns failed); the app builds with the default icon"
  fi
fi
# Signed build when an Apple Development identity and a provisioning profile for this bundle id exist:
# WeatherKit then works. Otherwise ad hoc as before, and the app falls back to Open-Meteo.
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/{print $2; exit}')
PROFILE=""
for p in ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.provisionprofile(N) ~/Library/MobileDevice/Provisioning\ Profiles/*.provisionprofile(N); do
  # Development profiles only: a Developer ID profile (ProvisionsAllDevices) belongs to scripts/release.sh.
  PL=$(security cms -D -i "$p" 2>/dev/null) || continue
  if print -r -- "$PL" | grep -q "\.$BUNDLE_ID</string>" && ! print -r -- "$PL" | grep -q "<key>ProvisionsAllDevices</key>"; then PROFILE="$p"; break; fi
done
if [[ -n "$IDENTITY" && -n "$PROFILE" ]]; then
  security cms -D -i "$PROFILE" > build/profile.plist
  TEAM=$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' build/profile.plist)
  cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
  # Desktop widget (v0.6): the app and widget share tonight's snapshot through an App Group named with the team ID (no
  # portal registration needed, spike 25 Sep 2026). The widget is built only when Xcode and xcodegen are present.
  GROUP="$TEAM.$BUNDLE_ID"
  /usr/libexec/PlistBuddy -c "Add :NightwatchAppGroup string $GROUP" "$APP/Contents/Info.plist"
  # The generated project gets the root Package.resolved, so the widget links exactly the dependency versions the app does.
  WIDGET_SKIP=""
  command -v xcodegen >/dev/null || WIDGET_SKIP="xcodegen not installed: brew install xcodegen"
  xcrun --find xcodebuild >/dev/null 2>&1 || WIDGET_SKIP="Xcode not installed"
  PINS=Widget/NightwatchWidget.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
  if [[ -z "$WIDGET_SKIP" ]] && (cd Widget && xcodegen generate --quiet) \
     && mkdir -p "$PINS" && cp Package.resolved "$PINS/" \
     && xcodebuild -project Widget/NightwatchWidget.xcodeproj -scheme NightwatchWidget -configuration Release \
          -derivedDataPath build/widget -onlyUsePackageVersionsFromResolvedFile DEVELOPMENT_TEAM="$TEAM" \
          MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/Nightwatch/Info.plist)" \
          CURRENT_PROJECT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Sources/Nightwatch/Info.plist)" \
          -allowProvisioningUpdates build > build/widget.log 2>&1; then
    mkdir -p "$APP/Contents/PlugIns"
    cp -R build/widget/Build/Products/Release/NightwatchWidget.appex "$APP/Contents/PlugIns/"
    echo "Widget: built and embedded"
  else
    echo "Widget: skipped (${WIDGET_SKIP:-the Xcode build failed; see build/widget.log})"
  fi
  cat > build/Nightwatch.entitlements <<ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.developer.weatherkit</key><true/>
  <key>com.apple.application-identifier</key><string>$TEAM.$BUNDLE_ID</string>
  <key>com.apple.developer.team-identifier</key><string>$TEAM</string>
  <key>com.apple.security.application-groups</key><array><string>$GROUP</string></array>
</dict></plist>
ENT
  codesign --force --sign "$IDENTITY" --entitlements build/Nightwatch.entitlements --options runtime "$APP"
  echo "Signed as $IDENTITY with the WeatherKit entitlement (profile $(basename "$PROFILE"))"
else
  codesign --force --sign - "$APP"
  echo "Signed ad hoc (no Apple Development identity or profile for $BUNDLE_ID): Open-Meteo only"
  echo "Widget: skipped (unsigned build; the widget needs the App Group a signed build carries)"
fi
if [[ "${1:-}" == "--no-install" ]]; then echo "Built $APP"; exit 0; fi
pkill -x Nightwatch || true
# macOS keeps a widget's process alive across reinstalls and goes on drawing with the code it first loaded (on 25 Sep 2026
# the desktop showed a build three hours old). Ending it makes the system relaunch the widget from the new copy.
pkill -f "Nightwatch.app/Contents/PlugIns/NightwatchWidget.appex/" || true
rm -rf /Applications/Nightwatch.app
cp -R "$APP" /Applications/Nightwatch.app
open /Applications/Nightwatch.app
echo "Installed and launched /Applications/Nightwatch.app"
