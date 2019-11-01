//
//  MKGPUImageBeautyMakeupFilter.m
//  MagicCamera
//
//  Created by mkil on 2019/10/24.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageBeautyMakeupFilter.h"
#import "MKHeader.h"

#import "MKLandmarkManager.h"
#import "MKFaceBaseData.h"

#import <GLKit/GLKit.h>


NSString *const kMKGPUImageBeautyMakeupFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 // 图像笛卡尔坐标系的关键点，也就是纹理坐标乘以宽高得到
 uniform highp vec2 cartesianPoints[106];
 
 // 纹理宽度
 uniform int textureWidth;
 // 纹理高度
 uniform int textureHeight;
 
 // 是否允许美型处理，存在人脸时为1，没有人脸时为0
 uniform int enableReshape;
 
 // 曲线形变处理
lowp vec2 curveWarp(lowp vec2 textureCoord, lowp vec2 originPosition, lowp vec2 targetPosition, lowp float radius)
{
    lowp vec2 offset = vec2(0.0);
    lowp vec2 result = vec2(0.0);
    
    lowp vec2 direction = targetPosition - originPosition;
    
    lowp float infect = distance(textureCoord, originPosition)/radius;
    
    infect = 1.0 - infect;
    infect = clamp(infect, 0.0, 1.0);
    offset = direction * infect;
    
    result = textureCoord - offset;
    
    return result;
}
 
 // 大眼处理
 lowp vec2 enlargeEye(lowp vec2 currentCoordinate, lowp vec2 circleCenter, lowp float radius, lowp float intensity)
{
    lowp float currentDistance = distance(currentCoordinate, circleCenter);
    lowp float weight = currentDistance / radius;
    weight = 1.0 - intensity * (1.0 - weight * weight);
    weight = clamp(weight, 0.0, 1.0);
    currentCoordinate = circleCenter + (currentCoordinate - circleCenter) * weight;
    
    return currentCoordinate;
}
 // 瘦脸
 lowp vec2 faceLift(lowp vec2 currentCoordinate, lowp float faceLength)
 {
     lowp vec2 coordinate = currentCoordinate;
     lowp vec2 currentPoint = vec2(0.0);
     lowp vec2 destPoint = vec2(0.0);
     
     lowp float faceLiftScale = 0.8 * 0.1;
     lowp float radius = faceLength;
     
     currentPoint = cartesianPoints[3];
     destPoint = currentPoint + (cartesianPoints[44] - currentPoint) * faceLiftScale;
     coordinate = curveWarp(coordinate, currentPoint, destPoint, radius);
     
     currentPoint = cartesianPoints[29];
     destPoint = currentPoint + (cartesianPoints[44] - currentPoint) * faceLiftScale;
     coordinate = curveWarp(coordinate, currentPoint, destPoint, radius);
     
     radius = faceLength * 0.8;
     currentPoint = cartesianPoints[10];
     destPoint = currentPoint + (cartesianPoints[46] - currentPoint) * (faceLiftScale * 0.6);
     coordinate = curveWarp(coordinate, currentPoint, destPoint, radius);
     
     currentPoint = cartesianPoints[22];
     destPoint = currentPoint + (cartesianPoints[46] - currentPoint) * (faceLiftScale * 0.6);
     coordinate = curveWarp(coordinate, currentPoint, destPoint, radius);
     
     return coordinate;
 }
 
 // 削脸
 lowp vec2 faceShave(lowp vec2 currentCoordinate, lowp float faceLength)
{
    lowp vec2 coordinate = currentCoordinate;
    lowp vec2 currentPoint = vec2(0.0);
    lowp vec2 destPoint = vec2(0.0);
    lowp float faceShaveScale = 0.8 * 0.25;
    lowp float radius = faceLength * 1.0;
    
    // 下巴中心
    lowp vec2 chinCenter = (cartesianPoints[16] + cartesianPoints[93]) * 0.5;
    currentPoint = cartesianPoints[13];
    destPoint = currentPoint + (chinCenter - currentPoint) * faceShaveScale;
    coordinate = curveWarp(coordinate, currentPoint, destPoint, radius);
    
    currentPoint = cartesianPoints[19];
    destPoint = currentPoint + (chinCenter - currentPoint) * faceShaveScale;
    coordinate = curveWarp(coordinate, currentPoint, destPoint, radius);
    
    return coordinate;
}

 // 处理下巴
 lowp vec2 chinChange(lowp vec2 currentCoordinate, lowp float faceLength)
{
    lowp vec2 coordinate = currentCoordinate;
    lowp vec2 currentPoint = vec2(0.0);
    lowp vec2 destPoint = vec2(0.0);
    lowp float chinScale = 0.8 * 0.08;
    lowp float radius = faceLength * 1.25;
    currentPoint = cartesianPoints[16];
    destPoint = currentPoint + (cartesianPoints[46] - currentPoint) * chinScale;
    coordinate = curveWarp(coordinate, currentPoint, destPoint, radius);
    
    return coordinate;
}

 
 void main()
 {
     lowp vec2 coordinate = textureCoordinate.xy;
     if (enableReshape == 0 || (cartesianPoints[46].x / float(textureWidth) <= 0.03) || (cartesianPoints[46].y / float(textureHeight) <= 0.03)) {
        gl_FragColor = texture2D(inputImageTexture, coordinate);
     } else {
         
         // 将坐标转成图像大小，这里是为了方便计算
         coordinate = textureCoordinate * vec2(float(textureWidth),float(textureHeight));
         
         // 两个瞳孔的距离
         lowp float eyeDistance = distance(cartesianPoints[74], cartesianPoints[77]);
         
         // 瘦脸
         coordinate = faceLift(coordinate, eyeDistance);
         
         // 削脸
         coordinate = faceShave(coordinate, eyeDistance);
         
         // 下巴
         coordinate = chinChange(coordinate, eyeDistance);
         
         
         // 大眼
         lowp float eyeEnlarge = 0.8 * 0.25; // 放大倍数
         if (eyeEnlarge > 0.0) {
             lowp float radius = eyeDistance * 0.33; // 眼睛放大半径
             coordinate = enlargeEye(coordinate, cartesianPoints[74] + (cartesianPoints[77] - cartesianPoints[74]) * 0.05, radius, eyeEnlarge);
             coordinate = enlargeEye(coordinate, cartesianPoints[77] + (cartesianPoints[74] - cartesianPoints[77]) * 0.05, radius, eyeEnlarge);
         }
         
         // 转变回原来的纹理坐标系
         coordinate = coordinate / vec2(float(textureWidth), float(textureHeight));
         gl_FragColor = texture2D(inputImageTexture, coordinate);
     }
 }
 );

