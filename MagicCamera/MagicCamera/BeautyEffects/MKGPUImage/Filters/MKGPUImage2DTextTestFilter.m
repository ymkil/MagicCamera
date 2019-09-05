//
//  MKGPUImage2DTextTestFilter.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImage2DTextTestFilter.h"
#import "MKHeader.h"

#import "MKLandmarkManager.h"

#import <GLKit/GLKit.h>

NSString *const kMKGPUImage2DTextTestVertexShaderString = SHADER_STRING
(
 attribute vec4 vPosition;
 attribute vec2 in_texture;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = vPosition;
     textureCoordinate = in_texture;
 }
 );

NSString *const kMKGPUImage2DTextTestFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );



@interface MKGPUImage2DTextTestFilter()
{
    MKGLProgram *_2DTextProgram;
    
    GLint _positionAttribute;
    GLint _inTextureAttribute;
    GLint _inputTextureUniform;
    
    GLKTextureInfo* _textureInfo;
}

@end


@implementation MKGPUImage2DTextTestFilter

- (id)initWithContext:(MKGPUImageContext *)context vertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString {
    if (!(self = [super initWithContext:context vertexShaderFromString:vertexShaderString fragmentShaderFromString:fragmentShaderString])) {
        return nil;
    }
    
    
    
    _2DTextProgram = [self.context programForVertexShaderString:kMKGPUImage2DTextTestVertexShaderString fragmentShaderString:kMKGPUImage2DTextTestFragmentShaderString];
    
    if (![_2DTextProgram link])
    {
        NSString *progLog = [_2DTextProgram programLog];
        NSLog(@"Program link log: %@", progLog);
        NSString *fragLog = [_2DTextProgram fragmentShaderLog];
        NSLog(@"Fragment shader compile log: %@", fragLog);
        NSString *vertLog = [_2DTextProgram vertexShaderLog];
        NSLog(@"Vertex shader compile log: %@", vertLog);
        _2DTextProgram = nil;
        NSAssert(NO, @"Filter shader link failed");
    }
    
    _positionAttribute = [_2DTextProgram attributeIndex:@"vPosition"];
    _inTextureAttribute = [_2DTextProgram attributeIndex:@"in_texture"];
    _inputTextureUniform = [_2DTextProgram uniformIndex:@"inputImageTexture"];
    
    //纹理贴图
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"F_tsh_008" ofType:@"png"];
    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:@(1), GLKTextureLoaderOriginBottomLeft, nil];//GLKTextureLoaderOriginBottomLeft 纹理坐标系是相反的
    _textureInfo = [GLKTextureLoader textureWithContentsOfFile:filePath options:options error:nil];
    
    return self;
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;{
    
    [self.context useAsCurrentContext];
    
    [filterProgram use];
    outputFramebuffer = [[self.context framebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions missCVPixelBuffer:YES];
    [outputFramebuffer activateFramebuffer];
    
//    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    
    glUniform1i(filterInputTextureUniform, 2);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    if(MKLandmarkManager.shareManager.faceData) {
        [self drawFaceLandMark:MKLandmarkManager.shareManager.faceData];
    }
    
    [firstInputFramebuffer unlock];
}

- (void)drawFaceLandMark:(NSArray *)faceArray {
    if (!faceArray || faceArray.count == 0) return;
    
    glEnable(GL_BLEND);
//    glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    MKFaceInfo *faceInfo = faceArray.firstObject;
    [outputFramebuffer activateFramebuffer];
    
    [_2DTextProgram use];
    
    GLfloat tempPoint[8];
    
    CGPoint pointer = [faceInfo.points[43] CGPointValue];
    CGPoint pointer1 = [faceInfo.points[1] CGPointValue];
    CGPoint pointer31 = [faceInfo.points[31] CGPointValue];
    
    CGFloat faceWidth = fabs(pointer31.x - pointer1.x);
    
    CGFloat faceHeight = faceWidth * (102.0/292.0);
    
    tempPoint[0] = pointer.x - faceWidth/2;
    tempPoint[1] = pointer.y - faceHeight/2;
    
    tempPoint[2] = pointer.x + faceWidth/2;
    tempPoint[3] = pointer.y - faceHeight/2;
    
    tempPoint[4] = pointer.x - faceWidth/2;
    tempPoint[5] = pointer.y + faceHeight/2;
    
    tempPoint[6] = pointer.x + faceWidth/2;
    tempPoint[7] = pointer.y + faceHeight/2;
    
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
        
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, _textureInfo.name);
    
    glUniform1i(_inputTextureUniform, 3);
    
    glVertexAttribPointer(_positionAttribute, 2, GL_FLOAT, 0, 0, tempPoint);
    glEnableVertexAttribArray(_positionAttribute);
    glVertexAttribPointer(_inTextureAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    glEnableVertexAttribArray(_inTextureAttribute);
    
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisable(GL_BLEND);
}


-(GLuint)createTexture2DImage:(UIImage *)image
{
    
    GLuint texture;
    
    CGImageRef spriteImage = [image CGImage];
    
    CGFloat widthOfImage = CGImageGetWidth(spriteImage);
    CGFloat heightOfImage = CGImageGetHeight(spriteImage);
    
    GLubyte *imageData = (GLubyte *) calloc(1, (int)widthOfImage * (int)heightOfImage * 4);;
    
    CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef imageContext = CGBitmapContextCreate(imageData, (size_t)widthOfImage, (size_t)heightOfImage, 8, (size_t)widthOfImage * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGContextDrawImage(imageContext, CGRectMake(0.0, 0.0, widthOfImage, heightOfImage), spriteImage);
    
    CGContextRelease(imageContext);
    CGColorSpaceRelease(genericRGBColorspace);
    
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, widthOfImage, heightOfImage, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    free(imageData);
    
    return texture;
}


@end

