//
//  MKGPUImageFilter.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "MKGPUImageOutput.h"
#import "MKGLProgram.h"
#import "MKGPUImageFramebuffer.h"
#import "MKGPUImageConstants.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kMKGPUImageVertexShaderString;
extern NSString *const kMKGPUImagePassthroughFragmentShaderString;

@interface MKGPUImageFilter : MKGPUImageOutput <MKGPUImageInput>
{
    
    MKGPUImageFramebuffer *firstInputFramebuffer;
    
    MKGLProgram *filterProgram;
    
    GLint filterPositionAttribute, filterTextureCoordinateAttribute;
    GLint filterInputTextureUniform;
}

@property(readonly) CVPixelBufferRef renderTarget;

- (id)initWithContext:(MKGPUImageContext *)context vertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString;

- (id)initWithContext:(MKGPUImageContext *)context fragmentShaderFromString:(NSString *)fragmentShaderString;

- (id)initWithContext:(MKGPUImageContext *)context;

- (CGSize)sizeOfFBO;

/// @name Rendering
+ (const GLfloat *)textureCoordinatesForRotation:(MKGPUImageRotationMode)rotationMode;

+ (BOOL)needExchangeWidthAndHeightWithRotation:(MKGPUImageRotationMode)rotationMode;

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;

- (void)informTargetsAboutNewFrame;

@end

NS_ASSUME_NONNULL_END
