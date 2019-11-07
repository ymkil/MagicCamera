//
//  MKGPUImageDynamicSticker2DFilter.m
//  MagicCamera
//
//  Created by mkil on 2019/9/29.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageDynamicSticker2DFilter.h"
#import "MKHeader.h"

#import "MKLandmarkManager.h"

#import <GPUImage/GPUImage.h>
#import "MKGPUImagePicture.h"
#import <GLKit/GLKit.h>

#import "MKTool.h"

/// 贴纸跟近平面的坐标比例
static CGFloat ProjectionScale = 2;

NSString *const kMKGPUImageDynamicSticker2DVertexShaderString = SHADER_STRING
(
 attribute vec3 vPosition;
 attribute vec2 in_texture;
 
 varying vec2 textureCoordinate;
 
 uniform mat4 u_mvpMatrix;
 
 void main()
 {
     gl_Position = u_mvpMatrix * vec4(vPosition, 1.0);
     textureCoordinate = in_texture;
 }
 );

NSString *const kMKGPUImageDynamicSticker2DFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );

@interface MKGPUImageDynamicSticker2DFilter()
{
    MKGLProgram *_program;
    
    GLint _positionAttribute;
    GLint _inTextureAttribute;
    GLint _inputTextureUniform;
    
    
    GLKMatrix4 _projectionMatrix;
    GLKMatrix4 _viewMatrix;
    GLKMatrix4 _modelViewMatrix;
    
    GLuint _mvpMatrixSlot;
    
    // 是否第一次生成 投影矩阵
    BOOL _isProjectionMatrix;
}

/// 记录每个node的起始毫秒，用于计算对应帧数
@property(nonatomic, strong) NSMutableDictionary *nodeFrameTime;

@end

@implementation MKGPUImageDynamicSticker2DFilter

- (id)initWithContext:(MKGPUImageContext *)context vertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString {
    if (!(self = [super initWithContext:context vertexShaderFromString:vertexShaderString fragmentShaderFromString:fragmentShaderString])) {
        return nil;
    }
    
    _program = [self.context programForVertexShaderString:kMKGPUImageDynamicSticker2DVertexShaderString fragmentShaderString:kMKGPUImageDynamicSticker2DFragmentShaderString];
    
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
    
    _positionAttribute = [_program attributeIndex:@"vPosition"];
    _inTextureAttribute = [_program attributeIndex:@"in_texture"];
    _inputTextureUniform = [_program uniformIndex:@"inputImageTexture"];
    
    _mvpMatrixSlot = [_program uniformIndex:@"u_mvpMatrix"];
    
    _nodeFrameTime = [[NSMutableDictionary alloc] initWithCapacity:6];
    
    _isProjectionMatrix = YES;
    return self;
}

#pragma mark -
#pragma mark matrix

- (void)generateTransitionMatrix {
    
    float mRatio = outputFramebuffer.size.width/outputFramebuffer.size.height;
    
    _projectionMatrix = GLKMatrix4MakeFrustum(-mRatio, mRatio, -1, 1, 3, 9);
    
    _viewMatrix = GLKMatrix4MakeLookAt(0, 0, 6, 0, 0, 0, 0, 1, 0);
}

#pragma mark -
#pragma mark filteModel

-(void)setFilterModel:(MKFilterModel *)filterModel
{
    _filterModel = filterModel;
    [_nodeFrameTime removeAllObjects];
}

