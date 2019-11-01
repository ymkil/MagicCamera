//
//  MKGPUImageTwoInputFilter.m
//  MagicCamera
//
//  Created by mkil on 2019/10/26.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageTwoInputFilter.h"

NSString *const kMKGPUImageTwoInputTextureVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 attribute vec4 inputTextureCoordinate2;
 
 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
     textureCoordinate2 = inputTextureCoordinate2.xy;
 }
 );

@implementation MKGPUImageTwoInputFilter

#pragma mark -
#pragma mark Initialization and teardown


- (id)initWithContext:(MKGPUImageContext *)context fragmentShaderFromString:(NSString *)fragmentShaderString;
{
    return [self initWithContext:context vertexShaderFromString:kMKGPUImageTwoInputTextureVertexShaderString fragmentShaderFromString:fragmentShaderString];
}

    
- (id)initWithContext:(MKGPUImageContext *)context vertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString;
{
    if (!(self = [super initWithContext:context vertexShaderFromString:vertexShaderString fragmentShaderFromString:fragmentShaderString]))
    {
        return nil;
    }
    
    inputRotation2 = kMKGPUImageNoRotation;
    
    hasReceivedFirstFrame = NO;
    hasReceivedSecondFrame = NO;
    
    runMSynchronouslyOnContextQueue(self.context, ^{
        [self.context useAsCurrentContext];
        
        filterSecondTextureCoordinateAttribute = [filterProgram attributeIndex:@"inputTextureCoordinate2"];
        
        filterInputTextureUniform2 = [filterProgram uniformIndex:@"inputImageTexture2"]; // This does assume a name of "inputImageTexture2" for second input texture in the fragment shader
        glEnableVertexAttribArray(filterSecondTextureCoordinateAttribute);
        
    });
    
    return self;
}

#pragma mark -
#pragma mark Rendering

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
    
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, [secondInputFramebuffer texture]);
    glUniform1i(filterInputTextureUniform2, 3);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    glVertexAttribPointer(filterSecondTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [[self class] textureCoordinatesForRotation:inputRotation2]);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [firstInputFramebuffer unlock];
    [secondInputFramebuffer unlock];
}

#pragma mark -
#pragma mark GPUImageInput

- (void)setInputFramebuffer:(MKGPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    if (textureIndex == 0)
    {
        firstInputFramebuffer = newInputFramebuffer;
        [firstInputFramebuffer lock];
    }
    else
    {
        secondInputFramebuffer = newInputFramebuffer;
        [secondInputFramebuffer lock];
    }
}

- (void)newFrameReadyIndex:(NSInteger)textureIndex;
{
    if (textureIndex == 0)
    {
        hasReceivedFirstFrame = YES;
    }
    else
    {
        hasReceivedSecondFrame = YES;
    }
    
    if (hasReceivedFirstFrame && hasReceivedSecondFrame)
    {
        [super newFrameReadyIndex:0];
        hasReceivedFirstFrame = NO;
        hasReceivedSecondFrame = NO;
    }
}

@end
