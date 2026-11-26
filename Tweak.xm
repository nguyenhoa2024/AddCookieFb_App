// FBTokenLogin - inject FB session (token+datr+cookie) vao app Facebook de login khong can password
// Chay trong tien trinh com.facebook.Facebook (dung keychain-access-groups cua app)
// Doc file Documents/fb_login.txt do XXTouch/SSH ghi vao. Chap nhan NGUYEN dong acc data:
//   uid|pass|c_user=...;xs=...;fr=...;datr=...|EAAAAA...token
// Tu dong rut token (EAA...) + c_user/xs/fr/datr. (pass bo qua)
#import <Foundation/Foundation.h>
#import <Security/Security.h>

static void kcSet(NSString *svc, NSString *agrp, CFTypeRef access, id account, NSData *data) {
    NSDictionary *del = @{ (__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                           (__bridge id)kSecAttrService:svc };
    SecItemDelete((__bridge CFDictionaryRef)del);
    NSDictionary *add = @{ (__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                           (__bridge id)kSecAttrService:svc,
                           (__bridge id)kSecAttrAccount:account,
                           (__bridge id)kSecAttrAccessGroup:agrp,
                           (__bridge id)kSecAttrAccessible:(__bridge id)access,
                           (__bridge id)kSecValueData:data };
    SecItemAdd((__bridge CFDictionaryRef)add, NULL);
}

static void ckSet(NSString *name, NSString *value) {
    if (name.length == 0 || value.length == 0) return;
    NSHTTPCookie *c = [NSHTTPCookie cookieWithProperties:@{
        NSHTTPCookieName:name, NSHTTPCookieValue:value,
        NSHTTPCookieDomain:@".facebook.com", NSHTTPCookiePath:@"/",
        NSHTTPCookieExpires:[NSDate dateWithTimeIntervalSinceNow:94608000] }];
    if (c) [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:c];
}

// rut value theo key (vd "c_user="), dung tai ky tu ; | newline space tab
static NSString* pick(NSString *s, NSString *key) {
    NSRange r = [s rangeOfString:key];
    if (r.location == NSNotFound) return nil;
    NSUInteger start = r.location + r.length, i = start;
    while (i < s.length) {
        unichar c = [s characterAtIndex:i];
        if (c == ';' || c == '|' || c == '\n' || c == '\r' || c == ' ' || c == '\t') break;
        i++;
    }
    return i > start ? [s substringWithRange:NSMakeRange(start, i - start)] : nil;
}

// rut access token: quet moi "EAA", lay chuoi alphanumeric DAI NHAT (token that luon dai nhat)
static NSString* pickToken(NSString *s) {
    NSString *best = nil;
    NSUInteger from = 0;
    while (from < s.length) {
        NSRange r = [s rangeOfString:@"EAA" options:0 range:NSMakeRange(from, s.length - from)];
        if (r.location == NSNotFound) break;
        NSUInteger start = r.location, i = start;
        while (i < s.length) {
            unichar c = [s characterAtIndex:i];
            BOOL ok = (c>='A'&&c<='Z')||(c>='a'&&c<='z')||(c>='0'&&c<='9');
            if (!ok) break;
            i++;
        }
        NSUInteger len = i - start;
        if (len >= 20 && (!best || len > best.length))
            best = [s substringWithRange:NSMakeRange(start, len)];
        from = (i > start) ? i : start + 1;
    }
    return best;
}

%ctor {
    @autoreleasepool {
        NSString *home = NSHomeDirectory();
        NSString *path = [home stringByAppendingPathComponent:@"Documents/fb_login.txt"];
        NSString *raw  = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (raw.length == 0) return;

        NSString *token  = pickToken(raw);
        NSString *c_user = pick(raw, @"c_user=");
        NSString *xs     = pick(raw, @"xs=");
        NSString *fr     = pick(raw, @"fr=");
        NSString *datr   = pick(raw, @"datr=");
        NSString *fbid   = c_user;
        // fallback: neu khong co "c_user=" thi lay field dau tien (uid)
        if (fbid.length == 0) {
            NSArray *parts = [raw componentsSeparatedByString:@"|"];
            if (parts.count > 0) fbid = [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        if (fbid.length == 0 || token.length == 0) return;

        NSData *fbidData = [fbid  dataUsingEncoding:NSUTF8StringEncoding];
        NSData *tokData  = [token dataUsingEncoding:NSUTF8StringEncoding];

        // 3 keychain item chua access token (chuoi EAA tho)
        kcSet(@"com.facebook.graph", @"T84QZS65DQ.platformFamily",
              kSecAttrAccessibleAfterFirstUnlock, fbidData, tokData);
        kcSet(@"facebook.activeaccount", @"group.com.facebook.family",
              kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, fbid, tokData);
        kcSet(@"group.com.facebook.family.appgrouptokenshare", @"group.com.facebook.family",
              kSecAttrAccessibleAfterFirstUnlock, fbidData, tokData);

        // datr (device identity) -> keychain + cookie, chong die
        if (datr.length)
            kcSet(@"com.facebook.datr", @"T84QZS65DQ.platformFamily",
                  kSecAttrAccessibleAfterFirstUnlock, @"",
                  [datr dataUsingEncoding:NSUTF8StringEncoding]);

        // cookie dong bo token
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
        ckSet(@"datr", datr);
        ckSet(@"c_user", c_user ?: fbid);
        ckSet(@"xs", xs);
        ckSet(@"fr", fr);

        // file cache user id (app doc luc khoi dong)
        [fbid writeToFile:[home stringByAppendingPathComponent:@"Documents/FBAPISessionLoggedInUserIDCache"]
               atomically:YES encoding:NSUTF8StringEncoding error:nil];

        // tieu thu 1 lan
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}
