//
//  MKLandmarkManager.h
//  MKBeautyEffectsDemo
//
//  Created by mkil on 2019/8/22.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MKLandmarkManager : NSObject

@property (nonatomic, strong) NSArray *faceData;
+ (instancetype)shareManager;
@end

NS_ASSUME_NONNULL_END
