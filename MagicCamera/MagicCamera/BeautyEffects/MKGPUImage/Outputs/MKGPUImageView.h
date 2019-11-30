//
//  MKGPUImageView.h
//  MagicCamera
//
//  Created by mkil on 2019/11/19.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MKGPUImageContext.h"

typedef NS_ENUM(NSUInteger, MKGPUImageFillModeType) {
    kMKGPUImageFillModeStretch,                       // Stretch to fill the full view, which may distort the image outside of its normal aspect ratio
    kMKGPUImageFillModePreserveAspectRatio,           // Maintains the aspect ratio of the source image, adding bars of the specified background color
    kMKGPUImageFillModePreserveAspectRatioAndFill     // Maintains the aspect ratio of the source image, zooming in on its center to fill the view
};

NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImageView : UIView <MKGPUImageInput>
{
    MKGPUImageRotationMode inputRotation;
}

/** The fill mode dictates how images are fit in the view, with the default being kGPUImageFillModePreserveAspectRatio
 */
@property(readwrite, nonatomic) MKGPUImageFillModeType fillMode;

@property(readonly, nonatomic) CGSize sizeInPixels;

- (void)setContext:(MKGPUImageContext *)context;

- (void)renderTexture:(GLuint) inputTextureId inputSize:(CGSize)newSize rotateMode:(MKGPUImageRotationMode)rotation;

@end

NS_ASSUME_NONNULL_END
