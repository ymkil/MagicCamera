//
//  MKGPUImageTextureOutput.h
//  MKBeautyEffectsDemo
//
//  Created by mkil on 2019/8/19.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MKGPUImageFilter.h"
#import "MKGPUImageContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImageTextureOutput : NSObject<MKGPUImageInput>

@property (nonatomic, assign) MKGPUImageRotationMode rotateMode;

- (instancetype)initWithContext:(MKGPUImageContext *)context;

/**
 设置输出BGRA纹理
 
 @param texture BGRA纹理
 */
- (void)setOutputWithBGRATexture:(GLint)texture width:(int)width height:(int)height;

@end

NS_ASSUME_NONNULL_END
