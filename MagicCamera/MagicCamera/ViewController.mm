//
//  ViewController.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

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
