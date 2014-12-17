//
//  FLViewController.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo Games. All rights reserved.
//

#import "FLViewController.h"

#import "HLError.h"
#import "HLGestureTarget.h"
#import "HLScrollNode.h"
#import "HLTiledNode.h"
#import "SKNode+HLGestureTarget.h"

#import "DSMultilineLabelNode.h"
#import "FLApplication.h"
#import "FLConstants.h"
#import "FLUser.h"
#import "FLTrackScene.h"

typedef NS_ENUM(NSInteger, FLViewControllerScene) {
  FLViewControllerSceneNone,
  FLViewControllerSceneTitle,
  FLViewControllerSceneGame
};

static const CGFloat FLZPositionTitleBackground = 1.0f;
static const CGFloat FLZPositionTitleMenu = 2.0f;
static const CGFloat FLZPositionTitleMessage = 3.0f;
static const CGFloat FLZPositionTitleModalPresentationMin = 4.0f;
static const CGFloat FLZPositionTitleModalPresentationMax = 5.0f;

static const CGFloat FLZPositionGameOverlayStatus = 1.0f;
static const CGFloat FLZPositionGameOverlayMenu = 2.0f;
static const CGFloat FLZPositionGameOverlayMessage = 3.0f;

static const CGFloat FLZPositionNextLevelOverlayMenu = 1.0f;
static const CGFloat FLZPositionNextLevelOverlayMessage = 2.0f;

static NSString * const FLExtraStateName = @"extra-application-state";
static NSString * FLExtraStatePath;

static const NSTimeInterval FLSceneTransitionDuration = 0.5;
static const NSTimeInterval FLOffscreenSlideDuration = 0.25;

static const CGFloat FLMessageNodeHeight = 32.0f;

static const NSUInteger FLSaveGameSlotCount = 3;

static NSString * const FLCommonMenuBack = NSLocalizedString(@"Back", @"Menu item: return to previous menu.");
static NSString * const FLCommonMenuEmptySlot = NSLocalizedString(@"(Empty)", @"Menu item: no game in this save slot.");
static NSString * const FLCommonMenuNew = NSLocalizedString(@"New", @"Menu item: start a new game.");

static NSString * const FLTitleMenuChallenge = NSLocalizedString(@"Play", @"Menu item: start a new or load an old challenge game.");
static NSString * const FLTitleMenuSandbox = NSLocalizedString(@"Sandbox", @"Menu item: start a new or load an old sandbox game.");
static NSString * const FLTitleMenuSettings = NSLocalizedString(@"Settings", @"Menu item: modify game global settings.");
static NSString * const FLTitleMenuAbout = NSLocalizedString(@"About", @"Menu item: show game production information.");
static NSString * const FLTitleMenuResetApp = NSLocalizedString(@"Reset App", @"Menu item: reset application to original installed (unlocks, tutorials, saves, etc).");
static NSString * const FLTitleMenuResetUnlocks = NSLocalizedString(@"Reset Unlocks", @"Menu item: reset unlocks, so new challenge games start at first level.");
static NSString * const FLTitleMenuResetTutorial = NSLocalizedString(@"Reset Tutorial", @"Menu item: reset tutorial so that it will display on the next new game.");

static NSString * const FLGameMenuResume = NSLocalizedString(@"Resume", @"Menu item: continue the current game.");
static NSString * const FLGameMenuSave = NSLocalizedString(@"Save", @"Menu item: save the current game.");
static NSString * const FLGameMenuRestart = NSLocalizedString(@"Restart", @"Menu item: restart current level.");
static NSString * const FLGameMenuHelp = NSLocalizedString(@"Help", @"Menu item: show help screen.");
static NSString * const FLGameMenuExit = NSLocalizedString(@"Exit", @"Menu item: exit current game, returning to title screen.");

static NSString * const FLNextLevelMenuSkip = NSLocalizedString(@"Don’t Save", @"Menu item: choose not to save the current game in any of the presented slots.");

@implementation FLViewController
{
  __weak SKScene *_currentScene;

  SKScene *_loadingScene;

  HLScene *_titleScene;
  __weak HLMenuNode *_titleMenuNode;

  FLTrackScene *_gameScene;
  SKNode *_gameOverlay;
  HLMenuNode *_gameMenuNode;
  HLMessageNode *_gameMessageNode;
  DSMultilineLabelNode *_gameStatusNode;
  BOOL _savedInGameOverlay;

  SKNode *_nextLevelOverlay;
  HLMenuNode *_nextLevelMenuNode;
  HLMessageNode *_nextLevelMessageNode;

  HLScrollNode *_helpOverlay;

  HLScrollNode *_aboutOverlay;
  CGFloat _aboutItemsHeight;

  UIAlertView *_saveConfirmAlert;
  NSString *_saveConfirmPath;
  void (^_saveConfirmCompletion)(void);
  UIAlertView *_restartConfirmAlert;
  UIAlertView *_deleteConfirmAlert;
  NSString *_deleteConfirmPath;
  void (^_deleteConfirmCompletion)(void);
  UIAlertView *_exitConfirmAlert;
  UIAlertView *_resetAppConfirmAlert;
  UIAlertView *_resetUnlocksConfirmAlert;
  UIAlertView *_resetTutorialConfirmAlert;
}

+ (void)initialize
{
  FLExtraStatePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0]
                      stringByAppendingPathComponent:[FLExtraStateName stringByAppendingPathExtension:@"archive"]];
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.restorationIdentifier = @"FLViewController";

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidReceiveMemoryWarning)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
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
  if (_currentScene) {
    if (_currentScene == _titleScene) {
      [extraCoder encodeObject:_titleScene forKey:@"titleScene"];
      [extraCoder encodeObject:_titleMenuNode forKey:@"titleMenuNode"];
    } else if (_currentScene == _gameScene) {
      [extraCoder encodeObject:_gameScene forKey:@"trackScene"];
    }
  }
  [extraCoder finishEncoding];
  [archiveData writeToFile:FLExtraStatePath atomically:NO];

  // note: Don't try to archive _currentScene as a pointer, since the scene objects
  // aren't archived alongside.  Instead, archive a code.
  FLViewControllerScene currentScene = FLViewControllerSceneNone;
  if (_currentScene == _titleScene) {
    currentScene = FLViewControllerSceneTitle;
  } else if (_currentScene == _gameScene) {
    currentScene = FLViewControllerSceneGame;
  }
  [coder encodeInteger:currentScene forKey:@"currentScene"];
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
    _gameScene = [extraCoder decodeObjectForKey:@"trackScene"];
    if (_gameScene) {
      _gameScene.delegate = self;
    }
    _titleScene = [extraCoder decodeObjectForKey:@"titleScene"];
    HLMenuNode *titleMenuNode = nil;
    if (_titleScene) {
      // noob: I'm keeping the pointer to the title scene's menu node a weak pointer just
      // to prove the point that it's a reference, not an owned object.  But of course
      // that means jumping through these hoops.  Good practice?
      titleMenuNode = [extraCoder decodeObjectForKey:@"titleMenuNode"];
      if (titleMenuNode) {
        titleMenuNode.delegate = self;
      }
    }
    _titleMenuNode = titleMenuNode;
    [extraCoder finishDecoding];
  }

  FLViewControllerScene currentScene = (FLViewControllerScene)[coder decodeIntegerForKey:@"currentScene"];
  _currentScene = nil;
  switch (currentScene) {
    case FLViewControllerSceneTitle:
      if (!_titleScene) {
        HLError(HLLevelError, @"FLViewController decodeRestorableStateWithCoder: Failed to decode restorable state for title scene.");
      } else {
        _currentScene = _titleScene;
      }
      break;
    case FLViewControllerSceneGame:
      if (!_gameScene) {
        HLError(HLLevelError, @"FLViewController decodeRestorableStateWithCoder: Failed to decode restorable state for track scene.");
      } else {
        _currentScene = _gameScene;
      }
      break;
    case FLViewControllerSceneNone:
      if (_titleScene) {
        HLError(HLLevelError, @"FLViewController decodeRestorableStateWithCoder: Decoded title scene, but current scene unset.");
        _currentScene = _titleScene;
      } else if (_gameScene) {
        HLError(HLLevelError, @"FLViewController decodeRestorableStateWithCoder: Decoded track scene, but current scene unset.");
        _currentScene = _gameScene;
      }
      break;
    default:
      [NSException raise:@"FLViewControllerUnknownScene" format:@"Unrecognized scene code %ld during decoding view controller.", (long)currentScene];
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
  // TODO: Sometimes getting wrong dimensions from view.bounds.size when in landscape.
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
    if (!_titleScene) {
      [self FL_titleSceneCreate];
    }
    _currentScene = _titleScene;
  }
  // note: Otherwise, a _currentScene was unarchived during application restoration.
  // In other similar situations, that means I need to update geometry of the scene:
  // in particular, if the archive was created in a different orientation.  But it
  // appears from testing that the application takes care of the rotation in this
  // case.

  // note: No loading of track assets, or showing loading screens.  If the track was
  // decoded from application state, then the assets were already loaded.  If not,
  // then we don't expect _currentScene to be _gameScene.

  // noob: This logic for loading track scene assets seems messy and distributed.
  // Check it with an assertion, but think about ways to improve it.  (For one thing,
  // maybe we should have a notification for applicationDidFinishLoading, so that
  // we can separate out concerns about application restorable state from what happens
  // when the view appears.
  if (_gameScene && _currentScene == _gameScene && ![FLTrackScene sceneAssetsLoaded]) {
    [NSException raise:@"FLViewControllerBadState" format:@"Method viewWillAppear assumes that track view would not be current without having assets already loaded."];
  }

  // note: No transition for now, even if loading the app for the first time.
  [self.skView presentScene:_currentScene];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [NSException raise:@"FLViewControllerBadState" format:@"Method viewWillAppear assumes that the view never disappears."];
  [super viewWillDisappear:animated];
}

