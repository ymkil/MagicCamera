//
//  MKLandmarkManager.m
//  MKBeautyEffectsDemo
//
//  Created by mkil on 2019/8/22.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKLandmarkManager.h"

#import "MGFacepp.h"

static MKLandmarkManager *manager = nil;

@implementation MKLandmarkManager

+ (instancetype)shareManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    
    return manager;
}

-(void)setFaceData:(NSArray *)faceData
{
    _faceData = faceData;
    if (_faceData) {
        for (int i = 0; i < _faceData.count; i ++) {
            ((MGFaceInfo *)_faceData[i]).points = [self conversionCoordinatePoint:((MGFaceInfo *)_faceData[i]).points];
            
            NSLog(@"landmark - %@",((MGFaceInfo *)_faceData[i]).points);
        }
        
    }
}

// 像素坐标点转换成位置坐标
-(NSArray<NSValue *> *)conversionCoordinatePoint:(NSArray<NSValue *> *)pixelPoints
{
    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:106];

    for (int i = 0; i < pixelPoints.count; i ++) {
        CGPoint pointer = [pixelPoints[i] CGPointValue];
        CGPoint point = CGPointMake([self changeToGLPointX:pointer.x], [self changeToGLPointY:pointer.y]);
        [points addObject:[NSValue valueWithCGPoint:point]];
    }
    
    return points;
}


- (GLfloat)changeToGLPointX:(CGFloat)x{
    GLfloat tempX = (x - _detectionWidth/2) / (_detectionWidth/2);
    
    return tempX;
}
- (GLfloat)changeToGLPointY:(CGFloat)y{
    GLfloat tempY = (_detectionHeight/2 - (_detectionHeight - y)) / (_detectionHeight/2);
    
    return tempY;
}

@end
