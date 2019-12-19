//
//  MKGPUImageView.m
//  MagicCamera
//
//  Created by mkil on 2019/11/19.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageView.h"

#import "MKGLProgram.h"
#import "MKGPUImageFramebuffer.h"
#import "MKGPUImageFilter.h"
#import "MKGPUImagePicture.h"

@interface MKGPUImageView()
{
    MKGPUImageContext *myContext;
    
    MKGPUImageFramebuffer *inputFramebufferForDisplay;
    GLuint displayRenderbuffer, displayFramebuffer;
    
    MKGLProgram *displayProgram;
    GLuint textureId;
    
    GLint displayPositionAttribute, displayTextureCoordinateAttribute;
    GLint displayInputTextureUniform;
    
    CGSize inputImageSize;
    GLfloat imageVertices[8];
    
    GLfloat backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha;
}

@end

@implementation MKGPUImageView

@synthesize sizeInPixels = _sizeInPixels;

#pragma mark -
#pragma mark Initialization and teardown
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame]))
    {
        return nil;
    }
    
    [self commonInit];
    
    return self;
}

-(id)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super initWithCoder:coder]))
    {
        return nil;
    }
    
    [self commonInit];
    
    return self;
}

- (void)commonInit
{
     // Set scaling to account for Retina display
    if ([self respondsToSelector:@selector(setContentScaleFactor:)])
    {
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
    }
    
    inputRotation = kMKGPUImageNoRotation;
    
    self.opaque = YES;
    self.hidden = NO;
    
    CAEAGLLayer *eagLayer = (CAEAGLLayer *)self.layer;
    // CALayer 默认是透明的，必须将它设为不透明才能让其可见
    eagLayer.opaque = YES;
    // 设置描绘属性，在这里设置不维持渲染内容以及颜色格式为 RGBA8
    eagLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
  
    
    myContext = [[MKGPUImageContext alloc] initWithCurrentGLContext];
    if (myContext.context == nil) {
        myContext = [[MKGPUImageContext alloc] initWithNewGLContext];
    }
    
    runMSynchronouslyOnContextQueue(myContext, ^{
        [myContext useAsCurrentContext];
        displayProgram = [[MKGLProgram alloc] initWithVertexShaderString:kMKGPUImageVertexShaderString fragmentShaderString:kMKGPUImagePassthroughFragmentShaderString];
        
        if (![displayProgram link])
        {
            NSString *progLog = [displayProgram programLog];
            NSLog(@"Program link log: %@", progLog);
            NSString *fragLog = [displayProgram fragmentShaderLog];
            NSLog(@"Fragment shader compile log: %@", fragLog);
            NSString *vertLog = [displayProgram vertexShaderLog];
            NSLog(@"Vertex shader compile log: %@", vertLog);
            displayProgram = nil;
            NSAssert(NO, @"Filter shader link failed");
        }
        
        displayPositionAttribute = [displayProgram attributeIndex:@"position"];
        displayTextureCoordinateAttribute = [displayProgram attributeIndex:@"inputTextureCoordinate"];
        displayInputTextureUniform = [displayProgram uniformIndex:@"inputImageTexture"];
        
        [displayProgram use];
        [self setBackgroundColorRed:0.0 green:0.0 blue:0.0 alpha:1.0];
        [self createDisplayFramebuffer];
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];
    runMSynchronouslyOnContextQueue(myContext, ^{
        [self destoryRenderAndFrameBuffer];
        [self createDisplayFramebuffer];
//        [self render];
    });
}

- (void)destoryRenderAndFrameBuffer
{
//    当 UIView 在进行布局变化之后，由于 layer 的宽高变化，导致原来创建的 renderbuffer不再相符，我们需要销毁既有 renderbuffer 和 framebuffer。下面，我们依然创建私有方法 destoryRenderAndFrameBuffer 来销毁生成的 buffer
    [myContext useAsCurrentContext];
    if (displayFramebuffer)
    {
        glDeleteFramebuffers(1, &displayFramebuffer);
        displayFramebuffer = 0;
    }
    
    if (displayRenderbuffer)
    {
        glDeleteRenderbuffers(1, &displayRenderbuffer);
        displayRenderbuffer = 0;
    }
}

- (void)createDisplayFramebuffer
{
    [myContext useAsCurrentContext];
    glGenFramebuffers(1, &displayFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, displayFramebuffer);
    
    glGenRenderbuffers(1, &displayRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
    
    if (![myContext.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer])
    {
        NSLog(@"failed to call context");
    }

    GLint backingWidth, backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    if ( (backingWidth == 0) || (backingHeight == 0) )
    {
        [self destoryRenderAndFrameBuffer];
        return;
    }
    
    _sizeInPixels.width = (CGFloat)backingWidth;
    _sizeInPixels.height = (CGFloat)backingHeight;
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, displayRenderbuffer);
}

#pragma mark -
#pragma mark render

- (void)render
{
    [myContext useAsCurrentContext];
    [displayProgram use];
    
    glBindFramebuffer(GL_FRAMEBUFFER, displayFramebuffer);
    glViewport(0, 0, (GLint)_sizeInPixels.width, (GLint)_sizeInPixels.height);
    
    glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE6);
    glBindTexture(GL_TEXTURE_2D, textureId);
//    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glUniform1i(displayInputTextureUniform, 6);
        
    glEnableVertexAttribArray(displayPositionAttribute);
    glVertexAttribPointer(displayPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    
    glEnableVertexAttribArray(displayTextureCoordinateAttribute);
    glVertexAttribPointer(displayTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [MKGPUImageView textureCoordinatesForRotation:inputRotation]);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [myContext presentBufferForDisplay];
    if (inputFramebufferForDisplay != nil) {
        [inputFramebufferForDisplay unlock];
        inputFramebufferForDisplay = nil;
    }
}

#pragma mark -
#pragma mark Handling fill mode

- (void)recalculateViewGeometry;
{

    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat heightScaling, widthScaling;
        
        CGSize currentViewSize = self.bounds.size;
        
        //    CGFloat imageAspectRatio = inputImageSize.width / inputImageSize.height;
        //    CGFloat viewAspectRatio = currentViewSize.width / currentViewSize.height;
        
        CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(inputImageSize, self.bounds);
        
        switch(_fillMode)
        {
            case kMKGPUImageFillModeStretch:
            {
                widthScaling = 1.0;
                heightScaling = 1.0;
            }; break;
            case kMKGPUImageFillModePreserveAspectRatio:
            {
                widthScaling = insetRect.size.width / currentViewSize.width;
                heightScaling = insetRect.size.height / currentViewSize.height;
            }; break;
            case kMKGPUImageFillModePreserveAspectRatioAndFill:
            {
                //            CGFloat widthHolder = insetRect.size.width / currentViewSize.width;
                widthScaling = currentViewSize.height / insetRect.size.height;
                heightScaling = currentViewSize.width / insetRect.size.width;
            }; break;
        }
        
        imageVertices[0] = -widthScaling;
        imageVertices[1] = -heightScaling;
        imageVertices[2] = widthScaling;
        imageVertices[3] = -heightScaling;
        imageVertices[4] = -widthScaling;
        imageVertices[5] = heightScaling;
        imageVertices[6] = widthScaling;
        imageVertices[7] = heightScaling;
    });


    
    //    static const GLfloat imageVertices[] = {
    //        -1.0f, -1.0f,
    //        1.0f, -1.0f,
    //        -1.0f,  1.0f,
    //        1.0f,  1.0f,
    //    };
}

