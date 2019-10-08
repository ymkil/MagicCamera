//
//  MKCameraFilterView.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKCameraFilterView.h"
#import "MKFilterModel.h"
#import "MKHeader.h"

#define kCameraFilterViewItemSize                 60
#define kCameraFilterCollectionViewHeight         100


@interface MKFilterCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *iconImV;
@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, strong) MKFilterModel *model;

@end

@implementation MKFilterCell

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self setUI];
        self.layer.cornerRadius = 22.0f;
        self.layer.masksToBounds = YES;
    }
    
    return self;
}

- (void)setUI
{
    _iconImV = [[UIImageView alloc] init];
    _iconImV.frame = CGRectMake(0, 0, kCameraFilterViewItemSize, kCameraFilterViewItemSize);
    _iconImV.contentMode = UIViewContentModeScaleToFill;
    [self.contentView addSubview:_iconImV];
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.frame = CGRectMake(0, kCameraFilterViewItemSize - 18, kCameraFilterViewItemSize, 18);
    _titleLabel.font = [UIFont systemFontOfSize:10];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.backgroundColor = [UIColor colorWithRed:8/255.0 green:157/255.0 blue:184/255.0 alpha:0.6f];
    [self.contentView addSubview:_titleLabel];
    self.contentView.backgroundColor = [UIColor colorWithRed:104/255.0 green:98/255.0 blue:98/255.0 alpha:0.5];
}

- (void)setModel:(MKFilterModel *)model
{
    _model = model;
    
    if (model) {
        _titleLabel.text = model.name;
        _iconImV.image = [UIImage imageWithContentsOfFile:model.icon];
    }
}


@end

@interface MKCameraFilterView()<UICollectionViewDelegate,UICollectionViewDataSource>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *sliderLabel;

@end

@implementation MKCameraFilterView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setHidden:YES];
        self.alpha = 0;
        [self buildCollectionView];
    }
    
    return self;
}

- (UICollectionViewFlowLayout *)collectionViewForFlowLayout
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(kCameraFilterViewItemSize, kCameraFilterViewItemSize);
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 5;
    layout.sectionInset = UIEdgeInsetsMake(5, 5, 0, 5);
    return layout;
}

- (void)buildCollectionView
{
    UICollectionViewFlowLayout *layout = [self collectionViewForFlowLayout];
    UICollectionView *collectionView = [[UICollectionView alloc]initWithFrame:CGRectMake(0, 30, self.frame.size.width, kCameraFilterViewItemSize) collectionViewLayout:layout];
    [collectionView setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.3f]];
    collectionView.delegate = self;
    collectionView.dataSource = self;
    collectionView.scrollsToTop = NO;
    collectionView.showsVerticalScrollIndicator = NO;
    collectionView.showsHorizontalScrollIndicator = NO;
    collectionView.backgroundColor = [UIColor clearColor];
    [collectionView registerClass:[MKFilterCell class] forCellWithReuseIdentifier:@"MKFilterCell"];
    [self addSubview:collectionView];
    _collectionView = collectionView;
}

- (void)toggleSliderView
{
    if (!self.slider) {
        self.slider = [[UISlider alloc] initWithFrame:CGRectMake(30, 0, kScreenW-60, 30)];
        self.slider.hidden = YES;
        self.slider.tintColor = [UIColor colorWithRed:8/255.0 green:157/255.0 blue:184/255.0 alpha:1.0];
        self.slider.maximumTrackTintColor = [UIColor whiteColor];
        [self.slider addTarget:self action:@selector(sliderClick:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:self.slider];
        
        self.sliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.slider.frame.origin.x+self.slider.value*(kScreenW-90)-8, self.slider.frame.origin.y-30, 40, 30)];
        self.sliderLabel.textAlignment = NSTextAlignmentCenter;
        self.sliderLabel.font = [UIFont systemFontOfSize:22];
        self.sliderLabel.textColor = [UIColor whiteColor];
        self.sliderLabel.text = [NSString stringWithFormat:@"%.0f", floor(self.slider.value*100)];
        [self addSubview:self.sliderLabel];
    }
    
    self.slider.alpha = 1.0f;
    self.sliderLabel.alpha = 1.0f;
    self.slider.hidden = !self.slider.hidden;
    self.sliderLabel.hidden = self.slider.hidden;
}

#pragma mark - PublicMethod

- (void)reloadData
{
    [_collectionView reloadData];
}

- (void)toggle
{
    if (self.hidden) {
        [self show];
    }else {
        [self hide];
    }
}

- (void)show
{
    if (!self.hidden) {
        return;
    }
    
//    if (_filterWillShowBlock) {
//        _filterWillShowBlock();
//    }
    self.hidden = NO;

    [UIView animateWithDuration:0.4f animations:^{
        self.alpha = 1;
    } completion:^(BOOL finished) {
//        [_collectionView scrollToItemAtIndexPath:_lastSelectedIndexPath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
//        [self selectConllectionViewAtIndex:_lastSelectedIndexPath];
    }];
    [_collectionView reloadData];
}

- (BOOL)hide
{
    if (self.hidden) {
        return NO;
    }
    
//    if (_filterWillHideBlock) {
//        _filterWillHideBlock();
//    }

    [UIView animateWithDuration:0.4f animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        self.hidden = YES;
//        self.slider.hidden = YES;
//        self.sliderLabel.hidden = self.slider.hidden;
    }];
    
    return YES;
}

//slider的事件
-(void)sliderClick:(UISlider *)sender{
    self.sliderLabel.text = [NSString stringWithFormat:@"%.0f", floor(sender.value*100)];
    _changeIntensityValueBlock(sender.value);
}

#pragma mark - UICollectionViewDataSource && UICollectionViewDelegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return _filterModels.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    MKFilterCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MKFilterCell" forIndexPath:indexPath];
    cell.model = _filterModels[indexPath.row];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    self.selectFilterModelBlock(_filterModels[indexPath.row]);
    
    [self toggleSliderView];
}


@end


