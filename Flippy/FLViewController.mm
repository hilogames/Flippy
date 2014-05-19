//
//  FLViewController.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLViewController.h"

#import "FLTrackScene.h"

static NSString * const FLExtraStateName = @"extra-application-state";
static NSString * FLExtraStatePath;

static const NSTimeInterval FLSceneTransitionDuration = 0.5;

@implementation FLViewController
{
  FLViewControllerScene _scene;
  HLMenuScene *_menuScene;
  FLTrackScene *_trackScene;
}

+ (void)initialize
{
  FLExtraStatePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
                      stringByAppendingPathComponent:[FLExtraStateName stringByAppendingPathExtension:@"archive"]];
}

- (id)init
{
  self = [super init];
  if (self) {
    self.restorationIdentifier = @"FLViewController";
    _scene = FLViewControllerSceneNone;
  }
  return self;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
  [super encodeRestorableStateWithCoder:coder];

  [coder encodeInt:(int)_scene forKey:@"scene"];

  // note: Calling encodeObject on either of these scenes doesn't work, perhaps because of a bug.  See:
  //
  //   http://stackoverflow.com/questions/23617405/why-is-encodewithcoder-not-getting-called-on-a-subclass-of-sknode-during-applica?noredirect=1#comment36287148_23617405
  //
  // As a workaround, we save state to a different file using our own archiver.  So, then, once the
  // problem with encodeObject is fixed: The menu scene definitely should just go into the application
  // state archive.  The track scene should also go there, unless we find it useful to have a auto-save
  // file available for crash recovery.
  NSMutableData *archiveData = [NSMutableData data];
  NSKeyedArchiver *extraCoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archiveData];
  if (_scene == FLViewControllerSceneTrack) {
    [extraCoder encodeObject:_trackScene forKey:@"trackScene"];
  } else if (_scene == FLViewControllerSceneMenu) {
    [extraCoder encodeObject:_menuScene forKey:@"menuScene"];
  }
  [extraCoder finishEncoding];
  [archiveData writeToFile:FLExtraStatePath atomically:NO];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
  [super decodeRestorableStateWithCoder:coder];

  FLViewControllerScene scene = (FLViewControllerScene)[coder decodeIntForKey:@"scene"];
  SKScene *restoredScene = nil;

  // note: We keep some extra application state in a separate file.  See comment in
  // encodeRestorableStateWithCoder.
  NSKeyedUnarchiver *extraCoder = nil;
  if ([[NSFileManager defaultManager] fileExistsAtPath:FLExtraStatePath]) {
    NSData *archiveData = [NSData dataWithContentsOfFile:FLExtraStatePath];
    extraCoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:archiveData];

    switch (scene) {
      case FLViewControllerSceneTrack: {
        FLTrackScene *trackScene = [extraCoder decodeObjectForKey:@"trackScene"];
        if (trackScene) {
          _trackScene = trackScene;
          _trackScene.delegate = self;
          restoredScene = trackScene;
        }
        break;
      }
      case FLViewControllerSceneMenu: {
        HLMenuScene *menuScene = [extraCoder decodeObjectForKey:@"menuScene"];
        if (menuScene) {
          _menuScene = menuScene;
          _menuScene.delegate = self;
          restoredScene = menuScene;
        }
        break;
      }
      case FLViewControllerSceneNone:
      default:
        // Do nothing.
        break;
    }
    
    [extraCoder finishDecoding];
  }

  if (restoredScene) {
    [self.skView presentScene:restoredScene];
    _scene = scene;
  } else {
    // note: A default menu scene is created at init.
    [self.skView presentScene:_menuScene];
    _scene = FLViewControllerSceneMenu;
  }
}

- (void)loadView
{
  SKView *skView = [[SKView alloc] init];
  //skView.showsFPS = YES;
  //skView.showsNodeCount = YES;
  //skView.showsDrawCount = YES;
  skView.ignoresSiblingOrder = YES;
  self.view = skView;

  // noob: This method is called during application state restoration after the view controller
  // has been returned from the application delegate, but before decodeRestorableStateWithCoder
  // is called.  But I only want to create the default _menuScene if it wasn't encoded, and I
  // only want to present the default _menuScene if no other current scene was encoded.  What's
  // the correct way to handle this?  I think in another app I added a notification center message
  // that informed anyone interested that decoding had finished; at that point, we can detect
  // whether a scene has been successfully decoded and/or presented, and react accordingly.  For
  // now, just keep this code short and sweet and it won't matter.
  [self FL_createMenuScene];
  [skView presentScene:_menuScene];
  _scene = FLViewControllerSceneMenu;
}

- (void)FL_createMenuScene
{
  _menuScene = [HLMenuScene sceneWithSize:[UIScreen mainScreen].bounds.size];
  _menuScene.delegate = self;
  _menuScene.scaleMode = SKSceneScaleModeResizeFill;
  _menuScene.backgroundImageName = @"grass";
  HLLabelButtonNode *buttonPrototype = [[HLLabelButtonNode alloc] initWithImageNamed:@"menu-button"];
  buttonPrototype.centerRect = CGRectMake(0.3333333f, 0.3333333f, 0.3333333f, 0.3333333f);
  buttonPrototype.fontName = @"Courier";
  buttonPrototype.fontSize = 24.0f;
  buttonPrototype.fontColor = [UIColor whiteColor];
  buttonPrototype.size = CGSizeMake(240.0f, 40.0f);
  buttonPrototype.verticalAlignmentMode = HLLabelButtonNodeVerticalAlignFontAscender;
  _menuScene.itemButtonPrototype = buttonPrototype;
  _menuScene.itemSoundFile = @"wooden-click-1.caf";
  
  [_menuScene.menu addItem:[HLMenuItem menuItemWithText:@"Challenge"]];
  [_menuScene.menu addItem:[HLMenu menuWithText:@"Sandbox"
                                          items:@[[HLMenuItem menuItemWithText:@"New"] ]]];
  [_menuScene.menu addItem:[HLMenuItem menuItemWithText:@"About"]];
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

#pragma mark -
#pragma mark HLMenuSceneDelegate

- (void)menuScene:(HLMenuScene *)menuScene didTapMenuItem:(HLMenuItem *)menuItem
{
  if ([[menuItem path] isEqualToString:@"Sandbox/New"]) {
    if (!_trackScene) {
      // TODO: Too slow.  Fade to black immediately to provide better feedback.
      // Maybe a "loading screen" scene, preloaded?  Or maybe a big UIView
      // over the SKView?  Or is there a simple way to pause the scene and disable all
      // interface, to create a modal SKSpriteNode overlay?
      // Note that in the eventual flow, there will first be a load/save
      // screen, but we'll have the same issue there.
      // TODO: Theeeeeennnnnn maybe look at what's taking so long.  But only as a
      // to-do.  Maybe test a big map on an older device.
      _trackScene = [FLTrackScene sceneWithSize:[UIScreen mainScreen].bounds.size];
      _trackScene.delegate = self;
      _trackScene.scaleMode = SKSceneScaleModeResizeFill;
    }
    _scene = FLViewControllerSceneTrack;
    [self.skView presentScene:_trackScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
  }
}

#pragma mark -
#pragma mark FLTrackSceneDelegate

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene
{
  _scene = FLViewControllerSceneMenu;
  [self.skView presentScene:_menuScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
}

@end
