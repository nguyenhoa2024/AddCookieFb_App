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

// Toast trong app (giong deb goc) de biet da xuat
static void showToast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIApplication *app = [UIApplication sharedApplication];
            UIWindow *win = nil;
            for (UIWindow *w in app.windows) { if (w.isKeyWindow && !w.isHidden) { win = w; break; } }
            if (!win) win = app.windows.firstObject;
            if (!win) return;
            UILabel *lbl = [[UILabel alloc] init];
            lbl.tag = 0x7B10;
            [[win viewWithTag:0x7B10] removeFromSuperview];
            lbl.text = msg;
            lbl.numberOfLines = 0;
            lbl.textColor = [UIColor whiteColor];
            lbl.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.88];
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
            lbl.layer.cornerRadius = 12; lbl.clipsToBounds = YES;
            CGFloat W = win.bounds.size.width - 40;
            CGSize sz = [lbl sizeThatFits:CGSizeMake(W - 24, 600)];
            lbl.frame = CGRectMake(20, 130, W, sz.height + 26);
            lbl.alpha = 0;
            [win addSubview:lbl];
            [UIView animateWithDuration:0.25 animations:^{ lbl.alpha = 1; } completion:^(BOOL _f){
                [UIView animateWithDuration:0.4 delay:3.5 options:0 animations:^{ lbl.alpha = 0; }
                                 completion:^(BOOL _f2){ [lbl removeFromSuperview]; }];
            }];
        } @catch (__unused NSException *e) {}
    });
}

static BOOL gToasted = NO;
static void writeOut(NSString *cookie, NSString *token) {
    NSString *line = [NSString stringWithFormat:@"%@|%@", cookie ?: @"", token ?: @""];
    @try { [UIPasteboard generalPasteboard].string = line; } @catch (__unused NSException *e) {} // xuat ra clipboard
    if (!gToasted && token.length > 0) {
        gToasted = YES;
        NSString *head = token.length > 18 ? [token substringToIndex:18] : token;
        showToast([NSString stringWithFormat:@"✅ FB Cookie & Token Copied\ntoken: %@...", head]);
    }
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ tryExtract(); });
    }
}
