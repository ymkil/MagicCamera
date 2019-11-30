//
//  MKGPUImageBeautifyFilter.h
//  MagicCamera
//
//  Created by mkil on 2019/11/29.
//  Copyright © 2019 黎宁康. All rights reserved.
//

/*
 *  注: 美颜计算过量消耗CPU，会导致实时卡顿
 *  需要的可以看 GPUImageBeautifyFilter,在 Temporary 目录()
 */

#import "MKGPUImageFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImageBeautifyFilter : MKGPUImageFilter

@property (nonatomic, assign) CGFloat beautyLevel;
@property (nonatomic, assign) CGFloat brightLevel;
@property (nonatomic, assign) CGFloat toneLevel;

@end

NS_ASSUME_NONNULL_END
