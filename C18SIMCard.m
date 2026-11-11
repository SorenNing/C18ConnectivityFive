#import "C18Five.h"
#import <QuartzCore/QuartzCore.h>
extern void MSHookMessageEx(Class,SEL,IMP,IMP*);
typedef void(^SIMHandler)(UIAlertAction*);
@interface SIMItem:NSObject@property(nonatomic,copy)NSString*carrier;@property(nonatomic)BOOL enabled;@property(nonatomic,strong)UIAlertAction*action;@property(nonatomic,copy)SIMHandler handler;@end
@implementation SIMItem@end
@interface SIMRow:UIControl@property(nonatomic,strong)UILabel*badge;@property(nonatomic,strong)UILabel*carrier;@end
@implementation SIMRow
- (instancetype)initWithItem:(SIMItem*)i{if(!(self=[super initWithFrame:CGRectZero]))return nil;_badge=[UILabel new];_badge.text=i.enabled?@"已开启":@"已关闭";_badge.textAlignment=NSTextAlignmentCenter;_badge.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];_badge.textColor=UIColor.whiteColor;_badge.backgroundColor=i.enabled?[UIColor colorWithRed:.2 green:.78 blue:.35 alpha:1]:[UIColor colorWithWhite:1 alpha:.16];_badge.layer.cornerRadius=12;_badge.clipsToBounds=YES;_carrier=[UILabel new];_carrier.text=i.carrier;_carrier.textColor=UIColor.whiteColor;_carrier.font=[UIFont systemFontOfSize:16];[self addSubview:_badge];[self addSubview:_carrier];return self;}
- (void)layoutSubviews{[super layoutSubviews];CGFloat w=self.bounds.size.width,h=self.bounds.size.height,bw=MAX(64,ceil([self.badge sizeThatFits:CGSizeMake(CGFLOAT_MAX,24)].width)+20),gap=12,cw=MIN(ceil([self.carrier sizeThatFits:CGSizeMake(CGFLOAT_MAX,h)].width),MAX(20,w-32-bw-gap)),x=(w-bw-gap-cw)*.5;self.badge.frame=CGRectMake(x,(h-24)*.5,bw,24);self.carrier.frame=CGRectMake(x+bw+gap,0,cw,h);}
@end
@interface SIMController:UIViewController@property(nonatomic,strong)NSArray*items;@property(nonatomic,strong)UIImage*glyph;@end
@implementation SIMController
- (void)loadView{UIView*v=[[UIView alloc]initWithFrame:CGRectMake(0,0,336,236)];v.layer.cornerRadius=44;v.clipsToBounds=YES;self.view=v;self.preferredContentSize=CGSizeMake(336,236);UIVisualEffectView*m=[[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];m.alpha=.88;m.frame=v.bounds;[v addSubview:m];UIImageView*icon=[[UIImageView alloc]initWithImage:[self.glyph imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];icon.tintColor=UIColor.whiteColor;icon.frame=CGRectMake(152,20,32,32);[v addSubview:icon];UILabel*h=[UILabel new];h.text=@"蜂窝管理";h.textColor=UIColor.whiteColor;h.textAlignment=NSTextAlignmentCenter;h.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];h.frame=CGRectMake(16,62,304,27);[v addSubview:h];CGFloat rh=67;for(NSUInteger n=0;n<self.items.count;n++){SIMRow*r=[[SIMRow alloc]initWithItem:self.items[n]];r.frame=CGRectMake(0,102+n*rh,336,rh);[v addSubview:r];}}
@end
void C18SIMInstallCard(void){}