- (void)viewDidLayoutSubviews
{
  if (_gameScene) {
    SKNode *gameScenePresentedOverlay = [_gameScene modalNodePresented];
    if (gameScenePresentedOverlay == _gameOverlay) {
      [self FL_gameOverlayUpdateGeometry];
    } else if (gameScenePresentedOverlay == _nextLevelOverlay) {
      [self FL_nextLevelOverlayUpdateGeometry];
    } else if (gameScenePresentedOverlay == _helpOverlay) {
      [self FL_helpOverlayUpdateGeometry];
    }
  }

  if (_titleScene) {
    SKNode *titleScenePresentedOverlay = [_titleScene modalNodePresented];
    if (titleScenePresentedOverlay == _aboutOverlay) {
      [self FL_aboutOverlayUpdateGeometry];
    }
  }
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
#pragma mark Notifications

- (void)applicationDidBecomeActive
{
  if (_gameScene) {
    [_gameScene timerResume];
  }
}

- (void)applicationWillResignActive
{
  if (_gameScene) {
    [_gameScene timerPause];
  }
}

- (void)applicationDidReceiveMemoryWarning
{
  SKNode *gameScenePresentedOverlay = nil;
  if (_gameScene) {
    gameScenePresentedOverlay = [_gameScene modalNodePresented];
  }
  if (gameScenePresentedOverlay != _gameOverlay) {
    [self FL_gameOverlayRelease];
  }
  if (gameScenePresentedOverlay != _nextLevelOverlay) {
    [self FL_nextLevelOverlayRelease];
  }
  if (gameScenePresentedOverlay != _helpOverlay) {
    [self FL_helpOverlayRelease];
  }

  if (_gameScene && _currentScene != _gameScene) {
    _gameScene = nil;
  }

  SKNode *titleScenePresentedOverlay = nil;
  if (_titleScene) {
    titleScenePresentedOverlay = [_titleScene modalNodePresented];
  }
  if (titleScenePresentedOverlay != _aboutOverlay) {
    [self FL_aboutOverlayRelease];
  }

  if (_titleScene && _currentScene != _titleScene) {
    _titleScene = nil;
  }

  if (_loadingScene && _currentScene != _loadingScene) {
    _loadingScene = nil;
  }
}

#pragma mark -
#pragma mark HLMenuNodeDelegate

- (BOOL)menuNode:(HLMenuNode *)menuNode shouldTapMenuItem:(HLMenuItem *)menuItem itemIndex:(NSUInteger)itemIndex
{
  HLMenu *menuItemParent = menuItem.parent;

  if (menuNode == _titleMenuNode) {

    if ([menuItem.text isEqualToString:FLTitleMenuSandbox]) {
      NSUInteger saveCount = [self FL_commonMenuUpdateSaves:(HLMenu *)menuItem forGameType:FLGameTypeSandbox includeNewButton:YES includeBackButton:YES];
      // note: The important thing is the update of the menu, above.  But as a bonus, go straight
      // to new game if there are no saves.
      if (saveCount == 0) {
        [self FL_load:FLGameTypeSandbox gameLevel:0 isNew:YES otherwiseSaveNumber:0];
        return NO;
      }
    } else if ([menuItem.text isEqualToString:FLTitleMenuChallenge]) {
      NSUInteger saveCount = [self FL_commonMenuUpdateSaves:(HLMenu *)menuItem forGameType:FLGameTypeChallenge includeNewButton:YES includeBackButton:YES];
      // note: The important thing is the update of the menu, above.  But as a bonus, go straight
      // to new menu if there are no saves, and to a new game if there are no special new-game options.
      if (saveCount == 0) {
        HLMenu *newMenu = (HLMenu *)[(HLMenu *)menuItem itemAtIndex:0];
        NSUInteger newCount = [self FL_titleMenuUpdateNew:newMenu];
        if (newCount == 1) {
          [self FL_load:FLGameTypeChallenge gameLevel:0 isNew:YES otherwiseSaveNumber:0];
        } else {
          [self FL_titleSceneShowMessage:NSLocalizedString(@"Choose starting level.",
                                                           @"Menu message: displayed when starting a new game over a list of challenge levels previously unlocked.")];
          [menuNode navigateToSubmenuWithPath:@[ FLTitleMenuChallenge, FLCommonMenuNew ]
                                    animation:HLMenuNodeAnimationSlideLeft];
        }
        return NO;
      }
    } else if ([menuItem.text isEqualToString:FLCommonMenuNew]) {
      // note: If this is a challenge game and there are special new-game options, then show the
      // submenu.  Otherwise, go straight to a basic new game.
      FLGameType gameType = ([menuItemParent.text isEqualToString:FLTitleMenuChallenge] ? FLGameTypeChallenge : FLGameTypeSandbox);
      if (gameType == FLGameTypeSandbox || [self FL_titleMenuUpdateNew:(HLMenu *)menuItem] == 1) {
        [self FL_load:gameType gameLevel:0 isNew:YES otherwiseSaveNumber:0];
        return NO;
      }
    }

    return YES;
  }

  if (menuNode == _gameMenuNode) {

    if ([menuItem.text isEqualToString:FLGameMenuSave]) {
      [self FL_commonMenuUpdateSaves:(HLMenu *)menuItem forGameType:_gameScene.gameType includeNewButton:NO includeBackButton:YES];
      [self FL_gameOverlayShowMessage:NSLocalizedString(@"Choose save slot.",
                                                        @"Menu message: displayed over a list of game slots for saving.")];
    }

    return YES;
  }

  return YES;
}

- (void)menuNode:(HLMenuNode *)menuNode didTapMenuItem:(HLMenuItem *)menuItem itemIndex:(NSUInteger)itemIndex
{
  HLMenu *menuItemParent = menuItem.parent;

  if (menuNode == _titleMenuNode) {

    if ([menuItem.text isEqualToString:FLCommonMenuNew]) {
      [self FL_titleSceneShowMessage:NSLocalizedString(@"Choose starting level.",
                                                       @"Menu message: displayed when starting a new game over a list of challenge levels previously unlocked.")];
    } else if ([menuItemParent.text isEqualToString:FLCommonMenuNew]) {
      // note: Assume this is a challenge game; sandbox games don't use a "New" submenu.
      // note: Last item in parent menu is a "Back" button.
      if (itemIndex + 1 < menuItemParent.itemCount) {
        int gameLevel = (int)itemIndex;
        [self FL_load:FLGameTypeChallenge gameLevel:gameLevel isNew:YES otherwiseSaveNumber:0];
      }
    } else if ([menuItem.text isEqualToString:FLTitleMenuChallenge]) {
      [self FL_titleSceneShowMessage:NSLocalizedString(@"Choose game to load.",
                                                       @"Menu message: displayed over a list of saved game slots.")];
    } else if ([menuItemParent.text isEqualToString:FLTitleMenuChallenge]) {
      [self FL_loadFromTitleMenu:FLGameTypeChallenge menuItem:menuItem itemIndex:itemIndex];
    } else if ([menuItem.text isEqualToString:FLTitleMenuSandbox]) {
      [self FL_titleSceneShowMessage:NSLocalizedString(@"Choose game to load.",
                                                       @"Menu message: displayed over a list of saved game slots.")];
    } else if ([menuItemParent.text isEqualToString:FLTitleMenuSandbox]) {
      [self FL_loadFromTitleMenu:FLGameTypeSandbox menuItem:menuItem itemIndex:itemIndex];
    } else if ([menuItem.text isEqualToString:FLTitleMenuAbout]) {
      [self FL_aboutFromTitleMenu];
    } else if ([menuItem.text isEqualToString:FLTitleMenuResetApp]) {
      [self FL_resetAppFromTitleMenuConfirm];
    } else if ([menuItem.text isEqualToString:FLTitleMenuResetUnlocks]) {
      [self FL_resetUnlocksFromTitleMenuConfirm];
    } else if ([menuItem.text isEqualToString:FLTitleMenuResetTutorial]) {
      [self FL_resetTutorialFromTitleMenuConfirm];
    }

    return;
  }

  if (menuNode == _gameMenuNode) {

    if ([menuItem.text isEqualToString:FLGameMenuResume]) {
      [_gameScene dismissModalNodeAnimation:HLScenePresentationAnimationFade];
      [_gameScene timerResume];
    } else if ([menuItem.text isEqualToString:FLGameMenuRestart]) {
      [self FL_restartFromGameMenuConfirm];
    } else if ([menuItemParent.text isEqualToString:FLGameMenuSave]) {
      if (![menuItem isKindOfClass:[HLMenuBackItem class]]) {
        _savedInGameOverlay = YES;
        NSString *savePath = [self FL_savePathForGameType:_gameScene.gameType saveNumber:itemIndex];
        [self FL_saveFromCommonMenuConfirm:savePath completion:^{
          [self->_gameMenuNode navigateToTopMenuAnimation:HLMenuNodeAnimationNone];
          [self FL_gameOverlayShowMessage:NSLocalizedString(@"Game saved.",
                                                            @"Menu message: displayed when a game has been saved.")];
        }];
      }
    } else if ([menuItem.text isEqualToString:FLGameMenuHelp]) {
      [self FL_helpFromGameMenu];
    } else if ([menuItem.text isEqualToString:FLGameMenuExit]) {
      [self FL_exitFromGameMenuConfirm];
    }

    return;
  }

  if (menuNode == _nextLevelMenuNode) {

    if ([menuItem.text isEqualToString:FLNextLevelMenuSkip]) {
      [self FL_nextLevel];
    } else {
      NSString *savePath = [self FL_savePathForGameType:_gameScene.gameType saveNumber:itemIndex];
      [self FL_saveFromCommonMenuConfirm:savePath completion:^{
        [self FL_nextLevel];
      }];
    }

    return;
  }
}

- (void)menuNode:(HLMenuNode *)menuNode didLongPressMenuItem:(HLMenuItem *)menuItem itemIndex:(NSUInteger)itemIndex
{
  if (menuNode == _titleMenuNode) {
    HLMenu *menuItemParent = menuItem.parent;
    if ([menuItemParent.text isEqualToString:FLTitleMenuChallenge]) {
      [self FL_deleteFromTitleMenuConfirm:FLGameTypeChallenge menuItem:menuItem itemIndex:itemIndex];
    } else if ([menuItemParent.text isEqualToString:FLTitleMenuSandbox]) {
      [self FL_deleteFromTitleMenuConfirm:FLGameTypeSandbox menuItem:menuItem itemIndex:itemIndex];
    }
  }
}

#pragma mark -
#pragma mark FLTrackSceneDelegate

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene
{
  if (!_gameOverlay) {
    [self FL_gameOverlayCreate];
  }

  [_gameScene timerPause];

  [self FL_gameStatusUpdateText];
  [self FL_gameOverlayUpdateGeometry];

  [_gameMenuNode navigateToTopMenuAnimation:HLMenuNodeAnimationNone];
  [_gameMessageNode hideMessage];

  // note: Register (or re-register) the menu node for gesture handling.  We're
  // being a bit sloppy here: The same modal overlay and menu node is used for
  // all games, and so we only really need to register for the first appearance
  // over a scene, but the call is idempotent, so it's okay.  And then really we
  // should unregister when the modal node is dismissed, we don't bother.
  [_gameScene registerDescendant:_gameMenuNode withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  [_gameScene presentModalNode:_gameOverlay animation:HLScenePresentationAnimationFade];

  _savedInGameOverlay = NO;
}

- (void)trackSceneDidTapNextLevelButton:(FLTrackScene *)trackScene
{
  if (!_nextLevelOverlay) {
    [self FL_nextLevelOverlayCreate];
  }

  [self FL_nextLevelOverlayUpdateGeometry];

  HLMenu *saveMenu = [[HLMenu alloc] init];
  [self FL_commonMenuUpdateSaves:saveMenu forGameType:_gameScene.gameType includeNewButton:NO includeBackButton:NO];
  HLMenuItem *skipMenuItem = [HLMenuItem menuItemWithText:FLNextLevelMenuSkip];
  skipMenuItem.buttonPrototype = [FLViewController FL_sharedMenuButtonPrototypeBack];
  [saveMenu addItem:skipMenuItem];
  [_nextLevelMenuNode setMenu:saveMenu animation:HLMenuNodeAnimationNone];

  // note: Register (or re-register) the menu node for gesture handling.  See note
  // in trackSceneDidTapMenuButton:; this is sloppy, but it doesn't matter.
  [_gameScene registerDescendant:_nextLevelMenuNode withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  [_gameScene presentModalNode:_nextLevelOverlay animation:HLScenePresentationAnimationFade];
  [self FL_nextLevelOverlayShowMessage:NSLocalizedString(@"Choose save slot.",
                                                         @"Menu message: displayed over a list of game slots for saving.")];
}

#pragma mark -
#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  if (alertView == _saveConfirmAlert) {
    if (buttonIndex == 1) {
      [self FL_saveWithSavePath:_saveConfirmPath completion:_saveConfirmCompletion];
    }
    _saveConfirmAlert = nil;
    _saveConfirmPath = nil;
    _saveConfirmCompletion = nil;
  } else if (alertView == _deleteConfirmAlert) {
    if (buttonIndex == 1) {
      [self FL_deleteWithSavePath:_deleteConfirmPath completion:_deleteConfirmCompletion];
    }
    _deleteConfirmAlert = nil;
    _deleteConfirmPath = nil;
    _deleteConfirmCompletion = nil;
  } else if (alertView == _restartConfirmAlert) {
    if (buttonIndex == 1) {
      [self FL_restart];
    }
    _restartConfirmAlert = nil;
  } else if (alertView == _exitConfirmAlert) {
    if (buttonIndex == 1) {
      [self FL_exitFromGameMenu];
    }
    _exitConfirmAlert = nil;
  } else if (alertView == _resetAppConfirmAlert) {
    if (buttonIndex == 1) {
      [self FL_resetAppFromTitleMenu];
    }
    _resetAppConfirmAlert = nil;
  } else if (alertView == _resetUnlocksConfirmAlert) {
    if (buttonIndex == 1) {
      [self FL_resetUnlocksFromTitleMenu];
    }
    _resetUnlocksConfirmAlert = nil;
  } else if (alertView == _resetTutorialConfirmAlert) {
    if (buttonIndex == 1) {
      [self FL_resetTutorialFromTitleMenu];
    }
    _resetTutorialConfirmAlert = nil;
  }
}

#pragma mark -
#pragma mark Common

- (HLMenuNode *)FL_commonMenuNodeCreate
{
  HLMenuNode *menuNode = [[HLMenuNode alloc] init];
  [menuNode hlSetGestureTarget:menuNode];
  menuNode.delegate = self;
  menuNode.position = CGPointMake(0.0f, 48.0f);
  menuNode.itemAnimation = HLMenuNodeAnimationSlideLeft;
  menuNode.itemAnimationDuration = FLOffscreenSlideDuration;
  menuNode.itemButtonPrototype = [FLViewController FL_sharedMenuButtonPrototypeBasic];
  menuNode.backItemButtonPrototype = [FLViewController FL_sharedMenuButtonPrototypeBack];
  menuNode.itemSpacing = 44.0f;
  menuNode.itemSoundFile = @"wooden-click-1.caf";
  return menuNode;
}

- (HLMessageNode *)FL_commonMessageNodeCreate
{
  HLMessageNode *messageNode = [[HLMessageNode alloc] initWithColor:[UIColor colorWithWhite:1.0f alpha:0.7f] size:CGSizeZero];
  messageNode.verticalAlignmentMode = HLLabelNodeVerticalAlignFontAscenderBias;
  messageNode.messageAnimationDuration = FLOffscreenSlideDuration;
  messageNode.messageLingerDuration = 2.0;
  messageNode.fontName = FLInterfaceFontName;
  messageNode.fontSize = 20.0f;
  messageNode.fontColor = [UIColor blackColor];
  return messageNode;
}

- (void)FL_loadingSceneCreate
{
  _loadingScene = [SKScene sceneWithSize:self.view.bounds.size];
  _loadingScene.scaleMode = SKSceneScaleModeResizeFill;
  _loadingScene.anchorPoint = CGPointMake(0.5f, 0.5f);

  const NSTimeInterval FLLoadingPulseDuration = 0.5;
  SKLabelNode *loadingLabelNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  loadingLabelNode.fontSize = 18.0f;
  loadingLabelNode.text = @"Loading...";
  loadingLabelNode.alpha = 0.0f;
  SKAction *pulse = [SKAction sequence:@[ [SKAction fadeAlphaTo:1.0f duration:FLLoadingPulseDuration],
                                          [SKAction fadeAlphaTo:0.5f duration:FLLoadingPulseDuration] ]];
  pulse.timingMode = SKActionTimingEaseInEaseOut;
  [loadingLabelNode runAction:[SKAction repeatActionForever:pulse]];
  [_loadingScene addChild:loadingLabelNode];
}

- (void)FL_loadingSceneUpdateGeometry
{
  // note: The most common need for this: Another scene is presented, and the device
  // orientation changes.  When the loading scene is next presented, it's size will
  // need to updated.
  _loadingScene.size = self.view.bounds.size;
}

- (void)FL_loadingSceneReset
{
  // note: Start with label faded all the way out, so that a quick load screen will
  // be a simple black.
  SKLabelNode *loadingLabelNode = (SKLabelNode *)[_loadingScene children][0];
  loadingLabelNode.alpha = 0.0f;
}

- (void)FL_titleSceneCreate
{
  _titleScene = [HLScene sceneWithSize:self.view.bounds.size];
  _titleScene.gestureTargetHitTestMode = HLSceneGestureTargetHitTestModeZPositionThenParent;
  _titleScene.scaleMode = SKSceneScaleModeResizeFill;
  _titleScene.anchorPoint = CGPointMake(0.5f, 0.5f);

  HLTiledNode *backgroundNode = [HLTiledNode tiledNodeWithImageNamed:@"grass.jpg" size:_titleScene.size];
  backgroundNode.zPosition = FLZPositionTitleBackground;
  [_titleScene addChild:backgroundNode withOptions:[NSSet setWithObject:HLSceneChildResizeWithScene]];

  HLMenuNode *titleMenuNode = [self FL_commonMenuNodeCreate];
  titleMenuNode.zPosition = FLZPositionTitleMenu;
  [_titleScene addChild:titleMenuNode withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  _titleMenuNode = titleMenuNode;

  [self FL_titleMenuCreate];
}

- (void)FL_titleSceneUpdateGeometry
{
  // note: The most common need for this: Another scene is presented, and the device
  // orientation changes.  When the title scene is next presented, it's size will
  // need to updated.
  _titleScene.size = self.view.bounds.size;
}
- (void)FL_titleSceneShowMessage:(NSString *)message
{
  HLMessageNode *messageNode = (HLMessageNode *)[_titleScene childNodeWithName:@"messageNode"];
  if (!messageNode) {
    messageNode = [self FL_commonMessageNodeCreate];
    messageNode.name = @"messageNode";
    messageNode.zPosition = FLZPositionTitleMessage;
    [_titleScene addChild:messageNode withOptions:[NSSet setWithObject:HLSceneChildNoCoding]];
  }

  // note: Could maintain the size and shape of the message node only when
  // our own geometry changes.  But easier to do it for every message, for now.
  HLMenuNode *titleMenuNode = _titleMenuNode;
  messageNode.position = CGPointMake(0.0f, titleMenuNode.position.y + titleMenuNode.itemSpacing);
  messageNode.size = CGSizeMake(_titleScene.size.width, FLMessageNodeHeight);

  [messageNode showMessage:message parent:_titleScene];
}

- (void)FL_titleSceneHideMessage
{
  HLMessageNode *messageNode = (HLMessageNode *)[_titleScene childNodeWithName:@"messageNode"];
  if (messageNode) {
    [messageNode hideMessage];
  }
}

- (void)FL_titleMenuCreate
{
  HLMenu *menu = [[HLMenu alloc] init];
  // note: Create empty loading menus for now; update later with FL_commonMenuUpdateSaves.
  [menu addItem:[HLMenu menuWithText:FLTitleMenuChallenge items:@[] ]];
  [menu addItem:[HLMenu menuWithText:FLTitleMenuSandbox items:@[] ]];
  [menu addItem:[HLMenu menuWithText:FLTitleMenuSettings items:@[ [HLMenuItem menuItemWithText:FLTitleMenuResetTutorial],
                                                                  [HLMenuItem menuItemWithText:FLTitleMenuResetUnlocks],
                                                                  [HLMenuItem menuItemWithText:FLTitleMenuResetApp],
                                                                  [HLMenuBackItem menuItemWithText:FLCommonMenuBack] ] ]];
  [menu addItem:[HLMenuItem menuItemWithText:FLTitleMenuAbout]];

  HLMenuNode *titleMenuNode = _titleMenuNode;
  [titleMenuNode setMenu:menu animation:HLMenuNodeAnimationNone];
}

- (NSUInteger)FL_titleMenuUpdateNew:(HLMenu *)newMenu
{
  NSUInteger newCount = 0;

  // note: Precondition: This is a challenge game.
  [newMenu removeAllItems];

  int levelCount = FLChallengeLevelsCount();
  for (int gameLevel = 0; gameLevel < levelCount; ++gameLevel) {
    if (gameLevel == 0 || FLUserUnlocksUnlocked([NSString stringWithFormat:@"FLUserUnlockLevel%d", gameLevel])) {
      NSString *levelTitle = FLChallengeLevelsInfo(gameLevel, FLChallengeLevelsTitle);
      [newMenu addItem:[HLMenuItem menuItemWithText:[NSString stringWithFormat:@"%d: %@", gameLevel, levelTitle]]];
      ++newCount;
    }
  }

  [newMenu addItem:[HLMenuBackItem menuItemWithText:FLCommonMenuBack]];

  return newCount;
}

- (void)FL_gameOverlayCreate
{
  _gameOverlay = [SKNode node];

  SKSpriteNode *statusBackgroundNode = [SKSpriteNode spriteNodeWithColor:[SKColor colorWithRed:0.4f green:0.5f blue:0.8f alpha:0.9f] size:CGSizeZero];
  [_gameOverlay addChild:statusBackgroundNode];
  _gameStatusNode = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  _gameStatusNode.zPosition = FLZPositionGameOverlayStatus;
  _gameStatusNode.fontSize = 18.0f;
  _gameStatusNode.fontColor = [SKColor whiteColor];
  [statusBackgroundNode addChild:_gameStatusNode];

  _gameMenuNode = [self FL_commonMenuNodeCreate];
  _gameMenuNode.zPosition = FLZPositionGameOverlayMenu;
  [_gameOverlay addChild:_gameMenuNode];

  HLMenu *menu = [[HLMenu alloc] init];
  [menu addItem:[HLMenuItem menuItemWithText:FLGameMenuResume]];
  // note: Create empty save menu for now; update later with FL_commonMenuUpdateSaves.
  [menu addItem:[HLMenu menuWithText:FLGameMenuSave items:@[]]];
  [menu addItem:[HLMenuItem menuItemWithText:FLGameMenuRestart]];
  [menu addItem:[HLMenuItem menuItemWithText:FLGameMenuHelp]];
  [menu addItem:[HLMenuItem menuItemWithText:FLGameMenuExit]];
  [_gameMenuNode setMenu:menu animation:HLMenuNodeAnimationNone];

  _gameMessageNode = [self FL_commonMessageNodeCreate];
  _gameMessageNode.zPosition = FLZPositionGameOverlayMessage;
}

- (void)FL_gameOverlayRelease
{
  _gameOverlay = nil;
  _gameStatusNode = nil;
  _gameMenuNode = nil;
  _gameMessageNode = nil;
}

- (void)FL_gameOverlayUpdateGeometry
{
  const CGFloat FLMessageSeparator = _gameMenuNode.itemSpacing;
  _gameMessageNode.position = CGPointMake(0.0f, _gameMenuNode.position.y + FLMessageSeparator);
  _gameMessageNode.size = CGSizeMake(_gameScene.size.width, FLMessageNodeHeight);

  const CGFloat FLStatusSeperator = _gameMenuNode.itemSpacing - FLMessageNodeHeight;
  const CGFloat FLStatusLabelPad = 5.0f;
  SKSpriteNode *statusBackgroundNode = (SKSpriteNode *)_gameStatusNode.parent;
  _gameStatusNode.paragraphWidth = _gameScene.size.width - 2.0f * FLStatusLabelPad - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
  statusBackgroundNode.size = CGSizeMake(_gameScene.size.width, _gameStatusNode.size.height + 2.0f * FLStatusLabelPad);
  statusBackgroundNode.position = CGPointMake(0.0f, (_gameScene.size.height - statusBackgroundNode.size.height) / 2.0f - FLStatusSeperator);
}

- (void)FL_gameOverlayShowMessage:(NSString *)message
{
  [_gameMessageNode showMessage:message parent:_gameOverlay];
}

- (void)FL_gameStatusUpdateText
{
  // note: Caller will probably need to call FL_gameOverlayUpdateGeometry after this.
  // If it becomes common to update the text more often than the the rest of the
  // overlay geometry needs to updated, then we'll split out our own geometry updating
  // code and call it separately when needed.
  if (!_gameScene) {
    return;
  }
  switch (_gameScene.gameType) {
    case FLGameTypeChallenge:
      _gameStatusNode.text = [NSString stringWithFormat:@"%@ %d:\n“%@”\n%ld %@",
                              NSLocalizedString(@"Level", @"Game information: followed by a level number."),
                              _gameScene.gameLevel,
                              FLChallengeLevelsInfo(_gameScene.gameLevel, FLChallengeLevelsTitle),
                              (unsigned long)[_gameScene regularSegmentCount],
                              NSLocalizedString(@"segments used", @"Game information: preceded by a number of segments used in a track.")];
      break;
    case FLGameTypeSandbox:
      _gameStatusNode.text = [NSString stringWithFormat:@"%@\n%ld %@",
                              FLGameTypeSandboxTitle(),
                              (unsigned long)[_gameScene regularSegmentCount],
                              NSLocalizedString(@"segments used", @"Game information: preceded by a number of segments used in a track.")];
      break;
    default:
      [NSException raise:@"FLViewControllerGameTypeUnknown" format:@"Unknown game type %ld.", (long)_gameScene.gameType];
  }
}

- (void)FL_nextLevelOverlayCreate
{
  _nextLevelOverlay = [SKNode node];

  _nextLevelMenuNode = [self FL_commonMenuNodeCreate];
  _nextLevelMenuNode.zPosition = FLZPositionNextLevelOverlayMenu;
  [_nextLevelOverlay addChild:_nextLevelMenuNode];

  // note: Create empty menu for now; update later with FL_commonMenuUpdateSaves.
  HLMenu *menu = [[HLMenu alloc] init];
  [_nextLevelMenuNode setMenu:menu animation:HLMenuNodeAnimationNone];

  _nextLevelMessageNode = [self FL_commonMessageNodeCreate];
  _nextLevelMessageNode.zPosition = FLZPositionNextLevelOverlayMessage;
}

- (void)FL_nextLevelOverlayRelease
{
  _nextLevelOverlay = nil;
  _nextLevelMenuNode = nil;
  _nextLevelMessageNode = nil;
}

- (void)FL_nextLevelOverlayUpdateGeometry
{
  const CGFloat FLMessageSeparator = _nextLevelMenuNode.itemSpacing;
  _nextLevelMessageNode.position = CGPointMake(0.0f, _nextLevelMenuNode.position.y + FLMessageSeparator);
  _nextLevelMessageNode.size = CGSizeMake(_gameScene.size.width, FLMessageNodeHeight);
}

- (void)FL_nextLevelOverlayShowMessage:(NSString *)message
{
  [_nextLevelMessageNode showMessage:message parent:_nextLevelOverlay];
}

+ (HLLabelButtonNode *)FL_sharedMenuButtonPrototypeBasic
{
  static HLLabelButtonNode *buttonPrototype = nil;
  if (!buttonPrototype) {
    buttonPrototype = FLInterfaceLabelButton();
    buttonPrototype.verticalAlignmentMode = HLLabelNodeVerticalAlignFontAscenderBias;
  }
  return buttonPrototype;
}

+ (HLLabelButtonNode *)FL_sharedMenuButtonPrototypeBack
{
  static HLLabelButtonNode *buttonPrototype = nil;
  if (!buttonPrototype) {
    buttonPrototype = [[FLViewController FL_sharedMenuButtonPrototypeBasic] copy];
    buttonPrototype.color = FLInterfaceColorLight();
    buttonPrototype.colorBlendFactor = 1.0f;
  }
  return buttonPrototype;
}

+ (HLLabelButtonNode *)FL_sharedMenuButtonPrototypeSaveGame
{
  static HLLabelButtonNode *buttonPrototype = nil;
  if (!buttonPrototype) {
    buttonPrototype = [[FLViewController FL_sharedMenuButtonPrototypeBasic] copy];
    buttonPrototype.fontSize = 14.0f;
    buttonPrototype.color = FLInterfaceColorMaybe();
    buttonPrototype.colorBlendFactor = 1.0f;
  }
  return buttonPrototype;
}

+ (HLLabelButtonNode *)FL_sharedMenuButtonPrototypeSaveGameEmpty
{
  static HLLabelButtonNode *buttonPrototype = nil;
  if (!buttonPrototype) {
    buttonPrototype = [[FLViewController FL_sharedMenuButtonPrototypeSaveGame] copy];
    buttonPrototype.color = FLInterfaceColorGood();
  }
  return buttonPrototype;
}

- (NSUInteger)FL_commonMenuUpdateSaves:(HLMenu *)saveMenu
                           forGameType:(FLGameType)gameType
                      includeNewButton:(BOOL)includeNewButton
                     includeBackButton:(BOOL)includeBackButton
{
  [saveMenu removeAllItems];

  if (includeNewButton) {
    // note: Create empty "new" menu for now; update later with FL_titleMenuUpdateNew.
    [saveMenu addItem:[HLMenu menuWithText:FLCommonMenuNew items:@[] ]];
  }

  NSUInteger saveCount = 0;
  for (NSUInteger saveNumber = 0; saveNumber < FLSaveGameSlotCount; ++saveNumber) {
    HLMenuItem *saveGameMenuItem = [[HLMenuItem alloc] init];
    NSString *saveLabel = [self FL_saveLabelForGameType:gameType saveNumber:saveNumber];
    if (saveLabel) {
      saveGameMenuItem.text = saveLabel;
      saveGameMenuItem.buttonPrototype = [FLViewController FL_sharedMenuButtonPrototypeSaveGame];
      ++saveCount;
    } else {
      saveGameMenuItem.text = FLCommonMenuEmptySlot;
      saveGameMenuItem.buttonPrototype = [FLViewController FL_sharedMenuButtonPrototypeSaveGameEmpty];
    }
    [saveMenu addItem:saveGameMenuItem];
  }

  if (includeBackButton) {
    [saveMenu addItem:[HLMenuBackItem menuItemWithText:FLCommonMenuBack]];
  }

  return saveCount;
}

- (NSString *)FL_levelPathForGameType:(FLGameType)gameType gameLevel:(int)gameLevel
{
  NSString *gameTypeTag;
  if (gameType == FLGameTypeChallenge) {
    gameTypeTag = FLGameTypeChallengeTag;
  } else {
    [NSException raise:@"FLViewControllerGameTypeInvalid" format:@"Invalid game type %ld for level information.", (long)gameType];
  }
  NSString *fileName = [NSString stringWithFormat:@"level-%@-%d", gameTypeTag, gameLevel];
  return [[NSBundle mainBundle] pathForResource:fileName ofType:@"archive" inDirectory:@"levels"];
}

- (BOOL)FL_saveExistsForGameType:(FLGameType)gameType saveNumber:(NSUInteger)saveNumber
{
  NSString *savePath = [self FL_savePathForGameType:gameType saveNumber:saveNumber];
  return [[NSFileManager defaultManager] fileExistsAtPath:savePath];
}

- (NSString *)FL_saveLabelForGameType:(FLGameType)gameType saveNumber:(NSUInteger)saveNumber
{
  static NSDateFormatter *dateFormatter = nil;
  if (!dateFormatter) {
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
  }

  NSString *savePath = [self FL_savePathForGameType:gameType saveNumber:saveNumber];
  NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:savePath error:nil];
  if (!attributes) {
    return nil;
  }
  NSDate *saveDate = (NSDate *)attributes[NSFileCreationDate];

  NSString *gameTypeSaveTitle;
  switch (gameType) {
    case FLGameTypeChallenge:
      gameTypeSaveTitle = FLGameTypeChallengeTitle();
      break;
    case FLGameTypeSandbox:
      gameTypeSaveTitle = FLGameTypeSandboxTitle();
      break;
    default:
      [NSException raise:@"FLViewControllerGameTypeUnknown" format:@"Unknown game type %ld.", (long)gameType];
  }

  return [NSString stringWithFormat:@"%@ %lu (%@)",
          gameTypeSaveTitle,
          (unsigned long)saveNumber + 1,
          [dateFormatter stringFromDate:saveDate]];
}

- (NSString *)FL_savePathForGameType:(FLGameType)gameType saveNumber:(NSUInteger)saveNumber
{
  NSString *gameTypeTag;
  switch (gameType) {
    case FLGameTypeChallenge:
      gameTypeTag = FLGameTypeChallengeTag;
      break;
    case FLGameTypeSandbox:
      gameTypeTag = FLGameTypeSandboxTag;
      break;
    default:
    [NSException raise:@"FLViewControllerGameTypeUnknown" format:@"Unknown game type %ld.", (long)gameType];
  }
  NSString *fileName = [NSString stringWithFormat:@"save-%@-%lu", gameTypeTag, (unsigned long)saveNumber];
  return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0]
          stringByAppendingPathComponent:[fileName stringByAppendingPathExtension:@"archive"]];
}

