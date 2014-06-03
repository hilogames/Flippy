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

static NSString * const FLGameTypeChallenge = @"challenge";
static NSString * const FLGameTypeSandbox = @"sandbox";

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
  HLMenuScene *_mainMenuScene;
  FLTrackScene *_trackScene;
  SKNode *_gameModalNode;
  HLMenuNode *_gameMenuNode;
  HLMessageNode *_gameMessageNode;

  BOOL _gameSavedWhileModallyPresented;

  UIAlertView *_exitConfirmAlert;
  UIAlertView *_saveConfirmAlert;
  NSString *_savePath;
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
  if (_currentScene == _mainMenuScene) {
    [extraCoder encodeObject:_mainMenuScene forKey:@"mainMenuScene"];
  }
  if (_trackScene) {
    [extraCoder encodeObject:_trackScene forKey:@"trackScene"];
  }
  [extraCoder finishEncoding];
  [archiveData writeToFile:FLExtraStatePath atomically:NO];

  // note: Don't try to archive _currentScene as a pointer, since the scene objects
  // aren't archived alongside.  Instead, archive a code.
  FLViewControllerScene currentScene = FLViewControllerSceneNone;
  if (_currentScene == _mainMenuScene) {
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
    _mainMenuScene = [extraCoder decodeObjectForKey:@"mainMenuScene"];
    if (_mainMenuScene) {
      _mainMenuScene.menuNode.delegate = self;
    }
    [extraCoder finishDecoding];
  }

  FLViewControllerScene currentScene = (FLViewControllerScene)[coder decodeIntForKey:@"currentScene"];
  switch (currentScene) {
    case FLViewControllerSceneMenu:
      if (!_mainMenuScene) {
        FLError(@"FLViewController decodeRestorableStateWithCoder: Failed to decode restorable state for main menu scene.");
      }
      _currentScene = _mainMenuScene;
      break;
    case FLViewControllerSceneTrack:
      if (!_trackScene) {
        FLError(@"FLViewController decodeRestorableStateWithCoder: Failed to decode restorable state for track scene.");
      }
      _currentScene = _trackScene;
      break;
    case FLViewControllerSceneNone:
      if (_mainMenuScene) {
        FLError(@"FLViewController decodeRestorableStateWithCoder: Decoded main menu scene, but current scene unset.");
        _currentScene = _mainMenuScene;
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
  // note: Sometimes getting wrong dimensions from view.bounds.size when in landscape.
  // See notes here:
  //
  //   http://filipstefansson.com/2013/10/31/fix-spritekit-scalemod-in-landscape-orientation.html
  //
  // ...but I've reproduced on the simulator such that viewWillLayoutSubviews also returns
  // the wrong dimensions.  I thought it might be when the scene is archived portrait but
  // restored landscape, but I reproduced on simulator after a reset.

  [super viewWillAppear:animated];

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
    if (!_mainMenuScene) {
      [self FL_createMainMenuScene];
    }
    _currentScene = _mainMenuScene;
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

- (BOOL)menuNode:(HLMenuNode *)menuNode shouldTapMenuItem:(HLMenuItem *)menuItem itemIndex:(NSUInteger)itemIndex
{
  if (menuNode == _gameMenuNode) {
    NSString *menuItemPath = [menuItem path];
    if ([menuItemPath isEqualToString:@"Save"]) {
      // TODO: If _trackScene is a challenge game, then update menu for FLGameTypeChallenge.
      [self FL_gameModalNodeUpdate:FLGameTypeSandbox];
      [self FL_gameModalNodeShowMessage:@"Choose save game slot."];
    }
  }
  return YES;
}

- (void)menuNode:(HLMenuNode *)menuNode didTapMenuItem:(HLMenuItem *)menuItem itemIndex:(NSUInteger)itemIndex
{
  NSString *menuItemPath = [menuItem path];
  HLMenuItem *menuItemParent = menuItem.parent;
  NSLog(@"did tap menu item %@", menuItemPath);

  if (menuNode == _mainMenuScene.menuNode) {

    if ([menuItemPath isEqualToString:@"Sandbox/New"]) {
      [self FL_sandboxNew];
    }
    
    return;
  }

  if (menuNode == _gameMenuNode) {

    if ([menuItemPath isEqualToString:@"Resume"]) {
      [_trackScene dismissModalNode];
    } else if ([menuItemParent.text isEqualToString:@"Save"]) {
      if (![menuItem isKindOfClass:[HLMenuBackItem class]]) {
        _gameSavedWhileModallyPresented = YES;
        // TODO: If _trackScene is a challenge game, then save game for FLGameTypeChallenge.
        NSString *savePath = [self FL_savePathForGameType:FLGameTypeSandbox saveNumber:itemIndex];
        [self FL_saveFromGameMenuConfirm:savePath];
      }
    } else if ([menuItemPath isEqualToString:@"Exit"]) {
      [self FL_exitFromGameMenuConfirm];
    }

    return;
  }
}

#pragma mark -
#pragma mark FLTrackSceneDelegate

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene
{
  if (!_gameModalNode) {
    [self FL_createGameModalNode:nil];
  }
  [_gameMenuNode navigateToTopMenuAnimation:HLMenuNodeAnimationNone];
  [_trackScene presentModalNode:_gameModalNode];
  _gameSavedWhileModallyPresented = NO;
}

#pragma mark -
#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  if (alertView == _exitConfirmAlert) {
    if (buttonIndex == 1) {
      [self FL_exitFromGameMenu];
    }
  } else if (alertView == _saveConfirmAlert) {
    if (buttonIndex == 1) {
      [self FL_saveFromGameMenu:_savePath];
    }
  }
}

