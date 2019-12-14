//
//  MKSegmentVideoAssetAdapter.m
//  MagicCamera
//
//  Created by mkil on 2019/12/7.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKSegmentVideoAssetAdapter.h"

@interface MKSegmentVideoAssetAdapter()
{
    NSArray* _fileURLs;
    AVMutableComposition *_composition;
}
@end

@implementation MKSegmentVideoAssetAdapter

-(instancetype)initWithURLs:(NSArray *)fileURLs {
    self = [super init];
    if (self) {
        _fileURLs = fileURLs;
        [self generateAsset];
    }
    return self;
}

- (void)generateAsset
{
    if (_fileURLs == nil) return;
    
    _composition = [AVMutableComposition composition];
    
    // Video Track
    AVMutableCompositionTrack *videoTrack = [_composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    // Audio Track
    AVMutableCompositionTrack *audioTrack = [_composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    
    CMTime cursorTime = kCMTimeZero;
    for (int i = 0; i < _fileURLs.count; i ++) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:_fileURLs[i] options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@(YES)}];
        
        CMTime duration = asset.duration;

        CMTimeRange timeRang = CMTimeRangeMake(cursorTime, duration);
        
        AVAssetTrack *segmentVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        AVAssetTrack *segmentAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        
        [videoTrack insertTimeRange:timeRang ofTrack:segmentVideoTrack atTime:cursorTime error:nil];
        [audioTrack insertTimeRange:timeRang ofTrack:segmentAudioTrack atTime:cursorTime error:nil];
        
        cursorTime = CMTimeAdd(cursorTime, duration);
    }
    
}

-(AVAsset *)asset
{
    
#ifdef DEBUG
    CMTimeShow(_composition.duration);
    float durationSeconds = CMTimeGetSeconds(_composition.duration);
    
    NSLog(@"duration = %f",durationSeconds);
#endif
    return _composition;
}

@end
