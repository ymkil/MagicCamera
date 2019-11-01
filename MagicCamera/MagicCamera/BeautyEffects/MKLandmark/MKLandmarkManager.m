//
//  MKLandmarkManager.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKLandmarkManager.h"
#import "MKFaceBaseData.h"
#import "MKTool.h"

static MKLandmarkManager *manager = nil;

@implementation MKLandmarkManager

+ (instancetype)shareManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    
    return manager;
}

-(void)setFaceData:(NSArray *)faceData
{
    _faceData = nil;
    if (faceData) {
        NSMutableArray *datas = [NSMutableArray arrayWithCapacity:1];
        for (int i = 0; i < faceData.count; i ++) {
            ((MGFaceInfo *)faceData[i]).points = [self conversionCoordinatePoint:((MGFaceInfo *)faceData[i]).points];
            [datas addObject:[[MKFaceInfo alloc] initWithInfo:faceData[i]]];
        }
        _faceData = datas;
    }
}

// 像素坐标点转换成位置坐标
-(NSArray<NSValue *> *)conversionCoordinatePoint:(NSArray<NSValue *> *)pixelPoints
{
    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:106];

    for (int i = 0; i < pixelPoints.count; i ++) {
        CGPoint pointer = [pixelPoints[i] CGPointValue];
        CGPoint point = CGPointMake([self changeToGLPointX:pointer.x], [self changeToGLPointY:pointer.y]);
        [points addObject:[NSValue valueWithCGPoint:point]];
    }
    
    return points;
}

- (GLfloat)changeToGLPointX:(CGFloat)x{
    GLfloat tempX = (x - _detectionWidth/2) / (_detectionWidth/2);
    return tempX;
}
- (GLfloat)changeToGLPointY:(CGFloat)y{
    GLfloat tempY = (_detectionHeight/2 - (_detectionHeight - y)) / (_detectionHeight/2);
    return tempY;
}

/**
 * 获取用于美型处理的坐标
 * @param vertexPoints      顶点坐标, 共122个顶点
 * @param texturePoints     纹理坐标, 共122个顶点
 @ @param length            数组长度
 * @param faceIndex         人脸索引
 */

-(void)generateFaceAdjustVertexPoints:(float *)vertexPoints withTexturePoints:(float *)texturePoints withLength:(int)length withFaceIndex:(int)faceIndex {
    
    if (vertexPoints == NULL || length != 122 * 2 || texturePoints == NULL) {
        return;
    }
    
    // 计算额外的人脸顶点坐标
    [self calculateExtraFacePoints:vertexPoints withLength:length withFaceIndex:faceIndex];
    // 计算图像边沿顶点坐标
    [self calculateImageEdgePoints:vertexPoints withLength:length];
    // 计算纹理坐标
    for (int i = 0; i < length; i ++) {
        texturePoints[i] = vertexPoints[i] * 0.5 + 0.5;
    }
}

/**
 *  计算人脸额外顶点，新增8个额外顶点坐标
 *  @param vertexPoints 顶点坐标, 共122个顶点
 *  @param length       数组长度
 *  @param faceIndex    人脸索引
 */

