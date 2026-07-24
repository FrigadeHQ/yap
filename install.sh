#!/usr/bin/env bash
#
# Builds Yap from source and installs it into /Applications.
#
# For local development. Released builds are signed and notarized; this one is
# signed ad-hoc, which means macOS treats every rebuild as a new application and
# forgets the permissions you granted the previous one. Yap has a
# "Reset and re-grant" button in Settings for that.

set -euo pipefail

APP_NAME="Yap"
BUILD_DIR="build"
INSTALL_DIR="/Applications"
CONFIGURATION="${CONFIGURATION:-Release}"

info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
fail() { printf "\033[1;31mError:\033[0m %s\n" "$1" >&2; exit 1; }

# Prerequisites
command -v xcodebuild >/dev/null 2>&1 || fail "Xcode is required. Install it from the App Store, then run: xcode-select --install"

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    info "Installing XcodeGen"
    brew install xcodegen
  else
    fail "XcodeGen is required. Install Homebrew from https://brew.sh, then run: brew install xcodegen"
  fi
fi

info "Generating Xcode project"
xcodegen generate

info "Building $APP_NAME ($CONFIGURATION)"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  build \
  | grep -E "error:|warning:|BUILD" || true

BUILT_APP="$BUILD_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
[ -d "$BUILT_APP" ] || fail "Build did not produce $BUILT_APP"

if pgrep -f "$INSTALL_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
  info "Quitting the running copy"
  killall "$APP_NAME" 2>/dev/null || true
  sleep 1
fi

info "Installing to $INSTALL_DIR/$APP_NAME.app"
rm -rf "${INSTALL_DIR:?}/$APP_NAME.app"
cp -R "$BUILT_APP" "$INSTALL_DIR/"

info "Launching"
open "$INSTALL_DIR/$APP_NAME.app"

cat <<EOF

$APP_NAME is installed and running. Look for the microphone in your menu bar.

Grant the four permissions it asks for, then press the shortcut and start talking.
The default is Cmd+Shift+D, and you can change it in Settings.
EOF
