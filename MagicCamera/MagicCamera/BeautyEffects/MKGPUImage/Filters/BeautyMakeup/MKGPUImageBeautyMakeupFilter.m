//
//  MKGPUImageBeautyMakeupFilter.m
//  MagicCamera
//
//  Created by mkil on 2019/11/6.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageBeautyMakeupFilter.h"
#import "MKHeader.h"

#import "MKGPUImagePicture.h"
#import "MKLandmarkManager.h"
#import "MKLandmarkEngine.h"
#import "MKFaceBaseData.h"


NSString *const kMKGPUImageBeautyMakeupVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 varying vec2 maskCoordinate;        // 遮罩纹理坐标
 void main()
 {
     gl_Position = position;
     // 原图纹理坐标，用顶点来计算
     textureCoordinate = position.xy * 0.5 + 0.5;
     // 遮罩纹理坐标，用传进来的坐标值计算
     maskCoordinate = inputTextureCoordinate.xy;
 }
 );

NSString *const kMKGPUImageBeautyMakeupFragmentShaderString = SHADER_STRING
(
#ifdef GL_FRAGMENT_PRECISION_HIGH
 precision highp float;
#else
 precision mediump float;
#endif
 
 varying highp vec2 textureCoordinate;
 
 varying highp vec2 maskCoordinate;        // 遮罩纹理坐标
 
 uniform sampler2D inputImageTexture; // 图像纹理, 原图、素材等
 
 uniform sampler2D materialTexture;  // 素材纹理, 对于唇彩来说，这里存放的是lut纹理
 
 uniform sampler2D maskTexture;      // 遮罩纹理, 唇彩或者眼睛的遮罩纹理
 
 uniform float strength;             // 彩妆强度
 
 void main()
 {
     vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     vec4 lipMaskColor = texture2D(materialTexture, maskCoordinate);
     
     if (lipMaskColor.r > 0.005) {
         vec2 quad1;
         vec2 quad2;
         vec2 texPos1;
         vec2 texPos2;
         
         float blueColor = textureColor.b * 15.0;
         
         quad1.y = floor(floor(blueColor) / 4.0);
         quad1.x = floor(blueColor) - (quad1.y * 4.0);
         
         quad2.y = floor(ceil(blueColor) / 4.0);
         quad2.x = ceil(blueColor) - (quad2.y * 4.0);
         
         texPos1.xy = (quad1.xy * 0.25) + 0.5/64.0 + ((0.25 - 1.0/64.0) * textureColor.rg);
         texPos2.xy = (quad2.xy * 0.25) + 0.5/64.0 + ((0.25 - 1.0/64.0) * textureColor.rg);
         
         lowp vec3 newColor1 = texture2D(materialTexture, texPos1).rgb;
         lowp vec3 newColor2 = texture2D(materialTexture, texPos2).rgb;
         
         lowp vec3 newColor = mix(newColor1, newColor2, fract(blueColor));
         
         textureColor = vec4(newColor, 1.0) * (lipMaskColor.r * strength);
     } else {
         textureColor = vec4(0.0, 0.0, 0.0, 0.0);
     }
     gl_FragColor = textureColor;
 }
 );

@interface MKGPUImageBeautyMakeupFilter()
{
    MKGLProgram *_program;
    
    GLint _positionAttribute;
    GLint _inTextureAttribute;

    GLuint _inputImageTextureSlot;
    GLuint _materialTextureSlot;
    GLuint _maskTextureSlot;
    
    GLuint _strengthSlot;
    
    // 顶点坐标
    float vertexPoints[20 * 2];
    
    GLuint maskTexture;
    GLuint lutTexture;
}

@property(nonatomic, strong) MKGPUImagePicture *maskPicture;
@property(nonatomic, strong) MKGPUImagePicture *lutPicture;

@end


@implementation MKGPUImageBeautyMakeupFilter

