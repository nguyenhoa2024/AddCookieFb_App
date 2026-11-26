// FBTokenExport - inject vao com.facebook.Facebook.
// KHONG tu xuat khi vao app nua. Mo 1 endpoint HTTP localhost (127.0.0.1:46980):
// CHI khi XXTouch goi http.get toi do thi tweak moi doc keychain + cookie va TRA
// "<cookie>|<token>" trong body HTTP (kem set clipboard + toast de nhan biet).
// Token EAAAAA (app id 6628568379) tu keychain cua chinh app, da khop dung acc
// dang login (chong token cu). Cookie c_user;xs;fr;datr;sb tu NSHTTPCookieStorage.
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>

static const int kPort = 46980;            // localhost endpoint, chi 127.0.0.1

// Quet chuoi, lay token EAA... (day nhat) - chiu duoc token nam trong blob/JSON
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
// - co token khop uid            -> dung (chac chan dung acc).
// - khong khop nhung CHI 1 token  -> dung (khong the nham voi acc khac).
// - nhieu token ma khong khop uid -> nil (tu choi, tranh token acc cu).
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

static NSString *uidFromCookie(NSString *ck) {
    if (!ck) return nil;
    NSRange r = [ck rangeOfString:@"c_user="];
    if (r.location == NSNotFound) return nil;
    NSUInteger i = r.location + r.length, s = i;
    while (i < ck.length) { unichar c = [ck characterAtIndex:i]; if (c < '0' || c > '9') break; i++; }
    return i > s ? [ck substringWithRange:NSMakeRange(s, i - s)] : nil;
}

// "<cookie>|<token>" (chi khi co du cookie + token khop acc), nil neu chua du.
static NSString *buildPayload(void) {
    NSString *ck  = collectCookies();
    if (!ck.length) return nil;
    NSString *uid = uidFromCookie(ck);
    NSString *tok = uid.length ? tokenForUID(uid) : nil;
    if (uid.length && tok.length) return [NSString stringWithFormat:@"%@|%@", ck, tok];
    return nil;
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

// Toast trong app. LUON goi tren MAIN thread.
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
        lbl.userInteractionEnabled = NO;
        CGFloat W = win.bounds.size.width - 40;
        CGSize sz = [lbl sizeThatFits:CGSizeMake(W - 24, 600)];
        lbl.frame = CGRectMake(20, 130, W, sz.height + 26);
        lbl.alpha = 0;
        [win addSubview:lbl];
        __weak UILabel *wlbl = lbl;
        [UIView animateWithDuration:0.25 animations:^{ UILabel *s=wlbl; if (s) s.alpha = 1; } completion:^(BOOL _f){
            [UIView animateWithDuration:0.4 delay:3.0 options:0 animations:^{ UILabel *s=wlbl; if (s) s.alpha = 0; }
                             completion:^(BOOL _f2){ UILabel *s=wlbl; if (s) [s removeFromSuperview]; }];
        }];
    } @catch (__unused NSException *e) {}
}

// Gui HTTP response text roi dong (SO_NOSIGPIPE da set tren fd -> send khong raise SIGPIPE)
static void sendResponse(int fd, int status, NSString *body) {
    body = body ?: @"";
    NSData *b = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSString *head = [NSString stringWithFormat:
        @"HTTP/1.1 %d %@\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",
        status, (status == 200 ? @"OK" : @"Service Unavailable"), (unsigned long)b.length];
    NSData *h = [head dataUsingEncoding:NSUTF8StringEncoding];
    send(fd, h.bytes, h.length, 0);
    if (b.length) send(fd, b.bytes, b.length, 0);
}

// Server localhost: moi ket noi -> doc keychain/cookie (tren thread nay, KHONG main)
// -> tra body + set clipboard + toast. Tu phuc hoi neu bind/listen loi.
static void serverLoop(void) {
    for (;;) {
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) { sleep(3); continue; }
        int yes = 1;
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
        struct sockaddr_in addr; memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port   = htons((uint16_t)kPort);
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);          // chi 127.0.0.1
        if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) { close(fd); sleep(3); continue; }
        if (listen(fd, 4) < 0) { close(fd); sleep(3); continue; }

        for (;;) {
            int c = accept(fd, NULL, NULL);
            if (c < 0) { if (errno == EINTR) continue; break; }
            int on = 1; setsockopt(c, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
            @autoreleasepool {
                char buf[2048];
                (void)recv(c, buf, sizeof(buf), 0);              // drain request, bo qua noi dung
                NSString *payload = nil;
                @try { payload = buildPayload(); } @catch (__unused NSException *e) {}
                if (payload.length) {
                    NSString *p = payload;
                    NSString *tokHead = @"";
                    NSRange bar = [p rangeOfString:@"|" options:NSBackwardsSearch];
                    if (bar.location != NSNotFound) {
                        NSString *t = [p substringFromIndex:bar.location + 1];
                        tokHead = t.length > 18 ? [t substringToIndex:18] : t;
                    }
                    NSString *th = tokHead;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        @try { [UIPasteboard generalPasteboard].string = p; } @catch (__unused NSException *e) {}
                        showToast([NSString stringWithFormat:@"✅ FB Cookie|Token da tra (XXTouch goi)\ntoken: %@...", th]);
                    });
                    sendResponse(c, 200, payload);
                } else {
                    sendResponse(c, 503, @"");                    // chua du cookie/token khop acc
                }
            }
            close(c);
        }
        close(fd);
        sleep(2);
    }
}

%ctor {
    @autoreleasepool {
        // Mo server o thread nen, doi app va XXTouch goi toi moi lam viec.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ serverLoop(); });
    }
}
