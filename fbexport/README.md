# FBTokenExport

Tweak iOS (roothide): inject vào `com.facebook.Facebook`, mở **endpoint HTTP localhost** để XXTouch **gọi mới lấy** `cookie|token` — **không tự xuất khi vào app nữa**.

## Cơ chế
Inject vào `com.facebook.Facebook`. Khi app chạy, tweak mở socket nghe tại **`127.0.0.1:46980`** (chỉ loopback, không ra ngoài mạng). Tweak **đứng im** cho tới khi có request:

1. XXTouch gọi `http.get("http://127.0.0.1:46980/...")`.
2. Tweak mới đọc **access token** (`EAAAAA...`, app id 6628568379) từ keychain — service `com.facebook.graph`, `com.facebook.account.zmshimmed`, `com.facebook.accountstatus`, `com.facebook.tim` (kèm `kSecAttrAccount`). **Chống token cũ**: chỉ lấy token có `account == c_user` đang đăng nhập; nhiều token mà không khớp acc thì **không trả** (tránh token acc cũ còn sót). Chỉ 1 token duy nhất thì dùng luôn.
3. Gom **cookie** (`c_user;xs;fr;datr;sb`) từ `NSHTTPCookieStorage`.
4. **Trả `<cookie>|<token>` trong body HTTP** (200). Đồng thời set clipboard + **toast** "✅ FB Cookie|Token da tra (XXTouch goi)" để nhận biết.
5. Chưa đủ cookie/token khớp acc → trả **503** (XXTouch retry).

> Đọc keychain/cookie chạy trên thread nền (thread accept), KHÔNG block main → không bị FB watchdog kill. Không đọc clipboard (tránh banner "pasted from" của iOS 14+). Toast trên main thread.

Khác bản cũ: trước đây `%ctor` + delay tự xuất ra clipboard khi mở app; giờ **chỉ chạy khi XXTouch gọi endpoint**.

## Build (CI)
Push `Tweak.xm`/`Makefile`/`control`/`*.plist` lên `main` → GitHub Actions (`Randomblock1/theos-action`, scheme rootless) build `HoaQn.FBTokenExport.deb` + metadata Sileo vào repo `AddCookieFb_App`. Version bump độc lập với FBTokenLogin. Depends: `ellekit`.

## Dùng (XXTouch) — gọi = 1 lệnh
Cài `.deb` + respring. `get_cookie_token_fb()` là **1 lệnh one-shot**: gọi endpoint 1 lần, **trả ngay** kèm `status`, KHÔNG ngồi đợi. Caller tự lo FB đang chạy + foreground + đã login, rồi xử lý theo status:

```lua
app.run("com.facebook.Facebook")          -- đảm bảo tweak nạp + FB foreground
sys.msleep(3000)
local uid, cookie, token, status = get_cookie_token_fb()
-- status: "OK"        -> có cookie|token
--         "NOT_READY" -> 503: CHƯA LOGIN / token chưa khớp acc  (đợi cũng vô ích, thoát ngay)
--         "NO_EP"     -> gọi không được: FB chưa chạy/chưa foreground / chưa cài tweak
--         "HTTP_xxx"  -> code lạ
```

Vì sao one-shot: trước đây hàm poll 60s, acc **chưa login** thì 503 liên tục rồi mới báo lỗi sau 60s. Giờ `NOT_READY` trả về tức thì để caller tự quyết (bỏ qua / thử lại sau / login tiếp). Chỉ nên warmup lặp cho `NO_EP` (app đang khởi động).

Xem `Xuat_cookie_token_clip.lua`: mở FB → warmup endpoint tối đa ~15s (chỉ với `NO_EP`), `NOT_READY` thoát ngay → check live + push server. Endpoint trả trong body `<cookie>|<token>` (200) hoặc 503 khi chưa đủ; đồng thời set clipboard + toast.