- (void)FL_saveFromCommonMenuConfirm:(NSString *)savePath completion:(void(^)(void))completion
{
  if (![[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
    [self FL_saveWithSavePath:savePath completion:completion];
    return;
  }

  UIAlertView *confirmAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Saving will overwrite an old game. Save anyway?",
                                                                                   @"Alert prompt: confirmation of intention to save a game.")
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"Cancel", @"Alert button: cancel save.")
                                               otherButtonTitles:FLGameMenuSave, nil];
  confirmAlert.alertViewStyle = UIAlertViewStyleDefault;
  [confirmAlert show];
  _saveConfirmAlert = confirmAlert;
  _saveConfirmPath = savePath;
  _saveConfirmCompletion = completion;
}

- (void)FL_saveWithSavePath:(NSString *)savePath completion:(void(^)(void))completion
{
  [NSKeyedArchiver archiveRootObject:_gameScene toFile:savePath];
  if (completion) {
    completion();
  }
}

- (void)FL_loadFromTitleMenu:(FLGameType)gameType menuItem:(HLMenuItem *)menuItem itemIndex:(NSUInteger)itemIndex
{
  // note: Item index: First "New" button, then saves (including empties), then "Back" button.
  // We handle it all (for now).

  // note: Both challenge and sandbox have a "New" button, but the challenge one is a
  // special submenu.
  if (itemIndex == 0 && gameType == FLGameTypeChallenge) {
    return;
  }

  if (itemIndex > FLSaveGameSlotCount) {
    return;
  }

  if ([menuItem.text isEqualToString:FLCommonMenuEmptySlot]) {
    [self FL_titleSceneShowMessage:NSLocalizedString(@"No game in slot.",
                                                     @"Menu message: displayed when user selects an empty game slot for loading.")];
    return;
  }

  BOOL isNew = (itemIndex == 0);
  
  NSUInteger saveNumber = (itemIndex - 1);
  [self FL_load:gameType gameLevel:0 isNew:isNew otherwiseSaveNumber:saveNumber];
}

