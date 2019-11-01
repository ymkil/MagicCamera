//
//  MKGPUImagePicture.h
//  MagicCamera
//
//  Created by mkil on 2019/9/6.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageOutput.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImagePicture : MKGPUImageOutput
{
    CGSize pixelSizeOfImage;
    BOOL hasProcessedImage;
    
    dispatch_semaphore_t imageUpdateSemaphore;
}

- (id)initWithContext:(MKGPUImageContext *)context withImage:(UIImage *)newImageSource;

// Image rendering
- (void)processImage;
- (CGSize)outputImageSize;

@end

NS_ASSUME_NONNULL_END
