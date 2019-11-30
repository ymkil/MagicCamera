//
//  MKGPUImageFilter.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageFilter.h"

// Hardcode the vertex shader for standard filters, but this can be overridden
NSString *const kMKGPUImageVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

NSString *const kMKGPUImagePassthroughFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );

@implementation MKGPUImageFilter

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithContext:(MKGPUImageContext *)context vertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString;
{
    if (!(self = [super initWithContext:context]))
    {
        return nil;
    }
    
    self.context = context;
    
    runMSynchronouslyOnContextQueue(self.context, ^{
        [self.context useAsCurrentContext];
        
        filterProgram = [self.context programForVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];
        
        if (!filterProgram.initialized)
        {
            if (![filterProgram link])
            {
                NSString *progLog = [filterProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [filterProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [filterProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                filterProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        filterPositionAttribute = [filterProgram attributeIndex:@"position"];
        filterTextureCoordinateAttribute = [filterProgram attributeIndex:@"inputTextureCoordinate"];
        filterInputTextureUniform = [filterProgram uniformIndex:@"inputImageTexture"]; // This does assume a name of "inputImageTexture" for the fragment shader
        
        [filterProgram use];
        
        glEnableVertexAttribArray(filterPositionAttribute);
        glEnableVertexAttribArray(filterTextureCoordinateAttribute);
    });
    
    return self;
}

- (id)initWithContext:(MKGPUImageContext *)context fragmentShaderFromString:(NSString *)fragmentShaderString;
{
    if (!(self = [self initWithContext:context vertexShaderFromString:kMKGPUImageVertexShaderString fragmentShaderFromString:fragmentShaderString]))
    {
        return nil;
    }
    
    return self;
}

- (id)initWithContext:(MKGPUImageContext *)context;
{
    if (!(self = [self initWithContext:context fragmentShaderFromString:kMKGPUImagePassthroughFragmentShaderString]))
    {
        return nil;
    }
    
    return self;
}

- (void)dealloc
{
    
}

#pragma mark -
#pragma mark Managing the display FBOs

- (CGSize)sizeOfFBO;
{
    return inputTextureSize;
}

#pragma mark -
#pragma mark Rendering

+ (const GLfloat *)textureCoordinatesForRotation:(MKGPUImageRotationMode)rotationMode;
{
    static const GLfloat noRotationTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat rotateLeftTextureCoordinates[] = {
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat rotateRightTextureCoordinates[] = {
        0.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat verticalFlipTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f,  0.0f,
        1.0f,  0.0f,
    };
    
    static const GLfloat horizontalFlipTextureCoordinates[] = {
        1.0f, 0.0f,
        0.0f, 0.0f,
        1.0f,  1.0f,
        0.0f,  1.0f,
    };
    
    static const GLfloat rotateRightVerticalFlipTextureCoordinates[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat rotateRightHorizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotate180TextureCoordinates[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    switch(rotationMode)
    {
        case kMKGPUImageNoRotation: return noRotationTextureCoordinates;
        case kMKGPUImageRotateLeft: return rotateLeftTextureCoordinates;
        case kMKGPUImageRotateRight: return rotateRightTextureCoordinates;
        case kMKGPUImageFlipVertical: return verticalFlipTextureCoordinates;
        case kMKGPUImageFlipHorizonal: return horizontalFlipTextureCoordinates;
        case kMKGPUImageRotateRightFlipVertical: return rotateRightVerticalFlipTextureCoordinates;
        case kMKGPUImageRotateRightFlipHorizontal: return rotateRightHorizontalFlipTextureCoordinates;
        case kMKGPUImageRotate180: return rotate180TextureCoordinates;
    }
}

+ (BOOL)needExchangeWidthAndHeightWithRotation:(MKGPUImageRotationMode)rotationMode {
    switch(rotationMode)
    {
        case kMKGPUImageNoRotation: return NO;
        case kMKGPUImageRotateLeft: return YES;
        case kMKGPUImageRotateRight: return YES;
        case kMKGPUImageFlipVertical: return NO;
        case kMKGPUImageFlipHorizonal: return NO;
        case kMKGPUImageRotateRightFlipVertical: return YES;
        case kMKGPUImageRotateRightFlipHorizontal: return YES;
        case kMKGPUImageRotate180: return NO;
    }
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;
{
    [self.context useAsCurrentContext];
    [filterProgram use];
    
    outputFramebuffer = [[self.context framebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions missCVPixelBuffer:NO];
    [outputFramebuffer activateFramebuffer];
    
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    
    glUniform1i(filterInputTextureUniform, 2);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [firstInputFramebuffer unlock];
}

- (void)informTargetsAboutNewFrame;
{
    // Get all targets the framebuffer so they can grab a lock on it
    for (id<MKGPUImageInput> currentTarget in targets)
    {
        [currentTarget setInputSize:[self outputFrameSize]];
        NSInteger indexOfObject = [targets indexOfObject:currentTarget];
        [currentTarget setInputFramebuffer:[self framebufferForOutput] atIndex:indexOfObject];
    }
    
    // Release our hold so it can return to the cache immediately upon processing
    [[self framebufferForOutput] unlock];
    
    [self removeOutputFramebuffer];
    
    // Trigger processing last, so that our unlock comes first in serial execution, avoiding the need for a callback
    for (id<MKGPUImageInput> currentTarget in targets)
    {
        NSInteger indexOfObject = [targets indexOfObject:currentTarget];
        [currentTarget newFrameReadyIndex:indexOfObject];
    }
}

- (CGSize)outputFrameSize;
{
    return inputTextureSize;
}

#pragma mark -
#pragma mark MKGPUImageInput

- (void)setInputSize:(CGSize)newSize;
{
    inputTextureSize = newSize;
}

- (void)setInputFramebuffer:(MKGPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    firstInputFramebuffer = newInputFramebuffer;
    [firstInputFramebuffer lock];
}

- (void)newFrameReadyIndex:(NSInteger)textureIndex;
{
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    [self renderToTextureWithVertices:imageVertices textureCoordinates:textureCoordinates];
    
    [self informTargetsAboutNewFrame];
}

@end
