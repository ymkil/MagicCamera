//
//  MKGPUImageTrackOutput.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageTrackOutput.h"

#import "MKGLProgram.h"
#import "MKGPUImageFilter.h"
#import "MKGPUImageFramebuffer.h"

#import "MKLandmarkManager.h"

// 人脸检测 (采用Face++的试用版测试 https://www.faceplusplus.com/)
#import "MGFacepp.h"

// 检测最多人脸数
static int maxFaceCount = 1;

// 人脸大小 默认 100 低于 100*100像素的⼈人脸将不不会被检测到
static int faceSize = 100;

// 关键点个数 106/81
static int pointsNum = 106;

@interface MKGPUImageTrackOutput()
{
    MKGPUImageFramebuffer *firstInputFramebuffer;
    
    MKGLProgram *dataProgram;
    GLint dataPositionAttribute, dataTextureCoordinateAttribute;
    GLint dataInputTextureUniform;
    
    MKGPUImageFramebuffer *outputFramebuffer;
    
    void *_faceData;
    
    dispatch_queue_t _detectImageQueue;
}

@property (nonatomic, weak) MKGPUImageContext *context;
@property (nonatomic, assign) CGSize outputSize;

@property (nonatomic, strong) MGFacepp *markManager;

@end

@implementation MKGPUImageTrackOutput

- (instancetype)initWithContext:(MKGPUImageContext *)context{
    if (!(self = [super init])) {
        return nil;
    }
    
    _context = context;
    
    runMSynchronouslyOnContextQueue(context, ^{
        [context useAsCurrentContext];
        
        dataProgram = [context programForVertexShaderString:kMKGPUImageVertexShaderString fragmentShaderString:kMKGPUImagePassthroughFragmentShaderString];
        
        if (!dataProgram.initialized)
        {
            if (![dataProgram link])
            {
                NSString *progLog = [dataProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [dataProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [dataProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                dataProgram = nil;
            }
        }
        
        _detectImageQueue = dispatch_queue_create("com.Mkil.image.detect", DISPATCH_QUEUE_SERIAL);
        
        dataPositionAttribute = [dataProgram attributeIndex:@"position"];
        dataTextureCoordinateAttribute = [dataProgram attributeIndex:@"inputTextureCoordinate"];
        dataInputTextureUniform = [dataProgram uniformIndex:@"inputImageTexture"];
        
        [self faceInit];
    });
    
    return self;
}

#pragma mark -
#pragma mark Data access

- (void)renderAtInternalSize;
{
    [self.context useAsCurrentContext];
    [dataProgram use];
    
    outputFramebuffer = [[self.context framebufferCache] fetchFramebufferForSize:CGSizeMake(self.outputSize.width, self.outputSize.height) missCVPixelBuffer:NO];
    
    [outputFramebuffer activateFramebuffer];
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    static const GLfloat noRotationTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    glUniform1i(dataInputTextureUniform, 4);
    
    glVertexAttribPointer(dataPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(dataTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0,noRotationTextureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFinish();
    
    [firstInputFramebuffer unlock];

    //获取人脸数据
    [self detectImage:outputFramebuffer.image];
    [outputFramebuffer unlock];
    outputFramebuffer = nil;
}

#pragma mark -
#pragma mark Data Face

-(void)faceInit
{
    NSString *modelPath = [[NSBundle mainBundle] pathForResource:KMGFACEMODELNAME ofType:@""];
    NSData *modelData = [NSData dataWithContentsOfFile:modelPath];
    
    self.markManager = [[MGFacepp alloc] initWithModel:modelData
                                          maxFaceCount:maxFaceCount
                                         faceppSetting:^(MGFaceppConfig *config) {
                                             //                                                  config.minFaceSize = faceSize;
                                             //                                                  config.orientation = 90;
                                             
                                             /*    MGFppDetectionModeDetect; // 检测图⽚
                                              *    MGFppDetectionModeTrackingFast; // 检测视频流,速度较快
                                              *    MGFppDetectionModeTrackingRobustj; // //检测视频流,精度较⾼高,推荐
                                              */
                                             config.detectionMode = MGFppDetectionModeDetect;
                                             //                                                  /** 设置视频流格式，默认PixelFormatTypeRGBA ,注意要和你的视频流格式保持⼀一致*/
                                             //                                                  config.pixelFormatType = PixelFormatTypeRGBA;
                                         }];
}

- (void **)faceData {
    return &_faceData;
}

// 检测图片
-(void)detectImage:(UIImage *)image {
    if (self.markManager.status !=MGMarkWorking) {
        MKLandmarkManager.shareManager.detectionWidth = image.size.width;
        MKLandmarkManager.shareManager.detectionHeight = image.size.height;

//        dispatch_async(_detectImageQueue, ^{
            @autoreleasepool {
                MGImageData *imageData = [[MGImageData alloc] initWithImage:image];
                [self.markManager beginDetectionFrame];
        
                NSArray *faceArray = [self.markManager detectWithImageData:imageData];
                
                [self.markManager endDetectionFrame];
                [imageData releaseImageData];
                
                if (faceArray.count > 0) {
//                    NSLog(@"face count : %lu", (unsigned long)faceArray.count);
                    MGFaceInfo *faceInfo = faceArray[0];
                    [self.markManager GetGetLandmark:faceInfo isSmooth:YES pointsNumber:pointsNum];
//                    [self.markManager GetAttribute3D:faceInfo];
//                    NSLog(@"landmark - %@",faceInfo.points);
                }else{
//                    NSLog(@"no face detected");
                }

                MKLandmarkManager.shareManager.faceData = faceArray;
            }
//        });
    }
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)setInputSize:(CGSize)newSize {
    CGSize outputSize;
    outputSize.width = 176;
    outputSize.height = newSize.height * outputSize.width / newSize.width ;
    
    self.outputSize = outputSize;
}

- (void)setInputFramebuffer:(MKGPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex{
    firstInputFramebuffer = newInputFramebuffer;
    [firstInputFramebuffer lock];
}

- (void)newFrameReadyIndex:(NSInteger)textureIndex {
    runMSynchronouslyOnContextQueue(self.context, ^{
        [self.context useAsCurrentContext];
        
        [self renderAtInternalSize];
    });
}

@end
