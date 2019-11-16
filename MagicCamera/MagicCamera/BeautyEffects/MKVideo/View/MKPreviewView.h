//
//  MKPreviewView.h
//  MagicCamera
//
//  Created by mkil on 2019/11/16.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MKPreviewView : UIView

- (void)setSession:(AVCaptureSession *)session;

@end

NS_ASSUME_NONNULL_END
