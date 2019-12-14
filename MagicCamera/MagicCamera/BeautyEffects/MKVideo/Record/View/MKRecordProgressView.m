//
//  MKRecordProgressView.m
//  MagicCamera
//
//  Created by mkil on 2019/11/25.
//  Copyright © 2019 黎宁康. All rights reserved.
//


#import "MKRecordProgressView.h"

struct RecordPoint {
    float start;
    float end;
};

@interface MKRecordProgressView()
{
    CGContextRef context;
    
    CGFloat progressEnd;   // 0.0 ~ 1.0
    
    struct RecordPoint nowPoint;
    
    NSMutableArray *allArray;
    NSMutableArray *pauseArray;
}


@end

@implementation MKRecordProgressView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.backgroundColor = [UIColor colorWithRed:85/255.0 green:83/255.0 blue:83/255.0 alpha:1];
        
        progressEnd = 0;
        _step = 0;
        allArray = [NSMutableArray arrayWithCapacity:5];
        pauseArray = [NSMutableArray arrayWithCapacity:5];
        
        nowPoint.start = 0.0;
        nowPoint.end = 0.0;
        
        _drawColor = [UIColor colorWithRed:245/255.0 green:203/255.0 blue:74/255.0 alpha:1];
        _pauseColor = [UIColor whiteColor];
        
        [self setNeedsDisplay];
    }
    
    return self;
}

- (void)drawRect:(CGRect)rect
{
    context = UIGraphicsGetCurrentContext();
    
    // 绘制背景条
    CGContextSetLineWidth(context, rect.size.height);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:85/255.0 green:83/255.0 blue:83/255.0 alpha:1].CGColor);
    CGContextMoveToPoint(context, rect.origin.x, rect.origin.y);
    CGContextAddLineToPoint(context, rect.size.width, rect.size.height);
    CGContextStrokePath(context);
    
    if (allArray.count <= 0) {
        if (nowPoint.end <= 0.0) {
            return;
        }
    }
    
    // 更新历史进度
    CGFloat beginX = 0;
    CGFloat endX = 0;
    
    if (allArray.count > 0) {
        struct RecordPoint beginPoint;
        struct RecordPoint endPoint;
        
        [allArray.firstObject getValue:&beginPoint];
        [allArray.lastObject getValue:&endPoint];
        
        beginX = beginPoint.start;
        endX = endPoint.end;
        
        CGContextSetStrokeColorWithColor(context, [_drawColor CGColor]);
        CGContextMoveToPoint(context, rect.size.width * beginX, 0);
        CGContextAddLineToPoint(context, rect.size.width * endX, 0);
        CGContextAddLineToPoint(context, rect.size.width * endX, rect.size.height);
        CGContextAddLineToPoint(context, rect.size.width * beginX, rect.size.height);
        CGContextStrokePath(context);
    }
    
    // 当前进度
    if (nowPoint.end != 0.0) {

        CGContextSetStrokeColorWithColor(context, [_drawColor CGColor]);
        CGContextMoveToPoint(context, rect.size.width * nowPoint.start, 0);
        CGContextAddLineToPoint(context, rect.size.width * nowPoint.end, 0);
        CGContextAddLineToPoint(context, rect.size.width * nowPoint.end, rect.size.height);
        CGContextAddLineToPoint(context, rect.size.width * nowPoint.start, rect.size.height);
        CGContextStrokePath(context);
        
    }
    
    // 暂停
    for (int i = 0; i < pauseArray.count; i++)
    {
        struct RecordPoint tempPoint;
        
        [pauseArray[i] getValue:&tempPoint];
        
//        CGContextSetStrokeColorWithColor(context, [pauseColor CGColor]);
//        CGContextMoveToPoint(context, rect.size.width * tempPoint.start, 0);
//        CGContextAddLineToPoint(context, rect.size.width * tempPoint.end + 1, rect.size.height);
//        CGContextStrokePath(context);
        
        CGContextSetStrokeColorWithColor(context, [_pauseColor CGColor]);
        CGContextMoveToPoint(context, rect.size.width * tempPoint.start, 0);
        CGContextAddLineToPoint(context, rect.size.width * tempPoint.end, 0);
        CGContextAddLineToPoint(context, rect.size.width * tempPoint.end, rect.size.height);
        CGContextAddLineToPoint(context, rect.size.width * tempPoint.start, rect.size.height);
        CGContextStrokePath(context);
    }
    
}

- (void)setStep:(CGFloat)step {
    if (step > 1.0 || step < 0.0) {
        _step = 0.0;
    } else {
        _step = step;
    }
}

- (void)drawMoved
{
    if (progressEnd == 0.0) {
        nowPoint.start = 0.0;
        nowPoint.end = _step;
    }
    progressEnd += _step;
    
    if (progressEnd >= 1.0) {
        progressEnd = 1.0;
    }
    nowPoint.end = progressEnd;
    [self setNeedsDisplay];
}

-(void)drawPause {
    //记录每次暂停的每一段
    if (progressEnd <= 1.0) {
        
        struct RecordPoint endPoint;
        [allArray.lastObject getValue:&endPoint];
        
        if (endPoint.end < 1.0) {
            [allArray addObject:[NSValue value:&nowPoint withObjCType:@encode(struct RecordPoint)]];
        }
    }

    nowPoint.start = progressEnd;
    nowPoint.end = progressEnd;

    if (progressEnd < 1.0) {
        struct RecordPoint pausePoint;
        pausePoint.start = progressEnd;
        pausePoint.end = progressEnd;
        [pauseArray addObject:[NSValue value:&pausePoint withObjCType:@encode(struct RecordPoint)]];
    }
    
    [self setNeedsDisplay];
}

- (void)drawDelete
{
    struct RecordPoint deletePoint;
    [allArray.lastObject getValue:&deletePoint];
    
    _deleteToProgressValue(1/(deletePoint.end - deletePoint.start));
    
    [pauseArray removeLastObject];
    [allArray removeLastObject];

    nowPoint.start = 0;
    nowPoint.end = 0;
    
    if (allArray.count > 0) {
        [allArray.lastObject getValue:&nowPoint];
    }
    
    progressEnd = nowPoint.end;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay];
    });
}

@end
