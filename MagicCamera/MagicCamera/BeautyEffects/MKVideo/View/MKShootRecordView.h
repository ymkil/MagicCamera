//
//  MKShootRecordView.h
//  MagicCamera
//
//  Created by mkil on 2019/11/16.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MKShootRecordViewDelegate <NSObject>
- (void)startRecord;
- (void)stopRecord;
@end

NS_ASSUME_NONNULL_BEGIN

@interface MKShootRecordView : UIControl
@property (nonatomic, weak) id <MKShootRecordViewDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
