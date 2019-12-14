//
//  MKShootRecordView.m
//  MagicCamera
//
//  Created by mkil on 2019/11/16.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKShootRecordView.h"
static const CGFloat BORDERLAYER_WIDTH = 80;
static const CGFloat CENTERLAYER_WIDTH = 60;
static const CGFloat BORDERWIDTH_FROM = 5;
static const CGFloat BORDERWIDTH_TO = 10;
static NSString *const BORDERWIDTH_ANIMATION_KEY = @"borderWidthAnimation";

@interface MKShootRecordView()
@property (nonatomic ,strong) CALayer *centerlayer;
@property (nonatomic, strong) CALayer *borderLayer;
@property (nonatomic, strong) UILabel *titleLB;
@end

@implementation MKShootRecordView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self setupUI];
    }
    return self;
}

#pragma mark - 懒加载
- (UILabel *)titleLB{
    if (!_titleLB) {
        _titleLB = [[UILabel alloc]initWithFrame:CGRectZero];
        _titleLB.textColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
        _titleLB.textAlignment = NSTextAlignmentCenter;
        _titleLB.backgroundColor = [UIColor clearColor];
        _titleLB.text = @"按住拍";
        [_titleLB sizeToFit];
        _titleLB.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    }
    return _titleLB;
}

#pragma mark - 初始化视图
- (void)setupUI{
    
    // 红色边框
    CALayer *borderLayer = [CALayer layer];
    borderLayer.backgroundColor = [UIColor clearColor].CGColor;
    borderLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    borderLayer.bounds = CGRectMake(0, 0, BORDERLAYER_WIDTH, BORDERLAYER_WIDTH);
    borderLayer.cornerRadius = BORDERLAYER_WIDTH / 2.0;
    borderLayer.masksToBounds = YES;
    borderLayer.borderColor = [UIColor colorWithRed:251/255.0 green:49/255.0 blue:89/255.0 alpha:0.5].CGColor;
    borderLayer.borderWidth = BORDERWIDTH_FROM;
    [self.layer addSublayer:borderLayer];
    _borderLayer = borderLayer;
    
    // 红色中心
    CALayer *centerlayer = [CALayer layer];
    centerlayer.backgroundColor = [UIColor colorWithRed:251/255.0 green:49/255.0 blue:89/255.0 alpha:1].CGColor;
    centerlayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    centerlayer.bounds = CGRectMake(0, 0, CENTERLAYER_WIDTH, CENTERLAYER_WIDTH);
    centerlayer.cornerRadius = CENTERLAYER_WIDTH / 2.0;
    centerlayer.masksToBounds = YES;
    [self.layer addSublayer:centerlayer];
    _centerlayer = centerlayer;
    
    // 标签
    [self addSubview:self.titleLB];
    
    [self addTarget:self action:@selector(touchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
}

#pragma mark - 私有方法
- (void)borderAnimaton{
    CABasicAnimation *animation = [CABasicAnimation animation];
    animation.keyPath = @"borderWidth";
    animation.repeatCount = FLT_MAX;
    animation.removedOnCompletion = NO;
    animation.duration = 0.5;
    animation.fromValue = @(BORDERWIDTH_FROM);
    animation.toValue = @(BORDERWIDTH_TO);
    animation.fillMode = kCAFillModeBackwards;
    animation.autoreverses = YES;
    [self.borderLayer addAnimation:animation forKey:BORDERWIDTH_ANIMATION_KEY];
}

- (void)scaleAnimation{
    
    _titleLB.hidden = YES;
    
    [UIView animateWithDuration:0.25 animations:^{
        self.centerlayer.cornerRadius = BORDERWIDTH_TO;
        self.centerlayer.transform = CATransform3DMakeScale(0.7, 0.7, 1);
        self.borderLayer.transform = CATransform3DMakeScale(1.8, 1.8, 1);
    } completion:^(BOOL finished) {
        [self borderAnimaton];
    }];
}
- (void)resetAnimation{
    
    [self.borderLayer removeAnimationForKey:BORDERWIDTH_ANIMATION_KEY];
    
    [UIView animateWithDuration:0.25 animations:^{
        self.centerlayer.cornerRadius = CENTERLAYER_WIDTH / 2.0;
        self.borderLayer.borderWidth = BORDERWIDTH_FROM;
        self.borderLayer.transform = CATransform3DIdentity;
        self.centerlayer.transform = CATransform3DIdentity;
    }completion:^(BOOL finished) {
        self.titleLB.hidden = NO;
    }];
}

#pragma mark - 响应事件
- (void)touchDown{
    [self scaleAnimation];
    if ([self.delegate respondsToSelector:@selector(startRecord)]) {
        [self.delegate startRecord];
    }
}
- (void)done{
    [self resetAnimation];
    if ([self.delegate respondsToSelector:@selector(stopRecord)]) {
        [self.delegate stopRecord];
    }
}

@end

