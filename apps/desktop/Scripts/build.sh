#!/bin/zsh
# Builds build/Mulch.app (arm64, release) from the SwiftPM package.
# Signs with a stable identity so launch-at-login and privacy grants survive rebuilds:
# CODESIGN_IDENTITY if set, else your Apple Development cert, else "Mulch Signing"
# (made by make-signing-cert.sh), else ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -x "$(xcode-select -p 2>/dev/null)/usr/bin/xcodebuild" ]]; then
  echo "Mulch needs full Xcode 26 or newer: sudo xcode-select --switch /Applications/Xcode.app" >&2
  exit 1
fi

APP_NAME="Mulch"
APP="build/$APP_NAME.app"
ICON="Resources/AppIcon.icns"

echo "Compiling arm64 release…"
swift build -c release --arch arm64
BINARY="$(swift build -c release --arch arm64 --show-bin-path)/$APP_NAME"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"

# Stamp the SDK version so macOS applies current-SDK behaviour.
MIN_OS="$(vtool -show-build "$BINARY" | awk '/minos/ {print $2; exit}')"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
vtool -set-build-version macos "$MIN_OS" "$SDK_VERSION" -replace \
  -output "$APP/Contents/MacOS/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

cp Resources/Info.plist "$APP/Contents/Info.plist"
# The version is the commit count on this branch, e.g. 42; CI passes MULCH_VERSION.
VERSION="${MULCH_VERSION:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"

if [[ ! -f "$ICON" ]]; then
  echo "Rendering icon…"
  PNG="$(mktemp -d)/icon.png"
  ICONSET="$(mktemp -d)/Mulch.iconset"
  mkdir -p "$ICONSET"
  swift Scripts/MakeIcon.swift "$PNG"
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

echo "Built $PWD/$APP ($VERSION, macOS $MIN_OS+, SDK $SDK_VERSION)"
