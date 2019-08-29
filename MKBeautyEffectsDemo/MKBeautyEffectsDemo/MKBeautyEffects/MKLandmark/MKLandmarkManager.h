//
//  MKLandmarkManager.h
//  MKBeautyEffectsDemo
//
//  Created by mkil on 2019/8/22.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MKLandmarkManager : NSObject

@property (nonatomic, strong) NSArray *faceData;

@property (nonatomic, assign) CGFloat detectionWidth;

@property (nonatomic, assign) CGFloat detectionHeight;

+ (instancetype)shareManager;

-(NSArray<NSValue *> *)conversionCoordinatePoint:(NSArray<NSValue *> *)pixelPoints;
@end

NS_ASSUME_NONNULL_END
