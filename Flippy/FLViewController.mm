//
//  FLViewController.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLViewController.h"

#import "FLTrackScene.h"
#import <HLSpriteKit/HLError.h>

typedef enum FLViewControllerScene { FLViewControllerSceneNone, FLViewControllerSceneTitle, FLViewControllerSceneGame } FLViewControllerScene;

static const CGFloat FLZPositionTitleBackground = 1.0f;
static const CGFloat FLZPositionTitleMenu = 2.0f;
static const CGFloat FLZPositionTitleMessage = 3.0f;

static NSString * const FLExtraStateName = @"extra-application-state";
static NSString * FLExtraStatePath;

static const NSTimeInterval FLSceneTransitionDuration = 0.5;
static const NSTimeInterval FLOffscreenSlideDuration = 0.25;

static const CGFloat FLMessageNodeHeight = 32.0f;

static const NSUInteger FLSaveGameSlotCount = 3;

static NSString * const FLSaveLabelChallenge = @"Game";
static NSString * const FLSaveLabelSandbox = @"Sandbox";

static NSString * const FLGameTypeChallenge = @"challenge";
static NSString * const FLGameTypeSandbox = @"sandbox";

static NSString * const FLCommonMenuBack = @"Back";
static NSString * const FLCommonMenuEmptySlot = @"(Empty)";
static NSString * const FLCommonMenuNew = @"New";

static NSString * const FLTitleMenuChallenge = @"Play";
static NSString * const FLTitleMenuChallengeNewPath = @"Play/New";
static NSString * const FLTitleMenuSandbox = @"Sandbox";
static NSString * const FLTitleMenuSandboxNewPath = @"Sandbox/New";
static NSString * const FLTitleMenuAbout = @"About";

static NSString * const FLGameMenuResume = @"Resume";
static NSString * const FLGameMenuSave = @"Save";
static NSString * const FLGameMenuExit = @"Exit";

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
  BOOL _savedInGameOverlay;

  UIAlertView *_saveConfirmAlert;
  NSString *_saveConfirmPath;
  UIAlertView *_exitConfirmAlert;
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

  FLViewControllerScene currentScene = (FLViewControllerScene)[coder decodeIntForKey:@"currentScene"];
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
    if (!_titleScene) {
      [self FL_titleSceneCreate];
    }
    _currentScene = _titleScene;
  }

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
  if (menuNode == _titleMenuNode) {

    if ([menuItem.text isEqualToString:FLTitleMenuSandbox]) {
      NSUInteger saveCount = [self FL_commonMenuUpdateSaves:(HLMenu *)menuItem forGameType:FLGameTypeSandbox includeNewButton:YES];
      // note: The important thing is the update of the menu, above.  But as a bonus, go straight
      // to new game if there are no saves.
      if (saveCount == 0) {
        [self FL_load:FLGameTypeSandbox isNew:YES otherwiseSaveNumber:0];
        return NO;
      }
    } else if ([menuItem.text isEqualToString:FLTitleMenuChallenge]) {
      NSUInteger saveCount = [self FL_commonMenuUpdateSaves:(HLMenu *)menuItem forGameType:FLGameTypeChallenge includeNewButton:YES];
      // note: The important thing is the update of the menu, above.  But as a bonus, go straight
      // to new game if there are no saves.
      if (saveCount == 0) {
        [self FL_load:FLGameTypeChallenge isNew:YES otherwiseSaveNumber:0];
        return NO;
      }
    }

    return YES;
  }
  
  if (menuNode == _gameMenuNode) {

    if ([menuItem.text isEqualToString:FLGameMenuSave]) {
      // TODO: If _gameScene is a challenge game, then update menu for FLGameTypeChallenge.
      [self FL_commonMenuUpdateSaves:(HLMenu *)menuItem forGameType:FLGameTypeSandbox includeNewButton:NO];
      [self FL_gameOverlayShowMessage:@"Choose save game slot."];
    }

    return YES;
  }

  return YES;
}

