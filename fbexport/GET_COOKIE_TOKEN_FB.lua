-- GET_COOKIE_TOKEN_FB.lua  (XXTouch) - test chuan cho tweak FBTokenExport
-- Mo app Facebook -> tweak doc keychain + cookie, XUAT ra CLIPBOARD "<cookie>|<token>"
-- + toast bao da xuat. Script doc clipboard, validate c_user + token EAA.
-- Tra ve: uid, cookie, token (hoac nil).

local function nLog(s) s = tostring(s); if sys and sys.log then pcall(sys.log, s) end end

local function clip_read()
    for _,fn in ipairs({function() return pasteboard.read() end, function() return pasteboard.read_text() end}) do
        local ok,v = pcall(fn); if ok and type(v)=="string" and v~="" then return v end
    end
    return nil
end
local function clip_write(s)
    for _,fn in ipairs({function() return pasteboard.write(s) end, function() return pasteboard.write_text(s) end}) do
        if pcall(fn) then return true end
    end
    return false
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

    -- dat sentinel de biet clipboard da bi tweak ghi de (tranh doc nham clipboard cu)
    local SENT = "FBX_" .. os.time()
    clip_write(SENT)

    nLog("get_cookie_token_fb: close + run Facebook")
    pcall(function() app.close("com.facebook.Facebook") end)
    sys.msleep(2500)
    pcall(function() app.run("com.facebook.Facebook") end)

    for i = 1, timeout_s do
        sys.msleep(1000)
        local c = clip_read()
        if c and c ~= SENT then
            local cookie, token, uid = parse_valid(c)
            if cookie then
                nLog("get_cookie_token_fb: OK giay " .. i .. " uid=" .. tostring(uid)
                    .. " token=" .. token:sub(1,16) .. "... len=" .. #token)
                sys.toast("OK cookie|token\nuid: " .. tostring(uid)
                    .. "\ntoken: " .. token:sub(1,20) .. "... (" .. #token .. ")", 8)
                return uid, cookie, token
            end
        end
        if i % 5 == 0 then nLog("get_cookie_token_fb: giay " .. i .. " clip chua hop le") end
    end

    nLog("get_cookie_token_fb: HET " .. timeout_s .. "s - tweak da cai + app da login chua?")
    sys.toast("THAT BAI: khong lay duoc cookie|token", 6)
    return nil
end

get_cookie_token_fb(60)
