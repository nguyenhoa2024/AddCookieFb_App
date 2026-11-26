// FBTokenExport - inject vao com.facebook.Facebook, vao app la TU XUAT cookie|token
// Doc access token (EAAAAA..., app id 6628568379) tu keychain cua chinh app
// + gom cookie (c_user;xs;fr;datr;sb) tu NSHTTPCookieStorage, ghi ra:
//     <container>/Documents/fb_cookie_token.txt   noi dung: <cookie>|<token>
// XXTouch (root) doc file nay tu container FB. KHONG dung XoaInfo/notification.
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

// Quet chuoi, lay token EAA... (day nhat) - chiu duoc truong hop token nam trong blob/JSON
static NSString *pickToken(NSString *s) {
    if (s.length == 0) return nil;
    NSString *best = nil;
    NSUInteger from = 0, n = s.length;
    while (from < n) {
        NSRange r = [s rangeOfString:@"EAA" options:0 range:NSMakeRange(from, n - from)];
        if (r.location == NSNotFound) break;
        NSUInteger start = r.location, i = start;
        while (i < n) {
            unichar c = [s characterAtIndex:i];
            BOOL ok = (c>='A'&&c<='Z')||(c>='a'&&c<='z')||(c>='0'&&c<='9');
            if (!ok) break;
            i++;
        }
        NSUInteger len = i - start;
        if (len >= 30 && (!best || len > best.length))
            best = [s substringWithRange:NSMakeRange(start, len)];
        from = (i > start) ? i : start + 1;
    }
    return best;
}

static NSString *scanDataForToken(NSData *data) {
    if (data.length == 0) return nil;
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!s) s = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    return pickToken(s);
}

// Query keychain theo service (wide query: KHONG set access group -> tra ve
// item tu moi access group cua app, vi dylib chay trong tien trinh FB).
static NSString *tokenFromServices(void) {
    NSArray *services = @[@"com.facebook.graph", @"com.facebook.account.zmshimmed",
                          @"com.facebook.accountstatus", @"com.facebook.tim"];
    NSString *best = nil;
    for (NSString *svc in services) {
        NSDictionary *q = @{ (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
                             (__bridge id)kSecAttrService:  svc,
                             (__bridge id)kSecReturnData:   (__bridge id)kCFBooleanTrue,
                             (__bridge id)kSecMatchLimit:   (__bridge id)kSecMatchLimitAll };
        CFTypeRef res = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &res) == errSecSuccess && res) {
            for (id item in (__bridge NSArray *)res) {
                NSData *d = [item isKindOfClass:[NSData class]] ? (NSData *)item : nil;
                NSString *tok = scanDataForToken(d);
                if (tok && (!best || tok.length > best.length)) best = tok;
            }
        }
        if (res) CFRelease(res);
    }
    return best;
}

// Fallback: quet TOAN BO generic password cua app tim token EAA...
static NSString *tokenWide(void) {
    NSDictionary *q = @{ (__bridge id)kSecClass:     (__bridge id)kSecClassGenericPassword,
                         (__bridge id)kSecReturnData:(__bridge id)kCFBooleanTrue,
                         (__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitAll };
    CFTypeRef res = NULL;
    NSString *best = nil;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &res) == errSecSuccess && res) {
        for (id item in (__bridge NSArray *)res) {
            NSData *d = [item isKindOfClass:[NSData class]] ? (NSData *)item : nil;
            NSString *tok = scanDataForToken(d);
            if (tok && (!best || tok.length > best.length)) best = tok;
        }
    }
    if (res) CFRelease(res);
    return best;
}

// Gom cookie facebook theo thu tu c_user;xs;fr;datr;sb
static NSString *collectCookies(void) {
    NSHTTPCookieStorage *cs = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *order = @[@"c_user", @"xs", @"fr", @"datr", @"sb"];
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    for (NSHTTPCookie *c in cs.cookies) {
        if ([c.domain rangeOfString:@"facebook"].location != NSNotFound
            && [order containsObject:c.name] && c.value.length)
            map[c.name] = c.value;
    }
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *k in order)
        if (map[k]) [parts addObject:[NSString stringWithFormat:@"%@=%@", k, map[k]]];
    return parts.count ? [parts componentsJoinedByString:@";"] : nil;
}

// Ghi thang vao duong dan XXTouch (noi script doc). Container Documents la fallback.
static NSString *const kXXPath  = @"/var/mobile/Media/1ferver/lua/scripts/fb_cookie_token.txt";
static NSString *docPath(void) {
    return [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]
            stringByAppendingPathComponent:@"fb_cookie_token.txt"];
}

static void writeOut(NSString *cookie, NSString *token) {
    NSString *line = [NSString stringWithFormat:@"%@|%@", cookie ?: @"", token ?: @""];
    [line writeToFile:kXXPath  atomically:YES encoding:NSUTF8StringEncoding error:nil]; // XXTouch path
    [line writeToFile:docPath() atomically:YES encoding:NSUTF8StringEncoding error:nil]; // fallback container
    @try { [UIPasteboard generalPasteboard].string = line; } @catch (__unused NSException *e) {}
}

static NSInteger gAttempts = 0;
static void tryExtract(void) {
    gAttempts++;
    NSString *tok = tokenFromServices();
    if (tok.length == 0) tok = tokenWide();
    NSString *ck = collectCookies();
    BOOL haveTok = tok.length > 0;
    BOOL haveCk  = ck.length > 0 && [ck rangeOfString:@"c_user="].location != NSNotFound;

    if (haveTok && haveCk) { writeOut(ck, tok); return; }           // du ca 2 -> xong
    if (gAttempts < 30) {                                           // chua du -> doi 2s thu lai
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ tryExtract(); });
    } else if (haveTok) {
        writeOut(ck, tok);                                         // het gio: co token thi van ghi
    }
}

%ctor {
    @autoreleasepool {
        // xoa file cu de XXTouch khong doc nham ket qua lan truoc
        [[NSFileManager defaultManager] removeItemAtPath:kXXPath  error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:docPath() error:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ tryExtract(); });
    }
}