- (id)initWithContext:(MKGPUImageContext *)context vertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString {
    if (!(self = [super initWithContext:context vertexShaderFromString:vertexShaderString fragmentShaderFromString:fragmentShaderString])) {
        return nil;
    }
    
    _program = [self.context programForVertexShaderString:kMKGPUImageBeautyMakeupVertexShaderString fragmentShaderString:kMKGPUImageBeautyMakeupFragmentShaderString];
    
    if (![_program link])
    {
        NSString *progLog = [_program programLog];
        NSLog(@"Program link log: %@", progLog);
        NSString *fragLog = [_program fragmentShaderLog];
        NSLog(@"Fragment shader compile log: %@", fragLog);
        NSString *vertLog = [_program vertexShaderLog];
        NSLog(@"Vertex shader compile log: %@", vertLog);
        _program = nil;
        NSAssert(NO, @"Filter shader link failed");
    }
    
    _positionAttribute = [_program attributeIndex:@"position"];
    _inTextureAttribute = [_program attributeIndex:@"inputTextureCoordinate"];
    
    _inputImageTextureSlot = [_program uniformIndex:@"inputImageTexture"];
    _materialTextureSlot = [_program uniformIndex:@"materialTexture"];
    _maskTextureSlot = [_program uniformIndex:@"maskTexture"];
    
    _strengthSlot = [_program uniformIndex:@"strength"];
    
    [self generateTexture];

    return self;
}

- (void)generateTexture
{
    UIImage *maskImage = [UIImage imageNamed:@"makeup_lips_mask"];
    UIImage *lutImage = [UIImage imageNamed:@"lut"];
    
    // TODO: 强引用防止纹理被回收。 可以单独创建纹理(不交给MKGPUImageFramebuffer管理，自行管理创建和回收)
    // 遮罩纹理
    _maskPicture = [[MKGPUImagePicture alloc] initWithContext:self.context withImage:maskImage];
    MKGPUImageFramebuffer *maskFrameBuffer = [_maskPicture framebufferForOutput];
    
    // lut 纹理
    _lutPicture = [[MKGPUImagePicture alloc] initWithContext:self.context withImage:lutImage];
    MKGPUImageFramebuffer *lutFrameBuffer = [_lutPicture framebufferForOutput];
    
    maskTexture = [maskFrameBuffer texture];
    lutTexture = [lutFrameBuffer texture];
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
    
    // 逐一绘制
    if(MKLandmarkManager.shareManager.faceData) {
        for(int i = 0; i < MKLandmarkManager.shareManager.faceData.count; i ++) {
            [self drawBeautyMakeupIndexFace:i withTexture:[firstInputFramebuffer texture]];
        }
    }
    
    [firstInputFramebuffer unlock];
}

-(void)drawBeautyMakeupIndexFace:(int)index withTexture:(GLuint)textureId
{
    glEnable(GL_BLEND);
    glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
    
    [outputFramebuffer activateFramebuffer];
    [_program use];
    
    [MKLandmarkEngine.shareManager getLipsVertices:vertexPoints withLength:40 withFaceIndex:index];
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, textureId);
    glUniform1i(_inputImageTextureSlot, 2);
    
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, lutTexture);
    glUniform1i(_materialTextureSlot, 3);
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, maskTexture);
    glUniform1i(_maskTextureSlot, 4);
    
    glUniform1f(_strengthSlot, 1);
    
    glVertexAttribPointer(_positionAttribute, 2, GL_FLOAT, 0, 0, vertexPoints);
    glEnableVertexAttribArray(_positionAttribute);
    glVertexAttribPointer(_inTextureAttribute, 2, GL_FLOAT, 0, 0, LipsMaskTextureVertices);
    glEnableVertexAttribArray(_inTextureAttribute);
    
    glDrawElements(GL_TRIANGLES,sizeof(LipsIndices)/sizeof(LipsIndices[0]), GL_UNSIGNED_SHORT, LipsIndices);
    glDisable(GL_BLEND);
}

@end
