-- GET_COOKIE_TOKEN_FB.lua  (XXTouch) - test chuan cho tweak FBTokenExport
-- Mo app Facebook -> tweak tu doc keychain + cookie, ghi "<cookie>|<token>" vao
-- container FB (Documents/fb_cookie_token.txt) + clipboard + toast bao da xuat.
-- App FB bi SANDBOX nen KHONG ghi thang ra path XXTouch duoc -> XXTouch (root)
-- doc file tu CONTAINER roi copy ra path XXTouch.
-- Tra ve: uid, cookie, token (hoac nil).

local XX_FILE = "/var/mobile/Media/1ferver/lua/scripts/fb_cookie_token.txt"

local function nLog(s) s = tostring(s); if sys and sys.log then pcall(sys.log, s) end end
local function readf(p) local f=io.open(p,"r"); if not f then return nil end local s=f:read("*a"); f:close(); return s end
local function writef(p,s) local f=io.open(p,"w"); if not f then return false end f:write(s or "") f:close() return true end
local function exec(c) local h=io.popen(c.." 2>&1"); if not h then return "" end local o=h:read("*a") or ""; h:close(); return o end

-- Documents/fb_cookie_token.txt trong container FB
local function fb_doc_path()
    local C = exec([[for d in /var/mobile/Containers/Data/Application/*/; do grep -q com.facebook.Facebook "$d/.com.apple.mobile_container_manager.metadata.plist" 2>/dev/null && printf "%s" "$d" && break; done]]):gsub("%s+$","")
    if C == "" then return nil end
    return C .. "Documents/fb_cookie_token.txt"
end

local function clip_read()
    for _,fn in ipairs({function() return pasteboard.read() end, function() return pasteboard.read_text() end}) do
        local ok,v = pcall(fn); if ok and type(v)=="string" and v~="" then return v end
    end
    return nil
end

local function parse_valid(raw)
    if not raw or raw == "" then return nil end
    local cookie, token = raw:match("^(.-)|(.*)$")
    cookie = cookie and cookie:gsub("%s","") or ""
    token  = token  and token:gsub("%s","")  or ""
    if cookie:find("c_user=") and token:find("^EAA") and #token >= 30 then
        return cookie, token, cookie:match("c_user=(%d+)")
    end
    return nil
end

function get_cookie_token_fb(timeout_s)
    timeout_s = timeout_s or 60
    if device.is_vpn_on() then device.turn_off_vpn() sys.msleep(1500) end

    local docf = fb_doc_path()
    nLog("get_cookie_token_fb: container file = " .. tostring(docf))
    if docf then os.remove(docf) end            -- xoa ket qua cu (tweak cung tu xoa)
    os.remove(XX_FILE)

    nLog("get_cookie_token_fb: close + run Facebook")
    pcall(function() app.close("com.facebook.Facebook") end)
    sys.msleep(2500)
    pcall(function() app.run("com.facebook.Facebook") end)

    for i = 1, timeout_s do
        sys.msleep(1000)
        -- 1) container file (nguon chinh - tweak ghi duoc)
        local cookie, token, uid = parse_valid(docf and readf(docf) or nil)
        -- 2) fallback clipboard
        if not cookie then cookie, token, uid = parse_valid(clip_read()) end
        if cookie then
            writef(XX_FILE, cookie .. "|" .. token)   -- copy ra path XXTouch (root ghi duoc)
            nLog("get_cookie_token_fb: OK giay " .. i .. " uid=" .. tostring(uid)
                .. " token=" .. token:sub(1,16) .. "... len=" .. #token)
            sys.toast("OK cookie|token\nuid: " .. tostring(uid)
                .. "\ntoken: " .. token:sub(1,20) .. "... (" .. #token .. ")", 8)
            return uid, cookie, token
        end
        if i % 5 == 0 then nLog("get_cookie_token_fb: giay " .. i .. " chua co") end
    end

    nLog("get_cookie_token_fb: HET " .. timeout_s .. "s - tweak da cai + app da login chua?")
    sys.toast("THAT BAI: khong lay duoc cookie|token", 6)
    return nil
end

get_cookie_token_fb(60)
