# Changelog — HoaQn.FBTokenLogin

Ghi chú cập nhật theo từng bản .deb.

## 1.0.0 — 2026-11-26
- Bản đầu tiên.
- Inject access token (EAAAAA / app 6628568379) + datr + cookie vào keychain app Facebook → login không cần mật khẩu.
- Tweak tự parse nguyên dòng acc data: `uid|pass|cookie|token`.
- Deploy từ XXTouch qua `fb_login(acc_line)` (ghi `Documents/fb_login.txt` → mở app).
- Build tự động bằng GitHub Actions, publish repo Sileo.
