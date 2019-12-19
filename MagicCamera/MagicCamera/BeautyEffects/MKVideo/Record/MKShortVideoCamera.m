//
//  MKShortVideoCamera.m
//  MagicCamera
//
//  Created by mkil on 2019/11/18.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKShortVideoCamera.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import "MKGPUImageFramebuffer.h"
#import "MKGPUImageColorConversion.h"
#import "MKGPUImageFilter.h"

#import "GPUImageContext.h"

#import "MKSegmentMovieWriter.h"

#import <AssetsLibrary/AssetsLibrary.h>

@interface MKShortVideoCamera() <MKSegmentMovieWriterDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
{
    GLuint textureId;
    
    MKGLProgram *yuvConversionProgram;
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
    
    int imageBufferWidth, imageBufferHeight;
    
    GLuint luminanceTexture, chrominanceTexture;
    
    const GLfloat *_preferredConversion;
    
    BOOL isFullYUVRange;
    
    MKGPUImageRotationMode outputRotation, internalRotation;
    
    dispatch_semaphore_t frameRenderingSemaphore;
}

@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;

@property (strong, nonatomic) MKGPUImageContext *myContext;

@property (nonatomic, strong) MKGPUImageFramebuffer *outputFramebuffer;

@property (nonatomic, strong) MKSegmentMovieWriter *segmentMovieWriter;

@end

@implementation MKShortVideoCamera

