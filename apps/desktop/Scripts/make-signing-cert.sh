#!/bin/bash
# Creates the self-signed "Mulch Signing" code-signing identity used by release builds.
#
#   Scripts/make-signing-cert.sh            import it into this Mac's login keychain
#   Scripts/make-signing-cert.sh --github   also store it as the repo's Actions secrets
#                                           (MACOS_SIGN_CERT_P12, MACOS_SIGN_CERT_PASSWORD)
#
# A stable identity keeps launch-at-login and privacy grants across updates. GitHub
# secrets are write-only, so the login keychain holds the only readable copy.
set -euo pipefail

NAME="Mulch Signing"
UPLOAD=false
[[ "${1:-}" == "--github" ]] && UPLOAD=true

if security find-identity -p codesigning 2>/dev/null | grep -qF "\"$NAME\""; then
  if $UPLOAD; then
    echo "\"$NAME\" already exists in the keychain. Delete it in Keychain Access to make a fresh one for GitHub." >&2
    exit 1
  fi
  echo "\"$NAME\" already exists."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<EOF
[ req ]
distinguished_name = dn
prompt             = no
x509_extensions    = v3

[ dn ]
CN = $NAME

[ v3 ]
basicConstraints       = critical,CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
subjectKeyIdentifier   = hash
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
  -days 3650 -config "$WORK/cert.cnf" 2>/dev/null

PASSWORD="$(openssl rand -base64 24)"
openssl pkcs12 -export \
  -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -out "$WORK/identity.p12" -passout "pass:$PASSWORD" \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
  -name "$NAME" 2>/dev/null

security import "$WORK/identity.p12" -k ~/Library/Keychains/login.keychain-db \
  -P "$PASSWORD" -T /usr/bin/codesign >/dev/null
echo "Imported \"$NAME\" into the login keychain."

if $UPLOAD; then
  base64 -i "$WORK/identity.p12" | gh secret set MACOS_SIGN_CERT_P12
  printf '%s' "$PASSWORD" | gh secret set MACOS_SIGN_CERT_PASSWORD
  echo "Stored MACOS_SIGN_CERT_P12 and MACOS_SIGN_CERT_PASSWORD as GitHub Actions secrets."
fi
