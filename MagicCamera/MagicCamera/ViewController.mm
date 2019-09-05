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
#import "MGFaceLicenseHandle.h"

#import "GPUImageBeautifyFilter.h"

#import "MKCameraView.h"

@interface ViewController ()
{
    GPUImageVideoCamera *_videoCamera;
    GPUImageBeautifyFilter *_beautifyFilter;
    GPUImageView *_cameraPreview;
    UIButton *_beautifyButton;
}

@property(nonatomic, strong) MKEffectFilter *effectFilter;

@end

@implementation ViewController

-(MKEffectFilter*)effectFilter
{
    if (!_effectFilter) {
        _effectFilter = [[MKEffectFilter alloc] init];
    }
    return _effectFilter;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    
    _cameraPreview = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    _cameraPreview.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    [self.view addSubview:_cameraPreview];
    
    _beautifyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _beautifyButton.backgroundColor = [UIColor whiteColor];
    [_beautifyButton setTitle:@"开启" forState:UIControlStateNormal];
    [_beautifyButton setTitle:@"关闭" forState:UIControlStateSelected];
    [_beautifyButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [_beautifyButton addTarget:self action:@selector(beautify) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_beautifyButton];
    [_beautifyButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.view).offset(-20);
        make.width.equalTo(@100);
        make.height.equalTo(@40);
        make.centerX.equalTo(self.view);
    }];
    
    _beautifyFilter = [[GPUImageBeautifyFilter alloc] init];
    _beautifyFilter.intensity = 0.9;
    
    [_videoCamera addTarget:_cameraPreview];
    [_videoCamera startCameraCapture];
    
    // UI
//    MKCameraView *cameraView = [[MKCameraView alloc] initWithFrame:self.view.bounds];
//    [self.view addSubview:cameraView];
    //
    //
    //    UIImageView *test = [[UIImageView alloc] init];
    //    test.frame = CGRectMake(50, 100, 100, 100);
    //    NSString *path = [[NSBundle mainBundle] pathForResource:@"beautify" ofType:@"png"];
    //
    //    test.image = [UIImage imageWithContentsOfFile:path];
    //
    //    [self.view addSubview:test];
}

- (void)beautify {
    
    if (_beautifyButton.selected) {
        _beautifyButton.selected = NO;
        [_videoCamera removeAllTargets];
        [_videoCamera addTarget:_cameraPreview];
    }
    else {
        _beautifyButton.selected = YES;
        [_videoCamera removeAllTargets];
        if (![MGFaceLicenseHandle getLicense]) {
            [_videoCamera addTarget:self.effectFilter];
            [self.effectFilter addTarget:_beautifyFilter];
            [_beautifyFilter addTarget:_cameraPreview];
        } else {
            [_videoCamera addTarget:_beautifyFilter];
            [_beautifyFilter addTarget:_cameraPreview];
        }
    }
}


@end
