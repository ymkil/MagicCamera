//
//  MKOverlayView.m
//  MagicCamera
//
//  Created by mkil on 2019/11/29.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKOverlayView.h"
#import "MKHeader.h"
#import "MKShootRecordView.h"
#import "MKRecordProgressView.h"
#import "MKCameraFilterView.h"
#import <Masonry/Masonry.h>

#define BOX_BOUNDS CGRectMake(0.0f, 0.0f, 150, 150.0f)

@interface MKOverlayView() <MKShootRecordViewDelegate>

@property(nonatomic, strong) MKShootRecordView *shootRecordView;        // 拍摄button
@property(nonatomic, strong) MKRecordProgressView *progressView;        // 进度条

@property (strong, nonatomic) UIView *focusBox;
@property (strong, nonatomic) UIView *exposureBox;

@property (nonatomic, strong) UIView *gestureDominateView;
@property (strong, nonatomic) UITapGestureRecognizer *singleTapRecognizer;
@property (strong, nonatomic) UITapGestureRecognizer *doubleTapRecognizer;
@property (strong, nonatomic) UITapGestureRecognizer *doubleDoubleTapRecognizer;

@property (nonatomic,strong) NSTimer *videoTimer;
@property (nonatomic,assign) CGFloat recordDuration;


@property (nonatomic, strong) MKCameraFilterView *filterView;

@property (nonatomic, strong) UIButton *effectBt;
@property (nonatomic, strong) UIButton *filterStyleBt;
@property (nonatomic, strong) UIButton *beautifyBt;

@property (nonatomic, strong) NSArray<MKFilterModel *> *styleFilterModels;
@property (nonatomic, strong) NSArray<MKFilterModel *> *stickerFilterModels;

@property (nonatomic, strong, readwrite) UIButton *rotateButton;
@property (nonatomic, assign) BOOL isRotating;  // 正在旋转中

@end

@implementation MKOverlayView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self generateDataSource];
        [self setupView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self generateDataSource];
        [self setupView];
    }
    return self;
}


