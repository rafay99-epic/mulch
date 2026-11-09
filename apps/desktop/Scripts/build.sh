#!/bin/zsh
# Builds build/<app name>.app (arm64, release) from the SwiftPM package.
#
#   MULCH_CHANNEL=stable   Mulch.app      com.rafay99.mulch       (default, released from main)
#   MULCH_CHANNEL=dev      Mulch Dev.app  com.rafay99.mulch.dev   (local, never updates)
#
# Signs with the team's Developer ID Application certificate (hardened runtime +
# secure timestamp, which notarization needs). There is no fallback: a missing
# identity fails the build. Scripts/package.sh zips and notarizes the result.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -x "$(xcode-select -p 2>/dev/null)/usr/bin/xcodebuild" ]]; then
  echo "Mulch needs full Xcode 26 or newer: sudo xcode-select --switch /Applications/Xcode.app" >&2
  exit 1
fi

CHANNEL="${MULCH_CHANNEL:-stable}"
case "$CHANNEL" in
  stable) APP_NAME="Mulch";     BUNDLE_ID="com.rafay99.mulch";     ICON="Resources/AppIcon.icns" ;;
  dev)    APP_NAME="Mulch Dev"; BUNDLE_ID="com.rafay99.mulch.dev"; ICON="Resources/AppIcon-Dev.icns" ;;
  *) echo "MULCH_CHANNEL must be stable or dev (got '$CHANNEL')" >&2; exit 1 ;;
esac
APP="build/$APP_NAME.app"

echo "Compiling arm64 release…  [$CHANNEL]"
swift build -c release --arch arm64
BINARY="$(swift build -c release --arch arm64 --show-bin-path)/Mulch"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"

# Stamp the SDK version so macOS applies current-SDK behaviour.
MIN_OS="$(vtool -show-build "$BINARY" | awk '/minos/ {print $2; exit}')"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
vtool -set-build-version macos "$MIN_OS" "$SDK_VERSION" -replace \
  -output "$APP/Contents/MacOS/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

cp Resources/Info.plist "$APP/Contents/Info.plist"
# The version is a plain integer the updater compares: the commit count, which CI
# passes as MULCH_VERSION for releases from main.
VERSION="${MULCH_VERSION:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}"
COMMIT="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')@$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
PB=/usr/libexec/PlistBuddy
PLIST="$APP/Contents/Info.plist"
$PB -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
$PB -c "Set :CFBundleVersion $VERSION" "$PLIST"
$PB -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
$PB -c "Set :CFBundleName $APP_NAME" "$PLIST"
$PB -c "Set :CFBundleExecutable $APP_NAME" "$PLIST"
$PB -c "Set :CFBundleDisplayName $APP_NAME" "$PLIST"
$PB -c "Add :MulchChannel string $CHANNEL" "$PLIST"
$PB -c "Add :MulchCommit string $COMMIT" "$PLIST"

if [[ ! -f "$ICON" ]]; then
  echo "Rendering icon…"
  PNG="$(mktemp -d)/icon.png"
  ICONSET="$(mktemp -d)/Mulch.iconset"
  mkdir -p "$ICONSET"
  swift Scripts/MakeIcon.swift "$PNG" "$CHANNEL"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$PNG" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$PNG" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$ICON"
fi
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

# Code signing. Every build, local or CI, signs with the Developer ID: the
# designated requirement is the Team ID, so launch-at-login and privacy grants
# survive updates and rebuilds. CODESIGN_IDENTITY overrides the identity.
# CODESIGN_KEYCHAIN (set by sign.sh) signs from an unlocked throwaway keychain,
# so no keychain dialog blocks a run. One binary, no nested code, no entitlements:
# Mulch only spawns processes and uses SMAppService, which the runtime allows.
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Syntax Labs (Private) Limited (MGH5K382YN)}"
# Captured first: `grep -q` exiting early under pipefail can fail on SIGPIPE.
IDENTITIES="$(security find-identity -p codesigning ${CODESIGN_KEYCHAIN:+"$CODESIGN_KEYCHAIN"})"
if ! grep -qF "\"$IDENTITY\"" <<< "$IDENTITIES"; then
  echo "error: \"$IDENTITY\" is not in the keychain. Use Scripts/sign.sh, or import ~/.vitals-signing/developer-id.p12." >&2
  exit 1
fi
KEYCHAIN_ARGS=()
[[ -n "${CODESIGN_KEYCHAIN:-}" ]] && KEYCHAIN_ARGS=(--keychain "$CODESIGN_KEYCHAIN")
codesign --force --options runtime --timestamp "${KEYCHAIN_ARGS[@]}" --sign "$IDENTITY" "$APP"
codesign --verify --strict --deep "$APP"
echo "Signed with: $IDENTITY (hardened runtime)"

echo "Built $PWD/$APP ($CHANNEL $VERSION, $COMMIT, macOS $MIN_OS+, SDK $SDK_VERSION)"
