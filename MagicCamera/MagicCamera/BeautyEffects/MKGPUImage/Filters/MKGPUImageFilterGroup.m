//
//  MKGPUImageFilterGroup.m
//  MagicCamera
//
//  Created by mkil on 2019/11/11.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageFilterGroup.h"

@implementation MKGPUImageFilterGroup

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    filters = [[NSMutableArray alloc] init];
    return self;
}

#pragma mark -
#pragma mark Filter management

- (void)addFilter:(MKGPUImageOutput<MKGPUImageInput> *)newFilter
{
    [filters addObject:newFilter];
}

- (MKGPUImageOutput<MKGPUImageInput> *)filterAtIndex:(NSUInteger)filterIndex
{
    return [filters objectAtIndex:filterIndex];
}

- (NSUInteger)filterCount
{
    return [filters count];
}

#pragma mark -
#pragma mark MKGPUImageOutput overrides

- (NSArray*)targets {
    return [_terminalFilter targets];
}

- (void)addTarget:(id<MKGPUImageInput>)newTarget
{
    [_terminalFilter addTarget:newTarget];
}

- (void)removeTarget:(id<MKGPUImageInput>)targetToRemove
{
    [_terminalFilter removeTarget:targetToRemove];
}

- (void)removeAllTargets
{
    [_terminalFilter removeAllTargets];
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)setInputSize:(CGSize)newSize
{
    for (MKGPUImageOutput<MKGPUImageInput> *currentFilter in _initialFilters) {
        [currentFilter setInputSize:newSize];
    }
}
- (void)setInputFramebuffer:(MKGPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex
{
    for (MKGPUImageOutput<MKGPUImageInput> *currentFilter in _initialFilters) {
        [currentFilter setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
    }
}

- (void)newFrameReadyIndex:(NSInteger)textureIndex
{
    for (MKGPUImageOutput<MKGPUImageInput> *currentFilter in _initialFilters) {
        if (currentFilter != self.inputFilterToIgnoreForUpdates)
        {
            [currentFilter newFrameReadyIndex:textureIndex];
        }
    }
}

@end
