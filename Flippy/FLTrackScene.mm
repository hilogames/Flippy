//
//  FLTrackScene.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLTrackScene.h"

#import <HLSpriteKit/HLSpriteKit.h>
#include <memory>
#include <tgmath.h>

#import "DSMultilineLabelNode.h"
#import "FLConstants.h"
#include "FLLinks.h"
#import "FLPath.h"
#import "FLSegmentNode.h"
#include "FLTrackGrid.h"

using namespace std;
using namespace HLCommon;

NSString * const FLGameTypeChallengeTag = @"challenge";
NSString * const FLGameTypeChallengeTitle = NSLocalizedString(@"Game", @"Game information: the label used for a challenge game.");

NSString * const FLGameTypeSandboxTag = @"sandbox";
NSString * const FLGameTypeSandboxTitle = NSLocalizedString(@"Sandbox", @"Game information: the label used for a sandbox game.");

// note: The art scale is used within the track layer to intentionally pixelate
// the art for train and segments.  It should not be considered intrinsic to the
// segment art, but only added privately here when part of the track scene.
static const CGFloat FLTrackArtScale = 2.0f;
static const CGFloat FLTrackSegmentSize = FLSegmentArtSizeBasic * FLTrackArtScale;

static const int FLTrackGridWidth = 101;
static const int FLTrackGridHeight = 101;
// note: Track grid min and max are inclusive.
static const int FLTrackGridXMin = -FLTrackGridWidth / 2;
static const int FLTrackGridXMax = FLTrackGridXMin + FLTrackGridWidth - 1;
static const int FLTrackGridYMin = -FLTrackGridHeight / 2;
static const int FLTrackGridYMax = FLTrackGridYMin + FLTrackGridHeight - 1;

static const CGSize FLWorldSize = {
  // note: Extra half segment for visual border.
  (FLTrackGridWidth + 1) * FLTrackSegmentSize,
  (FLTrackGridHeight + 1) * FLTrackSegmentSize
};
static const CGFloat FLWorldXMin = -FLWorldSize.width / 2.0f;
static const CGFloat FLWorldXMax = FLWorldXMin + FLWorldSize.width;
static const CGFloat FLWorldYMin = -FLWorldSize.height / 2.0f;
static const CGFloat FLWorldYMax = FLWorldYMin + FLWorldSize.height;
static const CGFloat FLOffWorldScreenMargin = 30.0f;

// Main layers.
static const CGFloat FLZPositionWorld = 0.0f;
static const CGFloat FLZPositionHud = 10.0f;
static const CGFloat FLZPositionModal = 20.0f;
static const CGFloat FLZPositionTutorial = 30.0f;
// World sublayers.
static const CGFloat FLZPositionWorldTerrain = 0.0f;
static const CGFloat FLZPositionWorldSelect = 1.0f;
static const CGFloat FLZPositionWorldHighlight = 1.5f;
static const CGFloat FLZPositionWorldTrack = 2.0f;
static const CGFloat FLZPositionWorldTrain = 3.0f;
static const CGFloat FLZPositionWorldLinks = 4.0f;
static const CGFloat FLZPositionWorldOverlay = 5.0f;
// Modal sublayers.
static const CGFloat FLZPositionModalMin = FLZPositionModal;
static const CGFloat FLZPositionModalMax = FLZPositionModal + 1.0f;

static const NSTimeInterval FLWorldAdjustDuration = 0.5;
static const NSTimeInterval FLWorldAdjustDurationSlow = 1.0;
static const NSTimeInterval FLWorldFitDuration = 0.3;
static const NSTimeInterval FLTrackRotateDuration = 0.1;
static const NSTimeInterval FLBlinkHalfCycleDuration = 0.1;
static const NSTimeInterval FLTutorialStepFadeDuration = 0.4;

// noob: The tool art uses a somewhat arbitrary size.  The display height is
// chosen based on the screen layout.  Perhaps scaling like that is a bad idea.
static const CGFloat FLMainToolbarToolArtSize = 54.0f;
static const CGFloat FLMainToolbarHeight = 48.0f;
static const CGFloat FLMessageSpacer = 1.0f;
static const CGFloat FLMessageHeight = 20.0f;
static const CGFloat FLTrackEditMenuHeight = 42.0f;  // at scale = 1
static const CGFloat FLTrackEditMenuBackgroundBorderSize = 3.0f;
static const CGFloat FLTrackEditMenuSquareSeparatorSize = 3.0f;
static const CGFloat FLTrackEditMenuWorldInverseScaleFactor = 1.0f / 3.0f;
static const CGFloat FLTrackEditMenuWorldScaleMinimum = 2.0f / 3.0f;
static const CGFloat FLTrackEditMenuSegmentPad = 20.0f;

// note: I've seen strings display wider than the paragraph width specified;
// so pad it a little.
static const CGFloat FLDSMultilineLabelParagraphWidthPad = 10.0f;

static NSString *FLGatesDirectoryPath;
static NSString *FLCircuitsDirectoryPath;
static NSString *FLExportsDirectoryPath;

static SKColor *FLSceneBackgroundColor = [SKColor blackColor];
//static SKColor *FLSceneBackgroundColor = [SKColor colorWithRed:0.4f green:0.6f blue:0.0f alpha:1.0f];

static const CGFloat FLCursorNodeAlpha = 0.4f;

static const CGFloat FLLinkLineWidth = 2.0f;
static SKColor *FLLinkLineColor = [SKColor colorWithRed:0.2f green:0.6f blue:0.9f alpha:1.0f];
static SKColor *FLLinkEraseLineColor = [SKColor whiteColor];
static const CGFloat FLLinkGlowWidth = 2.0f;
static SKColor *FLLinkHighlightColor = [SKColor colorWithRed:0.2f green:0.9f blue:0.6f alpha:1.0f];

// Choose 36 letters: A-Z and 0-9
static const int FLLabelPickerWidth = 6;
static char FLLabelPickerLabels[] = {
  'A', 'B', 'C', 'D', 'E', 'F',
  'G', 'H', 'I', 'J', 'K', 'L',
  'M', 'N', 'O', 'P', 'Q', 'R',
  'S', 'T', 'U', 'V', 'W', 'X',
  'Y', 'Z', '0', '1', '2', '3',
  '4', '5', '6', '7', '8', '9',
  '\0'
};
static const int FLLabelPickerSize = sizeof(FLLabelPickerLabels);
static NSString *FLLabelPickerLabelNone = NSLocalizedString(@"No Label", @"Label picker: Text representing a value of 'no label' in the picker interface.");
static int FLSquareIndexForLabelPickerLabel(char label) {
  if (label >= 'A' && label <= 'Z') {
    return label - 'A';
  }
  if (label >= '0' && label <= '9') {
    return 26 + label - '0';
  }
  if (label == '\0') {
    return 36;
  }
  return -1;
}

typedef NS_ENUM(NSInteger, FLUnlockItem) {
  FLUnlockGates,
  FLUnlockGateNot1,
  FLUnlockGateNot2,
  FLUnlockGateAnd1,
  FLUnlockGateOr1,
  FLUnlockGateOr2,
  FLUnlockGateXor1,
  FLUnlockGateXor2,
  FLUnlockCircuits,
  FLUnlockCircuitXor,
  FLUnlockCircuitHalfAdder,
  FLUnlockCircuitFullAdder,
  FLUnlockTutorialCompleted,
};

#pragma mark -
#pragma mark States

// States are functional components of the scene; the data is encapsulated in
// a simple public struct, and the associated functionality is implemented in
// private methods of the scene.

struct FLExportState
{
  FLExportState() : descriptionInputAlert(nil) {}
  UIAlertView *descriptionInputAlert;
};

typedef NS_ENUM(NSInteger, FLToolbarToolType) {
  FLToolbarToolTypeNone,
  FLToolbarToolTypeActionTap,
  FLToolbarToolTypeActionPan,
  FLToolbarToolTypeNavigation,
  FLToolbarToolTypeMode
};

struct FLConstructionToolbarState
{
  FLConstructionToolbarState() : toolbarNode(nil), currentNavigation(@"main"), currentPage(0), deleteExportConfirmAlert(nil) {
    toolTypes = [NSMutableDictionary dictionary];
    toolDescriptions = [NSMutableDictionary dictionary];
    toolSegmentTypes = [NSMutableDictionary dictionary];
  }
  HLToolbarNode *toolbarNode;
  NSString *currentNavigation;
  int currentPage;
  NSMutableDictionary *toolTypes;
  NSMutableDictionary *toolDescriptions;
  NSMutableDictionary *toolSegmentTypes;
  UIAlertView *deleteExportConfirmAlert;
  NSString *deleteExportName;
  NSString *deleteExportDescription;
};

struct FLSimulationToolbarState
{
  FLSimulationToolbarState() : toolbarNode(nil) {}
  HLToolbarNode *toolbarNode;
};

struct FLTrainMoveState
{
  FLTrainMoveState() : cursorNode(nil) {}
  SKNode *cursorNode;
  CGFloat progressPrecision;
};

struct FLTrackSelectState
{
  FLTrackSelectState() : selectedSegments(nil), selectedSegmentPointers(nil), visualParentNode(nil) {}
  NSMutableArray *selectedSegments;
  NSMutableSet *selectedSegmentPointers;
  SKNode *visualParentNode;
  NSMutableDictionary *visualSquareNodes;
};

struct FLTrackConflictState
{
  FLTrackConflictState() { conflictNodes = [NSMutableArray array]; }
  NSMutableArray *conflictNodes;
};

struct FLTrackMoveState
{
  FLTrackMoveState() : segmentNodes(nil), cursorNode(nil) {}
  SKNode *cursorNode;
  NSArray *segmentNodes;
  NSSet *segmentNodePointers;
  int beganGridX;
  int beganGridY;
  BOOL attempted;
  int attemptedTranslationGridX;
  int attemptedTranslationGridY;
  BOOL placed;
  int placedTranslationGridX;
  int placedTranslationGridY;
  void (^completion)(BOOL);
};

struct FLTrackEditMenuState
{
  FLTrackEditMenuState() : editMenuNode(nil), showing(NO) {}
  BOOL showing;
  HLToolbarNode *editMenuNode;
};

struct FLLinkEditState
{
  FLSegmentNode *beginNode;
  FLSegmentNode *endNode;
  SKShapeNode *connectorNode;
  SKNode *beginHighlightNode;
  SKNode *endHighlightNode;
};

struct FLLabelState
{
  FLLabelState() : labelPicker(nil), segmentNodesToBeLabeled(nil) {}
  HLGridNode *labelPicker;
  NSArray *segmentNodesToBeLabeled;
};

typedef NS_ENUM(NSInteger, FLWorldPanType) { FLWorldPanTypeNone, FLWorldPanTypeScroll, FLWorldPanTypeTrackMove, FLWorldPanTypeLink };

typedef NS_ENUM(NSInteger, FLWorldLongPressMode) { FLWorldLongPressModeNone, FLWorldLongPressModeAdd, FLWorldLongPressModeErase };

// note: This contains extra state information that seems too minor to split out
// into a "component".  For instance, track selection and track movement are
// caused by gestures in the world, but they are split out into their own
// components, with their own FL_* methods.  Tracking the original center
// of a pinch zoom, though, can stay here for now.
struct FLWorldGestureState
{
  CGPoint gestureFirstTouchLocation;
  FLWorldPanType panType;
  CGPoint pinchZoomCenter;
  FLWorldLongPressMode longPressMode;
};

struct FLWorldAutoScrollState
{
  FLWorldAutoScrollState() : scrolling(NO), gestureUpdateBlock(nil) {}
  BOOL scrolling;
  CGFloat velocityX;
  CGFloat velocityY;
  void (^gestureUpdateBlock)(void);
};

typedef NS_ENUM(NSInteger, FLCameraMode) { FLCameraModeManual, FLCameraModeFollowTrain };

typedef NS_ENUM(NSInteger, FLTutorialAction) {
  FLTutorialActionNone,
  FLTutorialActionBackdropTap,
  FLTutorialActionBackdropLongPress,
  FLTutorialActionConstructionToolbarTap,
  FLTutorialActionConstructionToolbarPanBegan,
  FLTutorialActionConstructionToolbarPanEnded,
  FLTutorialActionSimulationToolbarTap,
  FLTutorialActionSimulationStarted,
  FLTutorialActionSimulationStopped,
  FLTutorialActionGoalsDismissed,
  FLTutorialActionLinkEditBegan,
  FLTutorialActionLinkCreated,
};

typedef NS_OPTIONS(NSUInteger, FLTutorialResults) {
  FLTutorialResultNone = 0,
  FLTutorialResultContinue = (1 << 0),
  FLTutorialResultRepeat = (1 << 1),
  FLTutorialResultPrevious = (1 << 2),
  FLTutorialResultHideBackdropAllowInteraction = (1 << 3),
  FLTutorialResultHideBackdropDisallowInteraction = (1 << 4),
};

struct FLTutorialCutout {
  FLTutorialCutout() {}
  FLTutorialCutout(SKSpriteNode *spriteNode_, UIImage *image_, BOOL allowsGestures_)
    : spriteNode(spriteNode_), image(image_), allowsGestures(allowsGestures_) {}
  FLTutorialCutout(SKSpriteNode *spriteNode_, BOOL allowsGestures_)
    : spriteNode(spriteNode_), image(nil), allowsGestures(allowsGestures_) {}
  FLTutorialCutout(const CGRect& rect_, BOOL allowsGestures_)
    : rect(rect_), allowsGestures(allowsGestures_) {}
  SKSpriteNode *spriteNode;
  UIImage *image;
  CGRect rect;
  BOOL allowsGestures;
};

// note: Takes an array of arguments (those passed at runtime to FL_tutorialRecognizedAction)
// and returns a bitmask of results.
typedef FLTutorialResults(^FLTutorialConditionBlock)(NSArray *);

struct FLTutorialCondition {
  FLTutorialCondition(FLTutorialAction action_, FLTutorialResults simpleResults_) : action(action_), simpleResults(simpleResults_), dynamicResults(nil) {}
  FLTutorialCondition(FLTutorialAction action_, FLTutorialConditionBlock dynamicResults_) : action(action_), simpleResults(FLTutorialResultNone), dynamicResults(dynamicResults_) {}
  FLTutorialAction action;
  FLTutorialResults simpleResults;
  FLTutorialConditionBlock dynamicResults;
};

typedef NS_ENUM(NSInteger, FLTutorialLabelPosition) {
  FLTutorialLabelCenterScene,
  FLTutorialLabelUpperScene,
  FLTutorialLabelLowerScene,
  FLTutorialLabelAboveFirstCutout,
  FLTutorialLabelAboveCutouts,
  FLTutorialLabelBelowFirstCutout,
  FLTutorialLabelBelowCutouts,
};

struct FLTutorialState
{
  FLTutorialState() : step(0), tutorialActive(NO), backdropNode(nil), disallowOtherGestures(YES), labelPosition(FLTutorialLabelCenterScene) {}
  int step;
  BOOL tutorialActive;
  SKSpriteNode *backdropNode;
  BOOL disallowOtherGestures;
  FLTutorialLabelPosition labelPosition;
  vector<FLTutorialCutout> cutouts;
  vector<FLTutorialCondition> conditions;
};

#pragma mark -
#pragma mark Scene

struct PointerPairHash
{
  size_t operator()(const pair<void *, void *>& key) const {
    size_t h = ((reinterpret_cast<uintptr_t>(key.first) & 0xFFFF) << 16) | (reinterpret_cast<uintptr_t>(key.second) & 0xFFFF);
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = ((h >> 16) ^ h);
    return h;
  }
};

@implementation FLTrackScene
{
  BOOL _contentCreated;

  SKNode *_worldNode;
  SKNode *_trackNode;
  SKNode *_hudNode;
  SKNode *_linksNode;

  FLCameraMode _cameraMode;
  BOOL _simulationRunning;
  int _simulationSpeed;
  CFTimeInterval _updateLastTime;

  BOOL _linksVisible;
  BOOL _labelsVisible;
  BOOL _valuesVisible;

  shared_ptr<FLTrackGrid> _trackGrid;
  FLLinks _links;

  FLTutorialState _tutorialState;
  FLExportState _exportState;
  FLWorldGestureState _worldGestureState;
  FLWorldAutoScrollState _worldAutoScrollState;
  FLConstructionToolbarState _constructionToolbarState;
  FLSimulationToolbarState _simulationToolbarState;
  FLTrainMoveState _trainMoveState;
  FLTrackEditMenuState _trackEditMenuState;
  FLTrackSelectState _trackSelectState;
  FLTrackConflictState _trackConflictState;
  FLTrackMoveState _trackMoveState;
  FLLinkEditState _linkEditState;
  FLLabelState _labelState;

  HLMessageNode *_messageNode;
  FLTrain *_train;
}

+ (void)initialize
{
  NSString *bundleDirectory = [[NSBundle mainBundle] bundlePath];
  FLGatesDirectoryPath = [bundleDirectory stringByAppendingPathComponent:@"gates"];
  FLCircuitsDirectoryPath = [bundleDirectory stringByAppendingPathComponent:@"circuits"];
  NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
  FLExportsDirectoryPath = [documentsDirectory stringByAppendingPathComponent:@"exports"];
}

+ (void)loadSceneAssets
{
  [super loadSceneAssets];
  [self FL_loadTextures];
  [self FL_loadEmitters];
  [self FL_loadSound];
}

+ (void)releaseSceneAssets
{
  // note: Scene assets are loaded abusively into global shared resources, so there's
  // no good way, for now, to release them, and no real need to do so.
}

- (instancetype)initWithSize:(CGSize)size gameType:(FLGameType)gameType gameLevel:(int)gameLevel
{
  self = [super initWithSize:size];
  if (self) {
    _gameType = gameType;
    _gameLevel = gameLevel;
    // note: Assume game is old unless explicitly told otherwise by the view controller.
    // It's hard for us to know by ourselves.
    _gameIsNew = NO;
    _cameraMode = FLCameraModeManual;
    _simulationRunning = NO;
    _simulationSpeed = 0;
    _trackGrid.reset(new FLTrackGrid(FLTrackSegmentSize));
    self.gestureTargetHitTestMode = HLSceneGestureTargetHitTestModeZPositionThenParent;
  }
  return self;
}

- (instancetype)initWithSize:(CGSize)size
{
  return [self initWithSize:size gameType:FLGameTypeSandbox gameLevel:0];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {

    // note: There is no lazy-load option for textures (and perhaps other scene
    // resources); they must already be loaded.
    [HLScene assertSceneAssetsLoaded];

    _contentCreated = YES;

    // TODO: Some older archives were created with different scene background color.  Reset it here upon
    // decoding; can delete this code once (if) all archives have been recreated recently.
    self.backgroundColor = FLSceneBackgroundColor;

    // TODO: Some older archives were created with a different gesture target hit test mode.  Reset it
    // here upon decoding; can delete this code once (if) all archives have been recreated recently.
    self.gestureTargetHitTestMode = HLSceneGestureTargetHitTestModeZPositionThenParent;

    _gameType = (FLGameType)[aDecoder decodeIntegerForKey:@"gameType"];
    _gameLevel = [aDecoder decodeIntForKey:@"gameLevel"];
    _tutorialState.step = [aDecoder decodeIntForKey:@"tutorialStateStep"];
    _cameraMode = (FLCameraMode)[aDecoder decodeIntegerForKey:@"cameraMode"];
    // note: These settings affect the state of the simulation toolbar at creation;
    // make sure they are decoded before the simulation toolbar is created.
    _simulationRunning = [aDecoder decodeBoolForKey:@"simulationRunning"];
    _simulationSpeed = [aDecoder decodeIntForKey:@"simulationSpeed"];
    // note: These settings affect the state of the construction toolbar at creation;
    // make sure they are decoded before the construction toolbar is created.
    _linksVisible = [aDecoder decodeBoolForKey:@"linksVisible"];
    _labelsVisible = [aDecoder decodeBoolForKey:@"labelsVisible"];
    _valuesVisible = [aDecoder decodeBoolForKey:@"valuesVisible"];
    _constructionToolbarState.currentNavigation = [aDecoder decodeObjectForKey:@"constructionToolbarStateCurrentNavigation"];
    _constructionToolbarState.currentPage = [aDecoder decodeIntForKey:@"constructionToolbarStateCurrentPage"];

    // Re-link special node pointers to objects already decoded in hierarchy.
    _worldNode = [aDecoder decodeObjectForKey:@"worldNode"];
    _trackNode = [aDecoder decodeObjectForKey:@"trackNode"];

    // Recreate nodes from the hierarchy that were removed during encoding.
    [self FL_createTerrainNode];
    [self FL_createHudNode];
    [self FL_createLinksNode];
    [self FL_constructionToolbarSetVisible:YES];
    [self FL_simulationToolbarSetVisible:YES];

    // Recreate track grid based on segments in track node.
    _trackGrid.reset(new FLTrackGrid(FLSegmentArtSizeBasic * FLTrackArtScale));
    _trackGrid->import(_trackNode);

    // Decode links model and re-create links layer.
    NSArray *links = [aDecoder decodeObjectForKey:@"links"];
    NSUInteger l = 0;
    while (l + 1 < [links count]) {
      FLSegmentNode *a = links[l];
      ++l;
      FLSegmentNode *b = links[l];
      ++l;
      SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:a.switchPosition toLocation:b.switchPosition linkErase:NO];
      _links.insert(a, b, connectorNode);
    }
    if (_linksVisible) {
      [_worldNode addChild:_linksNode];
    }

    // Decode train.
    _train = [aDecoder decodeObjectForKey:@"train"];
    _train.delegate = self;
    [_train resetTrackGrid:_trackGrid];
    // TODO: Some older archives were created with wrong train speeds.  Reset it here upon decoding; can
    // delete this code once (if) all archives have been recreated recently.
    [self FL_train:_train setSpeed:_simulationSpeed];

    // Decode current selection.
    NSArray *selectedSegments = [aDecoder decodeObjectForKey:@"trackSelectStateSelectedSegments"];
    if (selectedSegments && [selectedSegments count] > 0) {
      [self FL_trackSelect:selectedSegments];
    }

    // Decode current track edit menu.
    if ([aDecoder decodeBoolForKey:@"trackEditMenuStateShowing"]) {
      [self FL_trackEditMenuShowAnimated:NO];
    }
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  if (!_contentCreated) {
    return;
  }

  // note: So... this encoding is often triggered by a in-game menu save button being clicked.
  // The in-game menu is presented as a modal node, child of the scene; a tap on the button
  // triggers a sound effect via SKAction playSoundFileNamed.  So the modal presentation node
  // is removed, but the SKAction persists in the scene's/ _action ivar; it gets encoded; and
  // on decoding it crashes (because it can't find the sound file at the path specified for the
  // old bundle path, now probably invalid).  In iOS8 the bundle changes for new simulator runs,
  // which is probably why this only started crashing in iOS8.  There might be a more elegant
  // fix for this problem, but this gets the job done.
  [self removeAllActions];

  // Remove nodes from hierarchy that should not be persisted.
  SKNode *holdTerrainNode = [_worldNode childNodeWithName:@"terrain"];
  [holdTerrainNode removeFromParent];
  [_hudNode removeFromParent];
  FLTrackSelectState holdTrackSelectState(_trackSelectState);
  if (_trackSelectState.selectedSegments) {
    [self FL_trackSelectClear];
  }
  FLTrackEditMenuState holdTrackEditMenuState(_trackEditMenuState);
  if (_trackEditMenuState.showing) {
    [self FL_trackEditMenuHideAnimated:NO];
  }
  if (_linksVisible) {
    [_linksNode removeFromParent];
  }
  [self FL_simulationToolbarSetVisible:NO];
  [self FL_constructionToolbarSetVisible:NO];
  [self FL_trackConflictClear];
  BOOL messageNodeAddedToParent = (_messageNode && _messageNode.parent);
  if (messageNodeAddedToParent) {
    [_messageNode removeFromParent];
  }
  if (_tutorialState.backdropNode) {
    [_tutorialState.backdropNode removeFromParent];
  }

  // Persist SKScene (including current node hierarchy).
  [super encodeWithCoder:aCoder];

  // Add back nodes that were removed.
  [_worldNode addChild:holdTerrainNode];
  [self addChild:_hudNode];
  if (holdTrackSelectState.selectedSegments) {
    [self FL_trackSelect:holdTrackSelectState.selectedSegments];
  }
  if (holdTrackEditMenuState.showing) {
    [self FL_trackEditMenuShowAnimated:NO];
  }
  if (_linksVisible) {
    [_worldNode addChild:_linksNode];
  }
  [self FL_simulationToolbarSetVisible:YES];
  [self FL_constructionToolbarSetVisible:YES];
  if (messageNodeAddedToParent) {
    [_hudNode addChild:_messageNode];
  }
  if (_tutorialState.backdropNode) {
    [self addChild:_tutorialState.backdropNode];
  }

  // Persist special node pointers (that should already been encoded
  // as part of hierarchy).
  [aCoder encodeObject:_worldNode forKey:@"worldNode"];
  [aCoder encodeObject:_trackNode forKey:@"trackNode"];

  // Encode links.
  NSMutableArray *links = [NSMutableArray array];
  for (auto l = _links.begin(); l != _links.end(); ++l) {
    [links addObject:(__bridge FLSegmentNode *)l->first.first];
    [links addObject:(__bridge FLSegmentNode *)l->first.second];
  }
  [aCoder encodeObject:links forKey:@"links"];

  // Encode other state.
  [aCoder encodeInteger:_gameType forKey:@"gameType"];
  [aCoder encodeInt:_gameLevel forKey:@"gameLevel"];
  [aCoder encodeInt:_tutorialState.step forKey:@"tutorialStateStep"];
  [aCoder encodeInteger:_cameraMode forKey:@"cameraMode"];
  [aCoder encodeBool:_simulationRunning forKey:@"simulationRunning"];
  [aCoder encodeInt:_simulationSpeed forKey:@"simulationSpeed"];
  [aCoder encodeObject:_train forKey:@"train"];
  [aCoder encodeObject:_trackSelectState.selectedSegments forKey:@"trackSelectStateSelectedSegments"];
  [aCoder encodeBool:_trackEditMenuState.showing forKey:@"trackEditMenuStateShowing"];
  [aCoder encodeBool:_linksVisible forKey:@"linksVisible"];
  [aCoder encodeBool:_labelsVisible forKey:@"labelsVisible"];
  [aCoder encodeBool:_valuesVisible forKey:@"valuesVisible"];
  [aCoder encodeObject:_constructionToolbarState.currentNavigation forKey:@"constructionToolbarStateCurrentNavigation"];
  [aCoder encodeInt:_constructionToolbarState.currentPage forKey:@"constructionToolbarStateCurrentPage"];
}

- (void)didMoveToView:(SKView *)view
{
  [super didMoveToView:view];

  if (!_contentCreated) {
    [self FL_createSceneContents];
    _contentCreated = YES;
  }

  // note: No need for cancelsTouchesInView: Not currently handling any touches in the view.

  // note: HLScene (through [super]) needs shared gesture recognizers only for registered
  // HLGestureTarget nodes.  We know ahead of time which ones we need.
  [self needSharedTapGestureRecognizer];
  [self needSharedDoubleTapGestureRecognizer];
  // note: This can be nice, but it slows down the single-tap recognition significantly
  // (and, in my opinion, unacceptably).  Instead there should be code in the double-tap
  // recognizers to "undo" any undesirable effect of single-tapping; see how that goes.
  // For example, see code in handleWorldDoubleTap.
  //[_tapRecognizer requireGestureRecognizerToFail:_doubleTapRecognizer];
  [self needSharedLongPressGestureRecognizer];
  [self needSharedPanGestureRecognizer];
  [self needSharedPinchGestureRecognizer];

  if (_gameType == FLGameTypeChallenge) {
    if ([self FL_unlocked:FLUnlockTutorialCompleted] || ![self FL_tutorialStepAnimated:_gameIsNew]) {
      [self FL_goalsShowWithSplash:YES];
    }
  }
}

- (void)didChangeSize:(CGSize)oldSize
{
  [super didChangeSize:oldSize];
  // note: Reset current world scale (and thence position) using constraints that might now be changed.
  [self FL_worldSetScale:_worldNode.xScale];
  [self FL_tutorialUpdateGeometry];
  [self FL_constructionToolbarUpdateGeometry];
  [self FL_simulationToolbarUpdateGeometry];
  [self FL_messageUpdateGeometry];
}

- (void)FL_createSceneContents
{
  self.backgroundColor = FLSceneBackgroundColor;
  self.anchorPoint = CGPointMake(0.5f, 0.5f);

  // note: There is no lazy-load option for textures (and perhaps other scene
  // resources); they must already be loaded.
  [HLScene assertSceneAssetsLoaded];

  // The large world is moved around within the scene; the scene acts as a window
  // into the world.  The scene always fits the view/screen, and it is centered at
  // in the middle of the screen; the coordinate system goes positive up and to the
  // right.  So, for example, if we want to show the portion of the world around
  // the point (100,-50) in world coordinates, then we set the _worldNode.position
  // to (-100,50) in scene coordinates.
  _worldNode = [SKNode node];
  _worldNode.zPosition = FLZPositionWorld;
  [self addChild:_worldNode];

  _trackNode = [SKNode node];
  _trackNode.zPosition = FLZPositionWorldTrack;
  [_worldNode addChild:_trackNode];

  [self FL_createTerrainNode];

  [self FL_createLinksNode];

  // The HUD node contains everything pinned to the scene window, outside the world.
  [self FL_createHudNode];

  _train = [self FL_trainCreate];
  [_worldNode addChild:_train];

  [self FL_constructionToolbarSetVisible:YES];
  [self FL_simulationToolbarSetVisible:YES];
}

- (void)FL_createTerrainNode
{
  HLTiledNode *terrainNode = [HLTiledNode tiledNodeWithImageNamed:@"grass.jpg" size:FLWorldSize];
  terrainNode.name = @"terrain";
  terrainNode.zPosition = FLZPositionWorldTerrain;
  // noob: Using a tip to use replace blend mode for opaque sprites, but since
  // JPEGs don't have an alpha channel in the source, does this really do anything
  // for JPEGs?
  terrainNode.blendMode = SKBlendModeReplace;

  [_worldNode addChild:terrainNode];
}

- (void)FL_createLinksNode
{
  _linksNode = [SKNode node];
  _linksNode.zPosition = FLZPositionWorldLinks;
}

- (void)FL_createHudNode
{
  _hudNode = [SKNode node];
  _hudNode.zPosition = FLZPositionHud;
  [self addChild:_hudNode];
}

- (void)didSimulatePhysics
{
  switch (_cameraMode) {
    case FLCameraModeFollowTrain: {
      // note: Set world position based on train position.  Note that the
      // train is in the world, but the world is in the scene, so convert.
      CGPoint trainSceneLocation = [self convertPoint:_train.position fromNode:_worldNode];
      [self FL_worldSetPositionX:(_worldNode.position.x - trainSceneLocation.x)
                       positionY:(_worldNode.position.y - trainSceneLocation.y)];
      break;
    }
    case FLCameraModeManual:
      break;
    default:
      break;
  }
}

