//
//  MKSegmentMovieWriter.m
//  MagicCamera
//
//  Created by mkil on 2019/11/23.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKSegmentMovieWriter.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "MKGLProgram.h"
#import "MKGPUImageFilter.h"

static const NSString *fileType = @"mov";

NSString *const kMKGPUImageColorSwizzlingFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate).bgra;
 }
 );

@interface MKSegmentMovieWriter()
{
    MKGPUImageContext *myContext;
    GLuint movieFramebuffer, movieRenderbuffer;
    
    MKGLProgram *colorSwizzlingProgram;
    GLint colorSwizzlingPositionAttribute, colorSwizzlingTextureCoordinateAttribute;
    GLint colorSwizzlingInputTextureUniform;
    
    CGSize videoSize;
    
    CVPixelBufferRef renderTarget;
    CVOpenGLESTextureRef renderTexture;
}

@property (strong, nonatomic) AVAssetWriter *assetWriter;
@property (strong, nonatomic) AVAssetWriterInput *assetWriterVideoInput;
@property (strong, nonatomic) AVAssetWriterInput *assetWriterAudioInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *assetWriterInputPixelBufferAdaptor;

@property (strong, nonatomic) NSDictionary *videoSettings;
@property (strong, nonatomic) NSDictionary *audioSettings;

@property (nonatomic) BOOL firstSample;
@property (nonatomic) BOOL isWriting;

@property (nonatomic, strong) NSFileManager *fileManager;

@end

@implementation MKSegmentMovieWriter


