#!/bin/zsh
# Zips build/Mulch.app into build/Mulch.zip, the asset the updater and the Homebrew
# cask download. With NOTARY_* set (CI's setup-signing.sh, or sign.sh) it first
# notarizes the app, staples the ticket onto it, and zips the stapled app, so
# Gatekeeper passes it offline. A rejection fails, so an un-notarized build never ships.
# Run Scripts/build.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Mulch.app"
ZIP="build/Mulch.zip"
[[ -d "$APP" ]] || { echo "Missing $APP; run Scripts/build.sh first." >&2; exit 1; }

zip_app() { rm -f "$ZIP"; ditto -c -k --keepParent "$APP" "$ZIP"; }
zip_app

if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
  echo "Notarizing $APP…"
  NOTARY=(--key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER:?}")
  SUBMISSION="$(xcrun notarytool submit "$ZIP" "${NOTARY[@]}" --output-format json)"
  ID="$(plutil -extract id raw -o - - <<< "$SUBMISSION")"
  echo "Submission $ID"
  # Apple can take over 30 minutes, and a single status request can time out,
  # which ends `notarytool wait`. Retry the wait so a dropped request isn't a
  # failed release. All attempts share one 2-hour deadline.
  STATUS=""
  DEADLINE=$((SECONDS + 7200))
  for attempt in 1 2 3 4 5; do
    LEFT=$((DEADLINE - SECONDS))
    (( LEFT > 0 )) || break
    RESULT="$(xcrun notarytool wait "$ID" "${NOTARY[@]}" --timeout "${LEFT}s" --output-format json || true)"
    STATUS="$(plutil -extract status raw -o - - <<< "$RESULT" 2>/dev/null || true)"
    [[ -n "$STATUS" ]] && break
    echo "Notary status check failed (attempt $attempt/5), retrying"
  done
  echo "Notarization status: ${STATUS:-unknown}"
  if [[ "$STATUS" != "Accepted" ]]; then
    xcrun notarytool log "$ID" "${NOTARY[@]}" || true
    echo "error: notarization was not accepted" >&2
    exit 1
  fi
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  zip_app
fi
echo "Packaged $PWD/$ZIP"