- (void)update:(CFTimeInterval)currentTime
{
  // Sanitize and constrain elapsed time.
  CFTimeInterval elapsedTime;
  elapsedTime = currentTime - _updateLastTime;
  _updateLastTime = currentTime;
  // note: No time elapsed if clock runs backwards.  (Does SKScene already check this?)
  if (elapsedTime < 0.0) {
    elapsedTime = 0.0;
  }
  // note: If framerate is crazy low, pretend time has slowed down, too.
  if (elapsedTime > 0.2) {
    NSLog(@"time is slow");
    elapsedTime = 0.01;
  }

  if (_simulationRunning) {
    [_train update:elapsedTime];
  }
  if (_worldAutoScrollState.scrolling) {
    [self FL_worldAutoScrollUpdate:elapsedTime];
  }
}

- (void)setGameType:(FLGameType)gameType
{
  _gameType = gameType;
  if (_simulationToolbarState.toolbarNode) {
    [self FL_simulationToolbarUpdateTools];
  }
}

- (size_t)segmentCount
{
  return _trackGrid->size();
}

#pragma mark -
#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  if (alertView == _exportState.descriptionInputAlert) {
    NSString *trackDescription = [alertView textFieldAtIndex:0].text;
    if (buttonIndex == 1 && trackDescription && trackDescription.length > 0) {
      [self FL_exportWithDescription:trackDescription];
    }
    _exportState.descriptionInputAlert = nil;
  } else if (alertView == _constructionToolbarState.deleteExportConfirmAlert) {
    if (buttonIndex == 1) {
      [self FL_exportDelete:_constructionToolbarState.deleteExportName description:_constructionToolbarState.deleteExportDescription];
    }
    _constructionToolbarState.deleteExportConfirmAlert = nil;
  }
}

#pragma mark -
#pragma mark UIGestureRecognizerDelegate

- (void)handleWorldTap:(UIGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
  FLSegmentNode *segmentNode = trackGridConvertGet(*_trackGrid, worldLocation);

  if (!segmentNode || [self FL_trackSelected:segmentNode]) {
    [self FL_trackSelectClear];
    [self FL_trackEditMenuHideAnimated:YES];
  } else {
    [self FL_trackSelectClear];
    [self FL_trackSelect:@[ segmentNode ]];
    [self FL_trackEditMenuShowAnimated:YES];
  }
}

- (void)handleWorldDoubleTap:(UIGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];

  int gridX;
  int gridY;
  _trackGrid->convert(worldLocation, &gridX, &gridY);

  FLSegmentNode *segmentNode = _trackGrid->get(gridX, gridY);
  if (segmentNode && segmentNode.switchPathId != FLSegmentSwitchPathIdNone) {
    [self FL_linkSwitchTogglePathIdForSegment:segmentNode animated:YES];
  }

  // note: Our current gesture single- and double- tap recognizers (created
  // by HLScene's needShared*GestureRecognizer methods) do not require the
  // other recognizer to fail.  Instead, try here to undo the common effect
  // of a single tap.
  if ([self FL_trackSelectedCount] == 1 && [self FL_trackSelected:segmentNode]) {
    [self FL_trackSelectClear];
    [self FL_trackEditMenuHideAnimated:YES];
  }
}

- (void)handleWorldLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

    CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
    CGPoint sceneLocation = [self convertPointFromView:viewLocation];
    CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
    [self FL_trackSelectPaintBeganWithLocation:worldLocation];

  } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {

    CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
    CGPoint sceneLocation = [self convertPointFromView:viewLocation];
    CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
    // note: Track selection painting might not even be functional (if the long press
    // did not start on a track segment), but the auto scroll is part of the functionality
    // here: it's a way of scrolling the world.
    [self FL_trackSelectPaintChangedWithLocation:worldLocation];
    [self FL_worldAutoScrollEnableForGestureWithLocation:sceneLocation gestureUpdateBlock:^{
      CGPoint scrolledWorldLocation = [self->_worldNode convertPoint:sceneLocation fromNode:self];
      [self FL_trackSelectPaintChangedWithLocation:scrolledWorldLocation];
    }];

  } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
    [self FL_worldAutoScrollDisable];
    [self FL_worldFitSegments:_trackSelectState.selectedSegments scaling:YES scrolling:YES includeTrackEditMenu:YES animated:YES];
    [self FL_trackEditMenuUpdateAnimated:YES];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
    [self FL_worldAutoScrollDisable];
    [self FL_worldFitSegments:_trackSelectState.selectedSegments scaling:YES scrolling:YES includeTrackEditMenu:YES animated:YES];
    [self FL_trackEditMenuUpdateAnimated:YES];
  }
}

- (void)handleWorldPan:(UIPanGestureRecognizer *)gestureRecognizer
{
  _cameraMode = FLCameraModeManual;

  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

    // Determine type of pan based on gesture location and current tool.
    //
    // note: The decision is based on the location of the first touch in the gesture, not the
    // current location (when the gesture is fully identified); they can be quite different.
    // (Whether or not to use the first touch location or the current touch location for
    // interpreting the pan is left as separate decision.)
    CGPoint firstTouchViewLocation = _worldGestureState.gestureFirstTouchLocation;
    CGPoint firstTouchSceneLocation = [self convertPointFromView:firstTouchViewLocation];
    CGPoint firstTouchWorldLocation = [_worldNode convertPoint:firstTouchSceneLocation fromNode:self];
    if (_linksVisible) {
      FLSegmentNode *segmentNode = [self FL_linkSwitchFindSegmentNearLocation:firstTouchWorldLocation];
      if (segmentNode) {
        // Pan begins with link tool near a segment with a switch.
        _worldGestureState.panType = FLWorldPanTypeLink;
        [self FL_linkEditBeganWithNode:segmentNode];
      } else {
        // Pan begins with link tool not close to a segment with a switch.
        _worldGestureState.panType = FLWorldPanTypeScroll;
      }
    } else {
      // Pan is not using link tool.
      FLSegmentNode *segmentNode = trackGridConvertGet(*_trackGrid, firstTouchWorldLocation);
      if ([self FL_trackSelected:segmentNode]) {
        // Pan begins inside a selected track segment.
        //
        // note: Here we use the first touch location to start the pan, because the translation of
        // the pan is calculated by gridlines crossed (not distance moved), and we wouldn't want to
        // miss a gridline.
        _worldGestureState.panType = FLWorldPanTypeTrackMove;
        [self FL_trackMoveBeganWithNodes:_trackSelectState.selectedSegments location:firstTouchWorldLocation completion:nil];
      } else {
        // Pan begins not inside a selected track segment.
        //
        // note: We end up not using the first touch location as the start of the scroll;
        // if we wanted to, we could offset the starting translation right now based on
        // the difference.
        _worldGestureState.panType = FLWorldPanTypeScroll;
      }
    }

  } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {

    switch (_worldGestureState.panType) {
      case FLWorldPanTypeTrackMove: {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
        [self FL_trackMoveChangedWithLocation:worldLocation];
        [self FL_worldAutoScrollEnableForGestureWithLocation:sceneLocation gestureUpdateBlock:^{
          CGPoint scrolledWorldLocation = [self->_worldNode convertPoint:sceneLocation fromNode:self];
          [self FL_trackMoveChangedWithLocation:scrolledWorldLocation];
        }];
        break;
      }
      case FLWorldPanTypeScroll: {
        CGPoint translation = [gestureRecognizer translationInView:self.view];
        [self FL_worldSetPositionX:(_worldNode.position.x + translation.x / self.xScale)
                         positionY:(_worldNode.position.y - translation.y / self.yScale)];
        [gestureRecognizer setTranslation:CGPointZero inView:self.view];
        break;
      }
      case FLWorldPanTypeLink: {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
        [self FL_linkEditChangedWithLocation:worldLocation];
        [self FL_worldAutoScrollEnableForGestureWithLocation:sceneLocation gestureUpdateBlock:^{
          CGPoint scrolledWorldLocation = [self->_worldNode convertPoint:sceneLocation fromNode:self];
          [self FL_linkEditChangedWithLocation:scrolledWorldLocation];
        }];
        break;
      }
      default:
        // note: This means the pan gesture was not actually doing anything,
        // but was allowed to continue.
        break;
    }

  } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {

    switch (_worldGestureState.panType) {
      case FLWorldPanTypeTrackMove: {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
        [self FL_trackMoveEndedWithLocation:worldLocation];
        [self FL_worldAutoScrollDisable];
        break;
      }
      case FLWorldPanTypeScroll:
        // note: Nothing to do here.
        break;
      case FLWorldPanTypeLink:
        [self FL_linkEditEnded];
        [self FL_worldAutoScrollDisable];
        break;
      default:
        // note: This means the pan gesture was not actually doing anything,
        // but was allowed to continue.
        break;
    }

  } else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {

    switch (_worldGestureState.panType) {
      case FLWorldPanTypeTrackMove: {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
        [self FL_trackMoveCancelledWithLocation:worldLocation];
        [self FL_worldAutoScrollDisable];
        break;
      }
      case FLWorldPanTypeScroll:
        // note: Nothing to do here.
        break;
      case FLWorldPanTypeLink:
        [self FL_linkEditCancelled];
        [self FL_worldAutoScrollDisable];
        break;
      default:
        // note: This means the pan gesture was not actually doing anything,
        // but was allowed to continue.
        break;
    }
  }
}

- (void)handleWorldPinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
  static CGFloat handlePinchWorldScaleBegin;
  static CGPoint handlePinchWorldPositionBegin;

  // noob: Pinch gesture continues for the recognizer until both fingers have
  // been lifted.  Seems like after one finger is up, we could be done.  But
  // for now, do it their way, and see if anything is weird.
  //if (gestureRecognizer.numberOfTouches != 2) {
  //  return;
  //}

  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
    handlePinchWorldScaleBegin = _worldNode.xScale;
    handlePinchWorldPositionBegin = _worldNode.position;
    // Choose a fixed point at the center of the zoom.
    //
    // note: The zoom happens centered on a particular point within the scene, which remains
    // fixed in the scene as the rest of the points scale around it.  Choose our fixed
    // point based on camera mode: If we're following something, then we should zoom
    // around that thing (assume at center of scene, e.g. 0,0 in scene coordinates).  If
    // not, then it's more pleasing and intuitive to zoom on the center of the pinch
    // gesture.
    //
    // noob: I experimented with recalculating the center of the pinch while the pinch changed,
    // so that the pinch gesture could do some panning while pinching.  But as the code is written,
    // the result was the opposite of, say, Google Maps app, and I found it a bit disorienting
    // anyway.  I like choosing my zoom center and then being able to move my fingers around on the
    // screen if I need more room for the gesture.  But probably there's a human interface guideline for
    // this which I should follow.
    _worldGestureState.pinchZoomCenter = CGPointZero;
    if (_cameraMode == FLCameraModeManual) {
      CGPoint centerViewLocation = [gestureRecognizer locationInView:self.view];
      _worldGestureState.pinchZoomCenter = [self convertPointFromView:centerViewLocation];
    }
    return;
  }

  // Zoom around previously-chosen center point.
  CGFloat worldScaleNew = [self FL_worldConstrainedScale:(handlePinchWorldScaleBegin * gestureRecognizer.scale)];
  CGFloat scaleFactor = worldScaleNew / handlePinchWorldScaleBegin;
  [self FL_worldSetConstrainedScale:worldScaleNew
                          positionX:((handlePinchWorldPositionBegin.x - _worldGestureState.pinchZoomCenter.x) * scaleFactor + _worldGestureState.pinchZoomCenter.x)
                          positionY:((handlePinchWorldPositionBegin.y - _worldGestureState.pinchZoomCenter.y) * scaleFactor + _worldGestureState.pinchZoomCenter.y)];
}

- (void)handleConstructionToolbarTap:(UITapGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_constructionToolbarState.toolbarNode convertPoint:sceneLocation fromNode:self];
  NSString *toolTag = [_constructionToolbarState.toolbarNode toolAtLocation:toolbarLocation];
  if (!toolTag) {
    return;
  }

  if (_tutorialState.tutorialActive) {
    [self FL_tutorialRecognizedAction:FLTutorialActionConstructionToolbarTap withArguments:@[ toolTag ]];
  }

  FLToolbarToolType toolType = (FLToolbarToolType)[_constructionToolbarState.toolTypes[toolTag] integerValue];

  // If navigating, reset state on mode buttons.
  if (toolType == FLToolbarToolTypeNavigation) {
    if (![toolTag isEqualToString:@"link"] && _linksVisible) {
      [self FL_linksToggle];
    }
  }

  if (toolType == FLToolbarToolTypeNavigation) {

    NSString *newNavigation;
    int newPage;
    HLToolbarNodeAnimation animation = HLToolbarNodeAnimationNone;
    if ([toolTag isEqualToString:@"next"]) {
      newNavigation = _constructionToolbarState.currentNavigation;
      newPage = _constructionToolbarState.currentPage + 1;
      animation = HLToolbarNodeAnimationSlideLeft;
    } else if ([toolTag isEqualToString:@"previous"]) {
      newNavigation = _constructionToolbarState.currentNavigation;
      newPage = _constructionToolbarState.currentPage - 1;
      animation = HLToolbarNodeAnimationSlideRight;
    } else if ([toolTag isEqualToString:@"main"]) {
      newNavigation = @"main";
      newPage = 0;
      animation = HLToolbarNodeAnimationSlideUp;
    } else {
      newNavigation = toolTag;
      newPage = 0;
      animation = HLToolbarNodeAnimationSlideDown;
    }

    if ([newNavigation isEqualToString:_constructionToolbarState.currentNavigation]
        && newPage == _constructionToolbarState.currentPage) {
      return;
    }

    _constructionToolbarState.currentNavigation = newNavigation;
    _constructionToolbarState.currentPage = newPage;
    [self FL_constructionToolbarUpdateToolsAnimation:animation];

    if ([newNavigation isEqualToString:@"exports"] && _constructionToolbarState.toolbarNode.toolCount == 1) {
      [self FL_messageShow:NSLocalizedString(@"No exports found.",
                                             @"Message to user: Shown when navigating to exports submenu, but no exports are found.")];
    }

  } else if (toolType == FLToolbarToolTypeActionTap) {

    if ([toolTag isEqualToString:@"export"]) {
      if ([self FL_trackSelectedNone]) {
        [self FL_messageShow:NSLocalizedString(@"Export: Make a selection.",
                                               @"Message to user: Shown when export button is pressed but no track selection currently exists.")];
      } else {
        [self FL_export];
      }
    } else if ([toolTag isEqualToString:@"show-values"]) {
      [self FL_valuesToggle];
    } else if ([toolTag isEqualToString:@"show-labels"]) {
      [self FL_labelsToggle];
    }

  } else if (toolType == FLToolbarToolTypeActionPan) {

    [self FL_messageShow:_constructionToolbarState.toolDescriptions[toolTag]];

  } else if (toolType == FLToolbarToolTypeMode) {

    if ([toolTag isEqualToString:@"link"]) {
      [self FL_linksToggle];
    }

  }
}

- (void)handleConstructionToolbarLongPress:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
    return;
  }
  if (![_constructionToolbarState.currentNavigation isEqualToString:@"exports"]) {
    return;
  }

  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_constructionToolbarState.toolbarNode convertPoint:sceneLocation fromNode:self];
  NSString *toolTag = [_constructionToolbarState.toolbarNode toolAtLocation:toolbarLocation];
  if (!toolTag) {
    return;
  }

  NSString *description = _constructionToolbarState.toolDescriptions[toolTag];
  if (!description) {
    return;
  }

  NSString *title = [NSString stringWithFormat:@"Delete “%@”?", description];
  UIAlertView *confirmView = [[UIAlertView alloc] initWithTitle:title
                                                        message:nil
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Delete", nil];
  confirmView.alertViewStyle = UIAlertViewStyleDefault;
  _constructionToolbarState.deleteExportConfirmAlert = confirmView;
  _constructionToolbarState.deleteExportName = toolTag;
  _constructionToolbarState.deleteExportDescription = description;
  [confirmView show];
}

- (void)handleConstructionToolbarPan:(UIPanGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];

  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

    CGPoint firstTouchSceneLocation = [self convertPointFromView:_worldGestureState.gestureFirstTouchLocation];
    CGPoint firstTouchToolbarLocation = [_constructionToolbarState.toolbarNode convertPoint:firstTouchSceneLocation fromNode:self];
    NSString *toolTag = [_constructionToolbarState.toolbarNode toolAtLocation:firstTouchToolbarLocation];
    if (!toolTag) {
      _worldGestureState.panType = FLWorldPanTypeNone;
      return;
    }
    FLToolbarToolType toolType = (FLToolbarToolType)[_constructionToolbarState.toolTypes[toolTag] integerValue];
    if (toolType != FLToolbarToolTypeActionPan) {
      _worldGestureState.panType = FLWorldPanTypeNone;
      return;
    }
    [self FL_trackSelectClear];
    _worldGestureState.panType = FLWorldPanTypeTrackMove;

    if (_tutorialState.tutorialActive) {
      [self FL_tutorialRecognizedAction:FLTutorialActionConstructionToolbarPanBegan withArguments:@[ toolTag ]];
    }

    if ([_constructionToolbarState.currentNavigation isEqualToString:@"segments"]) {

      // Create segment.
      FLSegmentType segmentType = (FLSegmentType)[_constructionToolbarState.toolSegmentTypes[toolTag] integerValue];
      FLSegmentNode *newSegmentNode = [self FL_createSegmentWithSegmentType:segmentType];
      newSegmentNode.showsLabel = _labelsVisible;
      newSegmentNode.showsSwitchValue = _valuesVisible;
      newSegmentNode.zRotation = (CGFloat)M_PI_2;
      // note: Locate the new segment underneath the current touch, even though it's
      // not yet added to the node hierarchy.  (The track move routines translate nodes
      // relative to their current position.)
      int gridX;
      int gridY;
      _trackGrid->convert(worldLocation, &gridX, &gridY);
      newSegmentNode.position = _trackGrid->convert(gridX, gridY);
      [self FL_trackMoveBeganWithNodes:@[ newSegmentNode ] location:worldLocation completion:nil];

    } else {

      // Import segments.
      NSString *importDirectory;
      if ([_constructionToolbarState.currentNavigation isEqualToString:@"gates"]) {
        importDirectory = FLGatesDirectoryPath;
      } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"circuits"]) {
        importDirectory = FLCircuitsDirectoryPath;
      } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"exports"]) {
        importDirectory = FLExportsDirectoryPath;
      } else {
        [NSException raise:@"FLConstructionToolbarInvalidNavigation" format:@"Unrecognized navigation '%@'.", _constructionToolbarState.currentNavigation];
      }
      NSString *importPath = [importDirectory stringByAppendingPathComponent:[toolTag stringByAppendingPathExtension:@"archive"]];
      NSString *description;
      NSArray *links;
      NSArray *newSegmentNodes = [self FL_importWithPath:importPath description:&description links:&links];

      // Configure imported segments for this world.
      for (FLSegmentNode *segmentNode in newSegmentNodes) {
        segmentNode.showsLabel = _labelsVisible;
        segmentNode.showsSwitchValue = _valuesVisible;
      }

      // Locate the new segments underneath the current touch.
      //
      // note: Do so even though they are not yet added to the node hierarchy.  (The track move
      // routines translate nodes relative to their current position.)
      [self FL_segments:newSegmentNodes setPositionCenteredOnLocation:worldLocation];

      // Scale world to fit import, if possible.
      [self FL_worldFitSegments:newSegmentNodes scaling:YES scrolling:NO includeTrackEditMenu:YES animated:YES];

      // Begin track move.
      [self FL_messageShow:[NSString stringWithFormat:NSLocalizedString(@"Added “%@” to track.",
                                                                        @"Message to user: Shown after successful import of {export name}."),
                            description]];
      [self FL_trackMoveBeganWithNodes:newSegmentNodes location:worldLocation completion:^(BOOL placed){
        if (placed) {
          NSUInteger l = 0;
          while (l + 1 < [links count]) {
            FLSegmentNode *a = links[l];
            ++l;
            FLSegmentNode *b = links[l];
            ++l;
            SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:a.switchPosition toLocation:b.switchPosition linkErase:NO];
            self->_links.insert(a, b, connectorNode);
          }
        }
      }];
    }

    return;
  }

  if (_worldGestureState.panType != FLWorldPanTypeTrackMove) {
    return;
  }

  if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
    [self FL_trackMoveChangedWithLocation:worldLocation];
    [self FL_worldAutoScrollEnableForGestureWithLocation:sceneLocation gestureUpdateBlock:^{
      CGPoint scrolledWorldLocation = [self->_worldNode convertPoint:sceneLocation fromNode:self];
      [self FL_trackMoveChangedWithLocation:scrolledWorldLocation];
    }];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
    if (_tutorialState.tutorialActive) {
      [self FL_tutorialRecognizedAction:FLTutorialActionConstructionToolbarPanEnded withArguments:nil];
    }
    NSArray *placedSegmentNodes = [self FL_trackMoveEndedWithLocation:worldLocation];
    if (placedSegmentNodes) {
      [self FL_worldFitSegments:placedSegmentNodes scaling:NO scrolling:YES includeTrackEditMenu:YES animated:YES];
    }
    [self FL_worldAutoScrollDisable];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
    NSArray *placedSegmentNodes = [self FL_trackMoveCancelledWithLocation:worldLocation];
    if (placedSegmentNodes) {
      [self FL_worldFitSegments:placedSegmentNodes scaling:NO scrolling:YES includeTrackEditMenu:YES animated:YES];
    }
    [self FL_worldAutoScrollDisable];
  }
}

- (void)handleSimulationToolbarTap:(UIGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_simulationToolbarState.toolbarNode convertPoint:sceneLocation fromNode:self];
  NSString *toolTag = [_simulationToolbarState.toolbarNode toolAtLocation:toolbarLocation];
  if (!toolTag) {
    return;
  }

  if (_tutorialState.tutorialActive) {
    [self FL_tutorialRecognizedAction:FLTutorialActionSimulationToolbarTap withArguments:@[ toolTag ]];
  }

  if ([toolTag isEqualToString:@"menu"]) {
    id<FLTrackSceneDelegate> delegate = self.delegate;
    if (delegate) {
      [delegate trackSceneDidTapMenuButton:self];
    }
  } else if ([toolTag isEqualToString:@"play"]) {
    [self FL_trackEditMenuHideAnimated:YES];
    [self FL_simulationStart];
    [_trackNode runAction:[SKAction playSoundFileNamed:@"train-whistle-2.caf" waitForCompletion:NO]];
  } else if ([toolTag isEqualToString:@"pause"]) {
    [self FL_simulationStop];
    [_trackNode runAction:[SKAction playSoundFileNamed:@"train-stop-hiss.caf" waitForCompletion:NO]];
  } else if ([toolTag isEqualToString:@"ff"]) {
    [self FL_simulationCycleSpeed];
  } else if ([toolTag isEqualToString:@"fff"]) {
    [self FL_simulationCycleSpeed];
  } else if ([toolTag isEqualToString:@"center"]) {
    CGPoint trainSceneLocation = [self convertPoint:_train.position fromNode:_worldNode];
    [self FL_worldSetPositionX:(_worldNode.position.x - trainSceneLocation.x)
                     positionY:(_worldNode.position.y - trainSceneLocation.y)
              animatedDuration:FLWorldAdjustDuration
                    completion:^{
                      self->_cameraMode = FLCameraModeFollowTrain;
                    }];
  } else if ([toolTag isEqualToString:@"goals"]) {
    [self FL_goalsShowWithSplash:NO];
  }
}

- (void)handleSimulationToolbarLongPress:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
    return;
  }

  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_simulationToolbarState.toolbarNode convertPoint:sceneLocation fromNode:self];
  NSString *toolTag = [_simulationToolbarState.toolbarNode toolAtLocation:toolbarLocation];
  if (!toolTag) {
    return;
  }

  if ([toolTag isEqualToString:@"center"]) {
    [self FL_worldSetScale:1.0f animatedDuration:FLWorldAdjustDuration completion:nil];
  }
}

- (void)handleTrackEditMenuTap:(UIGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_trackEditMenuState.editMenuNode convertPoint:sceneLocation fromNode:self];
  NSString *buttonTag = [_trackEditMenuState.editMenuNode toolAtLocation:toolbarLocation];

  if ([buttonTag isEqualToString:@"rotate-cw"]) {
    [self FL_trackRotateSegments:_trackSelectState.selectedSegments rotateBy:-1 animated:YES];
  } else if ([buttonTag isEqualToString:@"rotate-ccw"]) {
    [self FL_trackRotateSegments:_trackSelectState.selectedSegments rotateBy:1 animated:YES];
  } else if ([buttonTag isEqualToString:@"toggle-switch"]) {
    [self FL_linkSwitchTogglePathIdForSegments:_trackSelectState.selectedSegments animated:YES];
  } else if ([buttonTag isEqualToString:@"set-label"]) {
    [self FL_labelPickForSegments:_trackSelectState.selectedSegments];
  } else if ([buttonTag isEqualToString:@"delete"]) {
    if (_gameType == FLGameTypeSandbox) {
      [self FL_trackEraseSegments:_trackSelectState.selectedSegments animated:YES];
      [self FL_trackSelectClear];
      [self FL_trackEditMenuHideAnimated:YES];
    } else {
      NSMutableArray *eraseSegments = [NSMutableArray array];
      for (FLSegmentNode *segmentNode in _trackSelectState.selectedSegments) {
        if ([self FL_gameTypeChallengeCanEraseSegment:segmentNode]) {
          [eraseSegments addObject:segmentNode];
        }
      }
      if ([eraseSegments count] > 0) {
        [self FL_trackEraseSegments:eraseSegments animated:YES];
        [self FL_trackSelectEraseSegments:eraseSegments];
        [self FL_trackEditMenuUpdateAnimated:YES];
      } else {
        [self FL_messageShow:NSLocalizedString(@"Cannot delete in this level.",
                                               @"Message to user: Shown when user tries to delete special track segments in challenge mode.")];
      }
    }
  }
}

- (void)handleTrackEditMenuLongPress:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
    return;
  }

  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_trackEditMenuState.editMenuNode convertPoint:sceneLocation fromNode:self];
  NSString *buttonTag = [_trackEditMenuState.editMenuNode toolAtLocation:toolbarLocation];

  if ([buttonTag isEqualToString:@"toggle-switch"]) {
    BOOL setEnabled = ![_trackEditMenuState.editMenuNode enabledForTool:buttonTag];
    for (FLSegmentNode *segmentNode in _trackSelectState.selectedSegments) {
      [self FL_linkSwitchSetEnabled:setEnabled forSegment:segmentNode];
    }
    // note: It should be possible to avoid recreating the track edit menu, and instead
    // just determine for ourselves whether or not the toggle-switch button should be
    // enabled or not.  And in particular, we have the advantage of knowing it was already
    // displayed, and so the decision whether to enable it or not should be somewhat
    // trivial.  However, until performance is an issue, don't violate the encapsulation
    // here; just let the track menu figure it out.
    [self FL_trackEditMenuShowAnimated:NO];
  }
}

- (void)handleTrainPan:(UIGestureRecognizer *)gestureRecognizer
{
  _cameraMode = FLCameraModeManual;

  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
    CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
    CGPoint sceneLocation = [self convertPointFromView:viewLocation];
    CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
    [self FL_trainMoveBeganWithLocation:worldLocation];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
    CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
    CGPoint sceneLocation = [self convertPointFromView:viewLocation];
    CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
    [self FL_trainMoveChangedWithLocation:worldLocation];
    [self FL_worldAutoScrollEnableForGestureWithLocation:sceneLocation gestureUpdateBlock:^{
      CGPoint scrolledWorldLocation = [self->_worldNode convertPoint:sceneLocation fromNode:self];
      [self FL_trainMoveChangedWithLocation:scrolledWorldLocation];
    }];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
    [self FL_trainMoveEnded];
    [self FL_worldAutoScrollDisable];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
    [self FL_trainMoveEnded];
    [self FL_worldAutoScrollDisable];
  }
}

- (void)handleTutorialTap:(UIGestureRecognizer *)gestureRecognizer
{
  [self FL_tutorialRecognizedAction:FLTutorialActionBackdropTap withArguments:nil];
}

