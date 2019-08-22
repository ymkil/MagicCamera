//
//  MKLandmarkManager.m
//  MKBeautyEffectsDemo
//
//  Created by mkil on 2019/8/22.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKLandmarkManager.h"

static MKLandmarkManager *manager = nil;

@implementation MKLandmarkManager

+ (instancetype)shareManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    
    return manager;
}

@end
