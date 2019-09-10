//
//  MKEffectFilter.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "GPUImageFilter.h"
#import "MKFilterModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKEffectFilter : GPUImageFilter

-(void)setFilterModel:(MKFilterModel *)filterModel;

// 强度 (0~1)
-(void)setIntensity:(CGFloat)intensity;

@end

NS_ASSUME_NONNULL_END
