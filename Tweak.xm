// FBTokenLogin - inject FB session (token+datr+cookie) de login app Facebook khong can password
// Chay trong com.facebook.Facebook. Doc Documents/fb_login.txt (uid|pass|cookie|token), tu parse.
// AN TOAN: xoa file NGAY sau khi doc (tranh crash-loop neu inject loi) + bao @try/@catch (khong lam crash FB).
#import <Foundation/Foundation.h>
#import <Security/Security.h>

static void kcSet(NSString *svc, NSString *agrp, CFTypeRef access, id account, NSData *data) {
    @try {
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
    } @catch (__unused NSException *e) {}
}

static void ckSet(NSString *name, NSString *value) {
    @try {
        if (name.length == 0 || value.length == 0) return;
        NSHTTPCookie *c = [NSHTTPCookie cookieWithProperties:@{
            NSHTTPCookieName:name, NSHTTPCookieValue:value,
            NSHTTPCookieDomain:@".facebook.com", NSHTTPCookiePath:@"/",
            NSHTTPCookieExpires:[NSDate dateWithTimeIntervalSinceNow:94608000] }];
        if (c) [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:c];
    } @catch (__unused NSException *e) {}
}

static NSString* pick(NSString *s, NSString *key) {
    @try {
        NSRange r = [s rangeOfString:key];
        if (r.location == NSNotFound) return nil;
        NSUInteger start = r.location + r.length, i = start;
        while (i < s.length) {
            unichar c = [s characterAtIndex:i];
            if (c == ';' || c == '|' || c == '\n' || c == '\r' || c == ' ' || c == '\t') break;
            i++;
        }
        return i > start ? [s substringWithRange:NSMakeRange(start, i - start)] : nil;
    } @catch (__unused NSException *e) { return nil; }
}

static NSString* pickToken(NSString *s) {
    @try {
        NSString *best = nil; NSUInteger from = 0;
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
    } @catch (__unused NSException *e) { return nil; }
}

%ctor {
    @autoreleasepool {
        @try {
            NSString *home = NSHomeDirectory();
            NSString *path = [home stringByAppendingPathComponent:@"Documents/fb_login.txt"];
            NSString *raw  = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
            if (raw.length == 0) return;                       // khong co acc -> khong lam gi
            // *** XOA FILE NGAY (chong crash-loop): du phia duoi loi, lan mo sau se khong retry ***
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];

            NSString *token  = pickToken(raw);
            NSString *c_user = pick(raw, @"c_user=");
            NSString *xs     = pick(raw, @"xs=");
            NSString *fr     = pick(raw, @"fr=");
            NSString *datr   = pick(raw, @"datr=");
            NSString *fbid   = c_user;
            if (fbid.length == 0) {
                NSArray *parts = [raw componentsSeparatedByString:@"|"];
                if (parts.count > 0) fbid = [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }
            if (fbid.length == 0 || token.length == 0) return; // thieu du lieu -> bo qua (file da xoa)

            NSData *fbidData = [fbid  dataUsingEncoding:NSUTF8StringEncoding];
            NSData *tokData  = [token dataUsingEncoding:NSUTF8StringEncoding];

            kcSet(@"com.facebook.graph", @"T84QZS65DQ.platformFamily",
                  kSecAttrAccessibleAfterFirstUnlock, fbidData, tokData);
            kcSet(@"facebook.activeaccount", @"group.com.facebook.family",
                  kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, fbid, tokData);
            kcSet(@"group.com.facebook.family.appgrouptokenshare", @"group.com.facebook.family",
                  kSecAttrAccessibleAfterFirstUnlock, fbidData, tokData);
            if (datr.length)
                kcSet(@"com.facebook.datr", @"T84QZS65DQ.platformFamily",
                      kSecAttrAccessibleAfterFirstUnlock, @"",
                      [datr dataUsingEncoding:NSUTF8StringEncoding]);

            @try { [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways]; } @catch (__unused NSException *e) {}
            ckSet(@"datr", datr);
            ckSet(@"c_user", c_user ?: fbid);
            ckSet(@"xs", xs);
            ckSet(@"fr", fr);

            @try { [fbid writeToFile:[home stringByAppendingPathComponent:@"Documents/FBAPISessionLoggedInUserIDCache"]
                          atomically:YES encoding:NSUTF8StringEncoding error:nil]; } @catch (__unused NSException *e) {}
        } @catch (__unused NSException *e) {}   // tuyet doi khong lam crash FB
    }
}