- (void)handleTutorialLongPress:(UIGestureRecognizer *)gestureRecognizer
{
  [self FL_tutorialRecognizedAction:FLTutorialActionBackdropLongPress withArguments:nil];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  // I'm adding these one at a time as discovered needful, but so far things organize
  // themselves around the pan gesture recognizer:
  //
  //  . Pinch: I think this helps.  Otherwise it seems my pinch gesture sometimes gets
  //    interpreted as a pan.  I think.
  //
  //  . Taps: The way I wrote shouldReceiveTouch:, e.g. a tap on the train will get
  //    blocked because a train tap doesn't currently mean anything, but it doesn't let
  //    the tap fall through to anything below it.  I think that also means that the tap
  //    gesture doesn't get a chance to fail, which means the pan gesture never gets
  //    started at all.  Uuuuuuuunless I allow them to recognize simultaneously.  Ditto
  //    for _doubleTapRecognizer?  Untested.  But no, wait: Now I'm having problems where
  //    I'm in the middle of a pan (say, moving a track), and then suddenly the tap
  //    gesture recognizer fires (if I pan only a very short distance).  That's no good.
  //    So let's try no simultaneous again for a while.
  //
  //  . Long press: A pan motion after a long press should be handled only by the long
  //    press gesture recognizer, so no simultaneous recognition with pan.
  return gestureRecognizer == _panRecognizer && otherGestureRecognizer == _pinchRecognizer;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
  CGPoint viewLocation = [touch locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];

  // note: Remembering the first touch location is useful, for example, for a pan gesture recognizer,
  // which only knows where the gesture was first recognized (after possibly significant movement).
  _worldGestureState.gestureFirstTouchLocation = viewLocation;

  // note: Right now we just do a linear search through the various interface components to
  // see who wants to receive which gestures.  This could be replaced by some kind of general-purpose
  // registration system, where we register the component for a particular handler into a lookup table.
  // It doesn't seem linear would scale well, anyway, and so we might find ourselves maintaining a
  // lookup table regardless of the interface.

  // note: Currently, a handler is selected based on quick and easy criteria, which means a single
  // handler can end up handling a few different actions (e.g. the world handler handles track moves
  // and world pans).  The argument for putting all the logic here, and making the handlers extremely
  // fine-grained, would be that touches might need to fall through from one handler to another.  For
  // instance, maybe it takes a sophisticated check to determine if a tap within the bounds of a toolbar
  // should count as a tap on the toolbar or a tap on the world behind it.

  // Tutorial.
  if (_tutorialState.tutorialActive) {
    if (_tutorialState.backdropNode) {
      BOOL passGestureToOtherHandlers = NO;
      for (const FLTutorialCutout& cutout : _tutorialState.cutouts) {
        if (cutout.allowsGestures && CGRectContainsPoint(cutout.rect, sceneLocation)) {
          passGestureToOtherHandlers = YES;
          break;
        }
      }
      if (!passGestureToOtherHandlers) {
        if (gestureRecognizer == _tapRecognizer) {
          [gestureRecognizer removeTarget:nil action:nil];
          [gestureRecognizer addTarget:self action:@selector(handleTutorialTap:)];
          return YES;
        }
        if (gestureRecognizer == _longPressRecognizer) {
          [gestureRecognizer removeTarget:nil action:nil];
          [gestureRecognizer addTarget:self action:@selector(handleTutorialLongPress:)];
          return YES;
        }
        // note: Gesture is on backdrop for a gesture that the backdrop doesn't care about.
        // No gesture target added, and don't allow any other adds below.
        return NO;
      }
    } else if (_tutorialState.disallowOtherGestures) {
      // note: The backdrop always disallows other gestures.  But if the backdrop is hidden during an active
      // tutorial, the step setup will tell us whether we should disallow other gestures (e.g. to show a
      // "cutscene") or allow them (so the user can interact fully with the scene).
      return NO;
    }
  }

  // Modal overlay layer (handled by HLScene).
  if ([self modalNodePresented]) {
    return [super gestureRecognizer:gestureRecognizer shouldReceiveTouch:touch];
  }

  // Construction toolbar.
  if (_constructionToolbarState.toolbarNode
      && _constructionToolbarState.toolbarNode.parent
      && [_constructionToolbarState.toolbarNode containsPoint:sceneLocation]) {
    if (gestureRecognizer == _panRecognizer) {
      [gestureRecognizer removeTarget:nil action:nil];
      [gestureRecognizer addTarget:self action:@selector(handleConstructionToolbarPan:)];
      return YES;
    }
    if (gestureRecognizer == _tapRecognizer) {
      [gestureRecognizer removeTarget:nil action:nil];
      [gestureRecognizer addTarget:self action:@selector(handleConstructionToolbarTap:)];
      return YES;
    }
    if (gestureRecognizer == _longPressRecognizer) {
      [gestureRecognizer removeTarget:nil action:nil];
      [gestureRecognizer addTarget:self action:@selector(handleConstructionToolbarLongPress:)];
      return YES;
    }
    return NO;
  }

  // Simulation toolbar.
  if (_simulationToolbarState.toolbarNode
      && _simulationToolbarState.toolbarNode.parent
      && [_simulationToolbarState.toolbarNode containsPoint:sceneLocation]) {
    if (gestureRecognizer == _tapRecognizer) {
      [gestureRecognizer removeTarget:nil action:nil];
      [gestureRecognizer addTarget:self action:@selector(handleSimulationToolbarTap:)];
      return YES;
    }
    if (gestureRecognizer == _longPressRecognizer) {
      [gestureRecognizer removeTarget:nil action:nil];
      [gestureRecognizer addTarget:self action:@selector(handleSimulationToolbarLongPress:)];
      return YES;
    }
    return NO;
  }

  // Track edit menu.
  CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
  if (_trackEditMenuState.showing
      && [_trackEditMenuState.editMenuNode containsPoint:worldLocation]) {
    if (gestureRecognizer == _tapRecognizer) {
      [gestureRecognizer removeTarget:nil action:nil];
      [gestureRecognizer addTarget:self action:@selector(handleTrackEditMenuTap:)];
      return YES;
    }
    if (gestureRecognizer == _longPressRecognizer) {
      [gestureRecognizer removeTarget:nil action:nil];
      [gestureRecognizer addTarget:self action:@selector(handleTrackEditMenuLongPress:)];
      return YES;
    }
    return NO;
  }

  // Train.
  if (_train.parent
      && [_train containsPoint:worldLocation]) {
    if (gestureRecognizer == _panRecognizer) {
      [gestureRecognizer removeTarget:nil action:nil];
      [gestureRecognizer addTarget:self action:@selector(handleTrainPan:)];
      return YES;
    }
    return NO;
  }

  // World (and track).
  if (gestureRecognizer == _tapRecognizer) {
    [gestureRecognizer removeTarget:nil action:nil];
    [gestureRecognizer addTarget:self action:@selector(handleWorldTap:)];
    return YES;
  }
  if (gestureRecognizer == _doubleTapRecognizer) {
    [gestureRecognizer removeTarget:nil action:nil];
    [gestureRecognizer addTarget:self action:@selector(handleWorldDoubleTap:)];
    return YES;
  }
  if (gestureRecognizer == _longPressRecognizer) {
    [gestureRecognizer removeTarget:nil action:nil];
    [gestureRecognizer addTarget:self action:@selector(handleWorldLongPress:)];
    return YES;
  }
  if (gestureRecognizer == _panRecognizer) {
    [gestureRecognizer removeTarget:nil action:nil];
    [gestureRecognizer addTarget:self action:@selector(handleWorldPan:)];
    return YES;
  }
  if (gestureRecognizer == _pinchRecognizer) {
    [gestureRecognizer removeTarget:nil action:nil];
    [gestureRecognizer addTarget:self action:@selector(handleWorldPinch:)];
    return YES;
  }

  // None.
  //
  // noob: So, what if we return NO?  We want the gesture recognizer to be disabled, and its target
  // not to be called.  If returning NO doesn't do that, then try calling removeTarget:.
  return NO;
}

#pragma mark -
#pragma mark FLTrainDelegate

- (void)train:(FLTrain *)train triggeredSwitchAtSegment:(FLSegmentNode *)segmentNode pathId:(int)pathId
{
  [self FL_linkSwitchSetPathId:pathId forSegment:segmentNode animated:YES];
}

- (void)train:(FLTrain *)train stoppedAtSegment:(FLSegmentNode *)segmentNode
{
  // note: Currently only one train, so if train stops then stop the whole simulation.
  [self FL_simulationStop];
  [_trackNode runAction:[SKAction playSoundFileNamed:@"train-stop-hiss.caf" waitForCompletion:NO]];

  if (_gameType == FLGameTypeChallenge) {
    if (segmentNode.segmentType == FLSegmentTypePlatform) {
      FLSegmentNode *platformStartSegmentNode = nil;
      for (auto s : *_trackGrid) {
        if (s.second.segmentType == FLSegmentTypePlatformStart) {
          platformStartSegmentNode = s.second;
          break;
        }
      }
      if (platformStartSegmentNode) {
        const NSTimeInterval FLTrainFadeDuration = 0.1;
        [train runAction:[SKAction fadeOutWithDuration:FLTrainFadeDuration] completion:^{
          [train moveToSegment:platformStartSegmentNode pathId:0 progress:0.0f direction:FLPathDirectionIncreasing];
          [train runAction:[SKAction fadeInWithDuration:FLTrainFadeDuration]];
        }];
      }
    }
  } else if (segmentNode.segmentType == FLSegmentTypePlatform || segmentNode.segmentType == FLSegmentTypePlatformStart) {
    // note: Strictly speaking, we aren't allowed to mess with the train's zRotation.  But
    // we know the train is stopped, and we know we'll put it back on track in a second.
    const NSTimeInterval FLTrainRotateDuration = 0.4;
    [train runAction:[SKAction rotateByAngle:(CGFloat)M_PI duration:FLTrainRotateDuration] completion:^{
      [train moveToSegment:segmentNode pathId:0 progress:0.0f direction:FLPathDirectionIncreasing];
    }];
  }
}

- (void)train:(FLTrain *)train crashedAtSegment:(FLSegmentNode *)segmentNode
{
  // note: Currently only one train, so if train stops then stop the whole simulation.
  [self FL_simulationStop];
  [_trackNode runAction:[SKAction playSoundFileNamed:@"train-stop-hiss.caf" waitForCompletion:NO]];
}

#pragma mark -
#pragma mark Modal Presentation

- (void)presentModalNode:(SKNode *)node
               animation:(HLScenePresentationAnimation)animation
            zPositionMin:(CGFloat)zPositionMin
            zPositionMax:(CGFloat)zPositionMax
{
  [self FL_simulationStop];
  [super presentModalNode:node animation:animation zPositionMin:FLZPositionModalMin zPositionMax:FLZPositionModalMax];
}

#pragma mark -
#pragma mark Common

+ (void)FL_loadTextures
{
  // note: This is typically called on a background thread, and we load all our textures into a store
  // for convenient re-use.  It's not clear to me that SKTextures's preloadTextures:withCompletionHandler:
  // would do any better, but it might be worth checking.

  // note: Some sloppiness here in terms of resource-management: We use the shared HLTextureStore
  // rather than maintaining our own and passing it to those who need it; we preload textures for
  // (for example) FLTrain and FLSegmentNode rather than asking them to load themselves; etc.
  // This is justified, perhaps, since FLTrackScene is the master scene in the app, but be sure
  // to design more modularly if copying this pattern for other scenes.
  NSDate *startDate = [NSDate date];

  HLTextureStore *textureStore = [HLTextureStore sharedStore];

  // Train.
  [textureStore setTextureWithImageNamed:@"engine" andUIImageWithImageNamed:@"engine" forKey:@"engine" filteringMode:SKTextureFilteringNearest];

  // Tools.
  [textureStore setTextureWithImageNamed:@"menu" forKey:@"menu" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"play" forKey:@"play" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"pause" forKey:@"pause" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"ff" forKey:@"ff" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"fff" forKey:@"fff" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"center" forKey:@"center" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"goals" forKey:@"goals" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"delete" forKey:@"delete" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"rotate-cw" forKey:@"rotate-cw" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"rotate-ccw" forKey:@"rotate-ccw" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"set-label" forKey:@"set-label" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"toggle-switch" forKey:@"toggle-switch" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"main" forKey:@"main" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"next" forKey:@"next" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"previous" forKey:@"previous" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"segments" forKey:@"segments" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"gates" forKey:@"gates" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"circuits" forKey:@"circuits" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"exports" forKey:@"exports" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"link" forKey:@"link" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"show-labels" forKey:@"show-labels" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"show-values" forKey:@"show-values" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"export" forKey:@"export" filteringMode:SKTextureFilteringLinear];

  // Other.
  [textureStore setTextureWithImageNamed:@"switch" andUIImageWithImageNamed:@"switch-nonatlas.png" forKey:@"switch" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"value-0" andUIImageWithImageNamed:@"value-0-nonatlas.png" forKey:@"value-0" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"value-1" andUIImageWithImageNamed:@"value-1-nonatlas.png" forKey:@"value-1" filteringMode:SKTextureFilteringNearest];

  // Segments.
  [textureStore setTextureWithImageNamed:@"straight" andUIImageWithImageNamed:@"straight-nonatlas" forKey:@"straight" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"curve" andUIImageWithImageNamed:@"curve-nonatlas" forKey:@"curve" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"join-left" andUIImageWithImageNamed:@"join-left-nonatlas" forKey:@"join-left" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"join-right" andUIImageWithImageNamed:@"join-right-nonatlas" forKey:@"join-right" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"jog-left" andUIImageWithImageNamed:@"jog-left-nonatlas" forKey:@"jog-left" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"jog-right" andUIImageWithImageNamed:@"jog-right-nonatlas" forKey:@"jog-right" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"cross" andUIImageWithImageNamed:@"cross-nonatlas" forKey:@"cross" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"platform" andUIImageWithImageNamed:@"platform-nonatlas" forKey:@"platform" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"platform-start" andUIImageWithImageNamed:@"platform-start-nonatlas" forKey:@"platform-start" filteringMode:SKTextureFilteringNearest];
  // note: This looks particularly bad when used as a toolbar image -- which in fact is its only purpose.  But *all*
  // the segments look bad, so I'm choosing not to use linear filtering on this one, for now; see the TODO in HLToolbarNode.
  [textureStore setTextureWithImage:[FLSegmentNode createImageForReadoutSegment:FLSegmentTypeReadoutInput imageSize:FLSegmentArtSizeFull] forKey:@"readout-input" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImage:[FLSegmentNode createImageForReadoutSegment:FLSegmentTypeReadoutOutput imageSize:FLSegmentArtSizeFull] forKey:@"readout-output" filteringMode:SKTextureFilteringLinear];

  NSLog(@"FLTrackScene loadTextures: loaded in %0.2f seconds", [[NSDate date] timeIntervalSinceDate:startDate]);
}

+ (void)FL_loadEmitters
{
  // note: Again, sloppiness; see note in FL_loadTextures.
  NSDate *startDate = [NSDate date];

  HLEmitterStore *emitterStore = [HLEmitterStore sharedStore];
  SKEmitterNode *emitterNode;

  emitterNode = [emitterStore setEmitterWithResource:@"sleeperDestruction" forKey:@"sleeperDestruction"];
  // note: This kind of scaling thing makes me think having an FLTrackArtScale is a bad idea.  Resample the art instead.
  emitterNode.xScale = FLTrackArtScale;
  emitterNode.yScale = FLTrackArtScale;

  emitterNode = [emitterStore setEmitterWithResource:@"railDestruction" forKey:@"railDestruction"];
  emitterNode.xScale = FLTrackArtScale;
  emitterNode.yScale = FLTrackArtScale;

  NSLog(@"FLTrackScene loadEmitters: loaded in %0.2f seconds", [[NSDate date] timeIntervalSinceDate:startDate]);
}

+ (void)FL_loadSound
{
  NSDate *startDate = [NSDate date];

  // noob: Could make a store to control this, but it would be a weird store, since the
  // references to the sounds don't actually need to be tracked.
  [SKAction playSoundFileNamed:@"wooden-click-1.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"wooden-click-2.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"wooden-clickity-2.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"wooden-clatter-1.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"train-whistle-2.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"train-stop-hiss.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"ka-chick.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"train-whistle-tune-1.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"pop-2.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"plink-1.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"plink-2.caf" waitForCompletion:NO];

  NSLog(@"FLTrackScene loadSound: loaded in %0.2f seconds", [[NSDate date] timeIntervalSinceDate:startDate]);
}

- (void)FL_export
{
  if ([self FL_trackSelectedNone]) {
    return;
  }

  UIAlertView *inputView = [[UIAlertView alloc] initWithTitle:@"Exported Track Name"
                                                      message:nil
                                                     delegate:self
                                            cancelButtonTitle:@"Cancel"
                                            otherButtonTitles:@"Export", nil];
  inputView.alertViewStyle = UIAlertViewStylePlainTextInput;
  _exportState.descriptionInputAlert = inputView;
  [inputView show];
}

- (BOOL)FL_exportWithDescription:(NSString *)trackDescription
{
  CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
  CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuid);
  NSString *exportName = (__bridge_transfer NSString *)uuidString;
  CFRelease(uuid);

  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:FLExportsDirectoryPath]) {
    [fileManager createDirectoryAtPath:FLExportsDirectoryPath withIntermediateDirectories:NO attributes:nil error:NULL];
  }
  NSString *exportPath = [FLExportsDirectoryPath stringByAppendingPathComponent:[exportName stringByAppendingPathExtension:@"archive"]];

  // note: Could configure nodes in a standard way for export: e.g. no labels or values
  // showing and with the lower-leftmost segment (of the export) starting at position (0,0).
  // But these things are configured on import, and there seems to be no value in having the
  // raw data standardized.  A possible reason: Reducing nodes to their essentials makes the
  // data files more predictable (e.g. good for diffing).  Nah.  Not compelling.

  NSMutableData *archiveData = [NSMutableData data];
  NSKeyedArchiver *aCoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archiveData];

  [aCoder encodeObject:trackDescription forKey:@"trackDescription"];
  [aCoder encodeObject:_trackSelectState.selectedSegments forKey:@"segmentNodes"];
  NSMutableArray *links = [NSMutableArray array];
  for (auto link : _links) {
    FLSegmentNode *fromSegmentNode = (__bridge FLSegmentNode *)link.first.first;
    FLSegmentNode *toSegmentNode = (__bridge FLSegmentNode *)link.first.second;
    NSValue *fromSegmentNodePointer = [NSValue valueWithPointer:(void *)fromSegmentNode];
    NSValue *toSegmentNodePointer = [NSValue valueWithPointer:(void *)toSegmentNode];
    if ([_trackSelectState.selectedSegmentPointers containsObject:fromSegmentNodePointer]
        && [_trackSelectState.selectedSegmentPointers containsObject:toSegmentNodePointer]) {
      [links addObject:fromSegmentNode];
      [links addObject:toSegmentNode];
    }
  }
  [aCoder encodeObject:links forKey:@"links"];
  [aCoder finishEncoding];
  [archiveData writeToFile:exportPath atomically:NO];

  [self FL_messageShow:[NSString stringWithFormat:NSLocalizedString(@"Exported “%@”.",
                                                                    @"Message to user: Shown after a successful export of {export name}."),
                        trackDescription]];

  return YES;
}

- (void)FL_exportDelete:(NSString *)exportName description:(NSString *)trackDescription
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *exportPath = [FLExportsDirectoryPath stringByAppendingPathComponent:[exportName stringByAppendingPathExtension:@"archive"]];
  [fileManager removeItemAtPath:exportPath error:nil];

  [self FL_messageShow:[NSString stringWithFormat:NSLocalizedString(@"Deleted “%@”.",
                                                                    @"Message to user: Shown after a successful deletion of {export name}."),
                        trackDescription]];
  if ([_constructionToolbarState.currentNavigation isEqualToString:@"exports"]) {
    // note: Page might be too large as a result of the deletion.
    int pageMax = [self FL_constructionToolbarImportsPageMax:FLExportsDirectoryPath];
    if (_constructionToolbarState.currentPage > pageMax) {
      _constructionToolbarState.currentPage = pageMax;
    }
    [self FL_constructionToolbarShowExports:_constructionToolbarState.currentPage animation:HLToolbarNodeAnimationNone];
  }
}

- (NSArray *)FL_importWithPath:(NSString *)path description:(NSString * __autoreleasing *)trackDescription links:(NSArray * __autoreleasing *)links
{
  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
    [NSException raise:@"FLImportPathInvalid" format:@"Invalid import path %@.", path];
  }

  NSData *archiveData = [NSData dataWithContentsOfFile:path];
  NSKeyedUnarchiver *aDecoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:archiveData];

  NSArray *segmentNodes = [aDecoder decodeObjectForKey:@"segmentNodes"];
  if (trackDescription) {
    *trackDescription = [aDecoder decodeObjectForKey:@"trackDescription"];
    if (!*trackDescription) {
      *trackDescription = @"Unknown Description";
    }
  }
  if (links) {
    *links = [aDecoder decodeObjectForKey:@"links"];
  }

  [aDecoder finishDecoding];

  return segmentNodes;
}

- (FLSegmentNode *)FL_createSegmentWithSegmentType:(FLSegmentType)segmentType
{
  FLSegmentNode *segmentNode = [[FLSegmentNode alloc] initWithSegmentType:segmentType];
  segmentNode.scale = FLTrackArtScale;
  return segmentNode;
}

- (SKSpriteNode *)FL_createToolNodeForTextureKey:(NSString *)textureKey
{
  SKTexture *texture = [[HLTextureStore sharedStore] textureForKey:textureKey];
  SKSpriteNode *toolNode = [SKSpriteNode spriteNodeWithTexture:texture];
  toolNode.zRotation = (CGFloat)M_PI_2;
  return toolNode;
}

- (void)FL_segments:(NSArray *)segmentNodes getExtremesLeft:(CGFloat *)left right:(CGFloat *)right top:(CGFloat *)top bottom:(CGFloat *)bottom
{
  BOOL firstSegment = YES;
  for (FLSegmentNode *segmentNode in segmentNodes) {
    if (firstSegment) {
      firstSegment = NO;
      *left = segmentNode.position.x;
      *right = segmentNode.position.x;
      *top = segmentNode.position.y;
      *bottom = segmentNode.position.y;
    } else {
      if (segmentNode.position.x < *left) {
        *left = segmentNode.position.x;
      } else if (segmentNode.position.x > *right) {
        *right = segmentNode.position.x;
      }
      if (segmentNode.position.y < *bottom) {
        *bottom = segmentNode.position.y;
      } else if (segmentNode.position.y > *top) {
        *top = segmentNode.position.y;
      }
    }
  }
}

- (UIImage *)FL_segments:(NSArray *)segmentNodes createImageWithSize:(CGFloat)imageSize
{
  // TODO: Can this same purpose (eventually, to create a sprite node with this image)
  // be accomplished by calling "textureFromNode" method?  But keep in mind my desire
  // to trace out the path of the track segments with a constant-width line (with respect
  // to the final image size, no matter how many segments there are) rather than shrinking
  // the image down until you can't even see the shape -- textureFromNode probably can't
  // do that.

  CGFloat segmentsPositionLeft;
  CGFloat segmentsPositionRight;
  CGFloat segmentsPositionTop;
  CGFloat segmentsPositionBottom;
  [self FL_segments:segmentNodes getExtremesLeft:&segmentsPositionLeft right:&segmentsPositionRight top:&segmentsPositionTop bottom:&segmentsPositionBottom];

  // note: Keep in mind, segment images are drawn overlapping, with the "basic" segment size
  // representing the main content portion of the image drawn within the "full" segment size.
  CGFloat basicSegmentSize = FLSegmentArtSizeBasic * FLTrackArtScale;
  CGFloat fullSegmentSize = FLSegmentArtSizeFull * FLTrackArtScale;
  int widthUnits = int((segmentsPositionRight - segmentsPositionLeft + 0.00001f) / basicSegmentSize);
  int heightUnits = int((segmentsPositionTop - segmentsPositionBottom + 0.00001f) / basicSegmentSize);
  int sizeUnits = MAX(widthUnits, heightUnits);

  // note: The margin of the image contains the portion of the drawn segment that gets drawn
  // outside the basic segment area.  (As calculated here it's bigger than necessary, because
  // we don't actually typically draw all the way to the edge of the full segment area.)
  CGFloat imageMargin = imageSize * (fullSegmentSize - basicSegmentSize) / 2.0f / fullSegmentSize;

  CGFloat scaledBasicSegmentSize = (imageSize - imageMargin * 2.0f) / (sizeUnits + 1);
  CGFloat scaleBasicSegmentPosition = scaledBasicSegmentSize / basicSegmentSize;
  CGFloat scaledFullSegmentSize = scaleBasicSegmentPosition * fullSegmentSize;
  CGFloat halfScaledFullSegmentSize = scaledFullSegmentSize / 2.0f;
  CGFloat scaledBasicSegmentInset = (scaledFullSegmentSize - scaledBasicSegmentSize) / 2.0f;
  CGPoint shift = CGPointMake(segmentsPositionLeft - (sizeUnits - widthUnits) * basicSegmentSize / 2.0f,
                              segmentsPositionBottom - (sizeUnits - heightUnits) * basicSegmentSize / 2.0f);

  UIGraphicsBeginImageContext(CGSizeMake(imageSize, imageSize));
  CGContextRef context = UIGraphicsGetCurrentContext();
  // noob: From Apple documentation:
  //
  //   The default coordinate system used throughout UIKit is different from the coordinate system used by Quartz. In UIKit,
  //   the origin is in the upper-left corner, with the positive-y value pointing downward. The UIView object modifies the
  //   CTM of the Quartz graphics context to match the UIKit conventions by translating the origin to the upper left corner
  //   of the view and inverting the y-axis by multiplying it by -1. For more information on modified-coordinate systems and
  //   the implications in your own drawing code, see “Quartz 2D Coordinate Systems.”
  //
  // So when I load a png as a texture for an SKSpriteNode (SpriteKit uses a Quartz-like coordinate system),
  // the image shows the way I expect.  But when I draw to a Core graphics image context, and then capture a
  // UIImage using UIGraphicsGetImageFromCurrentImageContext(), and then use that image as a texture for an
  // SKSpriteNode, then the y-axis appears flipped.  The flipping operation, of course, is symmetrical, and
  // so to be honest I'm not entirely sure where the issue is introduced: Either the UIImage or the SKTexture
  // is doing one fewer or one more flips than I expect.  No matter what, flipping it once myself gives me the
  // result I expect.  I'm not sure that's the correct treatment.  (For instance, I could instead use
  // CGImageRef cgImage = CGBitmapContextCreateImage(context) to get a Quartz image, and then initialize the
  // texture using that image, which presumably would give me the result I expect.  But I haven't checked,
  // and HLTextureStore is factored in such a way that I want a UIImage.)
  CGContextTranslateCTM(context, 0.0f, imageSize);
  CGContextScaleCTM(context, 1.0f, -1.0f);
  // note: The segments are positioned and rotated according to scene coordinates, which uses Cartesian coordinates
  // and which by convention rotates all art M_PI_2 radians so that what is pointing to the right in the art asset
  // is pointing up in the scene.  So: rotate our context back to the right, so that we are creating an image in the
  // standard orientation (and with the standard origin) for art assets.
  CGContextTranslateCTM(context, 0.0f, imageSize);
  CGContextRotateCTM(context, -(CGFloat)M_PI_2);
  for (FLSegmentNode *segmentNode in segmentNodes) {
    UIImage *segmentNodeImage = [[HLTextureStore sharedStore] imageForKey:segmentNode.segmentKey];
    // Calculate final center position of the scaled segment (on the imageSize x imageSize image with origin in the lower left).
    CGPoint scaledSegmentPosition = CGPointMake((segmentNode.position.x - shift.x) * scaleBasicSegmentPosition - scaledBasicSegmentInset + imageMargin + halfScaledFullSegmentSize,
                                                (segmentNode.position.y - shift.y) * scaleBasicSegmentPosition - scaledBasicSegmentInset + imageMargin + halfScaledFullSegmentSize);
    CGContextSaveGState(context);
    // Move drawing context so its origin is at the image's target center position in the space.
    CGContextTranslateCTM(context, scaledSegmentPosition.x, scaledSegmentPosition.y);
    // Rotate drawing context (around its origin) so that when we draw the image it will be transformed
    // to the correct rotation.
    CGContextRotateCTM(context, segmentNode.zRotation);
    // The drawing context has its origin right in the center of where we want our image drawn;
    // the drawing target rectangle is specified by its lower left corner.
    CGContextDrawImage(context, CGRectMake(-halfScaledFullSegmentSize, -halfScaledFullSegmentSize, scaledFullSegmentSize, scaledFullSegmentSize), [segmentNodeImage CGImage]);
    // noob: Better/faster to unrotate and untranslate?
    CGContextRestoreGState(context);
  }
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return image;
}

- (void)FL_segments:(NSArray *)segmentNodes setPositionCenteredOnLocation:(CGPoint)worldLocation
{
  // note: The worldLocation will be aligned by this method to track grid square it is within;
  // the caller does not need to align it before passing it to this method.

  // Find position-aligned center point of segments.
  CGFloat segmentsPositionLeft;
  CGFloat segmentsPositionRight;
  CGFloat segmentsPositionTop;
  CGFloat segmentsPositionBottom;
  [self FL_segments:segmentNodes getExtremesLeft:&segmentsPositionLeft right:&segmentsPositionRight top:&segmentsPositionTop bottom:&segmentsPositionBottom];
  int widthUnits = int((segmentsPositionRight - segmentsPositionLeft + 0.00001f) / FLTrackSegmentSize);
  int heightUnits = int((segmentsPositionTop - segmentsPositionBottom + 0.00001f) / FLTrackSegmentSize);
  // note: Width and height of position differences, so for instance a width of one means
  // the group is two segments wide.
  CGPoint segmentsAlignedCenter = CGPointMake((segmentsPositionLeft + segmentsPositionRight) / 2.0f,
                                              (segmentsPositionBottom + segmentsPositionTop) / 2.0f);
  if (widthUnits % 2 == 1) {
    segmentsAlignedCenter.x -= (FLTrackSegmentSize / 2.0f);
  }
  if (heightUnits % 2 == 1) {
    segmentsAlignedCenter.y -= (FLTrackSegmentSize / 2.0f);
  }

  // Shift segments to the touch gesture (using calculated center).
  int gridX;
  int gridY;
  _trackGrid->convert(worldLocation, &gridX, &gridY);
  CGPoint touchAlignedCenter = _trackGrid->convert(gridX, gridY);
  CGPoint shift = CGPointMake(touchAlignedCenter.x - segmentsAlignedCenter.x,
                              touchAlignedCenter.y - segmentsAlignedCenter.y);
  for (FLSegmentNode *segmentNode in segmentNodes) {
    segmentNode.position = CGPointMake(segmentNode.position.x + shift.x,
                                       segmentNode.position.y + shift.y);
  }
}

- (void)FL_sceneGetVisibleLeft:(CGFloat *)left right:(CGFloat *)right top:(CGFloat *)top bottom:(CGFloat *)bottom
{
  CGSize sceneSize = self.size;

  *left = sceneSize.width * -1.0f * self.anchorPoint.x;

  *right = sceneSize.width * (1.0f - self.anchorPoint.x);

  HLToolbarNode *simulationToolbarNode = _simulationToolbarState.toolbarNode;
  if (simulationToolbarNode && simulationToolbarNode.parent) {
    CGFloat simulationToolbarBottom = simulationToolbarNode.position.y - simulationToolbarNode.size.height * simulationToolbarNode.anchorPoint.y;
    *top = simulationToolbarBottom;
  } else {
    *top = sceneSize.height * (1.0f - self.anchorPoint.y);
  }

  HLToolbarNode *constructionToolbarNode = _constructionToolbarState.toolbarNode;
  if (constructionToolbarNode && constructionToolbarNode.parent) {
    CGFloat constructionToolbarTop = constructionToolbarNode.position.y + constructionToolbarNode.size.height * (1.0f - constructionToolbarNode.anchorPoint.y);
    *bottom = constructionToolbarTop;
  } else {
    *bottom = sceneSize.height * -1.0f * self.anchorPoint.y;
  }
}

- (CGPoint)FL_worldConstrainedPositionX:(CGFloat)positionX
                              positionY:(CGFloat)positionY
                              forScaleX:(CGFloat)scaleX
                                 scaleY:(CGFloat)scaleY
{
  // note: World position is constrained by scale, not vice versa.
  CGFloat sceneHalfWidth = self.size.width / 2.0f;
  if (positionX < FLWorldXMin * scaleX + sceneHalfWidth - FLOffWorldScreenMargin) {
    positionX = FLWorldXMin * scaleX + sceneHalfWidth - FLOffWorldScreenMargin;
  } else if (positionX > FLWorldXMax * scaleX - sceneHalfWidth + FLOffWorldScreenMargin) {
    positionX = FLWorldXMax * scaleX - sceneHalfWidth + FLOffWorldScreenMargin;
  }
  CGFloat sceneHalfHeight = self.size.height / 2.0f;
  if (positionY < FLWorldYMin * scaleY + sceneHalfHeight - FLOffWorldScreenMargin) {
    positionY = FLWorldYMin * scaleY + sceneHalfHeight - FLOffWorldScreenMargin;
  } else if (positionY > FLWorldYMax * scaleY - sceneHalfHeight + FLOffWorldScreenMargin) {
    positionY = FLWorldYMax * scaleY - sceneHalfHeight + FLOffWorldScreenMargin;
  }
  return CGPointMake(positionX, positionY);
}

