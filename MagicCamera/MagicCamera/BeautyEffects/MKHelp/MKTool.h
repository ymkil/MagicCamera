//
//  MKTool.h
//  MagicCamera
//
//  Created by mkil on 2019/10/9.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MKTool : NSObject

/// 获取当前毫秒数
+ (uint64_t)getCurrentTimeMillis;

@end

NS_ASSUME_NONNULL_END
