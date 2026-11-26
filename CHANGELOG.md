## 1.0.17 — 2026-11-26
- CI: sinh Packages.gz + packages_list.txt + Release co Date/hash ca 2 file (giong format deb-ios-15)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>

## 1.0.16 — 2026-11-26
- Them tweak FBTokenExport (vao FB tu xuat cookie|token ra path XXTouch) + CI build chung 1 repo

- fbexport/: project Theos rieng (ID com.hoaqn.fbtokenexport), khong dung FBTokenLogin
- build.yml: build ca 2, dpkg-scanpackages liet ke 2 goi -> Sileo hien 2 tweak

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>

## 1.0.15 — 2026-11-26
- Tweak: fast-path access() + build -Os/strip (nhe, khong leak); README dung nguon raw

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>

## 1.0.14 — 2026-11-26
- Go GPG: nguon khong ky (paste domain vao Sileo la cai, flow don gian)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>

## 1.0.11 — 2026-11-26
- FIX: xoa fb_login.txt NGAY sau khi doc (chong crash-loop) + bao @try/@catch toan bo (khong lam crash FB)

## 1.0.9 — 2026-11-26
- CI: auto bat + deploy GitHub Pages (nguon Sileo on dinh, khong lech cache)

## 1.0.7 — 2026-11-26
- Author=roothide; version tu tang theo run_number; CI tu ghi CHANGELOG moi ban

# Changelog — HoaQn.FBTokenLogin

Phiên bản tự tăng mỗi lần build (CI). Ghi chú theo từng bản bên dưới.

## 1.0.0 — 2026-11-26
- Bản đầu: inject token+datr+cookie vào keychain app Facebook → login không cần mật khẩu.
- Tweak tự parse acc data `uid|pass|cookie|token`; deploy qua XXTouch `fb_login()`.
- Build tự động qua GitHub Actions.