- (void)FL_load:(FLGameType)gameType gameLevel:(int)gameLevel isNew:(BOOL)isNew otherwiseSaveNumber:(NSUInteger)saveNumber
{
  if (!_loadingScene) {
    [self FL_loadingSceneCreate];
  } else {
    [self FL_loadingSceneUpdateGeometry];
  }
  [self FL_loadingSceneReset];
  [self.skView presentScene:_loadingScene];
  _currentScene = _loadingScene;

  [FLTrackScene loadSceneAssetsWithCompletion:^{

    // noob: So this is executed on the main thread by the callback; does that mean
    // the animations on the loading screen will hang until this block completes?

    if (isNew) {
      switch (gameType) {
        case FLGameTypeSandbox:
          self->_gameScene = [[FLTrackScene alloc] initWithSize:self.view.bounds.size gameType:gameType gameLevel:gameLevel];
          self->_gameScene.delegate = self;
          self->_gameScene.scaleMode = SKSceneScaleModeResizeFill;
          self->_gameScene.gameIsNew = YES;
          break;
        case FLGameTypeChallenge: {
          NSString *levelPath = [self FL_levelPathForGameType:gameType gameLevel:gameLevel];
          self->_gameScene = [NSKeyedUnarchiver unarchiveObjectWithFile:levelPath];
          if (!self->_gameScene) {
            [NSException raise:@"FLGameLoadFailure" format:@"Could not load new game type %ld level %d from archive '%@'.", (long)gameType, gameLevel, levelPath];
          }
          // note: Scene size in archive might be different from our current scene size;
          // this happens most often when unarchiving a level that was created on a different
          // device (or device simulation).  It's possible that the scaleMode of resize-fill
          // should realize this and use the correct size when it is presented, but apparently
          // (at least with current SDK) it does not.
          self->_gameScene.size = self.view.bounds.size;
          self->_gameScene.delegate = self;
          // note: Check that the archive has the correct level and game type in the archive.  We'd like
          // to be able to change it at will, but the track scene doesn't currently support changing it
          // (because of the maintenance headache of trying to figure out what interface elements depend
          // on game type and level).  Instead, we insist that the archive be what we expected.
          if (self->_gameScene.gameType != gameType || self->_gameScene.gameLevel != gameLevel) {
            [NSException raise:@"FLGameLoadFailure" format:@"Archive '%@' has game type %ld and game %d but expected game type %ld and level %d.",
             levelPath, (long)self->_gameScene.gameType, self->_gameScene.gameLevel, (long)gameType, gameLevel];
          }
          self->_gameScene.gameIsNew = YES;
          break;
        }
        default:
          [NSException raise:@"FLViewControllerGameTypeUnknown" format:@"Unknown game type %ld.", (long)gameType];
      }
    } else {
      NSString *savePath = [self FL_savePathForGameType:gameType saveNumber:saveNumber];
      self->_gameScene = [NSKeyedUnarchiver unarchiveObjectWithFile:savePath];
      if (!self->_gameScene) {
        [NSException raise:@"FLGameLoadFailure" format:@"Could not load game type %ld save number %lu from archive '%@'.", (long)gameType, (unsigned long)saveNumber, savePath];
      }
      self->_gameScene.size = self.view.bounds.size;
      self->_gameScene.delegate = self;
      // note: Trust the archive with game type and level information, for now; ignore passed values.
    }

    [self.skView presentScene:self->_gameScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
    self->_currentScene = self->_gameScene;

  }];
}

- (void)FL_deleteFromTitleMenuConfirm:(FLGameType)gameType menuItem:(HLMenuItem *)menuItem itemIndex:(NSUInteger)itemIndex
{
  // note: Item index: First "New" button, then saves (including empties), then "Back" button.
  // We handle it all (for now).

  if (itemIndex == 0 || itemIndex > FLSaveGameSlotCount) {
    return;
  }
  if ([menuItem.text isEqualToString:FLCommonMenuEmptySlot]) {
    return;
  }
  
  NSUInteger saveNumber = (itemIndex - 1);
  NSString *savePath = [self FL_savePathForGameType:gameType saveNumber:saveNumber];
  if (!savePath || ![[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
    return;
  }

  NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Permanently delete game “%@”?",
                                                                 @"Alert prompt: confirmation of intention to delete a {saved game}."),
                     menuItem.text];
  UIAlertView *confirmAlert = [[UIAlertView alloc] initWithTitle:title
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"Cancel", @"Alert button: cancel game deletion.")
                                               otherButtonTitles:NSLocalizedString(@"Delete", @"Alert button: delete game"), nil];
  confirmAlert.alertViewStyle = UIAlertViewStyleDefault;
  [confirmAlert show];
  _deleteConfirmAlert = confirmAlert;
  _deleteConfirmPath = savePath;
  HLMenu *menuItemParent = menuItem.parent;
  NSArray *menuItemParentPath = menuItemParent.path;
  __weak id selfWeak = self;
  _deleteConfirmCompletion = ^{
    FLViewController *selfStrongAgain = selfWeak;
    if (selfStrongAgain) {
      [selfStrongAgain FL_commonMenuUpdateSaves:menuItem.parent forGameType:gameType includeNewButton:YES includeBackButton:YES];
      HLMenuNode *titleMenuNode = selfStrongAgain->_titleMenuNode;
      [titleMenuNode navigateToSubmenuWithPath:menuItemParentPath animation:HLMenuNodeAnimationNone];
      [selfStrongAgain FL_titleSceneShowMessage:NSLocalizedString(@"Deleted game.",
                                                                  @"Menu message: displayed when a game has been deleted.")];
    }
  };
}

