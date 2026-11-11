#import "C18Five.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>
extern void MSHookMessageEx(Class,SEL,IMP,IMP *);
static char kOwner;static BOOL hooksDone,presented;static BOOL(*origAppearance)(id,SEL);static NSHashTable*hosts;
static id Shell(void){Class c=objc_getClass("C18Shell");SEL s=NSSelectorFromString(@"shared");return c&&[c respondsToSelector:s]?((id(*)(id,SEL))objc_msgSend)(c,s):nil;}
static BOOL Slider(UIView*v,NSInteger d){if(!v||d>10)return NO;NSString*n=NSStringFromClass(v.class).lowercaseString;if([v isKindOfClass:UISlider.class]||[n containsString:@"slider"]||[n containsString:@"nowplaying"])return YES;for(UIView*x in v.subviews)if(Slider(x,d+1))return YES;return NO;}
static BOOL Wants(id self,SEL cmd){NSHashTable*r=objc_getAssociatedObject(self,&kOwner);C18FiveModuleHost*h=[r anyObject];if(!h)return origAppearance?origAppearance(self,cmd):NO;return presented&&h.window&&!h.hidden&&h.alpha>.01;}
void C18FiveInstallModuleHooks(void){if(hooksDone)return;Class c=objc_getClass("C18ButtonModuleView");Method m=class_getInstanceMethod(c,NSSelectorFromString(@"_wantsAppearance"));if(!m)return;char*t=method_copyReturnType(m);BOOL ok=t&&(*t=='B'||*t=='c');free(t);if(!ok)return;hooksDone=YES;MSHookMessageEx(c,NSSelectorFromString(@"_wantsAppearance"),(IMP)Wants,(IMP*)&origAppearance);hosts=[NSHashTable weakObjectsHashTable];}
void C18FiveModulesSetPresented(BOOL p){presented=p;for(C18FiveModuleHost*h in hosts.allObjects)if(p&&h.window&&!h.hidden)[h refresh];}
@interface C18FiveModuleHost ()
@property(nonatomic,copy,readwrite)NSString*slotID;
@property(nonatomic,copy,readwrite)NSString*failure;
@property(nonatomic,strong,readwrite)UIView*nativeHost;
@property(nonatomic,strong)UIView*moduleView;
@property(nonatomic,strong)UIView*buttonBackdrop;
@property(nonatomic,strong)id instance;
@end
@implementation C18FiveModuleHost
- (instancetype)initWithSlotID:(NSString*)sid owner:(UIView*)owner{if(!(self=[super initWithFrame:CGRectZero]))return nil;_slotID=[sid copy];_owner=owner;self.clipsToBounds=YES;self.backgroundColor=[UIColor colorWithWhite:1 alpha:.095];self.layer.cornerCurve=kCACornerCurveContinuous;self.layer.masksToBounds=YES;_buttonBackdrop=[UIView new];_buttonBackdrop.userInteractionEnabled=NO;_buttonBackdrop.backgroundColor=[UIColor colorWithWhite:1 alpha:.065];_buttonBackdrop.layer.cornerCurve=kCACornerCurveContinuous;_buttonBackdrop.layer.masksToBounds=YES;[self addSubview:_buttonBackdrop];C18FiveInstallModuleHooks();NSDictionary*e=C18FiveEntry(sid);NSString*bid=C18FiveModuleID(sid);id shell=Shell();SEL create=NSSelectorFromString(@"_instantiateModuleWithIdentifier:"),wrap=NSSelectorFromString(@"_makeModuleViewForIdentifier:size:instance:gallery:");@try{if(!e||!bid||C18FiveExcluded(bid,e[@"principal"]))self.failure=@"该项不支持圆形槽位";else if(!hooksDone||![shell respondsToSelector:create]||![shell respondsToSelector:wrap])self.failure=@"原插件模块加载入口不可用";else{_instance=((id(*)(id,SEL,id))objc_msgSend)(shell,create,bid);id wrapper=_instance?((id(*)(id,SEL,id,long long,id,BOOL))objc_msgSend)(shell,wrap,bid,0,_instance,NO):nil;UIView*native=C18FiveObject(wrapper,NSSelectorFromString(@"contentView"));Class cls=objc_getClass("C18ButtonModuleView");id vc=C18FiveGet(native,@"_vc");if(!wrapper||![native isKindOfClass:cls]||!vc||Slider([vc viewIfLoaded],0))self.failure=@"复杂模块，已排除";else{_nativeHost=native;_moduleView=wrapper;C18DataSwitchRegisterHost(_instance,self);NSHashTable*r=[NSHashTable weakObjectsHashTable];[r addObject:self];objc_setAssociatedObject(native,&kOwner,r,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[hosts addObject:self];[self addSubview:wrapper];}}}@catch(NSException*ex){self.failure=@"原模块初始化异常";}if(self.failure){_instance=nil;UILabel*l=[[UILabel alloc]initWithFrame:CGRectZero];l.text=@"不可用";l.textAlignment=NSTextAlignmentCenter;l.font=[UIFont systemFontOfSize:10];l.textColor=UIColor.secondaryLabelColor;[self addSubview:l];self.backgroundColor=[UIColor colorWithWhite:.5 alpha:.18];}return self;}
- (void)layoutSubviews{[super layoutSubviews];CGFloat s=MIN(self.bounds.size.width,self.bounds.size.height);self.layer.cornerRadius=s*.5;_buttonBackdrop.frame=self.bounds;_buttonBackdrop.layer.cornerRadius=s*.5;if(_moduleView){_moduleView.transform=CGAffineTransformIdentity;_moduleView.bounds=CGRectMake(0,0,60,60);_moduleView.center=CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));_moduleView.transform=CGAffineTransformMakeScale(s/60.,s/60.);[_moduleView setNeedsLayout];}else for(UIView*v in self.subviews)if(v!=_buttonBackdrop)v.frame=self.bounds;}
- (void)didMoveToWindow{[super didMoveToWindow];if(self.window)C18DataSwitchInstallGestures(self);}
- (id)c18ModuleInstance{return _instance;}
- (void)refresh{C18FiveVoid(_nativeHost,NSSelectorFromString(@"refresh"));C18FiveVoid(_nativeHost,NSSelectorFromString(@"ensureAppeared"));}
- (void)close{C18FiveVoid(_nativeHost,NSSelectorFromString(@"controlCenterDidDismiss"));[_moduleView removeFromSuperview];objc_setAssociatedObject(_nativeHost,&kOwner,nil,OBJC_ASSOCIATION_ASSIGN);_moduleView=nil;_nativeHost=nil;_instance=nil;[self removeFromSuperview];}
- (void)dealloc{objc_setAssociatedObject(_nativeHost,&kOwner,nil,OBJC_ASSOCIATION_ASSIGN);}
@end