#pragma mark -
#pragma mark Common

- (void)FL_createLoadingScene
{
  _loadingScene = [SKScene sceneWithSize:self.view.bounds.size];
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

- (void)FL_createMainMenuScene
{
  _mainMenuScene = [HLMenuScene sceneWithSize:self.view.bounds.size];
  _mainMenuScene.scaleMode = SKSceneScaleModeResizeFill;
  
  SKSpriteNode *backgroundNode = [SKSpriteNode spriteNodeWithImageNamed:@"grass"];
  _mainMenuScene.backgroundNode = backgroundNode;
  
  HLMenuNode *menuNode = [[HLMenuNode alloc] init];
  _mainMenuScene.menuNode = menuNode;
  menuNode.delegate = self;
  menuNode.position = CGPointMake(0.0f, 48.0f);
  menuNode.itemButtonPrototype = [FLViewController FL_sharedMenuButtonPrototypeBasic];
  menuNode.itemSpacing = 48.0f;
  menuNode.itemSoundFile = @"wooden-click-1.caf";
  
  HLMenu *menu = [[HLMenu alloc] init];
  [menu addItem:[HLMenu menuWithText:@"Play"
                               items:@[ [HLMenuItem menuItemWithText:@"New"],
                                        [HLMenuBackItem menuItemWithText:@"Back"] ]]];
  [menu addItem:[HLMenu menuWithText:@"Sandbox"
                               items:@[ [HLMenuItem menuItemWithText:@"New"],
                                        [HLMenuBackItem menuItemWithText:@"Back"] ]]];
  [menu addItem:[HLMenuItem menuItemWithText:@"About"]];
  [menuNode setMenu:menu animation:HLMenuNodeAnimationNone];
}

/**
 * Creates the in-game menu and message area to be presented modally over the track scene.
 *
 * Some of the content (of the menu, in particular), will need to be updated based
 * on the extra parameters to this method (like game type).  The parameters may be passed
 * nil if not currently relevant; call FL_updateGameModalNode before the relevant
 * content is displayed by the modal node.
 */
- (void)FL_createGameModalNode:(NSString *)gameType
{
  _gameModalNode = [SKNode node];

  _gameMenuNode = [[HLMenuNode alloc] init];
  _gameMenuNode.delegate = self;
  _gameMenuNode.position = CGPointMake(0.0f, 48.0f);
  _gameMenuNode.itemSpacing = 48.0f;
  _gameMenuNode.itemButtonPrototype = [FLViewController FL_sharedMenuButtonPrototypeBasic];
  _gameMenuNode.itemSoundFile = @"wooden-click-1.caf";
  [_gameModalNode addChild:_gameMenuNode];
  
  _gameMessageNode = [[HLMessageNode alloc] initWithColor:[UIColor colorWithWhite:1.0f alpha:0.5f] size:CGSizeZero];
  _gameMessageNode.messageLingerDuration = 3.0;
  _gameMessageNode.fontName = @"Courier";
  _gameMessageNode.fontSize = 20.0f;
  _gameMessageNode.fontColor = [UIColor blackColor];
  
  [self FL_gameModalNodeUpdate:gameType];
}

- (void)FL_gameModalNodeUpdate:(NSString *)gameType
{
  // TODO: Long press on buttons to delete game?
  
  // noob: Either create a new menu or else update the existing one in-place.
  // I'm not sure how well I like this; perhaps instead the menu node should
  // provide an explicit delegate callback to update a submenu right before
  // it's shown (rather than us having to hijack menuNode:shouldTapMenuItem:).
  static HLMenu *saveMenu = nil;
  
  HLMenu *menu = nil;
  if (saveMenu) {
    [saveMenu removeAllItems];
  } else {
    menu = [[HLMenu alloc] init];
    [menu addItem:[HLMenuItem menuItemWithText:@"Resume"]];
    saveMenu = [HLMenu menuWithText:@"Save" items:@[]];
    [menu addItem:saveMenu];
    [menu addItem:[HLMenuItem menuItemWithText:@"Exit"]];
  }
  
  const NSUInteger FLSaveGameSlotCount = 3;
  if (gameType) {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    for (NSUInteger saveNumber = 0; saveNumber < FLSaveGameSlotCount; ++saveNumber) {
      NSDate *saveDate;
      HLMenuItem *saveGameMenuItem = [[HLMenuItem alloc] init];
      if ([self FL_getSaveInfoForGameType:gameType saveNumber:saveNumber saveDate:&saveDate]) {
        saveGameMenuItem.text = [NSString stringWithFormat:@"Sandbox %lu (%@)",
                                 (unsigned long)saveNumber + 1,
                                 [dateFormatter stringFromDate:saveDate]];
        saveGameMenuItem.buttonPrototype = [FLViewController FL_sharedMenuButtonPrototypeSaveGame];
      } else {
        saveGameMenuItem.text = @"(Empty)";
        saveGameMenuItem.buttonPrototype = [FLViewController FL_sharedMenuButtonPrototypeSaveGameEmpty];
      }
      [saveMenu addItem:saveGameMenuItem];
    }
  }
  [saveMenu addItem:[HLMenuBackItem menuItemWithText:@"Back"]];
  
  if (!_gameMenuNode.menu) {
    [_gameMenuNode setMenu:menu animation:HLMenuNodeAnimationNone];
  }
}

- (void)FL_gameModalNodeShowMessage:(NSString *)message
{
  // noob: Considered designs for messages:
  // The message node could be part of the menu node, but the menu node knows
  // nothing about how the message node should appear, or its geometry, or the
  // scene geometry.  The message node could be part of the track scene, but
  // the track scene only knows that it's displaying a single modal node.  The
  // message node could be an automatic addition to the modal presentation system,
  // but again the modal presentation system doesn't know where it should appear,
  // or how it should look.  So.  We make our own custom menu+message node to
  // present modally.  If it proves useful, we could abstract it into an
  // HLModalMessageMenu or something.
  
  // note: Could maintain the size and shape of the message node only when
  // our own geometry changes.  But this is easier, for now.
  const CGFloat FLGameMessageNodeHeight = 32.0f;
  _gameMessageNode.position = CGPointMake(0.0f, _gameMenuNode.position.y + _gameMenuNode.itemSpacing);
  _gameMessageNode.size = CGSizeMake(_trackScene.size.width, FLGameMessageNodeHeight);
  
  [_gameMessageNode showMessage:message parent:_gameModalNode];
}

+ (HLLabelButtonNode *)FL_sharedMenuButtonPrototypeBasic
{
  static HLLabelButtonNode *buttonPrototype = nil;
  if (!buttonPrototype) {
    buttonPrototype = [[HLLabelButtonNode alloc] initWithImageNamed:@"menu-button"];
    buttonPrototype.centerRect = CGRectMake(0.3333333f, 0.3333333f, 0.3333333f, 0.3333333f);
    buttonPrototype.fontName = @"Courier";
    buttonPrototype.fontSize = 20.0f;
    buttonPrototype.fontColor = [UIColor whiteColor];
    buttonPrototype.size = CGSizeMake(240.0f, 36.0f);
    buttonPrototype.verticalAlignmentMode = HLLabelButtonNodeVerticalAlignFontAscender;
  }
  return buttonPrototype;
}

+ (HLLabelButtonNode *)FL_sharedMenuButtonPrototypeSaveGame
{
  static HLLabelButtonNode *buttonPrototype = nil;
  if (!buttonPrototype) {
    buttonPrototype = [[FLViewController FL_sharedMenuButtonPrototypeBasic] copy];
    buttonPrototype.fontSize = 14.0f;
    buttonPrototype.color = [UIColor orangeColor];
    buttonPrototype.colorBlendFactor = 1.0f;
  }
  return buttonPrototype;
}

+ (HLLabelButtonNode *)FL_sharedMenuButtonPrototypeSaveGameEmpty
{
  static HLLabelButtonNode *buttonPrototype = nil;
  if (!buttonPrototype) {
    buttonPrototype = [[FLViewController FL_sharedMenuButtonPrototypeSaveGame] copy];
    buttonPrototype.color = [UIColor greenColor];
  }
  return buttonPrototype;
}

- (void)FL_sandboxNew
{
  // TODO: Prompt to save existing track scene (if not already saved since the
  // menu was presented).

  _trackScene = [FLTrackScene sceneWithSize:self.view.bounds.size];
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

- (BOOL)FL_saveExistsForGameType:(NSString *)gameType saveNumber:(NSUInteger)saveNumber
{
  NSString *savePath = [self FL_savePathForGameType:gameType saveNumber:saveNumber];
  return [[NSFileManager defaultManager] fileExistsAtPath:savePath];
}

- (BOOL)FL_getSaveInfoForGameType:(NSString *)gameType saveNumber:(NSUInteger)saveNumber saveDate:(NSDate * __autoreleasing *)saveDate
{
  NSString *savePath = [self FL_savePathForGameType:gameType saveNumber:saveNumber];
  NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:savePath error:nil];
  if (!attributes) {
    return NO;
  }
  if (saveDate) {
    *saveDate = (NSDate *)[attributes objectForKey:NSFileCreationDate];
  }
  return YES;
}

- (NSString *)FL_savePathForGameType:(NSString *)gameType saveNumber:(NSUInteger)saveNumber
{
  NSString *saveName = [NSString stringWithFormat:@"save-%@-%lu", gameType, (unsigned long)saveNumber];
  return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
          stringByAppendingPathComponent:[saveName stringByAppendingPathExtension:@"archive"]];
}