- (void)menuNode:(HLMenuNode *)menuNode didTapMenuItem:(HLMenuItem *)menuItem itemIndex:(NSUInteger)itemIndex
{
  NSLog(@"did tap menu item %@", [menuItem path]);
  HLMenuItem *menuItemParent = menuItem.parent;

  if (menuNode == _titleMenuNode) {

    if ([menuItem.text isEqualToString:FLTitleMenuChallenge]) {
      [self FL_titleSceneShowMessage:@"Choose game to load."];
    } else if ([menuItem.text isEqualToString:FLTitleMenuSandbox]) {
      [self FL_titleSceneShowMessage:@"Choose game to load."];
    } else if ([menuItemParent.text isEqualToString:FLTitleMenuChallenge]) {
      [self FL_loadFromTitleMenu:FLGameTypeChallenge menuItem:menuItem itemIndex:itemIndex];
    } else if ([menuItemParent.text isEqualToString:FLTitleMenuSandbox]) {
      [self FL_loadFromTitleMenu:FLGameTypeSandbox menuItem:menuItem itemIndex:itemIndex];
    }
    
    return;
  }

  if (menuNode == _gameMenuNode) {

    if ([menuItem.text isEqualToString:FLGameMenuResume]) {
      [_gameScene dismissModalNode];
    } else if ([menuItemParent.text isEqualToString:FLGameMenuSave]) {
      if (![menuItem isKindOfClass:[HLMenuBackItem class]]) {
        _savedInGameOverlay = YES;
        // TODO: If _gameScene is a challenge game, then save game for FLGameTypeChallenge.
        NSString *savePath = [self FL_savePathForGameType:FLGameTypeSandbox saveNumber:itemIndex];
        [self FL_saveFromGameMenuConfirm:savePath];
      }
    } else if ([menuItem.text isEqualToString:FLGameMenuExit]) {
      [self FL_exitFromGameMenuConfirm];
    }

    return;
  }
}

#pragma mark -
#pragma mark FLTrackSceneDelegate

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene
{
  if (!_gameOverlay) {
    [self FL_gameOverlayCreate];
  }

  [_gameMenuNode navigateToTopMenuAnimation:HLMenuNodeAnimationNone];
  [_gameMessageNode hideMessage];

  // note: Register (or re-register) the menu node for gesture handling.  We're
  // being a bit sloppy here: The same modal overaly and menu node is used for
  // all games, and so we only really need to register for the first appearance
  // over a scene, but the call is idempotent, so it's okay.  And then really we
  // should unregister when the modal node is dismissed, we don't bother.
  [_gameScene registerDescendant:_gameMenuNode withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  [_gameScene presentModalNode:_gameOverlay];

  _savedInGameOverlay = NO;
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
      [self FL_saveFromGameMenu:_saveConfirmPath];
    }
  }
}

#pragma mark -
#pragma mark Common

- (HLMenuNode *)FL_commonMenuNodeCreate
{
  HLMenuNode *menuNode = [[HLMenuNode alloc] init];
  menuNode.delegate = self;
  menuNode.position = CGPointMake(0.0f, 48.0f);
  menuNode.itemAnimation = HLMenuNodeAnimationSlideLeft;
  menuNode.itemAnimationDuration = FLOffscreenSlideDuration;
  menuNode.itemButtonPrototype = [FLViewController FL_sharedMenuButtonPrototypeBasic];
  menuNode.itemSpacing = 48.0f;
  menuNode.itemSoundFile = @"wooden-click-1.caf";
  return menuNode;
}

- (HLMessageNode *)FL_commonMessageNodeCreate
{
  HLMessageNode *messageNode = [[HLMessageNode alloc] initWithColor:[UIColor colorWithWhite:1.0f alpha:0.5f] size:CGSizeZero];
  messageNode.verticalAlignmentMode = HLLabelNodeVerticalAlignFontAscenderBias;
  messageNode.messageAnimationDuration = FLOffscreenSlideDuration;
  messageNode.messageLingerDuration = 2.0;
  messageNode.fontName = @"Courier";
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
  SKLabelNode *loadingLabelNode = [SKLabelNode labelNodeWithFontNamed:@"Courier"];
  loadingLabelNode.fontSize = 18.0f;
  loadingLabelNode.text = @"Loading...";
  SKAction *pulse = [SKAction sequence:@[ [SKAction fadeAlphaTo:0.5f duration:FLLoadingPulseDuration],
                                          [SKAction fadeAlphaTo:1.0f duration:FLLoadingPulseDuration] ]];
  pulse.timingMode = SKActionTimingEaseInEaseOut;
  [loadingLabelNode runAction:[SKAction repeatActionForever:pulse]];
  [_loadingScene addChild:loadingLabelNode];
}

