//
//  MKShortVideoViewController.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

/*
 *  抽离的MKGPUImage 没有GPUImage强大的基础滤镜，所以暂时为抽离GPUImageBeautifyFilter的美颜效果，
 *  采用的另外一种 MKGPUImageBeautifyFilter 比较消耗CPU，会出现卡顿现象，后续待优化
 *  想要看美颜效果的，可以单独拿出 GPUImageBeautifyFilter 使用(或者查看我的博客 https://juejin.im/post/5db14158e51d452a0a3af356 )
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
    

    _previewView = [[MKGPUImageView alloc] initWithFrame:self.view.bounds];
    _previewView.fillMode = kMKGPUImageFillModePreserveAspectRatioAndFill;
    [self.view addSubview:_previewView];
    
    _videoCamera = [[MKShortVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront size:CGSizeMake(480, 640)];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    _videoCamera.delegate = self;
  
    _effectHandler = [[MKShortEffectHandler alloc] initWithProcessTexture:YES];
    [_videoCamera startSession];
    
    _overlayView = [[MKOverlayView alloc] initWithFrame:self.view.bounds];
    _overlayView.delegate = self;
    _overlayView.tapToFocusEnabled = _videoCamera.isSupportsTapToFocus;
    _overlayView.tapToExposeEnabled = _videoCamera.isSupportsTapToExpose;
    [self.view addSubview:_overlayView];
    
    _fileURLs = [NSMutableArray arrayWithCapacity:10];
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
