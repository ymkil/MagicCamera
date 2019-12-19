//
//  MKBaseVideoCamera.m
//  MagicCamera
//
//  Created by mkil on 2019/11/16.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKBaseVideoCamera.h"

@interface MKBaseVideoCamera()

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property(nonatomic, strong) NSString *sessionPreset;
@property(nonatomic, weak) AVCaptureDeviceInput *activeVideoInput;
@property(nonatomic, weak) AVCaptureDeviceInput *activeAudioInput;
@property(nonatomic, weak) AVCaptureDevice *microphone;
@property(nonatomic, assign) AVCaptureDevicePosition cameraPosition;

@end

@implementation MKBaseVideoCamera

- (id)init;
{
    if (!(self = [self initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack]))
    {
        return nil;
    }
    
    return self;
}

- (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition
{
    if (!(self = [super init]))
    {
        return nil;
    }
    self.sessionPreset = sessionPreset;
    self.cameraPosition = cameraPosition;
    _cameraProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0);
    _audioProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0);
    
    
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = self.sessionPreset;
    
    // Set up default camera device
    AVCaptureDevice *videoDevice;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == _cameraPosition)
        {
            videoDevice = device;
        }
    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (videoInput) {
        if ([self.captureSession canAddInput:videoInput]) {
            [self.captureSession addInput:videoInput];
            self.activeVideoInput = videoInput;
        } else {
            NSLog(@"Couldn't add video device");
            return nil;
        }
    } else {
        return nil;
    }
    
    return self;
}

- (BOOL)addAudioInputs
{
    if (self.activeAudioInput) return NO;
    
    // Setup default microphone
    _microphone = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    NSError *error = nil;
    self.activeAudioInput =
    [AVCaptureDeviceInput deviceInputWithDevice:_microphone error:&error];
    if (self.activeAudioInput) {
        if ([self.captureSession canAddInput:self.activeAudioInput]) {
            [self.captureSession addInput:self.activeAudioInput];
        } else {
            NSLog(@"Couldn't add audio device");
            return NO;
        }
    } else {
        return NO;
    }
    return YES;
}

- (BOOL)removeAudioInputs
{
    if (!self.activeAudioInput) return NO;
    [_captureSession beginConfiguration];
    [_captureSession removeInput:self.activeAudioInput];
    self.activeAudioInput = nil;
    _microphone = nil;
    [_captureSession commitConfiguration];
    return YES;
}


- (BOOL)setupSessionOutputs:(NSError **)error {
    return YES;
}

- (AVCaptureDevicePosition)cameraPosition
{
    return [[_activeVideoInput device] position];
}

- (void)startSession {
    if (![self.captureSession isRunning]) {
        [self.captureSession startRunning];
    }
}

- (void)stopSession {
    if ([self.captureSession isRunning]) {
        [self.captureSession stopRunning];
    }
}

#pragma mark -
#pragma mark Device Configuration
- (BOOL)isPositionFront {
    return [self cameraPosition] == AVCaptureDevicePositionFront;
}

+ (BOOL)isFrontFacingCameraPresent;
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == AVCaptureDevicePositionFront)
            return YES;
    }
    
    return NO;
}

- (BOOL)isFrontFacingCameraPresent
{
    return [MKBaseVideoCamera isFrontFacingCameraPresent];
}


#pragma mark - Flash and Torch Modes
- (BOOL)isHasFlash {
    return [self.activeVideoInput.device hasFlash];
}

- (AVCaptureFlashMode)flashMode {
    return [self.activeVideoInput.device flashMode];
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode {
    
    AVCaptureDevice *device = self.activeVideoInput.device;
    
    if (device.flashMode != flashMode &&
        [device isFlashModeSupported:flashMode]) {
        
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.flashMode = flashMode;
            [device unlockForConfiguration];
        }
    }
}

- (BOOL)isHasTorch {
    return [self.activeVideoInput.device hasTorch];
}

- (AVCaptureTorchMode)torchMode {
    return [self.activeVideoInput.device torchMode];
}

- (void)setTorchMode:(AVCaptureTorchMode)torchMode {
    
    AVCaptureDevice *device = self.activeVideoInput.device;
    
    if (device.torchMode != torchMode &&
        [device isTorchModeSupported:torchMode]) {
        
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.torchMode = torchMode;
            [device unlockForConfiguration];
        }
    }
}

#pragma mark Focus Methods

- (BOOL)isSupportsTapToFocus {
    return [self.activeVideoInput.device isFocusPointOfInterestSupported];
}