- (void)FL_titleSceneCreate
{
  _titleScene = [HLScene sceneWithSize:self.view.bounds.size];
  _titleScene.scaleMode = SKSceneScaleModeResizeFill;
  _titleScene.anchorPoint = CGPointMake(0.5f, 0.5f);
  
  SKSpriteNode *backgroundNode = [SKSpriteNode spriteNodeWithImageNamed:@"grass"];
  backgroundNode.zPosition = FLZPositionTitleBackground;
  [_titleScene addChild:backgroundNode withOptions:[NSSet setWithObject:HLSceneChildResizeWithScene]];

  HLMenuNode *titleMenuNode = [self FL_commonMenuNodeCreate];
  titleMenuNode.zPosition = FLZPositionTitleMenu;
  [_titleScene addChild:titleMenuNode withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  _titleMenuNode = titleMenuNode;

  [self FL_titleMenuCreate];
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
  [menu addItem:[HLMenu menuWithText:FLTitleMenuChallenge
                               items:@[ [HLMenuItem menuItemWithText:FLCommonMenuNew],
                                        [HLMenuBackItem menuItemWithText:FLCommonMenuBack] ]]];
  [menu addItem:[HLMenu menuWithText:FLTitleMenuSandbox
                               items:@[ [HLMenuItem menuItemWithText:FLCommonMenuNew],
                                        [HLMenuBackItem menuItemWithText:FLCommonMenuBack] ]]];
  [menu addItem:[HLMenuItem menuItemWithText:FLTitleMenuAbout]];

  HLMenuNode *titleMenuNode = _titleMenuNode;
  [titleMenuNode setMenu:menu animation:HLMenuNodeAnimationNone];
}

- (void)FL_gameOverlayCreate
{
  _gameOverlay = [SKNode node];

  _gameMenuNode = [self FL_commonMenuNodeCreate];
  [_gameOverlay addChild:_gameMenuNode];

  [self FL_gameMenuCreate];

  _gameMessageNode = [self FL_commonMessageNodeCreate];
}

- (void)FL_gameOverlayShowMessage:(NSString *)message
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
  // our own geometry changes.  But easier to do it for every message, for now.
  _gameMessageNode.position = CGPointMake(0.0f, _gameMenuNode.position.y + _gameMenuNode.itemSpacing);
  _gameMessageNode.size = CGSizeMake(_gameScene.size.width, FLMessageNodeHeight);
  
  [_gameMessageNode showMessage:message parent:_gameOverlay];
}

- (void)FL_gameMenuCreate
{
  HLMenu *menu = [[HLMenu alloc] init];
  [menu addItem:[HLMenuItem menuItemWithText:FLGameMenuResume]];
  // note: Create empty save menu for now; update later with FL_menuUpdateSaves.
  [menu addItem:[HLMenu menuWithText:FLGameMenuSave items:@[]]];
  [menu addItem:[HLMenuItem menuItemWithText:FLGameMenuExit]];
  [_gameMenuNode setMenu:menu animation:HLMenuNodeAnimationNone];
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
    buttonPrototype.verticalAlignmentMode = HLLabelNodeVerticalAlignFontAscenderBias;
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

- (NSUInteger)FL_commonMenuUpdateSaves:(HLMenu *)saveMenu forGameType:(NSString *)gameType includeNewButton:(BOOL)includeNewButton
{
  [saveMenu removeAllItems];

  if (includeNewButton) {
    [saveMenu addItem:[HLMenuItem menuItemWithText:FLCommonMenuNew]];
  }
  
  NSUInteger saveCount = 0;
  for (NSUInteger saveNumber = 0; saveNumber < FLSaveGameSlotCount; ++saveNumber) {
    HLMenuItem *saveGameMenuItem = [[HLMenuItem alloc] init];
    NSString *saveName = [self FL_saveNameForGameType:gameType saveNumber:saveNumber];
    if (saveName) {
      saveGameMenuItem.text = saveName;
      saveGameMenuItem.buttonPrototype = [FLViewController FL_sharedMenuButtonPrototypeSaveGame];
      ++saveCount;
    } else {
      saveGameMenuItem.text = FLCommonMenuEmptySlot;
      saveGameMenuItem.buttonPrototype = [FLViewController FL_sharedMenuButtonPrototypeSaveGameEmpty];
    }
    [saveMenu addItem:saveGameMenuItem];
  }
  
  [saveMenu addItem:[HLMenuBackItem menuItemWithText:FLCommonMenuBack]];
  return saveCount;
}

- (BOOL)FL_saveExistsForGameType:(NSString *)gameType saveNumber:(NSUInteger)saveNumber
{
  NSString *savePath = [self FL_savePathForGameType:gameType saveNumber:saveNumber];
  return [[NSFileManager defaultManager] fileExistsAtPath:savePath];
}

- (NSString *)FL_saveNameForGameType:(NSString *)gameType saveNumber:(NSUInteger)saveNumber
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
  NSDate *saveDate = (NSDate *)[attributes objectForKey:NSFileCreationDate];

  NSString *gameTypeSaveLabel;
  if ([gameType isEqualToString:FLGameTypeChallenge]) {
    gameTypeSaveLabel = FLSaveLabelChallenge;
  } else if ([gameType isEqualToString:FLGameTypeSandbox]) {
    gameTypeSaveLabel = FLSaveLabelSandbox;
  } else {
    [NSException raise:@"FLViewControllerGameTypeUnknown" format:@"Unknown game type '%@'.", gameType];
  }
  
  return [NSString stringWithFormat:@"%@ %lu (%@)",
          gameTypeSaveLabel,
          (unsigned long)saveNumber + 1,
          [dateFormatter stringFromDate:saveDate]];
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
  _saveConfirmPath = savePath;
}

