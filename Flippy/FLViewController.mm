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
{
  FLTrackScene *_trackScene;
}

- (id)init
{
  self = [super init];
  if (self) {
    self.restorationIdentifier = @"FLViewController";
  }
  return self;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
  [super encodeRestorableStateWithCoder:coder];
  [_trackScene save:@"current"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
  [super decodeRestorableStateWithCoder:coder];
  FLTrackScene *trackScene = [FLTrackScene load:@"current"];
  if (trackScene) {
    _trackScene = trackScene;
    SKView *skView = (SKView *)self.view;
    [skView presentScene:_trackScene];
  }
}

- (void)loadView
{
  NSLog(@"FLViewController loadView");

  SKView *skView = [[SKView alloc] init];
  skView.showsFPS = YES;
  skView.showsNodeCount = YES;
  skView.showsDrawCount = YES;
  skView.ignoresSiblingOrder = YES;
  self.view = skView;

  // noob: Initialize with empty size and use autolayout to fill screen?
  _trackScene = [FLTrackScene sceneWithSize:[UIScreen mainScreen].bounds.size];
  _trackScene.scaleMode = SKSceneScaleModeResizeFill;
  [skView presentScene:_trackScene];
}

- (SKView *)skView
{
  return (SKView *)self.view;
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