- (void)FL_deleteWithSavePath:(NSString *)savePath completion:(void(^)(void))completion
{
  [[NSFileManager defaultManager] removeItemAtPath:savePath error:NULL];
  if (completion) {
    completion();
  }
}

- (void)FL_restartFromGameMenuConfirm
{
  if (_savedInGameOverlay) {
    [self FL_restart];
    return;
  }

  NSString *title;
  switch (_gameScene.gameType) {
    case FLGameTypeChallenge:
      title = NSLocalizedString(@"All unsaved changes to the level will be lost. Restart level anyway?",
                                @"Alert prompt: confirmation of intention to restart a level of a challenge game.");
      break;
    case FLGameTypeSandbox:
      title = NSLocalizedString(@"The sandbox will be completely cleared and all unsaved progress will be lost. Restart anyway?",
                                @"Alert prompt: confirmation of intention to restart a sandbox game.");
      break;
    default:
      [NSException raise:@"FLViewControllerGameTypeUnknown" format:@"Unknown game type %ld.", (long)_gameScene.gameType];
  }

  UIAlertView *confirmAlert = [[UIAlertView alloc] initWithTitle:title
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"Cancel", @"Alert button: cancel restart.")
                                               otherButtonTitles:FLGameMenuRestart, nil];
  confirmAlert.alertViewStyle = UIAlertViewStyleDefault;
  [confirmAlert show];
  _restartConfirmAlert = confirmAlert;
}

