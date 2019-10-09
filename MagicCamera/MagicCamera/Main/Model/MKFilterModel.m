//
//  MKFilterModel.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKFilterModel.h"

#define kFilterShaderDefaultAlphaValue 0.5f

@implementation MKNodeModel

@end

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
            
            MKFilterModel *model;
            // build
            if (type == MKFilterTypeStyle) {
                model = [self buildStyleFilterModelsWithPath:currentFolder];
            } else if (type == MKFilterTypeEffects) {
                model = [self buildStickerFilterModelsWithPath:currentFolder];
            }
            
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

// 人脸特效
+ (MKFilterModel *)buildStickerFilterModelsWithPath:(NSString *)filter {
    
    // StickerPath
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
    model.type = MKFilterTypeEffects;
    
    NSMutableArray *nodes = [NSMutableArray arrayWithCapacity:1];
    
    for (NSDictionary *nodeDict in dict[@"nodes"]) {
        MKNodeModel *node = [[MKNodeModel alloc] init];
        node.type = nodeDict[@"type"];
        node.dirname = nodeDict[@"dirname"];
        node.filePath = [currentFolder stringByAppendingPathComponent:nodeDict[@"dirname"]];
        node.facePos = [nodeDict[@"facePos"] integerValue];
        node.startIndex = [nodeDict[@"startIndex"] integerValue];
        node.endIndex = [nodeDict[@"endIndex"] integerValue];
        node.offsetX = [nodeDict[@"offsetX"] floatValue];
        node.offsetY = [nodeDict[@"offsetY"] floatValue];
        node.ratio = [nodeDict[@"ratio"] floatValue];
        node.number = [nodeDict[@"number"] integerValue];
        node.width = [nodeDict[@"width"] floatValue];
        node.height = [nodeDict[@"height"] floatValue];
        node.duration = [nodeDict[@"duration"] integerValue];
        node.isloop = [nodeDict[@"isloop"] integerValue];
        node.maxcount = [nodeDict[@"maxcount"] integerValue];
        [nodes addObject:node];
    }
    model.nodes = nodes;

    return model;
}

@end