- (void)setBackgroundColorRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent alpha:(GLfloat)alphaComponent;
{
    backgroundColorRed = redComponent;
    backgroundColorGreen = greenComponent;
    backgroundColorBlue = blueComponent;
    backgroundColorAlpha = alphaComponent;
}

#pragma mark -
#pragma mark Rendering

+ (const GLfloat *)textureCoordinatesForRotation:(MKGPUImageRotationMode)rotationMode;
{
    // 注:纹理上下颠倒,这是因为OpenGL要求y轴0.0坐标是在图片的底部的，但是图片的y轴0.0坐标通常在顶部。
    // 解决1:glsl 里面 反转 y 轴(gl_Position = vec4(vPosition.x,-vPosition.y,vPosition.z,1.0))
    // 解决2:纹理坐标(s,t) -> (s,abs(t - 1))

    //    static const GLfloat noRotationTextureCoordinates[] = {
    //        0.0f, 0.0f,
    //        1.0f, 0.0f,
    //        0.0f, 1.0f,
    //        1.0f, 1.0f,
    //    };
    
    static const GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };

    static const GLfloat rotateLeftTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateRightTextureCoordinates[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat verticalFlipTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat horizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateRightVerticalFlipTextureCoordinates[] = {
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat rotateRightHorizontalFlipTextureCoordinates[] = {
        0.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat rotate180TextureCoordinates[] = {
        1.0f, 0.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
    };
    
    switch(rotationMode)
    {
        case kMKGPUImageNoRotation: return noRotationTextureCoordinates;
        case kMKGPUImageRotateLeft: return rotateLeftTextureCoordinates;
        case kMKGPUImageRotateRight: return rotateRightTextureCoordinates;
        case kMKGPUImageFlipVertical: return verticalFlipTextureCoordinates;
        case kMKGPUImageFlipHorizonal: return horizontalFlipTextureCoordinates;
        case kMKGPUImageRotateRightFlipVertical: return rotateRightVerticalFlipTextureCoordinates;
        case kMKGPUImageRotateRightFlipHorizontal: return rotateRightHorizontalFlipTextureCoordinates;
        case kMKGPUImageRotate180: return rotate180TextureCoordinates;
    }
}

#pragma mark -
#pragma mark renderTexture

- (void)renderTexture:(GLuint) inputTextureId inputSize:(CGSize)newSize rotateMode:(MKGPUImageRotationMode)rotation
{
    CGSize rotatedSize = newSize;
    if (MKGPUImageRotationSwapsWidthAndHeight(inputRotation))
    {
        rotatedSize.width = newSize.height;
        rotatedSize.height = newSize.width;
    }
    
    if (!CGSizeEqualToSize(inputImageSize, rotatedSize))
    {
        inputImageSize = rotatedSize;
        [self recalculateViewGeometry];
    }
    
    textureId = inputTextureId;
    inputRotation = rotation;
//    dispatch_sync(dispatch_get_main_queue(), ^{
        [self render];
//    });
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)setInputSize:(CGSize)newSize;
{
    
}

- (void)setInputFramebuffer:(MKGPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    inputFramebufferForDisplay = newInputFramebuffer;
    textureId = [inputFramebufferForDisplay texture];
    [inputFramebufferForDisplay lock];
}

- (void)newFrameReadyIndex:(NSInteger)textureIndex;
{
    [self render];
}

- (void)setFillMode:(MKGPUImageFillModeType)newValue;
{
    _fillMode = newValue;
    [self recalculateViewGeometry];
}

@end
