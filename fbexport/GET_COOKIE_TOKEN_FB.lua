-- GET_COOKIE_TOKEN_FB.lua  (XXTouch) - test chuan cho tweak FBTokenExport
-- Mo app Facebook -> tweak tu ghi /var/mobile/Media/1ferver/lua/scripts/fb_cookie_token.txt
-- (noi dung: <cookie>|<token>). Script doc lai + validate c_user + token EAA.
-- Tra ve: uid, cookie, token (hoac nil). Khong push - chi lay cookie|token.

local SCRIPTS_DIR = "/var/mobile/Media/1ferver/lua/scripts/"
local OUT_FILE    = SCRIPTS_DIR .. "fb_cookie_token.txt"

local function nLog(s) s = tostring(s); if sys and sys.log then pcall(sys.log, s) end end
local function DocFile(p)
    local f = io.open(p, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

function get_cookie_token_fb(timeout_s)
    timeout_s = timeout_s or 60
    if device.is_vpn_on() then device.turn_off_vpn() sys.msleep(1500) end

    -- xoa ket qua cu truoc khi mo app (tweak cung tu xoa, lam ca o day cho chac)
    os.remove(OUT_FILE)

    nLog("get_cookie_token_fb: close + run Facebook")
    pcall(function() app.close("com.facebook.Facebook") end)
    sys.msleep(2500)
    pcall(function() app.run("com.facebook.Facebook") end)

    -- cho tweak ghi file (3s warmup trong tweak + retry 2s). Poll toi timeout.
    local raw
    for i = 1, timeout_s do
        sys.msleep(1000)
        raw = DocFile(OUT_FILE)
        if raw and raw ~= "" then
            local cookie, token = raw:match("^(.-)|(.*)$")
            cookie = cookie and cookie:gsub("%s", "") or ""
            token  = token  and token:gsub("%s", "")  or ""
            local has_cuser = cookie:find("c_user=") ~= nil
            local has_token = token:find("^EAA") ~= nil and #token >= 30
            if has_cuser and has_token then
                local uid = cookie:match("c_user=(%d+)")
                nLog("get_cookie_token_fb: OK giay " .. i .. " uid=" .. tostring(uid)
                    .. " token=" .. token:sub(1, 16) .. "... len=" .. #token)
                sys.toast("OK cookie|token\nuid: " .. tostring(uid)
                    .. "\ntoken: " .. token:sub(1, 20) .. "... (" .. #token .. ")", 8)
                return uid, cookie, token
            end
            -- file co nhung chua du (token rong / thieu c_user) -> cho tiep
            if i % 5 == 0 then nLog("get_cookie_token_fb: giay " .. i .. " file chua du: " .. raw:sub(1, 60)) end
        elseif i % 5 == 0 then
            nLog("get_cookie_token_fb: giay " .. i .. " chua co file")
        end
    end

    nLog("get_cookie_token_fb: HET " .. timeout_s .. "s khong co cookie|token hop le (tweak da cai + app da login?)")
    sys.toast("THAT BAI: khong lay duoc cookie|token", 6)
    return nil
end

-- CHAY TEST
get_cookie_token_fb(60)
