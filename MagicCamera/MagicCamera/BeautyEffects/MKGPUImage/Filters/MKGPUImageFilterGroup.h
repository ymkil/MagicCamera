//
//  MKGPUImageFilterGroup.h
//  MagicCamera
//
//  Created by mkil on 2019/11/11.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageOutput.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKGPUImageFilterGroup : MKGPUImageOutput <MKGPUImageInput>
{
    NSMutableArray *filters;
}

@property(readwrite, nonatomic, strong) MKGPUImageOutput<MKGPUImageInput> *terminalFilter;
@property(readwrite, nonatomic, strong) NSArray *initialFilters;
@property(readwrite, nonatomic, strong) MKGPUImageOutput<MKGPUImageInput> *inputFilterToIgnoreForUpdates;

// Filter management
- (void)addFilter:(MKGPUImageOutput<MKGPUImageInput> *)newFilter;
- (MKGPUImageOutput<MKGPUImageInput> *)filterAtIndex:(NSUInteger)filterIndex;
- (NSUInteger)filterCount;
@end

NS_ASSUME_NONNULL_END
