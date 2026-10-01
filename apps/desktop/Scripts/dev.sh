#!/bin/zsh
# Builds Mulch Dev from this checkout and installs it to /Applications, next to
# Mulch. Own bundle ID, config (~/.config/mulch-dev), history and
# log, and it never updates itself, so testing a branch never touches the real app.
set -euo pipefail
cd "$(dirname "$0")/.."

MULCH_CHANNEL=dev ./Scripts/build.sh

osascript -e 'tell application id "com.rafay99.mulch.dev" to quit' >/dev/null 2>&1 || true
for _ in {1..20}; do pgrep -xq "Mulch Dev" || break; sleep 0.25; done

rm -rf "/Applications/Mulch Dev.app"
ditto "build/Mulch Dev.app" "/Applications/Mulch Dev.app"
open "/Applications/Mulch Dev.app"
echo "Installed Mulch Dev from $(git rev-parse --abbrev-ref HEAD)@$(git rev-parse --short HEAD). Log: ~/Library/Logs/Mulch Dev/activity.log"
