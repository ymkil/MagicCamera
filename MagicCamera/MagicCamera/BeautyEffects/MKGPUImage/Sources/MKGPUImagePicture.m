//
//  MKGPUImagePicture.m
//  MagicCamera
//
//  Created by mkil on 2019/9/6.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImagePicture.h"

@implementation MKGPUImagePicture

- (id)initWithContext:(MKGPUImageContext *)context withImage:(UIImage *)newImageSource
{
//    if (!(self = [self initWithContext:context withImage:[newImageSource CGImage] smoothlyScaleOutput:NO])) {
//        return nil;
//    }
    return [self initWithContext:context withImage:[newImageSource CGImage] smoothlyScaleOutput:NO];
}

- (id)initWithContext:(MKGPUImageContext *)context withImage:(CGImageRef )newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput
{
    return [self initWithContext:context withImage:newImageSource smoothlyScaleOutput:smoothlyScaleOutput removePremultiplication:NO];
}

- (id)initWithContext:(MKGPUImageContext *)context withImage:(CGImageRef )newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput removePremultiplication:(BOOL)removePremultiplication;
{
    
    if (!(self = [super initWithContext:context]))
    {
        return nil;
    }
    self.context = context;
    
    hasProcessedImage = NO;
    self.shouldSmoothlyScaleOutput = smoothlyScaleOutput;
    imageUpdateSemaphore = dispatch_semaphore_create(0);
    dispatch_semaphore_signal(imageUpdateSemaphore);
    
    
    // TODO: Dispatch this whole thing asynchronously to move image loading off main thread
    CGFloat widthOfImage = CGImageGetWidth(newImageSource);
    CGFloat heightOfImage = CGImageGetHeight(newImageSource);
    
    // If passed an empty image reference, CGContextDrawImage will fail in future versions of the SDK.
    NSAssert( widthOfImage > 0 && heightOfImage > 0, @"Passed image must not be empty - it should be at least 1px tall and wide");
    
    pixelSizeOfImage = CGSizeMake(widthOfImage, heightOfImage);
    CGSize pixelSizeToUseForTexture = pixelSizeOfImage;
    
    BOOL shouldRedrawUsingCoreGraphics = NO;
    
    // For now, deal with images larger than the maximum texture size by resizing to be within that limit
    CGSize scaledImageSizeToFitOnGPU = [self.context sizeThatFitsWithinATextureForSize:pixelSizeOfImage];
    if (!CGSizeEqualToSize(scaledImageSizeToFitOnGPU, pixelSizeOfImage))
    {
        pixelSizeOfImage = scaledImageSizeToFitOnGPU;
        pixelSizeToUseForTexture = pixelSizeOfImage;
        shouldRedrawUsingCoreGraphics = YES;
    }
    
    if (self.shouldSmoothlyScaleOutput)
    {
        // In order to use mipmaps, you need to provide power-of-two textures, so convert to the next largest power of two and stretch to fill
        CGFloat powerClosestToWidth = ceil(log2(pixelSizeOfImage.width));
        CGFloat powerClosestToHeight = ceil(log2(pixelSizeOfImage.height));
        
        pixelSizeToUseForTexture = CGSizeMake(pow(2.0, powerClosestToWidth), pow(2.0, powerClosestToHeight));
        
        shouldRedrawUsingCoreGraphics = YES;
    }
    
    GLubyte *imageData = NULL;
    CFDataRef dataFromImageDataProvider = NULL;
    GLenum format = GL_BGRA;
    BOOL isLitteEndian = YES;
    BOOL alphaFirst = NO;
    BOOL premultiplied = NO;
    
    if (!shouldRedrawUsingCoreGraphics) {
        /* Check that the memory layout is compatible with GL, as we cannot use glPixelStore to
         * tell GL about the memory layout with GLES.
         */
        if (CGImageGetBytesPerRow(newImageSource) != CGImageGetWidth(newImageSource) * 4 ||
            CGImageGetBitsPerPixel(newImageSource) != 32 ||
            CGImageGetBitsPerComponent(newImageSource) != 8)
        {
            shouldRedrawUsingCoreGraphics = YES;
        } else {
            /* Check that the bitmap pixel format is compatible with GL */
            CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(newImageSource);
            if ((bitmapInfo & kCGBitmapFloatComponents) != 0) {
                /* We don't support float components for use directly in GL */
                shouldRedrawUsingCoreGraphics = YES;
            } else {
                CGBitmapInfo byteOrderInfo = bitmapInfo & kCGBitmapByteOrderMask;
                if (byteOrderInfo == kCGBitmapByteOrder32Little) {
                    /* Little endian, for alpha-first we can use this bitmap directly in GL */
                    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
                    if (alphaInfo != kCGImageAlphaPremultipliedFirst && alphaInfo != kCGImageAlphaFirst &&
                        alphaInfo != kCGImageAlphaNoneSkipFirst) {
                        shouldRedrawUsingCoreGraphics = YES;
                    }
                } else if (byteOrderInfo == kCGBitmapByteOrderDefault || byteOrderInfo == kCGBitmapByteOrder32Big) {
                    isLitteEndian = NO;
                    /* Big endian, for alpha-last we can use this bitmap directly in GL */
                    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
                    if (alphaInfo != kCGImageAlphaPremultipliedLast && alphaInfo != kCGImageAlphaLast &&
                        alphaInfo != kCGImageAlphaNoneSkipLast) {
                        shouldRedrawUsingCoreGraphics = YES;
                    } else {
                        /* Can access directly using GL_RGBA pixel format */
                        premultiplied = alphaInfo == kCGImageAlphaPremultipliedLast || alphaInfo == kCGImageAlphaPremultipliedLast;
                        alphaFirst = alphaInfo == kCGImageAlphaFirst || alphaInfo == kCGImageAlphaPremultipliedFirst;
                        format = GL_RGBA;
                    }
                }
            }
        }
    }
    
    //    CFAbsoluteTime elapsedTime, startTime = CFAbsoluteTimeGetCurrent();
    
    if (shouldRedrawUsingCoreGraphics)
    {
        // For resized or incompatible image: redraw
        imageData = (GLubyte *) calloc(1, (int)pixelSizeToUseForTexture.width * (int)pixelSizeToUseForTexture.height * 4);
        
        CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
        
        CGContextRef imageContext = CGBitmapContextCreate(imageData, (size_t)pixelSizeToUseForTexture.width, (size_t)pixelSizeToUseForTexture.height, 8, (size_t)pixelSizeToUseForTexture.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        //        CGContextSetBlendMode(imageContext, kCGBlendModeCopy); // From Technical Q&A QA1708: http://developer.apple.com/library/ios/#qa/qa1708/_index.html
        CGContextDrawImage(imageContext, CGRectMake(0.0, 0.0, pixelSizeToUseForTexture.width, pixelSizeToUseForTexture.height), newImageSource);
        CGContextRelease(imageContext);
        CGColorSpaceRelease(genericRGBColorspace);
        isLitteEndian = YES;
        alphaFirst = YES;
        premultiplied = YES;
    }
    else
    {
        // Access the raw image bytes directly
        dataFromImageDataProvider = CGDataProviderCopyData(CGImageGetDataProvider(newImageSource));
        imageData = (GLubyte *)CFDataGetBytePtr(dataFromImageDataProvider);
    }
    
    if (removePremultiplication && premultiplied) {
        NSUInteger    totalNumberOfPixels = round(pixelSizeToUseForTexture.width * pixelSizeToUseForTexture.height);
        uint32_t    *pixelP = (uint32_t *)imageData;
        uint32_t    pixel;
        CGFloat        srcR, srcG, srcB, srcA;
        
        for (NSUInteger idx=0; idx<totalNumberOfPixels; idx++, pixelP++) {
            pixel = isLitteEndian ? CFSwapInt32LittleToHost(*pixelP) : CFSwapInt32BigToHost(*pixelP);
            
            if (alphaFirst) {
                srcA = (CGFloat)((pixel & 0xff000000) >> 24) / 255.0f;
            }
            else {
                srcA = (CGFloat)(pixel & 0x000000ff) / 255.0f;
                pixel >>= 8;
            }
            
            srcR = (CGFloat)((pixel & 0x00ff0000) >> 16) / 255.0f;
            srcG = (CGFloat)((pixel & 0x0000ff00) >> 8) / 255.0f;
            srcB = (CGFloat)(pixel & 0x000000ff) / 255.0f;
            
            srcR /= srcA; srcG /= srcA; srcB /= srcA;
            
            pixel = (uint32_t)(srcR * 255.0) << 16;
            pixel |= (uint32_t)(srcG * 255.0) << 8;
            pixel |= (uint32_t)(srcB * 255.0);
            
            if (alphaFirst) {
                pixel |= (uint32_t)(srcA * 255.0) << 24;
            }
            else {
                pixel <<= 8;
                pixel |= (uint32_t)(srcA * 255.0);
            }
            *pixelP = isLitteEndian ? CFSwapInt32HostToLittle(pixel) : CFSwapInt32HostToBig(pixel);
        }
    }
    
  
    runMSynchronouslyOnContextQueue(self.context, ^{
        [self.context useAsCurrentContext];
        
        outputFramebuffer = [[self.context framebufferCache] fetchFramebufferForSize:pixelSizeToUseForTexture missCVPixelBuffer:YES];
        
        [outputFramebuffer activateFramebuffer];
        
        glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
        if (self.shouldSmoothlyScaleOutput)
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        }
        // no need to use self.outputTextureOptions here since pictures need this texture formats and type
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)pixelSizeToUseForTexture.width, (int)pixelSizeToUseForTexture.height, 0, format, GL_UNSIGNED_BYTE, imageData);
        
        if (self.shouldSmoothlyScaleOutput)
        {
            glGenerateMipmap(GL_TEXTURE_2D);
        }
        glBindTexture(GL_TEXTURE_2D, 0);
    });
    
    if (shouldRedrawUsingCoreGraphics)
    {
        free(imageData);
    }
    else
    {
        if (dataFromImageDataProvider)
        {
            CFRelease(dataFromImageDataProvider);
        }
    }
    
    return self;
}

