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
#import <GLKit/GLKit.h>

NSString *const kMKGPUImageDynamicSticker2DVertexShaderString = SHADER_STRING
(
 attribute vec3 vPosition;
 attribute vec2 in_texture;
 
 varying vec2 textureCoordinate;
 
 uniform mat4 projectionMatrix;
 uniform mat4 viewMatrix;
 uniform mat4 modelViewMatrix;
 
 void main()
 {
     gl_Position = projectionMatrix * viewMatrix * modelViewMatrix * vec4(vPosition, 1.0);
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
    
    GLuint _projectionMatrixSlot;
    GLuint _viewMatrixSlot;
    GLuint _modelViewMatrixSlot;
    
    // 是否第一次生成 投影矩阵
    BOOL _isProjectionMatrix;
    int _msecNum;
}

@property (nonatomic, strong) dispatch_source_t timer;

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
    
    _projectionMatrixSlot = [_program uniformIndex:@"projectionMatrix"];
    _viewMatrixSlot = [_program uniformIndex:@"viewMatrix"];
    _modelViewMatrixSlot = [_program uniformIndex:@"modelViewMatrix"];
    
    //纹理贴图
//    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"F_tsh_008" ofType:@"png"];
//    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:@(1), GLKTextureLoaderOriginBottomLeft, nil];//GLKTextureLoaderOriginBottomLeft 纹理坐标系是相反的
//    _textureInfo = [GLKTextureLoader textureWithContentsOfFile:filePath options:options error:nil];
    
    _isProjectionMatrix = YES;
    return self;
}

- (void)dealloc {
    dispatch_cancel(_timer);
    _timer = nil;
}

#pragma mark -
#pragma mark Timer
- (void)createTimer
{
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    // 一毫秒一次
    dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, NSEC_PER_MSEC, 0);
    
    dispatch_source_set_event_handler(self.timer, ^{
        _msecNum++;
        if (_msecNum == WINT_MAX) {
            _msecNum = 0;
        }
    });

    // 启动定时器
    dispatch_resume(_timer);
}

- (void)generateTransitionMatrix {
    
    float mRatio = outputFramebuffer.size.width/outputFramebuffer.size.height;
    
    // 近平面 设置 为 3
    _projectionMatrix = GLKMatrix4MakeFrustum(-mRatio, mRatio, -1, 1, 3, 9);
    
    _viewMatrix = GLKMatrix4MakeLookAt(0, 0, 6, 0, 0, 0, 0, 1, 0);
}

#pragma mark -
#pragma mark filteModel

