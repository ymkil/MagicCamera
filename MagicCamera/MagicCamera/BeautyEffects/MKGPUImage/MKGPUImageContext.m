//
//  MKGPUImageContext.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageContext.h"

#import "MKGLProgram.h"
#import "MKGPUImageFramebuffer.h"

#define MAXSHADERPROGRAMSALLOWEDINCACHE 40

dispatch_queue_attr_t MKGPUImageDefaultQueueAttribute(void)
{
    if ([[[UIDevice currentDevice] systemVersion] compare:@"9.0" options:NSNumericSearch] != NSOrderedAscending)
    {
        return dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0);
    }
    return nil;
}

void runMSynchronouslyOnContextQueue(MKGPUImageContext *context, void (^block)(void))
{
    dispatch_queue_t videoProcessingQueue = [context contextQueue];
    if (videoProcessingQueue) {
        if (dispatch_get_specific([context contextKey]))
        {
            block();
        }else
        {
            dispatch_sync(videoProcessingQueue, block);
        }
    }else {
        block();
    }
}

@interface MKGPUImageContext()
{
    NSMutableDictionary *shaderProgramCache;
    EAGLSharegroup *_sharegroup;
    
    BOOL _newGLContext;
}

@end

@implementation MKGPUImageContext

@synthesize context = _context;
@synthesize contextQueue = _contextQueue;
@synthesize contextKey = _contextKey;
@synthesize coreVideoTextureCache = _coreVideoTextureCache;
@synthesize framebufferCache = _framebufferCache;

static int specificKey;

- (instancetype)init {
    @throw [NSException exceptionWithName:@"init Exception" reason:@"use initWithNewGLContext or initWithCurrentGLContext" userInfo:nil];
}

- (instancetype)initWithNewGLContext;
{
    self = [super init];
    if (self) {
        _contextQueue = dispatch_queue_create("com.Mkil.MKGPUImage", MKGPUImageDefaultQueueAttribute());
        
        CFStringRef specificValue = CFSTR("MKGPUImageQueue");
        dispatch_queue_set_specific(_contextQueue,
                                    &specificKey,
                                    (void*)specificValue,
                                    (dispatch_function_t)CFRelease);
        
        shaderProgramCache = [[NSMutableDictionary alloc] init];
        
        dispatch_sync(_contextQueue, ^{
            _context = [self createContext];
        });
    }
    return self;
}

- (instancetype)initWithCurrentGLContext
{
    self = [super init];
    if (self) {
        shaderProgramCache = [[NSMutableDictionary alloc] init];
        _context = [EAGLContext currentContext];
    }
    return self;
}

- (void *)contextKey {
    return &specificKey;
}

- (void)useAsCurrentContext;
{
    EAGLContext *imageProcessingContext = [self context];
    if ([EAGLContext currentContext] != imageProcessingContext)
    {
        [EAGLContext setCurrentContext:imageProcessingContext];
    }
}

- (void)presentBufferForDisplay;
{
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

- (MKGLProgram *)programForVertexShaderString:(NSString *)vertexShaderString fragmentShaderString:(NSString *)fragmentShaderString;
{
    NSString *lookupKeyForShaderProgram = [NSString stringWithFormat:@"V: %@ - F: %@", vertexShaderString, fragmentShaderString];
    MKGLProgram *programFromCache = [shaderProgramCache objectForKey:lookupKeyForShaderProgram];
    
    if (programFromCache == nil)
    {
        programFromCache = [[MKGLProgram alloc] initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];
        [shaderProgramCache setObject:programFromCache forKey:lookupKeyForShaderProgram];
    }
    
    return programFromCache;
}

- (void)useSharegroup:(EAGLSharegroup *)sharegroup;
{
    NSAssert(_context == nil, @"Unable to use a share group when the context has already been created. Call this method before you use the context for the first time.");
    
    _sharegroup = sharegroup;
}

- (EAGLContext *)createContext;
{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:_sharegroup];
    NSAssert(context != nil, @"Unable to create an OpenGL ES 2.0 context. The MKGPUImage framework requires OpenGL ES 2.0 support to work.");
    return context;
}

#pragma mark -
#pragma mark Manage fast texture upload

+ (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop
    
#endif
}

#pragma mark -
#pragma mark Accessors

- (CVOpenGLESTextureCacheRef)coreVideoTextureCache;
{
    if (_coreVideoTextureCache == NULL)
    {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [self context], NULL, &_coreVideoTextureCache);
        
        if (err)
        {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate %d", err);
        }
        
    }
    
    return _coreVideoTextureCache;
}

- (MKGPUImageFramebufferCache *)framebufferCache;
{
    if (_framebufferCache == nil)
    {
        _framebufferCache = [[MKGPUImageFramebufferCache alloc] initWithContext:self];
    }
    
    return _framebufferCache;
}

- (void)useImageProcessingContext;
{
    [self useAsCurrentContext];
}

- (GLint)maximumTextureSizeForThisDevice;
{
    static dispatch_once_t pred;
    static GLint maxTextureSize = 0;
    
    dispatch_once(&pred, ^{
        [self useImageProcessingContext];
        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    });
    
    return maxTextureSize;
}

- (CGSize)sizeThatFitsWithinATextureForSize:(CGSize)inputSize;
{
    GLint maxTextureSize = [self maximumTextureSizeForThisDevice];
    if ( (inputSize.width < maxTextureSize) && (inputSize.height < maxTextureSize) )
    {
        return inputSize;
    }
    
    CGSize adjustedSize;
    if (inputSize.width > inputSize.height)
    {
        adjustedSize.width = (CGFloat)maxTextureSize;
        adjustedSize.height = ((CGFloat)maxTextureSize / inputSize.width) * inputSize.height;
    }
    else
    {
        adjustedSize.height = (CGFloat)maxTextureSize;
        adjustedSize.width = ((CGFloat)maxTextureSize / inputSize.height) * inputSize.width;
    }
    
    return adjustedSize;
}

@end