- (instancetype)initWithContext:(MKGPUImageContext *)context size:(CGSize)newSize videoSettings:(NSDictionary *)videoSettings audioSettings:(NSDictionary *)audioSettings {
    self = [super init];
    if (self) {
        
        myContext = context;
        videoSize = newSize;
        
        _videoSettings = videoSettings;
        _audioSettings = audioSettings;
        _firstSample = YES;
        
        _fileManager = [NSFileManager defaultManager];
        
        runMSynchronouslyOnContextQueue(myContext, ^{
            [myContext useAsCurrentContext];
            
            if ([MKGPUImageContext supportsFastTextureUpload])
            {
                colorSwizzlingProgram = [myContext programForVertexShaderString:kMKGPUImageVertexShaderString fragmentShaderString:kMKGPUImagePassthroughFragmentShaderString];
            }
            else
            {
                colorSwizzlingProgram = [myContext programForVertexShaderString:kMKGPUImageVertexShaderString fragmentShaderString:kMKGPUImageColorSwizzlingFragmentShaderString];
            }
            
            if (![colorSwizzlingProgram link])
            {
                NSString *progLog = [colorSwizzlingProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [colorSwizzlingProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [colorSwizzlingProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                colorSwizzlingProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
            
            colorSwizzlingPositionAttribute = [colorSwizzlingProgram attributeIndex:@"position"];
            colorSwizzlingTextureCoordinateAttribute = [colorSwizzlingProgram attributeIndex:@"inputTextureCoordinate"];
            colorSwizzlingInputTextureUniform = [colorSwizzlingProgram uniformIndex:@"inputImageTexture"];
            
            [colorSwizzlingProgram use];
            
            glEnableVertexAttribArray(colorSwizzlingPositionAttribute);
            glEnableVertexAttribArray(colorSwizzlingTextureCoordinateAttribute);
        });
        
    }
    
    return self;
}

- (void)dealloc
{
    // 删除临时文件
    [self deleteTempVideoFile];
}

- (void)startWriting {

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSError *error = nil;

        NSString *fileType = AVFileTypeQuickTimeMovie;
        self.assetWriter = [AVAssetWriter assetWriterWithURL:[self outputURL]
                                                    fileType:fileType
                                                       error:&error];
        
        if (!self.assetWriter || error) {
            NSString *formatString = @"Could not create AVAssetWriter: %@";
            NSLog(@"%@", [NSString stringWithFormat:formatString, error]);
            return;
        }
        
        // use default output settings if none specified
        if (_videoSettings == nil) {
            NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
            [settings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
            [settings setObject:[NSNumber numberWithInt:videoSize.width] forKey:AVVideoWidthKey];
            [settings setObject:[NSNumber numberWithInt:videoSize.height] forKey:AVVideoHeightKey];
            _videoSettings = settings;
        } else {    // custom output settings specified
            __unused NSString *videoCodec = [_videoSettings objectForKey:AVVideoCodecKey];
            __unused NSNumber *width = [_videoSettings objectForKey:AVVideoWidthKey];
            __unused NSNumber *height = [_videoSettings objectForKey:AVVideoHeightKey];
            
            NSAssert(videoCodec && width && height, @"OutputSettings is missing required parameters.");
            
            if( [_videoSettings objectForKey:@"EncodingLiveVideo"] ) {
                NSMutableDictionary *tmp = [_videoSettings mutableCopy];
                [tmp removeObjectForKey:@"EncodingLiveVideo"];
                _videoSettings = tmp;
            }
        }
        
        self.assetWriterVideoInput =  [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                                     outputSettings:self.videoSettings];
        self.assetWriterVideoInput.expectsMediaDataInRealTime = YES;
        
        NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                                               [NSNumber numberWithInt:videoSize.width], kCVPixelBufferWidthKey,
                                                               [NSNumber numberWithInt:videoSize.height], kCVPixelBufferHeightKey,
                                                               nil];
        self.assetWriterInputPixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.assetWriterVideoInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
        
        if ([self.assetWriter canAddInput:self.assetWriterVideoInput]) {
            [self.assetWriter addInput:self.assetWriterVideoInput];
        } else {
            NSLog(@"Unable to add video input.");
            return;
        }
        
        self.assetWriterAudioInput =
        [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio
                                       outputSettings:self.audioSettings];
        
        self.assetWriterAudioInput.expectsMediaDataInRealTime = YES;
        
        if ([self.assetWriter canAddInput:self.assetWriterAudioInput]) {
            [self.assetWriter addInput:self.assetWriterAudioInput];
        } else {
            NSLog(@"Unable to add audio input.");
        }
        
        runMSynchronouslyOnContextQueue(myContext, ^{
            [self.assetWriter startWriting];
        });
        self.isWriting = YES;
        self.firstSample = YES;
    });
}

- (void)processAudioBuffer:(CMSampleBufferRef)audioBuffer
{
    runMSynchronouslyOnContextQueue(myContext, ^{
        if (!self.isWriting) {
            return;
        }
    
        if (self.firstSample) {
            CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(audioBuffer);
            [self.assetWriter startSessionAtSourceTime:currentTime];
            self.firstSample = NO;
        }
        
        if (self.assetWriterAudioInput.isReadyForMoreMediaData) {
            if (self.assetWriter.status == AVAssetWriterStatusWriting) {
                if (![self.assetWriterAudioInput appendSampleBuffer:audioBuffer]) {
                    NSLog(@"Error appending audio sample buffer.");
                }
            }
        }
        
    });
}

- (void)processVideoTextureId:(GLuint)inputTextureId AtRotationMode:(MKGPUImageRotationMode) inputRotation AtTime:(CMTime)frameTime
{
    glFinish();
    runMSynchronouslyOnContextQueue(myContext, ^{
        
        if (!self.isWriting) {
            return;
        }
        
        if (self.firstSample) {
            [self.assetWriter startSessionAtSourceTime:frameTime];
            self.firstSample = NO;
        }
        
        if (!_assetWriterVideoInput.readyForMoreMediaData)
        {
            NSLog(@"1: Had to drop a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            return;
        }
        
        [myContext useAsCurrentContext];
        [self renderAtInternalSizeUsingTexture:inputTextureId AtRotationMode:inputRotation];
        
        CVPixelBufferRef pixel_buffer = NULL;
        
        if ([MKGPUImageContext supportsFastTextureUpload])
        {
            pixel_buffer = renderTarget;
            CVPixelBufferLockBaseAddress(pixel_buffer, 0);
        } else {
            CVReturn status = CVPixelBufferPoolCreatePixelBuffer (NULL, [_assetWriterInputPixelBufferAdaptor pixelBufferPool], &pixel_buffer);
            if ((pixel_buffer == NULL) || (status != kCVReturnSuccess))
            {
                CVPixelBufferRelease(pixel_buffer);
                return;
            }
            else
            {
                CVPixelBufferLockBaseAddress(pixel_buffer, 0);
                
                GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
                glReadPixels(0, 0, videoSize.width, videoSize.height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
            }
        }
        
        void(^write)(void) = ^() {
            while( ! _assetWriterVideoInput.readyForMoreMediaData) {
                NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
                //            NSLog(@"video waiting...");
                [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
            }
            if (!_assetWriterVideoInput.readyForMoreMediaData)
            {
                NSLog(@"2: Had to drop a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            }
            else if(self.assetWriter.status == AVAssetWriterStatusWriting)
            {
                if (![_assetWriterInputPixelBufferAdaptor appendPixelBuffer:pixel_buffer withPresentationTime:frameTime])
                    NSLog(@"Problem appending pixel buffer at time: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            }
            else
            {
                NSLog(@"Couldn't write a frame");
                //NSLog(@"Wrote a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            }
            CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
            
            
            if (![MKGPUImageContext supportsFastTextureUpload])
            {
                CVPixelBufferRelease(pixel_buffer);
            }
        };
        
        write();
    });
}

- (void)stopWriting {
    self.isWriting = NO;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.assetWriter finishWritingWithCompletionHandler:^{
            
            if (self.assetWriter.status == AVAssetWriterStatusCompleted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSURL *fileURL = [self.assetWriter outputURL];
                    [self.delegate didWriteMovieAtURL:fileURL];
                    NSLog(@"fileURL = %@", fileURL);
                });
            } else {
                NSLog(@"Failed to write movie: %@", self.assetWriter.error);
            }
        }];
    });
}

- (void)setFilterFBO;
{
    if (!movieFramebuffer)
    {
        [self createDataFBO];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, movieFramebuffer);
    
    glViewport(0, 0, (int)videoSize.width, (int)videoSize.height);
}

- (void)renderAtInternalSizeUsingTexture:(GLuint)texture AtRotationMode:(MKGPUImageRotationMode) inputRotation
{
    [myContext useAsCurrentContext];
    [self setFilterFBO];
    
    [colorSwizzlingProgram use];
    
    glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // This needs to be flipped to write out to video correctly
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };

    const GLfloat *textureCoordinates = [MKGPUImageFilter textureCoordinatesForRotation:inputRotation];
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, texture);
    glUniform1i(colorSwizzlingInputTextureUniform, 4);
    
    //    NSLog(@"Movie writer framebuffer: %@", inputFramebufferToUse);
    
    glVertexAttribPointer(colorSwizzlingPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(colorSwizzlingTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFinish();
}

#pragma mark -
#pragma mark Frame rendering
- (void)createDataFBO
{
    glActiveTexture(GL_TEXTURE1);
    glGenFramebuffers(1, &movieFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, movieFramebuffer);
    
    if ([MKGPUImageContext supportsFastTextureUpload])
    {
        // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/
        
        
        CVPixelBufferPoolCreatePixelBuffer (NULL, [_assetWriterInputPixelBufferAdaptor pixelBufferPool], &renderTarget);
        
        /* AVAssetWriter will use BT.601 conversion matrix for RGB to YCbCr conversion
         * regardless of the kCVImageBufferYCbCrMatrixKey value.
         * Tagging the resulting video file as BT.601, is the best option right now.
         * Creating a proper BT.709 video is not possible at the moment.
         */
        CVBufferSetAttachment(renderTarget, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
        CVBufferSetAttachment(renderTarget, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVAttachmentMode_ShouldPropagate);
        CVBufferSetAttachment(renderTarget, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
        
        CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, [myContext coreVideoTextureCache], renderTarget,
                                                      NULL, // texture attributes
                                                      GL_TEXTURE_2D,
                                                      GL_RGBA, // opengl format
                                                      (int)videoSize.width,
                                                      (int)videoSize.height,
                                                      GL_BGRA, // native iOS format
                                                      GL_UNSIGNED_BYTE,
                                                      0,
                                                      &renderTexture);
        
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
    }
    else
    {
        glGenRenderbuffers(1, &movieRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, movieRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, (int)videoSize.width, (int)videoSize.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, movieRenderbuffer);
    }
    
    
    __unused GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);
}

#pragma mark -
#pragma mark File deal
- (NSURL *)outputURL {
    NSString * docsdir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * segmentMoviePath = [docsdir stringByAppendingPathComponent:@"SegmentMovie"];
    
    BOOL isSegmentDir = NO;
    BOOL existed = [_fileManager fileExistsAtPath:segmentMoviePath isDirectory:&isSegmentDir];
    
    if (!(isSegmentDir == YES && existed == YES) ) {
        [_fileManager createDirectoryAtPath:segmentMoviePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *filePath = [segmentMoviePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",[self getCurrentDate],fileType]];
    NSURL *url = [NSURL fileURLWithPath:filePath];

    return url;
}

- (void)deleteTempVideoFile
{
    NSString * docsdir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * segmentMoviePath = [docsdir stringByAppendingPathComponent:@"SegmentMovie"];
    
    if ([_fileManager fileExistsAtPath:segmentMoviePath]) {
        NSArray *contents = [_fileManager contentsOfDirectoryAtPath:segmentMoviePath error:nil];
        NSEnumerator *e = [contents objectEnumerator];
        NSString *fileName;
        while ((fileName = [e nextObject])) {
            if ([[fileName pathExtension] isEqualToString:fileType]) {
                NSLog(@"delect filename = %@",[segmentMoviePath stringByAppendingPathComponent:fileName]);
                [_fileManager removeItemAtPath:[segmentMoviePath stringByAppendingPathComponent:fileName] error:nil];
            }
        }
    }
}
/**
 获取时间
 
 @return 返回日期，用日期命名
 */
- (NSString *)getCurrentDate {
    //用日期做为视频文件名称
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    return dateStr;
}

@end