- (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition size:(CGSize)newSize
{
    if (!(self = [super initWithSessionPreset:sessionPreset cameraPosition:cameraPosition]))
    {
        return nil;
    }

    _myContext = [[MKGPUImageContext alloc] initWithCurrentGLContext];
    if (_myContext.context == nil) {
        _myContext = [[MKGPUImageContext alloc] initWithNewGLContext];
    }
    
    outputRotation = kMKGPUImageNoRotation;
    internalRotation = kMKGPUImageNoRotation;

    frameRenderingSemaphore = dispatch_semaphore_create(1);
    
    runMSynchronouslyOnContextQueue(_myContext, ^{
        [_myContext useAsCurrentContext];
        
        if (isFullYUVRange)
        {
            yuvConversionProgram = [_myContext programForVertexShaderString:kMKGPUImageVertexShaderString fragmentShaderString:kMKGPUImageYUVFullRangeConversionForLAFragmentShaderString];
        }
        else
        {
            yuvConversionProgram = [_myContext programForVertexShaderString:kMKGPUImageVertexShaderString fragmentShaderString:kMKGPUImageYUVVideoRangeConversionForLAFragmentShaderString];
        }
        
        if (![yuvConversionProgram link])
        {
            NSString *progLog = [yuvConversionProgram programLog];
            NSLog(@"Program link log: %@", progLog);
            NSString *fragLog = [yuvConversionProgram fragmentShaderLog];
            NSLog(@"Fragment shader compile log: %@", fragLog);
            NSString *vertLog = [yuvConversionProgram vertexShaderLog];
            NSLog(@"Vertex shader compile log: %@", vertLog);
            yuvConversionProgram = nil;
            NSAssert(NO, @"Filter shader link failed");
        }
        
        yuvConversionPositionAttribute = [yuvConversionProgram attributeIndex:@"position"];
        yuvConversionTextureCoordinateAttribute = [yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
        yuvConversionLuminanceTextureUniform = [yuvConversionProgram uniformIndex:@"luminanceTexture"];
        yuvConversionChrominanceTextureUniform = [yuvConversionProgram uniformIndex:@"chrominanceTexture"];
        yuvConversionMatrixUniform = [yuvConversionProgram uniformIndex:@"colorConversionMatrix"];
        
        [yuvConversionProgram use];
    });
    
    NSError *error;
    if (![self setupSessionOutputs:&error size:newSize]) {
        NSLog(@"Error: %@", [error localizedDescription]);
    }

    return self;
}

- (BOOL)setupSessionOutputs:(NSError **)error size:(CGSize)newSize {
    [self.captureSession beginConfiguration];
    
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    
    _preferredConversion = kMKColorConversion709;
    
    if ([MKGPUImageContext supportsFastTextureUpload]) {
        
        BOOL supportsFullYUVRange = NO;
        NSArray *supportedPixelFormats = self.videoDataOutput.availableVideoCVPixelFormatTypes;
        for (NSNumber *currentPixelFormat in supportedPixelFormats)
        {
            if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            {
                supportsFullYUVRange = YES;
            }
        }
        
        if (supportsFullYUVRange)
        {
            [self.videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            isFullYUVRange = YES;
        }
        else
        {
            [self.videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            isFullYUVRange = NO;
        }
    } else {
        [self.videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }

    [self.videoDataOutput setSampleBufferDelegate:self
                                            queue:self.cameraProcessingQueue];
    
    if ([self.captureSession canAddOutput:self.videoDataOutput]) {
        [self.captureSession addOutput:self.videoDataOutput];
    } else {
        return NO;
    }
    [self.captureSession commitConfiguration];
    
    [self addAudioInputsAndOutputs];
    
    NSString *fileType = AVFileTypeQuickTimeMovie;

//    NSDictionary *videoSettings =
//    [self.videoDataOutput
//     recommendedVideoSettingsForAssetWriterWithOutputFileType:fileType];

    NSDictionary *audioSettings =
    [self.audioDataOutput
     recommendedAudioSettingsForAssetWriterWithOutputFileType:fileType];

    _segmentMovieWriter = [[MKSegmentMovieWriter alloc] initWithContext:_myContext size:newSize videoSettings:nil audioSettings:audioSettings];
    _segmentMovieWriter.delegate = self;
    
    return YES;
}

- (BOOL)addAudioInputsAndOutputs
{
    [self addAudioInputs];
    
    if (self.audioDataOutput)
        return NO;
    
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    [self.audioDataOutput setSampleBufferDelegate:self
                                            queue:self.audioProcessingQueue];
    
    if ([self.captureSession canAddOutput:self.audioDataOutput]) {
        [self.captureSession addOutput:self.audioDataOutput];
    } else {
        return NO;
    }
    
    return YES;
}

- (BOOL)removeAudioInputsAndOutputs
{
    [self removeAudioInputs];
    [self.captureSession beginConfiguration];
    [self.captureSession removeOutput:self.audioDataOutput];
    self.audioDataOutput = nil;
    [self.captureSession commitConfiguration];
    return YES;
}

#pragma mark - Delegate methods
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (captureOutput == self.videoDataOutput) {
        if (dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0)
        {
            return;
        }
        
        CFRetain(sampleBuffer);
        runMSynchronouslyOnContextQueue(_myContext, ^{
            [self processVideoSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
            dispatch_semaphore_signal(frameRenderingSemaphore);
        });
    } else {
        
        [_segmentMovieWriter processAudioBuffer:sampleBuffer];
        
    }
}

#pragma mark -
#pragma mark Manage the camera video stream

- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    int bufferWidth = (int) CVPixelBufferGetWidth(pixelBuffer);
    int bufferHeight = (int) CVPixelBufferGetHeight(pixelBuffer);

    CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    
    if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
        if (isFullYUVRange) {
            _preferredConversion = kMKColorConversion601FullRange;
        }
        else {
            _preferredConversion = kMKColorConversion601;
        }
    }
    else {
        _preferredConversion = kMKColorConversion709;
    }
    
    [_myContext useAsCurrentContext];
    
    if ([MKGPUImageContext supportsFastTextureUpload]) {
        
        if (CVPixelBufferGetPlaneCount(pixelBuffer) > 0) { // Check for YUV planar inputs to do RGB conversion
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            
            CVOpenGLESTextureRef _luminanceTextureRef;
            CVOpenGLESTextureRef _chrominanceTextureRef;
            
            if ( (imageBufferWidth != bufferWidth) && (imageBufferHeight != bufferHeight) )
            {
                imageBufferWidth = bufferWidth;
                imageBufferHeight = bufferHeight;
            }
            
            CVReturn err;
            
            // Y-plane
            glActiveTexture(GL_TEXTURE4);
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [_myContext coreVideoTextureCache], pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &_luminanceTextureRef);
            
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }
            
            luminanceTexture = CVOpenGLESTextureGetName(_luminanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, luminanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
            // UV-plane
            glActiveTexture(GL_TEXTURE5);
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [_myContext coreVideoTextureCache], pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &_chrominanceTextureRef);
            
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }
            
            chrominanceTexture = CVOpenGLESTextureGetName(_chrominanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
            [self convertYUVToRGBOutput];
            
            if (MKGPUImageRotationSwapsWidthAndHeight(internalRotation))
            {
                imageBufferWidth = bufferHeight;
                imageBufferHeight = bufferWidth;
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CFRelease(_luminanceTextureRef);
            CFRelease(_chrominanceTextureRef);
            textureId = [_outputFramebuffer texture];
        }
    
    } else {
        
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        int bytesPerRow = (int) CVPixelBufferGetBytesPerRow(pixelBuffer);
        MKGPUTextureOptions options;
        options.minFilter = GL_LINEAR;
        options.magFilter = GL_LINEAR;
        options.wrapS = GL_CLAMP_TO_EDGE;
        options.wrapT = GL_CLAMP_TO_EDGE;
        options.internalFormat = GL_RGBA;
        options.format = GL_BGRA;
        options.type = GL_UNSIGNED_BYTE;

        _outputFramebuffer = [[_myContext framebufferCache] fetchFramebufferForSize:CGSizeMake(bytesPerRow/4, bufferHeight) textureOptions:options missCVPixelBuffer:YES];
        [_outputFramebuffer activateFramebuffer];

        glBindTexture(GL_TEXTURE_2D, [_outputFramebuffer texture]);

        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bytesPerRow / 4, bufferHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(pixelBuffer));
        textureId = [_outputFramebuffer texture];

        imageBufferWidth = bytesPerRow / 4;
        imageBufferHeight = bufferHeight;
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    
    int rotatedImageBufferWidth = bufferWidth, rotatedImageBufferHeight = bufferHeight;
    if (GPUImageRotationSwapsWidthAndHeight(internalRotation))
    {
        rotatedImageBufferWidth = bufferHeight;
        rotatedImageBufferHeight = bufferWidth;
    }
    
    runMSynchronouslyOnContextQueue(_myContext, ^{
        if ([self.delegate respondsToSelector:@selector(effectsProcessingTexture:inputSize:rotateMode:)]) {
            [self.delegate effectsProcessingTexture:textureId inputSize:CGSizeMake(imageBufferWidth, imageBufferHeight) rotateMode:outputRotation];
        }
    });

    if ([self.delegate respondsToSelector:@selector(renderTexture:inputSize:rotateMode:)]) {
        [self.delegate renderTexture:textureId inputSize:CGSizeMake(rotatedImageBufferWidth, rotatedImageBufferHeight) rotateMode:outputRotation];
    }
    
    [_segmentMovieWriter processVideoTextureId:textureId AtRotationMode:outputRotation AtTime:currentTime];
    
    [_outputFramebuffer unlock];
    _outputFramebuffer = nil;
}

- (void)convertYUVToRGBOutput;
{
    [_myContext useAsCurrentContext];
    [yuvConversionProgram use];
    
    int rotatedImageBufferWidth = imageBufferWidth, rotatedImageBufferHeight = imageBufferHeight;
    
    if (MKGPUImageRotationSwapsWidthAndHeight(internalRotation))
    {
        rotatedImageBufferWidth = imageBufferHeight;
        rotatedImageBufferHeight = imageBufferWidth;
    }
    
    MKGPUTextureOptions options;
    options.minFilter = GL_LINEAR;
    options.magFilter = GL_LINEAR;
    options.wrapS = GL_CLAMP_TO_EDGE;
    options.wrapT = GL_CLAMP_TO_EDGE;
    options.internalFormat = GL_RGBA;
    options.format = GL_BGRA;
    options.type = GL_UNSIGNED_BYTE;
    
    
    _outputFramebuffer = [[_myContext framebufferCache] fetchFramebufferForSize:CGSizeMake(rotatedImageBufferWidth, rotatedImageBufferHeight) textureOptions:options missCVPixelBuffer:YES];
    [_outputFramebuffer activateFramebuffer];
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glUniform1i(yuvConversionLuminanceTextureUniform, 4);
    
    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glUniform1i(yuvConversionChrominanceTextureUniform, 5);
    
    glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);
    
    glVertexAttribPointer(yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [MKGPUImageFilter textureCoordinatesForRotation:internalRotation]);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)updateOrientation
{
    runMSynchronouslyOnContextQueue(_myContext, ^{
        
        if ([MKGPUImageContext supportsFastTextureUpload])
        {
            outputRotation = kMKGPUImageNoRotation;
            if ([self cameraPosition] == AVCaptureDevicePositionBack)
            {
                if (_horizontallyMirrorRearFacingCamera)
                {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:internalRotation = kMKGPUImageRotateRightFlipVertical; break;
                        case UIInterfaceOrientationPortraitUpsideDown:internalRotation = kMKGPUImageRotate180; break;
                        case UIInterfaceOrientationLandscapeLeft:internalRotation = kMKGPUImageFlipHorizonal; break;
                        case UIInterfaceOrientationLandscapeRight:internalRotation = kMKGPUImageFlipVertical; break;
                        default:internalRotation = kMKGPUImageNoRotation;
                    }
                } else {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:internalRotation = kMKGPUImageRotateRight; break;
                        case UIInterfaceOrientationPortraitUpsideDown:internalRotation = kMKGPUImageRotateLeft; break;
                        case UIInterfaceOrientationLandscapeLeft:internalRotation = kMKGPUImageRotate180; break;
                        case UIInterfaceOrientationLandscapeRight:internalRotation = kMKGPUImageNoRotation; break;
                        default:internalRotation = kMKGPUImageNoRotation;
                    }
                }
            } else {
                if (_horizontallyMirrorFrontFacingCamera)
                {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:internalRotation = kMKGPUImageRotateRightFlipVertical; break;
                        case UIInterfaceOrientationPortraitUpsideDown:internalRotation = kMKGPUImageRotateRightFlipHorizontal; break;
                        case UIInterfaceOrientationLandscapeLeft:internalRotation = kMKGPUImageFlipHorizonal; break;
                        case UIInterfaceOrientationLandscapeRight:internalRotation = kMKGPUImageFlipVertical; break;
                        default:internalRotation = kMKGPUImageNoRotation;
                    }
                } else {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:internalRotation = kMKGPUImageRotateRight; break;
                        case UIInterfaceOrientationPortraitUpsideDown:internalRotation = kMKGPUImageRotateLeft; break;
                        case UIInterfaceOrientationLandscapeLeft:internalRotation = kMKGPUImageNoRotation; break;
                        case UIInterfaceOrientationLandscapeRight:internalRotation = kMKGPUImageRotate180; break;
                        default:internalRotation = kMKGPUImageNoRotation;
                    }
                }
            }
        } else {
            if ([self cameraPosition] == AVCaptureDevicePositionBack)
            {
                if (_horizontallyMirrorRearFacingCamera) {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:outputRotation = kMKGPUImageRotateRightFlipVertical; break;
                        case UIInterfaceOrientationPortraitUpsideDown:outputRotation = kMKGPUImageRotate180; break;
                        case UIInterfaceOrientationLandscapeLeft:outputRotation = kMKGPUImageFlipHorizonal; break;
                        case UIInterfaceOrientationLandscapeRight:outputRotation = kMKGPUImageFlipVertical; break;
                        default:outputRotation = kMKGPUImageNoRotation;
                    }
                } else {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:outputRotation = kMKGPUImageRotateRight; break;
                        case UIInterfaceOrientationPortraitUpsideDown:outputRotation = kMKGPUImageRotateLeft; break;
                        case UIInterfaceOrientationLandscapeLeft:outputRotation = kMKGPUImageRotate180; break;
                        case UIInterfaceOrientationLandscapeRight:outputRotation = kMKGPUImageNoRotation; break;
                        default:outputRotation = kMKGPUImageNoRotation;
                    }
                }
            } else {
                if (_horizontallyMirrorFrontFacingCamera) {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:outputRotation = kMKGPUImageRotateRightFlipVertical; break;
                        case UIInterfaceOrientationPortraitUpsideDown:outputRotation = kMKGPUImageRotateRightFlipHorizontal; break;
                        case UIInterfaceOrientationLandscapeLeft:outputRotation = kMKGPUImageFlipHorizonal; break;
                        case UIInterfaceOrientationLandscapeRight:outputRotation = kMKGPUImageFlipVertical; break;
                        default:outputRotation = kMKGPUImageNoRotation;
                    }
                } else {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:outputRotation = kMKGPUImageRotateRight; break;
                        case UIInterfaceOrientationPortraitUpsideDown:outputRotation = kMKGPUImageRotateLeft; break;
                        case UIInterfaceOrientationLandscapeLeft:outputRotation = kMKGPUImageNoRotation; break;
                        case UIInterfaceOrientationLandscapeRight:outputRotation = kMKGPUImageRotate180; break;
                        default:outputRotation = kMKGPUImageNoRotation;
                    }
                }
            }
        }
    });
}