-(void)setFilterModel:(MKFilterModel *)filterModel
{
    _filterModel = filterModel;
    _msecNum = 0;
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
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    [outputFramebuffer activateFramebuffer];
    [_program use];
    
    GLfloat tempPoint[8];
    
    CGFloat ProjectionScale = 2;
    
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
    
    // 1.3、求出真正的中心点顶点坐标，这里由于frustumM设置了长宽比，因此ndc坐标计算时需要变成mRatio:1，这里需要转换一下
    float ndcCenterX = (centerX - outputFramebuffer.size.width/outputFramebuffer.size.height) * ProjectionScale;
    float ndcCenterY = (centerY - 1.0f) * ProjectionScale;
    
    // 1.4、贴纸的宽高在ndc坐标系中的长度
    float ndcStickerWidth = stickerWidth / mImageHeight * ProjectionScale;
    float ndcStickerHeight = ndcStickerWidth * (float) node.height / (float) node.width;
    
    
    tempPoint[0] = ndcCenterX - ndcStickerWidth;
    tempPoint[1] = ndcCenterY - ndcStickerHeight;
    
    tempPoint[2] = ndcCenterX + ndcStickerWidth;
    tempPoint[3] = ndcCenterY - ndcStickerHeight;

    tempPoint[4] = ndcCenterX - ndcStickerWidth;
    tempPoint[5] = ndcCenterY + ndcStickerHeight;

    tempPoint[6] = ndcCenterX + ndcStickerWidth;
    tempPoint[7] = ndcCenterY + ndcStickerHeight;

    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    // 欧拉角
//    float pitchAngle = -(float)(faceInfo.pitch * 180/M_PI);
//    float yawAngle = (float)(faceInfo.yaw * 180/M_PI);
//    float rollAngle = (float)(faceInfo.roll * 180/M_PI);

    float pitchAngle = faceInfo.pitch;
    float yawAngle = faceInfo.yaw;
    float rollAngle = -faceInfo.roll;
    
    if (fabsf(yawAngle) > 10) {
        yawAngle = (yawAngle/fabsf(yawAngle)) * 10;
    }
    
    
    if (fabsf(pitchAngle) > 30) {
        pitchAngle = (pitchAngle/fabsf(pitchAngle)) * 30;
    }
    
    NSLog(@"pitchAngle = %f yawAngle = %f rollAngle = %f", pitchAngle, yawAngle, rollAngle);
    
    _modelViewMatrix = GLKMatrix4Identity;
    _modelViewMatrix = GLKMatrix4Translate(_modelViewMatrix, ndcCenterX, ndcCenterY, 0);
    
    _modelViewMatrix = GLKMatrix4RotateZ(_modelViewMatrix, rollAngle);
    _modelViewMatrix = GLKMatrix4RotateY(_modelViewMatrix, yawAngle);
    _modelViewMatrix = GLKMatrix4RotateX(_modelViewMatrix, pitchAngle);
//    _modelViewMatrix = GLKMatrix4Rotate(_modelViewMatrix, rollAngle, 0, 0, 1);
//    _modelViewMatrix = GLKMatrix4Rotate(_modelViewMatrix, 1.5, 0, 1, 0);
//    _modelViewMatrix = GLKMatrix4Rotate(_modelViewMatrix, pitchAngle, 1, 0, 0);
    
    _modelViewMatrix = GLKMatrix4Translate(_modelViewMatrix, -ndcCenterX, -ndcCenterY, 0);
    
    GPUImagePicture *picture1 = [[GPUImagePicture alloc] initWithImage:[UIImage imageNamed:@"F_tsh_008"]];
    GPUImageFramebuffer *frameBuffer1 =  [picture1 framebufferForOutput];
    
    
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, [frameBuffer1 texture]);
    
    glUniform1i(_inputTextureUniform, 3);
    
    glUniformMatrix4fv(_projectionMatrixSlot, 1, GL_FALSE, _projectionMatrix.m);
    glUniformMatrix4fv(_viewMatrixSlot, 1, GL_FALSE, _viewMatrix.m);
    glUniformMatrix4fv(_modelViewMatrixSlot, 1, GL_FALSE, _modelViewMatrix.m);
    
    glVertexAttribPointer(_positionAttribute, 2, GL_FLOAT, 0, 0, tempPoint);
    glEnableVertexAttribArray(_positionAttribute);
    glVertexAttribPointer(_inTextureAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    glEnableVertexAttribArray(_inTextureAttribute);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glDisable(GL_BLEND);
    
}


