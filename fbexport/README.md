# FBTokenExport

Tweak iOS (roothide): **mở app Facebook là tự xuất `cookie|token` ra file**, không cần thao tác tay, không XoaInfo, không clipboard phụ thuộc.

## Cơ chế
Inject vào `com.facebook.Facebook`. Khi app mở, tweak:
1. Đọc **access token** (`EAAAAA...`, app id 6628568379) từ keychain của chính app — query các service `com.facebook.graph`, `com.facebook.account.zmshimmed`, `com.facebook.accountstatus`, `com.facebook.tim` (wide query, không set access group → lấy được vì chạy trong tiến trình FB), lấy chuỗi `EAA...` dài nhất. Fallback: quét toàn bộ generic password của app.
2. Gom **cookie** (`c_user;xs;fr;datr;sb`) từ `NSHTTPCookieStorage`.
3. Ghi `<cookie>|<token>` ra:
   - `/var/mobile/Media/1ferver/lua/scripts/fb_cookie_token.txt` (đường dẫn XXTouch — chính)
   - `<container>/Documents/fb_cookie_token.txt` (fallback)
   - + copy vào clipboard chung.
4. Retry mỗi 2s tới ~60s (token keychain có sớm, cookie cần app init xong).

Khác tweak `fbextract` cũ: **bỏ XoaInfo / notification**, ghi thẳng file ở path XXTouch.

## Build (CI)
Push `Tweak.xm`/`Makefile`/`control`/`*.plist` lên nhánh `main` → GitHub Actions (`Randomblock1/theos-action`) tự build và commit `HoaQn.FBTokenExport.deb` + metadata Sileo (`Packages`/`Release`) vào repo. Thêm URL repo (raw/Pages) vào Sileo để cài. Depends: `ellekit`.

## Build tay
Theos roothide: `export THEOS=~/theos && make package FINALPACKAGE=1`. Hoặc có sẵn `.dylib`: `sh build-deb.sh`.

## Dùng (XXTouch)
Cài `.deb` + respring. Chạy `GET_COOKIE_TOKEN_FB.lua`: nó mở FB, chờ file `fb_cookie_token.txt`, đọc + validate `c_user` + token `EAA`, trả `uid, cookie, token`. Ghép vào pipeline push tùy ý.
