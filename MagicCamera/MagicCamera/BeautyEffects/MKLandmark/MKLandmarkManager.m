//
//  MKLandmarkManager.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
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

-(void)setFaceData:(NSArray *)faceData
{
    _faceData = nil;
    if (faceData) {
        NSMutableArray *datas = [NSMutableArray arrayWithCapacity:1];
        for (int i = 0; i < faceData.count; i ++) {
            ((MGFaceInfo *)faceData[i]).points = [self conversionCoordinatePoint:((MGFaceInfo *)faceData[i]).points];
            [datas addObject:[[MKFaceInfo alloc] initWithInfo:faceData[i]]];
            NSLog(@"landmark - %@",((MGFaceInfo *)faceData[i]).points);
        }
        _faceData = datas;
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

@implementation MKFaceInfo

-(id)initWithInfo:(MGFaceInfo *)info
{
    self = [super init];
    if (self) {
        self.trackID = info.trackID;
        self.index = info.index;
        self.rect = info.rect;
        self.points = info.points;
        self.pitch = info.pitch;
        self.yaw = info.yaw;
        self.roll = info.roll;
    }
    return self;
}


@end