//- (void)drawFaceNode:(MKNodeModel *)node withfaceInfo:(MKFaceInfo *)faceInfo {
//    glEnable(GL_BLEND);
//    glEnable(GL_DEPTH_TEST);
//    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
//
//    [outputFramebuffer activateFramebuffer];
//    [_program use];
//
//    GLfloat tempPoint[8];
//    CGPoint centerPoint = [faceInfo.points[node.facePos] CGPointValue];
//    CGPoint startPoint = [faceInfo.points[node.startIndex] CGPointValue];
//    CGPoint endPoint = [faceInfo.points[node.endIndex] CGPointValue];
//
//    NSLog(@"pitch = %f yaw = %f roll = %f", faceInfo.pitch, faceInfo.yaw, faceInfo.roll);
//
//    CGFloat faceWidth = fabs(endPoint.x - startPoint.x) * 2;
//
//    CGFloat faceHeight = faceWidth * (node.height/node.width) * 2;
//
//    tempPoint[0] = centerPoint.x - (faceWidth)/2;
//    tempPoint[1] = centerPoint.y - (faceHeight)/2;
//
//    tempPoint[2] = centerPoint.x + (faceWidth)/2;
//    tempPoint[3] = centerPoint.y - (faceHeight)/2;
//
//    tempPoint[4] = centerPoint.x - (faceWidth)/2;
//    tempPoint[5] = centerPoint.y + (faceHeight)/2;
//
//    tempPoint[6] = centerPoint.x + (faceWidth)/2;
//    tempPoint[7] = centerPoint.y + (faceHeight)/2;
//
//    static const GLfloat textureCoordinates[] = {
//        0.0f, 0.0f,
//        1.0f, 0.0f,
//        0.0f, 1.0f,
//        1.0f, 1.0f,
//    };
//
//    // 欧拉角
//    float pitchAngle = -(faceInfo.pitch * 180/M_PI);
//    float yawAngle = (faceInfo.yaw * 180/M_PI);
//    float rollAngle = (faceInfo.roll * 180/M_PI);
//
//    if (fabsf(yawAngle) > 10) {
//        yawAngle = (yawAngle/fabsf(yawAngle)) * 10;
//    }
//
//    if (fabsf(pitchAngle) > 30) {
//        pitchAngle = (pitchAngle/fabsf(pitchAngle)) * 30;
//    }
//
//    NSLog(@"pitchAngle = %f yawAngle = %f rollAngle = %f", pitchAngle, yawAngle, rollAngle);
//
//    _modelViewMatrix = GLKMatrix4Identity;
//    _modelViewMatrix = GLKMatrix4Translate(_modelViewMatrix, centerPoint.x, centerPoint.y, 0);
//
//    //    _modelViewMatrix = GLKMatrix4RotateZ(_modelViewMatrix, rollAngle);
//    //    _modelViewMatrix = GLKMatrix4RotateY(_modelViewMatrix, yawAngle);
//    //    _modelViewMatrix = GLKMatrix4RotateX(_modelViewMatrix, pitchAngle);
//    //    _modelViewMatrix = GLKMatrix4Rotate(_modelViewMatrix, rollAngle, 0, 0, 1);
//    _modelViewMatrix = GLKMatrix4Rotate(_modelViewMatrix, 10, 0, 1, 0);
//    //    _modelViewMatrix = GLKMatrix4Rotate(_modelViewMatrix, pitchAngle, 1, 0, 0);
//
//    _modelViewMatrix = GLKMatrix4Translate(_modelViewMatrix, -centerPoint.x, -centerPoint.y, 0);
//
//    GPUImagePicture *picture1 = [[GPUImagePicture alloc] initWithImage:[UIImage imageNamed:@"F_tsh_008"]];
//    GPUImageFramebuffer *frameBuffer1 =  [picture1 framebufferForOutput];
//
//
//    glActiveTexture(GL_TEXTURE3);
//    glBindTexture(GL_TEXTURE_2D, [frameBuffer1 texture]);
//
//    glUniform1i(_inputTextureUniform, 3);
//
//    glUniformMatrix4fv(_projectionMatrixSlot, 1, GL_FALSE, _projectionMatrix.m);
//    glUniformMatrix4fv(_viewMatrixSlot, 1, GL_FALSE, _viewMatrix.m);
//    glUniformMatrix4fv(_modelViewMatrixSlot, 1, GL_FALSE, _modelViewMatrix.m);
//
//    glVertexAttribPointer(_positionAttribute, 2, GL_FLOAT, 0, 0, tempPoint);
//    glEnableVertexAttribArray(_positionAttribute);
//    glVertexAttribPointer(_inTextureAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
//    glEnableVertexAttribArray(_inTextureAttribute);
//
//    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
//
//    glDisable(GL_BLEND);
//    glDisable(GL_DEPTH_TEST);
//}

float getDistance(float x1, float y1, float x2, float y2) {
    return sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
}

@end
