//
//  MKGPUImageLookupFilter.h
//  MagicCamera
//
//  Created by mkil on 2019/9/10.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImageLookupFilter : MKGPUImageFilter

@property (nonatomic, strong) UIImage* lookup;

@property (nonatomic, assign) CGFloat intensity;

@end

NS_ASSUME_NONNULL_END
