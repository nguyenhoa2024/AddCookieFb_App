#!/bin/sh
# Them nguon "FB Token Login" vao Sileo roothide — nguon DA KY GPG (khong can Trusted:yes).
# Chay 1 lan tren moi may (qua SSH hoac trong provisioning). Doi URL neu ban doi repo.
set -e
BASE="https://cdn.jsdelivr.net/gh/nguyenhoa2024/AddCookieFb_App@main"
KEYDIR=/var/jb/etc/apt/keyrings
SRC=/var/jb/etc/apt/sources.list.d/hoaqn.sources

mkdir -p "$KEYDIR"
curl -fsSL -o "$KEYDIR/hoaqn.gpg" "$BASE/hoaqn.gpg"

cat > "$SRC" <<EOF
Types: deb
URIs: $BASE/
Suites: ./
Components:
Signed-By: $KEYDIR/hoaqn.gpg
EOF

apt-get update
echo "DONE — mo Sileo, cai goi 'FB Token Login'."
