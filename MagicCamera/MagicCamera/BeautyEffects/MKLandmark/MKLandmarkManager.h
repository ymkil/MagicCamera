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

@property (nonatomic, strong) NSArray *faceData;

@property (nonatomic, assign) CGFloat detectionWidth;

@property (nonatomic, assign) CGFloat detectionHeight;

+ (instancetype)shareManager;

-(NSArray<NSValue *> *)conversionCoordinatePoint:(NSArray<NSValue *> *)pixelPoints;
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
