//
//  FLViewController.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLViewController.h"

#import "FLTrackScene.h"

@implementation FLViewController

- (void)loadView
{
  SKView *skView = [[SKView alloc] init];
  skView.showsFPS = YES;
  skView.showsNodeCount = YES;
  skView.showsDrawCount = YES;
  skView.ignoresSiblingOrder = YES;
  self.view = skView;

  // noob: Initialize with empty size and use autolayout to fill screen?
  SKScene *scene = [FLTrackScene sceneWithSize:[UIScreen mainScreen].bounds.size];
  scene.scaleMode = SKSceneScaleModeResizeFill;
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
