#!/bin/zsh
# Installs the latest Stable GitHub release to /Applications, replacing a running copy.
# Needs `gh`. Mulch updates itself after that; `brew install --cask rafay99-epic/apps/mulch` also works.
set -euo pipefail

REPO="rafay99-epic/mulch"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

gh release download --repo "$REPO" --pattern 'Mulch.zip' --dir "$WORK"
ditto -x -k "$WORK/Mulch.zip" "$WORK"

osascript -e 'tell application id "com.rafay99.mulch" to quit' >/dev/null 2>&1 || true
for _ in {1..20}; do pgrep -xq Mulch || break; sleep 0.25; done

rm -rf /Applications/Mulch.app
ditto "$WORK/Mulch.app" /Applications/Mulch.app
xattr -dr com.apple.quarantine /Applications/Mulch.app 2>/dev/null || true
open /Applications/Mulch.app
echo "Installed Mulch $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/Mulch.app/Contents/Info.plist)"
