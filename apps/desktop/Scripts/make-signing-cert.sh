#!/bin/bash
# Creates a self-signed code-signing identity in the login keychain. Run once per Mac.
# A stable identity keeps launch-at-login and privacy grants across rebuilds.
set -euo pipefail

NAME="${1:-Mulch Signing}"
if security find-identity -p codesigning 2>/dev/null | grep -qF "\"$NAME\""; then
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
  -P "$PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s \
  -k "$(security find-generic-password -ws 'login' 2>/dev/null || true)" \
  ~/Library/Keychains/login.keychain-db >/dev/null 2>&1 || \
  echo "note: macOS will ask to allow codesign on first use."

echo "Created \"$NAME\". Scripts/build.sh uses it automatically."
