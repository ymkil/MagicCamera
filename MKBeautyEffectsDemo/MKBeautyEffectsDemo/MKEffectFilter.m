//
//  MKEffectFilter.m
//  MKBeautyEffectsDemo
//
//  Created by mkil on 2019/8/19.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKEffectFilter.h"
#import "MKEffectHandler.h"

@interface MKEffectFilter()

@property (nonatomic, strong) MKEffectHandler *effectHandler;

@end


@implementation MKEffectFilter

- (instancetype)init
{
    self = [super init];
    if (self) {
        runSynchronouslyOnVideoProcessingQueue(^{
            [GPUImageContext useImageProcessingContext];
            
            _effectHandler = [[MKEffectHandler alloc] initWithProcessTexture:YES];
        });
    }
    return self;
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;{
    
    //------------->绘制特效图像<--------------//
    [self.effectHandler setRotateMode:kMKGPUImageNoRotation];
    [self.effectHandler processWithTexture:firstInputFramebuffer.texture width:[self sizeOfFBO].width height:[self sizeOfFBO].height];
    
    glEnableVertexAttribArray(filterPositionAttribute);
    glEnableVertexAttribArray(filterTextureCoordinateAttribute);
    
    [filterProgram use];
    //------------->绘制特效图像<--------------//
    
    [super renderToTextureWithVertices:vertices textureCoordinates:textureCoordinates];
}

@end