- (void)rotateCamera
{
    [super rotateCamera];
    [self setOutputImageOrientation:_outputImageOrientation];
}


- (void)setOutputImageOrientation:(UIInterfaceOrientation)newValue
{
    _outputImageOrientation = newValue;
    [self updateOrientation];
}

- (void)setHorizontallyMirrorFrontFacingCamera:(BOOL)newValue
{
    _horizontallyMirrorFrontFacingCamera = newValue;
    [self updateOrientation];
}

- (void)setHorizontallyMirrorRearFacingCamera:(BOOL)newValue
{
    _horizontallyMirrorRearFacingCamera = newValue;
    [self updateOrientation];
}


#pragma mark -
#pragma mark operate manage

- (void)startWriting
{
    [self.segmentMovieWriter startWriting];
}
- (void)stopWriting
{
    [self.segmentMovieWriter stopWriting];
}

- (void)didWriteMovieAtURL:(NSURL *)outputURL {
    [self.delegate didWriteMovieAtURL:outputURL];
    
//    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
//    
//    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputURL]) {
//        
//        ALAssetsLibraryWriteVideoCompletionBlock completionBlock;
//        
//        completionBlock = ^(NSURL *assetURL, NSError *error){
//            if (error) {
//                //                [self.delegate assetLibraryWriteFailedWithError:error];
//            }
//        };
//        
//        [library writeVideoAtPathToSavedPhotosAlbum:outputURL
//                                    completionBlock:completionBlock];
//    }
}

- (void)dealloc
{
    [self stopSession];
//    [videoOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
//    [audioOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
//
//    [self removeInputsAndOutputs];
    
    // ARC forbids explicit message send of 'release'; since iOS 6 even for dispatch_release() calls: stripping it out in that case is required.
#if !OS_OBJECT_USE_OBJC
    if (frameRenderingSemaphore != NULL)
    {
        dispatch_release(frameRenderingSemaphore);
    }
#endif
}

@end
