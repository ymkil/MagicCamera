//
//  MKFilterModel.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKFilterModel.h"

#define kFilterShaderDefaultAlphaValue 0.5f

@implementation MKFilterModel

+ (NSArray<MKFilterModel *> *)buildFilterModelsWithPath:(NSString *)path whitType:(MKFilterType)type
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return nil;
    }
    
    NSMutableArray<MKFilterModel *> *filters = [NSMutableArray array];
    
    if (type == MKFilterTypeStyle || type == MKFilterTypeEffects) {
        
        NSArray<NSString *> *filterFolder = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
        
        for (NSString *filter in filterFolder) {
            NSString *currentFolder = [path stringByAppendingPathComponent:filter];
            // build
            MKFilterModel *model = [self buildStyleFilterModelsWithPath:currentFolder];
            
            // add
            if (model) {
                [filters addObject:model];
            }
        }
    } else {
        
    }
    
    return filters;
}

// 风格滤镜
+ (MKFilterModel *)buildStyleFilterModelsWithPath:(NSString *)filter {
    
    // filterPath
    NSString *currentFolder = filter;
    // config
    NSString *config = [currentFolder stringByAppendingPathComponent:@"config.json"];
    NSData *configData = [NSData dataWithContentsOfFile:config];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:configData options:NSJSONReadingMutableContainers error:nil];
    if (!dict) {
        return nil;
    }
    
    MKFilterModel *model = [[MKFilterModel alloc] init];
    model.fileName = [[currentFolder lastPathComponent] lowercaseString];
    model.name = dict[@"name"];
    model.icon = [currentFolder stringByAppendingPathComponent:dict[@"icon"]];
    model.image = [currentFolder stringByAppendingPathComponent:dict[@"image"]];
    model.currentAlphaValue = kFilterShaderDefaultAlphaValue;
    model.type = MKFilterTypeStyle;
        
    return model;
}

@end
