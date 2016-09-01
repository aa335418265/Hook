//
//  SpreadButtonManager.m
//  FloatWindowDemo
//
//  Created by fenglh on 16/7/25.
//  Copyright © 2016年 xiaoxigame. All rights reserved.
//

#import "SpreadButtonManager.h"
#import "UIColor+CustomColors.h"
#import "FlatButton.h"
#import "AnimationsListViewController.h"
#import "HUTransitionAnimator.h"
#import <pop/POP.h>
#import <AudioToolbox/AudioToolbox.h>
#import "UIApplication+ITXExtension.h"
#import <objc/runtime.h>

#define TopView [UIApplication itx_topViewController].view

@interface SpreadButtonManager ()<UINavigationControllerDelegate>
@property (nonatomic, strong) FlatButton *circleButton;
@property (nonatomic,readwrite, assign) BOOL isShowing;
@property (nonatomic,readwrite, assign) BOOL isWXLocking;
@property (nonatomic,readwrite, assign) BOOL avoidRevoke;//放撤销
@property (nonatomic,readwrite, assign) BOOL oneKeyRecord;//一键录音
@property (nonatomic,readwrite, assign) RedEnvPluginType redEnvPluginType;//抢红包类型
@property (nonatomic,assign) CGPoint orignPosition;


@end
@implementation SpreadButtonManager


+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static SpreadButtonManager *instanced=nil;
    dispatch_once(&once, ^{
        instanced = [[SpreadButtonManager alloc] init];
        [instanced configureUI];
    });
    return instanced;
}


#pragma mark -公有方法

//一键录音
- (BOOL)oneKeyRecord
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"OneKeyRecord"] boolValue];
}

- (void)openOneKeyRecord:(BOOL)open
{
    [[NSUserDefaults standardUserDefaults] setObject:@(open) forKey:@"OneKeyRecord"];
}
//抢红包
- (RedEnvPluginType)redEnvPluginType
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"RedEnvPluginType"] integerValue];
}
- (void)openRedEnvPlugin:(RedEnvPluginType)type
{
    [[NSUserDefaults standardUserDefaults] setObject:@(type) forKey:@"RedEnvPluginType"];
}
//防撤销
- (BOOL)avoidRevoke
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"AvoidRevoke"] boolValue];
}
- (void)openAvoidRevoke:(BOOL)open
{
    [[NSUserDefaults standardUserDefaults] setObject:@(open) forKey:@"AvoidRevoke"];
}

- (void)shake
{
    NSLog(@"摇一摇");
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    if (self.isShowing) {
        self.isShowing = NO;
        [self performFlyOutAnimation];
    }else{
        self.isShowing = YES;
        [self performFlyInAnimation];
    }
}

#pragma mark - 私有方法


- (void)configureUI
{
    [self addCircleButton];
}

- (void)addCircleButton
{
    self.circleButton = [FlatButton button];
    self.circleButton.backgroundColor = [UIColor customBlueColor];
    self.circleButton.frame = CGRectMake(20, -40, 40, 40);
    self.circleButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.circleButton.layer setMasksToBounds:YES];
    [self.circleButton addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.circleButton.layer setCornerRadius:20.0f];
//    UIPanGestureRecognizer *recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
//    [self.circleButton addGestureRecognizer:recognizer];
    
    UIViewController *topViewController = [UIApplication itx_topViewController];
    NSLog(@"初始化按钮在 :%@",[topViewController class]);
    [topViewController.view addSubview:self.circleButton];

}



- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC{
    HUTransitionAnimator *animator;
    animator = [[HUTransitionVerticalLinesAnimator alloc] init];
    animator.presenting = (operation == UINavigationControllerOperationPop)?NO:YES;
    return animator;
}

- (void)buttonClick:(FlatButton *)button
{
    [self pauseAllAnimations:YES forLayer:button.layer];
    AnimationsListViewController *animationsListViewController = [[AnimationsListViewController alloc] init];
    animationsListViewController.hidesBottomBarWhenPushed = YES;
    UIViewController *topVC = [UIApplication itx_topViewController];
    topVC.navigationController.delegate = self;
    NSString *string = [NSString stringWithFormat:@"%@",[topVC class]];
    NSLog(@"按钮点击-》top ViewController:%@",string);
    if ([topVC isKindOfClass:objc_getClass("NewMainFrameViewController")]) {
        NSLog(@"调用微信自己的PushViewController函数");
        [topVC performSelector:@selector(PushViewController:) withObject:animationsListViewController];
    }else{
        NSLog(@"自行调用topVC.navigationController pushViewController");
        [topVC.navigationController pushViewController:animationsListViewController animated:YES];
    }
}

- (void)pauseAllAnimations:(BOOL)pause forLayer:(CALayer *)layer
{
    for (NSString *key in layer.pop_animationKeys) {
        POPAnimation *animation = [layer pop_animationForKey:key];
        [animation setPaused:pause];
    }
}

- (void)performFlyOutAnimation
{
    [self.circleButton.layer pop_removeAllAnimations];
    POPBasicAnimation *offscreenAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    offscreenAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    offscreenAnimation.toValue = @(CGRectGetHeight([[UIScreen mainScreen] bounds])  + 40);
    offscreenAnimation.beginTime = CACurrentMediaTime() + 0.75;
    [self.circleButton.layer pop_addAnimation:offscreenAnimation forKey:@"offscreenAnimation"];

}

- (void)performFlyInAnimation
{
    [self.circleButton.layer pop_removeAllAnimations];
    //设置弹簧动画
    POPSpringAnimation *springAnim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    springAnim.beginTime = CACurrentMediaTime() + 0.75;
    springAnim.springBounciness = 15;
    springAnim.springSpeed = 5;
    springAnim.fromValue = @-40;
    springAnim.toValue = @(CGRectGetHeight([[UIScreen mainScreen] bounds]) - 100);
    
    //设置不透明度动画
    POPBasicAnimation *opacityAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    //时间函数（加速入，减速出）
    opacityAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    opacityAnim.duration = 0.25;
    opacityAnim.toValue = @1.0;
    [self.circleButton.layer pop_addAnimation:springAnim forKey:@"AnimationSpring"];
    [self.circleButton.layer pop_addAnimation:opacityAnim forKey:@"AnimationOpacity"];
}



#pragma mark - getters and setters
- (void)setAuthValidTime:(double)seconds
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[NSDate date] forKey:@"AuthStartDate"];
    [dict setObject:@(seconds) forKey:@"AuthValidSeconds"];
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:@"AuthInfo"];
}

- (NSUInteger)authTimeLeftSecond
{
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:@"AuthInfo"];
    
    NSDate *authStartDate = [dict objectForKey:@"AuthStartDate"];
    double authValidSeconds = [[dict objectForKey:@"AuthValidSeconds"] doubleValue];
    
    if (authStartDate == nil) {
        return 0;
    }
    
    double timeInterval = [[NSDate date] timeIntervalSinceDate:authStartDate];
    if (timeInterval > authValidSeconds) {
        NSLog(@"认证时间已过期");
        return 0;
    }
    double timeLeftSeconds = authValidSeconds - timeInterval;
    NSLog(@"剩余时间:%fls",timeInterval);
    return timeLeftSeconds;
}

@end
