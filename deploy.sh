#!/bin/sh
# Usage: sh deploy.sh "fbid|token|datr|c_user|xs|fr"
[ -z "$1" ] && echo "usage: deploy.sh \"fbid|token|datr|c_user|xs|fr\"" && exit 1
C=""
for d in /var/mobile/Containers/Data/Application/*/; do
  grep -q com.facebook.Facebook "$d/.com.apple.mobile_container_manager.metadata.plist" 2>/dev/null && C="$d" && break
done
[ -z "$C" ] && echo "khong thay container FB" && exit 1
printf '%s' "$1" > "${C}Documents/fb_login.txt"
chown mobile:mobile "${C}Documents/fb_login.txt"
killall -9 Facebook 2>/dev/null
echo "da ghi fb_login.txt -> mo app Facebook (vd: qua XXTouch app.run) de tweak login"
