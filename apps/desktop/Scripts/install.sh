#!/bin/zsh
# Builds Mulch (Stable) from this checkout and installs it to /Applications, replacing
# a running copy. To test a branch without touching the real app, use dev.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/build.sh

osascript -e 'tell application id "com.rafay99.mulch" to quit' >/dev/null 2>&1 || true
for _ in {1..20}; do pgrep -xq Mulch || break; sleep 0.25; done

rm -rf /Applications/Mulch.app
ditto build/Mulch.app /Applications/Mulch.app
open /Applications/Mulch.app
echo "Installed /Applications/Mulch.app"
