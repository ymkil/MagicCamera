//
//  MKLandmarkManager.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "MGFacepp.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKLandmarkManager : NSObject
// 人脸数据 [MKFaceInfo]
@property (nonatomic, strong) NSArray *faceData;
// 检测人脸图片的宽度
@property (nonatomic, assign) CGFloat detectionWidth;
// 检测人脸图片的高度
@property (nonatomic, assign) CGFloat detectionHeight;

+ (instancetype)shareManager;

// 像素坐标点转换成位置坐标
-(NSArray<NSValue *> *)conversionCoordinatePoint:(NSArray<NSValue *> *)pixelPoints;

/**
 * 获取用于美型处理的坐标
 * @param vertexPoints      顶点坐标, 共122个顶点
 * @param texturePoints     纹理坐标, 共122个顶点
 @ @param length            数组长度
 * @param faceIndex         人脸索引
 */
-(void)generateFaceAdjustVertexPoints:(float *)vertexPoints withTexturePoints:(float *)texturePoints withLength:(int)length withFaceIndex:(int)faceIndex;
@end

// 人脸数据
@interface MKFaceInfo : NSObject

/** tracking ID */
@property (nonatomic, assign) NSInteger trackID;

/** 在该张图片中人脸序号 */
@property (nonatomic, assign) int index;

/** 人脸的rect */
@property (nonatomic, assign) CGRect rect;

/** 人脸点坐标 （NSValue -> CGPoints）*/
@property (nonatomic, strong) NSArray <NSValue *>*points;

//3D info
@property (nonatomic, assign) float pitch;
@property (nonatomic, assign) float yaw;
@property (nonatomic, assign) float roll;

-(id)initWithInfo:(MGFaceInfo *)info;

@end

NS_ASSUME_NONNULL_END