@interface MKGPUImageBeautyMakeupFilter()
{
    GLint _cartesianPointsSlot;
    GLint _textureWidthSlot;
    GLint _textureHeighSlot;
    GLint _enableReshapeSlot;
    
    // 顶点坐标
    float vertexPoints[122 * 2];
    // 纹理坐标
    float texturePoints[122 * 2];
    
    // 笛卡尔坐标系
    float cartesianVertices[106 * 2];
}

@end


@implementation MKGPUImageBeautyMakeupFilter


- (id)initWithContext:(MKGPUImageContext *)context vertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString {
    
    if (!(self = [super initWithContext:context vertexShaderFromString:vertexShaderString fragmentShaderFromString:kMKGPUImageBeautyMakeupFragmentShaderString])) {
        return nil;
    }
    
    _cartesianPointsSlot = [filterProgram uniformIndex:@"cartesianPoints"];
    _textureWidthSlot = [filterProgram uniformIndex:@"textureWidth"];
    _textureHeighSlot = [filterProgram uniformIndex:@"textureHeight"];
    _enableReshapeSlot = [filterProgram uniformIndex:@"enableReshape"];
    
    return self;
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;{
    
    [self.context useAsCurrentContext];
    
    [filterProgram use];
    outputFramebuffer = [[self.context framebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions missCVPixelBuffer:YES];
    [outputFramebuffer activateFramebuffer];
    
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    if (MKLandmarkManager.shareManager.faceData && MKLandmarkManager.shareManager.faceData.count > 0) {
        
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
        
        int length = sizeof(vertexPoints)/sizeof(vertexPoints[0]);
        
        [MKLandmarkManager.shareManager generateFaceAdjustVertexPoints:vertexPoints withTexturePoints:texturePoints withLength:length withFaceIndex:0];
        
        glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertexPoints);
        glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, texturePoints);
        
        glUniform1i(_textureWidthSlot, [firstInputFramebuffer size].width);
        glUniform1i(_textureHeighSlot, [firstInputFramebuffer size].height);
        
        
        for (int i = 0; i < 106; i ++) {
            cartesianVertices[i * 2] = texturePoints[i * 2] * [firstInputFramebuffer size].width;
            cartesianVertices[i * 2 + 1] = texturePoints[i * 2 + 1] * [firstInputFramebuffer size].height;
        }
        
        glUniform2fv(_cartesianPointsSlot, 106, cartesianVertices);
        
        glUniform1i(_enableReshapeSlot, 1);
        
        glDrawElements(GL_TRIANGLES,sizeof(FaceImageIndices)/sizeof(FaceImageIndices[0]), GL_UNSIGNED_SHORT, FaceImageIndices);
    } else {
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
        
        glUniform1i(filterInputTextureUniform, 2);
        
        glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
        glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
        
        glUniform1i(_enableReshapeSlot, 0);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    [firstInputFramebuffer unlock];
}

@end