- (void)FL_restart
{
  [self FL_load:_gameScene.gameType gameLevel:_gameScene.gameLevel isNew:YES otherwiseSaveNumber:0];
}

- (void)FL_helpOverlayCreate
{
  _helpOverlay = [[HLScrollNode alloc] init];
  _helpOverlay.contentNode = [SKSpriteNode spriteNodeWithColor:[SKColor clearColor] size:CGSizeZero];

  NSString *path = [[NSBundle mainBundle] pathForResource:@"Help" ofType:@"plist"];
  NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
  NSArray *helpItems = (NSArray *)[NSPropertyListSerialization propertyListWithData:data
                                                                            options:NSPropertyListImmutable
                                                                             format:NULL
                                                                              error:NULL];
  // note: Hacky: Headers are the first entry, and every entry after an empty entry.
  BOOL isHeader = YES;
  for (NSString *helpItem in helpItems) {
    DSMultilineLabelNode *helpItemNode = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    if (isHeader) {
      helpItemNode.fontColor = FLInterfaceColorMaybe();
      helpItemNode.fontSize = 16.0f;
    } else {
      helpItemNode.fontColor = [SKColor whiteColor];
      helpItemNode.fontSize = 14.0f;
    }
    helpItemNode.text = helpItem;
    [_helpOverlay.contentNode addChild:helpItemNode];
    isHeader = (!helpItem || [helpItem length] == 0);
  }

  [_helpOverlay hlSetGestureTarget:_helpOverlay];
  HLTapGestureTarget *helpContentGestureTarget = [HLTapGestureTarget tapGestureTargetWithHandleGestureBlock:^(UIGestureRecognizer *gestureRecognizer){
    [self->_gameScene unregisterDescendant:self->_helpOverlay];
    [self->_gameScene unregisterDescendant:self->_helpOverlay.contentNode];
    [self->_gameScene dismissModalNodeAnimation:HLScenePresentationAnimationFade];
  }];
  helpContentGestureTarget.gestureTransparent = YES;
  [_helpOverlay.contentNode hlSetGestureTarget:helpContentGestureTarget];
}

