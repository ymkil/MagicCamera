//
//  MKGPUImageGaussianBlurFilter.m
//  MagicCamera
//
//  Created by mkil on 2019/11/14.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageGaussianBlurFilter.h"

NSString *const kMKGPUImageGaussianBlurVertexShaderString = SHADER_STRING
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

NSString *const kMKGPUImageGaussianBlurFragmentShaderString = SHADER_STRING
(
#ifdef GL_FRAGMENT_PRECISION_HIGH
 precision highp float;
#else
 precision mediump float;
#endif
 
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform float imageWidth;
 uniform float imageHeight;
 
 void main()
 {
     // 3*3的高斯Kernel
     vec2 sOff = vec2(1.0/imageWidth, 1.0/imageHeight);
     
     lowp vec3 sum = vec3(0.0);
     lowp vec4 fragColor=texture2D(inputImageTexture,textureCoordinate);
     
     sum += 0.25*texture2D(inputImageTexture, textureCoordinate + sOff * vec2(0.5,0.5)).rgb;
     sum += 0.25*texture2D(inputImageTexture, textureCoordinate + sOff * vec2(-0.5,0.5)).rgb;
     sum += 0.25*texture2D(inputImageTexture, textureCoordinate + sOff * vec2(0.5,-0.5)).rgb;
     sum += 0.25*texture2D(inputImageTexture, textureCoordinate + sOff * vec2(-0.5,-0.5)).rgb;
     
     gl_FragColor = vec4(sum, fragColor.a);
 }
 );

@interface MKGPUImageGaussianBlurFilter()
{
    GLint _imageWidthSlot;
    GLint _imageHeightSlot;
}

@end


@implementation MKGPUImageGaussianBlurFilter

- (id)initWithContext:(MKGPUImageContext *)context vertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString {
    
    if (!(self = [super initWithContext:context vertexShaderFromString:kMKGPUImageGaussianBlurVertexShaderString fragmentShaderFromString:kMKGPUImageGaussianBlurFragmentShaderString])) {
        return nil;
    }
    
    _imageWidthSlot = [filterProgram uniformIndex:@"imageWidth"];
    _imageHeightSlot = [filterProgram uniformIndex:@"imageHeight"];
    
    return self;
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;{
    
    [self.context useAsCurrentContext];
    
    [filterProgram use];
    outputFramebuffer = [[self.context framebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions missCVPixelBuffer:YES];
    [outputFramebuffer activateFramebuffer];
    
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    
    glUniform1i(filterInputTextureUniform, 2);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glUniform1f(_imageWidthSlot, [self sizeOfFBO].width);
    glUniform1f(_imageHeightSlot, [self sizeOfFBO].height);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [firstInputFramebuffer unlock];
}

@end
