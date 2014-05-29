//
//  FLViewController.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLViewController.h"

#import "FLTrackScene.h"

typedef enum FLViewControllerScene { FLViewControllerSceneNone, FLViewControllerSceneMenu, FLViewControllerSceneTrack } FLViewControllerScene;

static NSString * const FLExtraStateName = @"extra-application-state";
static NSString * FLExtraStatePath;

static const NSTimeInterval FLSceneTransitionDuration = 0.5;

void
FLError(NSString *message)
{
  // TODO: Use CocoaLumberjack for non-critical error logging.
  NSLog(@"ERROR: %@", message);
}

@implementation FLViewController
{
  SKScene *_currentScene;

  SKScene *_loadingScene;
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
  }
  return self;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
  [super encodeRestorableStateWithCoder:coder];

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
  if (_currentScene == _menuScene) {
    [extraCoder encodeObject:_menuScene forKey:@"menuScene"];
  }
  if (_trackScene) {
    [extraCoder encodeObject:_trackScene forKey:@"trackScene"];
  }
  [extraCoder finishEncoding];
  [archiveData writeToFile:FLExtraStatePath atomically:NO];

  // note: Don't try to archive _currentScene as a pointer, since the scene objects
  // aren't archived alongside.  Instead, archive a code.
  FLViewControllerScene currentScene = FLViewControllerSceneNone;
  if (_currentScene == _menuScene) {
    currentScene = FLViewControllerSceneMenu;
  } else if (_currentScene == _trackScene) {
    currentScene = FLViewControllerSceneTrack;
  }
  [coder encodeInt:(int)currentScene forKey:@"currentScene"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
  [super decodeRestorableStateWithCoder:coder];

  // note: We keep some extra application state in a separate file.  See comment in
  // encodeRestorableStateWithCoder.
  NSKeyedUnarchiver *extraCoder = nil;
  if ([[NSFileManager defaultManager] fileExistsAtPath:FLExtraStatePath]) {
    NSData *archiveData = [NSData dataWithContentsOfFile:FLExtraStatePath];
    extraCoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:archiveData];
    // noob: As things stand, the track assets must be loaded before the track scene
    // can be decoded.  It might be better if instead the track could be decoded
    // fully but have its visual state only restored later, for instance when it is
    // about to be added to the view.
    if ([extraCoder containsValueForKey:@"trackScene"]) {
      [FLTrackScene loadSceneAssets];
    }
    _trackScene = [extraCoder decodeObjectForKey:@"trackScene"];
    if (_trackScene) {
      _trackScene.delegate = self;
    }
    _menuScene = [extraCoder decodeObjectForKey:@"menuScene"];
    if (_menuScene) {
      _menuScene.menuNode.delegate = self;
    }
    [extraCoder finishDecoding];
  }

  FLViewControllerScene currentScene = (FLViewControllerScene)[coder decodeIntForKey:@"currentScene"];
  switch (currentScene) {
    case FLViewControllerSceneMenu:
      if (!_menuScene) {
        FLError(@"FLViewController decodeRestorableStateWithCoder: Failed to decode restorable state for menu scene.");
      }
      _currentScene = _menuScene;
      break;
    case FLViewControllerSceneTrack:
      if (!_trackScene) {
        FLError(@"FLViewController decodeRestorableStateWithCoder: Failed to decode restorable state for track scene.");
      }
      _currentScene = _trackScene;
      break;
    case FLViewControllerSceneNone:
      if (_menuScene) {
        FLError(@"FLViewController decodeRestorableStateWithCoder: Decoded menu scene, but current scene unset.");
        _currentScene = _menuScene;
      } else if (_trackScene) {
        FLError(@"FLViewController decodeRestorableStateWithCoder: Decoded track scene, but current scene unset.");
        _currentScene = _trackScene;
      } else {
        _currentScene = nil;
      }
      break;
    default:
      [NSException raise:@"FLViewControllerUnknownScene" format:@"Unrecognized scene code %d during decoding view controller.", currentScene];
      break;
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
}

- (void)viewWillAppear:(BOOL)animated
{
  // note: loadView creates as little as possible; decodeRestorableStateWithCoder
  // may or may not fill things out a little bit.  So here, then we're in one of
  // three possible states:
  //
  //   1) View was previously hidden and is now about to appear again.  This
  //      state shouldn't exist; an exception is added to viewWillDisappear to
  //      check the assumption.
  //
  //   2) View is about to appear for the first time after application decoded
  //      restorable state.  In this case, present the state if it's presentable.
  //
  //   3) View is brand new and bare from loadView.  In that case -- or in case
  //      the restorable state from (2) wasn't sufficient for a presentation --
  //      create a default starting scene (that is, a menu).
  
  if (!_currentScene) {
    if (!_menuScene) {
      [self FL_createMenuScene];
    }
    _currentScene = _menuScene;
    HLMenu *mainMenu = (HLMenu *)[_menuScene.menuNode.menu itemForPathComponents:@[ @"Main" ]];
    [_menuScene.menuNode navigateToMenu:mainMenu animation:HLMenuNodeAnimationNone];
  }

  // note: No loading of track assets, or showing loading screens.  If the track was
  // decoded from application state, then the assets were already loaded.  If not,
  // then we don't expect _currentScene to be _trackScene.
  
  // noob: This logic for loading track scene assets seems messy and distributed.
  // Check it with an assertion, but think about ways to improve it.  (For one thing,
  // maybe we should have a notification for applicationDidFinishLoading, so that
  // we can separate out concerns about application restorable state from what happens
  // when the view appears.
  if (_trackScene && _currentScene == _trackScene && ![FLTrackScene sceneAssetsLoaded]) {
    [NSException raise:@"FLViewControllerBadState" format:@"Method viewWillAppear assumes that track view would not be current without having assets already loaded."];
  }

  // note: No transition for now, even if loading the app for the first time.
  [self.skView presentScene:_currentScene];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [NSException raise:@"FLViewControllerBadState" format:@"Method viewWillAppear assumes that the view never disappears."];
}

