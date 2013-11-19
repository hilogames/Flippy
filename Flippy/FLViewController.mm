//
//  FLViewController.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLViewController.h"

#import "FLMyScene.h"

@implementation FLViewController

- (void)loadView
{
  SKView *skView = [[SKView alloc] init];
  skView.showsFPS = YES;
  skView.showsNodeCount = YES;
  self.view = skView;

  // noob: Initialize with empty size and use autolayout to fill screen?
  SKScene *scene = [FLMyScene sceneWithSize:[UIScreen mainScreen].bounds.size];
  scene.scaleMode = SKSceneScaleModeAspectFill;
  [skView presentScene:scene];
}

- (BOOL)shouldAutorotate
{
  return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
    return UIInterfaceOrientationMaskAllButUpsideDown;
  } else {
    return UIInterfaceOrientationMaskAll;
  }
}

@end
