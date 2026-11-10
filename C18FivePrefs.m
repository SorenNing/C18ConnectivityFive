#import "C18Five.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

extern void MSHookMessageEx(Class, SEL, IMP, IMP *);
@interface PSSpecifier : NSObject
+ (id)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(int)cell edit:(id)edit;
+ (id)groupSpecifierWithName:(NSString *)name;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
@end
static IMP gOriginalSpecifiers;
static BOOL gPrefsInstalled;
static int gPrefsTryCount;
static char kExtraSpecifiers;
static char kPrefsBridge;
static void C18FiveTryInstallPreferences(void);
static id C18FiveMakeGroup(NSString *name) {
    Class cls=NSClassFromString(@"PSSpecifier");
    if (!cls) return nil;
    return ((id(*)(id,SEL,id))objc_msgSend)(cls,@selector(groupSpecifierWithName:),name);
}
static id C18FiveMakeSpecifier(NSString *name,id target,SEL set,SEL get,NSString *cell) {
    Class cls=NSClassFromString(@"PSSpecifier");
    if (!cls) return nil;
    id (*make)(id,SEL,id,id,SEL,SEL,Class,int,id)=(void *)objc_msgSend;
    id spec=make(cls,@selector(preferenceSpecifierNamed:target:set:get:detail:cell:edit:),name,target,set,get,Nil,0,nil);
    ((void(*)(id,SEL,id,id))objc_msgSend)(spec,@selector(setProperty:forKey:),cell,@"cell");
    return spec;
}
@interface C18FivePrefsBridge : NSObject
+ (instancetype)shared;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
@end
@implementation C18FivePrefsBridge
+ (instancetype)shared { static C18FivePrefsBridge *b; static dispatch_once_t once; dispatch_once(&once,^{b=[self new];}); return b; }
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key=[specifier propertyForKey:@"key"]; NSInteger mode=0; NSArray *slots=nil; C18FiveRead(&mode,&slots);
    if ([key isEqualToString:@"Mode"]) return @(mode);
    if ([key hasPrefix:@"Slot"]) { NSInteger i=key.integerValue-1; return i>=0&&i<slots.count ? slots[i] : @"builtin:0"; }
    return nil;
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key=[specifier propertyForKey:@"key"]; NSInteger mode=0; NSArray *slots=nil; C18FiveRead(&mode,&slots);
    if ([key isEqualToString:@"Mode"]) { C18FiveWrite([value integerValue],slots); return; }
    if (![key hasPrefix:@"Slot"]) return;
    NSInteger index=key.integerValue-1; if (index<0||index>=5||![value isKindOfClass:NSString.class]) return;
    NSMutableArray *next=[slots mutableCopy]; NSString *old=next[index]; NSInteger existing=[next indexOfObject:value];
    if (existing!=NSNotFound && existing!=index) next[existing]=old;
    next[index]=value; C18FiveWrite(mode,next);
}
@end
static void C18FiveAppendSettings(id controller) {
    NSArray *cached=objc_getAssociatedObject(controller,&kExtraSpecifiers); if (cached) return;
    NSArray *base=((id(*)(id,SEL))gOriginalSpecifiers)(controller,@selector(specifiers));
    if (![base isKindOfClass:NSArray.class]) return;
    C18FivePrefsBridge *bridge=[C18FivePrefsBridge shared]; NSMutableArray *out=[base mutableCopy];
    id group=C18FiveMakeGroup(@"五键连接模块");
    ((void(*)(id,SEL,id,id))objc_msgSend)(group,@selector(setProperty:forKey:),@"选择显示模式和五个槽位；复杂滑块、播放器和卡片模块不会出现在列表。",@"footerText");
    if (group) [out addObject:group];
    id mode=C18FiveMakeSpecifier(@"布局模式",bridge,@selector(setPreferenceValue:specifier:),@selector(readPreferenceValue:),@"PSSegmentCell");
    ((void(*)(id,SEL,id,id))objc_msgSend)(mode,@selector(setProperty:forKey:),@"Mode",@"key");
    ((void(*)(id,SEL,id,id))objc_msgSend)(mode,@selector(setProperty:forKey:),@[@0,@4,@5],@"validValues");
    ((void(*)(id,SEL,id,id))objc_msgSend)(mode,@selector(setProperty:forKey:),@[@"原版布局",@"自定义四键",@"自定义五键"],@"validTitles");
    ((void(*)(id,SEL,id,id))objc_msgSend)(mode,@selector(setProperty:forKey:),@0,@"default");
    if (mode) [out addObject:mode];
    NSArray *catalog=C18FiveCatalog();
    for (NSInteger i=0;i<5;i++) {
        NSMutableArray *values=[NSMutableArray array]; NSMutableArray *titles=[NSMutableArray array];
        for (NSDictionary *entry in catalog) { if (entry[@"id"] && entry[@"title"]) { [values addObject:entry[@"id"]]; [titles addObject:[NSString stringWithFormat:@"%@ · %@",entry[@"group"]?:@"",entry[@"title"]]]; } }
        id row=C18FiveMakeSpecifier([NSString stringWithFormat:@"槽位%ld",(long)(i+1)],bridge,@selector(setPreferenceValue:specifier:),@selector(readPreferenceValue:),@"PSLinkListCell");
        ((void(*)(id,SEL,id,id))objc_msgSend)(row,@selector(setProperty:forKey:),@"PSListItemsController",@"detail");
        ((void(*)(id,SEL,id,id))objc_msgSend)(row,@selector(setProperty:forKey:),[NSString stringWithFormat:@"Slot%ld",(long)(i+1)],@"key");
        ((void(*)(id,SEL,id,id))objc_msgSend)(row,@selector(setProperty:forKey:),values,@"validValues"); ((void(*)(id,SEL,id,id))objc_msgSend)(row,@selector(setProperty:forKey:),titles,@"validTitles");
        ((void(*)(id,SEL,id,id))objc_msgSend)(row,@selector(setProperty:forKey:),@"builtin:0",@"default");
        if (row) [out addObject:row];
    }
    objc_setAssociatedObject(controller,&kExtraSpecifiers,out,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller,&kPrefsBridge,bridge,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static id C18FiveSpecifiersHook(id self,SEL cmd) {
    C18FiveAppendSettings(self);
    return objc_getAssociatedObject(self,&kExtraSpecifiers) ?: ((id(*)(id,SEL))gOriginalSpecifiers)(self,cmd);
}
static void C18FiveTryInstallPreferences(void) {
    if (gPrefsInstalled || gPrefsTryCount++>80) return;
    Class cls=objc_getClass("C18PRootListController");
    Method method=cls?class_getInstanceMethod(cls,@selector(specifiers)):NULL;
    if (method) { gPrefsInstalled=YES; MSHookMessageEx(cls,@selector(specifiers),(IMP)C18FiveSpecifiersHook,&gOriginalSpecifiers); return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),dispatch_get_main_queue(),^{C18FiveTryInstallPreferences();});
}
void C18FiveInstallPreferences(void) { dispatch_async(dispatch_get_main_queue(),^{C18FiveTryInstallPreferences();}); }