- (CGFloat)FL_worldConstrainedScale:(CGFloat)scale
{
  const CGFloat FLWorldScaleMin = 0.125f;
  const CGFloat FLWorldScaleMax = 1.0f;
  
  // note: World position is constrained by scale, not vice versa.  But minimum
  // scale is constrained by scene size.
  if (scale > FLWorldScaleMax) {
    scale = FLWorldScaleMax;
    return scale;
  }

  CGFloat worldScaleOffWorldLimit = MAX((self.size.width - FLOffWorldScreenMargin * 2.0f) / FLWorldSize.width,
                                        (self.size.height - FLOffWorldScreenMargin * 2.0f) / FLWorldSize.height);
  CGFloat worldScaleMin = MAX(FLWorldScaleMin, worldScaleOffWorldLimit);
  if (scale < worldScaleMin) {
    scale = worldScaleMin;
  }
  return scale;
}

- (void)FL_worldSetPositionX:(CGFloat)positionX
                   positionY:(CGFloat)positionY
{
  _worldNode.position = [self FL_worldConstrainedPositionX:positionX
                                                 positionY:positionY
                                                 forScaleX:_worldNode.xScale
                                                    scaleY:_worldNode.yScale];
}

- (void)FL_worldSetPositionX:(CGFloat)positionX
                   positionY:(CGFloat)positionY
            animatedDuration:(NSTimeInterval)duration
                  completion:(void (^)(void))completion
{
  CGPoint worldPosition = [self FL_worldConstrainedPositionX:positionX
                                                   positionY:positionY
                                                   forScaleX:_worldNode.xScale
                                                      scaleY:_worldNode.yScale];
  SKAction *move = [SKAction moveTo:worldPosition duration:duration];
  move.timingMode = SKActionTimingEaseInEaseOut;
  [_worldNode runAction:move completion:completion];
}

/**
 * Sets the world scale and updates all interface elements which depend on world
 * scale.  The passed scale is first constrained to legal values according to
 * FL_worldConstrainedScale.  Note that world position is constrained by scale,
 * not vice versa, so world position is one of the dependencies that will be
 * updated.
 */
- (void)FL_worldSetScale:(CGFloat)scale
{
  CGFloat constrainedScale = [self FL_worldConstrainedScale:scale];
  [self FL_worldSetConstrainedScale:constrainedScale
                          positionX:_worldNode.position.x
                          positionY:_worldNode.position.y];
}

/**
 * Animates the world scale to a new value and updates all interface elements which
 * depend on world scale (in animation if appropriate).  The passed scale is first
 * constrained to legal values according to FL_worldConstrainedScale.  Note that
 * world position is constrained by scale, not vice versa, so world position is one
 * of the dependencies that will be updated.
 */
- (void)FL_worldSetScale:(CGFloat)scale
        animatedDuration:(NSTimeInterval)duration
              completion:(void (^)(void))completion
{
  CGFloat constrainedScale = [self FL_worldConstrainedScale:scale];
  // note: Could re-use FL_worldSetConstrainedScale:positionX:positionY:animatedDuration:completion:
  // here, but that does a little extra unnecessary computation for position (which is assumes is
  // changing over the animation duration).
  CGFloat startScale = _worldNode.xScale;
  CGFloat positionX = _worldNode.position.x;
  CGFloat positionY = _worldNode.position.y;
  SKAction *scaleWorld = [SKAction customActionWithDuration:duration actionBlock:^(SKNode *node, CGFloat elapsedTime){
    CGFloat currentScale = startScale + (constrainedScale - startScale) * (CGFloat)(elapsedTime / duration);
    node.xScale = currentScale;
    node.yScale = currentScale;
    [self FL_trackEditMenuScaleToWorld];
    // note: Maybe smoother to constrain the position once before animation, and animate
    // to that position?  Might even be able to skip the constraint checks in the animation,
    // since any intermediate values will be temporary.
    node.position = [self FL_worldConstrainedPositionX:positionX
                                             positionY:positionY
                                             forScaleX:currentScale
                                                scaleY:currentScale];
  }];
  scaleWorld.timingMode = SKActionTimingEaseInEaseOut;
  [_worldNode runAction:scaleWorld completion:completion];
}

/**
 * Sets the world scale and position and updates all interface elements which depend
 * on world scale.  The passed scale is first constrained to legal values according to
 * FL_worldConstrainedScale.  Note that the passed world position is constrained by scale,
 * not vice versa.
 *
 * note: The caller is responsible to constrain the scale value using FL_worldConstrainedScale
 * before calling this method.  (This is because the caller typically needs to know the final
 * scale value before calling, and so we shouldn't change it after it's been passed to us.)
 */
- (void)FL_worldSetConstrainedScale:(CGFloat)constrainedScale
                          positionX:(CGFloat)positionX
                          positionY:(CGFloat)positionY
{
  _worldNode.xScale = constrainedScale;
  _worldNode.yScale = constrainedScale;
  [self FL_trackEditMenuScaleToWorld];
  _worldNode.position = [self FL_worldConstrainedPositionX:positionX
                                                 positionY:positionY
                                                 forScaleX:constrainedScale
                                                    scaleY:constrainedScale];
}

/**
 * Animates the world scale and position to new values and updates all interface elements
 * which depend on world scale (in animation if appropriate).  The passed scale is first
 * constrained to legal values according to FL_worldConstrainedScale.  Note that the passed
 * world position is constrained by scale, not vice versa.
 *
 * note: The caller is responsible to constrain the scale value using FL_worldConstrainedScale
 * before calling this method.  (This is because the caller typically needs to know the final
 * scale value before calling, and so we shouldn't change it after it's been passed to us.)
 */
- (void)FL_worldSetConstrainedScale:(CGFloat)constrainedScale
                          positionX:(CGFloat)positionX
                          positionY:(CGFloat)positionY
                   animatedDuration:(NSTimeInterval)duration
                         completion:(void (^)(void))completion
{
  CGFloat startScale = _worldNode.xScale;
  CGFloat startPositionX = _worldNode.position.x;
  CGFloat startPositionY = _worldNode.position.y;
  SKAction *scaleWorld = [SKAction customActionWithDuration:duration actionBlock:^(SKNode *node, CGFloat elapsedTime){
    CGFloat elapsedProportion = (CGFloat)(elapsedTime / duration);
    CGFloat currentScale = startScale + (constrainedScale - startScale) * elapsedProportion;
    node.xScale = currentScale;
    node.yScale = currentScale;
    [self FL_trackEditMenuScaleToWorld];
    // note: Maybe smoother to constrain the position once before animation, and animate
    // to that position?  Might even be able to skip the constraint checks in the animation,
    // since any intermediate values will be temporary.
    CGFloat currentPositionX = startPositionX + (positionX - startPositionX) * elapsedProportion;
    CGFloat currentPositionY = startPositionY + (positionY - startPositionY) * elapsedProportion;
    node.position = [self FL_worldConstrainedPositionX:currentPositionX
                                             positionY:currentPositionY
                                             forScaleX:currentScale
                                                scaleY:currentScale];
  }];
  scaleWorld.timingMode = SKActionTimingEaseInEaseOut;
  [_worldNode runAction:scaleWorld completion:completion];
}

- (void)FL_worldFitSegments:(NSArray *)segmentNodes
                    scaling:(BOOL)scaling
                  scrolling:(BOOL)scrolling
       includeTrackEditMenu:(BOOL)includeTrackEditMenu
                   animated:(BOOL)animated
{
  CGFloat contentWorldLeft;
  CGFloat contentWorldRight;
  CGFloat contentWorldTop;
  CGFloat contentWorldBottom;
  [self FL_segments:segmentNodes getExtremesLeft:&contentWorldLeft right:&contentWorldRight top:&contentWorldTop bottom:&contentWorldBottom];
  // note: The segment extrema are returned as segment positions (centers of segments).  We want to
  // pad out farther: A half segment size gets us to the edge of the basic segment, but of course
  // track runs along the edge and overlaps into the next segment.  So push it out to full segment
  // size, for sure, plus a little visual padding: Perhaps another half (basic) segments size
  // is about right.
  contentWorldLeft -= FLTrackSegmentSize;
  contentWorldRight += FLTrackSegmentSize;
  contentWorldTop += FLTrackSegmentSize;
  contentWorldBottom -= FLTrackSegmentSize;
  CGSize contentWorldSize = CGSizeMake(contentWorldRight - contentWorldLeft, contentWorldTop - contentWorldBottom);

  CGFloat visibleSceneLeft;
  CGFloat visibleSceneRight;
  CGFloat visibleSceneTop;
  CGFloat visibleSceneBottom;
  [self FL_sceneGetVisibleLeft:&visibleSceneLeft right:&visibleSceneRight top:&visibleSceneTop bottom:&visibleSceneBottom];
  CGSize visibleSceneSize = CGSizeMake(visibleSceneRight - visibleSceneLeft, visibleSceneTop - visibleSceneBottom);

  CGFloat worldConstrainedScaleNew = _worldNode.xScale;
  if (scaling) {
    CGFloat worldScaleNew;
    if (includeTrackEditMenu) {
      // note: For now, don't bother calculating track edit menu width from segmentNodes
      // using [self FL_trackEditMenuWidthForSegments:segmentNodes].  Instead, assume that
      // the toolbar width fits on the screen at all world scales.
      worldScaleNew = [self FL_trackEditMenuWorldScaleToFitSegmentSize:contentWorldSize intoTargetSceneSize:visibleSceneSize withTrackEditMenuWidth:0.0f];
    } else {
      worldScaleNew = MIN(visibleSceneSize.width / contentWorldSize.width,
                          visibleSceneSize.height / contentWorldSize.height);
    }
    worldConstrainedScaleNew = [self FL_worldConstrainedScale:worldScaleNew];
  }

  CGPoint worldPositionNew;
  if (scrolling) {

    // Calculate some additional helpful scrolling-relevant metrics.
    CGSize visibleWorldSize = CGSizeMake(visibleSceneSize.width / worldConstrainedScaleNew,
                                         visibleSceneSize.height / worldConstrainedScaleNew);
    CGPoint visibleSceneCenter = CGPointMake(visibleSceneLeft + (visibleSceneRight - visibleSceneLeft) / 2.0f,
                                             visibleSceneBottom + (visibleSceneTop - visibleSceneBottom) / 2.0f);
    CGPoint visibleWorldCenter = CGPointMake((visibleSceneCenter.x - _worldNode.position.x) / worldConstrainedScaleNew,
                                             (visibleSceneCenter.y - _worldNode.position.y) / worldConstrainedScaleNew);

    // Include track edit menu (if appropriate) in content bounds, size, and center.
    CGPoint contentWorldCenter = CGPointMake(contentWorldLeft + (contentWorldRight - contentWorldLeft) / 2.0f,
                                             contentWorldBottom + (contentWorldTop - contentWorldBottom) / 2.0f);
    if (includeTrackEditMenu) {
      CGFloat trackEditMenuScale = [self FL_trackEditMenuScaleForWorldScale:worldConstrainedScaleNew];
      CGFloat trackEditMenuWorldWidth = [self FL_trackEditMenuWidthForSegments:segmentNodes] * trackEditMenuScale;
      if (trackEditMenuWorldWidth > contentWorldSize.width) {
        CGFloat halfTrackEditMenuWorldWidth = trackEditMenuWorldWidth / 2.0f;
        contentWorldLeft = contentWorldCenter.x - halfTrackEditMenuWorldWidth;
        contentWorldRight = contentWorldCenter.x + halfTrackEditMenuWorldWidth;
        contentWorldSize.width = trackEditMenuWorldWidth;
      }
      CGFloat trackEditMenuWorldHeight = FLTrackEditMenuSegmentPad + FLTrackEditMenuHeight * trackEditMenuScale;
      contentWorldTop += trackEditMenuWorldHeight;
      contentWorldSize.height += trackEditMenuWorldHeight;
      contentWorldCenter.y += trackEditMenuWorldHeight / 2.0f;
    }

    // Adjust world position (in scene) to fit content (as much as possible).
    CGPoint visibleWorldCenterNew = visibleWorldCenter;
    if (contentWorldSize.width > visibleWorldSize.width) {
      visibleWorldCenterNew.x = contentWorldCenter.x;
    } else if (abs(visibleWorldCenter.x - contentWorldCenter.x) < (visibleWorldSize.width - contentWorldSize.width) / 2.0f) {
      // note: Already fits in visible area.
    } else if (visibleWorldCenter.x < contentWorldCenter.x) {
      visibleWorldCenterNew.x = contentWorldRight - visibleWorldSize.width / 2.0f;
    } else {
      visibleWorldCenterNew.x = contentWorldLeft + visibleWorldSize.width / 2.0f;
    }
    if (contentWorldSize.height > visibleWorldSize.height) {
      if (includeTrackEditMenu) {
        visibleWorldCenterNew.y = contentWorldTop - visibleWorldSize.height / 2.0f;
      } else {
        visibleWorldCenterNew.y = contentWorldCenter.y;
      }
    } else if (abs(visibleWorldCenter.y - contentWorldCenter.y) < (visibleWorldSize.height - contentWorldSize.height) / 2.0f) {
      // note: Already fits in visible area.
    } else if (visibleWorldCenter.y < contentWorldCenter.y) {
      visibleWorldCenterNew.y = contentWorldTop - visibleWorldSize.height / 2.0f;
    } else {
      visibleWorldCenterNew.y = contentWorldBottom + visibleWorldSize.height / 2.0f;
    }
    worldPositionNew.x = visibleSceneCenter.x - visibleWorldCenterNew.x * worldConstrainedScaleNew;
    worldPositionNew.y = visibleSceneCenter.y - visibleWorldCenterNew.y * worldConstrainedScaleNew;
  }
  // note: worldPositionNew not yet constrained to world; do it below.

  if ((!scaling || abs(worldConstrainedScaleNew - _worldNode.xScale) < 0.001f)
      && (!scrolling || (abs(worldPositionNew.x - _worldNode.position.x) < 0.1f
                         && abs(worldPositionNew.y - _worldNode.position.y) < 0.1f))) {
    return;
  }
  
  if (animated) {
    [self FL_worldSetConstrainedScale:worldConstrainedScaleNew
                            positionX:worldPositionNew.x
                            positionY:worldPositionNew.y
                     animatedDuration:FLWorldFitDuration
                           completion:nil];
  } else {
    [self FL_worldSetConstrainedScale:worldConstrainedScaleNew
                            positionX:worldPositionNew.x
                            positionY:worldPositionNew.y];
  }
}

/**
 * Update the auto scroll state based on the scene location of a relevant gesture (usually
 * a pan): If the gesture is within a margin near the edge of the screen, then enable
 * auto-scrolling and set the velocity of the auto-scroll.
 *
 * The actual scroll, at the calculated velocities, will be triggered through calls to
 * update:.  The gestureUpdateBlock will be called immediately after the scroll in update:.
 * The canonical use-case is like this: The user drags someting to the edge of the screen,
 * which triggers an auto-scroll.  The user pauses the drag gesture (relative to the screen
 * waiting while the world scrolls to the right place.  Meanwhile, since the drag gesture is
 * paused, the pan gesture recognizer isn't getting any updates, and so the item being dragged
 * is left behind.  The gestureUpdateBlock can fix this, because it can call into the gesture
 * handling code for a drag (relative to the world) even though the gesture hasn't changed
 * (relative to the screen).
 */
- (void)FL_worldAutoScrollEnableForGestureWithLocation:(CGPoint)sceneLocation gestureUpdateBlock:(void(^)(void))gestureUpdateBlock
{
  // note: Consider adding an auto-scroll delay: Only auto-scroll after a gesture
  // has been inside the margin for a little while.

  const CGFloat FLWorldAutoScrollMarginSizeMax = 96.0f;
  CGFloat marginSize = MIN(self.size.width, self.size.height) / 10.0f;
  if (marginSize > FLWorldAutoScrollMarginSizeMax) {
    marginSize = FLWorldAutoScrollMarginSizeMax;
  }

// Commented out karl: I'm surprised to find that I like this old autoscroll (which
// only goes in X direction, or Y direction, or both equally) as much or maybe more
// than the new autoscroll (which scrolls in a radial direction from center of screen).
// So, keep it around for a little while I decide which to keep.
//
//  // note: Proximity measures linearly how close the gesture is to the edge of the screen,
//  // ranging from zero to one, where one is all the way on the screen's edge.  Velocity
//  // has a magnitude indicating the speed of the scrolling, in screen points, and a direction
//  // indicating the direction of the scroll along the X or Y axis.
//  //
//  // note: Current formula for velocity magnitude:
//  //
//  //   v_mag = base^p + linear*p + min
//  //
//  // It's mostly linear for the first half of proximity, and then the exponent term takes over.
//  const CGFloat FLAutoScrollVelocityMin = 4.0f;
//  const CGFloat FLAutoScrollVelocityLinear = 108.0f;
//  const CGFloat FLAutoScrollVelocityBase = 256.0f;
//
//  _worldAutoScrollState.scrolling = NO;
//
//  CGFloat sceneXMin = self.size.width * -1.0f * self.anchorPoint.x;
//  CGFloat sceneXMax = sceneXMin + self.size.width;
//  if (sceneLocation.x < sceneXMin + marginSize) {
//    CGFloat proximity = ((sceneXMin + marginSize) - sceneLocation.x) / marginSize;
//    CGFloat speed = pow(FLAutoScrollVelocityBase, proximity) + FLAutoScrollVelocityLinear * proximity + FLAutoScrollVelocityMin;
//    _worldAutoScrollState.scrolling = YES;
//    _worldAutoScrollState.velocityX = -1.0f * speed;
//  } else if (sceneLocation.x > sceneXMax - marginSize) {
//    CGFloat proximity = (sceneLocation.x - (sceneXMax - marginSize)) / marginSize;
//    CGFloat speed = pow(FLAutoScrollVelocityBase, proximity) + FLAutoScrollVelocityLinear * proximity + FLAutoScrollVelocityMin;
//    _worldAutoScrollState.scrolling = YES;
//    _worldAutoScrollState.velocityX = speed;
//  } else {
//    _worldAutoScrollState.velocityX = 0.0f;
//  }
//
//  CGFloat sceneYMin = self.size.height * -1.0f * self.anchorPoint.y;
//  CGFloat sceneYMax = sceneYMin + self.size.height;
//  if (sceneLocation.y < sceneYMin + marginSize) {
//    CGFloat proximity = ((sceneYMin + marginSize) - sceneLocation.y) / marginSize;
//    CGFloat speed = pow(FLAutoScrollVelocityBase, proximity) + FLAutoScrollVelocityLinear * proximity + FLAutoScrollVelocityMin;
//    _worldAutoScrollState.scrolling = YES;
//    _worldAutoScrollState.velocityY = -1.0f * speed;
//  } else if (sceneLocation.y > sceneYMax - marginSize) {
//    CGFloat proximity = (sceneLocation.y - (sceneYMax - marginSize)) / marginSize;
//    CGFloat speed = pow(FLAutoScrollVelocityBase, proximity) + FLAutoScrollVelocityLinear * proximity + FLAutoScrollVelocityMin;
//    _worldAutoScrollState.scrolling = YES;
//    _worldAutoScrollState.velocityY = speed;
//  } else {
//    _worldAutoScrollState.velocityY = 0.0f;
//  }
//
//  if (_worldAutoScrollState.scrolling) {
//    _worldAutoScrollState.gestureUpdateBlock = gestureUpdateBlock;
//  }


  // note: Proximity measures linearly how close the gesture is to the edge of the screen,
  // ranging from zero to one, where one is all the way on the screen's edge.  (If the gesture
  // is close to two edges, the closer one is used.)  A velocity vector is calculated in X
  // and Y vector components; each component has magnitude (speed in screen points) and sign
  // (direction) along the corresponding axis.
  //
  // note: Current formula for velocity magnitude (speed):
  //
  //   v_mag = base^p + linear*p + min
  //
  // With the below values, it's mostly linear for the first half of proximity, and then the
  // exponent term takes over.
  const CGFloat FLAutoScrollVelocityMin = 4.0f;
  const CGFloat FLAutoScrollVelocityLinear = 108.0f;
  const CGFloat FLAutoScrollVelocityBase = 256.0f;

  _worldAutoScrollState.scrolling = NO;

  CGFloat sceneXMin = self.size.width * -1.0f * self.anchorPoint.x;
  CGFloat sceneXMax = sceneXMin + self.size.width;
  CGFloat sceneYMin = self.size.height * -1.0f * self.anchorPoint.y;
  CGFloat sceneYMax = sceneYMin + self.size.height;

  CGFloat proximity = 0.0f;
  if (sceneLocation.x < sceneXMin + marginSize) {
    CGFloat proximityX = ((sceneXMin + marginSize) - sceneLocation.x) / marginSize;
    proximity = proximityX;
    _worldAutoScrollState.scrolling = YES;
  } else if (sceneLocation.x > sceneXMax - marginSize) {
    CGFloat proximityX = (sceneLocation.x - (sceneXMax - marginSize)) / marginSize;
    proximity = proximityX;
    _worldAutoScrollState.scrolling = YES;
  }
  if (sceneLocation.y < sceneYMin + marginSize) {
    CGFloat proximityY = ((sceneYMin + marginSize) - sceneLocation.y) / marginSize;
    if (proximityY > proximity) {
      proximity = proximityY;
    }
    _worldAutoScrollState.scrolling = YES;
  } else if (sceneLocation.y > sceneYMax - marginSize) {
    CGFloat proximityY = (sceneLocation.y - (sceneYMax - marginSize)) / marginSize;
    if (proximityY > proximity) {
      proximity = proximityY;
    }
    _worldAutoScrollState.scrolling = YES;
  }

  if (_worldAutoScrollState.scrolling) {

    CGFloat sceneXCenter = sceneXMin + self.size.width / 2.0f;
    CGFloat sceneYCenter = sceneYMin + self.size.height / 2.0f;
    CGFloat locationOffsetX = sceneLocation.x - sceneXCenter;
    CGFloat locationOffsetY = sceneLocation.y - sceneYCenter;
    CGFloat locationOffsetSum = abs(locationOffsetX) + abs(locationOffsetY);
    CGFloat speed = pow(FLAutoScrollVelocityBase, proximity) + FLAutoScrollVelocityLinear * proximity + FLAutoScrollVelocityMin;
    _worldAutoScrollState.velocityX = (locationOffsetX / locationOffsetSum) * speed;
    _worldAutoScrollState.velocityY = (locationOffsetY / locationOffsetSum) * speed;

    _worldAutoScrollState.gestureUpdateBlock = gestureUpdateBlock;
  }
}

- (void)FL_worldAutoScrollDisable
{
  _worldAutoScrollState.scrolling = NO;
  _worldAutoScrollState.gestureUpdateBlock = nil;
}

- (void)FL_worldAutoScrollUpdate:(CFTimeInterval)elapsedTime
{
  // note: Precondition: _worldAutoScrollState.scrolling == YES.
  CGFloat scrollXDistance = _worldAutoScrollState.velocityX * (CGFloat)elapsedTime;
  CGFloat scrollYDistance = _worldAutoScrollState.velocityY * (CGFloat)elapsedTime;
  // note: Scrolling velocity is measured in scene units, not world units (i.e. regardless of world scale).
  [self FL_worldSetPositionX:(_worldNode.position.x - scrollXDistance / _worldNode.xScale)
                   positionY:(_worldNode.position.y - scrollYDistance / _worldNode.yScale)];
  if (_worldAutoScrollState.gestureUpdateBlock) {
    _worldAutoScrollState.gestureUpdateBlock();
  }
}

- (void)FL_constructionToolbarSetVisible:(BOOL)visible
{
  if (!_constructionToolbarState.toolbarNode) {
    _constructionToolbarState.toolbarNode = [[HLToolbarNode alloc] init];
    _constructionToolbarState.toolbarNode.backgroundBorderSize = 4.0f;
    _constructionToolbarState.toolbarNode.squareSeparatorSize = 4.0;
    _constructionToolbarState.toolbarNode.anchorPoint = CGPointMake(0.5f, 0.0f);
    [self FL_constructionToolbarUpdateGeometry];
  }

  if (visible) {
    if (!_constructionToolbarState.toolbarNode.parent) {
      [_hudNode addChild:_constructionToolbarState.toolbarNode];
    }
  } else {
    if (_constructionToolbarState.toolbarNode.parent) {
      [_constructionToolbarState.toolbarNode removeFromParent];
    }
  }
}

- (void)FL_constructionToolbarUpdateGeometry
{
  _constructionToolbarState.toolbarNode.automaticWidth = NO;
  _constructionToolbarState.toolbarNode.automaticHeight = NO;
  _constructionToolbarState.toolbarNode.position = CGPointMake(0.0f, -self.size.height / 2.0f);
  _constructionToolbarState.toolbarNode.size = CGSizeMake(self.size.width, FLMainToolbarHeight);

  // note: Page might be too large as a result of additional toolbar width made possible by the new geometry.
  int pageMax = _constructionToolbarState.currentPage;
  if ([_constructionToolbarState.currentNavigation isEqualToString:@"gates"]) {
    pageMax = [self FL_constructionToolbarImportsPageMax:FLGatesDirectoryPath];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"circuits"]) {
    pageMax = [self FL_constructionToolbarImportsPageMax:FLCircuitsDirectoryPath];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"exports"]) {
    pageMax = [self FL_constructionToolbarImportsPageMax:FLExportsDirectoryPath];
  }
  if (_constructionToolbarState.currentPage > pageMax) {
    _constructionToolbarState.currentPage = pageMax;
  }

  [self FL_constructionToolbarUpdateToolsAnimation:HLToolbarNodeAnimationNone];
}

- (void)FL_constructionToolbarUpdateToolsAnimation:(HLToolbarNodeAnimation)animation
{
  if ([_constructionToolbarState.currentNavigation isEqualToString:@"main"]) {
    [self FL_constructionToolbarShowMain:_constructionToolbarState.currentPage animation:animation];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"segments"]) {
    [self FL_constructionToolbarShowSegments:_constructionToolbarState.currentPage animation:animation];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"gates"]) {
    [self FL_constructionToolbarShowGates:_constructionToolbarState.currentPage animation:animation];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"circuits"]) {
    [self FL_constructionToolbarShowCircuits:_constructionToolbarState.currentPage animation:animation];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"exports"]) {
    [self FL_constructionToolbarShowExports:_constructionToolbarState.currentPage animation:animation];
  } else {
    [NSException raise:@"FLConstructionToolbarInvalidNavigation" format:@"Unrecognized navigation '%@'.", _constructionToolbarState.currentNavigation];
  }
}

- (void)FL_constructionToolbarShowMain:(int)page animation:(HLToolbarNodeAnimation)animation
{
  NSMutableArray *toolNodes = [NSMutableArray array];
  NSMutableArray *toolTags = [NSMutableArray array];
  NSString *textureKey;

  textureKey = @"segments";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);

  if ([self FL_unlocked:FLUnlockGates]) {
    textureKey = @"gates";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  }

  if ([self FL_unlocked:FLUnlockCircuits]) {
    textureKey = @"circuits";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  }

  textureKey = @"exports";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);

  textureKey = @"link";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeMode);

  textureKey = @"show-labels";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionTap);

  textureKey = @"show-values";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionTap);

  textureKey = @"export";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionTap);

  [_constructionToolbarState.toolbarNode setTools:toolNodes tags:toolTags animation:animation];

  [_constructionToolbarState.toolbarNode setHighlight:_linksVisible forTool:@"link"];
  [_constructionToolbarState.toolbarNode setHighlight:_labelsVisible forTool:@"show-labels"];
  [_constructionToolbarState.toolbarNode setHighlight:_valuesVisible forTool:@"show-values"];
}

- (void)FL_constructionToolbarShowSegments:(int)page animation:(HLToolbarNodeAnimation)animation
{
  NSMutableArray *toolNodes = [NSMutableArray array];
  NSMutableArray *toolTags = [NSMutableArray array];
  NSString *textureKey;

  textureKey = @"straight";
  [toolTags addObject:textureKey];
  SKSpriteNode *toolNode = [self FL_createToolNodeForTextureKey:textureKey];
  toolNode.position = CGPointMake(FLSegmentArtStraightShift, 0.0f);
  [toolNodes addObject:toolNode];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = @"Straight Track";
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeStraight);

  textureKey = @"curve";
  [toolTags addObject:textureKey];
  toolNode = [self FL_createToolNodeForTextureKey:textureKey];
  toolNode.position = CGPointMake(FLSegmentArtCurveShift, -FLSegmentArtCurveShift);
  [toolNodes addObject:toolNode];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = @"Curved Track";
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeCurve);

  textureKey = @"join-left";
  [toolTags addObject:textureKey];
  toolNode = [self FL_createToolNodeForTextureKey:textureKey];
  toolNode.position = CGPointMake(FLSegmentArtCurveShift, -FLSegmentArtCurveShift);
  [toolNodes addObject:toolNode];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = @"Fork Right Track";
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeJoinLeft);

  textureKey = @"join-right";
  [toolTags addObject:textureKey];
  toolNode = [self FL_createToolNodeForTextureKey:textureKey];
  toolNode.position = CGPointMake(FLSegmentArtCurveShift, FLSegmentArtCurveShift);
  [toolNodes addObject:toolNode];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = @"Fork Left Track";
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeJoinRight);

  textureKey = @"jog-left";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = @"Jog Left Track";
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeJogLeft);

  textureKey = @"jog-right";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = @"Jog Right Track";
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeJogRight);

  textureKey = @"cross";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = @"Cross Track";
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeCross);

  if (_gameType == FLGameTypeSandbox) {
    textureKey = @"readout-input";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
    _constructionToolbarState.toolDescriptions[textureKey] = @"Input Value";
    _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeReadoutInput);
  }

  if (_gameType == FLGameTypeSandbox) {
    textureKey = @"readout-output";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
    _constructionToolbarState.toolDescriptions[textureKey] = @"Output Value";
    _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeReadoutOutput);
  }

  if (_gameType == FLGameTypeSandbox) {
    textureKey = @"platform";
    [toolTags addObject:textureKey];
    toolNode = [self FL_createToolNodeForTextureKey:textureKey];
    toolNode.position = CGPointMake(FLSegmentArtStraightShift, 0.0f);
    [toolNodes addObject:toolNode];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
    _constructionToolbarState.toolDescriptions[textureKey] = @"Platform";
    _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypePlatform);
  }

  if (_gameType == FLGameTypeSandbox) {
    textureKey = @"platform-start";
    [toolTags addObject:textureKey];
    toolNode = [self FL_createToolNodeForTextureKey:textureKey];
    toolNode.position = CGPointMake(FLSegmentArtStraightShift, 0.0f);
    [toolNodes addObject:toolNode];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
    _constructionToolbarState.toolDescriptions[textureKey] = @"Starting Platform";
    _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypePlatformStart);
  }

  // note: Currently we create all tools and then discard those that aren't on the current page.
  // Obviously that could be tweaked for performance.
  NSMutableArray *pageToolNodes;
  NSMutableArray *pageToolTags;
  // note: There are currently seven basic segments, and it makes sense to put them all on the
  // first page together, even if that means scaling.  In the future that might change, and
  // we might instead use FL_constructionToolbarPageSize.
  const int pageSize = 9;
  [self FL_constructionToolbarSelectPageContentForNodes:toolNodes
                                                   tags:toolTags
                                                   page:page
                                               pageSize:pageSize
                                          pageToolNodes:&pageToolNodes
                                           pageToolTags:&pageToolTags];

  [_constructionToolbarState.toolbarNode setTools:pageToolNodes tags:pageToolTags animation:animation];
}

