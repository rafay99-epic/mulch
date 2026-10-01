#!/bin/bash
# Imports the release signing identity from Actions secrets into a temporary keychain
# and exports CODESIGN_IDENTITY for build.sh. Fails without the secrets: an unsigned
# release would lose launch-at-login and privacy grants on update.
set -euo pipefail

if [ -z "${MACOS_SIGN_CERT_P12:-}" ] || [ -z "${MACOS_SIGN_CERT_PASSWORD:-}" ]; then
  echo "::error::MACOS_SIGN_CERT_P12 / MACOS_SIGN_CERT_PASSWORD are missing. Run apps/desktop/Scripts/make-signing-cert.sh --github."
  exit 1
fi

KEYCHAIN="$RUNNER_TEMP/mulch-signing.keychain-db"
KEYCHAIN_PW="$(openssl rand -base64 24)"
CERT_P12="$RUNNER_TEMP/mulch-signing.p12"
trap 'rm -f "$CERT_P12"' EXIT

security create-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
echo "$MACOS_SIGN_CERT_P12" | base64 --decode > "$CERT_P12"
security import "$CERT_P12" -k "$KEYCHAIN" -P "$MACOS_SIGN_CERT_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PW" "$KEYCHAIN" >/dev/null

# Put the new keychain first in the search list, keeping the existing ones.
existing=()
while IFS= read -r kc; do
  kc="${kc//\"/}"; kc="${kc#"${kc%%[![:space:]]*}"}"
  [ -n "$kc" ] && existing+=("$kc")
done < <(security list-keychains -d user)
security list-keychains -d user -s "$KEYCHAIN" "${existing[@]}"

IDENTITY="$(security find-identity -p codesigning "$KEYCHAIN" | sed -n 's/.*"\(.*\)".*/\1/p' | head -1)"
[ -n "$IDENTITY" ] || { echo "::error::No code-signing identity found after import."; exit 1; }
echo "CODESIGN_IDENTITY=$IDENTITY" >> "$GITHUB_ENV"
echo "Signing identity: $IDENTITY"