- (void)FL_saveFromGameMenuConfirm:(NSString *)savePath
{
  if (![[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
    [self FL_saveFromGameMenu:savePath];
    return;
  }

  UIAlertView *confirmAlert = [[UIAlertView alloc] initWithTitle:@"Saving will overwrite an old game. Save anyway?"
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:@"Cancel"
                                               otherButtonTitles:@"Save", nil];
  confirmAlert.alertViewStyle = UIAlertViewStyleDefault;
  [confirmAlert show];
  _saveConfirmAlert = confirmAlert;
  _savePath = savePath;
}

- (void)FL_saveFromGameMenu:(NSString *)savePath
{
  [NSKeyedArchiver archiveRootObject:_trackScene toFile:savePath];
  [_gameMenuNode navigateToTopMenuAnimation:HLMenuNodeAnimationNone];
  [self FL_gameModalNodeShowMessage:@"Game saved."];
}

- (void)FL_exitFromGameMenuConfirm
{
  if (_gameSavedWhileModallyPresented) {
    [self FL_exitFromGameMenu];
    return;
  }

  UIAlertView *confirmAlert = [[UIAlertView alloc] initWithTitle:@"Unsaved changes will be lost. Exit anyway?"
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:@"Cancel"
                                               otherButtonTitles:@"Exit", nil];
  confirmAlert.alertViewStyle = UIAlertViewStyleDefault;
  [confirmAlert show];
  _exitConfirmAlert = confirmAlert;
}

- (void)FL_exitFromGameMenu
{
  [_trackScene dismissModalNode];
  if (!_mainMenuScene) {
    [self FL_createMainMenuScene];
  } else {
    [_mainMenuScene.menuNode navigateToTopMenuAnimation:HLMenuNodeAnimationNone];
  }
  [self.skView presentScene:_mainMenuScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
  _currentScene = _mainMenuScene;
}

@end
