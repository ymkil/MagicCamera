//
//  ViewController.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#if 1
// 自定义摄像头采集部分，调试中
#import "ViewController.h"
#import "MKPreviewView.h"
#import "MKBaseVideoCamera.h"
#import "MKShootRecordView.h"

@interface ViewController () <MKShootRecordViewDelegate>

@property(nonatomic, strong)MKBaseVideoCamera *videoCamera;
@property(nonatomic, strong)MKShootRecordView *shootRecordView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    MKPreviewView *previewView = [[MKPreviewView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:previewView];
    
    CGFloat x = CGRectGetMidX(self.view.bounds) - 40;
    CGFloat y = CGRectGetHeight(self.view.bounds) - 80 - 60;
    
    _shootRecordView = [[MKShootRecordView alloc] initWithFrame:CGRectMake(x, y, 80, 80)];
    _shootRecordView.delegate = self;
    [self.view addSubview:_shootRecordView];
    
    _videoCamera = [[MKBaseVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    
    NSError *error;
    if ([_videoCamera setupSession:&error]) {
        [previewView setSession:_videoCamera.captureSession];
        [_videoCamera startSession];
    } else {
        NSLog(@"Error: %@", [error localizedDescription]);
    }
}

- (void)startRecord
{
    NSLog(@"开始录制");
}
- (void)stopRecord
{
    NSLog(@"停止录制");
}

@end

#else
// GPUImage 摄像头采集部分，已实现大部分功能(美颜、2D贴纸、大脸瘦眼、唇彩等)
#import "ViewController.h"
#import "MKEffectFilter.h"
#import <GPUImage/GPUImage.h>
#import <Masonry/Masonry.h>

#import "GPUImageBeautifyFilter.h"

#import "MKCameraView.h"

@interface ViewController () <CameraViewDelegate>
{
    GPUImageVideoCamera *_videoCamera;
    GPUImageBeautifyFilter *_beautifyFilter;
    GPUImageView *_cameraPreview;
    UIButton *_beautifyButton;
}

@property(nonatomic, strong) UIView *welcomeView;

@property(nonatomic, strong) MKEffectFilter *effectFilter;

@end

@implementation ViewController


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