- (void)setupView {
    
    _gestureDominateView = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:_gestureDominateView];
    
    CGFloat x = CGRectGetMidX(self.bounds) - 40;
    CGFloat y = CGRectGetHeight(self.bounds) - 80 - 60;
    
    _shootRecordView = [[MKShootRecordView alloc] initWithFrame:CGRectMake(x, y, 80, 80)];
    _shootRecordView.delegate = self;
    [self addSubview:_shootRecordView];
    
    _progressView = [[MKRecordProgressView alloc] initWithFrame:CGRectMake(5, 5, self.bounds.size.width - 10, 3)];
    _progressView.step = 1/(15/0.1);
    weakSelf()
    _progressView.deleteToProgressValue = ^(CGFloat value) {
        
        NSLog(@"deleteValue %f",15/value);
        
        wself.recordDuration -= 15/value;
        if (wself.recordDuration < 0) {
            wself.recordDuration = 0;
        }
    };
    NSLog(@"step = %f",_progressView.step);
    [self addSubview:_progressView];
    
    // TODO: 断点回删(测试按钮)
    UIButton *deleteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    deleteBtn.frame = CGRectMake(160, 100, 60, 20);
    [self addSubview:deleteBtn];
    [deleteBtn addTarget:self action:@selector(delete) forControlEvents:UIControlEventTouchUpInside];
    [deleteBtn setTitle:@"delete" forState:UIControlStateNormal];
    [deleteBtn setTitleColor:UIColor.redColor forState:UIControlStateNormal];
    
    
    _singleTapRecognizer =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    
    _doubleTapRecognizer =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    _doubleTapRecognizer.numberOfTapsRequired = 2;
    
    _doubleDoubleTapRecognizer =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleDoubleTap:)];
    _doubleDoubleTapRecognizer.numberOfTapsRequired = 2;
    _doubleDoubleTapRecognizer.numberOfTouchesRequired = 2;
    
    [_gestureDominateView addGestureRecognizer:_singleTapRecognizer];
    [_gestureDominateView addGestureRecognizer:_doubleTapRecognizer];
    [_gestureDominateView addGestureRecognizer:_doubleDoubleTapRecognizer];
    [_singleTapRecognizer requireGestureRecognizerToFail:_doubleTapRecognizer];
    
    _focusBox = [self viewWithColor:[UIColor colorWithRed:0.102 green:0.636 blue:1.000 alpha:1.000]];
    _exposureBox = [self viewWithColor:[UIColor colorWithRed:1.000 green:0.421 blue:0.054 alpha:1.000]];
    [self addSubview:_focusBox];
    [self addSubview:_exposureBox];
    
    // TODO: 已下滤镜UI还需要优化
    _filterView = [[MKCameraFilterView alloc] initWithFrame:CGRectMake(0, kScreenH - 65 - 90 - 40, kScreenW, 90)];
    
    _filterView.selectFilterModelBlock = ^(MKFilterModel *model) {
        if (wself.delegate) {
            [wself.delegate alterFilterModel:model];
        }
    };
    
    _filterView.changeIntensityValueBlock = ^(float intensity) {
        if (wself.delegate) {
            [wself.delegate alterIntensity:intensity];
        }
    };
    
    _effectBt = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.effectBt setImage:[UIImage imageNamed:@"bt_camera_effect"] forState:UIControlStateNormal];
    [_effectBt addTarget:self action:@selector(onEffectBtClick:) forControlEvents:UIControlEventTouchUpInside];
    
    _filterStyleBt = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.filterStyleBt setImage:[UIImage imageNamed:@"bt_camera_style_filter"] forState:UIControlStateNormal];
    [_filterStyleBt addTarget:self action:@selector(onFilterStyleBtClick:) forControlEvents:UIControlEventTouchUpInside];
    
    _beautifyBt = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.beautifyBt setImage:[UIImage imageNamed:@"bt_camera_face_texiao_nor"] forState:UIControlStateNormal];
    [_beautifyBt addTarget:self action:@selector(onBeautifyBtClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self addSubview:_filterView];
    [self addSubview:_effectBt];
    [self addSubview:_filterStyleBt];
    [self addSubview:_beautifyBt];
    
    [self.effectBt mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(34, 34));
        make.left.equalTo(self.mas_left).offset(36);
        make.bottom.equalTo(self.mas_bottom).offset(-65);
    }];
    
    [self.filterStyleBt mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(34, 34));
        make.right.equalTo(self.beautifyBt.mas_left).offset(-36);
        make.bottom.equalTo(self.mas_bottom).offset(-65);
    }];
    
    [self.beautifyBt mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(34, 34));
        make.right.equalTo(self.mas_right).offset(-36);
        make.bottom.equalTo(self.mas_bottom).offset(-65);
    }];
    
    [self setupRotateButton];
    
}

- (void)setupRotateButton {
    self.rotateButton = [[UIButton alloc] init];
    [self addSubview:self.rotateButton];
    [self.rotateButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self).offset(18);
        make.centerX.equalTo(self).multipliedBy(1.85);
        make.size.mas_equalTo(CGSizeMake(30, 30));
    }];
    [self.rotateButton addTarget:self
                          action:@selector(rotateAction:)
                forControlEvents:UIControlEventTouchUpInside];
    [self.rotateButton setImage:[UIImage imageNamed:@"btn_rotato"] forState:UIControlStateNormal];
}


- (void)handleSingleTap:(UIGestureRecognizer *)recognizer {
    CGPoint point = [recognizer locationInView:self];
    [self runBoxAnimationOnView:self.focusBox point:point];
    if (self.delegate) {
        [self.delegate tappedToFocusAtPoint:[self captureDevicePointForPoint:point]];
    }
}

- (CGPoint)captureDevicePointForPoint:(CGPoint)point {
    // 坐标转换
    CGPoint currentPoint = CGPointMake(point.y / self.bounds.size.height, 1 - point.x / self.bounds.size.width);
    
    return currentPoint;
}

- (void)handleDoubleTap:(UIGestureRecognizer *)recognizer {
    CGPoint point = [recognizer locationInView:self];
    [self runBoxAnimationOnView:self.exposureBox point:point];
    if (self.delegate) {
        [self.delegate tappedToExposeAtPoint:[self captureDevicePointForPoint:point]];
    }
}

- (void)handleDoubleDoubleTap:(UIGestureRecognizer *)recognizer {
    [self runResetAnimation];
    if (self.delegate) {
        [self.delegate tappedToResetFocusAndExposure];
    }
}

