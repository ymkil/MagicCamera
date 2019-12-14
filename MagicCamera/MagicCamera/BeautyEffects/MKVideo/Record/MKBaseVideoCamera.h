//
//  MKBaseVideoCamera.h
//  MagicCamera
//
//  Created by mkil on 2019/11/16.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MKBaseVideoCamera : NSObject

@property (strong, nonatomic, readonly) AVCaptureSession *captureSession;
@property (strong, nonatomic, readonly) dispatch_queue_t cameraProcessingQueue;
@property (strong, nonatomic, readonly) dispatch_queue_t audioProcessingQueue;

- (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition;

// Session Configuration
- (BOOL)setupSession:(NSError **)error;

@property (readonly, getter = isFrontFacingCameraPresent) BOOL frontFacingCameraPresent;

/** Get the position (front, rear) of the source camera
 */
- (AVCaptureDevicePosition)cameraPosition;

// Camera Device Support
@property (nonatomic, readonly) BOOL isHasTorch;
@property (nonatomic, readonly) BOOL isHasFlash;
@property (nonatomic, readonly) BOOL isSupportsTapToFocus;
@property (nonatomic, readonly) BOOL isSupportsTapToExpose;
@property (nonatomic) AVCaptureTorchMode torchMode;
@property (nonatomic) AVCaptureFlashMode flashMode;

- (void)startSession;
- (void)stopSession;

- (BOOL)addAudioInputs;
- (BOOL)removeAudioInputs;

// Tap to * Methods
- (void)focusAtPoint:(CGPoint)point;
- (void)exposeAtPoint:(CGPoint)point;
- (void)resetFocusAndExposureModes;

/** This flips between the front and rear cameras
 */
- (void)rotateCamera;

@end

NS_ASSUME_NONNULL_END