- (void)FL_constructionToolbarShowGates:(int)page animation:(HLToolbarNodeAnimation)animation
{
  vector<FLUnlockItem> unlockItems = {
    FLUnlockGateNot1,
    FLUnlockGateNot2,
    FLUnlockGateAnd1,
    FLUnlockGateOr1,
    FLUnlockGateOr2,
    FLUnlockGateXor1,
    FLUnlockGateXor2,
  };
  [self FL_constructionToolbarShowImports:FLGatesDirectoryPath unlockItems:&unlockItems page:page animation:animation];
}

- (void)FL_constructionToolbarShowCircuits:(int)page animation:(HLToolbarNodeAnimation)animation
{
  vector<FLUnlockItem> unlockItems = {
    FLUnlockCircuitXor,
    FLUnlockCircuitHalfAdder,
    FLUnlockCircuitFullAdder,
  };
  [self FL_constructionToolbarShowImports:FLCircuitsDirectoryPath unlockItems:&unlockItems page:page animation:animation];
}

- (void)FL_constructionToolbarShowExports:(int)page animation:(HLToolbarNodeAnimation)animation
{
  [self FL_constructionToolbarShowImports:FLExportsDirectoryPath unlockItems:nullptr page:page animation:animation];
}

- (void)FL_constructionToolbarShowImports:(NSString *)importDirectory
                              unlockItems:(vector<FLUnlockItem> *)unlockItems
                                     page:(int)page
                                animation:(HLToolbarNodeAnimation)animation
{
  // Get a list of all imports (sorted appropriately).
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *importFiles;
  if ([importDirectory isEqualToString:FLExportsDirectoryPath]) {
    // note: For user-exported files, sort by descending creation date.
    NSURL *importURL = [NSURL fileURLWithPath:importDirectory isDirectory:NO];
    NSArray *importFileURLs = [fileManager contentsOfDirectoryAtURL:importURL includingPropertiesForKeys:@[ NSURLCreationDateKey ] options:0 error:nil];
    NSArray *sortedImportFileURLs = [importFileURLs sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2){
      NSDate *date1;
      [obj1 getResourceValue:&date1 forKey:NSURLCreationDateKey error:nil];
      NSDate *date2;
      [obj2 getResourceValue:&date2 forKey:NSURLCreationDateKey error:nil];
      NSComparisonResult result = [date1 compare:date2];
      if (result == NSOrderedAscending) {
        return NSOrderedDescending;
      } else if (result == NSOrderedDescending) {
        return NSOrderedAscending;
      } else {
        return NSOrderedSame;
      }
    }];
    NSMutableArray *mutableImportFiles = [NSMutableArray array];
    for (NSURL *url in sortedImportFileURLs) {
      NSDate *date = nil;
      [url getResourceValue:&date forKey:NSURLCreationDateKey error:nil];
      [mutableImportFiles addObject:[url lastPathComponent]];
    }
    importFiles = mutableImportFiles;
  } else {
    // note: For segments and gates, alphabetize; the preloaded gates and circuits take
    // advantage of this by naming their files in the desired order for the interface.
    importFiles = [fileManager contentsOfDirectoryAtPath:importDirectory error:nil];
    importFiles = [importFiles sortedArrayUsingSelector:@selector(compare:)];
  }

  // Create textures for each import (if they don't already exist in shared store).
  size_t unlockItemIndex = 0;
  NSMutableArray *importTextureKeys = [NSMutableArray array];
  for (NSString *importFile in importFiles) {
    NSString *importName = [importFile stringByDeletingPathExtension];
    SKTexture *texture = [[HLTextureStore sharedStore] textureForKey:importName];
    if (!texture) {
      NSString *importPath = [importDirectory stringByAppendingPathComponent:importFile];
      NSString *importDescription = nil;
      NSArray *segmentNodes = [self FL_importWithPath:importPath description:&importDescription links:NULL];
      UIImage *importImage = [self FL_segments:segmentNodes createImageWithSize:FLMainToolbarToolArtSize];
      [[HLTextureStore sharedStore] setTextureWithImage:importImage forKey:importName filteringMode:SKTextureFilteringNearest];
      _constructionToolbarState.toolTypes[importName] = @(FLToolbarToolTypeActionPan);
      _constructionToolbarState.toolDescriptions[importName] = importDescription;
    }
    if (!unlockItems || unlockItemIndex >= unlockItems->size() || [self FL_unlocked:(*unlockItems)[unlockItemIndex]]) {
      [importTextureKeys addObject:importName];
    }
    ++unlockItemIndex;
  }

  // Calculate indexes that will be included in page.
  //
  // note: [begin,end)
  NSUInteger importTextureKeysCount = [importTextureKeys count];
  NSUInteger pageSize = [self FL_constructionToolbarPageSize];
  NSUInteger beginIndex;
  NSUInteger endIndex;
  [self FL_toolbarGetPageContentBeginIndex:&beginIndex endIndex:&endIndex forPage:page contentCount:importTextureKeysCount pageSize:pageSize];

  // Select tools for specified page.
  NSMutableArray *toolNodes = [NSMutableArray array];
  NSMutableArray *toolTags = [NSMutableArray array];
  // note: First "main".
  NSString *textureKey = @"main";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  // note: Next "previous".
  if (page != 0) {
    textureKey = @"previous";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  }
  // note: The page might end up with no imports if the requested page is too
  // large.  Caller beware.
  for (NSUInteger i = beginIndex; i < endIndex; ++i) {
    textureKey = importTextureKeys[i];
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  }
  if (endIndex < importTextureKeysCount) {
    textureKey = @"next";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  }

  // Set tools.
  [_constructionToolbarState.toolbarNode setTools:toolNodes tags:toolTags animation:animation];
}

- (int)FL_constructionToolbarImportsPageMax:(NSString *)importDirectory
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *importFiles = [fileManager contentsOfDirectoryAtPath:importDirectory error:nil];
  NSUInteger pageSize = [self FL_constructionToolbarPageSize];
  NSUInteger importFilesCount = [importFiles count];
  // note: Basic number of imports that can fit on a page is (pageSize - 3), leaving room for a main button,
  // a previous button, and a next button.  But subtract one from the total because first page gets an
  // extra import button (because no need for previous); subtract one more for the last page (no next);
  // and subtract one more so the integer math gives a zero-indexed result.
  return int((importFilesCount - 3) / (pageSize - 3));
}

- (NSUInteger)FL_constructionToolbarPageSize
{
  CGFloat backgroundBorderSize = _constructionToolbarState.toolbarNode.backgroundBorderSize;
  CGFloat squareSeparatorSize = _constructionToolbarState.toolbarNode.squareSeparatorSize;
  NSUInteger pageSize = (NSUInteger)((_constructionToolbarState.toolbarNode.size.width + squareSeparatorSize - 2.0f * backgroundBorderSize) / (FLMainToolbarHeight - 2.0f * backgroundBorderSize + squareSeparatorSize));
  // note: Need main/previous/next buttons, and then anything less than two remaining is silly.
  if (pageSize < 5) {
    pageSize = 5;
  }
  return pageSize;
}

- (void)FL_constructionToolbarSelectPageContentForNodes:(NSArray *)toolNodes
                                                   tags:(NSArray *)toolTags
                                                   page:(int)page
                                               pageSize:(NSUInteger)pageSize
                                          pageToolNodes:(NSArray * __autoreleasing *)pageToolNodes
                                           pageToolTags:(NSArray * __autoreleasing *)pageToolTags
{
  // Calculate indexes that will be included in page.
  //
  // note: [begin,end)
  NSUInteger allNodesCount = [toolNodes count];
  NSUInteger beginIndex;
  NSUInteger endIndex;
  [self FL_toolbarGetPageContentBeginIndex:&beginIndex endIndex:&endIndex forPage:page contentCount:allNodesCount pageSize:pageSize];

  NSMutableArray *selectedToolNodes = [NSMutableArray array];
  NSMutableArray *selectedToolTags = [NSMutableArray array];

  // First tool is always "main".
  NSString *textureKey = @"main";
  [selectedToolTags addObject:textureKey];
  [selectedToolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);

  // Next tool is "previous" if not on first page.
  if (page != 0) {
    textureKey = @"previous";
    [selectedToolTags addObject:textureKey];
    [selectedToolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  }

  // Then include the content tools.
  for (NSUInteger i = beginIndex; i < endIndex; ++i) {
    [selectedToolTags addObject:toolTags[i]];
    [selectedToolNodes addObject:toolNodes[i]];
  }

  // And last a "next" button if not on last page.
  if (endIndex < allNodesCount) {
    textureKey = @"next";
    [selectedToolTags addObject:textureKey];
    [selectedToolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  }

  *pageToolNodes = selectedToolNodes;
  *pageToolTags = selectedToolTags;
}

- (void)FL_toolbarGetPageContentBeginIndex:(NSUInteger *)beginIndex
                                  endIndex:(NSUInteger *)endIndex
                                   forPage:(int)page
                              contentCount:(NSUInteger)contentCount
                                  pageSize:(NSUInteger)pageSize
{
  // note: [begin,end)
  const NSUInteger contentPerMiddlePage = pageSize - 3;
  // note: First page has room for an extra import, so add one to index.
  // (Subtract it out below if we're on the first page.)
  *beginIndex = contentPerMiddlePage * (NSUInteger)page + 1;
  *endIndex = *beginIndex + contentPerMiddlePage;
  if (page == 0) {
    --(*beginIndex);
  }
  // note: Last page has room for an extra import, so add one if we're
  // indexed at the next-to-last; also, stay in bounds for partial last
  // page.
  if (*endIndex + 1 >= contentCount) {
    *endIndex = contentCount;
  }
}

- (void)FL_simulationToolbarSetVisible:(BOOL)visible
{
  if (!_simulationToolbarState.toolbarNode) {
    _simulationToolbarState.toolbarNode = [[HLToolbarNode alloc] init];
    _simulationToolbarState.toolbarNode.backgroundBorderSize = 4.0f;
    _simulationToolbarState.toolbarNode.squareSeparatorSize = 4.0;
    _simulationToolbarState.toolbarNode.anchorPoint = CGPointMake(0.5f, 1.0f);
    [self FL_simulationToolbarUpdateGeometry];
  }

  if (visible) {
    if (!_simulationToolbarState.toolbarNode.parent) {
      [_hudNode addChild:_simulationToolbarState.toolbarNode];
    }
  } else {
    if (_simulationToolbarState.toolbarNode.parent) {
      [_simulationToolbarState.toolbarNode removeFromParent];
    }
  }
}

- (void)FL_simulationToolbarUpdateGeometry
{
  _simulationToolbarState.toolbarNode.automaticWidth = NO;
  _simulationToolbarState.toolbarNode.automaticHeight = NO;
  _simulationToolbarState.toolbarNode.position = CGPointMake(0.0f, self.size.height / 2.0f);
  _simulationToolbarState.toolbarNode.size = CGSizeMake(self.size.width, FLMainToolbarHeight);
  [self FL_simulationToolbarUpdateTools];
}

- (void)FL_simulationToolbarUpdateTools
{
  NSMutableArray *toolNodes = [NSMutableArray array];
  NSMutableArray *toolTags = [NSMutableArray array];

  NSString *textureKey = @"menu";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];

  if (_simulationRunning) {
    textureKey = @"pause";
  } else {
    textureKey = @"play";
  }
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];

  if (_simulationSpeed <= 1) {
    textureKey = @"ff";
  } else {
    textureKey = @"fff";
  }
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  NSString *speedToolTextureKey = textureKey;

  textureKey = @"center";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];

  textureKey = @"goals";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];

  [_simulationToolbarState.toolbarNode setTools:toolNodes tags:toolTags animation:HLToolbarNodeAnimationNone];

  [_simulationToolbarState.toolbarNode setHighlight:(_simulationSpeed > 0) forTool:speedToolTextureKey];
}

- (void)FL_simulationStart
{
  _simulationRunning = YES;
  _train.running = YES;
  [self FL_simulationToolbarUpdateTools];

  if (_tutorialState.tutorialActive) {
    [self FL_tutorialRecognizedAction:FLTutorialActionSimulationStarted withArguments:nil];
  }
}

- (void)FL_simulationStop
{
  _simulationRunning = NO;
  _train.running = NO;
  [self FL_simulationToolbarUpdateTools];

  if (_tutorialState.tutorialActive) {
    [self FL_tutorialRecognizedAction:FLTutorialActionSimulationStopped withArguments:nil];
  }
}

- (void)FL_simulationCycleSpeed
{
  int simulationSpeed = _simulationSpeed + 1;
  if (simulationSpeed > 2) {
    simulationSpeed = 0;
  }
  [self FL_simulationSetSpeed:simulationSpeed];
}

- (void)FL_simulationSetSpeed:(int)simulationSpeed
{
  _simulationSpeed = simulationSpeed;
  [self FL_train:_train setSpeed:simulationSpeed];
  [self FL_simulationToolbarUpdateTools];
}

- (FLTrain *)FL_trainCreate
{
  SKTexture *trainTexture = [[HLTextureStore sharedStore] textureForKey:@"engine"];
  FLTrain *train = [[FLTrain alloc] initWithTexture:trainTexture trackGrid:_trackGrid];
  train.delegate = self;
  train.scale = FLTrackArtScale;
  train.zPosition = FLZPositionWorldTrain;
  [self FL_train:train setSpeed:_simulationSpeed];
  return train;
}

- (void)FL_train:(FLTrain *)train setSpeed:(int)simulationSpeed
{
  const CGFloat FLTrainNormalSpeedPathLengthPerSecond = 1.8f;
  CGFloat speedPathLengthPerSecond = FLTrainNormalSpeedPathLengthPerSecond * (1.0f + simulationSpeed * simulationSpeed);
  train.trainSpeed = speedPathLengthPerSecond;
}

- (void)FL_messageShow:(NSString *)message
{
  if (!_messageNode) {
    _messageNode = [[HLMessageNode alloc] initWithColor:[SKColor colorWithWhite:0.0f alpha:0.5f] size:CGSizeZero];
    _messageNode.verticalAlignmentMode = HLLabelNodeVerticalAlignFontAscenderBias;
    _messageNode.messageLingerDuration = 2.0;
    _messageNode.messageSoundFile = @"pop-2.caf";
    _messageNode.fontName = FLInterfaceFontName;
    _messageNode.fontSize = 14.0f;
    _messageNode.fontColor = [SKColor whiteColor];
    [self FL_messageUpdateGeometry];
  }
  [_messageNode showMessage:message parent:_hudNode];
}

- (void)FL_messageUpdateGeometry
{
  CGFloat bottom = (FLMessageHeight - self.size.height) / 2.0f;
  if (_constructionToolbarState.toolbarNode) {
    bottom += _constructionToolbarState.toolbarNode.size.height;
  }
  _messageNode.position = CGPointMake(0.0f, bottom + FLMessageSpacer);
  _messageNode.size = CGSizeMake(self.size.width, FLMessageHeight);
}

- (void)FL_goalsShowWithSplash:(BOOL)splash
{
  const CGFloat FLZPositionGoalsOverlayContent = 0.0f;
  const CGFloat FLZPositionGoalsOverlayDismissNode = 1.0f;
  const CGFloat FLZPositionGoalsOverlayVictoryButton = 2.0f;

  // Always show results if this goals screen is being shown by a command from the
  // user.  Otherwise, only show results if this is an old (loaded or application
  // restored) game.
  BOOL showResults = !splash || !_gameIsNew;

  SKNode *goalsOverlay = [SKNode node];
  NSMutableArray *layoutNodes = [NSMutableArray array];

  // note: Show in a square that won't have to change size if the interface rotates.
  CGFloat edgeSizeMax = MIN(self.size.width, self.size.height);
  DSMultilineLabelNode *introNode = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  introNode.zPosition = FLZPositionGoalsOverlayContent;
  introNode.fontSize = 18.0f;
  introNode.fontColor = [SKColor whiteColor];
  if (_gameType == FLGameTypeChallenge) {
    introNode.text = [NSString stringWithFormat:@"%@ %d:\n“%@”\n\n%@:\n%@\n\n%@",
                      NSLocalizedString(@"Level", @"Game information: followed by a level number."),
                      _gameLevel,
                      FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsTitle),
                      NSLocalizedString(@"Goals", @"Game information: the header over the description of goals for the current level."),
                      FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsGoalShort),
                      FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsGoalLong)];
  } else {
    introNode.text = FLGameTypeSandboxTitle;
  }
  if (showResults) {
    introNode.text = [NSString stringWithFormat:@"%@\n\n%@:",
                      introNode.text,
                      NSLocalizedString(@"Current Results", @"Game information: on the goals screen, the header over the displayed results of the current level solution."0)];
  }
  introNode.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthPad;
  [layoutNodes addObject:introNode];

  HLLabelButtonNode *victoryButton = nil;
  if (showResults) {
    BOOL victory = NO;
    NSString *resultText = nil;
    SKColor *resultColor = nil;
    // note: Would be cool to animate truth table results as they are calculated.  If in the
    // future the truth table is generated synchronously with this display, that might be a
    // good time to implement some nice animation as the results arrive.
    FLTrackTruthTable *trackTruthTable = trackGridGenerateTruthTable(*_trackGrid, _links, true);
    if ([trackTruthTable.platformStartSegmentNodes count] != 1) {
      resultText = NSLocalizedString(@"(Results can only be shown when track contains exactly one Starting Platform.)",
                                     @"Game information: note explaining that results (including truth table) can't be shown until the track meets certain conditions.");
      resultColor = FLInterfaceColorBad();
    } else if (trackTruthTable.state == FLTrackTruthTableStateMissingSegments) {
      resultText = NSLocalizedString(@"(Results can only be shown when track contains at least one Input Value and one Output Value.)",
                                     @"Game information: note explaining that results (including truth table) can't be shown until the track meets certain conditions.");
      resultColor = FLInterfaceColorBad();
    } else {
      NSArray *goalValues = nil;
      if (_gameType == FLGameTypeChallenge) {
        goalValues = FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsGoalValues);
      }
      HLGridNode *truthTable = [self FL_truthTableCreate:trackTruthTable index:0 correctValues:goalValues correct:&victory];
      truthTable.zPosition = FLZPositionGoalsOverlayContent;
      [layoutNodes addObject:truthTable];
      if (_gameType == FLGameTypeChallenge && victory) {
        if (_gameLevel + 1 >= FLChallengeLevelsCount()) {
          resultText = NSLocalizedString(@"Last Level Complete!",
                                         @"Game information: displayed when current level solution is correct according to goals and current level is the last level.");
        } else {
          resultText = NSLocalizedString(@"Level Complete!",
                                         @"Game information: displayed when current level solution is correct according to goals.");
        }
        resultColor = FLInterfaceColorGood();
      } else if (trackTruthTable.state == FLTrackTruthTableStateInfiniteLoopDetected) {
        resultText = NSLocalizedString(@"Loop detected: The results simulation halted after finding a loop in the track.",
                                       @"Game information: displayed on the goals screen when a loop in the track is detected.");
        resultColor = FLInterfaceColorBad();
      }
    }
    if (resultText) {
      DSMultilineLabelNode *resultNode = [[DSMultilineLabelNode alloc] initWithFontNamed:FLInterfaceFontName];
      resultNode.zPosition = FLZPositionGoalsOverlayContent;
      resultNode.fontSize = 18.0f;
      resultNode.fontColor = resultColor;
      resultNode.text = resultText;
      resultNode.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthPad;
      [layoutNodes addObject:resultNode];
    }
    if (_gameType == FLGameTypeChallenge && victory) {
      NSArray *victoryUserUnlocks = FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsVictoryUserUnlocks);
      [self runAction:[SKAction playSoundFileNamed:@"train-whistle-tune-1.caf" waitForCompletion:NO]];
      FLUserUnlocksUnlock(victoryUserUnlocks);
      if (_gameLevel + 1 < FLChallengeLevelsCount()) {
        victoryButton = FLInterfaceLabelButton();
        victoryButton.zPosition = FLZPositionGoalsOverlayVictoryButton;
        victoryButton.text = NSLocalizedString(@"Next Level",
                                               @"Button: takes you to the next level of a challenge game.");
        [layoutNodes addObject:victoryButton];
      }
    }
  }

  // Layout main components (not counting dismissNode).
  CGFloat totalHeight = 0.0f;
  for (id layoutNode in layoutNodes) {
    totalHeight += [layoutNode size].height;
  }
  const CGFloat FLLayoutNodePad = 10.0f;
  totalHeight += ([layoutNodes count] - 1) * FLLayoutNodePad;
  CGFloat layoutNodeY = totalHeight / 2.0f;
  for (id layoutNode in layoutNodes) {
    CGFloat layoutNodeHeight = [layoutNode size].height;
    [layoutNode setPosition:CGPointMake(0.0f, layoutNodeY - layoutNodeHeight / 2.0f)];
    layoutNodeY -= (layoutNodeHeight + FLLayoutNodePad);
    [goalsOverlay addChild:layoutNode];
  }

  HLGestureTargetSpriteNode *dismissNode = [HLGestureTargetSpriteNode spriteNodeWithColor:[SKColor clearColor] size:self.size];
  // noob: Some confusion around zPositions here.  We don't need to know absolute zPosition of
  // the dismissNode, which is a good thing, because it would be hard to figure out.  (I know that
  // HLScene's presentModalNode will put the goalsOverlay somewhere between our passed min
  // and max (FLZPositionModalMin and FLZPositionModalMax), but I don't know where.)
  dismissNode.zPosition = FLZPositionGoalsOverlayDismissNode;
  [goalsOverlay addChild:dismissNode];

  // Set up interactive elements.
  //
  // note: Okay, lots of thoughts here with putting two HLGestureTarget buttons on the same display
  // without doing any subclassing.
  //
  //  1) The buttons need to be aware of each other.  Perhaps like the "Okay" and "Cancel" buttons
  //     of an alert, all actions should pass through the same callback.  In that case, I'd maybe
  //     have an FL_goalsDismissWithButtonIndex method, with stored goalsOverlay state from this
  //     method, and set each of their handleGestureBlocks to call it.  But that seems to be getting
  //     closer and closer to subclassing: The buttons are acting together, with shared state, and
  //     so should be entirely encapsulated together.
  //
  //  2) But really, the only reason the buttons need to be aware of each other is (currently)
  //     because of unregistering: they both need to unregister both (when dismissing the overlay).
  //     Which reminds me that unregistering HLGestureTargets is a pain in the ass in general, and
  //     according to current implementation not even essential.  BUT.  Unregistering still makes
  //     sense for other possible future HLScene implementations, and no matter what, unregistering
  //     is a nice option to have (even just to clear userData) and so it philosophically makes sense
  //     to always do it.
  //
  //  3) Unregistering is especially a pain in the ass when an HLGestureTarget*Node wants to
  //     unregister itself: The node contains a reference to the handleGesture block, but then
  //     we try to make the block contain a reference to the node.  To break the retain cycle,
  //     we can make the node reference weak, but that's just one more line of code in something
  //     that already feels unnecessary.  Can there be a property in HLGestureTarget*Node for
  //     (__weak HLScene *)autoUnregisterScene, which automatically unregisters itself when the node
  //     is deallocated?
  //
  //  4) And in fact the real problem is HLGestureTarget*Nodes that don't just want to unregister
  //     but in fact want to delete themselves.  Very common: Create some kind of dialog box, and
  //     add a single button which dismisses it.  So then the button removes the dialog box from the
  //     node hierarchy, no other references exist, the parent is deleted which deletes the children,
  //     the button is deleted, so the callback block (being run) is deleted.  So (see notes in
  //     notes/objective-c.txt) we have add TWO lines of code, making a strong reference (at block execution
  //     time) of a weak reference (at block copy time) of the dialog box.  What a pain.  HLGestureTarget*Node
  //     should make this easier for us somehow.  Could it retain a strong reference for us right before
  //     invoking the block?
  //
  // For now: Consider it normal that, when building a node with multiple out-of-the-box HLGestureTargets,
  // you have to set their handleGesture callbacks together, in a block of code like this one down at
  // the bottom of the setup.
  __weak HLLabelButtonNode *victoryButtonWeak = victoryButton;
  __weak HLGestureTargetSpriteNode *dismissNodeWeak = dismissNode;
  if (victoryButton) {
    [victoryButton setGestureTargetDelegateStrong:[[HLGestureTargetTapDelegate alloc] initWithHandleGestureBlock:^(UIGestureRecognizer *gestureRecognizer){
      if (self->_tutorialState.tutorialActive) {
        [self FL_tutorialRecognizedAction:FLTutorialActionGoalsDismissed withArguments:nil];
      }
      [self unregisterDescendant:victoryButtonWeak];
      [self unregisterDescendant:dismissNodeWeak];
      // noob: Retain a strong reference to block owner when dismissing the modal node; nobody else
      // is retaining the victoryButton, but we'd like to finish running this block before getting
      // deallocated.  The weak reference is copied with the block at copy time; now this strong
      // reference (though theoretically possibly nil) will exist until we're done the block.  It's
      // not actually clear how necessary this is, because I don't usually see problems unless this
      // block starts deleting a whole bunch of stuff (like if the didTapNext delegate method deletes
      // the scene right away, as it is prone to do if it is not careful).
      __unused HLLabelButtonNode *victoryButtonStrongAgain = victoryButtonWeak;
      [self dismissModalNodeAnimation:HLScenePresentationAnimationNone];
      id<FLTrackSceneDelegate> delegate = self.delegate;
      if (delegate) {
        // noob: So this is dangerous.  The delegate is probably going to delete this scene.
        // We've got strong references to the scene copied with the block, so let's make sure
        // the block is gone before we try to deallocate the scene.  Okay so wait that's a problem
        // with all existing blocks that reference self, right?  Like, they should all have __weak
        // references?  Unless SKNode explicitly releases children during its deallocation.
        // Sooooo . . . that's something to test.  For now, there aren't crashes, and if there's
        // a retain cycle I haven't noticed it yet.
        [delegate performSelector:@selector(trackSceneDidTapNextLevelButton:) withObject:self];
      }
    }]];
    [self registerDescendant:victoryButton withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  }

  [dismissNode setGestureTargetDelegateStrong:[[HLGestureTargetTapDelegate alloc] initWithHandleGestureBlock:^(UIGestureRecognizer *gestureRecognizer){
    if (self->_tutorialState.tutorialActive) {
      [self FL_tutorialRecognizedAction:FLTutorialActionGoalsDismissed withArguments:nil];
    }
    [self unregisterDescendant:victoryButtonWeak];
    [self unregisterDescendant:dismissNodeWeak];
    __unused HLGestureTargetSpriteNode *dismissNodeStrongAgain = dismissNodeWeak;
    [self dismissModalNodeAnimation:HLScenePresentationAnimationFade];
  }]];
  [self registerDescendant:dismissNode withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];

  [self presentModalNode:goalsOverlay animation:HLScenePresentationAnimationFade];
}

- (HLGridNode *)FL_truthTableCreate:(FLTrackTruthTable *)trackTruthTable
                              index:(int)truthTableIndex
                      correctValues:(NSArray *)correctValues
                            correct:(BOOL *)correct
{
  FLTruthTable& truthTable = trackTruthTable.truthTables[static_cast<NSUInteger>(truthTableIndex)];

  int inputSize = truthTable.getInputSize();
  int outputSize = truthTable.getOutputSize();
  NSMutableArray *contentTexts = [NSMutableArray array];
  NSMutableArray *contentColors = [NSMutableArray array];
  int gridWidth = inputSize + outputSize;
  if (correctValues) {
    ++gridWidth;
  }

  // Specify content for header row.
  for (FLSegmentNode *inputSegmentNode in trackTruthTable.inputSegmentNodes) {
    [contentTexts addObject:[NSString stringWithFormat:@"%c", inputSegmentNode.label]];
    [contentColors addObject:[SKColor blackColor]];
  }
  for (FLSegmentNode *outputSegmentNode in trackTruthTable.outputSegmentNodes) {
    [contentTexts addObject:[NSString stringWithFormat:@"%c", outputSegmentNode.label]];
    [contentColors addObject:[SKColor blackColor]];
  }
  if (correctValues) {
    [contentTexts addObject:@""];
    [contentColors addObject:[SKColor blackColor]];
  }

  // Specify content for value rows.
  *correct = YES;
  vector<int> inputValues = truthTable.inputValuesFirst();
  NSUInteger cv = 0;
  do {
    BOOL rowCorrect = YES;
    for (auto iv : inputValues) {
      [contentTexts addObject:[NSString stringWithFormat:@"%d", iv]];
      [contentColors addObject:[SKColor whiteColor]];
    }
    int *outputValues = truthTable.outputValues(inputValues);
    for (int ov = 0; ov < outputSize; ++ov) {
      [contentTexts addObject:[NSString stringWithFormat:@"%d", outputValues[ov]]];
      if (!correctValues) {
        [contentColors addObject:FLInterfaceColorLight()];
      } else {
        int correctValue = [correctValues[cv++] intValue];
        if (outputValues[ov] == correctValue) {
          [contentColors addObject:FLInterfaceColorGood()];
        } else {
          [contentColors addObject:FLInterfaceColorBad()];
          rowCorrect = NO;
          *correct = NO;
        }
      }
    }
    if (correctValues) {
      if (rowCorrect) {
        [contentTexts addObject:@"✓"];
        [contentColors addObject:FLInterfaceColorGood()];
      } else {
        [contentTexts addObject:@"✗"];
        [contentColors addObject:FLInterfaceColorBad()];
      }
    }
  } while (truthTable.inputValuesSuccessor(inputValues));

  // Create all content nodes for the grid.
  CGFloat labelWidthMax = 0.0f;
  CGFloat labelHeightMax = 0.0f;
  NSMutableArray *contentNodes = [NSMutableArray array];
  for (NSUInteger c = 0; c < [contentTexts count]; ++c) {
    SKLabelNode *labelNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    labelNode.fontColor = contentColors[c];
    labelNode.fontSize = 24.0f;
    labelNode.text = contentTexts[c];
    if (labelNode.frame.size.width > labelWidthMax) {
      labelWidthMax = labelNode.frame.size.width;
    }
    if (labelNode.frame.size.height > labelHeightMax) {
      labelHeightMax = labelNode.frame.size.height;
    }
    labelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    labelNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    [contentNodes addObject:labelNode];
  }

  // Create grid.
  int squareCount = gridWidth * (truthTable.getRowCount() + 1);
  HLGridNode *gridNode = [[HLGridNode alloc] initWithGridWidth:gridWidth
                                                   squareCount:squareCount
                                                    layoutMode:HLGridNodeLayoutModeAlignLeft
                                                    squareSize:CGSizeMake(labelWidthMax + 6.0f, labelHeightMax + 6.0f)
                                          backgroundBorderSize:1.0f
                                           squareSeparatorSize:0.0f];
  gridNode.backgroundColor = [SKColor blackColor];
  gridNode.squareColor = [SKColor colorWithWhite:0.2f alpha:1.0f];
  gridNode.highlightColor = [SKColor colorWithWhite:0.8f alpha:1.0f];
  gridNode.content = contentNodes;
  for (int s = 0; s < gridWidth; ++s) {
    [gridNode setHighlight:YES forSquare:s];
  }
  // note: For bigger tables, try highlighting every other row:
//  for (int s = 0; s < squareCount; ++s) {
//    if (s / gridWidth % 2 == 0) {
//      [gridNode setHighlight:YES forSquare:s];
//    }
//  }

  return gridNode;
}

