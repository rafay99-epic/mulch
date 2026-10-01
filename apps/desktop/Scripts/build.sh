#!/bin/zsh
# Builds build/<app name>.app (arm64, release) from the SwiftPM package.
#
#   MULCH_CHANNEL=stable   Mulch.app      com.rafay99.mulch       (default, released from main)
#   MULCH_CHANNEL=dev      Mulch Dev.app  com.rafay99.mulch.dev   (local, never updates)
#
# Signs with a stable identity so launch-at-login and privacy grants survive rebuilds:
# CODESIGN_IDENTITY if set, else your Apple Development cert, else "Mulch Signing"
# (made by make-signing-cert.sh), else ad-hoc.
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

# Identity order: $CODESIGN_IDENTITY, an Apple Development cert, "Mulch Signing", ad-hoc.
IDENTITIES="$(security find-identity -p codesigning 2>/dev/null || true)"
IDENTITY="${CODESIGN_IDENTITY:-$(grep -o '"Apple Development: [^"]*"' <<< "$IDENTITIES" | head -1 | tr -d '"')}"
IDENTITY="${IDENTITY:-Mulch Signing}"
if ! grep -qF "\"$IDENTITY\"" <<< "$IDENTITIES"; then
  echo "Signing identity \"$IDENTITY\" not found; signing ad-hoc. Run Scripts/make-signing-cert.sh once to fix." >&2
  IDENTITY="-"
fi
codesign --force --sign "$IDENTITY" "$APP"
echo "Signed with: $IDENTITY"

echo "Built $PWD/$APP ($CHANNEL $VERSION, $COMMIT, macOS $MIN_OS+, SDK $SDK_VERSION)"