- (void)FL_helpOverlayRelease
{
  _helpOverlay = nil;
}

- (void)FL_helpOverlayUpdateGeometry
{
  const CGFloat FLHelpTextPad = 10.0f;
  const CGFloat FLHelpTextSpacer = 8.0f;

  // note: Using content node for two purposes: 1) to organize help text; 2) to serve
  // as a node that covers everything and handles tap to dismiss the modal presentation.
  SKSpriteNode *helpContentNode = (SKSpriteNode *)_helpOverlay.contentNode;

  CGFloat paragraphWidth = MIN(_gameScene.size.width - FLHelpTextPad * 2.0f,
                               FLDSMultilineLabelParagraphWidthReadableMax);

  CGFloat helpItemTotalHeight = 0.0f;
  for (DSMultilineLabelNode *helpItemNode in helpContentNode.children) {
    helpItemNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
    helpItemNode.anchorPoint = CGPointMake(0.0f, 1.0f);
    helpItemNode.paragraphWidth = paragraphWidth - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
    helpItemTotalHeight += helpItemNode.size.height;
  }
  helpItemTotalHeight += FLHelpTextSpacer * ([helpContentNode.children count] - 1) + FLHelpTextPad * 2.0f;
  CGFloat helpItemPositionX = -paragraphWidth / 2.0f + FLHelpTextPad;
  CGFloat helpItemPositionY = helpItemTotalHeight / 2.0f - FLHelpTextPad;
  for (DSMultilineLabelNode *helpItemNode in helpContentNode.children) {
    helpItemNode.position = CGPointMake(helpItemPositionX, helpItemPositionY);
    helpItemPositionY -= helpItemNode.size.height + FLHelpTextSpacer;
  }

  CGSize contentSize = CGSizeMake(_gameScene.size.width,
                                  MAX(_gameScene.size.height, helpItemTotalHeight));
  _helpOverlay.size = _gameScene.size;
  _helpOverlay.contentSize = contentSize;
  helpContentNode.size = contentSize;
  if (_gameScene.size.height < helpItemTotalHeight) {
    _helpOverlay.contentOffset = CGPointMake(0.0f, -contentSize.height / 2.0f);
  }
}

