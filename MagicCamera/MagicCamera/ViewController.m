//
//  ViewController.m
//  MagicCamera
//
//  Created by mkil on 2019/12/16.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "ViewController.h"
#import "MKShortVideoViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)startCamera:(id)sender {
    MKShortVideoViewController *camera = [[MKShortVideoViewController alloc] init];
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:camera] animated:true completion:nil];
}

@end