#pragma mark -
#pragma mark draw
- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;{
    
    [self.context useAsCurrentContext];
    
    [filterProgram use];
    outputFramebuffer = [[self.context framebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions missCVPixelBuffer:YES];
    [outputFramebuffer activateFramebuffer];
    
    if (_isProjectionMatrix) {
        [self generateTransitionMatrix];
        _isProjectionMatrix = NO;
    }

    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    
    glUniform1i(filterInputTextureUniform, 2);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    // 逐一绘制
    if(MKLandmarkManager.shareManager.faceData && _filterModel && _filterModel.nodes) {
        for (int i = 0; i < MKLandmarkManager.shareManager.faceData.count; i ++) {
            for (int j = 0; j < _filterModel.nodes.count; j ++) {
                if (i >= _filterModel.nodes[j].maxcount) continue;
                [self drawFaceNode:_filterModel.nodes[j] withfaceInfo:MKLandmarkManager.shareManager.faceData[i]];
            }
        }
    }
    
    [firstInputFramebuffer unlock];
}

- (void)drawFaceNode:(MKNodeModel *)node withfaceInfo:(MKFaceInfo *)faceInfo {
    
    GLuint textureId = [self getNodeTexture:node];
    if (textureId <= 0) return;
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    [outputFramebuffer activateFramebuffer];
    [_program use];
    
    GLfloat tempPoint[8];
    
    CGFloat mImageWidth = MKLandmarkManager.shareManager.detectionWidth;
    CGFloat mImageHeight = MKLandmarkManager.shareManager.detectionHeight;
    
    float stickerWidth = getDistance(([faceInfo.points[node.startIndex] CGPointValue].x * 0.5 + 0.5) * mImageWidth,
                                     ([faceInfo.points[node.startIndex] CGPointValue].y * 0.5 + 0.5) * mImageHeight, ([faceInfo.points[node.endIndex] CGPointValue].x * 0.5 + 0.5) * mImageWidth, ([faceInfo.points[node.endIndex] CGPointValue].y * 0.5 + 0.5) * mImageHeight);
    float stickerHeight = stickerWidth * node.height/node.width;
    
    float centerX = 0.0f;
    float centerY = 0.0f;
    
    centerX = ([faceInfo.points[node.facePos] CGPointValue].x * 0.5 + 0.5) * mImageWidth;
    centerY = ([faceInfo.points[node.facePos] CGPointValue].y * 0.5 + 0.5) * mImageHeight;
    
    centerX = centerX / mImageHeight * ProjectionScale;
    centerY = centerY / mImageHeight * ProjectionScale;
    
    // 求出真正的中心点顶点坐标，这里由于frustumM设置了长宽比，因此ndc坐标计算时需要变成mRatio:1，这里需要转换一下
    float ndcCenterX = (centerX - outputFramebuffer.size.width/outputFramebuffer.size.height) * ProjectionScale;
    float ndcCenterY = (centerY - 1.0f) * ProjectionScale;
    
    // 贴纸的宽高在ndc坐标系中的长度
    float ndcStickerWidth = stickerWidth / mImageHeight * ProjectionScale;
    float ndcStickerHeight = ndcStickerWidth * (float) node.height / (float) node.width;
    
    // ndc偏移坐标
    float offsetX = (stickerWidth * node.offsetX) / mImageHeight * ProjectionScale;
    float offsetY = (stickerHeight * node.offsetY) / mImageHeight * ProjectionScale;

    // 根据偏移坐标算出锚点的ndc 坐标
    float anchorX = ndcCenterX + offsetX;
    float anchorY = ndcCenterY + offsetY;
    
    // 贴纸实际的顶点坐标
    tempPoint[0] = anchorX - ndcStickerWidth;
    tempPoint[1] = anchorY - ndcStickerHeight;
    
    tempPoint[2] = anchorX + ndcStickerWidth;
    tempPoint[3] = anchorY - ndcStickerHeight;

    tempPoint[4] = anchorX - ndcStickerWidth;
    tempPoint[5] = anchorY + ndcStickerHeight;

    tempPoint[6] = anchorX + ndcStickerWidth;
    tempPoint[7] = anchorY + ndcStickerHeight;

    // 纹理坐标
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    // 欧拉角
    float pitchAngle = faceInfo.pitch;
    float yawAngle = faceInfo.yaw;
    float rollAngle = -faceInfo.roll;
    
    _modelViewMatrix = GLKMatrix4Identity;
    
    // 移到贴纸中心
    _modelViewMatrix = GLKMatrix4Translate(_modelViewMatrix, ndcCenterX, ndcCenterY, 0);
    
    _modelViewMatrix = GLKMatrix4RotateZ(_modelViewMatrix, rollAngle);
    _modelViewMatrix = GLKMatrix4RotateY(_modelViewMatrix, yawAngle);
    _modelViewMatrix = GLKMatrix4RotateX(_modelViewMatrix, pitchAngle);

    // 平移回到原来构建的视椎体的位置
    _modelViewMatrix = GLKMatrix4Translate(_modelViewMatrix, -ndcCenterX, -ndcCenterY, 0);
    
    GLKMatrix4 mvpMatrix = GLKMatrix4Multiply(_projectionMatrix, _viewMatrix);
    mvpMatrix = GLKMatrix4Multiply(mvpMatrix, _modelViewMatrix);
    
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, textureId);
    glUniform1i(_inputTextureUniform, 3);
    
    glUniformMatrix4fv(_mvpMatrixSlot, 1, GL_FALSE, mvpMatrix.m);
    
    glVertexAttribPointer(_positionAttribute, 2, GL_FLOAT, 0, 0, tempPoint);
    glEnableVertexAttribArray(_positionAttribute);
    glVertexAttribPointer(_inTextureAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    glEnableVertexAttribArray(_inTextureAttribute);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glDisable(GL_BLEND);

}

-(GLuint )getNodeTexture:(MKNodeModel *)node {
    
    uint64_t nodeMillis = 0;
    
    if (_nodeFrameTime[node.dirname] == nil) {
        nodeMillis = [MKTool getCurrentTimeMillis];
        _nodeFrameTime[node.dirname] = [[NSNumber alloc] initWithUnsignedLongLong:nodeMillis];
    } else {
        nodeMillis = [_nodeFrameTime[node.dirname] unsignedLongLongValue];
    }
    
    int frameIndex = (int)(([MKTool getCurrentTimeMillis] - nodeMillis) / node.duration);
    
    if (frameIndex >= node.number) {
        if (node.isloop) {
            _nodeFrameTime[node.dirname] = [[NSNumber alloc] initWithUnsignedLongLong:[MKTool getCurrentTimeMillis]];
            frameIndex = 0;
        } else {
            return 0;
        }
    }
    
    NSString *imageName = [NSString stringWithFormat:@"%@_%03d.png",node.dirname,frameIndex];
    NSString *path = [node.filePath stringByAppendingPathComponent:imageName];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    
    MKGPUImagePicture *picture = [[MKGPUImagePicture alloc] initWithContext:self.context withImage:image];
    MKGPUImageFramebuffer *pictureFrameBuffer = [picture framebufferForOutput];
    
    return [pictureFrameBuffer texture];
}

@end
