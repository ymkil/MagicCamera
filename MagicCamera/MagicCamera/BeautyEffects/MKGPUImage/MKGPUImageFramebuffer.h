//
//  MKGPUImageFramebuffer.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>

#import "MKGPUImageConstants.h"

@class MKGPUImageContext;
NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImageFramebuffer : NSObject

@property(readonly) CGSize size;
@property(readonly) MKGPUTextureOptions textureOptions;
@property(readonly) GLuint texture;
@property(readonly) BOOL missCVPixelBuffer;
@property(readonly) NSUInteger framebufferReferenceCount;
@property(nonatomic, weak) MKGPUImageContext *context;

// Initialization and teardown

- (id)initWithContext:(MKGPUImageContext *)context size:(CGSize)framebufferSize textureOptions:(MKGPUTextureOptions)fboTextureOptions missCVPixelBuffer:(BOOL)missCVPixelBuffer;

// Usage
- (void)activateFramebuffer;

// Reference counting
- (void)lock;
- (void)unlock;
- (void)clearAllLocks;

//// Raw data bytes
- (NSUInteger)bytesPerRow;
- (GLubyte *)byteBuffer;
- (CVPixelBufferRef)pixelBuffer;
- (UIImage *)image;

@end

NS_ASSUME_NONNULL_END