- (void)FL_createLoadingScene
{
  _loadingScene = [SKScene sceneWithSize:[UIScreen mainScreen].bounds.size];
  _loadingScene.scaleMode = SKSceneScaleModeResizeFill;
  _loadingScene.anchorPoint = CGPointMake(0.5f, 0.5f);

  const NSTimeInterval FLLoadingPulseDuration = 0.5;
  SKLabelNode *loadingLabelNode = [SKLabelNode labelNodeWithFontNamed:@"Courier"];
  loadingLabelNode.text = @"Loading...";
  SKAction *pulse = [SKAction sequence:@[ [SKAction fadeAlphaTo:0.5f duration:FLLoadingPulseDuration],
                                          [SKAction fadeAlphaTo:1.0f duration:FLLoadingPulseDuration] ]];
  pulse.timingMode = SKActionTimingEaseInEaseOut;
  [loadingLabelNode runAction:[SKAction repeatActionForever:pulse]];
  [_loadingScene addChild: loadingLabelNode];
}

- (void)FL_createMenuScene
{
  _menuScene = [HLMenuScene sceneWithSize:[UIScreen mainScreen].bounds.size];
  _menuScene.scaleMode = SKSceneScaleModeResizeFill;

  SKSpriteNode *backgroundNode = [SKSpriteNode spriteNodeWithImageNamed:@"grass"];
  _menuScene.backgroundNode = backgroundNode;

  HLMenuNode *menuNode = [[HLMenuNode alloc] init];
  _menuScene.menuNode = menuNode;
  menuNode.delegate = self;

  HLLabelButtonNode *buttonPrototype = [[HLLabelButtonNode alloc] initWithImageNamed:@"menu-button"];
  buttonPrototype.centerRect = CGRectMake(0.3333333f, 0.3333333f, 0.3333333f, 0.3333333f);
  buttonPrototype.fontName = @"Courier";
  buttonPrototype.fontSize = 24.0f;
  buttonPrototype.fontColor = [UIColor whiteColor];
  buttonPrototype.size = CGSizeMake(240.0f, 40.0f);
  buttonPrototype.verticalAlignmentMode = HLLabelButtonNodeVerticalAlignFontAscender;
  menuNode.itemButtonPrototype = buttonPrototype;
  menuNode.itemSoundFile = @"wooden-click-1.caf";

  HLMenu *menu = [[HLMenu alloc] init];
  menuNode.menu = menu;
  [menu addItem:[HLMenuItem menuItemWithText:@"Save"]];
  [menu addItem:[HLMenu menuWithText:@"Main"
                               items:@[ [HLMenu menuWithText:@"Challenge"
                                                       items:@[ [HLMenuItem menuItemWithText:@"New"],
                                                                [HLMenuBackItem menuItemWithText:@"Back"] ]],
                                        [HLMenu menuWithText:@"Sandbox"
                                                       items:@[ [HLMenuItem menuItemWithText:@"New"],
                                                                [HLMenuBackItem menuItemWithText:@"Back"] ]],
                                        [HLMenuItem menuItemWithText:@"About"] ]]];
  [menu addItem:[HLMenuItem menuItemWithText:@"Options"]];
  [menu addItem:[HLMenuItem menuItemWithText:@"Return to Game"]];
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
#pragma mark HLMenuNodeDelegate

- (void)menuNode:(HLMenuNode *)menuNode didTapMenuItem:(HLMenuItem *)menuItem
{
  NSLog(@"menu item %@", [menuItem path]);
  if ([[menuItem path] isEqualToString:@"Main/Sandbox/New"]) {
    [self FL_sandboxNew];
  }
}

#pragma mark -
#pragma mark FLTrackSceneDelegate

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene
{
  if (!_menuScene) {
    [self FL_createMenuScene];
  }
  [_menuScene.menuNode navigateToTopMenuAnimation:HLMenuNodeAnimationNone];
  [self.skView presentScene:_menuScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
  _currentScene = _menuScene;
}

#pragma mark -
#pragma mark Common

- (void)FL_sandboxNew
{
  // TODO: Prompt to save existing track scene (if not already saved since the
  // menu was presented).

  _trackScene = [FLTrackScene sceneWithSize:[UIScreen mainScreen].bounds.size];
  _trackScene.delegate = self;
  _trackScene.scaleMode = SKSceneScaleModeResizeFill;

  if ([FLTrackScene sceneAssetsLoaded]) {
    [self.skView presentScene:_trackScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
    _currentScene = _trackScene;
    return;
  }

  if (!_loadingScene) {
    [self FL_createLoadingScene];
  }
  [self.skView presentScene:_loadingScene];
  [FLTrackScene loadSceneAssetsWithCompletion:^{
    [self.skView presentScene:self->_trackScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
    self->_currentScene = self->_trackScene;
  }];
}

@end