- (void)FL_trainMoveBeganWithLocation:(CGPoint)worldLocation
{
  // note: This seems to work pretty well.  When adjusting, consider two things: 1) When the pan
  // gesture moves a pixel, the train should also move; 2) When the gesture puts the train at the
  // end of a switched segment (like a join), this precision determines how close it has to be
  // to the end of the path so that the switch is considered relevant (and will determine which
  // path the train ends up on).
  _trainMoveState.progressPrecision = FLPath::getLength(FLPathTypeStraight) / FLTrackSegmentSize / _worldNode.xScale;

  if (!_trainMoveState.cursorNode) {
    SKSpriteNode *cursorNode = [SKSpriteNode spriteNodeWithTexture:[[HLTextureStore sharedStore] textureForKey:@"engine"]];
    cursorNode.zPosition = FLZPositionWorldOverlay;
    cursorNode.zRotation = (CGFloat)M_PI_2;
    cursorNode.xScale = FLTrackArtScale;
    cursorNode.yScale = FLTrackArtScale;
    cursorNode.alpha = FLCursorNodeAlpha;
    _trainMoveState.cursorNode = cursorNode;
  }
  _trainMoveState.cursorNode.position = worldLocation;
  [_trackNode addChild:_trainMoveState.cursorNode];
}

- (void)FL_trainMoveChangedWithLocation:(CGPoint)worldLocation
{
  const int FLGridSearchDistance = 1;
  _trainMoveState.cursorNode.position = worldLocation;
  [_train moveToClosestOnTrackLocationForLocation:worldLocation
                               gridSearchDistance:FLGridSearchDistance
                                progressPrecision:_trainMoveState.progressPrecision];
}

- (void)FL_trainMoveEnded
{
  [_trainMoveState.cursorNode removeFromParent];
}

- (void)FL_trackSelect:(NSArray *)segmentNodes
{
  if (!_trackSelectState.visualParentNode) {
    _trackSelectState.visualParentNode = [SKNode node];
    _trackSelectState.visualParentNode.zPosition = FLZPositionWorldSelect;

    const CGFloat FLTrackSelectAlphaMin = 0.7f;
    const CGFloat FLTrackSelectAlphaMax = 1.0f;
    const CGFloat FLTrackSelectFadeDuration = 0.45f;
    SKAction *pulseIn = [SKAction fadeAlphaTo:FLTrackSelectAlphaMax duration:FLTrackSelectFadeDuration];
    pulseIn.timingMode = SKActionTimingEaseOut;
    SKAction *pulseOut = [SKAction fadeAlphaTo:FLTrackSelectAlphaMin duration:FLTrackSelectFadeDuration];
    pulseOut.timingMode = SKActionTimingEaseIn;
    SKAction *pulseOnce = [SKAction sequence:@[ pulseIn, pulseOut ]];
    SKAction *pulseForever = [SKAction repeatActionForever:pulseOnce];
    [_trackSelectState.visualParentNode runAction:pulseForever];

    // note: This doesn't work well with light backgrounds.
    [_worldNode addChild:_trackSelectState.visualParentNode];
  }

  if (!_trackSelectState.visualSquareNodes) {
    _trackSelectState.visualSquareNodes = [NSMutableDictionary dictionary];
  }
  for (FLSegmentNode *segmentNode in segmentNodes) {
    NSValue *segmentNodePointer = [NSValue valueWithPointer:(void *)segmentNode];
    SKSpriteNode *selectionSquare = _trackSelectState.visualSquareNodes[segmentNodePointer];
    if (!selectionSquare) {
      selectionSquare = [SKSpriteNode spriteNodeWithColor:[SKColor colorWithWhite:0.2f alpha:1.0f]
                                                     size:CGSizeMake(FLSegmentArtSizeBasic * FLTrackArtScale,
                                                                     FLSegmentArtSizeBasic * FLTrackArtScale)];
      selectionSquare.blendMode = SKBlendModeAdd;
      _trackSelectState.visualSquareNodes[segmentNodePointer] = selectionSquare;
      [_trackSelectState.visualParentNode addChild:selectionSquare];
    }
    selectionSquare.position = segmentNode.position;
  }
  // noob: Add pointers to a quick-lookup structure to avoid linear search in the array
  // of objects.  (Not using a NSSet in place of the array because these nodes can change in
  // significant ways while selected, which will affect their hash functions as of iOS8.)
  if (_trackSelectState.selectedSegments) {
    for (FLSegmentNode *segmentNode in segmentNodes) {
      NSValue *segmentNodePointer = [NSValue valueWithPointer:(void *)segmentNode];
      if (![_trackSelectState.selectedSegmentPointers containsObject:segmentNodePointer]) {
        [_trackSelectState.selectedSegments addObject:segmentNode];
        [_trackSelectState.selectedSegmentPointers addObject:segmentNodePointer];
      }
    }
  } else {
    _trackSelectState.selectedSegments = [NSMutableArray arrayWithArray:segmentNodes];
    _trackSelectState.selectedSegmentPointers = [NSMutableSet set];
    for (FLSegmentNode *segmentNode in segmentNodes) {
      [_trackSelectState.selectedSegmentPointers addObject:[NSValue valueWithPointer:(void *)segmentNode]];
    }
  }
}

- (void)FL_trackSelectEraseSegment:(FLSegmentNode *)segmentNode
{
  if (!_trackSelectState.selectedSegments) {
    return;
  }
  [self FL_trackSelectEraseCommon:@[ segmentNode ]];
}

- (void)FL_trackSelectEraseSegments:(NSArray *)segmentNodes
{
  if (!_trackSelectState.selectedSegments) {
    return;
  }
  [self FL_trackSelectEraseCommon:segmentNodes];
}

- (void)FL_trackSelectEraseCommon:(NSArray *)segmentNodes
{
  for (FLSegmentNode *segmentNode in segmentNodes) {
    NSValue *segmentNodePointer = [NSValue valueWithPointer:(void *)segmentNode];
    [_trackSelectState.selectedSegmentPointers removeObject:segmentNodePointer];
  }

  if ([_trackSelectState.selectedSegmentPointers count] == 0) {
    _trackSelectState.selectedSegments = nil;
    _trackSelectState.selectedSegmentPointers = nil;
    _trackSelectState.visualSquareNodes = nil;
  } else {
    // note: This might get nasty for large selections.  But the selected segments are mutable, which makes
    // storing them in NSSet or NSOrderedSet problematic.  Could store them in an NSDictionary that maps
    // pointer to object.
    [_trackSelectState.selectedSegments removeObjectsInArray:segmentNodes];
    for (FLSegmentNode *segmentNode in segmentNodes) {
      NSValue *segmentNodePointer = [NSValue valueWithPointer:(void *)segmentNode];
      SKSpriteNode *selectionSquare = _trackSelectState.visualSquareNodes[segmentNodePointer];
      if (selectionSquare) {
        [selectionSquare removeFromParent];
        [_trackSelectState.visualSquareNodes removeObjectForKey:segmentNodePointer];
      }
    }
  }
}

- (void)FL_trackSelectClear
{
  _trackSelectState.selectedSegments = nil;
  _trackSelectState.selectedSegmentPointers = nil;
  _trackSelectState.visualSquareNodes = nil;
  [_trackSelectState.visualParentNode removeAllChildren];
}

- (BOOL)FL_trackSelected:(FLSegmentNode *)segmentNode
{
  if (!_trackSelectState.selectedSegmentPointers) {
    return NO;
  }
  NSValue *segmentNodePointer = [NSValue valueWithPointer:(void *)segmentNode];
  return [_trackSelectState.selectedSegmentPointers containsObject:segmentNodePointer];
}

- (BOOL)FL_trackSelectedNone
{
  return (_trackSelectState.selectedSegmentPointers == nil);
}

- (NSUInteger)FL_trackSelectedCount
{
  if (!_trackSelectState.selectedSegmentPointers) {
    return 0;
  }
  return [_trackSelectState.selectedSegmentPointers count];
}

- (void)FL_trackSelectPaintBeganWithLocation:(CGPoint)worldLocation
{
  FLSegmentNode *segmentNode = trackGridConvertGet(*_trackGrid, worldLocation);
  if (!segmentNode) {
    _worldGestureState.longPressMode = FLWorldLongPressModeNone;
    return;
  }

  if ([self FL_trackSelected:segmentNode]) {
    _worldGestureState.longPressMode = FLWorldLongPressModeErase;
    [self FL_trackSelectEraseSegment:segmentNode];
  } else {
    _worldGestureState.longPressMode = FLWorldLongPressModeAdd;
    [self FL_trackSelect:@[ segmentNode ]];
  }
  [self FL_trackEditMenuHideAnimated:YES];
}

- (void)FL_trackSelectPaintChangedWithLocation:(CGPoint)worldLocation
{
  if (_worldGestureState.longPressMode == FLWorldLongPressModeNone) {
    return;
  }

  FLSegmentNode *segmentNode = trackGridConvertGet(*_trackGrid, worldLocation);
  if (segmentNode) {
    if (_worldGestureState.longPressMode == FLWorldLongPressModeAdd) {
      [self FL_trackSelect:@[ segmentNode ]];
    } else {
      [self FL_trackSelectEraseSegment:segmentNode];
    }
  }
}

- (void)FL_trackConflictShow:(FLSegmentNode *)segmentNode
{
  SKSpriteNode *conflictNode = [SKSpriteNode spriteNodeWithColor:FLInterfaceColorBad()
                                                            size:CGSizeMake(FLTrackSegmentSize, FLTrackSegmentSize)];
  conflictNode.zPosition = FLZPositionWorldSelect;
  conflictNode.position = segmentNode.position;
  conflictNode.alpha = 0.4f;
  [_worldNode addChild:conflictNode];
  [_trackConflictState.conflictNodes addObject:conflictNode];
}

- (void)FL_trackConflictClear
{
  [_trackConflictState.conflictNodes makeObjectsPerformSelector:@selector(removeFromParent)];
  [_trackConflictState.conflictNodes removeAllObjects];
}

/**
 * Begins a move of one or more track segments.
 *
 * @param The segment nodes to move.  They are assumed to either all be new (not set in _trackGrid
 *        and with no node parent) or else all old (set in _trackGrid and with parent set to _trackNode).
 *
 * @param The location of the gesture which started the move.
 */
- (void)FL_trackMoveBeganWithNodes:(NSArray *)segmentNodes location:(CGPoint)worldLocation completion:(void (^)(BOOL placed))completion
{
  if (!segmentNodes || [segmentNodes count] == 0) {
    [NSException raise:@"FLTrackMoveInvalidArgument"
                format:@"Track move requires a non-empty set of segment nodes to move."];
  }
  if (_trackMoveState.segmentNodes) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Beginning track move, but previous move not completed."];
  }

  _trackMoveState.segmentNodes = segmentNodes;
  NSMutableSet *segmentNodePointers = [NSMutableSet set];
  for (FLSegmentNode *segmentNode in segmentNodes) {
    NSValue *segmentNodePointer = [NSValue valueWithPointer:(void *)segmentNode];
    [segmentNodePointers addObject:segmentNodePointer];
  }
  _trackMoveState.segmentNodePointers = segmentNodePointers;
  _trackMoveState.completion = completion;

  _trackGrid->convert(worldLocation, &_trackMoveState.beganGridX, &_trackMoveState.beganGridY);
  _trackMoveState.attempted = NO;
  _trackMoveState.attemptedTranslationGridX = 0;
  _trackMoveState.attemptedTranslationGridY = 0;
  FLSegmentNode *anySegmentNode = [segmentNodes firstObject];
  if (anySegmentNode.parent) {
    // note: Okay, pretty big assumption here, but it's a precondition of the function.
    _trackMoveState.placed = YES;
  } else {
    _trackMoveState.placed = NO;
  }
  _trackMoveState.placedTranslationGridX = 0;
  _trackMoveState.placedTranslationGridY = 0;

  if (!_trackMoveState.cursorNode) {
    _trackMoveState.cursorNode = [SKNode node];
    _trackMoveState.cursorNode.zPosition = FLZPositionWorldOverlay;
    _trackMoveState.cursorNode.alpha = FLCursorNodeAlpha;
  }
  for (FLSegmentNode *segmentNode in segmentNodes) {
    [_trackMoveState.cursorNode addChild:[segmentNode copy]];
  }
  [_trackNode addChild:_trackMoveState.cursorNode];

  [self FL_trackEditMenuHideAnimated:YES];

  [self FL_trackMoveUpdateWithLocation:worldLocation];
}

- (void)FL_trackMoveChangedWithLocation:(CGPoint)worldLocation
{
  if (!_trackMoveState.segmentNodes) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Continuing track move, but track move not begun."];
  }
  [self FL_trackMoveUpdateWithLocation:worldLocation];
}

- (NSArray *)FL_trackMoveEndedWithLocation:(CGPoint)worldLocation
{
  if (!_trackMoveState.segmentNodes) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Ended track move, but track move not begun."];
  }
  NSArray *placedSegmentNodes = [self FL_trackMoveEndedCommonWithLocation:worldLocation];
  [_trackMoveState.cursorNode removeAllChildren];
  [_trackMoveState.cursorNode removeFromParent];
  if (_trackMoveState.placed) {
    [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-clickity-2.caf" waitForCompletion:NO]];
  }
  return placedSegmentNodes;
}

- (NSArray *)FL_trackMoveCancelledWithLocation:(CGPoint)worldLocation
{
  if (!_trackMoveState.segmentNodes) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Cancelled track move, but track move not begun."];
  }
  NSArray *placedSegmentNodes = [self FL_trackMoveEndedCommonWithLocation:worldLocation];
  [_trackMoveState.cursorNode removeAllChildren];
  [_trackMoveState.cursorNode removeFromParent];
  return placedSegmentNodes;
}

- (NSArray *)FL_trackMoveEndedCommonWithLocation:(CGPoint)worldLocation
{
  // noob: Does the platform guarantee this behavior already, to wit, that an "ended" call
  // with a certain location will always be preceeded by a "moved" call at that same
  // location?
  [self FL_trackMoveUpdateWithLocation:worldLocation];

  [self FL_trackConflictClear];

  // note: Currently interface doesn't allow movement of track when links are visible,
  // so this only needs to be done when ended/cancelled.
  if (_trackMoveState.placed) {
    // note: Could skip this if no movement actually took place.
    for (FLSegmentNode *segmentNode in _trackMoveState.segmentNodes) {
      [self FL_linkRedrawForSegment:segmentNode];
    }
  }

  if (_trackMoveState.completion) {
    _trackMoveState.completion(_trackMoveState.placed);
  }

  [self FL_trackEditMenuUpdateAnimated:YES];

  NSArray *placedSegmentNodes = nil;
  if (_trackMoveState.placed) {
    placedSegmentNodes = _trackMoveState.segmentNodes;
  }

  _trackMoveState.segmentNodes = nil;
  _trackMoveState.segmentNodePointers = nil;
  _trackMoveState.completion = nil;

  return placedSegmentNodes;
}

- (void)FL_trackMoveUpdateWithLocation:(CGPoint)worldLocation
{
  // Update cursor.
  //
  // note: Consider having cursor snap to grid alignment.
  _trackMoveState.cursorNode.position = CGPointMake(worldLocation.x - _trackMoveState.beganGridX * FLTrackSegmentSize,
                                                    worldLocation.y - _trackMoveState.beganGridY * FLTrackSegmentSize);

  // Find translation.
  //
  // note: The translation is based on gridlines crossed by the gesture, not
  // total distance moved.
  int translationGridX;
  int translationGridY;
  _trackGrid->convert(worldLocation, &translationGridX, &translationGridY);
  translationGridX -= _trackMoveState.beganGridX;
  translationGridY -= _trackMoveState.beganGridY;

  // Return early if we've already attempted placement for this translation.
  //
  // note: As written, we will re-attempt each new translation the first time
  // the controlling gesture enters a new grid square, even if we've already
  // tried the new grid square previously.  Small waste; no big deal.
  if (_trackMoveState.attempted
      && translationGridX == _trackMoveState.attemptedTranslationGridX
      && translationGridY == _trackMoveState.attemptedTranslationGridY) {
    return;
  }
  _trackMoveState.attempted = YES;
  _trackMoveState.attemptedTranslationGridX = translationGridX;
  _trackMoveState.attemptedTranslationGridY = translationGridY;

  // Return early if the gesture translation is not different than the current placement.
  [self FL_trackConflictClear];
  if (_trackMoveState.placed
      && translationGridX == _trackMoveState.placedTranslationGridX
      && translationGridY == _trackMoveState.placedTranslationGridY) {
    return;
  }

  // Check placement at new (or initial, if not placed) translation.
  int deltaTranslationGridX = translationGridX - _trackMoveState.placedTranslationGridX;
  int deltaTranslationGridY = translationGridY - _trackMoveState.placedTranslationGridY;
  BOOL hasConflict = NO;
  for (FLSegmentNode *segmentNode : _trackMoveState.segmentNodes) {
    // note: Rather than recalculating grid coordinates every loop, could
    // store them in the segmentNodes structure.
    int placementGridX;
    int placementGridY;
    _trackGrid->convert(segmentNode.position, &placementGridX, &placementGridY);
    placementGridX += deltaTranslationGridX;
    placementGridY += deltaTranslationGridY;
    FLSegmentNode *occupyingSegmentNode = _trackGrid->get(placementGridX, placementGridY);
    if (placementGridX < FLTrackGridXMin || placementGridX > FLTrackGridXMax
        || placementGridY < FLTrackGridYMin || placementGridY > FLTrackGridYMax) {
      hasConflict = YES;
    } else if (occupyingSegmentNode) {
      NSValue *occupyingSegmentNodePointer = [NSValue valueWithPointer:(void *)occupyingSegmentNode];
      if (![_trackMoveState.segmentNodePointers containsObject:occupyingSegmentNodePointer]) {
        [self FL_trackConflictShow:occupyingSegmentNode];
        hasConflict = YES;
      }
    }
  }
  if (hasConflict) {
    return;
  }

  // Remove from old placement (if any).
  if (_trackMoveState.placed) {
    for (FLSegmentNode *segmentNode : _trackMoveState.segmentNodes) {
      trackGridConvertErase(*_trackGrid, segmentNode.position);
    }
  }

  // Place at new (or initial, if not placed) translation.
  for (FLSegmentNode *segmentNode : _trackMoveState.segmentNodes) {
    segmentNode.position = CGPointMake(segmentNode.position.x + deltaTranslationGridX * FLTrackSegmentSize,
                                       segmentNode.position.y + deltaTranslationGridY * FLTrackSegmentSize);
    trackGridConvertSet(*_trackGrid, segmentNode.position, segmentNode);
    if (!_trackMoveState.placed) {
      [_trackNode addChild:segmentNode];
    }
  }
  _trackMoveState.placed = YES;
  _trackMoveState.placedTranslationGridX = translationGridX;
  _trackMoveState.placedTranslationGridY = translationGridY;
  [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-click-2.caf" waitForCompletion:NO]];

  // Update selection.
  [self FL_trackSelect:_trackMoveState.segmentNodes];
}

/**
 * Shows or hides the track edit menu based on the current selection.
 *
 * The track edit menu visibility and position is always related to the current track
 * selection; however, the caller can still hide the menu, or choose not to update its
 * position.  A typical scenario: During multiple selection the caller might want to
 * keep the track edit menu hidden; the caller might only want to update the track edit
 * menu on touch-up.
 *
 * The FL_trackEditMenuShow* FL_trackEditMenuHide* methods may be called when the
 * size of the current selection is known to the caller; otherwise, call this method.
 */
- (void)FL_trackEditMenuUpdateAnimated:(BOOL)animated
{
  if (!_trackSelectState.selectedSegments) {
    [self FL_trackEditMenuHideAnimated:animated];
  } else {
    [self FL_trackEditMenuShowAnimated:animated];
  }
}

- (void)FL_trackEditMenuShowAnimated:(BOOL)animated
{
  // note: It might be reasonable to be defensive here and return without error
  // even if there is no selection.  But I'd like to prove first there's a good reason.
  //
  //   . Got a crash here once with selectedSegments = nil.  Couldn't reproduce.  Hypothesis
  //     that I was moving a segment with world pan but the long press recognizer was also
  //     firing and it erased my selection while I was moving.
  if (!_trackSelectState.selectedSegments || [_trackSelectState.selectedSegments count] == 0) {
    [NSException raise:@"FLTrackEditMenuShowWithoutSelection" format:@"No current selection for track edit menu."];
  }

  if (!_trackEditMenuState.editMenuNode) {
    _trackEditMenuState.editMenuNode = [[HLToolbarNode alloc] init];
    _trackEditMenuState.editMenuNode.size = CGSizeMake(0.0f, FLTrackEditMenuHeight);
    _trackEditMenuState.editMenuNode.zPosition = FLZPositionWorldOverlay;
    _trackEditMenuState.editMenuNode.anchorPoint = CGPointMake(0.5f, 0.0f);
    _trackEditMenuState.editMenuNode.automaticWidth = YES;
    _trackEditMenuState.editMenuNode.automaticHeight = NO;
    _trackEditMenuState.editMenuNode.backgroundBorderSize = FLTrackEditMenuBackgroundBorderSize;
    _trackEditMenuState.editMenuNode.squareSeparatorSize = FLTrackEditMenuSquareSeparatorSize;
  }

  // Collect information about selected segments.
  NSArray *segmentNodes = _trackSelectState.selectedSegments;
  CGFloat segmentsPositionLeft;
  CGFloat segmentsPositionRight;
  CGFloat segmentsPositionTop;
  CGFloat segmentsPositionBottom;
  [self FL_segments:segmentNodes getExtremesLeft:&segmentsPositionLeft right:&segmentsPositionRight top:&segmentsPositionTop bottom:&segmentsPositionBottom];
  BOOL hasSwitch = NO;
  BOOL canHaveSwitch = NO;
  BOOL canLabelAny = (_gameType == FLGameTypeSandbox);
  BOOL canDeleteAny = NO;
  NSUInteger toolCount;
  [self FL_trackEditMenuGetTraitsForSegments:segmentNodes hasSwitch:&hasSwitch canHaveSwitch:&canHaveSwitch canLabelAny:&canLabelAny canDeleteAny:&canDeleteAny toolCount:&toolCount];

  // Update tools.
  NSMutableArray *textureKeys = [NSMutableArray array];
  [textureKeys addObject:@"rotate-ccw"];
  if (canHaveSwitch) {
    [textureKeys addObject:@"toggle-switch"];
  }
  if (canLabelAny) {
    [textureKeys addObject:@"set-label"];
  }
  [textureKeys addObject:@"delete"];
  [textureKeys addObject:@"rotate-cw"];
  // note: Internal checking here to make sure of consistent logic.
  if ([textureKeys count] != toolCount) {
    [NSException raise:@"FLTrackEditMenuInconsistent" format:@"Ensure that tool counting is the same in FL_trackEditMenuShowAnimated: and FL_trackEditMenuGetTraitsForSegments:."];
  }
  NSMutableArray *toolNodes = [NSMutableArray array];
  for (NSString *textureKey in textureKeys) {
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey]];
  }
  [_trackEditMenuState.editMenuNode setTools:toolNodes tags:textureKeys animation:HLToolbarNodeAnimationNone];
  if (canHaveSwitch) {
    [_trackEditMenuState.editMenuNode setEnabled:hasSwitch forTool:@"toggle-switch"];
  }
  [_trackEditMenuState.editMenuNode setEnabled:canDeleteAny forTool:@"delete"];

  // Show menu.
  if (!_trackEditMenuState.showing) {
    [_worldNode addChild:_trackEditMenuState.editMenuNode];
    _trackEditMenuState.showing = YES;
  }
  CGFloat segmentsPositionMidX = (segmentsPositionLeft + segmentsPositionRight) / 2.0f;
  CGFloat segmentsPositionMidY = (segmentsPositionBottom + segmentsPositionTop) / 2.0f;
  CGPoint position = CGPointMake(segmentsPositionMidX, segmentsPositionTop + FLTrackSegmentSize / 2.0f + FLTrackEditMenuSegmentPad);
  CGPoint origin = CGPointMake(segmentsPositionMidX, segmentsPositionMidY);
  CGFloat fullScale = [self FL_trackEditMenuScaleForWorldScale:_worldNode.xScale];
  [_trackEditMenuState.editMenuNode showWithOrigin:origin
                                     finalPosition:position
                                         fullScale:fullScale
                                          animated:animated];
}

- (void)FL_trackEditMenuGetTraitsForSegments:(NSArray *)segmentNodes
                                   hasSwitch:(BOOL *)hasSwitch
                               canHaveSwitch:(BOOL *)canHaveSwitch
                                 canLabelAny:(BOOL *)canLabelAny
                                canDeleteAny:(BOOL *)canDeleteAny
                                   toolCount:(NSUInteger *)toolCount
{
  *hasSwitch = NO;
  *canHaveSwitch = NO;
  *canLabelAny = (_gameType == FLGameTypeSandbox);
  for (FLSegmentNode *segmentNode in segmentNodes) {
    if ([segmentNode canHaveSwitch]) {
      *canHaveSwitch = YES;
      if (segmentNode.switchPathId != FLSegmentSwitchPathIdNone) {
        *hasSwitch = YES;
        break;
      }
    }
  }
  *canDeleteAny = NO;
  if (_gameType == FLGameTypeSandbox) {
    *canDeleteAny = YES;
  } else {
    for (FLSegmentNode *segmentNode in segmentNodes) {
      if ([self FL_gameTypeChallengeCanEraseSegment:segmentNode]) {
        *canDeleteAny = YES;
        break;
      }
    }
  }
  *toolCount = 3;
  if (*canHaveSwitch) {
    ++(*toolCount);
  }
  if (*canLabelAny) {
    ++(*toolCount);
  }
}

- (CGFloat)FL_trackEditMenuWidthForSegments:(NSArray *)segmentNodes
{
  // note: At scale = 1.
  BOOL hasSwitch = NO;
  BOOL canHaveSwitch = NO;
  BOOL canLabelAny = (_gameType == FLGameTypeSandbox);
  BOOL canDeleteAny = NO;
  NSUInteger toolCount;
  [self FL_trackEditMenuGetTraitsForSegments:segmentNodes hasSwitch:&hasSwitch canHaveSwitch:&canHaveSwitch canLabelAny:&canLabelAny canDeleteAny:&canDeleteAny toolCount:&toolCount];
  return (FLTrackEditMenuHeight - 2.0f * FLTrackEditMenuBackgroundBorderSize + FLTrackEditMenuSquareSeparatorSize) * toolCount - FLTrackEditMenuSquareSeparatorSize;
}

- (void)FL_trackEditMenuHideAnimated:(BOOL)animated
{
  if (!_trackEditMenuState.showing) {
    return;
  }
  _trackEditMenuState.showing = NO;
  [_trackEditMenuState.editMenuNode hideAnimated:NO];
}

- (void)FL_trackEditMenuScaleToWorld
{
  CGFloat editMenuScale = [self FL_trackEditMenuScaleForWorldScale:_worldNode.xScale];
  _trackEditMenuState.editMenuNode.xScale = editMenuScale;
  _trackEditMenuState.editMenuNode.yScale = editMenuScale;
}

- (CGFloat)FL_trackEditMenuScaleForWorldScale:(CGFloat)worldScale
{
  // note: The track edit menu scales inversely to the world, but perhaps at a different rate.
  // A value of 1.0f means the edit menu will always maintain the same screen size no matter
  // what the scale of the world.  Values less than one mean less-dramatic scaling than
  // the world, and vice versa.
  //
  // note: Use same formula here as FL_trackEditMenuWorldScaleToFitSegmentSize:intoTargetSceneSize:.
  // My original formula was 1 / sqrt(_worldNode.xScale), but to make some math easier I changed it
  // to (1/3) / _worldNode.xScale + 2/3.  (Note that both of them solve to 1 at 1.)
  return FLTrackEditMenuWorldInverseScaleFactor / worldScale + FLTrackEditMenuWorldScaleMinimum;
}

/**
 * Returns a world scale that will fit the passed (size of) segments, along with an accompanying
 * track edit menu, into the passed target size (in scene coordinates).  The width of the track
 * edit menu can be calculated by the caller and passed in, or else passed 0.0f meaning "don't
 * bother to take the width of the track edit menu into account, just the height".
 *
 * note: It might be surprising that this would be the purview of the track edit menu.  The
 * reason why, of course, is because the track edit menu itself changes screen size as a function
 * of world scale.  It's not the identity function, and it's kept private (in FL_trackEditMenuScaleForWorldScale),
 * so unless we make it public, we have to do the math here in FL_trackEditMenu* land.
 */