- (void)dealloc
{
    [outputFramebuffer unlock];
#if !OS_OBJECT_USE_OBJC
    if (imageUpdateSemaphore != NULL)
    {
        dispatch_release(imageUpdateSemaphore);
    }
#endif
}

- (void)processImage
{
    [self processImageWithCompletionHandler:nil];
}

- (void)informTargetsAboutNewFrame;
{
    // Get all targets the framebuffer so they can grab a lock on it
    for (id<MKGPUImageInput> currentTarget in targets)
    {
        [currentTarget setInputSize:pixelSizeOfImage];
        NSInteger indexOfObject = [targets indexOfObject:currentTarget];
        [currentTarget setInputFramebuffer:outputFramebuffer atIndex:indexOfObject];
    }

    // Release our hold so it can return to the cache immediately upon processing
    [[self framebufferForOutput] unlock];

    [self removeOutputFramebuffer];

    // Trigger processing last, so that our unlock comes first in serial execution, avoiding the need for a callback
    for (id<MKGPUImageInput> currentTarget in targets)
    {
        NSInteger indexOfObject = [targets indexOfObject:currentTarget];
        [currentTarget newFrameReadyIndex:indexOfObject];
    }
}

- (BOOL)processImageWithCompletionHandler:(void (^)(void))completion
{
    hasProcessedImage = YES;
    
    if (dispatch_semaphore_wait(imageUpdateSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        return NO;
    }
    
    runMSynchronouslyOnContextQueue(self.context, ^{
        
        [self informTargetsAboutNewFrame];
        
        dispatch_semaphore_signal(imageUpdateSemaphore);
        
        if (completion != nil) {
            completion();
        }
    });
    
    return YES;
}

- (CGSize)outputImageSize;
{
    return pixelSizeOfImage;
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
    
    if (hasProcessedImage)
    {
        [newTarget setInputSize:pixelSizeOfImage];
        NSInteger indexOfObject = [targets indexOfObject:newTarget];
        [newTarget setInputFramebuffer:outputFramebuffer atIndex:indexOfObject];
    }
    
}


@end
