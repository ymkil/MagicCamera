//
//  MKShortVideoViewController.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

/*  这里是抽离 GPUImage 采集部分，由于早期架构不过成熟，会出现一些异常bug，这部分跑起来前面几次会崩溃
 *  查看效果请使用下面一段代码  #if 1 , 下面这段没有实现断点录制功能(#if 0 实现断点录制功能 暂时因为架构会报错)
 *  准备全面采用 GPUImage , 温馨提示: 不要轻易自己抽离GPUImage , 当然大神另外, 不然会有各种异常bug
 */
#if 0

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

#import "MKVideoEditViewController.h"
#import "MKSegmentVideoAssetAdapter.h"


@interface MKShortVideoViewController () <MKShootRecordRenderDelegate, MKOverlayViewDelegate>
{
    NSMutableArray *_fileURLs;
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
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    self.navigationController.navigationBarHidden = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _videoCamera = [[MKShortVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront size:CGSizeMake(480, 640)];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    _videoCamera.delegate = self;
  
    _effectHandler = [[MKShortEffectHandler alloc] initWithProcessTexture:YES];
    
    _previewView = [[MKGPUImageView alloc] initWithFrame:self.view.bounds];
    _previewView.fillMode = kMKGPUImageFillModePreserveAspectRatioAndFill;
    [self.view addSubview:_previewView];
    
    
    _overlayView = [[MKOverlayView alloc] initWithFrame:self.view.bounds];
    _overlayView.delegate = self;
    _overlayView.tapToFocusEnabled = _videoCamera.isSupportsTapToFocus;
    _overlayView.tapToExposeEnabled = _videoCamera.isSupportsTapToExpose;
    [self.view addSubview:_overlayView];
    
    _fileURLs = [NSMutableArray arrayWithCapacity:10];
    
    [_videoCamera startSession];
}

#pragma mark-
#pragma mark MKShootRecordRenderDelegate

- (void)renderTexture:(GLuint) inputTextureId inputSize:(CGSize)newSize rotateMode:(MKGPUImageRotationMode)rotation
{
    [_previewView renderTexture:inputTextureId inputSize:newSize rotateMode:rotation];
}

- (void)effectsProcessingTexture:(GLuint)texture inputSize:(CGSize)size rotateMode:(MKGPUImageRotationMode)rotation
{
    [self.effectHandler setRotateMode:rotation];
    [self.effectHandler processWithTexture:texture width:size.width height:size.height];
}

- (void)didWriteMovieAtURL:(NSURL *)outputURL {
    [_fileURLs addObject:outputURL];
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
    // 测试       分段删除测试
    [_fileURLs removeLastObject];
    
    // 视频编辑调试
//    MKVideoEditViewController *editVC = [[MKVideoEditViewController alloc] init];
//
//    MKSegmentVideoAssetAdapter *assetAdapter = [[MKSegmentVideoAssetAdapter alloc] initWithURLs:_fileURLs];
//
//    editVC.assetAdapter = assetAdapter;
//
//    [self.navigationController pushViewController:editVC animated:true];
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

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    self.navigationController.navigationBarHidden = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
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
