# Changelog — HoaQn.FBTokenLogin

Phiên bản tự tăng mỗi lần build (CI). Ghi chú theo từng bản bên dưới.

## 1.0.0 — 2026-11-26
- Bản đầu: inject token+datr+cookie vào keychain app Facebook → login không cần mật khẩu.
- Tweak tự parse acc data `uid|pass|cookie|token`; deploy qua XXTouch `fb_login()`.
- Build tự động qua GitHub Actions.
