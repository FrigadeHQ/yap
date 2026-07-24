#!/usr/bin/env bash
#
# Builds, signs, notarizes, staples, and packages Yap for distribution.
#
# Prerequisites (one-time):
#   1. A "Developer ID Application" certificate in your keychain (create it in
#      Xcode: Settings > Accounts > Manage Certificates > + ).
#   2. Notarization credentials stored under the profile name below:
#        xcrun notarytool store-credentials yap-notary \
#          --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
#
# Output: dist/Yap.dmg — a notarized, stapled disk image ready to hand out.

set -euo pipefail

APP="Yap"
SCHEME="Yap"
CONFIG="Release"
BUILD_DIR="build"
DIST_DIR="dist"
ENTITLEMENTS="Sources/Yap.entitlements"
NOTARY_PROFILE="${YAP_NOTARY_PROFILE:-yap-notary}"

info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
fail() { printf "\033[1;31mError:\033[0m %s\n" "$1" >&2; exit 1; }

# --- 1. Find the Developer ID Application identity -------------------------------
IDENTITY=$(security find-identity -v -p codesigning \
  | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)".*/\1/')
[ -n "$IDENTITY" ] || fail "No 'Developer ID Application' certificate found. Create one in Xcode first."
info "Signing as: $IDENTITY"

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || fail "Notarization profile '$NOTARY_PROFILE' not set up. See the header of this script."

# --- 2. Build -------------------------------------------------------------------
info "Generating project"
xcodegen generate

info "Building $CONFIG"
xcodebuild -project "$APP.xcodeproj" -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  clean build | grep -E "error:|BUILD" || true

APP_PATH="$BUILD_DIR/Build/Products/$CONFIG/$APP.app"
[ -d "$APP_PATH" ] || fail "Build did not produce $APP_PATH"

# --- 3. Sign, inside-out, with Hardened Runtime + secure timestamp --------------
info "Signing nested code"
while IFS= read -r nested; do
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$nested"
done < <(find "$APP_PATH/Contents" \( -name "*.framework" -o -name "*.dylib" -o -name "*.bundle" \))

info "Signing app"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" "$APP_PATH"

codesign --verify --strict --verbose=2 "$APP_PATH"

# --- 4. Package a drag-to-install DMG -------------------------------------------
info "Building disk image"
mkdir -p "$DIST_DIR"
STAGING=$(mktemp -d)
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
DMG="$DIST_DIR/$APP.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

# --- 5. Notarize + staple -------------------------------------------------------
info "Submitting for notarization (this waits for Apple)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

info "Stapling ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

info "Done: $DMG"
spctl -a -t open --context context:primary-signature -v "$DMG" 2>&1 || true
