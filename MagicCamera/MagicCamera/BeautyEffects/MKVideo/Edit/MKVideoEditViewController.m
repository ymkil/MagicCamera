//
//  MKVideoEditViewController.m
//  MagicCamera
//
//  Created by mkil on 2019/12/7.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKVideoEditViewController.h"

@interface MKVideoEditViewController ()

@property(nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;

@end

@implementation MKVideoEditViewController

- (AVPlayer *)player {
    if (_player == nil) {
        
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:_assetAdapter.asset];
        
        _player = [AVPlayer playerWithPlayerItem:playerItem];
        _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
        [self.view.layer addSublayer:_playerLayer];
        _playerLayer.frame = self.view.bounds;
        _playerLayer.backgroundColor = [UIColor redColor].CGColor;
    }
    
    return _player;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    
    [self.player play];
}

@end
