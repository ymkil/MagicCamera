//
//  MKShortVideoViewController.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#if 1
// 自定义摄像头采集部分，调试中
/*
 *  抽离的MKGPUImage 没有GPUImage强大的基础滤镜，所以暂时为抽离GPUImageBeautifyFilter的美颜效果，
 *  采用的另外一种 MKGPUImageBeautifyFilter 比较消耗CPU，会出现卡顿现象，后续待优化
 *  想要看美颜效果的，可以把使用 GPUImage 采集的 UI(无断点录制效果)
 */
#import "MKShortVideoViewController.h"
#import "MKPreviewView.h"
#import "MKShortVideoCamera.h"
#import "MKShortEffectHandler.h"
#import "MKEffectHandler.h"
#import "MKOverlayView.h"
#import "MKGPUImageView.h"
#import "MKHeader.h"

#import <AssetsLibrary/AssetsLibrary.h>

#import "MKLandmarkManager.h"

@interface MKShortVideoViewController () <MKShootRecordRenderDelegate, MKOverlayViewDelegate>
{
    BOOL isVideoEffects;
}

@property(nonatomic, strong) MKShortEffectHandler *effectHandler;

@property(nonatomic, strong) MKShortVideoCamera *videoCamera;
@property(nonatomic, strong) MKGPUImageView *previewView;
@property(nonatomic, strong) MKOverlayView *overlayView;

@end

@implementation MKShortVideoViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _previewView = [[MKGPUImageView alloc] initWithFrame:self.view.bounds];
    _previewView.fillMode = kMKGPUImageFillModePreserveAspectRatioAndFill;
    [self.view addSubview:_previewView];
    
    _videoCamera = [[MKShortVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront size:CGSizeMake(480, 640)];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    _videoCamera.delegate = self;
  
    // 激活人脸SDK
    if ([self activateFaceSDK]) {
        [self activateVideoEffects];
    }
    
    [_videoCamera startSession];
    
    _overlayView = [[MKOverlayView alloc] initWithFrame:self.view.bounds];
    _overlayView.delegate = self;
    _overlayView.tapToFocusEnabled = _videoCamera.isSupportsTapToFocus;
    _overlayView.tapToExposeEnabled = _videoCamera.isSupportsTapToExpose;
    [self.view addSubview:_overlayView];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark video effects
- (void)activateVideoEffects {
    _effectHandler = [[MKShortEffectHandler alloc] initWithProcessTexture:YES];
    isVideoEffects = YES;
}

#pragma mark-
#pragma mark ActivateFaceSDKNotification

- (BOOL)activateFaceSDK {
    
    if (!MKLandmarkManager.shareManager.isAuthorization) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activateFaceSDKClick:) name:MKLandmarkAuthorizationNotificationName object:nil];
        [MKLandmarkManager.shareManager faceLicenseAuthorization];
        return NO;
    }
    return YES;
}

- (void)activateFaceSDKClick:(NSNotification *)notification
{
    NSString *isactivate = notification.userInfo[@"isActivate"];
    if ([isactivate isEqualToString:@"1"]) {      // 激活成功
        // 启动特效
        [self activateVideoEffects];
    } else {                                    // 激活失败
        
    }
}

#pragma mark-
#pragma mark MKShootRecordRenderDelegate

- (void)renderTexture:(GLuint) inputTextureId inputSize:(CGSize)newSize rotateMode:(MKGPUImageRotationMode)rotation
{
    [_previewView renderTexture:inputTextureId inputSize:newSize rotateMode:rotation];
}

- (void)effectsProcessingTexture:(GLuint)texture inputSize:(CGSize)size rotateMode:(MKGPUImageRotationMode)rotation
{
    if (isVideoEffects) {
        [self.effectHandler setRotateMode:rotation];
        [self.effectHandler processWithTexture:texture width:size.width height:size.height];
    }
}

- (void)didWriteMovieAtURL:(NSURL *)outputURL {

}

#pragma mark -
#pragma mark MKOverlayViewDelegate
- (void)startRecord
{
    [_videoCamera startWriting];
    NSLog(@"开始录制");
}
- (void)stopRecord
{
    [_videoCamera stopWriting];
    NSLog(@"停止录制");
}

- (void)deleteUpSegment
{
    
}

- (void)tappedToFocusAtPoint:(CGPoint)point {
    [_videoCamera focusAtPoint:point];
}

- (void)tappedToExposeAtPoint:(CGPoint)point {
    [_videoCamera exposeAtPoint:point];
}

- (void)tappedToResetFocusAndExposure {
    [_videoCamera resetFocusAndExposureModes];
}

- (void)rotateCamera {
    [_videoCamera rotateCamera];
}

#pragma mark-
#pragma mark ViewDelegate

-(void)alterFilterModel:(MKFilterModel*) model
{
    [_effectHandler setFilterModel:model];
}
-(void)alterIntensity:(float) intensity
{
    [_effectHandler setIntensity:intensity];
}

@end

#else
// GPUImage 摄像头采集部分，已实现大部分功能(美颜、2D贴纸、大脸瘦眼、唇彩等)
#import "MKShortVideoViewController.h"
#import "MKEffectFilter.h"
#import <GPUImage/GPUImage.h>
#import <Masonry/Masonry.h>

#import "GPUImageBeautifyFilter.h"

#import "MKCameraView.h"

@interface MKShortVideoViewController () <CameraViewDelegate>
{
    GPUImageVideoCamera *_videoCamera;
    GPUImageBeautifyFilter *_beautifyFilter;
    GPUImageView *_cameraPreview;
    UIButton *_beautifyButton;
}

@property(nonatomic, strong) UIView *welcomeView;

@property(nonatomic, strong) MKEffectFilter *effectFilter;

@end

@implementation MKShortVideoViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _welcomeView = [[UIView alloc] initWithFrame:self.view.bounds];
    _welcomeView.backgroundColor = [[UIColor alloc] initWithRed:59/255.0 green:55/255.0 blue: 54/255.0 alpha:0.5];
    
    UIButton *startBut = [[UIButton alloc] init];
    [startBut setTitle:@"开启" forState:UIControlStateNormal];
    [startBut addTarget:self action:@selector(startVideo) forControlEvents:UIControlEventTouchUpInside];
    
    [_welcomeView addSubview:startBut];
    [startBut mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(_welcomeView.mas_centerX);
        make.centerY.equalTo(_welcomeView.mas_centerY);
        make.width.mas_equalTo(80);
        make.height.mas_equalTo(40);
    }];
    
    [self.view addSubview:_welcomeView];
}


-(void)startVideo {
    [_welcomeView removeFromSuperview];
    
    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    
    _cameraPreview = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    _cameraPreview.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    [self.view addSubview:_cameraPreview];
    
    _effectFilter = [[MKEffectFilter alloc] init];
    
    _beautifyFilter = [[GPUImageBeautifyFilter alloc] init];
    _beautifyFilter.intensity = 0.9;
    
    [_videoCamera addTarget:_effectFilter];
    [_effectFilter addTarget:_beautifyFilter];
    [_beautifyFilter addTarget:_cameraPreview];
    [_videoCamera startCameraCapture];
    
    // UI
    MKCameraView *cameraView = [[MKCameraView alloc] initWithFrame:self.view.bounds];
    cameraView.delegate = self;
    [self.view addSubview:cameraView];
}


#pragma mark-
#pragma mark ViewDelegate

-(void)alterFilterModel:(MKFilterModel*) model
{
    [_effectFilter setFilterModel:model];
}
-(void)alterIntensity:(float) intensity
{
    [_effectFilter setIntensity:intensity];
}

@end


#endif
