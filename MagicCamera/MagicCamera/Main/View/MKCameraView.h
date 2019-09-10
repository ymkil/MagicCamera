//
//  MKCameraView.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MKFilterModel.h"

NS_ASSUME_NONNULL_BEGIN

@protocol CameraViewDelegate <NSObject>
-(void)alterFilterModel:(MKFilterModel*) model;
-(void)alterIntensity:(float) intensity;
@end


@interface MKCameraView : UIView
@property (nonatomic, weak) id<CameraViewDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
