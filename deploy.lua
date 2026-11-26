-- FBTokenLogin deploy (XXTouch): gan data acc cho tweak roi mo FB -> tweak tu login
-- Truyen NGUYEN dong acc data cua ban: uid|pass|c_user=..;xs=..;fr=..;datr=..|EAAAAA...token
-- Tweak tu rut token (EAA...) + c_user/xs/fr/datr. (pass bo qua)

local function fb_login(acc_line)
    local function exec(c) local h=io.popen(c.." 2>&1"); if not h then return "" end local o=h:read("*a") or ""; h:close(); return o end
    local C = exec([[for d in /var/mobile/Containers/Data/Application/*/; do grep -q com.facebook.Facebook "$d/.com.apple.mobile_container_manager.metadata.plist" 2>/dev/null && printf "%s" "$d" && break; done]])
    C = (C or ""):gsub("%s+$","")
    if C == "" then nLog("FBTokenLogin: khong thay container FB") return false end
    local f = io.open(C.."Documents/fb_login.txt","w")
    if not f then nLog("FBTokenLogin: khong ghi duoc fb_login.txt") return false end
    f:write(acc_line); f:close()
    exec("chown mobile:mobile '"..C.."Documents/fb_login.txt'")
    exec("killall -9 Facebook 2>/dev/null")
    sys.msleep(1000)
    app.run("com.facebook.Facebook")   -- tweak inject luc app khoi dong -> login luon
    nLog("FBTokenLogin: da gan data + mo FB")
    return true
end

-- ================= VI DU (thay bang acc that cua ban) =================
local ACC = "<UID>|<PASS>|c_user=<UID>;xs=<XS>;fr=<FR>;datr=<DATR>|<TOKEN_EAAAAA>"
fb_login(ACC)

-- De dung trong script lon: copy ham fb_login() vao code cua ban, roi goi fb_login(dong_acc).
-- Chay hang loat: lap danh sach acc -> fb_login(acc) -> cho login -> kiem tra -> acc tiep theo.
