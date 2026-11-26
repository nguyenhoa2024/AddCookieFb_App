-- GET_COOKIE_TOKEN_FB.lua  (XXTouch) - test tweak FBTokenExport (ON-DEMAND, 1 LENH)
-- Tweak KHONG tu xuat khi vao app. get_cookie_token_fb() = 1 LENH: goi endpoint
-- HTTP localhost 127.0.0.1:46980 1 lan, tra NGAY + status (khong ngoi doi 60s).
--   status: "OK" | "NOT_READY"(503 chua login) | "NO_EP"(FB chua chay/foreground) | "HTTP_xxx"

local FBX_URL = "http://127.0.0.1:46980/fbtoken"

local function nLog(s) s = tostring(s); if sys and sys.log then pcall(sys.log, s) end end

local function parse_valid(raw)
    if not raw or raw == "" then return nil end
    local cookie, token = raw:match("^(.-)|(.*)$")
    cookie = cookie and cookie:gsub("%s", "") or ""
    token  = token  and token:gsub("%s", "")  or ""
    if cookie:find("c_user=") and token:find("^EAA") and #token >= 30 then
        return cookie, token, cookie:match("c_user=(%d+)")
    end
    return nil
end

-- 1 LENH one-shot. Tra: uid, cookie, token, status
function get_cookie_token_fb()
    local ok, code, _, body = pcall(http.get, FBX_URL, 5)
    if not ok or not code then return nil, nil, nil, "NO_EP" end
    if code == 200 and type(body) == "string" then
        local cookie, token, uid = parse_valid(body)
        if cookie then return uid, cookie, token, "OK" end
    end
    return nil, nil, nil, (code == 503 and "NOT_READY" or ("HTTP_" .. tostring(code)))
end

---------- DEMO cach xu ly lenh ----------
if device.is_vpn_on() then device.turn_off_vpn() sys.msleep(1500) end

pcall(function() app.run("com.facebook.Facebook") end)   -- caller tu lo FB foreground
sys.msleep(3000)

local uid, cookie, token, status
for i = 1, 15 do                          -- warmup endpoint (NO_EP); NOT_READY -> thoat ngay
    uid, cookie, token, status = get_cookie_token_fb()
    nLog("test giay " .. i .. " status=" .. tostring(status))
    if status == "OK" or status == "NOT_READY" then break end
    if i % 5 == 0 then pcall(function() app.run("com.facebook.Facebook") end) end
    sys.msleep(1000)
end

if status == "OK" then
    nLog("OK uid=" .. tostring(uid) .. " token=" .. token:sub(1, 16) .. "... len=" .. #token)
    sys.toast("OK cookie|token\nuid: " .. tostring(uid)
        .. "\ntoken: " .. token:sub(1, 20) .. "... (" .. #token .. ")", 8)
else
    nLog("THAT BAI status=" .. tostring(status) .. " (chua login? tweak chua cai? FB chua foreground?)")
    sys.toast("THAT BAI cookie|token [" .. tostring(status) .. "]", 6)
end
