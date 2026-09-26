#!/bin/zsh
# Builds the Mac App Store package, build/appstore/Nightwatch-<version>.pkg: the APPSTORE variant of the same code (no
# update check, Sources/Nightwatch/Distribution.swift), signed with the Apple Distribution certificate and the two Mac App
# Store profiles, packaged and signed for upload with Apple's Transporter app. The one-off setup is in docs/app-store.md.
#
# usage: scripts/appstore.sh
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { print -u2 "appstore: $1"; exit 1 }

# 1. Prerequisites (docs/app-store.md): two certificates and a Mac App Store profile for the app and for the widget.
IDENTITY=${NIGHTWATCH_APPSTORE_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Distribution/{print $2; exit}')}
[[ -n "$IDENTITY" ]] || fail "no 'Apple Distribution' certificate in the keychain (docs/app-store.md, step 1)"
INSTALLER=${NIGHTWATCH_INSTALLER_IDENTITY:-$(security find-identity -v -p basic | awk -F'"' '/3rd Party Mac Developer Installer|Mac Installer Distribution/{print $2; exit}')}
[[ -n "$INSTALLER" ]] || fail "no 'Mac Installer Distribution' certificate in the keychain (docs/app-store.md, step 1)"
TEAM=$(security find-certificate -c "$IDENTITY" -p | openssl x509 -noout -subject | tr ',' '\n' | sed -n 's/^ *OU *= *//p' | head -1)
[[ -n "$TEAM" ]] || fail "could not read the team ID from the certificate '$IDENTITY'"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Sources/Nightwatch/Info.plist)
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/Nightwatch/Info.plist)
WIDGET_ID="$BUNDLE_ID.widget"
GROUP="$TEAM.$BUNDLE_ID"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# A Mac App Store profile names the bundle, provisions no devices and is not Developer ID (which provisions all devices).
store_profile() {
  for p in ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.provisionprofile(N) ~/Library/MobileDevice/Provisioning\ Profiles/*.provisionprofile(N); do
    security cms -D -i "$p" > "$WORK/p.plist" 2>/dev/null || continue
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$WORK/p.plist" 2>/dev/null)" == "$TEAM.$1" ]] || continue
    /usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$WORK/p.plist" >/dev/null 2>&1 && continue
    /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$WORK/p.plist" >/dev/null 2>&1 && continue
    print -r -- "$p"; return
  done
}
APP_PROFILE=$(store_profile "$BUNDLE_ID"); WIDGET_PROFILE=$(store_profile "$WIDGET_ID")
[[ -n "$APP_PROFILE" ]] || fail "no Mac App Store profile for $BUNDLE_ID (docs/app-store.md, step 3)"
[[ -n "$WIDGET_PROFILE" ]] || fail "no Mac App Store profile for $WIDGET_ID (docs/app-store.md, step 3)"

# 2. Build the App Store variant with the everyday script, then re-sign both bundles for the store.
NIGHTWATCH_APPSTORE=1 scripts/build-app.sh --no-install
SRC=build/Nightwatch.app
[[ -d "$SRC/Contents/PlugIns/NightwatchWidget.appex" ]] || fail "the build has no widget (see build/widget.log)"
OUT=build/appstore; mkdir -p "$OUT"
APP="$WORK/Nightwatch.app"; ditto "$SRC" "$APP"
APPEX="$APP/Contents/PlugIns/NightwatchWidget.appex"
cp "$APP_PROFILE" "$APP/Contents/embedded.provisionprofile"
cp "$WIDGET_PROFILE" "$APPEX/Contents/embedded.provisionprofile"

# The store build carries no temporary sandbox exceptions and no file-picker access: there are no 0.6 settings to import.
cat > "$WORK/widget.entitlements" <<ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.application-identifier</key><string>$TEAM.$WIDGET_ID</string>
  <key>com.apple.developer.team-identifier</key><string>$TEAM</string>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.application-groups</key><array><string>$GROUP</string></array>
</dict></plist>
ENT
cat > "$WORK/app.entitlements" <<ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.application-identifier</key><string>$TEAM.$BUNDLE_ID</string>
  <key>com.apple.developer.team-identifier</key><string>$TEAM</string>
  <key>com.apple.developer.weatherkit</key><true/>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.network.client</key><true/>
  <key>com.apple.security.personal-information.location</key><true/>
  <key>com.apple.security.application-groups</key><array><string>$GROUP</string></array>
</dict></plist>
ENT
# Inside out: the widget first, so the app's seal records the widget's new signature.
codesign --force --options runtime --entitlements "$WORK/widget.entitlements" --sign "$IDENTITY" "$APPEX"
codesign --force --options runtime --entitlements "$WORK/app.entitlements" --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# 3. Guard the difference between the builds before packaging.
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q temporary-exception && fail "the store build must carry no temporary sandbox exception"
strings "$APP/Contents/MacOS/Nightwatch" | grep -q "Check for a new version once a day" && fail "the store build still has the update check: was it built with -DAPPSTORE?"

# 4. Package for upload.
PKG="$OUT/Nightwatch-$VERSION.pkg"
productbuild --component "$APP" /Applications --sign "$INSTALLER" "$PKG"
pkgutil --check-signature "$PKG" | head -3
print "Ready: $PKG (version $VERSION, build $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"))"
print "Upload it with Apple's Transporter app: open -a Transporter \"$PKG\""
