//
//  MKGPUImageOutput.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MKGPUImageFramebuffer.h"
#import "MKGPUImageContext.h"


NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImageOutput : NSObject
{
    MKGPUImageFramebuffer *outputFramebuffer;
    
    NSMutableArray *targets;
    
    CGSize inputTextureSize;
}

@property(readwrite, nonatomic) BOOL shouldSmoothlyScaleOutput;
@property (nonatomic, weak) MKGPUImageContext *context;
@property(readwrite, nonatomic) MKGPUTextureOptions outputTextureOptions;

- (id)initWithContext:(MKGPUImageContext *)context;

- (MKGPUImageFramebuffer *)framebufferForOutput;

- (void)removeOutputFramebuffer;

- (NSArray*)targets;

- (void)addTarget:(id<MKGPUImageInput>)newTarget;

- (void)removeTarget:(id<MKGPUImageInput>)targetToRemove;

- (void)removeAllTargets;

@end

NS_ASSUME_NONNULL_END
