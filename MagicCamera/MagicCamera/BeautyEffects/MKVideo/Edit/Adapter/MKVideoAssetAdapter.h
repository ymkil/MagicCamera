//
//  MKVideoAssetAdapter.h
//  MagicCamera
//
//  Created by mkil on 2019/12/7.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MKVideoAssetAdapter : NSObject

@property(nonatomic, strong) AVAsset *asset;

@end

NS_ASSUME_NONNULL_END