- (void)focusAtPoint:(CGPoint)point {
    
    CGPoint currentPoint = point;
    if ([self isPositionFront]) {
        currentPoint = CGPointMake(currentPoint.x, 1 - currentPoint.y);
    }
    
    AVCaptureDevice *device = self.activeVideoInput.device;
    
    if (device.isFocusPointOfInterestSupported &&
        [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
        }
    }
}

#pragma mark -
#pragma mark - Exposure Methods
- (BOOL)isSupportsTapToExpose {
    return [self.activeVideoInput.device isExposurePointOfInterestSupported];
}

// Define KVO context pointer for observing 'adjustingExposure" device property.
static const NSString *MKCameraAdjustingExposureContext;

- (void)exposeAtPoint:(CGPoint)point {
    
    CGPoint currentPoint = point;
    if ([self isPositionFront]) {
        currentPoint = CGPointMake(currentPoint.x, 1 - currentPoint.y);
    }
    
    AVCaptureDevice *device = self.activeVideoInput.device;
    AVCaptureExposureMode exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    
    if (device.isExposurePointOfInterestSupported &&
        [device isExposureModeSupported:exposureMode]) {
        
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            
            device.exposurePointOfInterest = point;
            device.exposureMode = exposureMode;
            
            if ([device isExposureModeSupported:AVCaptureExposureModeLocked]) {
                [device addObserver:self
                         forKeyPath:@"adjustingExposure"
                            options:NSKeyValueObservingOptionNew
                            context:&MKCameraAdjustingExposureContext];
            }
            [device unlockForConfiguration];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if (context == &MKCameraAdjustingExposureContext) {
        AVCaptureDevice *device = (AVCaptureDevice *)object;
        
        if (!device.isAdjustingExposure &&
            [device isExposureModeSupported:AVCaptureExposureModeLocked]) {
            
            [object removeObserver:self
                        forKeyPath:@"adjustingExposure"
                           context:&MKCameraAdjustingExposureContext];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error;
                if ([device lockForConfiguration:&error]) {
                    device.exposureMode = AVCaptureExposureModeLocked;
                    [device unlockForConfiguration];
                }
            });
        }
        
        
    } else {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
    
}

- (void)resetFocusAndExposureModes {
    
    AVCaptureDevice *device = self.activeVideoInput.device;
    
    AVCaptureExposureMode exposureMode =
    AVCaptureExposureModeContinuousAutoExposure;
    
    AVCaptureFocusMode focusMode = AVCaptureFocusModeContinuousAutoFocus;
    
    BOOL canResetFocus = [device isFocusPointOfInterestSupported] &&
    [device isFocusModeSupported:focusMode];
    
    BOOL canResetExposure = [device isExposurePointOfInterestSupported] &&
    [device isExposureModeSupported:exposureMode];
    
    CGPoint centerPoint = CGPointMake(0.5f, 0.5f);
    
    NSError *error;
    if ([device lockForConfiguration:&error]) {
        
        if (canResetFocus) {
            device.focusMode = focusMode;
            device.focusPointOfInterest = centerPoint;
        }
        
        if (canResetExposure) {
            device.exposureMode = exposureMode;
            device.exposurePointOfInterest = centerPoint;
        }
        
        [device unlockForConfiguration];
        
    }
}


- (void)rotateCamera
{
    if (self.frontFacingCameraPresent == NO)
        return;
    
    NSError *error;
    AVCaptureDeviceInput *newVideoInput;
    AVCaptureDevicePosition currentCameraPosition = [[_activeVideoInput device] position];
    
    if (currentCameraPosition == AVCaptureDevicePositionBack)
    {
        currentCameraPosition = AVCaptureDevicePositionFront;
    }
    else
    {
        currentCameraPosition = AVCaptureDevicePositionBack;
    }
    
    AVCaptureDevice *backFacingCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == currentCameraPosition)
        {
            backFacingCamera = device;
        }
    }
    newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:backFacingCamera error:&error];
    
    if (newVideoInput != nil)
    {
        [_captureSession beginConfiguration];
        
        [_captureSession removeInput:_activeVideoInput];
        if ([_captureSession canAddInput:newVideoInput])
        {
            [_captureSession addInput:newVideoInput];
            _activeVideoInput = newVideoInput;
        }
        else
        {
            [_captureSession addInput:_activeVideoInput];
        }
        //captureSession.sessionPreset = oriPreset;
        [_captureSession commitConfiguration];
    }
    
}


@end

