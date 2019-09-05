//
//  MKGPUImageFramebufferCache.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#import "MKGPUImageConstants.h"

@class MKGPUImageFramebuffer;
@class MKGPUImageContext;

NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImageFramebufferCache : NSObject

// Framebuffer management
- (id)initWithContext:(MKGPUImageContext *)context;

- (MKGPUImageFramebuffer *)fetchFramebufferForSize:(CGSize)framebufferSize textureOptions:(MKGPUTextureOptions)textureOptions missCVPixelBuffer:(BOOL)missCVPixelBuffer;

- (MKGPUImageFramebuffer *)fetchFramebufferForSize:(CGSize)framebufferSize missCVPixelBuffer:(BOOL)missCVPixelBuffer;

- (void)returnFramebufferToCache:(MKGPUImageFramebuffer *)framebuffer;

@end

NS_ASSUME_NONNULL_END
