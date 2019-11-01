//
//  MKGPUImageTwoInputFilter.h
//  MagicCamera
//
//  Created by mkil on 2019/10/26.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImageTwoInputFilter : MKGPUImageFilter
{
    MKGPUImageFramebuffer *secondInputFramebuffer;
    
    GLint filterSecondTextureCoordinateAttribute;
    GLint filterInputTextureUniform2;
    MKGPUImageRotationMode inputRotation2;
    
    BOOL hasReceivedFirstFrame, hasReceivedSecondFrame;
    
}
@end

NS_ASSUME_NONNULL_END
