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
@property (strong, nonatomic, readonly) dispatch_queue_t dispatchQueue;

- (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition;

// Session Configuration
- (BOOL)setupSession:(NSError **)error;

- (void)startSession;
- (void)stopSession;

@end

NS_ASSUME_NONNULL_END

