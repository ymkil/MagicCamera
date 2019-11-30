//
//  MKSegmentMovieWriter.h
//  MagicCamera
//
//  Created by mkil on 2019/11/23.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MKGPUImageContext.h"

@protocol MKSegmentMovieWriterDelegate <NSObject>
- (void)didWriteMovieAtURL:(NSURL *_Nullable)outputURL;
@end

NS_ASSUME_NONNULL_BEGIN

@interface MKSegmentMovieWriter : NSObject

- (instancetype)initWithContext:(MKGPUImageContext *)context size:(CGSize)newSize videoSettings:(NSDictionary *)videoSettings audioSettings:(NSDictionary *)audioSettings;

- (void)startWriting;
- (void)stopWriting;

- (void)processVideoTextureId:(GLuint)inputTextureId AtRotationMode:(MKGPUImageRotationMode) inputRotation AtTime:(CMTime)frameTime;
- (void)processAudioBuffer:(CMSampleBufferRef)audioBuffer;

@property (weak, nonatomic) id<MKSegmentMovieWriterDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
