//
//  ViewController.m
//  MKBeautyEffectsDemo
//
//  Created by mkil on 2019/8/15.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "ViewController.h"
#import "MKEffectFilter.h"
#import <GPUImage/GPUImage.h>

@interface ViewController ()<GPUImageVideoCameraDelegate>
{
    GPUImageVideoCamera *_videoCamera;
    MKEffectFilter *_effectFilter;
    GPUImageView *_cameraPreview;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // GPUImage
    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = YES;

    
    _cameraPreview = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    _cameraPreview.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    [self.view addSubview:_cameraPreview];
    
    _effectFilter = [[MKEffectFilter alloc] init];
    
    [_videoCamera addTarget:_effectFilter];
    [_effectFilter addTarget:_cameraPreview];
    
    [_videoCamera startCameraCapture];

}



@end
