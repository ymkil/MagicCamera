//
//  MKGPUImageKeyPointFilter.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageKeyPointFilter.h"
#import "MKHeader.h"

#import "MKLandmarkManager.h"

NSString *const kMKGPUImageKeyPointVertexShaderString = SHADER_STRING
(
 attribute vec4 vPosition;
 uniform float sizeScale;
 
 void main()
 {
     gl_Position = vPosition;
     gl_PointSize = 5.0 * sizeScale;
 }
 );

NSString *const kMKGPUImageKeyPointFragmentShaderString = SHADER_STRING
(
 precision mediump float;
 
 void main()
 {
     gl_FragColor = vec4(0.2, 0.709803922, 0.898039216, 1.0);
 }
 );



@interface MKGPUImageKeyPointFilter()
{
    MKGLProgram *_keyPointProgram;
    
    GLint _keyPointPositionAttribute;
    GLint _colorSelectorSlot;
}

@end


@implementation MKGPUImageKeyPointFilter

- (id)initWithContext:(MKGPUImageContext *)context vertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString {
    if (!(self = [super initWithContext:context vertexShaderFromString:vertexShaderString fragmentShaderFromString:fragmentShaderString])) {
        return nil;
    }
    
    _keyPointProgram = [self.context programForVertexShaderString:kMKGPUImageKeyPointVertexShaderString fragmentShaderString:kMKGPUImageKeyPointFragmentShaderString];

    if (![_keyPointProgram link])
    {
        NSString *progLog = [_keyPointProgram programLog];
        NSLog(@"Program link log: %@", progLog);
        NSString *fragLog = [_keyPointProgram fragmentShaderLog];
        NSLog(@"Fragment shader compile log: %@", fragLog);
        NSString *vertLog = [_keyPointProgram vertexShaderLog];
        NSLog(@"Vertex shader compile log: %@", vertLog);
        _keyPointProgram = nil;
        NSAssert(NO, @"Filter shader link failed");
    }
    
    _keyPointPositionAttribute = [_keyPointProgram attributeIndex:@"vPosition"];
    _colorSelectorSlot = [_keyPointProgram uniformIndex:@"sizeScale"];
    
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
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    if(MKLandmarkManager.shareManager.faceData) {
        [self drawFaceLandMark:MKLandmarkManager.shareManager.faceData];
    }
    
    [firstInputFramebuffer unlock];
}

- (void)drawFaceLandMark:(NSArray *)faceArray {
    if (!faceArray || faceArray.count == 0) return;
    
    glEnable(GL_BLEND);
    glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
    
    MKFaceInfo *faceInfo = faceArray.firstObject;
    [outputFramebuffer activateFramebuffer];
    [_keyPointProgram use];
    [self drawFacePointer:faceInfo.points faceRect:faceInfo.rect];
    
    glDisable(GL_BLEND);
}


- (void)drawFacePointer:(NSArray *)pointArray faceRect:(CGRect)rect{
    
    const GLfloat lineWidth = rect.size.width/kScreenW * 1.8;
    
    glUniform1f(_colorSelectorSlot, 0.8);
    
    const GLsizei pointCount = (GLsizei)pointArray.count;
    GLfloat tempPoint[pointCount * 3];
    GLubyte indices[pointCount];
    
    
    for (int i = 0; i < pointArray.count; i ++) {
        CGPoint pointer = [pointArray[i] CGPointValue];
       
        tempPoint[i*3+0]=pointer.x;
        tempPoint[i*3+1]=pointer.y;
        tempPoint[i*3+2]=0.0f;
        
        indices[i]=i;
    }
    
    glVertexAttribPointer( 0, 3, GL_FLOAT, GL_TRUE, 0, tempPoint );
    glEnableVertexAttribArray(_keyPointPositionAttribute);
    glDrawElements(GL_POINTS, (GLsizei)sizeof(indices)/sizeof(GLubyte), GL_UNSIGNED_BYTE, indices);
}


@end
