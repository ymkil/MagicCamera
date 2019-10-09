//
//  MKTool.m
//  MagicCamera
//
//  Created by mkil on 2019/10/9.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKTool.h"

@implementation MKTool

+(uint64_t)getCurrentTimeMillis {
    return [[NSDate date] timeIntervalSince1970] * 1000;
}


@end
