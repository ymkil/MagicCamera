//
//  MKOverlayView.h
//  MagicCamera
//
//  Created by mkil on 2019/11/29.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MKFilterModel.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MKOverlayViewDelegate <NSObject>
// 开始录制
- (void)startRecord;
// 停止录制
- (void)stopRecord;
// 删除上一段
- (void)deleteUpSegment;

- (void)tappedToFocusAtPoint:(CGPoint)point;
- (void)tappedToExposeAtPoint:(CGPoint)point;
- (void)tappedToResetFocusAndExposure;

-(void)alterFilterModel:(MKFilterModel*) model;
-(void)alterIntensity:(float) intensity;

-(void)rotateCamera;

@end

@interface MKOverlayView : UIView

@property(nonatomic, strong) id<MKOverlayViewDelegate> delegate;

@property (nonatomic) BOOL tapToFocusEnabled;
@property (nonatomic) BOOL tapToExposeEnabled;

@end

NS_ASSUME_NONNULL_END