- (void)FL_helpFromGameMenu
{
  [_gameScene dismissModalNodeAnimation:HLScenePresentationAnimationFade];
  if (!_helpOverlay) {
    [self FL_helpOverlayCreate];
    [self FL_helpOverlayUpdateGeometry];
  }
  [_gameScene registerDescendant:_helpOverlay withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  [_gameScene registerDescendant:_helpOverlay.contentNode withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  [_gameScene presentModalNode:_helpOverlay animation:HLScenePresentationAnimationFade];
}

- (void)FL_aboutOverlayCreate
{
  const CGFloat FLAboutItemPad = 15.0f;
  const CGFloat FLAboutItemSpacer = 10.0f;

  _aboutOverlay = [[HLScrollNode alloc] init];
  // note: Using content node for two purposes: 1) to organize about text; 2) to serve
  // as a node that covers everything and handles tap to dismiss the modal presentation.
  SKSpriteNode *aboutContentNode = [SKSpriteNode spriteNodeWithColor:[SKColor colorWithWhite:0.0f alpha:0.8f] size:CGSizeZero];
  _aboutOverlay.contentNode = aboutContentNode;

  // note: Show multiline text in a square that won't have to change size if the interface
  // rotates to a narrower horizontal dimension.
  CGFloat edgeSizeMax = MIN(MIN(_titleScene.size.width, _titleScene.size.height) - FLAboutItemPad * 2.0f,
                            FLDSMultilineLabelParagraphWidthReadableMax);

  NSMutableArray *aboutItems = [NSMutableArray array];

  SKSpriteNode *companyImage = [SKSpriteNode spriteNodeWithImageNamed:@"hilo-icon-128-background.png"];
  [aboutItems addObject:companyImage];
  
  DSMultilineLabelNode *companyLabel = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  companyLabel.fontSize = 18.0f;
  companyLabel.fontColor = [SKColor whiteColor];
  companyLabel.text = @"Hilo Games";
  companyLabel.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
  [aboutItems addObject:companyLabel];
  
  DSMultilineLabelNode *contactLabel = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  contactLabel.fontSize = 14.0f;
  contactLabel.fontColor = FLInterfaceColorLight();
  contactLabel.text = @"Karl Voskuil\nkarl@hilogames.com";
  contactLabel.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
  [aboutItems addObject:contactLabel];
  
  DSMultilineLabelNode *creditsLabel = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  creditsLabel.fontSize = 12.0f;
  creditsLabel.fontColor = FLInterfaceColorSunny();
  creditsLabel.text = @"Grass texture from www.goodtextures.com."
  "\nMulti-line label node (DSMultilineLabelNode) from Downright Simple (github.com/downrightsimple)."
  "\nEverything else Karl Voskuil / hilogames.com.";
  creditsLabel.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
  [aboutItems addObject:creditsLabel];
  
  DSMultilineLabelNode *sourceCodeLabel = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  sourceCodeLabel.fontSize = 12.0f;
  sourceCodeLabel.fontColor = [SKColor whiteColor];
  sourceCodeLabel.text = @"Some or all of the source code for Flippy the Train is available under MIT License from github.com/hilogames.";
  sourceCodeLabel.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
  [aboutItems addObject:sourceCodeLabel];
  
  _aboutItemsHeight = FLAboutItemPad * 2.0f;
  for (id aboutItem in aboutItems) {
    CGSize aboutItemSize = [aboutItem size];
    _aboutItemsHeight += aboutItemSize.height + FLAboutItemPad;
  }
  CGFloat aboutItemPositionY = _aboutItemsHeight / 2.0f - FLAboutItemPad;
  for (id aboutItem in aboutItems) {
    [aboutItem setAnchorPoint:CGPointMake(0.5f, 1.0f)];
    [aboutItem setPosition:CGPointMake(0.0f, aboutItemPositionY)];
    [aboutContentNode addChild:aboutItem];
    CGSize aboutItemSize = [aboutItem size];
    aboutItemPositionY -= (aboutItemSize.height + FLAboutItemSpacer);
  }

  [_aboutOverlay hlSetGestureTarget:_aboutOverlay];
  HLTapGestureTarget *aboutContentGestureTarget = [HLTapGestureTarget tapGestureTargetWithHandleGestureBlock:^(UIGestureRecognizer *gestureRecognizer){
    [self->_titleScene unregisterDescendant:self->_aboutOverlay];
    [self->_titleScene unregisterDescendant:self->_aboutOverlay.contentNode];
    [self->_titleScene dismissModalNodeAnimation:HLScenePresentationAnimationFade];
  }];
  aboutContentGestureTarget.gestureTransparent = YES;
  [_aboutOverlay.contentNode hlSetGestureTarget:aboutContentGestureTarget];
}

- (void)FL_aboutOverlayRelease
{
  _aboutOverlay = nil;
}

- (void)FL_aboutOverlayUpdateGeometry
{
  SKSpriteNode *aboutContentNode = (SKSpriteNode *)_aboutOverlay.contentNode;

  _aboutOverlay.size = _titleScene.size;
  CGSize contentSize = CGSizeMake(_titleScene.size.width,
                                  MAX(_titleScene.size.height, _aboutItemsHeight));
  _aboutOverlay.contentSize = contentSize;
  aboutContentNode.size = contentSize;

  if (_titleScene.size.height < aboutContentNode.size.height) {
    _aboutOverlay.contentOffset = CGPointMake(0.0f, -aboutContentNode.size.height / 2.0f);
  }
}

- (void)FL_aboutFromTitleMenu
{
  if (!_aboutOverlay) {
    [self FL_aboutOverlayCreate];
    [self FL_aboutOverlayUpdateGeometry];
  }
  [_titleScene registerDescendant:_aboutOverlay withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  [_titleScene registerDescendant:_aboutOverlay.contentNode withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  [_titleScene presentModalNode:_aboutOverlay animation:HLScenePresentationAnimationFade zPositionMin:FLZPositionTitleModalPresentationMin zPositionMax:FLZPositionTitleModalPresentationMax];
}

- (void)FL_exitFromGameMenuConfirm
{
  if (_savedInGameOverlay) {
    [self FL_exitFromGameMenu];
    return;
  }

  UIAlertView *confirmAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Unsaved changes will be lost. Exit anyway?",
                                                                                   @"Alert prompt: confirmation of intention to exit a game.")
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"Cancel", @"Alert button: cancel exit.")
                                               otherButtonTitles:FLGameMenuExit, nil];
  confirmAlert.alertViewStyle = UIAlertViewStyleDefault;
  [confirmAlert show];
  _exitConfirmAlert = confirmAlert;
}

- (void)FL_exitFromGameMenu
{
  // noob: If this is animated, for example using fade, then we have problems.  I haven't
  // investigated fully, but I suppose there might be a problem with running an action on
  // a node which suddenly stops being part of the active scene.  Or something.  Anyway,
  // we don't want animation for the modal node; we want animation to transition to the
  // title scene.
  [_gameScene dismissModalNodeAnimation:HLScenePresentationAnimationNone];

  _gameScene = nil;

  if (!_titleScene) {
    [self FL_titleSceneCreate];
  } else {
    [self FL_titleSceneUpdateGeometry];
    [self FL_titleSceneHideMessage];
    HLMenuNode *titleMenuNode = _titleMenuNode;
    [titleMenuNode navigateToTopMenuAnimation:HLMenuNodeAnimationNone];
  }
  [self.skView presentScene:_titleScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
  _currentScene = _titleScene;
}

- (void)FL_resetAppFromTitleMenuConfirm
{
  UIAlertView *confirmAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Game will be restored to its newly-installed state; all saved games will be deleted. Reset app?",
                                                                                   @"Alert prompt: confirmation of intention to reset app.")
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"Cancel", @"Alert button: cancel reset.")
                                               otherButtonTitles:FLTitleMenuResetApp, nil];
  confirmAlert.alertViewStyle = UIAlertViewStyleDefault;
  [confirmAlert show];
  _resetAppConfirmAlert = confirmAlert;
}

- (void)FL_resetAppFromTitleMenu
{
  // note: Rather than "restoring the app to its newly-installed state", we could make
  // a smaller claim: Reset tutorial, unlocks, and saved games.  In that case we could
  // do all that stuff here.  But if it's a full factory reset we want, then that's the
  // purview of the global application, not just this view controller.
  [FLApplication applicationReset];
  [self FL_titleSceneShowMessage:NSLocalizedString(@"App reset.",
                                                   @"Menu message: displayed when the app has been reset.")];
}

- (void)FL_resetUnlocksFromTitleMenuConfirm
{
  UIAlertView *confirmAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Saved games will be preserved, but all unlocked features and records will be lost. Reset unlocks?",
                                                                                   @"Alert prompt: confirmation of intention to reset unlocks.")
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"Cancel", @"Alert button: cancel reset.")
                                               otherButtonTitles:FLTitleMenuResetUnlocks, nil];
  confirmAlert.alertViewStyle = UIAlertViewStyleDefault;
  [confirmAlert show];
  _resetUnlocksConfirmAlert = confirmAlert;
}

- (void)FL_resetUnlocksFromTitleMenu
{
  FLUserRecordsResetAll();
  BOOL tutorialCompleted = FLUserUnlocksUnlocked(@"FLUserUnlockTutorialCompleted");
  FLUserUnlocksResetAll();
  if (tutorialCompleted) {
    FLUserUnlocksUnlock(@[ @"FLUserUnlockTutorialCompleted" ]);
  }
  [self FL_titleSceneShowMessage:NSLocalizedString(@"Unlocks reset.",
                                                   @"Menu message: displayed when unlocks have been reset.")];
}

- (void)FL_resetTutorialFromTitleMenuConfirm
{
  UIAlertView *confirmAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"The tutorial will start over on the next new game. Reset tutorial?",
                                                                                   @"Alert prompt: confirmation of intention to reset tutorial.")
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"Cancel", @"Alert button: cancel reset.")
                                               otherButtonTitles:FLTitleMenuResetTutorial, nil];
  confirmAlert.alertViewStyle = UIAlertViewStyleDefault;
  [confirmAlert show];
  _resetTutorialConfirmAlert = confirmAlert;
}

- (void)FL_resetTutorialFromTitleMenu
{
  FLUserUnlocksReset(@"FLUserUnlockTutorialCompleted");
  [self FL_titleSceneShowMessage:NSLocalizedString(@"Tutorial reset.",
                                                   @"Menu message: displayed when the tutorial has been reset.")];
}

- (void)FL_nextLevel
{
  [_gameScene dismissModalNodeAnimation:HLScenePresentationAnimationNone];

  int levelCount = FLChallengeLevelsCount();
  FLGameType gameType = _gameScene.gameType;
  int nextLevel = _gameScene.gameLevel + 1;
  if (nextLevel < levelCount) {
    // noob: So this method is called by a block (in the scene) which may or may
    // not contain the correct kind of references to the objects it needs to finish.
    // But it seems to be working for now, even though I delete its scene out from
    // under it.  More noobish notes are in FLTrackScene at the block invocation
    // site, and also further back in the FLGoalsNode handler which kicks off the whole
    // process with the "Next Level" button.
    [self FL_load:gameType gameLevel:nextLevel isNew:YES otherwiseSaveNumber:0];
  }
}

@end
