//
//  MKGPUImageContext.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <OpenGLES/EAGLDrawable.h>
#import <AVFoundation/AVFoundation.h>

@class MKGLProgram;
@class MKGPUImageFramebuffer;

#import "MKGPUImageFramebufferCache.h"
#import "MKGPUImageConstants.h"

NS_ASSUME_NONNULL_BEGIN

@class MKGPUImageContext;
void runMSynchronouslyOnContextQueue(MKGPUImageContext *context, void (^block)(void));

@interface MKGPUImageContext : NSObject

@property(readonly, nonatomic) dispatch_queue_t contextQueue;
@property(readonly, nonatomic) void *contextKey;

@property(readonly, retain, nonatomic) EAGLContext *context;

@property(readonly) CVOpenGLESTextureCacheRef coreVideoTextureCache;
@property(readonly, retain, nonatomic) MKGPUImageFramebufferCache *framebufferCache;

- (instancetype)initWithNewGLContext;

- (instancetype)initWithCurrentGLContext;

- (void)useAsCurrentContext;

- (void)presentBufferForDisplay;

- (MKGLProgram *)programForVertexShaderString:(NSString *)vertexShaderString fragmentShaderString:(NSString *)fragmentShaderString;

- (CGSize)sizeThatFitsWithinATextureForSize:(CGSize)inputSize;

// Manage fast texture upload
+ (BOOL)supportsFastTextureUpload;

@end

@protocol MKGPUImageInput <NSObject>

- (void)setInputSize:(CGSize)newSize;
- (void)setInputFramebuffer:(MKGPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;

- (void)newFrameReadyIndex:(NSInteger)textureIndex;

@end

NS_ASSUME_NONNULL_END
