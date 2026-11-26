# FBTokenLogin

Tweak iOS: **login app Facebook chỉ bằng token (+datr+cookie), không cần mật khẩu, không thao tác tay**. Dùng cho jailbreak roothide (đã test iPhone 6s / iOS 15.8.8).

## Cơ chế
Tweak inject vào tiến trình `com.facebook.Facebook` (dùng keychain-access-groups của chính app). Khi app mở, `%ctor` đọc file `Documents/fb_login.txt` trong container FB; nếu có thì:
1. Ghi **access token** (chuỗi `EAAAAA...`, app id 6628568379) vào 3 keychain item: `com.facebook.graph`, `facebook.activeaccount`, `group.com.facebook.family.appgrouptokenshare` (acct = FBID).
2. Ghi **datr** vào keychain `com.facebook.datr` + cookie (chống die — đồng bộ device identity).
3. Set cookie `c_user/xs/fr/datr`.
4. Ghi `Documents/FBAPISessionLoggedInUserIDCache` = FBID.
5. Xoá `fb_login.txt` (chạy 1 lần).

App đọc keychain lúc khởi động → **login luôn trong lần mở đó** (không cần cold-start lại).

## ⚠️ Điều kiện (quan trọng, không là DIE)
- **Token phải đúng app Facebook-iOS (app id 6628568379)** → prefix `EAAAAA...`. Token app khác (`EAAG`, `EAAB`, token page/business) → app đá ra "Phiên đã hết hạn".
- Token + datr + cookie **cùng 1 acc, đồng bộ**.
- Device (VietSpoof): **mỗi acc 1 bộ cố định**, không đổi loạn.
- **IP/proxy khớp vùng** của acc.
- **Warm-up** (idle/lướt) trước khi làm action.

## Format acc data
1 dòng, phân tách bằng `|`:
```
fbid|token|datr|c_user|xs|fr
```
`datr` trở đi là optional nhưng **nên có đủ** để chống die. (Nếu acc data gốc của bạn là `uid|pass|cookie|token` thì parse ra: fbid=uid, token=phần EAAAAA, datr/c_user/xs/fr tách từ cookie.)

## Build
Cần Theos của **roothide** (môi trường đã build VietSpoof):
```
export THEOS=~/theos
make clean
make package FINALPACKAGE=1
```
Ra file `.deb` trong `packages/`. (Hoặc nếu đã có `FBTokenLogin.dylib` build sẵn: `sh build-deb.sh`.)

## Cài
- Đưa `.deb` vào repo Sileo (xem dưới) rồi cài qua Sileo trên từng máy, **hoặc** copy `.deb` lên máy và `dpkg -i`. Depends: `ellekit`.
- Sau cài: respring. Tweak chỉ inject vào app Facebook.

## Deploy / login 1 acc
- **XXTouch**: sửa biến `DATA` trong `deploy.lua` rồi chạy — nó ghi `fb_login.txt` vào container FB và mở app.
- **SSH**: `sh deploy.sh "fbid|token|datr|c_user|xs|fr"` rồi mở app Facebook (vd qua XXTouch `app.run`).

Chạy hàng loạt: lặp qua danh sách acc, mỗi acc gọi deploy rồi mở app, kiểm tra kết quả, logout (xoá 3 keychain + file) trước acc tiếp theo.

## Nguồn Sileo
Repo build sẵn qua GitHub Actions, phục vụ qua jsDelivr. Thêm nguồn này vào Sileo:
```
https://cdn.jsdelivr.net/gh/nguyenhoa2024/AddCookieFb_App@main/
```
Repo không ký (chuẩn repo jB cá nhân). Sileo roothide thêm xong có thể hiện cảnh báo "untrusted repo" — bấm qua là cài được. Rồi cài gói **FB Token Login**.

Repo chỉ serve 1 file index `Packages` (không bz2/gz) để tránh jsDelivr cache-skew gây lỗi "Hash invalid".
