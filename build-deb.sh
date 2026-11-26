#!/bin/sh
# Dong goi .deb thu cong tu .dylib da build san (FBTokenLogin.dylib)
# Chay tren may co dpkg-deb + ldid (vd chinh iPhone jailbreak)
set -e
PKGROOT=./pkgroot
DL=/var/jb/Library/MobileSubstrate/DynamicLibraries
rm -rf "$PKGROOT"
mkdir -p "$PKGROOT$DL" "$PKGROOT/DEBIAN"
cp FBTokenLogin.dylib "$PKGROOT$DL/FBTokenLogin.dylib"
cp FBTokenLogin.plist "$PKGROOT$DL/FBTokenLogin.plist"
ldid -S "$PKGROOT$DL/FBTokenLogin.dylib"
cp control "$PKGROOT/DEBIAN/control"
dpkg-deb -Zgzip -b "$PKGROOT" com.manh.fbtokenlogin_1.0.0_iphoneos-arm64.deb
echo "xong: com.manh.fbtokenlogin_1.0.0_iphoneos-arm64.deb"