- (CGFloat)FL_trackEditMenuWorldScaleToFitSegmentSize:(CGSize)segmentSize intoTargetSceneSize:(CGSize)sceneSize withTrackEditMenuWidth:(CGFloat)trackEditMenuWidth
{
  // note: The segments are in the world, and the world is in the scene.  So to fit segmentSize into
  // sceneSize, the correct scale is simply:
  //
  //    worldScale = MIN(sceneSize.x / segmentSize.x, sceneSize.y / segmentSize.y)
  //
  // When we also want to leave room for the trackEditMenu (displayed above the segments according
  // to current implementation).  The scale of the trackEditMenu is a function of worldScale; see
  // FL_trackEditMenuScaleForWorldScale, but current function is this:
  //
  //    trackScale(worldScale) = 1 / (3 * worldScale) + 2/3
  //
  // So then the calculation to fit segmentSize + trackMenuSize becomes, in X:
  //
  //    worldScale_x = sceneSize.x / MAX(segmentSize.x, trackMenuSize.x * trackScale(worldScale_x))
  //
  // and in Y:
  //
  //    worldScale_y = sceneSize.y / (segmentSize.y + trackMenuSegmentPad + trackMenuSize.y * trackScale(worldScale_y))
  //
  // Solve for worldScale_x and worldScale_y, and then take the minimum to fit both dimensions.

  CGFloat worldScaleX;
  CGFloat worldScaleXSegments = sceneSize.width / segmentSize.width;
  if (trackEditMenuWidth < 0.001f) {
    worldScaleX = worldScaleXSegments;
  } else {
    CGFloat worldScaleXTrackEditMenu = sceneSize.width / trackEditMenuWidth;
    worldScaleX = MIN(worldScaleXSegments, worldScaleXTrackEditMenu);
  }

  CGFloat worldScaleY = (sceneSize.height - FLTrackEditMenuHeight * FLTrackEditMenuWorldInverseScaleFactor) / (segmentSize.height + FLTrackEditMenuSegmentPad + FLTrackEditMenuHeight * FLTrackEditMenuWorldScaleMinimum);

  return MIN(worldScaleX, worldScaleY);
}

- (SKShapeNode *)FL_linkDrawFromLocation:(CGPoint)fromWorldLocation toLocation:(CGPoint)toWorldLocation linkErase:(BOOL)linkErase
{
  SKShapeNode *linkNode = [[SKShapeNode alloc] init];
  linkNode.position = CGPointZero;

  CGMutablePathRef linkPath = CGPathCreateMutable();
  CGPathMoveToPoint(linkPath, NULL, fromWorldLocation.x, fromWorldLocation.y);
  CGPathAddLineToPoint(linkPath, NULL, toWorldLocation.x, toWorldLocation.y);
  linkNode.path = linkPath;
  CGPathRelease(linkPath);

  linkNode.lineWidth = FLLinkLineWidth;
  if (linkErase) {
    linkNode.strokeColor = FLLinkEraseLineColor;
    [linkNode runAction:[SKAction repeatActionForever:[SKAction sequence:@[ [SKAction fadeOutWithDuration:FLBlinkHalfCycleDuration],
                                                                            [SKAction waitForDuration:FLBlinkHalfCycleDuration],
                                                                            [SKAction fadeInWithDuration:FLBlinkHalfCycleDuration],
                                                                            [SKAction waitForDuration:FLBlinkHalfCycleDuration] ]]]];
  } else {
    linkNode.strokeColor = FLLinkLineColor;
  }
  linkNode.glowWidth = FLLinkGlowWidth;
  [_linksNode addChild:linkNode];

  return linkNode;
}

- (void)FL_linkRedrawForSegment:(FLSegmentNode *)segmentNode
{
  vector<FLSegmentNode *> links;
  _links.get(segmentNode, &links);
  for (auto link : links) {
    SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:segmentNode.switchPosition toLocation:link.switchPosition linkErase:NO];
    _links.set(segmentNode, link, connectorNode);
  }
}

- (void)FL_linkEditBeganWithNode:(FLSegmentNode *)segmentNode
{
  // note: Precondition is that the passed node has a switch.
  _linkEditState.beginNode = segmentNode;

  if (_tutorialState.tutorialActive) {
    [self FL_tutorialRecognizedAction:FLTutorialActionLinkEditBegan withArguments:nil];
  }

  // Display a begin-segment highlight.
  _linkEditState.beginHighlightNode = [self FL_linkEditCreateHighlightForSegment:_linkEditState.beginNode];
  [_worldNode addChild:_linkEditState.beginHighlightNode];

  [_linksNode runAction:[SKAction playSoundFileNamed:@"plink-1.caf" waitForCompletion:NO]];

  // note: No connector yet, until we move a bit.
  _linkEditState.connectorNode = nil;

  // note: No ending node or highlight yet.
  _linkEditState.endNode = nil;
}

- (void)FL_linkEditChangedWithLocation:(CGPoint)worldLocation
{
  // note: Begin-segment highlight stays the same.

  // Display an end-segment highlight if there is a nearby node with a switch.
  FLSegmentNode *endNode = [self FL_linkSwitchFindSegmentNearLocation:worldLocation];
  if (endNode && endNode != _linkEditState.beginNode && endNode.switchPathId != FLSegmentSwitchPathIdNone) {
    if (endNode != _linkEditState.endNode) {
      [_linkEditState.endHighlightNode removeFromParent];
      _linkEditState.endNode = endNode;
      _linkEditState.endHighlightNode = [self FL_linkEditCreateHighlightForSegment:endNode];
      [_worldNode addChild:_linkEditState.endHighlightNode];
    }
  } else {
    if (_linkEditState.endNode) {
      [_linkEditState.endHighlightNode removeFromParent];
      _linkEditState.endNode = nil;
      _linkEditState.endHighlightNode = nil;
    }
  }

  // Display a connector (a line segment).
  CGPoint beginSwitchPosition = _linkEditState.beginNode.switchPosition;
  CGPoint endSwitchPosition;
  BOOL linkErase;
  if (_linkEditState.endNode) {
    endSwitchPosition = _linkEditState.endNode.switchPosition;
    linkErase = (_links.get(_linkEditState.beginNode, _linkEditState.endNode) != nil);
  } else {
    endSwitchPosition = worldLocation;
    linkErase = NO;
  }
  SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:beginSwitchPosition toLocation:endSwitchPosition linkErase:linkErase];
  if (_linkEditState.connectorNode) {
    [_linkEditState.connectorNode removeFromParent];
  }
  _linkEditState.connectorNode = connectorNode;
}

- (void)FL_linkEditEnded
{
  BOOL preserveConnectorNode = NO;
  if (_linkEditState.endNode && _linkEditState.beginNode != _linkEditState.endNode) {
    // Connecting segments once creates a link; twice deletes it.
    SKShapeNode *oldConnectorNode = _links.get(_linkEditState.beginNode, _linkEditState.endNode);
    if (oldConnectorNode) {
      _links.erase(_linkEditState.beginNode, _linkEditState.endNode);
      [_linksNode runAction:[SKAction playSoundFileNamed:@"plink-2.caf" waitForCompletion:NO]];
    } else {
      SKAction *blinkAction = [SKAction sequence:@[ [SKAction fadeOutWithDuration:FLBlinkHalfCycleDuration],
                                                    [SKAction fadeInWithDuration:FLBlinkHalfCycleDuration],
                                                    [SKAction fadeOutWithDuration:FLBlinkHalfCycleDuration],
                                                    [SKAction fadeInWithDuration:FLBlinkHalfCycleDuration] ]];
      [_linkEditState.connectorNode runAction:blinkAction];
      _links.insert(_linkEditState.beginNode, _linkEditState.endNode, _linkEditState.connectorNode);
      [_linkEditState.endNode setSwitchPathId:[_linkEditState.beginNode switchPathId] animated:YES];
      preserveConnectorNode = YES;
      if (_tutorialState.tutorialActive) {
        [self FL_tutorialRecognizedAction:FLTutorialActionLinkCreated withArguments:nil];
      }
      [_linksNode runAction:[SKAction playSoundFileNamed:@"plink-1.caf" waitForCompletion:NO]];
    }
  }

  _linkEditState.beginNode = nil;
  [_linkEditState.beginHighlightNode removeFromParent];
  _linkEditState.beginHighlightNode = nil;
  if (_linkEditState.connectorNode) {
    if (!preserveConnectorNode) {
      [_linkEditState.connectorNode removeFromParent];
    }
    _linkEditState.connectorNode = nil;
  }
  if (_linkEditState.endNode) {
    [_linkEditState.endHighlightNode removeFromParent];
    _linkEditState.endNode = nil;
    _linkEditState.endHighlightNode = nil;
  }
}

- (void)FL_linkEditCancelled
{
  _linkEditState.beginNode = nil;
  [_linkEditState.beginHighlightNode removeFromParent];
  _linkEditState.beginHighlightNode = nil;
  if (_linkEditState.connectorNode) {
    [_linkEditState.connectorNode removeFromParent];
    _linkEditState.connectorNode = nil;
  }
  if (_linkEditState.endNode) {
    [_linkEditState.endHighlightNode removeFromParent];
    _linkEditState.endNode = nil;
    _linkEditState.endHighlightNode = nil;
  }
}

- (SKNode *)FL_linkEditCreateHighlightForSegment:(FLSegmentNode *)segmentNode
{
  // note: Arguably the segment should know how to highlight itself.  However: 1) The segment
  // only knows its texture, not its image, and our current approach uses the CGImage;
  // 2) The track scene might want to highlight other child nodes in the same way, and put
  // all highlights together in the same layer and/or use the same parameters.  So for now:
  // Put this highlight effect here in the track scene.

  const CGFloat FLLinkHighlightOffsetDistance = 4.0f;
  const CGFloat FLLinkHighlightBlur = 12.0f;
  const int FLLinkHighlightShadowCount = 4;
  UIImage *segmentImage = [[HLTextureStore sharedStore] imageForKey:segmentNode.segmentKey];
  UIImage *shadowedImage = [segmentImage multiShadowWithOffsetDistance:FLLinkHighlightOffsetDistance
                                                           shadowCount:FLLinkHighlightShadowCount
                                                                  blur:FLLinkHighlightBlur
                                                                 color:FLLinkHighlightColor
                                                                cutout:NO];

  SKTexture *texture = [SKTexture textureWithImage:shadowedImage];
  SKSpriteNode *highlightNode = [SKSpriteNode spriteNodeWithTexture:texture];
  highlightNode.position = segmentNode.position;
  highlightNode.zPosition = FLZPositionWorldHighlight;
  highlightNode.zRotation = segmentNode.zRotation;
  highlightNode.xScale = segmentNode.xScale;
  highlightNode.yScale = segmentNode.yScale;

  return highlightNode;
}

- (void)FL_linkSwitchSetPathId:(int)pathId forSegment:(FLSegmentNode *)segmentNode animated:(BOOL)animated
{
  if (segmentNode.switchPathId == pathId) {
    return;
  }
  linksSetSwitchPathId(_links, segmentNode, pathId, animated);
  if (animated) {
    [_trackNode runAction:[SKAction playSoundFileNamed:@"ka-chick.caf" waitForCompletion:NO]];
  }
}

- (void)FL_linkSwitchTogglePathIdForSegment:(FLSegmentNode *)segmentNode animated:(BOOL)animated
{
  linksToggleSwitchPathId(_links, segmentNode, animated);
  if (animated) {
    [_trackNode runAction:[SKAction playSoundFileNamed:@"ka-chick.caf" waitForCompletion:NO]];
  }
}

- (void)FL_linkSwitchTogglePathIdForSegments:(NSArray *)segmentNodes animated:(BOOL)animated
{
  for (FLSegmentNode *segmentNode in segmentNodes) {
    linksToggleSwitchPathId(_links, segmentNode, animated);
  }
  if (animated) {
    [_trackNode runAction:[SKAction playSoundFileNamed:@"ka-chick.caf" waitForCompletion:NO]];
  }
}

- (BOOL)FL_linkSwitchSetEnabled:(BOOL)enabled forSegment:(FLSegmentNode *)segmentNode
{
  // note: Returns the enabled state of the switch (resulting from this call).  Note
  // that the method is defensively programmed as a convenience for some callers (and
  // won't set the enabled value requested if it can't be done), which makes such a
  // return value necessary.
  int currentPathId = [segmentNode switchPathId];
  if (enabled == (currentPathId != FLSegmentSwitchPathIdNone)) {
    return enabled;
  }

  if (enabled) {
    if ([segmentNode canHaveSwitch]) {
      [segmentNode setSwitchPathId:1 animated:NO];
      return YES;
    }
    return NO;
  } else {
    if (![segmentNode mustHaveSwitch]) {
      [segmentNode setSwitchPathId:FLSegmentSwitchPathIdNone animated:NO];
      _links.erase(segmentNode);
      return NO;
    }
    return YES;
  }
}

- (FLSegmentNode *)FL_linkSwitchFindSegmentNearLocation:(CGPoint)worldLocation
{
  int gridX;
  int gridY;
  _trackGrid->convert(worldLocation, &gridX, &gridY);

  FLSegmentNode *closestSegmentNode = nil;
  CGFloat closestDistanceSquared;
  for (int gx = gridX - 1; gx <= gridX + 1; ++gx) {
    for (int gy = gridY - 1; gy <= gridY + 1; ++gy) {
      FLSegmentNode *segmentNode = _trackGrid->get(gx, gy);
      if (!segmentNode || segmentNode.switchPathId == FLSegmentSwitchPathIdNone) {
        continue;
      }
      CGPoint switchLocation = [segmentNode switchPosition];
      CGFloat deltaX = worldLocation.x - switchLocation.x;
      CGFloat deltaY = worldLocation.y - switchLocation.y;
      CGFloat distanceSquared = deltaX * deltaX + deltaY * deltaY;
      if (!closestSegmentNode || distanceSquared < closestDistanceSquared) {
        closestSegmentNode = segmentNode;
        closestDistanceSquared = distanceSquared;
      }
    }
  }

  // note: The grid search limits the distance already, but it's good to bring it in a
  // little more, to allow easier non-linking interaction with the world (to wit, panning)
  // in linking mode.  This could be the caller's purview, but for now standardize it
  // here.  Note that the visual dimensions of a track segment is FLTrackSegmentSize on
  // each side, which seems like a good standard unit of closeness; from there, the
  // multiplying factor is just based on my experimentation and personal preference.
  const CGFloat FLLinkSwitchFindDistanceMax = FLTrackSegmentSize * 1.1f;
  if (!closestSegmentNode || closestDistanceSquared > FLLinkSwitchFindDistanceMax * FLLinkSwitchFindDistanceMax) {
    return nil;
  } else {
    return closestSegmentNode;
  }
}

- (void)FL_linksToggle
{
  if (_linksVisible) {
    [self FL_linksHide];
  } else {
    [self FL_linksShow];
  }
}

- (void)FL_linksShow
{
  if (_linksVisible) {
    return;
  }
  _linksVisible = YES;
  if ([_constructionToolbarState.currentNavigation isEqualToString:@"main"]) {
    [_constructionToolbarState.toolbarNode setHighlight:YES forTool:@"link"];
  }
  [_worldNode addChild:_linksNode];
}

- (void)FL_linksHide
{
  if (!_linksVisible) {
    return;
  }
  _linksVisible = NO;
  if ([_constructionToolbarState.currentNavigation isEqualToString:@"main"]) {
    [_constructionToolbarState.toolbarNode setHighlight:NO forTool:@"link"];
  }
  [_linksNode removeFromParent];
}

- (void)FL_labelsToggle
{
  _labelsVisible = !_labelsVisible;
  [_constructionToolbarState.toolbarNode setHighlight:_labelsVisible forTool:@"show-labels"];
  for (auto s : *_trackGrid) {
    FLSegmentNode *segmentNode = s.second;
    segmentNode.showsLabel = _labelsVisible;
  }
}

