//
//  MKRecordProgressView.h
//  MagicCamera
//
//  Created by mkil on 2019/11/25.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MKRecordProgressView : UIView

@property (nonatomic, strong) UIColor *pauseColor;
@property (nonatomic, strong) UIColor *drawColor;

@property (nonatomic, copy) void(^deleteToProgressValue)(CGFloat value);

// 设置步长 使其整体进度 在 0.0 ~ 1.0 之间
@property(nonatomic, assign) CGFloat step;

//绘制中
- (void)drawMoved;

//暂停
-(void)drawPause;

//删除上一段
- (void)drawDelete;

@end

NS_ASSUME_NONNULL_END
