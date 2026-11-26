#!/bin/sh
# Tao metadata repo Sileo tu cac .deb trong ./debs
mkdir -p debs
: > Packages
for d in debs/*.deb; do
  [ -f "$d" ] || continue
  dpkg-deb -f "$d" >> Packages
  echo "Filename: $d" >> Packages
  echo "Size: $(wc -c < "$d")" >> Packages
  echo "MD5sum: $(md5sum "$d" 2>/dev/null | cut -d' ' -f1)" >> Packages
  echo "SHA256: $(sha256sum "$d" 2>/dev/null | cut -d' ' -f1)" >> Packages
  echo "" >> Packages
done
bzip2 -kf Packages 2>/dev/null
cat > Release <<EOF
Origin: Manh Repo
Label: Manh Repo
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm64
Components: main
Description: FBTokenLogin - login FB app bang token
EOF
echo "da tao Packages / Packages.bz2 / Release"