-(void)calculateExtraFacePoints:(float *)vertexPoints withLength:(int)length withFaceIndex:(int)faceIndex {
    if (self.faceData == NULL || self.faceData.count <= 0 || self.faceData.count <= faceIndex) {
        return;
    }
    
    MKFaceInfo *faceInfo = self.faceData[faceIndex];
    
    if(vertexPoints == NULL || (faceInfo.points.count + 8) * 2 > length ) {
        return;
    }
    
    // 取出前106个关键点
    for (int i = 0; i < faceInfo.points.count; i ++) {
        vertexPoints[i * 2] = [faceInfo.points[i] CGPointValue].x;
        vertexPoints[i * 2 + 1] = [faceInfo.points[i] CGPointValue].y;
    }
    
    float tempPoint[2] = {0,0};
    // 嘴唇中心
    getCenter(vertexPoints[mouthUpperLipBottom * 2], vertexPoints[mouthUpperLipBottom * 2 + 1], vertexPoints[mouthLowerLipTop * 2], vertexPoints[mouthLowerLipTop * 2 + 1], tempPoint);
    vertexPoints[mouthCenter * 2] = tempPoint[0];
    vertexPoints[mouthCenter * 2 + 1] = tempPoint[1];
    
    // 左眉心
    getCenter(vertexPoints[leftEyebrowUpperMiddle * 2], vertexPoints[leftEyebrowUpperMiddle * 2 + 1], vertexPoints[leftEyebrowLowerMiddle * 2], vertexPoints[leftEyebrowLowerMiddle * 2 + 1], tempPoint);
    vertexPoints[leftEyebrowCenter * 2] = tempPoint[0];
    vertexPoints[leftEyebrowCenter * 2 + 1] = tempPoint[1];
    
    // 右眉心
    getCenter(vertexPoints[rightEyebrowUpperMiddle * 2], vertexPoints[rightEyebrowUpperMiddle * 2 + 1], vertexPoints[rightEyebrowLowerMiddle * 2], vertexPoints[rightEyebrowLowerMiddle * 2 + 1], tempPoint);
    vertexPoints[rightEyebrowCenter * 2] = tempPoint[0];
    vertexPoints[rightEyebrowCenter * 2 + 1] = tempPoint[1];
    
    // 额头中心
    vertexPoints[headCenter * 2] = vertexPoints[eyeCenter * 2] * 2 - vertexPoints[noseLowerMiddle * 2];
    vertexPoints[headCenter * 2 + 1] = vertexPoints[eyeCenter * 2 + 1] * 2 - vertexPoints[noseLowerMiddle * 2 + 1];
    
    // 额头左侧
    getCenter(vertexPoints[leftEyebrowLeftTopCorner * 2], vertexPoints[leftEyebrowLeftTopCorner * 2 + 1], vertexPoints[headCenter * 2], vertexPoints[headCenter * 2 + 1], tempPoint);
    vertexPoints[leftHead * 2] = tempPoint[0];
    vertexPoints[leftHead * 2 + 1] = tempPoint[1];
    
    // 额头右侧
    getCenter(vertexPoints[rightEyebrowRightTopCorner * 2], vertexPoints[rightEyebrowRightTopCorner * 2 + 1], vertexPoints[headCenter * 2], vertexPoints[headCenter * 2 + 1], tempPoint);
    vertexPoints[rightHead * 2] = tempPoint[0];
    vertexPoints[rightHead * 2 + 1] = tempPoint[1];
    
    // 左脸颊中心
    getCenter(vertexPoints[leftCheekEdgeCenter * 2], vertexPoints[leftCheekEdgeCenter * 2 + 1], vertexPoints[noseLeft * 2], vertexPoints[noseLeft * 2 + 1], tempPoint);
    vertexPoints[leftCheekCenter * 2] = tempPoint[0];
    vertexPoints[leftCheekCenter * 2 + 1] = tempPoint[1];
    
    // 右脸颊中心
    getCenter(vertexPoints[rightCheekEdgeCenter * 2], vertexPoints[rightCheekEdgeCenter * 2 + 1], vertexPoints[noseRight * 2], vertexPoints[noseRight * 2 + 1], tempPoint);
    vertexPoints[rightCheekCenter * 2] = tempPoint[0];
    vertexPoints[rightCheekCenter * 2 + 1] = tempPoint[1];
    
}

/**
 *  计算图像周围顶点
 *  @param vertexPoints 顶点坐标
 *  @param length       数组长度
 */

-(void)calculateImageEdgePoints:(float *)vertexPoints withLength:(int)length {
    
    if (vertexPoints == NULL || length < 122 * 2) {
        return;
    }
    
    // TODO: 方向待处理
    vertexPoints[114 * 2] = 0;
    vertexPoints[114 * 2 + 1] = 1;
    vertexPoints[115 * 2] = 1;
    vertexPoints[115 * 2 + 1] = 1;
    vertexPoints[116 * 2] = 1;
    vertexPoints[116 * 2 + 1] = 0;
    vertexPoints[117 * 2] = 1;
    vertexPoints[117 * 2 + 1] = -1;
    
    // 118 ~ 121 与 114 ~ 117 的顶点坐标恰好反过来
    vertexPoints[118 * 2] = -vertexPoints[114 * 2];
    vertexPoints[118 * 2 + 1] = -vertexPoints[114 * 2 + 1];
    vertexPoints[119 * 2] = -vertexPoints[115 * 2];
    vertexPoints[119 * 2 + 1] = -vertexPoints[115 * 2 + 1];
    vertexPoints[120 * 2] = -vertexPoints[116 * 2];
    vertexPoints[120 * 2 + 1] = -vertexPoints[116 * 2 + 1];
    vertexPoints[121 * 2] = -vertexPoints[117 * 2];
    vertexPoints[121 * 2 + 1] = -vertexPoints[117 * 2 + 1];
}



@end

@implementation MKFaceInfo

-(id)initWithInfo:(MGFaceInfo *)info
{
    self = [super init];
    if (self) {
        self.trackID = info.trackID;
        self.index = info.index;
        self.rect = info.rect;
        self.points = info.points;
        self.pitch = info.pitch;
        self.yaw = info.yaw;
        self.roll = info.roll;
    }
    return self;
}


@end
