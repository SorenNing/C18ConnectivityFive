// C18ConnectivityFive — beta4 companion. Keeps the shipping C18 classes intact.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/dispatch.h>
#import <notify.h>
#import <math.h>

extern void MSHookMessageEx(Class cls, SEL sel, IMP replacement, IMP *original);
static NSString * const kC18Domain = @"com.ning.c18connectivity";
static const char * const kC18Notify = "com.ning.c18connectivity.reload";
// Original 7-item order verified from C18ConnectivityView::_makeGlyphFor:on:.
static NSString * const kC18Names[7] = {@"飞行模式", @"隔空投送", @"Wi-Fi", @"蜂窝数据", @"蓝牙", @"个人热点", @"VPN"};
static NSInteger gMode = 0; // 0=original, 4=custom four, 5=custom five
static NSInteger gSlots[5] = {4, 2, 3, 1, 0};
static CFAbsoluteTime gReadAt = 0;
static NSHashTable<UIView *> *gViews;
static BOOL gViewHooked = NO, gPrefsHooked = NO;
static dispatch_source_t gInstallTimer;
static char kLastModeKey;

static NSInteger C18ReadInteger(NSString *key, NSInteger fallback) {
    CFPropertyListRef raw = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)kC18Domain);
    NSInteger result = raw && [(__bridge id)raw respondsToSelector:@selector(integerValue)] ? [(__bridge id)raw integerValue] : fallback;
    if (raw) CFRelease(raw);
    return result;
}
static void C18ReadConfig(BOOL force) {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (!force && gReadAt && now - gReadAt < 0.35) return;
    gReadAt = now;
    CFPreferencesAppSynchronize((__bridge CFStringRef)kC18Domain);
    NSInteger mode = C18ReadInteger(@"Mode", 0);
    NSInteger defaults[5] = {4, 2, 3, 1, 0};
    NSInteger slots[5];
    BOOL valid = mode == 0 || mode == 4 || mode == 5;
    for (NSInteger i=0; i<5; i++) {
        slots[i] = C18ReadInteger([NSString stringWithFormat:@"Slot%ld", (long)(i+1)], defaults[i]);
        if (slots[i] < 0 || slots[i] > 6) valid = NO;
        for (NSInteger j=0; j<i; j++) if (slots[i] == slots[j]) valid = NO;
    }
    if (mode == 5 && slots[4] == 1) valid = NO; // AirDrop presents a menu, not a toggle.
    gMode = valid ? mode : 0; // Fail open to beta4 instead of breaking control center.
    if (valid) for (NSInteger i=0; i<5; i++) gSlots[i] = slots[i];
}
static void C18SaveConfig(NSInteger mode, const NSInteger slots[5]) {
    if (mode != 0 && mode != 4 && mode != 5) return;
    CFPreferencesSetAppValue(CFSTR("Mode"), (__bridge CFPropertyListRef)@(mode), (__bridge CFStringRef)kC18Domain);
    for (NSInteger i=0; i<5; i++) {
        NSString *key = [NSString stringWithFormat:@"Slot%ld", (long)(i+1)];
        CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)@(slots[i]), (__bridge CFStringRef)kC18Domain);
    }
    CFPreferencesAppSynchronize((__bridge CFStringRef)kC18Domain);
    gReadAt = 0;
    notify_post(kC18Notify);
}
static id C18Ivar(id object, const char *name) {
    if (!object) return nil;
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    return ivar ? object_getIvar(object, ivar) : nil;
}
static BOOL C18Parts(UIView *view, NSArray **buttonsOut, NSArray **tilesOut, UIView **clusterOut) {
    NSArray *buttons = C18Ivar(view, "_buttons");
    NSArray *tiles = C18Ivar(view, "_tiles");
    UIView *cluster = C18Ivar(view, "_cluster");
    if (![buttons isKindOfClass:NSArray.class] || buttons.count != 7 ||
        ![tiles isKindOfClass:NSArray.class] || tiles.count != 7 ||
        ![cluster isKindOfClass:UIView.class]) return NO;
    for (id button in buttons) if (![button isKindOfClass:UIControl.class]) return NO;
    for (id tile in tiles) if (![tile isKindOfClass:UIView.class]) return NO;
    if (buttonsOut) *buttonsOut = buttons;
    if (tilesOut) *tilesOut = tiles;
    if (clusterOut) *clusterOut = cluster;
    return YES;
}
static BOOL C18Expanded(id view) {
    SEL selector = @selector(isExpanded);
    return [view respondsToSelector:selector] && ((BOOL(*)(id,SEL))objc_msgSend)(view, selector);
}
static void C18ResetOriginal(UIView *view) {
    NSArray *buttons, *tiles; UIView *cluster;
    if (!C18Parts(view, &buttons, &tiles, &cluster)) return;
    for (UIControl *button in buttons) button.hidden = NO;
    for (UIView *tile in tiles) tile.hidden = NO;
    cluster.hidden = NO;
    // The original methods restore per-size interaction, glyph scale and alphas.
    if ([view respondsToSelector:@selector(_applyButtonRoles)])
        ((void(*)(id,SEL))objc_msgSend)(view, @selector(_applyButtonRoles));
    if ([view respondsToSelector:@selector(_applyLayoutAlphas)])
        ((void(*)(id,SEL))objc_msgSend)(view, @selector(_applyLayoutAlphas));
}
// Compact mode uses the original seven C18RoundButton instances and their original
// tags/action targets. Repositioning never mutates an item's function or state.
static BOOL C18ApplyCustom(UIView *view) {
    NSArray *buttons, *tiles; UIView *cluster;
    if (gMode == 0 || C18Expanded(view) || !C18Parts(view, &buttons, &tiles, &cluster)) return NO;
    CGRect bounds = view.bounds;
    CGFloat width = CGRectGetWidth(bounds), height = CGRectGetHeight(bounds);
    if (width < 200 || height < 45) return NO;
    NSInteger count = gMode;
    CGFloat gap = 5.0, inset = 6.0;
    CGFloat diameter = MIN(height - 2.0 * inset, (width - 2.0 * inset - gap * 4.0) / 5.0);
    if (diameter < 35.0) return NO;
    CGFloat margin = (width - diameter * 5.0 - gap * 4.0) / 2.0;
    CGFloat y = (height - diameter) / 2.0;
    cluster.frame = bounds;
    cluster.hidden = NO;
    cluster.alpha = 1.0;
    cluster.userInteractionEnabled = YES;
    for (UIView *tile in tiles) {
        tile.userInteractionEnabled = NO;
        tile.hidden = YES;
        tile.alpha = 0.0;
    }
    for (UIControl *button in buttons) {
        button.hidden = YES;
        button.userInteractionEnabled = NO;
        button.alpha = 0.0;
    }
    for (NSInteger slot=0; slot<count; slot++) {
        UIControl *button = buttons[gSlots[slot]];
        button.frame = CGRectMake(margin + slot * (diameter + gap), y, diameter, diameter);
        button.hidden = NO;
        button.alpha = 1.0;
        button.userInteractionEnabled = YES;
    }
    if (count == 4) {
        // The three remaining controls retain the beta4 small-button arrangement.
        NSInteger rest[3], found = 0;
        for (NSInteger i=0; i<7; i++) {
            BOOL used = NO;
            for (NSInteger j=0; j<4; j++) if (gSlots[j] == i) used = YES;
            if (!used && found < 3) rest[found++] = i;
        }
        CGFloat small = (diameter - 5.0) * 0.5;
        CGRect positions[3] = {
            CGRectMake(margin + 4 * (diameter + gap), y, small, small),
            CGRectMake(margin + 4 * (diameter + gap) + small + 5.0, y, small, small),
            CGRectMake(margin + 4 * (diameter + gap) + (diameter-small)*0.5, y + diameter-small, small, small)
        };
        for (NSInteger j=0; j<found; j++) {
            UIControl *button = buttons[rest[j]];
            button.frame = positions[j];
            button.hidden = NO;
            button.alpha = 1.0;
            button.userInteractionEnabled = YES;
        }
    }
    objc_setAssociatedObject(view, &kLastModeKey, @(gMode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}
static void (*gOrigLayout)(id, SEL);
static void (*gOrigGridSize)(id, SEL, long long);
static void (*gOrigRoles)(id, SEL);
static void (*gOrigAlphas)(id, SEL);
static BOOL (*gOrigCanExpand)(id, SEL);
static BOOL (*gOrigShouldExpand)(id, SEL, CGPoint);
static void C18AfterOriginal(id view) {
    C18ReadConfig(NO);
    if (gMode == 0) {
        if ([objc_getAssociatedObject(view, &kLastModeKey) integerValue] != 0) {
            objc_setAssociatedObject(view, &kLastModeKey, nil, OBJC_ASSOCIATION_ASSIGN);
            C18ResetOriginal(view);
        }
        return;
    }
    C18ApplyCustom(view);
}
static void C18LayoutHook(id self, SEL cmd) {
    if (gOrigLayout) gOrigLayout(self, cmd);
    C18AfterOriginal(self);
    if (gViews) [gViews addObject:self];
}
static void C18GridSizeHook(id self, SEL cmd, long long size) {
    if (gOrigGridSize) gOrigGridSize(self, cmd, size);
    C18AfterOriginal(self);
}
static void C18RolesHook(id self, SEL cmd) {
    if (gOrigRoles) gOrigRoles(self, cmd);
    C18AfterOriginal(self);
}
static void C18AlphasHook(id self, SEL cmd) {
    if (gOrigAlphas) gOrigAlphas(self, cmd);
    C18AfterOriginal(self);
}
static BOOL C18CanExpandHook(id self, SEL cmd) {
    C18ReadConfig(NO);
    if (gMode == 5 && C18Parts(self, NULL, NULL, NULL) && !C18Expanded(self)) return NO;
    return gOrigCanExpand ? gOrigCanExpand(self, cmd) : NO;
}
static BOOL C18ShouldExpandHook(id self, SEL cmd, CGPoint point) {
    C18ReadConfig(NO);
    if (gMode == 5 && C18Parts(self, NULL, NULL, NULL) && !C18Expanded(self)) return NO;
    return gOrigShouldExpand ? gOrigShouldExpand(self, cmd, point) : NO;
}
static void C18ReloadAll(void) {
    C18ReadConfig(YES);
    for (UIView *view in gViews.allObjects) [view setNeedsLayout];
}
static void C18InstallViewHooks(void) {
    if (gViewHooked) return;
    Class cls = objc_getClass("C18ConnectivityView");
    if (!cls) return;
    const SEL selectors[] = {@selector(layoutSubviews), @selector(setGridSize:),
        @selector(_applyButtonRoles), @selector(_applyLayoutAlphas), @selector(canExpand),
        @selector(shouldExpandOnTouchAtPoint:)};
    for (NSInteger i=0; i<6; i++) if (!class_getInstanceMethod(cls, selectors[i])) return;
    gViewHooked = YES; // Guard against repeated MSHookMessageEx installing our own IMP as orig.
    MSHookMessageEx(cls, selectors[0], (IMP)C18LayoutHook, (IMP *)&gOrigLayout);
    MSHookMessageEx(cls, selectors[1], (IMP)C18GridSizeHook, (IMP *)&gOrigGridSize);
    MSHookMessageEx(cls, selectors[2], (IMP)C18RolesHook, (IMP *)&gOrigRoles);
    MSHookMessageEx(cls, selectors[3], (IMP)C18AlphasHook, (IMP *)&gOrigAlphas);
    MSHookMessageEx(cls, selectors[4], (IMP)C18CanExpandHook, (IMP *)&gOrigCanExpand);
    MSHookMessageEx(cls, selectors[5], (IMP)C18ShouldExpandHook, (IMP *)&gOrigShouldExpand);
    gViews = [NSHashTable weakObjectsHashTable];
    int token = 0;
    notify_register_dispatch(kC18Notify, &token, dispatch_get_main_queue(), ^(int t) { C18ReloadAll(); });
}