- (void)runBoxAnimationOnView:(UIView *)view point:(CGPoint)point {
    view.center = point;
    view.hidden = NO;
    [UIView animateWithDuration:0.15f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         view.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0);
                     }
                     completion:^(BOOL complete) {
                         double delayInSeconds = 0.5f;
                         dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                         dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                             view.hidden = YES;
                             view.transform = CGAffineTransformIdentity;
                         });
                     }];
}

- (void)runResetAnimation {
    if (!self.tapToFocusEnabled && !self.tapToExposeEnabled) {
        return;
    }

    CGPoint centerPoint = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
    self.focusBox.center = centerPoint;
    self.exposureBox.center = centerPoint;
    self.exposureBox.transform = CGAffineTransformMakeScale(1.2f, 1.2f);
    self.focusBox.hidden = NO;
    self.exposureBox.hidden = NO;
    [UIView animateWithDuration:0.15f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.focusBox.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0);
                         self.exposureBox.layer.transform = CATransform3DMakeScale(0.7, 0.7, 1.0);
                     }
                     completion:^(BOOL complete) {
                         double delayInSeconds = 0.5f;
                         dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                         dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                             self.focusBox.hidden = YES;
                             self.exposureBox.hidden = YES;
                             self.focusBox.transform = CGAffineTransformIdentity;
                             self.exposureBox.transform = CGAffineTransformIdentity;
                         });
                     }];
}

- (void)setTapToFocusEnabled:(BOOL)enabled {
    _tapToFocusEnabled = enabled;
    self.singleTapRecognizer.enabled = enabled;
}

- (void)setTapToExposeEnabled:(BOOL)enabled {
    _tapToExposeEnabled = enabled;
    self.doubleTapRecognizer.enabled = enabled;
}

- (UIView *)viewWithColor:(UIColor *)color {
    UIView *view = [[UIView alloc] initWithFrame:BOX_BOUNDS];
    view.backgroundColor = [UIColor clearColor];
    view.layer.borderColor = color.CGColor;
    view.layer.borderWidth = 5.0f;
    view.hidden = YES;
    return view;
}

#pragma mark-
#pragma mark MKShootRecordViewDelegate

- (void)startRecord
{
    [self.videoTimer invalidate];
    self.videoTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(recordProgressClick) userInfo:nil repeats:YES];
    [_progressView drawMoved];

    if ([self.delegate respondsToSelector:@selector(startRecord)]) {
        [self.delegate startRecord];
    }
}
- (void)stopRecord
{
    [_progressView drawPause];
    [self.videoTimer invalidate];
    
    if ([self.delegate respondsToSelector:@selector(stopRecord)]) {
        [self.delegate stopRecord];
    }
}

-(void)delete
{
    [self.videoTimer invalidate];
    [_progressView drawDelete];
    
    if ([self.delegate respondsToSelector:@selector(deleteUpSegment)]) {
        [self.delegate deleteUpSegment];
    }
}

- (void)recordProgressClick {
    _recordDuration+=0.1;
    if (_recordDuration > 15) {
        //        [self stop];
        return;
    }
    [_progressView drawMoved];
}

#pragma mark - PublicMethod


- (void)onEffectBtClick:(UIButton *)bt {
    _filterView.filterModels = _stickerFilterModels;
    [_filterView toggle];
}

- (void)onFilterStyleBtClick:(UIButton *)bt {
    _filterView.filterModels = _styleFilterModels;
    [_filterView toggle];
}

- (void)onBeautifyBtClick:(UIButton *)bt {
    
    
}

- (void)generateDataSource
{
    _styleFilterModels = [MKFilterModel buildFilterModelsWithPath:kStyleFilterPath whitType:MKFilterTypeStyle];
    _stickerFilterModels = [MKFilterModel buildFilterModelsWithPath:kStickerFilterPath whitType:MKFilterTypeEffects];
}

- (void)rotateAction:(UIButton *)button {
    if (self.isRotating) {
        return;
    }
    self.isRotating = YES;
    
    [UIView animateWithDuration:0.25f animations:^{
        self.rotateButton.transform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI);
    } completion:^(BOOL finished) {
        self.rotateButton.transform = CGAffineTransformIdentity;
        self.isRotating = NO;
    }];
    
    if ([self.delegate respondsToSelector:@selector(rotateCamera)]) {
        [self.delegate rotateCamera];
    }
}

@end
