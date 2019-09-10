//
//  MKFilterModel.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MKFilterType)
{
    MKFilterTypeBeauty,         // 磨皮、瘦脸等
    MKFilterTypeStyle,          // 风格滤镜
    MKFilterTypeEffects         // 人脸特效
};

@interface MKFilterModel : NSObject

@property (nonatomic, assign) MKFilterType type;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, strong) NSString *image;
@property (nonatomic, assign) BOOL isAdjust;
@property (nonatomic, assign) float currentAlphaValue;
@property (nonatomic, strong) NSArray<NSString *> *textureImages;

+ (NSArray<MKFilterModel *> *)buildFilterModelsWithPath:(NSString *)path whitType:(MKFilterType)type;

@end

NS_ASSUME_NONNULL_END
