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

@property(nonatomic, strong) MKEffectFilter *effectFilter;

@end

@implementation ViewController


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
