// FBTokenExport - inject vao com.facebook.Facebook, vao app la TU XUAT cookie|token
// Doc access token (EAAAAA..., app id 6628568379) tu keychain cua chinh app
// + gom cookie (c_user;xs;fr;datr;sb) tu NSHTTPCookieStorage.
// XUAT ra CLIPBOARD (nhu ban goc): noi dung "<cookie>|<token>" + TOAST bao da xuat.
// KHONG ghi file, KHONG XoaInfo, KHONG notification.
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

// kSecAttrAccount co the la NSString hoac NSData -> string
static NSString *acctToStr(id acct) {
    if ([acct isKindOfClass:[NSString class]]) return (NSString *)acct;
    if ([acct isKindOfClass:[NSData class]])
        return [[NSString alloc] initWithData:(NSData *)acct encoding:NSUTF8StringEncoding];
    return nil;
}

// CHONG TOKEN CU: token phai thuoc dung uid (c_user) dang dang nhap.
// Doc keychain kem kSecAttrAccount; uu tien token co account == wantUID.
// - co token khop uid            -> dung (chac chan dung acc).
// - khong khop nhung CHI 1 token  -> dung (khong the nham voi acc khac).
// - nhieu token ma khong khop uid -> nil (tu choi xuat, tranh token acc cu).
static NSString *tokenForUID(NSString *wantUID) {
    NSArray *services = @[@"com.facebook.graph", @"com.facebook.account.zmshimmed",
                          @"com.facebook.accountstatus", @"com.facebook.tim"];
    NSMutableSet *distinct = [NSMutableSet set];
    NSString *matched = nil, *single = nil;
    for (NSString *svc in services) {
        NSDictionary *q = @{ (__bridge id)kSecClass:           (__bridge id)kSecClassGenericPassword,
                             (__bridge id)kSecAttrService:      svc,
                             (__bridge id)kSecReturnData:       (__bridge id)kCFBooleanTrue,
                             (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
                             (__bridge id)kSecMatchLimit:       (__bridge id)kSecMatchLimitAll };
        CFTypeRef res = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &res) == errSecSuccess && res) {
            for (id item in (__bridge NSArray *)res) {
                if (![item isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *it = (NSDictionary *)item;
                NSString *tok = scanDataForToken(it[(__bridge id)kSecValueData]);
                if (!tok) continue;
                [distinct addObject:tok];
                single = tok;
                NSString *acct = acctToStr(it[(__bridge id)kSecAttrAccount]);
                if (wantUID.length && acct.length && [acct isEqualToString:wantUID]) matched = tok;
            }
        }
        if (res) CFRelease(res);
    }
    if (matched) return matched;
    if (distinct.count == 1) return single;
    return nil;
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

// Tim window dang hien (iOS15: uu tien scene foreground, fallback .windows). MAIN thread.
static UIWindow *frontWindow(void) {
    UIApplication *app = [UIApplication sharedApplication];
    @try {
        if ([app respondsToSelector:@selector(connectedScenes)]) {
            for (UIScene *sc in app.connectedScenes) {
                if (![sc isKindOfClass:[UIWindowScene class]]) continue;
                if (sc.activationState != UISceneActivationStateForegroundActive) continue;
                UIWindowScene *ws = (UIWindowScene *)sc;
                for (UIWindow *w in ws.windows) { if (w.isKeyWindow && !w.isHidden) return w; }
                if (ws.windows.count) return ws.windows.firstObject;
            }
        }
    } @catch (__unused NSException *e) {}
    @try {
        for (UIWindow *w in app.windows) { if (w.isKeyWindow && !w.isHidden) return w; }
        return app.windows.firstObject;
    } @catch (__unused NSException *e) {}
    return nil;
}

// Toast trong app (giong deb goc). LUON goi tren MAIN thread.
static void showToast(NSString *msg) {
    @try {
        UIWindow *win = frontWindow();
        if (!win) return;
        [[win viewWithTag:0x7B10] removeFromSuperview];
        UILabel *lbl = [[UILabel alloc] init];
        lbl.tag = 0x7B10;
        lbl.text = msg;
        lbl.numberOfLines = 0;
        lbl.textColor = [UIColor whiteColor];
        lbl.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.88];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        lbl.layer.cornerRadius = 12; lbl.clipsToBounds = YES;
        lbl.userInteractionEnabled = NO;                 // khong chan tap cua app
        CGFloat W = win.bounds.size.width - 40;
        CGSize sz = [lbl sizeThatFits:CGSizeMake(W - 24, 600)];
        lbl.frame = CGRectMake(20, 130, W, sz.height + 26);
        lbl.alpha = 0;
        [win addSubview:lbl];
        __weak UILabel *wlbl = lbl;
        [UIView animateWithDuration:0.25 animations:^{ UILabel *s=wlbl; if (s) s.alpha = 1; } completion:^(BOOL _f){
            [UIView animateWithDuration:0.4 delay:3.5 options:0 animations:^{ UILabel *s=wlbl; if (s) s.alpha = 0; }
                             completion:^(BOOL _f2){ UILabel *s=wlbl; if (s) [s removeFromSuperview]; }];
        }];
    } @catch (__unused NSException *e) {}
}

// Day ket qua ra clipboard + toast. Dieu phoi ve MAIN thread (UIKit chi tren main).
static void deliver(NSString *cookie, NSString *token) {
    NSString *line = [NSString stringWithFormat:@"%@|%@", cookie ?: @"", token ?: @""];
    NSString *head = token.length > 18 ? [token substringToIndex:18] : token;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try { [UIPasteboard generalPasteboard].string = line; } @catch (__unused NSException *e) {}
        showToast([NSString stringWithFormat:@"✅ FB Cookie & Token Copied\ntoken: %@...", head]);
    });
}

static NSString *uidFromCookie(NSString *ck) {
    if (!ck) return nil;
    NSRange r = [ck rangeOfString:@"c_user="];
    if (r.location == NSNotFound) return nil;
    NSUInteger i = r.location + r.length, s = i;
    while (i < ck.length) { unichar c = [ck characterAtIndex:i]; if (c < '0' || c > '9') break; i++; }
    return i > s ? [ck substringWithRange:NSMakeRange(s, i - s)] : nil;
}

static dispatch_queue_t gQueue = NULL;     // serial queue nen (keychain/cookie khong chay main)
static NSInteger gAttempts = 0;
static BOOL gDone = NO;

static void tryExtract(void) {
    @autoreleasepool {
        if (gDone) return;
        gAttempts++;
        NSString *ck  = collectCookies();
        NSString *uid = uidFromCookie(ck);
        NSString *tok = uid.length ? tokenForUID(uid) : nil;   // CHI lay token khop acc hien tai

        if (uid.length && tok.length) {                         // du + khop acc -> xuat
            gDone = YES;
            deliver(ck, tok);
            return;
        }
        if (gAttempts < 30) {                                   // chua du -> doi 2s thu lai (tren queue nen)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                           gQueue, ^{ tryExtract(); });
        } else {
            // KHONG xuat token cu/sai acc. Bao de biet da thu ma chua co token khop.
            dispatch_async(dispatch_get_main_queue(), ^{
                showToast(@"⚠️ FBTokenExport: chua co token khop acc (khong xuat token cu)");
            });
        }
    }
}

%ctor {
    @autoreleasepool {
        gQueue = dispatch_queue_create("com.hoaqn.fbtokenexport.q", DISPATCH_QUEUE_SERIAL);
        // delay 3s cho app init xong (keychain/cookie san sang), chay tren queue nen
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                       gQueue, ^{ tryExtract(); });
    }
}
