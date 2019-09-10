//
//  MKGPUImageOutput.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageOutput.h"

@implementation MKGPUImageOutput

@synthesize shouldSmoothlyScaleOutput = _shouldSmoothlyScaleOutput;
@synthesize outputTextureOptions = _outputTextureOptions;

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithContext:(MKGPUImageContext *)context;
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    targets = [[NSMutableArray alloc] init];
    
    // set default texture options
    _outputTextureOptions.minFilter = GL_LINEAR;
    _outputTextureOptions.magFilter = GL_LINEAR;
    _outputTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    _outputTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    _outputTextureOptions.internalFormat = GL_RGBA;
    _outputTextureOptions.format = GL_BGRA;
    _outputTextureOptions.type = GL_UNSIGNED_BYTE;
    
    self.context = context;
    
    return self;
}

- (void)dealloc
{
    [self removeAllTargets];
}

#pragma mark -
#pragma mark Managing targets

- (MKGPUImageFramebuffer *)framebufferForOutput;
{
    return outputFramebuffer;
}

- (void)removeOutputFramebuffer;
{
    outputFramebuffer = nil;
}

- (NSArray*)targets;
{
    return [NSArray arrayWithArray:targets];
}

- (void)addTarget:(id<MKGPUImageInput>)newTarget;
{
    if([targets containsObject:newTarget])
    {
        return;
    }
    
    runMSynchronouslyOnContextQueue(self.context, ^{
        [targets addObject:newTarget];
    });
}

- (void)removeTarget:(id<MKGPUImageInput>)targetToRemove;
{
    if(![targets containsObject:targetToRemove])
    {
        return;
    }
    
    runMSynchronouslyOnContextQueue(self.context, ^{
        [targets removeObject:targetToRemove];
    });
}

- (void)removeAllTargets;
{
    runMSynchronouslyOnContextQueue(self.context, ^{
        [targets removeAllObjects];
    });
}

@end