- (void)FL_saveFromGameMenu:(NSString *)savePath
{
  [NSKeyedArchiver archiveRootObject:_gameScene toFile:savePath];
  [_gameMenuNode navigateToTopMenuAnimation:HLMenuNodeAnimationNone];
  [self FL_gameOverlayShowMessage:@"Game saved."];
}

- (void)FL_loadFromTitleMenu:(NSString *)gameType menuItem:(HLMenuItem *)menuItem itemIndex:(NSUInteger)itemIndex
{
  // note: Item index: First "New" button, then saves (including empties), then "Back" button.
  // We handle it all (for now).

  if (itemIndex > FLSaveGameSlotCount) {
    return;
  }

  if ([menuItem.text isEqualToString:FLCommonMenuEmptySlot]) {
    [self FL_titleSceneShowMessage:@"No game in slot."];
    return;
  }

  BOOL isNew = (itemIndex == 0);

  [self FL_load:gameType isNew:isNew otherwiseSaveNumber:(itemIndex - 1)];
}

- (void)FL_load:(NSString *)gameType isNew:(BOOL)isNew otherwiseSaveNumber:(NSUInteger)saveNumber
{
  if (isNew) {
    _gameScene = [FLTrackScene sceneWithSize:self.view.bounds.size];
    _gameScene.delegate = self;
    _gameScene.scaleMode = SKSceneScaleModeResizeFill;
    // TODO: Set up for challenge vs sandbox game.
  }

  // Bypass loading screen if short load time is guaranteed.
  if (isNew && [FLTrackScene sceneAssetsLoaded]) {
    [self.skView presentScene:_gameScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
    _currentScene = _gameScene;
    return;
  }
  
  if (!_loadingScene) {
    [self FL_loadingSceneCreate];
  }
  [self.skView presentScene:_loadingScene];

  [FLTrackScene loadSceneAssetsWithCompletion:^{

    // noob: So this is executed on the main thread by the callback; does that mean
    // the animations on the loading screen will hang while we're loading?

    if (!isNew) {
      NSString *savePath = [self FL_savePathForGameType:gameType saveNumber:saveNumber];
      // note: Scene size can be wrong in simulator when loading game on different device.  This might
      // be identical or related to the problem documented in viewWillAppear, because it seems similarly
      // fishy: After we unarchive a scene with scaleMode SKSceneScaleModeResizeFill, shouldn't it
      // resize itself immediately when presented in the view?
      self->_gameScene = [NSKeyedUnarchiver unarchiveObjectWithFile:savePath];
      self->_gameScene.delegate = self;
    }

    [self.skView presentScene:self->_gameScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
    self->_currentScene = self->_gameScene;
  }];
}

- (void)FL_exitFromGameMenuConfirm
{
  if (_savedInGameOverlay) {
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
  [_gameScene dismissModalNode];
  if (!_titleScene) {
    [self FL_titleSceneCreate];
  } else {
    [self FL_titleSceneHideMessage];
    HLMenuNode *titleMenuNode = _titleMenuNode;
    [titleMenuNode navigateToTopMenuAnimation:HLMenuNodeAnimationNone];
  }
  [self.skView presentScene:_titleScene transition:[SKTransition fadeWithDuration:FLSceneTransitionDuration]];
  _currentScene = _titleScene;
}

@end