- (void)FL_labelPickForSegments:(NSArray *)segmentNodes
{
  if (!_labelState.labelPicker) {

    NSMutableArray *letterNodes = [NSMutableArray array];
    CGFloat letterWidthMax = 0.0f;
    CGFloat letterHeightMax = 0.0f;
    for (int i = 0; i < FLLabelPickerSize; ++i) {
      SKLabelNode *letterNode = [SKLabelNode labelNodeWithFontNamed:@"Arial-BoldMT"];
      letterNode.fontColor = [SKColor whiteColor];
      if (i + 1 == FLLabelPickerSize) {
        letterNode.fontSize = 20.0f;
        letterNode.text = FLLabelPickerLabelNone;
      } else {
        letterNode.fontSize = 28.0f;
        letterNode.text = [NSString stringWithFormat:@"%c", FLLabelPickerLabels[i]];
        if (letterNode.frame.size.width > letterWidthMax) {
          letterWidthMax = letterNode.frame.size.width;
        }
        if (letterNode.frame.size.height > letterHeightMax) {
          letterHeightMax = letterNode.frame.size.height;
        }
      }
      letterNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
      letterNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
      [letterNodes addObject:letterNode];
    }

    CGFloat squareEdgeSize = MAX(letterWidthMax, letterHeightMax) + 2.0f;
    _labelState.labelPicker = [[HLGridNode alloc] initWithGridWidth:FLLabelPickerWidth
                                                        squareCount:FLLabelPickerSize
                                                         layoutMode:HLGridNodeLayoutModeFill
                                                         squareSize:CGSizeMake(squareEdgeSize, squareEdgeSize)
                                               backgroundBorderSize:5.0f
                                                squareSeparatorSize:1.0f];
    [_labelState.labelPicker setGestureTargetDelegateWeak:_labelState.labelPicker];
    _labelState.labelPicker.backgroundColor = FLInterfaceColorDark();
    _labelState.labelPicker.squareColor = FLInterfaceColorMedium();
    _labelState.labelPicker.highlightColor = FLInterfaceColorLight();
    _labelState.labelPicker.content = letterNodes;
    // note: Could easily store referenes to segmentNodes in the block for each invocation,
    // and do all the work there, too, but I felt slightly anxious that then the block
    // would retain references to objects that might not be needed otherwise.  So,
    // an object method instead, with explicit state stored here in _labelState and
    // then cleared in the callback.
    _labelState.labelPicker.squareTappedBlock = ^(int squareIndex){
      [self FL_labelPicked:squareIndex];
    };
    // note: Could register and unregister for each pick, but it seems okay to just
    // leave the one picker registered the whole time.
    [self registerDescendant:_labelState.labelPicker withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  }

  BOOL firstSegment = YES;
  char commonLabel;
  BOOL allSegmentsHaveCommonLabel = YES;
  for (FLSegmentNode *segmentNode in segmentNodes) {
    char label = segmentNode.label;
    if (firstSegment) {
      commonLabel = label;
      firstSegment = NO;
    } else if (label != commonLabel) {
      allSegmentsHaveCommonLabel = NO;
      break;
    }
  }
  if (!firstSegment && allSegmentsHaveCommonLabel) {
    int squareIndex = FLSquareIndexForLabelPickerLabel(commonLabel);
    [_labelState.labelPicker setSelectionForSquare:squareIndex];
  } else {
    [_labelState.labelPicker clearSelection];
  }

  _labelState.segmentNodesToBeLabeled = segmentNodes;
  [self presentModalNode:_labelState.labelPicker animation:HLScenePresentationAnimationFade];
}

- (void)FL_labelPicked:(int)squareIndex
{
  [_labelState.labelPicker setSelectionForSquare:squareIndex];
  for (FLSegmentNode *segmentNode in _labelState.segmentNodesToBeLabeled) {
    segmentNode.label = FLLabelPickerLabels[squareIndex];
  }
  _labelState.segmentNodesToBeLabeled = nil;
  [self dismissModalNodeAnimation:HLScenePresentationAnimationFade];
}

- (void)FL_valuesToggle
{
  _valuesVisible = !_valuesVisible;
  [_constructionToolbarState.toolbarNode setHighlight:_valuesVisible forTool:@"show-values"];
  for (auto s : *_trackGrid) {
    FLSegmentNode *segmentNode = s.second;
    segmentNode.showsSwitchValue = _valuesVisible;
  }
}

- (void)FL_trackRotateSegment:(FLSegmentNode *)segmentNode rotateBy:(int)rotateBy animated:(BOOL)animated
{
  // note: rotateBy positive is in the counterclockwise direction, but current implementation
  // will animate the shortest arc regardless of rotateBy sign.
  int newRotationQuarters = (segmentNode.zRotationQuarters + rotateBy) % 4;
  // note: Repeatedly rotating by adding M_PI_2 * rotateBy leads to cumulative floating point
  // error, which can be large enough over time to affect the calculation (e.g. if the epsilon
  // value in convertRotationRadiansToQuarters is not large enough).  So: Don't just add the
  // angle; recalculate it.
  if (!animated) {
    segmentNode.zRotationQuarters = newRotationQuarters;
    [self FL_linkRedrawForSegment:segmentNode];
  } else {
    segmentNode.showsLabel = NO;
    segmentNode.showsSwitchValue = NO;
    [segmentNode runAction:[SKAction rotateToAngle:(newRotationQuarters * (CGFloat)M_PI_2) duration:FLTrackRotateDuration shortestUnitArc:YES] completion:^{
      [self FL_linkRedrawForSegment:segmentNode];
      segmentNode.showsLabel = self->_labelsVisible;
      segmentNode.showsSwitchValue = self->_valuesVisible;
    }];
    [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-click-1.caf" waitForCompletion:NO]];
  }
}

- (void)FL_trackRotateSegments:(NSArray *)segmentNodes rotateBy:(int)rotateBy animated:(BOOL)animated
{
  if ([segmentNodes count] == 1) {
    [self FL_trackRotateSegment:[segmentNodes firstObject] rotateBy:rotateBy animated:animated];
    return;
  }

  // Collect information about segments.
  CGFloat segmentsPositionLeft;
  CGFloat segmentsPositionRight;
  CGFloat segmentsPositionTop;
  CGFloat segmentsPositionBottom;
  [self FL_segments:segmentNodes getExtremesLeft:&segmentsPositionLeft right:&segmentsPositionRight top:&segmentsPositionTop bottom:&segmentsPositionBottom];
  // note: isSymmetryRotation just in terms of the bounding box, which will be the same
  // after the rotation as before the rotation.
  BOOL isSymmetricRotation = (rotateBy % 2 == 0) || (fabs(segmentsPositionRight - segmentsPositionLeft - segmentsPositionTop + segmentsPositionBottom) < 0.001f);

  // Calculate a good pivot point for the group of segments.
  CGPoint pivot = CGPointMake((segmentsPositionLeft + segmentsPositionRight) / 2.0f,
                              (segmentsPositionBottom + segmentsPositionTop) / 2.0f);
  if (!isSymmetricRotation) {
    int widthUnits = int((segmentsPositionRight - segmentsPositionLeft + 0.00001f) / FLTrackSegmentSize);
    int heightUnits = int((segmentsPositionTop - segmentsPositionBottom + 0.00001f) / FLTrackSegmentSize);
    if (widthUnits % 2 != heightUnits % 2) {
      // note: Choose a good nearby pivot.  Later we'll check for conflict, where a good pivot will
      // mean a pivot that allows the rotation to occur.  But even if this selection is rotating
      // on a conflict-free field, we still need a good pivot, to wit, such that rotating four times will
      // bring us back to the original position.  For that we need state, at least until the selection
      // changes.  Well, okay, let's steal some state that already exists: The zRotation of the
      // first segment in the set.
      CGPoint offsetPivot = CGPointMake(FLTrackSegmentSize / 2.0f, 0.0f);
      int normalRotationQuarters = normalizeRotationQuarters([[segmentNodes firstObject] zRotationQuarters]);
      rotatePoints(&offsetPivot, 1, normalRotationQuarters);
      pivot.x += offsetPivot.x;
      pivot.y += offsetPivot.y;
    }
  }

  // Check proposed rotation for conflicts.
  int normalRotationQuarters = normalizeRotationQuarters(rotateBy);
  BOOL hasConflict = NO;
  NSMutableSet *segmentNodePointers = [NSMutableSet set];
  for (FLSegmentNode *segmentNode in segmentNodes) {
    NSValue *segmentNodePointer = [NSValue valueWithPointer:(void *)segmentNode];
    [segmentNodePointers addObject:segmentNodePointer];
  }
  for (FLSegmentNode *segmentNode in segmentNodes) {
    CGPoint positionRelativeToPivot = CGPointMake(segmentNode.position.x - pivot.x, segmentNode.position.y - pivot.y);
    rotatePoints(&positionRelativeToPivot, 1, normalRotationQuarters);
    CGPoint finalPosition = CGPointMake(positionRelativeToPivot.x + pivot.x, positionRelativeToPivot.y + pivot.y);
    // note: Could store final position to be used below.  My instinct, though, is that
    // recalculating it is fast enough to be okay (or perhaps even as good).
    FLSegmentNode *occupyingSegmentNode = trackGridConvertGet(*_trackGrid, finalPosition);
    if (occupyingSegmentNode) {
      NSValue *occupyingSegmentNodePointer = [NSValue valueWithPointer:(void *)occupyingSegmentNode];
      if (![segmentNodePointers containsObject:occupyingSegmentNodePointer]) {
        [self FL_trackConflictShow:occupyingSegmentNode];
        hasConflict = YES;
      }
    }
  }
  if (hasConflict) {
    [self performSelector:@selector(FL_trackConflictClear) withObject:nil afterDelay:0.5];
    return;
  }

  // Prepare finalization code block.
  void (^finalizeRotation)(void) = ^{
    for (FLSegmentNode *segmentNode in segmentNodes) {
      trackGridConvertErase(*(self->_trackGrid), segmentNode.position);
    }
    for (FLSegmentNode *segmentNode in segmentNodes) {
      CGPoint positionRelativeToPivot = CGPointMake(segmentNode.position.x - pivot.x, segmentNode.position.y - pivot.y);
      rotatePoints(&positionRelativeToPivot, 1, normalRotationQuarters);
      segmentNode.position = CGPointMake(positionRelativeToPivot.x + pivot.x, positionRelativeToPivot.y + pivot.y);
      segmentNode.zRotationQuarters = (segmentNode.zRotationQuarters + rotateBy) % 4;
      trackGridConvertSet(*(self->_trackGrid), segmentNode.position, segmentNode);
    }
    for (FLSegmentNode *segmentNode in segmentNodes) {
      [self FL_linkRedrawForSegment:segmentNode];
    }
    [self FL_trackSelect:segmentNodes];
    if (!isSymmetricRotation) {
      [self FL_trackEditMenuShowAnimated:YES];
    }
  };

  // Rotate.
  if (animated) {

    [self FL_trackSelectClear];
    if (!isSymmetricRotation) {
      [self FL_trackEditMenuHideAnimated:NO];
    }

    // Copy segments into a temporary parent node.
    SKNode *rotateNode = [SKNode node];
    [_trackNode addChild:rotateNode];
    for (FLSegmentNode *segmentNode in segmentNodes) {
      [segmentNode removeFromParent];
      // noob: Unless I make a copy, something gets screwed up with my segmentNodes: They end up
      // with a null self.scene, and the coordinate conversions (e.g. by the segmentNode's
      // switchPosition method, trying to use [self.parent convert*]) give bogus results in
      // some circumstances (e.g. in the completion block of the rotation action, below).  This
      // copying business is a workaround, but it seems low-impact, so I'm not pursuing it further
      // for now.
      FLSegmentNode *segmentNodeCopy = [segmentNode copy];
      segmentNodeCopy.position = CGPointMake(segmentNode.position.x - pivot.x, segmentNode.position.y - pivot.y);
      [rotateNode addChild:segmentNodeCopy];
      segmentNodeCopy.showsLabel = NO;
      segmentNodeCopy.showsSwitchValue = NO;
    }
    rotateNode.position = pivot;

    // Rotate the temporary parent node and then finalize segment position.
    [rotateNode runAction:[SKAction rotateToAngle:(rotateBy * (CGFloat)M_PI_2) duration:FLTrackRotateDuration shortestUnitArc:YES] completion:^{
      for (FLSegmentNode *segmentNode in segmentNodes) {
        [self->_trackNode addChild:segmentNode];
      }
      finalizeRotation();
      [rotateNode removeFromParent];
    }];
    [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-click-1.caf" waitForCompletion:NO]];

  } else {
    finalizeRotation();
  }
}

- (void)FL_trackEraseSegment:(FLSegmentNode *)segmentNode animated:(BOOL)animated
{
  [self FL_trackEraseCommon:segmentNode animated:animated];
  if (animated) {
    [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-clatter-1.caf" waitForCompletion:NO]];
  }
}

- (void)FL_trackEraseSegments:(NSArray *)segmentNodes animated:(BOOL)animated
{
  for (FLSegmentNode *segmentNode in segmentNodes) {
    [self FL_trackEraseCommon:segmentNode animated:animated];
  }
  if (animated) {
    [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-clatter-1.caf" waitForCompletion:NO]];
  }
}

- (void)FL_trackEraseCommon:(FLSegmentNode *)segmentNode animated:(BOOL)animated
{
  [segmentNode removeFromParent];
  if (animated) {
    HLEmitterStore *emitterStore = [HLEmitterStore sharedStore];
    SKEmitterNode *sleeperDestruction = [emitterStore emitterCopyForKey:@"sleeperDestruction"];
    SKEmitterNode *railDestruction = [emitterStore emitterCopyForKey:@"railDestruction"];
    sleeperDestruction.position = segmentNode.position;
    railDestruction.position = segmentNode.position;
    [_trackNode addChild:sleeperDestruction];
    [_trackNode addChild:railDestruction];
    // noob: I read it is recommended to remove emitter nodes when they aren't visible.  I'm not sure if that applies
    // to emitter nodes that have reached their numParticlesToEmit maximum, but it certainly seems like a best practice.
    SKAction *removeAfterWait = [SKAction sequence:@[ [SKAction waitForDuration:(sleeperDestruction.particleLifetime * 1.0)],
                                                      [SKAction removeFromParent] ]];
    [sleeperDestruction runAction:removeAfterWait];
    [railDestruction runAction:removeAfterWait];
  }
  trackGridConvertErase(*_trackGrid, segmentNode.position);
  _links.erase(segmentNode);
}

- (void)FL_trackGridDump
{
  std::cout << "dump track grid:" << std::endl;
  for (int y = 3; y >= -4; --y) {
    for (int x = -4; x <= 3; ++x) {
      FLSegmentNode *segmentNode = _trackGrid->get(x, y);
      char c;
      if (segmentNode == nil) {
        c = '.';
      } else {
        switch (segmentNode.segmentType) {
          case FLSegmentTypeStraight:
            c = '|';
            break;
          case FLSegmentTypeCurve:
            c = '/';
            break;
          case FLSegmentTypeJoinLeft:
          case FLSegmentTypeJoinRight:
            c = 'Y';
            break;
          case FLSegmentTypeJogLeft:
          case FLSegmentTypeJogRight:
            c = 'S';
            break;
          case FLSegmentTypeNone:
            c = ' ';
            break;
          default:
            c = '?';
            break;
        }
      }
      std::cout << c;
    }
    std::cout << std::endl;
  }
}

- (BOOL)FL_unlocked:(FLUnlockItem)item
{
  if (_gameType == FLGameTypeChallenge) {
    switch (item) {
      case FLUnlockGates:
        return _gameLevel >= 1;
      case FLUnlockGateNot1:
      case FLUnlockGateNot2:
        return _gameLevel >= 1;
      case FLUnlockGateAnd1:
        return _gameLevel >= 2;
      case FLUnlockGateOr1:
      case FLUnlockGateOr2:
        return _gameLevel >= 3;
      case FLUnlockGateXor1:
      case FLUnlockGateXor2:
        return _gameLevel >= 4;
      case FLUnlockCircuits:
        return NO;
      case FLUnlockTutorialCompleted:
        return FLUserUnlocksUnlocked(@"FLUserUnlockTutorialCompleted");
      default:
        [NSException raise:@"FLUnlockItemUnknown" format:@"Unknown unlock item %ld.", (long)item];
    }
  } else if (_gameType == FLGameTypeSandbox) {
    switch (item) {
      case FLUnlockGates:
        return FLUserUnlocksUnlocked(@"FLUserUnlockGateNot")
          || FLUserUnlocksUnlocked(@"FLUserUnlockGateAnd")
          || FLUserUnlocksUnlocked(@"FLUserUnlockGateOr")
          || FLUserUnlocksUnlocked(@"FLUserUnlockGateXor");
      case FLUnlockGateNot1:
      case FLUnlockGateNot2:
        return FLUserUnlocksUnlocked(@"FLUserUnlockGateNot");
      case FLUnlockGateAnd1:
        return FLUserUnlocksUnlocked(@"FLUserUnlockGateAnd");
      case FLUnlockGateOr1:
      case FLUnlockGateOr2:
        return FLUserUnlocksUnlocked(@"FLUserUnlockGateOr");
      case FLUnlockGateXor1:
      case FLUnlockGateXor2:
        return FLUserUnlocksUnlocked(@"FLUserUnlockGateXor");
      case FLUnlockCircuits:
        return FLUserUnlocksUnlocked(@"FLUserUnlockCircuitXor")
          || FLUserUnlocksUnlocked(@"FLUserUnlockCircuitHalfAdder")
          || FLUserUnlocksUnlocked(@"FLUserUnlockCircuitFullAdder");
      case FLUnlockCircuitXor:
        return FLUserUnlocksUnlocked(@"FLUserUnlockCircuitXor");
      case FLUnlockCircuitHalfAdder:
        return FLUserUnlocksUnlocked(@"FLUserUnlockHalfAdder");
      case FLUnlockCircuitFullAdder:
        return FLUserUnlocksUnlocked(@"FLUserUnlockFullAdder");
      case FLUnlockTutorialCompleted:
        return FLUserUnlocksUnlocked(@"FLUserUnlockTutorialCompleted");
      default:
        [NSException raise:@"FLUnlockItemUnknown" format:@"Unknown unlock item %ld.", (long)item];
    }
  }
  return NO;
}

- (BOOL)FL_gameTypeChallengeCanEraseSegment:(FLSegmentNode *)segmentNode
{
  // note: If this ends up getting specified per-level, then should put it into the
  // game information plist.  Also, game type logic is scattered around right now,
  // but could make a general system for it like FL_unlocked, where certain named
  // permissions are routed through a single FL_allowed or FL_included or
  // something method.
  return (segmentNode.segmentType != FLSegmentTypeReadoutInput
          && segmentNode.segmentType != FLSegmentTypeReadoutOutput
          && segmentNode.segmentType != FLSegmentTypePlatformStart);
}

void
FL_tutorialContextCutoutRect(CGContextRef context, CGRect rect)
{
  // note: Could draw the background and the cutout rect in a single pass using winding
  // count or even/odd paths (see http://www.cocoawithlove.com/2010/05/5-ways-to-draw-2d-shape-with-hole-in.html).
  CGContextSetBlendMode(context, kCGBlendModeDestinationOut);
  CGContextSetFillColorWithColor(context, [[SKColor whiteColor] CGColor]);
  CGContextFillRect(context, rect);
}

void
FL_tutorialContextCutoutImage(CGContextRef context, UIImage *image, CGPoint cutoutCenter, CGSize cutoutSize, CGFloat rotation)
{
  // note: Cut out a piece of the context in the shape of the passed image (or in a simple rectangle if the
  // passed image is nil).  The shape is cutout centered around the passed cutoutCenter (in context coordinates,
  // i.e. with origin of the context in the lower left); first it is rotated according to the passed rotation
  // parameter.  The cutoutSize then determines the size of the cutout after such rotation.  In other words, the
  // passed image and size are both considered to be in a normal rotation; they will be rotated before being cut
  // out of the context.
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, cutoutCenter.x, cutoutCenter.y);
  CGContextRotateCTM(context, rotation);
  CGRect cutoutRect = CGRectMake(-cutoutSize.width / 2.0f, -cutoutSize.height / 2.0f, cutoutSize.width, cutoutSize.height);
  if (image) {
    CGContextSetBlendMode(context, kCGBlendModeDestinationOut);
    CGContextDrawImage(context, cutoutRect, [image CGImage]);
  } else {
    FL_tutorialContextCutoutRect(context, cutoutRect);
  }
  CGContextRestoreGState(context);
}

- (void)FL_tutorialCreateStepWithLabel:(NSString *)label
{
  CGSize sceneSize = self.size;

  UIGraphicsBeginImageContext(sceneSize);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextTranslateCTM(context, 0.0f, sceneSize.height);
  CGContextScaleCTM(context, 1.0f, -1.0f);

  SKColor *FLTutorialBackdropColor = [SKColor colorWithWhite:0.0f alpha:0.7f];
  CGContextSetFillColorWithColor(context, [FLTutorialBackdropColor CGColor]);
  CGContextFillRect(context, CGRectMake(0.0f, 0.0f, sceneSize.width, sceneSize.height));

  // Cutouts are handled as follows:
  //
  //   . If a sprite is provided, it is used to calculate the position and size of the cutout.
  //     The assumption is that the sprite represents something *in the scene* which we intend
  //     to "show through" the backdrop.
  //
  //   . Since CoreGraphics routines are used to make the cutout, we need a UIImage which corresponds
  //     to the texture of the cutout sprite.  If no image is provided, the sprite's rectangle (based
  //     on the sprite's size, not its frame) is rotated to the sprite's current rotation and cut out
  //     of the backdrop.
  //
  //   . Because we care about the appearance of the sprite *as in the scene*, all sprite geometry
  //     (importantly, position, rotation, and scale) must be translated into scene coordinates.
  //     For simplicity's sake (and because this is currently true for all callers), we assume that
  //     no parent of the sprite is rotated or scaled with respect to the scene.  This allows us
  //     to calculate geometry using only the sprite's rotation and scale (and/or using the
  //     sprite's frame property to get the bounding box).
  //
  //   . A cutout may alternately be specified by a simple rect (rather than a sprite).  The rect
  //     is assumed to be in scene coordinates.

  for (FLTutorialCutout& cutout : _tutorialState.cutouts) {
    if (cutout.spriteNode) {
      // note: The cutout method wants a description of the rectangle of the sprite/image when it is
      // in a normal rotation; then we pass the rotation to the cutout method, and it rotates the
      // rectangle for us.  Note also that sprite.size already accounts for sprite.scale; good.
      CGPoint cutoutCenterSceneLocation = [self convertPoint:cutout.spriteNode.position fromNode:cutout.spriteNode.parent];
      CGPoint cutoutCenterContextLocation = CGPointMake(cutoutCenterSceneLocation.x + sceneSize.width / 2.0f,
                                                        cutoutCenterSceneLocation.y + sceneSize.height / 2.0f);
      FL_tutorialContextCutoutImage(context, cutout.image, cutoutCenterContextLocation, cutout.spriteNode.size, cutout.spriteNode.zRotation);
      // note: We remember the rect of the cutout for later hit-testing.  But it is remembered as a simple
      // non-rotated rectangle in scene coordinates.  So rather than using the size of the cutout sprite
      // as the "cutout rect", we must make a bounding box for the rotated sprite.
      CGSize rotatedCutoutSceneBounds = HLGetBoundsForTransformation(cutout.spriteNode.size, cutout.spriteNode.zRotation);
      cutout.rect = CGRectMake(cutoutCenterSceneLocation.x - rotatedCutoutSceneBounds.width / 2.0f,
                               cutoutCenterSceneLocation.y - rotatedCutoutSceneBounds.height / 2.0f,
                               rotatedCutoutSceneBounds.width,
                               rotatedCutoutSceneBounds.height);
    } else {
      FL_tutorialContextCutoutRect(context, cutout.rect);
    }
  }

  UIImage *backdropImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  SKSpriteNode *backdropNode = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImage:backdropImage]];
  _tutorialState.backdropNode = backdropNode;
  backdropNode.zPosition = FLZPositionTutorial;

  const CGFloat FLTutorialLabelPad = 5.0f;
  DSMultilineLabelNode *labelNode = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  labelNode.zPosition = 0.1f;
  labelNode.fontSize = 20.0f;
  labelNode.fontColor = [SKColor whiteColor];
  labelNode.text = label;
  labelNode.paragraphWidth = MIN(sceneSize.width, sceneSize.height) - FLDSMultilineLabelParagraphWidthPad - FLTutorialLabelPad * 2.0f;
  [backdropNode addChild:labelNode];

  // Layout label relative to cutouts (if appropriate).
  switch (_tutorialState.labelPosition) {
    case FLTutorialLabelCenterScene:
      labelNode.position = CGPointZero;
      break;
    case FLTutorialLabelUpperScene:
      labelNode.position = CGPointMake(0.0f, self.size.height / 5.0f);
      break;
    case FLTutorialLabelLowerScene:
      labelNode.position = CGPointMake(0.0f, -self.size.height / 5.0f);
      break;
    case FLTutorialLabelAboveFirstCutout:
      if (!_tutorialState.cutouts.empty()) {
        FLTutorialCutout& firstCutout = _tutorialState.cutouts.front();
        labelNode.position = CGPointMake(0.0f, CGRectGetMaxY(firstCutout.rect) + labelNode.size.height / 2.0f + FLTutorialLabelPad);
      }
      break;
    case FLTutorialLabelAboveCutouts:
      if (!_tutorialState.cutouts.empty()) {
        CGFloat cutoutsTop = -std::numeric_limits<CGFloat>::infinity();
        for (FLTutorialCutout& cutout : _tutorialState.cutouts) {
          CGFloat cutoutTop = CGRectGetMaxY(cutout.rect);
          if (cutoutTop > cutoutsTop) {
            cutoutsTop = cutoutTop;
          }
        }
        labelNode.position = CGPointMake(0.0f, cutoutsTop + labelNode.size.height / 2.0f + FLTutorialLabelPad);
      }
      break;
    case FLTutorialLabelBelowFirstCutout:
      if (!_tutorialState.cutouts.empty()) {
        FLTutorialCutout& firstCutout = _tutorialState.cutouts.front();
        labelNode.position = CGPointMake(0.0f, CGRectGetMinY(firstCutout.rect) - labelNode.size.height / 2.0f - FLTutorialLabelPad);
      }
      break;
    case FLTutorialLabelBelowCutouts:
      if (!_tutorialState.cutouts.empty()) {
        CGFloat cutoutsBottom = std::numeric_limits<CGFloat>::infinity();
        for (FLTutorialCutout& cutout : _tutorialState.cutouts) {
          CGFloat cutoutBottom = CGRectGetMinY(cutout.rect);
          if (cutoutBottom < cutoutsBottom) {
            cutoutsBottom = cutoutBottom;
          }
        }
        labelNode.position = CGPointMake(0.0f, cutoutsBottom - labelNode.size.height / 2.0f - FLTutorialLabelPad);
      }
      break;
    default:
      break;
  }
}

- (void)FL_tutorialShowWithLabel:(NSString *)label
                   firstPanWorld:(BOOL)firstPanWorld
                     panLocation:(CGPoint)panSceneLocation
                        animated:(BOOL)animated
{
  void (^showBackdrop)(void) = ^{
    // note: Put the creation step in this block so that it happens after the optional firstPanWorld;
    // that ensures the scene locations of the cutouts are converted properly.
    [self FL_tutorialCreateStepWithLabel:label];
    SKSpriteNode *backdropNode = self->_tutorialState.backdropNode;
    [self addChild:backdropNode];
    if (animated) {
      SKNode *labelNode = [backdropNode.children objectAtIndex:0];
      backdropNode.alpha = 0.0f;
      labelNode.alpha = 0.0f;
      [backdropNode runAction:[SKAction fadeInWithDuration:FLTutorialStepFadeDuration] completion:^{
        [labelNode runAction:[SKAction fadeInWithDuration:FLTutorialStepFadeDuration]];
      }];
    }
  };

  if (firstPanWorld) {
    const CGFloat FLTutorialPanWorldDistancePerSecond = 150.0f;
    CGFloat distance = sqrt(panSceneLocation.x * panSceneLocation.x + panSceneLocation.y * panSceneLocation.y);
    NSTimeInterval duration = distance / FLTutorialPanWorldDistancePerSecond;
    if (duration > 0.1) {
      if (duration > FLWorldAdjustDurationSlow) {
        duration = FLWorldAdjustDurationSlow;
      }
      [self FL_worldSetPositionX:(_worldNode.position.x - panSceneLocation.x)
                       positionY:(_worldNode.position.y - panSceneLocation.y)
                animatedDuration:duration
                      completion:showBackdrop];
      return;
    }
  }

  showBackdrop();
}

- (void)FL_tutorialShowWithLabel:(NSString *)label
                        animated:(BOOL)animated
{
  [self FL_tutorialShowWithLabel:label
                   firstPanWorld:NO
                     panLocation:CGPointZero  // ignored
                        animated:animated];
}

- (BOOL)FL_tutorialStepAnimated:(BOOL)animated
{
  // Clean up previous step, if any.
  [self FL_tutorialHideAnimated:animated];
  _tutorialState.cutouts.clear();
  _tutorialState.conditions.clear();

  // Show current step.
  BOOL stepExists = NO;
  switch (_gameLevel) {
    case 0:
      stepExists = [self FL_tutorialStepLevel0Animated:animated];
      break;
    case 1:
      stepExists = [self FL_tutorialStepLevel1Animated:animated];
      break;
    default:
      stepExists = NO;
      break;
  }

  // note: "Tutorial active" is an interface primarily intended for the various tutorial hooks scattered
  // throughout the scene's code: It's a quick way to shortcircuit any setup/computation that only needs
  // to be done if the tutorial is in progress in some way (and in particular, regardless of whether the
  // tutorial backdrop is currently showing).
  _tutorialState.tutorialActive = stepExists;

  return stepExists;
}

- (void)FL_tutorialHideAnimated:(BOOL)animated
{
  // note: Currently, if backdrop is set, that means it exists and is added to parent.
  // And the backdrop is the only thing to hide, currently.
  if (!_tutorialState.backdropNode) {
    return;
  }
  SKSpriteNode *backdropNode = _tutorialState.backdropNode;
  _tutorialState.backdropNode = nil;
  if (animated) {
    [backdropNode runAction:[SKAction sequence:@[ [SKAction fadeOutWithDuration:FLTutorialStepFadeDuration],
                                                  [SKAction removeFromParent] ]]];
  } else {
    [backdropNode removeFromParent];
  }
  // note: See note in [FL_tutorialStep] regarding "tutorialActive": Just because the
  // step is hidden doesn't mean it's not active, so we don't mess with that here.
}

- (void)FL_tutorialUpdateGeometry
{
  // note: Easiest: If the backdrop exists, restart/recreate the tutorial step.
  // This might miss some subtleties in case a particular step only creates the
  // drop after waiting for some action to take place, but currently, no such
  // step exists.
  if (_tutorialState.backdropNode) {
    [self FL_tutorialStepAnimated:NO];
  }
}

- (BOOL)FL_tutorialStepLevel0Animated:(BOOL)animated
{
  switch (_tutorialState.step) {
    case 0: {
      NSString *label = NSLocalizedString(@"This is\nFlippy the Train.",
                                          @"Tutorial message.");
      _tutorialState.cutouts.emplace_back(_train, [[HLTextureStore sharedStore] imageForKey:@"engine"], NO);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      CGPoint panSceneLocation = [self convertPoint:_train.position fromNode:_worldNode];
      [self FL_tutorialShowWithLabel:label firstPanWorld:YES panLocation:panSceneLocation animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 1: {
      NSString *label = NSLocalizedString(@"Tap here to build more track for Flippy.",
                                          @"Tutorial message.");
      SKSpriteNode *squareNode = [_constructionToolbarState.toolbarNode squareNodeForTool:@"segments"];
      _tutorialState.cutouts.emplace_back(squareNode, YES);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionConstructionToolbarTap, FLTutorialResultContinue);
      return YES;
    }
    case 2: {
      NSString *label = NSLocalizedString(@"Drag a ‘Straight Track’ segment from the toolbar to an open spot.",
                                          @"Tutorial message.");
      SKSpriteNode *squareNode = [_constructionToolbarState.toolbarNode squareNodeForTool:@"straight"];
      _tutorialState.cutouts.emplace_back(squareNode, YES);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      CGPoint panSceneLocation = [self convertPoint:_train.position fromNode:_worldNode];
      // note: Pan so that the grid location two spots up from the train is centered,
      // hopefully suggesting a good place to put the straight segment (to wit, extending
      // the track up from the existing join segment).
      panSceneLocation.y += FLTrackSegmentSize * 2.0f;
      [self FL_tutorialShowWithLabel:label firstPanWorld:YES panLocation:panSceneLocation animated:YES];
      _tutorialState.conditions.emplace_back(FLTutorialActionConstructionToolbarPanBegan, FLTutorialResultHideBackdropDisallowInteraction);
      _tutorialState.conditions.emplace_back(FLTutorialActionConstructionToolbarPanEnded, ^NSUInteger(NSArray *arguments){
        // note: Hacky: Peek into _trackMoveState, hopefully before it clears state.
        // I'm preferring this over scanning _trackGrid for new segments just because
        // that seems so verbose and perhaps brittle (if the level ever changes).
        if (self->_trackMoveState.placed) {
          return FLTutorialResultContinue;
        } else {
          return FLTutorialResultRepeat;
        }
      });
      return YES;
    }
    case 3: {
      [self FL_trackEditMenuHideAnimated:YES];
      [self FL_trackSelectClear];
      NSString *label = NSLocalizedString(@"Now tap the green arrow button to start Flippy.",
                                          @"Tutorial message.");
      SKSpriteNode *squareNode = [_simulationToolbarState.toolbarNode squareNodeForTool:@"play"];
      _tutorialState.cutouts.emplace_back(squareNode, YES);
      _tutorialState.labelPosition = FLTutorialLabelBelowCutouts;
      CGPoint panSceneLocation = [self convertPoint:_train.position fromNode:_worldNode];
      [self FL_tutorialShowWithLabel:label firstPanWorld:YES panLocation:panSceneLocation animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionSimulationStarted, FLTutorialResultHideBackdropDisallowInteraction);
      _tutorialState.conditions.emplace_back(FLTutorialActionSimulationStopped, FLTutorialResultContinue);
      return YES;
    }
    case 4: {
      NSString *label = NSLocalizedString(@"Good job, Flippy!\n\nSo what is Flippy trying to do?",
                                          @"Tutorial message.");
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 5: {
      NSString *label = NSLocalizedString(@"Flippy starts out on a green platform. Each level has only one.",
                                          @"Tutorial message.");
      FLSegmentNode *segmentNode = _trackGrid->get(0, 0);
      _tutorialState.cutouts.emplace_back(segmentNode, [[HLTextureStore sharedStore] imageForKey:@"platform-start"], NO);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      CGPoint panSceneLocation = [self convertPoint:segmentNode.position fromNode:_trackNode];
      [self FL_tutorialShowWithLabel:label firstPanWorld:YES panLocation:panSceneLocation animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 6: {
      FLSegmentNode *platformSegmentNode = _trackGrid->get(0, 0);
      [_train moveToSegment:platformSegmentNode pathId:0 progress:0.0f direction:FLPathDirectionIncreasing];
      NSString *label = NSLocalizedString(@"Here the track forks. Flippy curves or goes straight depending on the blue switch.",
                                          @"Tutorial message.");
      FLSegmentNode *segmentNode = _trackGrid->get(0, 1);
      _tutorialState.cutouts.emplace_back(segmentNode, NO);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      CGPoint panSceneLocation = [self convertPoint:segmentNode.position fromNode:_trackNode];
      [self FL_tutorialShowWithLabel:label firstPanWorld:YES panLocation:panSceneLocation animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 7: {
      [self FL_linksShow];
      NSString *label = NSLocalizedString(@"That blue switch is linked to this “input.” Therefore, the input determines which way Flippy goes.",
                                          @"Tutorial message.");
      _tutorialState.cutouts.emplace_back(_trackGrid->get(1, 0), NO);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 8: {
      NSString *label = NSLocalizedString(@"Flippy eventually arrives at this junction. Tap to watch what happens.",
                                          @"Tutorial message.");
      FLSegmentNode *segmentNode = _trackGrid->get(1, 4);
      _tutorialState.cutouts.emplace_back(segmentNode, NO);
      _tutorialState.labelPosition = FLTutorialLabelBelowCutouts;
      CGPoint panSceneLocation = [self convertPoint:segmentNode.position fromNode:_trackNode];
      [self FL_tutorialShowWithLabel:label firstPanWorld:YES panLocation:panSceneLocation animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 9: {
      FLSegmentNode *segmentNode = _trackGrid->get(1, 4);
      [self FL_linkSwitchSetPathId:1 forSegment:segmentNode animated:NO];
      [_train moveToSegment:segmentNode pathId:0 progress:0.0f direction:FLPathDirectionIncreasing];
      // note: Set train speed a bit slower than normal.
      _train.trainSpeed = 1.0f;
      [self FL_simulationStart];
      _tutorialState.conditions.emplace_back(FLTutorialActionSimulationStopped, FLTutorialResultContinue);
      return YES;
    }
    case 10: {
      [self FL_train:_train setSpeed:_simulationSpeed];
      NSString *label = NSLocalizedString(@"The switch flips as Flippy travels over it. (Tap to continue, or press-and-hold to watch again.)",
                                          @"Tutorial message.");
      _tutorialState.labelPosition = FLTutorialLabelLowerScene;
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropLongPress, FLTutorialResultPrevious);
      return YES;
    }
    case 11: {
      NSString *label = NSLocalizedString(@"The switch value is linked to this “output.” Therefore, Flippy determines the output value.",
                                          @"Tutorial message.");
      _tutorialState.cutouts.emplace_back(_trackGrid->get(0, 5), NO);
      _tutorialState.labelPosition = FLTutorialLabelBelowCutouts;
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 12: {
      [self FL_linksHide];
      NSString *label = NSLocalizedString(@"The goal of each level is to build a track so that Flippy sets the output correctly.",
                                          @"Tutorial message.");
      _tutorialState.labelPosition = FLTutorialLabelLowerScene;
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 13: {
      NSString *label = NSLocalizedString(@"Tap this button to see the goals for this level.",
                                          @"Tutorial message.");
      SKSpriteNode *squareNode = [_simulationToolbarState.toolbarNode squareNodeForTool:@"goals"];
      _tutorialState.cutouts.emplace_back(squareNode, YES);
      _tutorialState.labelPosition = FLTutorialLabelBelowCutouts;
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionSimulationToolbarTap, FLTutorialResultHideBackdropAllowInteraction);
      _tutorialState.conditions.emplace_back(FLTutorialActionGoalsDismissed, FLTutorialResultContinue);
      return YES;
    }
    case 14: {
      NSString *label = NSLocalizedString(@"Tap the goals button again when you want to check your solution.\n\nNow go forth, Flippy, and solve the level!",
                                          @"Tutorial message.");
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    default:
      return NO;
  }
}

- (BOOL)FL_tutorialStepLevel1Animated:(BOOL)animated
{
  switch (_tutorialState.step) {
    case 0: {
      NSString *label = NSLocalizedString(@"This level starts with no existing track.",
                                          @"Tutorial message.");
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 1: {
      NSString *label = NSLocalizedString(@"Also, it has two inputs rather than one.",
                                          @"Tutorial message.");
      FLSegmentNode *input1SegmentNode = _trackGrid->get(1, 0);
      FLSegmentNode *input2SegmentNode = _trackGrid->get(2, 0);
      _tutorialState.cutouts.emplace_back(input1SegmentNode, NO);
      _tutorialState.cutouts.emplace_back(input2SegmentNode, NO);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      CGPoint input1SceneLocation = [self convertPoint:input1SegmentNode.position fromNode:input1SegmentNode.parent];
      CGPoint input2SceneLocation = [self convertPoint:input2SegmentNode.position fromNode:input2SegmentNode.parent];
      CGPoint panSceneLocation = CGPointMake((input1SceneLocation.x + input2SceneLocation.x) / 2.0f,
                                             (input1SceneLocation.y + input2SceneLocation.y) / 2.0f);
      [self FL_tutorialShowWithLabel:label firstPanWorld:YES panLocation:panSceneLocation animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 2: {
      NSString *label = NSLocalizedString(@"Tap this button to show labels on the inputs.",
                                          @"Tutorial message.");
      SKSpriteNode *squareNode = [_constructionToolbarState.toolbarNode squareNodeForTool:@"show-labels"];
      _tutorialState.cutouts.emplace_back(squareNode, YES);
      _tutorialState.cutouts.emplace_back(_trackGrid->get(1, 0), NO);
      _tutorialState.cutouts.emplace_back(_trackGrid->get(2, 0), NO);
      _tutorialState.labelPosition = FLTutorialLabelAboveFirstCutout;
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionConstructionToolbarTap, FLTutorialResultContinue);
      return YES;
    }
    case 3: {
      NSString *label = NSLocalizedString(@"Okay. Now let’s look at the goals.",
                                          @"Tutorial message.");
      SKSpriteNode *squareNode = [_simulationToolbarState.toolbarNode squareNodeForTool:@"goals"];
      _tutorialState.cutouts.emplace_back(squareNode, YES);
      _tutorialState.cutouts.emplace_back(_trackGrid->get(1, 0), NO);
      _tutorialState.cutouts.emplace_back(_trackGrid->get(2, 0), NO);
      _tutorialState.labelPosition = FLTutorialLabelBelowFirstCutout;
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionSimulationToolbarTap, FLTutorialResultHideBackdropAllowInteraction);
      _tutorialState.conditions.emplace_back(FLTutorialActionGoalsDismissed, FLTutorialResultContinue);
      return YES;
    }
    case 4: {
      FLSegmentNode *segmentNode = [self FL_createSegmentWithSegmentType:FLSegmentTypeJoinLeft];
      segmentNode.position = _trackGrid->convert(0, 1);
      segmentNode.zRotationQuarters = 1;
      [_trackNode addChild:segmentNode];
      _trackGrid->set(0, 1, segmentNode);
      segmentNode.alpha = 0.0f;
      [segmentNode runAction:[SKAction sequence:@[ [SKAction waitForDuration:1.2],
                                                   [SKAction fadeInWithDuration:0.7] ]]];
      NSString *label = NSLocalizedString(@"Suppose you’ve added a switched segment to the track. How can it be linked to an input?",
                                          @"Tutorial message.");
      _tutorialState.cutouts.emplace_back(segmentNode, NO);
      _tutorialState.cutouts.emplace_back(_trackGrid->get(1, 0), NO);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      CGPoint panSceneLocation = [self convertPoint:segmentNode.position fromNode:_trackNode];
      panSceneLocation.x += FLTrackSegmentSize;
      [self FL_tutorialShowWithLabel:label firstPanWorld:YES panLocation:panSceneLocation animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    case 5: {
      NSString *label = NSLocalizedString(@"First, tap this button.",
                                          @"Tutorial message.");
      SKSpriteNode *squareNode = [_constructionToolbarState.toolbarNode squareNodeForTool:@"link"];
      _tutorialState.cutouts.emplace_back(squareNode, YES);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
     [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionConstructionToolbarTap, FLTutorialResultContinue);
      return YES;
    }
    case 6: {
      NSString *label = NSLocalizedString(@"Now drag from one switch to the other until a blue line connects them.",
                                          @"Tutorial message.");
      _tutorialState.cutouts.emplace_back(_trackGrid->get(0, 1), YES);
      _tutorialState.cutouts.emplace_back(_trackGrid->get(1, 0), YES);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultHideBackdropAllowInteraction);
      _tutorialState.conditions.emplace_back(FLTutorialActionLinkEditBegan, FLTutorialResultHideBackdropAllowInteraction);
      _tutorialState.conditions.emplace_back(FLTutorialActionLinkCreated, FLTutorialResultContinue);
      return YES;
    }
    case 7: {
      NSString *label = NSLocalizedString(@"The link button is highlighted, so we’re still in linking mode. Tap it again to exit linking mode.",
                                          @"Tutorial message.");
      SKSpriteNode *squareNode = [_constructionToolbarState.toolbarNode squareNodeForTool:@"link"];
      _tutorialState.cutouts.emplace_back(squareNode, YES);
      _tutorialState.labelPosition = FLTutorialLabelUpperScene;
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionConstructionToolbarTap, FLTutorialResultContinue);
      return YES;
    }
    case 8: {
      // note: Unlock here, on not on next step, so that if the tutorial is reset it won't immediately get
      // completed again.  (On reset, a tutorial should be shown on a new game, and not on this one,
      // so don't set step to 0.)
      FLUserUnlocksUnlock(@[ @"FLUserUnlockTutorialCompleted" ]);
      NSString *label = NSLocalizedString(@"That’s all for this tutorial. Have fun!",
                                          @"Tutorial message.");
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      return YES;
    }
    default:
      return NO;
  }
}

- (void)FL_tutorialRecognizedAction:(FLTutorialAction)action withArguments:(NSArray *)arguments
{
  // note: Assume caller already checked _tutorialState.tutorialActive.
  FLTutorialResults results = FLTutorialResultNone;
  for (FLTutorialCondition& condition : _tutorialState.conditions) {
    if (condition.action == action) {
      if (condition.dynamicResults) {
        results |= condition.dynamicResults(arguments);
      } else {
        results |= condition.simpleResults;
      }
    }
  }

  // noob: Seems better to me to let the interface actions complete on the main thread
  // before triggering a complete new tutorial step.  But I'm not sure if this is necessary
  // or desirable.

  if ((results & FLTutorialResultPrevious) != 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      --(self->_tutorialState.step);
      [self FL_tutorialStepAnimated:YES];
    });
    // note: Would seem to exclude other results, so return.
    return;
  }

  if ((results & FLTutorialResultRepeat) != 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self FL_tutorialStepAnimated:YES];
    });
    // note: Would seem to exclude other results, so return.
    return;
  }

  if ((results & FLTutorialResultContinue) != 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      ++(self->_tutorialState.step);
      [self FL_tutorialStepAnimated:YES];
    });
    // note: Would seem to exclude other results, so return.
    return;
  }

  if ((results & FLTutorialResultHideBackdropAllowInteraction) != 0) {
    _tutorialState.disallowOtherGestures = NO;
    [self FL_tutorialHideAnimated:YES];
  } else if ((results & FLTutorialResultHideBackdropDisallowInteraction) != 0) {
    _tutorialState.disallowOtherGestures = YES;
    [self FL_tutorialHideAnimated:YES];
  }
}

@end
