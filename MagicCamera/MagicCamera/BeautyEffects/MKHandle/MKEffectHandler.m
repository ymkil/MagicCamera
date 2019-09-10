//
//  MKEffectHandler.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKEffectHandler.h"
#import "MKGPUImageTextureInput.h"
#import "MKGPUImageTextureOutput.h"

#import "MGFaceLicenseHandle.h"
#import "MKGPUImageTrackOutput.h"

#import "MKGPUImageKeyPointFilter.h"
#import "MKGPUImageLookupFilter.h"
#import "MKGPUImage2DTextTestFilter.h"



@interface MKEffectHandler()
{
    GLint bindingFrameBuffer;
    GLint bindingRenderBuffer;
    GLint viewPoint[4];
    NSMutableArray<NSNumber *>* vertexAttribEnableArray;
    NSInteger vertexAttribEnableArraySize;
}

@property (nonatomic, strong) MKGPUImageContext *glContext;
@property (nonatomic, strong) MKGPUImageTextureInput *textureInput;
@property (nonatomic, strong) MKGPUImageTextureOutput *textureOutput;

@property (nonatomic, strong) MKGPUImageFilter *commonInputFilter;
@property (nonatomic, strong) MKGPUImageFilter *commonOutputFilter;

@property (nonatomic, strong) MKGPUImageTrackOutput *trackOutput;

@property (nonatomic, strong) MKGPUImageKeyPointFilter *keyPointfilter;
@property (nonatomic, strong) MKGPUImageLookupFilter *lookupFilter;
@property (nonatomic, strong) MKGPUImage2DTextTestFilter *testFilter;

@property (nonatomic, assign) BOOL initCommonProcess;
@property (nonatomic, assign) BOOL initProcess;

@end

@implementation MKEffectHandler

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"init Exception" reason:@"use initWithProcessTexture:" userInfo:nil];
}

- (instancetype)initWithProcessTexture:(Boolean)isProcessTexture;
{
    self = [super init];
    if (self) {
        vertexAttribEnableArraySize = 5;
        vertexAttribEnableArray = [NSMutableArray array];
        
        if (isProcessTexture) {
            _glContext = [[MKGPUImageContext alloc] initWithCurrentGLContext];
        } else {
            _glContext = [[MKGPUImageContext alloc] initWithNewGLContext];
        }
        
        _textureInput = [[MKGPUImageTextureInput alloc] initWithContext:_glContext];
        _textureOutput = [[MKGPUImageTextureOutput alloc] initWithContext:_glContext];
        
        _commonInputFilter = [[MKGPUImageFilter alloc] initWithContext:_glContext];
        _commonOutputFilter = [[MKGPUImageFilter alloc] initWithContext:_glContext];

        _trackOutput = [[MKGPUImageTrackOutput alloc] initWithContext:_glContext];
        
        _keyPointfilter = [[MKGPUImageKeyPointFilter alloc] initWithContext:_glContext];
        _lookupFilter = [[MKGPUImageLookupFilter alloc] initWithContext:_glContext];
        _testFilter = [[MKGPUImage2DTextTestFilter alloc] initWithContext:_glContext];
    }
    return self;
}

- (void)setRotateMode:(MKGPUImageRotationMode)rotateMode{
    _rotateMode = rotateMode;
    
    self.textureInput.rotateMode = rotateMode;
    
    if (rotateMode == kMKGPUImageRotateLeft) {
        rotateMode = kMKGPUImageRotateRight;
    }else if (rotateMode == kMKGPUImageRotateRight) {
        rotateMode = kMKGPUImageRotateLeft;
    }
    
    self.textureOutput.rotateMode = rotateMode;
}

/**
 通用处理
 */
- (void)commonProcess {
    if (!self.initCommonProcess) {
        
        NSMutableArray *filterChainArray = [NSMutableArray array];
    
        [filterChainArray addObject:self.keyPointfilter];
        [filterChainArray addObject:self.lookupFilter];
        [filterChainArray addObject:self.testFilter];
        
        if (![MGFaceLicenseHandle getLicense]) {
            [self.commonInputFilter addTarget:self.trackOutput];
        }
        
        if (filterChainArray.count > 0) {
            [self.commonInputFilter addTarget:[filterChainArray firstObject]];
            
            for (int x = 0; x < filterChainArray.count - 1; x++) {
                [filterChainArray[x] addTarget:filterChainArray[x+1]];
            }
            
            [[filterChainArray lastObject] addTarget:self.commonOutputFilter];
            
        }else {
            [self.textureInput addTarget:self.commonOutputFilter];
        }
        
        self.initCommonProcess = YES;
    }
}

- (void)processWithTexture:(GLuint)texture width:(GLint)width height:(GLint)height{
    
    [self saveOpenGLState];
    
    [self commonProcess];
//
    if (!self.initProcess) {
        [self.textureInput addTarget:self.commonInputFilter];
        [self.commonOutputFilter addTarget:self.textureOutput];
        self.initProcess = YES;
    }
    
    // 设置输出的Filter
    [self.textureOutput setOutputWithBGRATexture:texture width:width height:height];
//
//    // 设置输入的Filter, 同时开始处理纹理数据
    [self.textureInput processWithBGRATexture:texture width:width height:height];
    
    [self restoreOpenGLState];
}

/**
 保存opengl状态
 */
- (void)saveOpenGLState {
    // 获取当前绑定的FrameBuffer
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, (GLint *)&bindingFrameBuffer);
    
    // 获取当前绑定的RenderBuffer
    glGetIntegerv(GL_RENDERBUFFER_BINDING, (GLint *)&bindingRenderBuffer);
    
    // 获取viewpoint
    glGetIntegerv(GL_VIEWPORT, (GLint *)&viewPoint);
    
    // 获取顶点数据
    [vertexAttribEnableArray removeAllObjects];
    for (int x = 0 ; x < vertexAttribEnableArraySize; x++) {
        GLint vertexAttribEnable;
        glGetVertexAttribiv(x, GL_VERTEX_ATTRIB_ARRAY_ENABLED, &vertexAttribEnable);
        if (vertexAttribEnable) {
            [vertexAttribEnableArray addObject:@(x)];
        }
    }
}

/**
 恢复opengl状态
 */
- (void)restoreOpenGLState {
    // 还原当前绑定的FrameBuffer
    glBindFramebuffer(GL_FRAMEBUFFER, bindingFrameBuffer);
    
    // 还原当前绑定的RenderBuffer
    glBindRenderbuffer(GL_RENDERBUFFER, bindingRenderBuffer);
    
    // 还原viewpoint
    glViewport(viewPoint[0], viewPoint[1], viewPoint[2], viewPoint[3]);
    
    // 还原顶点数据
    for (int x = 0 ; x < vertexAttribEnableArray.count; x++) {
        glEnableVertexAttribArray(vertexAttribEnableArray[x].intValue);
    }
}

- (void)destroy{
    self.textureInput = NULL;
    self.textureOutput = NULL;
    self.commonInputFilter = NULL;
    self.commonOutputFilter = NULL;

    self.glContext = NULL;
}

- (void)dealloc{
    [self destroy];
}

#pragma mark -
#pragma mark handle

-(void)setFilterModel:(MKFilterModel *)filterModel
{
    _filterModel = filterModel;
    
    if (filterModel.type == MKFilterTypeStyle) {
        _lookupFilter.lookup = [UIImage imageWithContentsOfFile:filterModel.image];
    }

}

-(void)setIntensity:(CGFloat)intensity
{
    if (_filterModel.type == MKFilterTypeStyle) {
        _lookupFilter.intensity = intensity;
    }
}


@end
