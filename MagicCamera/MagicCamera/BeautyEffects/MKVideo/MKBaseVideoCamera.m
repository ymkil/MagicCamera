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
    _dispatchQueue = dispatch_queue_create("com.CaptureDispatchQueue", NULL);
    
    return self;
}


- (BOOL)setupSession:(NSError * _Nullable __autoreleasing *)error {
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = self.sessionPreset;
    
    if (![self setupSessionInputs:error]) {
        return NO;
    }
    
    if (![self setupSessionOutputs:error]) {
        return NO;
    }
    
    return YES;
}

- (BOOL)setupSessionInputs:(NSError **)error {
    
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
    
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:error];
    if (videoInput) {
        if ([self.captureSession canAddInput:videoInput]) {
            [self.captureSession addInput:videoInput];
            self.activeVideoInput = videoInput;
        } else {
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Failed to add video input."};
            *error = [NSError errorWithDomain:@"----"
                                         code:1000
                                     userInfo:userInfo];
            return NO;
        }
    } else {
        return NO;
    }
    
    // Setup default microphone
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput =
    [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:error];
    if (audioInput) {
        if ([self.captureSession canAddInput:audioInput]) {
            [self.captureSession addInput:audioInput];
        } else {
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Failed to add audio input."};
            *error = [NSError errorWithDomain:@"----"
                                         code:1000
                                     userInfo:userInfo];
            return NO;
        }
    } else {
        return NO;
    }
    
    return YES;
}

- (BOOL)setupSessionOutputs:(NSError **)error {
    return YES;
}

- (void)startSession {
    dispatch_async(self.dispatchQueue, ^{
        if (![self.captureSession isRunning]) {
            [self.captureSession startRunning];
        }
    });
}

- (void)stopSession {
    dispatch_async(self.dispatchQueue, ^{
        if ([self.captureSession isRunning]) {
            [self.captureSession stopRunning];
        }
    });
}

#pragma mark - Device Configuration



@end

