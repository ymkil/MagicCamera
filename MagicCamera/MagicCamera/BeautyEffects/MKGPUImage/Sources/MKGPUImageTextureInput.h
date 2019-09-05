//
//  MKGPUImageTextureInput.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageOutput.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImageTextureInput : MKGPUImageOutput

@property (nonatomic, assign) MKGPUImageRotationMode rotateMode;


/**
 处理纹理
 
 @param texture 纹理数据
 */
- (void)processWithBGRATexture:(GLint)texture width:(int)width height:(int)height;

@end

NS_ASSUME_NONNULL_END
