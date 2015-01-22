//
//  FLTrackScene.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo Games. All rights reserved.
//

#import "FLTrackScene.h"

#import "HLSpriteKit.h"
#include <memory>
#include <tgmath.h>

#import "DSMultilineLabelNode.h"
#include "FLLinks.h"
#import "FLPath.h"
#import "FLSegmentNode.h"
#include "FLTrackGrid.h"
#import "FLUser.h"

using namespace std;
using namespace HLCommon;

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
// note: This needs to be large enough on the top edge of the world to allow the track edit
// menu to be accessible from under the simulation toolbar.
static const CGFloat FLOffWorldScreenMargin = 75.0f;

// Main layers.
static const CGFloat FLZPositionWorld = 0.0f;
static const CGFloat FLZPositionHud = 10.0f;
static const CGFloat FLZPositionModal = 20.0f;
static const CGFloat FLZPositionTutorial = 30.0f;
// World sublayers.
static const CGFloat FLZPositionWorldTerrain = 0.0f;
static const CGFloat FLZPositionWorldSelectBelow = 1.0f;
static const CGFloat FLZPositionWorldHighlight = 1.5f;
static const CGFloat FLZPositionWorldTrack = 2.0f;
static const CGFloat FLZPositionWorldSelectAbove = 2.5f;
static const CGFloat FLZPositionWorldTrain = 3.0f;
static const CGFloat FLZPositionWorldLinks = 4.0f;
static const CGFloat FLZPositionWorldOverlay = 5.0f;
// Modal sublayers.
static const CGFloat FLZPositionModalMin = FLZPositionModal;
static const CGFloat FLZPositionModalMax = FLZPositionModal + 1.0f;
// Tutorial sublayers.
static const CGFloat FLZPositionTutorialBackdrop = 0.0f;
static const CGFloat FLZPositionTutorialContent = 1.0f;

static const NSTimeInterval FLWorldAdjustDuration = 0.5;
static const NSTimeInterval FLWorldAdjustDurationSlow = 1.0;
static const NSTimeInterval FLWorldFitDuration = 0.3;
static const NSTimeInterval FLTrackRotateDuration = 0.1;
static const NSTimeInterval FLBlinkHalfCycleDuration = 0.1;
static const NSTimeInterval FLTutorialStepFadeDuration = 0.4;

// noob: The tool art uses a somewhat arbitrary size, and the toolbar display height
// is chosen based on something else (the screen layout).  Perhaps scaling like that
// (when most of the art is intentionally pixelated) is a bad idea.
static const CGFloat FLMainToolbarToolArtSize = 54.0f;
static const CGFloat FLMainToolbarHeightCompact = 48.0f;
static const CGFloat FLMainToolbarHeightRegular = 72.0f;
static const CGFloat FLMessageSpacer = 2.0f;
static const CGFloat FLMessageHeight = 20.0f;
static const CGFloat FLTrackEditMenuHeightCompact = 42.0f;
static const CGFloat FLTrackEditMenuHeightRegular = 54.0f;
static const CGFloat FLTrackEditMenuBackgroundBorderSize = 3.0f;
static const CGFloat FLTrackEditMenuSquareSeparatorSize = 3.0f;
static const CGFloat FLTrackEditMenuSpacer = 2.0f;

static NSString *FLGatesDirectoryPath;
static NSString *FLCircuitsDirectoryPath;
static NSString *FLExportsDirectoryPath;
static NSString *FLDeletionsDirectoryPath;

static SKColor *FLSceneBackgroundColor = [SKColor blackColor];

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
  FLSegmentLabelNone
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
  if (label == FLSegmentLabelNone) {
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
};

typedef NS_ENUM(NSInteger, FLRecordItem) {
  FLRecordSegmentsFewest,
  FLRecordJoinsFewest,
  FLRecordSolutionFastest,
};

#pragma mark -
#pragma mark States

// States are functional components of the scene; the data is encapsulated in
// a simple public struct, and the associated functionality is implemented in
// private methods of the scene.

typedef NS_ENUM(NSInteger, FLToolbarToolType) {
  FLToolbarToolTypeNone,
  FLToolbarToolTypeActionTap,
  FLToolbarToolTypeActionPan,
  FLToolbarToolTypeNavigation
};

struct FLConstructionToolbarState
{
  FLConstructionToolbarState() : toolbarNode(nil), currentNavigation(@"main"), currentPage(0), deleteExportConfirmAlert(nil) {
    toolTypes = [NSMutableDictionary dictionary];
    toolDescriptions = [NSMutableDictionary dictionary];
    toolSegmentTypes = [NSMutableDictionary dictionary];
    toolArchiveTextureStore = [[HLTextureStore alloc] init];
  }
  HLToolbarNode *toolbarNode;
  NSString *currentNavigation;
  int currentPage;
  NSMutableDictionary *toolTypes;
  NSMutableDictionary *toolDescriptions;
  NSMutableDictionary *toolSegmentTypes;
  HLTextureStore *toolArchiveTextureStore;
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
  BOOL active() {
    return cursorNode && cursorNode.parent;
  }
  void release() {
    cursorNode = nil;
  }
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
  FLTrackMoveState() : segmentNodes(nil), segmentNodePointers(nil), cursorNode(nil) {}
  BOOL active() {
    return segmentNodes != nil;
  }
  void release() {
    // note: Only cursorNode persists between moves.
    cursorNode = nil;
  }
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
  BOOL active() {
    return showing;
  }
  void release() {
    editMenuNode = nil;
  }
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

struct FLExportState
{
  FLExportState() : descriptionInputAlert(nil) {}
  UIAlertView *descriptionInputAlert;
};

struct FLDeleteState
{
  FLDeleteState() : dirtyTextures(NO) {}
  BOOL dirtyTextures;
};

struct FLLabelState
{
  FLLabelState() : backdropNode(nil), labelPicker(nil), segmentNodesToBeLabeled(nil) {}
  BOOL active() {
    return ((backdropNode && backdropNode.parent) || segmentNodesToBeLabeled);
  }
  void release() {
    backdropNode = nil;
    labelPicker = nil;
    segmentNodesToBeLabeled = nil;
  }
  SKSpriteNode *backdropNode;
  HLGridNode *labelPicker;
  NSArray *segmentNodesToBeLabeled;
};

struct FLRecordState
{
  FLRecordState() {
    cachedRecords = [NSMutableDictionary dictionary];
  }
  NSMutableDictionary *cachedRecords;
};

typedef NS_ENUM(NSInteger, FLWorldPanType) { FLWorldPanTypeNone, FLWorldPanTypeScroll, FLWorldPanTypeTrackMove, FLWorldPanTypeLink };

typedef NS_ENUM(NSInteger, FLWorldLongPressMode) { FLWorldLongPressModeNone, FLWorldLongPressModeAdd, FLWorldLongPressModeErase };

// note: This contains extra state information that seems too minor to split out
// into a "component".  For instance, track selection and track movement are
// caused by gestures in the world, but they are split out into their own
// components, with their own FL_* methods.
struct FLWorldGestureState
{
  CGPoint gestureFirstTouchLocation;
  FLWorldPanType panType;
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
  FLTutorialResultExit = (1 << 5),
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
  UIUserInterfaceSizeClass _interfaceSizeClass;

  SKNode *_worldNode;
  SKNode *_trackNode;
  SKNode *_hudNode;
  SKNode *_linksNode;

  FLCameraMode _cameraMode;
  BOOL _simulationRunning;
  int _simulationSpeed;
  CFTimeInterval _updateLastTime;
  NSDate *_timerResumed;
  NSTimeInterval _timerAccumulated;

  BOOL _linksVisible;
  BOOL _labelsVisible;
  BOOL _valuesVisible;

  shared_ptr<FLTrackGrid> _trackGrid;
  FLLinks _links;

  FLTutorialState _tutorialState;
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
  FLExportState _exportState;
  FLDeleteState _deleteState;
  FLLabelState _labelState;
  FLRecordState _recordState;

  HLMessageNode *_messageNode;
  FLGoalsNode *_goalsNode;
  FLTrain *_train;
}

+ (void)initialize
{
  NSString *bundleDirectory = [[NSBundle mainBundle] bundlePath];
  FLGatesDirectoryPath = [bundleDirectory stringByAppendingPathComponent:@"gates"];
  FLCircuitsDirectoryPath = [bundleDirectory stringByAppendingPathComponent:@"circuits"];
  NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
  FLExportsDirectoryPath = [documentsDirectory stringByAppendingPathComponent:@"exports"];
  FLDeletionsDirectoryPath = [documentsDirectory stringByAppendingPathComponent:@"deletions"];
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
    _timerAccumulated = [aDecoder decodeDoubleForKey:@"timerAccumulated"];
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
      SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:a.switchLinkLocation toLocation:b.switchLinkLocation linkErase:NO];
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
  [aCoder encodeDouble:_timerAccumulated forKey:@"timerAccumulated"];
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
  //
  // note: Requiring higher-taps-required recognizers to fail before recognizing lower-taps-
  // required gestures (via requireGestureRecognizerToFail) works exactly as desired except
  // that it introduces a significant delay in recognition of the lower-taps gestures.
  // Unacceptable, I think; instead, the handlers of higher-taps-gestures should "undo" any
  // undesirable effects of lower-taps-gestures that surely fired before it.
  UITapGestureRecognizer *doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] init];
  doubleTapGestureRecognizer.numberOfTapsRequired = 2;
  UITapGestureRecognizer *doubleTwoTapGestureRecognizer = [[UITapGestureRecognizer alloc] init];
  doubleTwoTapGestureRecognizer.numberOfTouchesRequired = 2;
  doubleTwoTapGestureRecognizer.numberOfTapsRequired = 2;
  // note: Okay, a big note on trying to get swipe gesture recognizers working with a pan
  // gesture recognizer.  Here are some combinations I tried:
  //
  //   . If swipe touches required are all 1, then either you allow both gesture recognizers
  //     to recognize simultaneously, in which case every gesture is both a pan and a swipe,
  //     or you don't, in which case every gesture is considered a swipe.
  //
  //   . So then if swipe touches required are 2: If you allow simultaneous recognition, then
  //     the one-finger gesture is only a pan, but the two-finger gesture is both a pan and
  //     a swipe.  If you don't allow simultaneous recognition, every gesture is considered only
  //     a pan.  (This doesn't quite jive with the previous result where every gesture was considered
  //     a swipe.  Also, it seems pans allow any number of touches.)
  //
  //   . Okay, so test for touches explicitly upon gesture recognition: If it's two, it's a swipe;
  //     if it's one, it's a pan.  This doesn't work at gestureRecognizer:shouldReceiveTouch:,
  //     because at that point the numberOfTouches of the gesture is always 0.  But you can set
  //     the swipe recognizers to require two touches, and you can check for one touch in the
  //     pan gesture target handler method.  The number of touches can change during a two-fingered
  //     pan gesture, typically from 1 to 2 to 1 to 0.  So check when the gesture state is at
  //     BEGIN; that seems to do the trick.
  //
  //   . If you make the pan gesture require the swipe gestures to fail, with two touches, then
  //     everything is pretty good: The two-finger swipes fail when there is only one touch,
  //     and the two-finger gestures are reconized right away.  But it introduces a delay into
  //     the pan recognition, which is unacceptable here (since panning is so much more common
  //     than swiping).
  UISwipeGestureRecognizer *swipeLeftGestureRecognizer = [[UISwipeGestureRecognizer alloc] init];
  swipeLeftGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
  swipeLeftGestureRecognizer.numberOfTouchesRequired = 2;
  UISwipeGestureRecognizer *swipeRightGestureRecognizer = [[UISwipeGestureRecognizer alloc] init];
  swipeRightGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
  swipeRightGestureRecognizer.numberOfTouchesRequired = 2;
  UISwipeGestureRecognizer *swipeUpGestureRecognizer = [[UISwipeGestureRecognizer alloc] init];
  swipeUpGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
  swipeUpGestureRecognizer.numberOfTouchesRequired = 2;
  UISwipeGestureRecognizer *swipeDownGestureRecognizer = [[UISwipeGestureRecognizer alloc] init];
  swipeDownGestureRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
  swipeDownGestureRecognizer.numberOfTouchesRequired = 2;
  [self needSharedGestureRecognizers:@[ [[UITapGestureRecognizer alloc] init],
                                        doubleTapGestureRecognizer,
                                        doubleTwoTapGestureRecognizer,
                                        [[UILongPressGestureRecognizer alloc] init],
                                        [[UIPanGestureRecognizer alloc] init],
                                        [[UIPinchGestureRecognizer alloc] init],
                                        [[UIRotationGestureRecognizer alloc] init],
                                        swipeUpGestureRecognizer,
                                        swipeDownGestureRecognizer,
                                        swipeLeftGestureRecognizer,
                                        swipeRightGestureRecognizer ]];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidReceiveMemoryWarning)
                                               name:UIApplicationDidReceiveMemoryWarningNotification
                                             object:nil];

  if (_gameType == FLGameTypeChallenge) {
    if (![self FL_tutorialStepAnimated:_gameIsNew]) {
      [self FL_goalsShowWithSplash:YES];
    }
  }
  
  [self timerResume];
}

- (void)willMoveFromView:(SKView *)view
{
  [self timerPause];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super willMoveFromView:view];
}

- (void)didChangeSize:(CGSize)oldSize
{
  [super didChangeSize:oldSize];

  // note: Alternately, could get trait collection from view controller and make ourselves compact
  // if either dimension is compact.
  if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    _interfaceSizeClass = UIUserInterfaceSizeClassRegular;
  } else {
    _interfaceSizeClass = UIUserInterfaceSizeClassCompact;
  }

  // note: Reset current world scale (and thence position) using constraints that might now be changed.
  [self FL_worldSetScale:_worldNode.xScale];
  [self FL_tutorialUpdateGeometry];
  [self FL_constructionToolbarUpdateGeometry];
  [self FL_simulationToolbarUpdateGeometry];
  [self FL_trackEditMenuUpdateGeometry];
  [self FL_messageUpdateGeometry];
  [self FL_goalsUpdateGeometry];
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

- (NSUInteger)segmentCount
{
  return (NSUInteger)_trackGrid->size();
}

- (NSUInteger)regularSegmentCount
{
  // note: Count segments that are considered "regular" track, i.e. not readouts
  // and not platforms.
  NSUInteger regularSegmentCount = 0;
  for (auto s : *_trackGrid) {
    FLSegmentType segmentType = s.second.segmentType;
    if (segmentType != FLSegmentTypeReadoutInput
        && segmentType != FLSegmentTypeReadoutOutput
        && segmentType != FLSegmentTypePlatformLeft
        && segmentType != FLSegmentTypePlatformRight
        && segmentType != FLSegmentTypePlatformStartLeft
        && segmentType != FLSegmentTypePlatformStartRight) {
      ++regularSegmentCount;
    }
  }
  return regularSegmentCount;
}

- (NSUInteger)joinSegmentCount
{
  NSUInteger joinSegmentCount = 0;
  for (auto s : *_trackGrid) {
    FLSegmentType segmentType = s.second.segmentType;
    if (segmentType == FLSegmentTypeJoinLeft
        || segmentType == FLSegmentTypeJoinRight) {
      ++joinSegmentCount;
    }
  }
  return joinSegmentCount;
}

- (void)timerPause
{
  if (_timerResumed) {
    _timerAccumulated -= [_timerResumed timeIntervalSinceNow];
    _timerResumed = nil;
  }
}

- (void)timerResume
{
  if (!_timerResumed) {
    _timerResumed = [NSDate date];
  }
}

- (void)timerReset
{
  _timerAccumulated = 0.0;
  _timerResumed = [NSDate date];
}

- (NSTimeInterval)timerGet
{
  if (_timerResumed) {
    return (_timerAccumulated - [_timerResumed timeIntervalSinceNow]);
  } else {
    return _timerAccumulated;
  }
}

#pragma mark -
#pragma mark Notifications

- (void)applicationDidReceiveMemoryWarning
{
  if (!_trainMoveState.active()) {
    _trainMoveState.release();
  }
  if (!_trackMoveState.active()) {
    _trackMoveState.release();
  }
  if (!_trackEditMenuState.active()) {
    _trackEditMenuState.release();
  }
  if (!_labelState.active()) {
    _labelState.release();
  }
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
  if (gestureRecognizer.state != UIGestureRecognizerStateEnded) {
    return;
  }

  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];

  FLSegmentNode *segmentNode = [self FL_trackFindSegmentNearLocation:worldLocation];

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
  if (gestureRecognizer.state != UIGestureRecognizerStateEnded) {
    return;
  }

  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
  FLSegmentNode *segmentNode = [self FL_trackFindSegmentNearLocation:worldLocation];

  if (segmentNode) {
    [self FL_trackSelectClear];
    NSArray *connectedSegmentNodes = trackGridGetAllConnecting(*_trackGrid, segmentNode);
    [self FL_trackSelect:@[ segmentNode ] ];
    [self FL_trackSelect:connectedSegmentNodes];
    [self FL_worldFitSegments:_trackSelectState.selectedSegments scaling:YES scrolling:YES includeTrackEditMenu:YES animated:YES];
    [self FL_trackEditMenuUpdateAnimated:YES];
  }

  // note: Our current configuration of tap gesture recognizers (no simultaneous
  // recognition, and no requirement for others to fail) means the single tap
  // recognizer has already triggered, and we have the option of triggering it
  // again explicitly if this double-tap should instead be treated as two single-taps.
  // In this handler, though, the single- and double-tap implementations work well
  // together naturally as-is (since they both affect selection).
}

- (void)handleWorldDoubleTwoTap:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state != UIGestureRecognizerStateEnded) {
    return;
  }

  for (NSUInteger touch = 0; touch < gestureRecognizer.numberOfTouches; ++touch) {
    CGPoint viewLocation = [gestureRecognizer locationOfTouch:touch inView:self.view];
    CGPoint sceneLocation = [self convertPointFromView:viewLocation];
    CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
    FLSegmentNode *segmentNode = [self FL_trackFindSegmentNearLocation:worldLocation];
    if (segmentNode && [segmentNode canSwitch]) {
      [self FL_linkSwitchTogglePathIdForSegment:segmentNode animated:YES];
    }
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
    // note: Long press can be used not for selection but just for auto-scroll; in that case,
    // we don't want to bounce back to the old selection.  In fact, if the user gets too accustomed
    // to auto-scroll this way, she might not want world-fit even when doing selection painting.
    // Maybe slightly better than this would be to not world-fit when the selection does not change
    // from the beginning of the gesture.
    if (_worldGestureState.longPressMode != FLWorldLongPressModeNone
        && [self FL_trackSelectedCount] > 1) {
      [self FL_worldFitSegments:_trackSelectState.selectedSegments scaling:YES scrolling:YES includeTrackEditMenu:YES animated:YES];
    }
    [self FL_trackEditMenuUpdateAnimated:YES];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
    [self FL_worldAutoScrollDisable];
    if (_worldGestureState.longPressMode != FLWorldLongPressModeNone
        && [self FL_trackSelectedCount] > 1) {
      [self FL_worldFitSegments:_trackSelectState.selectedSegments scaling:YES scrolling:YES includeTrackEditMenu:YES animated:YES];
    }
    [self FL_trackEditMenuUpdateAnimated:YES];
  }
}

- (void)handleWorldPan:(UIPanGestureRecognizer *)gestureRecognizer
{
  _cameraMode = FLCameraModeManual;

  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

    // note: Our view recognizes two-touch swipe gestures separately from pan gestures.
    // But there is no way of setting numberOfTouchesRequired on a pan recognizer.  So
    // must check manually here.
    //
    // noob: If I test for this in gestureRecognizer:shouldReceiveTouch:, then I always get numberOfTouches=0.
    // And the numberOfTouches changes through the gesture, so should check at the beginning of the gesture.
    if (gestureRecognizer.numberOfTouches != 1) {
      _worldGestureState.panType = FLWorldPanTypeNone;
      return;
    }

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
        return;
      }
    }
    FLSegmentNode *segmentNode = [self FL_trackFindSegmentNearLocation:firstTouchWorldLocation];
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
  static CGPoint handlePinchZoomCenter;

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
    // so that the pinch gesture could do some panning while pinching, but I found it a bit
    // disorienting.  I like choosing my zoom center and then being able to move my fingers around on the
    // screen if I need more room for the gesture.  But probably there's a human interface guideline for
    // this which I should follow.
    handlePinchZoomCenter = CGPointZero;
    if (_cameraMode == FLCameraModeManual) {
      CGPoint centerViewLocation = [gestureRecognizer locationInView:self.view];
      handlePinchZoomCenter = [self convertPointFromView:centerViewLocation];
    }
    return;
  }

  // Zoom around previously-chosen center point.
  CGFloat worldScaleNew = [self FL_worldConstrainedScale:(handlePinchWorldScaleBegin * gestureRecognizer.scale)];
  CGFloat scaleFactor = worldScaleNew / handlePinchWorldScaleBegin;
  [self FL_worldSetConstrainedScale:worldScaleNew
                          positionX:((handlePinchWorldPositionBegin.x - handlePinchZoomCenter.x) * scaleFactor + handlePinchZoomCenter.x)
                          positionY:((handlePinchWorldPositionBegin.y - handlePinchZoomCenter.y) * scaleFactor + handlePinchZoomCenter.y)];
}

- (void)handleWorldRotation:(UIRotationGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
    return;
  }
  if ([self FL_trackSelectedNone]) {
    return;
  }
  int rotateBy;
  if (gestureRecognizer.velocity < 0.0f) {
    rotateBy = 1;
  } else {
    rotateBy = -1;
  }
  [self FL_trackRotateSegments:_trackSelectState.selectedSegments pointers:_trackSelectState.selectedSegmentPointers rotateBy:rotateBy animated:YES];
}

- (void)handleWorldSwipe:(UISwipeGestureRecognizer *)gestureRecognizer
{
  if ([self FL_trackSelectedNone]) {
    return;
  }
  FLSegmentFlipDirection flipDirection;
  switch (gestureRecognizer.direction) {
    case UISwipeGestureRecognizerDirectionLeft:
    case UISwipeGestureRecognizerDirectionRight:
      flipDirection = FLSegmentFlipHorizontal;
      break;
    case UISwipeGestureRecognizerDirectionUp:
    case UISwipeGestureRecognizerDirectionDown:
      flipDirection = FLSegmentFlipVertical;
      break;
    default:
      [NSException raise:@"FLTrackSceneUnknownGestureDirection" format:@"Gesture direction %ld unknown.", (long)gestureRecognizer.direction];
  }
  [self FL_trackFlipSegments:_trackSelectState.selectedSegments pointers:_trackSelectState.selectedSegmentPointers direction:flipDirection];
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

    if ([newNavigation isEqualToString:@"exports"]) {
      if (_constructionToolbarState.toolbarNode.toolCount == 1) {
        [self FL_messageShow:NSLocalizedString(@"No exports found.",
                                               @"Message to user: Shown when navigating to exports toolbar, but no exports are found.")];
      }
    } else if ([newNavigation isEqualToString:@"deletions"]) {
      if (_constructionToolbarState.toolbarNode.toolCount == 1) {
        [self FL_messageShow:NSLocalizedString(@"No deletions found.",
                                               @"Message to user: Shown when navigating to deletions toolbar, but no deletion files are found.")];
      }
    }

  } else if (toolType == FLToolbarToolTypeActionTap) {

    if ([toolTag isEqualToString:@"link"]) {
      if ([self FL_linksToggle]) {
        [self FL_messageShow:NSLocalizedString(@"Entering linking mode.",
                                               @"Message to user: Shown when link-mode button is pressed to enable linking mode.")];
      } else {
        [self FL_messageShow:NSLocalizedString(@"Exiting linking mode.",
                                               @"Message to user: Shown when link-mode button is pressed to disable linking mode.")];
      }
    } else if ([toolTag isEqualToString:@"show-values"]) {
      if ([self FL_valuesToggle]) {
        [self FL_messageShow:NSLocalizedString(@"Showing switch values.",
                                               @"Message to user: Shown when values button is pressed to show switch values.")];
      } else {
        [self FL_messageShow:NSLocalizedString(@"Hiding switch values.",
                                               @"Message to user: Shown when values button is pressed to hide switch values.")];
      }
    } else if ([toolTag isEqualToString:@"show-labels"]) {
      if ([self FL_labelsToggle]) {
        [self FL_messageShow:NSLocalizedString(@"Showing track labels.",
                                               @"Message to user: Shown when labels button is pressed to show track labels.")];
      } else {
        [self FL_messageShow:NSLocalizedString(@"Hiding track labels.",
                                               @"Message to user: Shown when labels button is pressed to hide track labels.")];
      }
    }

  } else if (toolType == FLToolbarToolTypeActionPan) {

    [self FL_messageShow:_constructionToolbarState.toolDescriptions[toolTag]];

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
    if ([toolTag isEqualToString:@"duplicate"] && [self FL_trackSelectedNone]) {
      [self FL_messageShow:NSLocalizedString(@"Duplicate: Make a selection.",
                                             @"Message to user: Shown when duplicate button is dragged but no track is selected.")];
      _worldGestureState.panType = FLWorldPanTypeNone;
      return;
    }

    if (_tutorialState.tutorialActive) {
      [self FL_tutorialRecognizedAction:FLTutorialActionConstructionToolbarPanBegan withArguments:@[ toolTag ]];
    }

    if ([_constructionToolbarState.currentNavigation isEqualToString:@"segments"]) {
      [self FL_trackSelectClear];

      // Create segment.
      FLSegmentType segmentType = (FLSegmentType)[_constructionToolbarState.toolSegmentTypes[toolTag] integerValue];
      FLSegmentNode *newSegmentNode = [self FL_createSegmentWithSegmentType:segmentType];
      newSegmentNode.mayShowLabel = _labelsVisible;
      newSegmentNode.mayShowBubble = _valuesVisible;
      newSegmentNode.zRotation = (CGFloat)M_PI_2;
      // note: Locate the new segment underneath the current touch, even though it's
      // not yet added to the node hierarchy.  (The track move routines translate nodes
      // relative to their current position.)
      int gridX;
      int gridY;
      _trackGrid->convert(worldLocation, &gridX, &gridY);
      newSegmentNode.position = _trackGrid->convert(gridX, gridY);
      [self FL_trackSelectClear];
      [self FL_trackMoveBeganWithNodes:@[ newSegmentNode ] location:worldLocation completion:nil];

    } else if ([toolTag isEqualToString:@"duplicate"]) {

      // Copy selected segments.
      NSArray *duplicatedSegmentNodes;
      NSArray *originalSegmentNodes;
      if (_gameType == FLGameTypeSandbox) {
        duplicatedSegmentNodes = [[NSArray alloc] initWithArray:_trackSelectState.selectedSegments copyItems:YES];
        originalSegmentNodes = _trackSelectState.selectedSegments;
      } else {
        duplicatedSegmentNodes = [NSMutableArray array];
        originalSegmentNodes = [NSMutableArray array];
        for (FLSegmentNode *segmentNode in _trackSelectState.selectedSegments) {
          if ([self FL_gameTypeChallengeCanCreateSegment:segmentNode.segmentType]) {
            [(NSMutableArray *)duplicatedSegmentNodes addObject:[segmentNode copy]];
            [(NSMutableArray *)originalSegmentNodes addObject:segmentNode];
          }
        }
        if ([duplicatedSegmentNodes count] == 0) {
          _worldGestureState.panType = FLWorldPanTypeNone;
          [self FL_messageShow:NSLocalizedString(@"These segments can’t be duplicated.",
                                                 @"Message to user: Shown after unsuccessful duplication of track selection.")];
          return;
        }
      }
      // note: A reasonably fast n^2?  Could put this off until segments placed, but if it's
      // fast enough it's neater to do it ahead of time.
      NSMutableArray *links = [NSMutableArray array];
      NSUInteger segmentNodeCount = [originalSegmentNodes count];
      for (NSUInteger i = 0; i < segmentNodeCount; ++i) {
        for (NSUInteger j = i + 1; j < segmentNodeCount; ++j) {
          if (_links.get(originalSegmentNodes[i], originalSegmentNodes[j])) {
            [links addObject:duplicatedSegmentNodes[i]];
            [links addObject:duplicatedSegmentNodes[j]];
          }
        }
      }

      // Configure imported segments for this world.
      if (_gameType == FLGameTypeChallenge) {
        for (FLSegmentNode *segmentNode in duplicatedSegmentNodes) {
          segmentNode.label = FLSegmentLabelNone;
        }
      }

      // Locate the new segments underneath the current touch.
      //
      // note: Do so even though they are not yet added to the node hierarchy.  (The track move
      // routines translate nodes relative to their current position.)
      [self FL_segments:duplicatedSegmentNodes setPositionCenteredOnLocation:worldLocation];

      // Scale world to fit import, if possible.
      [self FL_worldFitSegments:duplicatedSegmentNodes scaling:YES scrolling:NO includeTrackEditMenu:YES animated:YES];

      // Begin track move.
      [self FL_messageShow:NSLocalizedString(@"Duplicated selection to track.",
                                             @"Message to user: Shown after successful duplication of track selection.")];
      [self FL_trackSelectClear];
      [self FL_trackMoveBeganWithNodes:duplicatedSegmentNodes location:worldLocation completion:^(BOOL placed){
        if (placed) {
          for (NSUInteger l = 0; l + 1 < [links count]; l += 2) {
            FLSegmentNode *a = links[l];
            FLSegmentNode *b = links[l + 1];
            SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:a.switchLinkLocation toLocation:b.switchLinkLocation linkErase:NO];
            self->_links.insert(a, b, connectorNode);
          }
        }
      }];

    } else {

      // Import segments.
      NSString *importDirectory;
      if ([_constructionToolbarState.currentNavigation isEqualToString:@"gates"]) {
        importDirectory = FLGatesDirectoryPath;
      } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"circuits"]) {
        importDirectory = FLCircuitsDirectoryPath;
      } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"exports"]) {
        importDirectory = FLExportsDirectoryPath;
      } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"deletions"]) {
        importDirectory = FLDeletionsDirectoryPath;
      } else {
        [NSException raise:@"FLConstructionToolbarInvalidNavigation" format:@"Unrecognized navigation '%@'.", _constructionToolbarState.currentNavigation];
      }
      NSString *importPath = [importDirectory stringByAppendingPathComponent:[toolTag stringByAppendingPathExtension:@"archive"]];
      NSString *description;
      NSArray *links;
      NSArray *newSegmentNodes = [self FL_segmentsReadArchiveWithPath:importPath description:&description links:&links];

      // Remove any disallowed segment types.
      NSMutableSet *removedSegmentNodePointers = [NSMutableSet set];
      if (_gameType == FLGameTypeChallenge) {
        NSMutableArray *allowedSegmentNodes = [NSMutableArray array];
        for (FLSegmentNode *segmentNode in newSegmentNodes) {
          if ([self FL_gameTypeChallengeCanCreateSegment:segmentNode.segmentType]) {
            [allowedSegmentNodes addObject:segmentNode];
          } else {
            [removedSegmentNodePointers addObject:[NSValue valueWithNonretainedObject:segmentNode]];
          }
        }
        newSegmentNodes = allowedSegmentNodes;
        if ([newSegmentNodes count] == 0) {
          _worldGestureState.panType = FLWorldPanTypeNone;
          [self FL_messageShow:NSLocalizedString(@"These segments can’t be imported.",
                                                 @"Message to user: Shown after unsuccessful import.")];
          return;
        }
      }

      // Configure imported segments for this world.
      for (FLSegmentNode *segmentNode in newSegmentNodes) {
        segmentNode.mayShowLabel = _labelsVisible;
        segmentNode.mayShowBubble = _valuesVisible;
        if (_gameType == FLGameTypeChallenge) {
          segmentNode.label = FLSegmentLabelNone;
        }
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
      [self FL_trackSelectClear];
      [self FL_trackMoveBeganWithNodes:newSegmentNodes location:worldLocation completion:^(BOOL placed){
        if (placed) {
          for (NSUInteger l = 0; l + 1 < [links count]; l += 2) {
            FLSegmentNode *a = links[l];
            FLSegmentNode *b = links[l + 1];
            if ([removedSegmentNodePointers containsObject:[NSValue valueWithNonretainedObject:a]]
                || [removedSegmentNodePointers containsObject:[NSValue valueWithNonretainedObject:b]]) {
              continue;
            }
            SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:a.switchLinkLocation toLocation:b.switchLinkLocation linkErase:NO];
            self->_links.insert(a, b, connectorNode);
          }
        }
      }];
    }

    _worldGestureState.panType = FLWorldPanTypeTrackMove;
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
    id<FLTrackSceneDelegate> delegate = self.trackSceneDelegate;
    if (delegate) {
      [delegate trackSceneDidTapMenuButton:self];
    }
  } else if ([toolTag isEqualToString:@"play"]) {
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
    [self FL_worldSetPositionToTrainAnimatedDuration:FLWorldAdjustDuration
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
  if (gestureRecognizer.state != UIGestureRecognizerStateEnded) {
    return;
  }

  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_trackEditMenuState.editMenuNode convertPoint:sceneLocation fromNode:self];
  NSString *buttonTag = [_trackEditMenuState.editMenuNode toolAtLocation:toolbarLocation];

  [self FL_handleTrackEditMenuTap:buttonTag];
}

- (void)FL_handleTrackEditMenuTap:(NSString *)buttonTag
{
  if ([buttonTag isEqualToString:@"rotate-cw"]) {
    [self FL_trackRotateSegments:_trackSelectState.selectedSegments pointers:_trackSelectState.selectedSegmentPointers rotateBy:-1 animated:YES];
  } else if ([buttonTag isEqualToString:@"rotate-ccw"]) {
    [self FL_trackRotateSegments:_trackSelectState.selectedSegments pointers:_trackSelectState.selectedSegmentPointers rotateBy:1 animated:YES];
  } else if ([buttonTag isEqualToString:@"flip-horizontal"]) {
    [self FL_trackFlipSegments:_trackSelectState.selectedSegments pointers:_trackSelectState.selectedSegmentPointers direction:FLSegmentFlipHorizontal];
  } else if ([buttonTag isEqualToString:@"flip-vertical"]) {
    [self FL_trackFlipSegments:_trackSelectState.selectedSegments pointers:_trackSelectState.selectedSegmentPointers direction:FLSegmentFlipVertical];
  } else if ([buttonTag isEqualToString:@"toggle-switch"]) {
    [self FL_linkSwitchTogglePathIdForSegments:_trackSelectState.selectedSegments animated:YES];
  } else if ([buttonTag isEqualToString:@"set-label"]) {
    [self FL_labelPickForSegments:_trackSelectState.selectedSegments];
  } else if ([buttonTag isEqualToString:@"export"]) {
    [self FL_export];
  }
}

- (void)handleTrackEditMenuDoubleTap:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state != UIGestureRecognizerStateEnded) {
    return;
  }
  
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_trackEditMenuState.editMenuNode convertPoint:sceneLocation fromNode:self];
  NSString *buttonTag = [_trackEditMenuState.editMenuNode toolAtLocation:toolbarLocation];
  
  if ([buttonTag isEqualToString:@"delete"]) {
    if ([self FL_deleteSegments:_trackSelectState.selectedSegments pointers:_trackSelectState.selectedSegmentPointers] == 0) {
      [self FL_messageShow:NSLocalizedString(@"Cannot delete special segments.",
                                             @"Message to user: Shown when user tries to delete special track segments in challenge mode.")];
    }
  } else {
    // note: Our current configuration of tap gesture recognizers (no simultaneous
    // recognition, and no requirement for others to fail) means the single tap
    // recognizer has already triggered, and we have the option of triggering it
    // again explicitly if this double-tap should instead be treated as two single-taps.
    // In this handler, that's the case for any button that doesn't want the double-tap.
    [self FL_handleTrackEditMenuTap:buttonTag];
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

    BOOL enabled = ![_trackEditMenuState.editMenuNode enabledForTool:buttonTag];
    for (FLSegmentNode *segmentNode in _trackSelectState.selectedSegments) {
      if ([self FL_segmentCanHideSwitch:segmentNode.segmentType]) {
        segmentNode.mayShowSwitch = enabled;
        if (!enabled) {
          // note: Could make the user do this manually.  But this seems like a safe bet
          // in terms of convenience.
          _links.erase(segmentNode);
        }
      }
    }
    // note: It should be possible to avoid recreating the track edit menu, and instead
    // just determine for ourselves whether or not the toggle-switch button should be
    // enabled or not.  And in particular, we have the advantage of knowing it was already
    // displayed, and so the decision whether to enable it or not should be somewhat
    // trivial.  However, until performance is an issue, don't violate the encapsulation
    // here; just let the track menu figure it out.
    [self FL_trackEditMenuShowAnimated:NO];

  } else if ([buttonTag isEqualToString:@"delete"]) {
    [self FL_messageShow:NSLocalizedString(@"Double-tap to delete selected track.",
                                           @"Message to user: Shown as a hint delete button is long-pressed rather than double-tapped.")];
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
  // Taps: Even without simultaneous recognition enabled, a double tap will result in two
  // gesture handlers recognizing: The first tap will trigger a single-tap (in "ended"
  // state) (and nothing on the double-tap handler), and the second tap will trigger a
  // double-tap (in "ended" state).  Simultaneous recognition means the second tap will
  // also be recognized as a second single-tap.  Requiring gesture recognizer to fail
  // on the single tap blocks the first tap from being recognized at all.  Currently the
  // code is written with no simultaneous recognition desired: If the double-tap handler
  // doesn't want to do anything, it has the option of calling the single-tap handler
  // again to handle the second tap.

  // Swipe and pan: Basically these are the same gesture, or at least every swipe is
  // also a pan, so they must be recognized simultaneously or else one will never fire.
  // (I think according to my early tests, the swipe always worked and never the pan.)
  // So allow simultaneous.  (But of course I don't actually want both gestures to
  // happen at the same time.  I tried having the swipes require more touches, but the
  // pan gesture recognizes even when there are multiple touches.  I tried having the
  // pan requireGestureRecognizerToFail for the swipe, but that's too much delay.
  // Instead I do extra testing on number of touches after both gestures have
  // recognized simultaneously; see notes elsewhere.)
  if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]
      && [otherGestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]]) {
    return YES;
  }
  // Pinch and rotation: If they don't recognize simultaneously, the pinch usually
  // wins, and it's pretty hard to do a rotation.  However, when they recognize
  // simultaneously, then I find they both pretty much recognize every time, and it's
  // too easy to rotate things accidentally.  I could recognize both simultaneously and
  // then put some kind of test in the rotation code e.g. a minimum velocity or angle
  // or something.  But actually that's pretty much the same thing that happens when
  // they aren't recognized simultaneously.  So go with that for now; commented out.
  //if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]
  //    && [otherGestureRecognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
  //  return YES;
  //}
  return NO;
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
        if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]
            && [(UITapGestureRecognizer *)gestureRecognizer numberOfTapsRequired] == 1) {
          [gestureRecognizer removeTarget:nil action:NULL];
          [gestureRecognizer addTarget:self action:@selector(handleTutorialTap:)];
          return YES;
        }
        if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
          [gestureRecognizer removeTarget:nil action:NULL];
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
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
      [gestureRecognizer removeTarget:nil action:NULL];
      [gestureRecognizer addTarget:self action:@selector(handleConstructionToolbarPan:)];
      return YES;
    }
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]
        && [(UITapGestureRecognizer *)gestureRecognizer numberOfTapsRequired] == 1) {
      [gestureRecognizer removeTarget:nil action:NULL];
      [gestureRecognizer addTarget:self action:@selector(handleConstructionToolbarTap:)];
      return YES;
    }
    if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
      [gestureRecognizer removeTarget:nil action:NULL];
      [gestureRecognizer addTarget:self action:@selector(handleConstructionToolbarLongPress:)];
      return YES;
    }
    return NO;
  }

  // Simulation toolbar.
  if (_simulationToolbarState.toolbarNode
      && _simulationToolbarState.toolbarNode.parent
      && [_simulationToolbarState.toolbarNode containsPoint:sceneLocation]) {
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]
        && [(UITapGestureRecognizer *)gestureRecognizer numberOfTapsRequired] == 1) {
      [gestureRecognizer removeTarget:nil action:NULL];
      [gestureRecognizer addTarget:self action:@selector(handleSimulationToolbarTap:)];
      return YES;
    }
    if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
      [gestureRecognizer removeTarget:nil action:NULL];
      [gestureRecognizer addTarget:self action:@selector(handleSimulationToolbarLongPress:)];
      return YES;
    }
    return NO;
  }

  // Track edit menu.
  if (_trackEditMenuState.showing
      && [_trackEditMenuState.editMenuNode containsPoint:sceneLocation]) {
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
      NSUInteger numberOfTapsRequired = [(UITapGestureRecognizer *)gestureRecognizer numberOfTapsRequired];
      switch (numberOfTapsRequired) {
        case 1:
          [gestureRecognizer removeTarget:nil action:NULL];
          [gestureRecognizer addTarget:self action:@selector(handleTrackEditMenuTap:)];
          return YES;
        case 2:
          [gestureRecognizer removeTarget:nil action:NULL];
          [gestureRecognizer addTarget:self action:@selector(handleTrackEditMenuDoubleTap:)];
          return YES;
        default:
          break;
      }
    }
    if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
      [gestureRecognizer removeTarget:nil action:NULL];
      [gestureRecognizer addTarget:self action:@selector(handleTrackEditMenuLongPress:)];
      return YES;
    }
    return NO;
  }

  // Train.
  CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
  if (_train.parent
      && [_train containsPoint:worldLocation]) {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
      [gestureRecognizer removeTarget:nil action:NULL];
      [gestureRecognizer addTarget:self action:@selector(handleTrainPan:)];
      return YES;
    }
    return NO;
  }

  // World (and track).
  if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
    NSUInteger numberOfTapsRequired = [(UITapGestureRecognizer *)gestureRecognizer numberOfTapsRequired];
    switch (numberOfTapsRequired) {
      case 1:
        [gestureRecognizer removeTarget:nil action:NULL];
        [gestureRecognizer addTarget:self action:@selector(handleWorldTap:)];
        return YES;
      case 2: {
        NSUInteger numberOfTouchesRequired = [(UITapGestureRecognizer *)gestureRecognizer numberOfTouchesRequired];
        if (numberOfTouchesRequired == 1) {
          [gestureRecognizer removeTarget:nil action:NULL];
          [gestureRecognizer addTarget:self action:@selector(handleWorldDoubleTap:)];
          return YES;
        } else {
          [gestureRecognizer removeTarget:nil action:NULL];
          [gestureRecognizer addTarget:self action:@selector(handleWorldDoubleTwoTap:)];
          return YES;
        }
      }
      default:
        break;
    }
  } else if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
    [gestureRecognizer removeTarget:nil action:NULL];
    [gestureRecognizer addTarget:self action:@selector(handleWorldLongPress:)];
    return YES;
  } else if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
    [gestureRecognizer removeTarget:nil action:NULL];
    [gestureRecognizer addTarget:self action:@selector(handleWorldPan:)];
    return YES;
  } else if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
    [gestureRecognizer removeTarget:nil action:NULL];
    [gestureRecognizer addTarget:self action:@selector(handleWorldPinch:)];
    return YES;
  } else if ([gestureRecognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
    [gestureRecognizer removeTarget:nil action:NULL];
    [gestureRecognizer addTarget:self action:@selector(handleWorldRotation:)];
    return YES;
  } else if ([gestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]]) {
    [gestureRecognizer removeTarget:nil action:NULL];
    [gestureRecognizer addTarget:self action:@selector(handleWorldSwipe:)];
    return YES;
  }

  // None.
  //
  // noob: Need to call removeTarget:?
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

  FLSegmentType segmentType = segmentNode.segmentType;
  if (_gameType == FLGameTypeChallenge) {
    if (segmentType == FLSegmentTypePlatformLeft || segmentType == FLSegmentTypePlatformRight) {
      FLSegmentNode *platformStartSegmentNode = nil;
      for (auto s : *_trackGrid) {
        if (s.second.segmentType == FLSegmentTypePlatformStartLeft || s.second.segmentType == FLSegmentTypePlatformStartRight) {
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
  } else if (segmentType == FLSegmentTypePlatformLeft || segmentType == FLSegmentTypePlatformRight
             || segmentType == FLSegmentTypePlatformStartLeft || segmentType == FLSegmentTypePlatformStartRight) {
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
#pragma mark FLGoalsNodeDelegate

- (void)goalsNode:(FLGoalsNode *)goalsNode didDismissWithNextLevel:(BOOL)nextLevel
{
  [self FL_goalsDismissWithNextLevel:nextLevel];
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
  [textureStore setTextureWithImageNamed:@"export" forKey:@"export" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"rotate-cw" forKey:@"rotate-cw" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"rotate-ccw" forKey:@"rotate-ccw" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"flip-horizontal" forKey:@"flip-horizontal" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"flip-vertical" forKey:@"flip-vertical" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"set-label" forKey:@"set-label" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"toggle-switch" forKey:@"toggle-switch" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"main" forKey:@"main" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"next" forKey:@"next" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"previous" forKey:@"previous" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"segments" forKey:@"segments" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"gates" forKey:@"gates" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"circuits" forKey:@"circuits" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"exports" forKey:@"exports" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"deletions" forKey:@"deletions" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"duplicate" forKey:@"duplicate" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"link" forKey:@"link" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"show-labels" forKey:@"show-labels" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"show-values" forKey:@"show-values" filteringMode:SKTextureFilteringLinear];

  // Other.
  [textureStore setTextureWithImageNamed:@"switch" andUIImageWithImageNamed:@"switch-nonatlas.png" forKey:@"switch" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImageNamed:@"value-0" andUIImageWithImageNamed:@"value-0-nonatlas.png" forKey:@"value-0" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"value-1" andUIImageWithImageNamed:@"value-1-nonatlas.png" forKey:@"value-1" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"unlock" forKey:@"unlock" filteringMode:SKTextureFilteringLinear];

  // Segments.
  [textureStore setTextureWithImageNamed:@"straight" andUIImageWithImageNamed:@"straight-nonatlas" forKey:@"straight" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"curve" andUIImageWithImageNamed:@"curve-nonatlas" forKey:@"curve" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"join-left" andUIImageWithImageNamed:@"join-left-nonatlas" forKey:@"join-left" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"join-right" andUIImageWithImageNamed:@"join-right-nonatlas" forKey:@"join-right" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"jog-left" andUIImageWithImageNamed:@"jog-left-nonatlas" forKey:@"jog-left" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"jog-right" andUIImageWithImageNamed:@"jog-right-nonatlas" forKey:@"jog-right" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"cross" andUIImageWithImageNamed:@"cross-nonatlas" forKey:@"cross" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"platform-left" andUIImageWithImageNamed:@"platform-left-nonatlas" forKey:@"platform-left" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"platform-right" andUIImageWithImageNamed:@"platform-right-nonatlas" forKey:@"platform-right" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"platform-start-left" andUIImageWithImageNamed:@"platform-start-left-nonatlas" forKey:@"platform-start-left" filteringMode:SKTextureFilteringNearest];
  [textureStore setTextureWithImageNamed:@"platform-start-right" andUIImageWithImageNamed:@"platform-start-right-nonatlas" forKey:@"platform-start-right" filteringMode:SKTextureFilteringNearest];
  // note: This looks particularly bad when used as a toolbar image -- which in fact is its only purpose.  But *all*
  // the segments look bad, so I'm choosing not to use linear filtering on this one, for now; see the TODO in HLToolbarNode.
  [textureStore setTextureWithImage:[FLSegmentNode createImageForReadoutSegment:FLSegmentTypeReadoutInput imageSize:FLSegmentArtSizeFull] forKey:@"readout-input" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImage:[FLSegmentNode createImageForReadoutSegment:FLSegmentTypeReadoutOutput imageSize:FLSegmentArtSizeFull] forKey:@"readout-output" filteringMode:SKTextureFilteringLinear];
  [textureStore setTextureWithImage:[FLSegmentNode createImageForPixelSegmentImageSize:FLSegmentArtSizeFull] forKey:@"pixel" filteringMode:SKTextureFilteringLinear];

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
  
  [emitterStore setEmitterWithResource:@"happyBurst" forKey:@"happyBurst"];

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
  [SKAction playSoundFileNamed:@"brr-bring.caf" waitForCompletion:NO];

  NSLog(@"FLTrackScene loadSound: loaded in %0.2f seconds", [[NSDate date] timeIntervalSinceDate:startDate]);
}

- (FLSegmentNode *)FL_createSegmentWithSegmentType:(FLSegmentType)segmentType
{
  FLSegmentNode *segmentNode = [[FLSegmentNode alloc] initWithSegmentType:segmentType];
  segmentNode.scale = FLTrackArtScale;
  return segmentNode;
}

- (SKSpriteNode *)FL_createToolNodeForTextureKey:(NSString *)textureKey textureStore:(HLTextureStore *)textureStore
{
  SKTexture *texture = [textureStore textureForKey:textureKey];
  SKSpriteNode *toolNode = [SKSpriteNode spriteNodeWithTexture:texture];
  toolNode.zRotation = (CGFloat)M_PI_2;
  return toolNode;
}

- (NSArray *)FL_segmentsReadArchiveWithPath:(NSString *)path
                                description:(NSString * __autoreleasing *)trackDescription
                                      links:(NSArray * __autoreleasing *)links
{
  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
    [NSException raise:@"FLReadPathInvalid" format:@"Invalid read path %@.", path];
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

- (void)FL_segments:(NSArray *)segmentNodes
writeArchiveWithPath:(NSString *)path
    segmentPointers:(NSSet *)segmentPointers
        description:(NSString *)trackDescription
{
  // note: Could configure nodes in a standard way for write: e.g. no labels or values
  // showing and with the lower-leftmost segment (of the export) starting at position (0,0).
  // But these things are configured on read, and there seems to be no value in having the
  // raw data standardized.  A possible reason: Reducing nodes to their essentials makes the
  // data files more predictable (e.g. good for diffing).  Nah.  Not compelling.
  
  NSMutableData *archiveData = [NSMutableData data];
  NSKeyedArchiver *aCoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archiveData];
  
  [aCoder encodeObject:trackDescription forKey:@"trackDescription"];
  [aCoder encodeObject:segmentNodes forKey:@"segmentNodes"];
  NSArray *links = linksIntersect(_links, segmentPointers);
  [aCoder encodeObject:links forKey:@"links"];
  [aCoder finishEncoding];

  [archiveData writeToFile:path atomically:NO];
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

- (BOOL)FL_segmentCanHideSwitch:(FLSegmentType)segmentType
{
  // note: Only allow showing/hiding switches on certain kinds of segments.  This isn't
  // implemented in FLSegmentNode because the segments don't care one way or another:
  // this is an application thing, deciding whether or not we want to allow it.
  return (segmentType == FLSegmentTypeJoinLeft || segmentType == FLSegmentTypeJoinRight);
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

- (void)FL_worldSetPositionToTrainAnimatedDuration:(NSTimeInterval)duration
                                        completion:(void (^)(void))completion
{
  // note: No big deal if train isn't moving.  But if train is moving, need to
  // continually update destination.
  SKAction *move = [SKAction customActionWithDuration:duration actionBlock:^(SKNode *node, CGFloat elapsedTime){
    CGPoint trainSceneLocation = [self convertPoint:self->_train.position fromNode:self->_worldNode];
    CGPoint currentWorldPosition = self->_worldNode.position;
    CGFloat currentWorldScale = self->_worldNode.xScale;
    CGPoint targetWorldPosition = [self FL_worldConstrainedPositionX:(currentWorldPosition.x - trainSceneLocation.x)
                                                           positionY:(currentWorldPosition.y - trainSceneLocation.y)
                                                           forScaleX:currentWorldScale
                                                              scaleY:currentWorldScale];
    CGFloat elapsedProportion = (CGFloat)(elapsedTime / duration);
    self->_worldNode.position = CGPointMake(currentWorldPosition.x + (targetWorldPosition.x - currentWorldPosition.x) * elapsedProportion,
                                            currentWorldPosition.y + (targetWorldPosition.y - currentWorldPosition.y) * elapsedProportion);
  }];
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
  if (includeTrackEditMenu) {
    visibleSceneBottom -= (_interfaceSizeClass == UIUserInterfaceSizeClassCompact ? FLTrackEditMenuHeightCompact : FLTrackEditMenuHeightRegular);
  }
  CGSize visibleSceneSize = CGSizeMake(visibleSceneRight - visibleSceneLeft, visibleSceneTop - visibleSceneBottom);

  CGFloat worldConstrainedScaleNew = _worldNode.xScale;
  if (scaling) {
    CGFloat worldScaleFit;
    worldScaleFit = MIN(visibleSceneSize.width / contentWorldSize.width,
                        visibleSceneSize.height / contentWorldSize.height);
    CGFloat worldConstrainedScaleFit = [self FL_worldConstrainedScale:worldScaleFit];
    if (worldConstrainedScaleFit < worldConstrainedScaleNew) {
      worldConstrainedScaleNew = worldConstrainedScaleFit;
    }
  }

  CGPoint worldPositionNew = _worldNode.position;
  if (scrolling) {

    // Calculate some additional helpful scrolling-relevant metrics.
    CGSize visibleWorldSize = CGSizeMake(visibleSceneSize.width / worldConstrainedScaleNew,
                                         visibleSceneSize.height / worldConstrainedScaleNew);
    CGPoint visibleSceneCenter = CGPointMake(visibleSceneLeft + (visibleSceneRight - visibleSceneLeft) / 2.0f,
                                             visibleSceneBottom + (visibleSceneTop - visibleSceneBottom) / 2.0f);
    CGPoint visibleWorldCenter = CGPointMake((visibleSceneCenter.x - _worldNode.position.x) / worldConstrainedScaleNew,
                                             (visibleSceneCenter.y - _worldNode.position.y) / worldConstrainedScaleNew);
    CGPoint contentWorldCenter = CGPointMake(contentWorldLeft + (contentWorldRight - contentWorldLeft) / 2.0f,
                                             contentWorldBottom + (contentWorldTop - contentWorldBottom) / 2.0f);

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

  // note: 768x1024 is the current screen (logical point) maximum; 96 points seems enough
  // of a margin for any screen size.
  const CGFloat FLWorldAutoScrollMarginSizeMax = 96.0f;
  CGFloat marginSize = MIN(self.size.width, self.size.height) / 7.0f;
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
  //   v_mag = linear*p + min
  //
  // I played with various non-linear functions, but this seemed the best.
  const CGFloat FLAutoScrollVelocityMin = 4.0f;
  const CGFloat FLAutoScrollVelocityLinear = 800.0f;

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
    CGFloat speed = FLAutoScrollVelocityLinear * proximity + FLAutoScrollVelocityMin;
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
  if (_interfaceSizeClass == UIUserInterfaceSizeClassCompact) {
    _constructionToolbarState.toolbarNode.size = CGSizeMake(self.size.width, FLMainToolbarHeightCompact);
  } else {
    _constructionToolbarState.toolbarNode.size = CGSizeMake(self.size.width, FLMainToolbarHeightRegular);
  }

  // note: Page might be too large as a result of additional toolbar width made possible by the new geometry.
  int pageMax = _constructionToolbarState.currentPage;
  if ([_constructionToolbarState.currentNavigation isEqualToString:@"gates"]) {
    pageMax = [self FL_constructionToolbarArchivesPageMax:FLGatesDirectoryPath];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"circuits"]) {
    pageMax = [self FL_constructionToolbarArchivesPageMax:FLCircuitsDirectoryPath];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"exports"]) {
    pageMax = [self FL_constructionToolbarArchivesPageMax:FLExportsDirectoryPath];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"deletions"]) {
    pageMax = [self FL_constructionToolbarArchivesPageMax:FLDeletionsDirectoryPath];
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
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"deletions"]) {
    [self FL_constructionToolbarShowDeletions:_constructionToolbarState.currentPage animation:animation];
  } else {
    [NSException raise:@"FLConstructionToolbarInvalidNavigation" format:@"Unrecognized navigation '%@'.", _constructionToolbarState.currentNavigation];
  }
}

- (void)FL_constructionToolbarShowMain:(int)page animation:(HLToolbarNodeAnimation)animation
{
  HLTextureStore *sharedTextureStore = [HLTextureStore sharedStore];
  NSMutableArray *toolNodes = [NSMutableArray array];
  NSMutableArray *toolTags = [NSMutableArray array];
  NSString *textureKey;

  textureKey = @"segments";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);

  if ([self FL_unlocked:FLUnlockGates]) {
    textureKey = @"gates";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  }

  if ([self FL_unlocked:FLUnlockCircuits]) {
    textureKey = @"circuits";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  }

  textureKey = @"exports";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  
  textureKey = @"deletions";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  
  textureKey = @"duplicate";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Drag to duplicate selected track.",
                                                                             @"Message to user: shown when the duplicate tool (in the bottom toolbar) is tapped.");
  
  textureKey = @"link";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionTap);

  textureKey = @"show-labels";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionTap);

  textureKey = @"show-values";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionTap);

  [_constructionToolbarState.toolbarNode setTools:toolNodes tags:toolTags animation:animation];

  [_constructionToolbarState.toolbarNode setHighlight:_linksVisible forTool:@"link"];
  [_constructionToolbarState.toolbarNode setHighlight:_labelsVisible forTool:@"show-labels"];
  [_constructionToolbarState.toolbarNode setHighlight:_valuesVisible forTool:@"show-values"];
}

- (void)FL_constructionToolbarShowSegments:(int)page animation:(HLToolbarNodeAnimation)animation
{
  HLTextureStore *sharedTextureStore = [HLTextureStore sharedStore];
  NSMutableArray *toolNodes = [NSMutableArray array];
  NSMutableArray *toolTags = [NSMutableArray array];
  NSString *textureKey;

  textureKey = @"straight";
  [toolTags addObject:textureKey];
  SKSpriteNode *toolNode = [self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore];
  toolNode.position = CGPointMake(FLSegmentArtStraightShift, 0.0f);
  [toolNodes addObject:toolNode];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Straight Track",
                                                                             @"The name of the straight track segment.");
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeStraight);

  textureKey = @"curve";
  [toolTags addObject:textureKey];
  toolNode = [self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore];
  toolNode.position = CGPointMake(FLSegmentArtCurveShift, -FLSegmentArtCurveShift);
  [toolNodes addObject:toolNode];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Curved Track",
                                                                             @"The name of the curved track segment.");
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeCurve);

  textureKey = @"join-left";
  [toolTags addObject:textureKey];
  toolNode = [self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore];
  toolNode.position = CGPointMake(FLSegmentArtCurveShift, -FLSegmentArtCurveShift);
  [toolNodes addObject:toolNode];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Fork Right Track",
                                                                             @"The name of the track segment with one straight section and one that curves away to the right.");
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeJoinLeft);

  textureKey = @"join-right";
  [toolTags addObject:textureKey];
  toolNode = [self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore];
  toolNode.position = CGPointMake(FLSegmentArtCurveShift, FLSegmentArtCurveShift);
  [toolNodes addObject:toolNode];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Fork Left Track",
                                                                             @"The name of the track segment with one straight section and one that curves away to the left.");
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeJoinRight);

  textureKey = @"jog-left";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Jog Left Track",
                                                                             @"The name of the track segment that jogs to the left.");
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeJogLeft);

  textureKey = @"jog-right";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Jog Right Track",
                                                                             @"The name of the track segment that jogs to the right.");
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeJogRight);

  textureKey = @"cross";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Cross Track",
                                                                             @"The name of the track segment that is shaped like an X.");
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeCross);

  if (_gameType != FLGameTypeChallenge || [self FL_gameTypeChallengeCanCreateSegment:FLSegmentTypeReadoutInput]) {
    textureKey = @"readout-input";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
    _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Input Value",
                                                                               @"The name of the track segment that shows input values using a switch and numbers.");
    _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeReadoutInput);
  }

  if (_gameType != FLGameTypeChallenge || [self FL_gameTypeChallengeCanCreateSegment:FLSegmentTypeReadoutOutput]) {
    textureKey = @"readout-output";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
    _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Output Value",
                                                                               @"The name of the track segment that shows output values using a switch and numbers.");
    _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypeReadoutOutput);
  }

  if (_gameType != FLGameTypeChallenge || [self FL_gameTypeChallengeCanCreateSegment:FLSegmentTypePixel]) {
    textureKey = @"pixel";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
    _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"White/Black Value",
                                                                               @"The name of the track segment that shows values using a block of color.");
    _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypePixel);
  }

  textureKey = @"platform-left";
  [toolTags addObject:textureKey];
  toolNode = [self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore];
  toolNode.position = CGPointMake(FLSegmentArtStraightShift, 0.0f);
  [toolNodes addObject:toolNode];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Platform",
                                                                             @"The name of the (non-starting) platform track segment.");
  _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypePlatformLeft);

  if (_gameType != FLGameTypeChallenge || [self FL_gameTypeChallengeCanCreateSegment:FLSegmentTypePlatformStartLeft]) {
    textureKey = @"platform-start-left";
    [toolTags addObject:textureKey];
    toolNode = [self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore];
    toolNode.position = CGPointMake(FLSegmentArtStraightShift, 0.0f);
    [toolNodes addObject:toolNode];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
    _constructionToolbarState.toolDescriptions[textureKey] = NSLocalizedString(@"Starting Platform",
                                                                               @"The name of the starting platform track segment.");
    _constructionToolbarState.toolSegmentTypes[textureKey] = @(FLSegmentTypePlatformStartLeft);
  }

  // note: Currently we create all tools and then discard those that aren't on the current page.
  // Obviously that could be tweaked for performance.
  NSMutableArray *pageToolNodes;
  NSMutableArray *pageToolTags;
  // note: There are currently seven basic segments; it makes sense to put them all on the
  // first page together, even if that means scaling.
  const NSUInteger FLConstructionToolbarSegmentsPageSizeMin = 9;
  NSUInteger pageSize = [self FL_constructionToolbarPageSize];
  if (pageSize < FLConstructionToolbarSegmentsPageSizeMin) {
    pageSize = FLConstructionToolbarSegmentsPageSizeMin;
  }
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
  [self FL_constructionToolbarShowArchives:FLGatesDirectoryPath sortByDate:NO unlockItems:&unlockItems page:page recreateTextures:NO animation:animation];
}

- (void)FL_constructionToolbarShowCircuits:(int)page animation:(HLToolbarNodeAnimation)animation
{
  vector<FLUnlockItem> unlockItems = {
    FLUnlockCircuitXor,
    FLUnlockCircuitHalfAdder,
    FLUnlockCircuitFullAdder,
  };
  [self FL_constructionToolbarShowArchives:FLCircuitsDirectoryPath sortByDate:NO unlockItems:&unlockItems page:page recreateTextures:NO animation:animation];
}

- (void)FL_constructionToolbarShowExports:(int)page animation:(HLToolbarNodeAnimation)animation
{
  [self FL_constructionToolbarShowArchives:FLExportsDirectoryPath sortByDate:YES unlockItems:nullptr page:page recreateTextures:NO animation:animation];
}

- (void)FL_constructionToolbarShowDeletions:(int)page animation:(HLToolbarNodeAnimation)animation
{
  BOOL recreateTextures = _deleteState.dirtyTextures;
  [self FL_constructionToolbarShowArchives:FLDeletionsDirectoryPath sortByDate:YES unlockItems:nullptr page:page recreateTextures:recreateTextures animation:animation];
  _deleteState.dirtyTextures = NO;
}

- (void)FL_constructionToolbarShowArchives:(NSString *)archiveDirectory
                                sortByDate:(BOOL)sortByDate
                               unlockItems:(vector<FLUnlockItem> *)unlockItems
                                      page:(int)page
                          recreateTextures:(BOOL)recreateTextures
                                 animation:(HLToolbarNodeAnimation)animation
{
  // Get a list of all archives (sorted appropriately).
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *archiveFiles;
  if (sortByDate) {
    NSURL *archiveURL = [NSURL fileURLWithPath:archiveDirectory isDirectory:NO];
    NSArray *archiveFileURLs = [fileManager contentsOfDirectoryAtURL:archiveURL includingPropertiesForKeys:@[ NSURLCreationDateKey ] options:0 error:nil];
    NSArray *sortedArchiveFileURLs = [archiveFileURLs sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2){
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
    NSMutableArray *mutableArchiveFiles = [NSMutableArray array];
    for (NSURL *url in sortedArchiveFileURLs) {
      NSDate *date = nil;
      [url getResourceValue:&date forKey:NSURLCreationDateKey error:nil];
      [mutableArchiveFiles addObject:[url lastPathComponent]];
    }
    archiveFiles = mutableArchiveFiles;
  } else {
    // note: "Normal" sorting is alphabetical; the preloaded gates and circuits take
    // advantage of this by naming their files in the desired order for the interface.
    archiveFiles = [fileManager contentsOfDirectoryAtPath:archiveDirectory error:nil];
    archiveFiles = [archiveFiles sortedArrayUsingSelector:@selector(compare:)];
  }

  // Get textures for each unlocked archive (creating new textures where appropriate).
  size_t unlockItemIndex = 0;
  NSMutableArray *archiveTextureKeys = [NSMutableArray array];
  for (NSString *archiveFile in archiveFiles) {
    if (!unlockItems || unlockItemIndex >= unlockItems->size() || [self FL_unlocked:(*unlockItems)[unlockItemIndex]]) {
      // note: Assume no namespace conflicts among gates, circuits, exports, deletions, and any
      // other callers.  Maybe safer to create separate texture stores for each, but it seems
      // safe enough as-is.
      NSString *archiveName = [archiveFile stringByDeletingPathExtension];
      SKTexture *texture = nil;
      if (!recreateTextures) {
        texture = [_constructionToolbarState.toolArchiveTextureStore textureForKey:archiveName];
      }
      if (!texture) {
        NSString *archivePath = [archiveDirectory stringByAppendingPathComponent:archiveFile];
        NSString *archiveDescription = nil;
        NSArray *segmentNodes = [self FL_segmentsReadArchiveWithPath:archivePath description:&archiveDescription links:NULL];
        UIImage *archiveImage = [self FL_segments:segmentNodes createImageWithSize:FLMainToolbarToolArtSize];
        // note: Could put archive textures into the shared texture store for reuse between scenes, which would
        // save a little loading time, but we don't have a good place to store archiveDescription along with the
        // texture.  Rather than add a special interface to HLTextureStore, or create a special static store for
        // FLTrackScene to store just archive descriptions, for now we use a texture store that has the same
        // lifetime as _constructionToolbarState.toolDescriptions.
        [_constructionToolbarState.toolArchiveTextureStore setTextureWithImage:archiveImage forKey:archiveName filteringMode:SKTextureFilteringNearest];
        _constructionToolbarState.toolTypes[archiveName] = @(FLToolbarToolTypeActionPan);
        _constructionToolbarState.toolDescriptions[archiveName] = archiveDescription;
      }
      [archiveTextureKeys addObject:archiveName];
    }
    ++unlockItemIndex;
  }

  // Calculate indexes that will be included in page.
  //
  // note: [begin,end)
  NSUInteger archiveTextureKeysCount = [archiveTextureKeys count];
  NSUInteger pageSize = [self FL_constructionToolbarPageSize];
  NSUInteger beginIndex;
  NSUInteger endIndex;
  [self FL_toolbarGetPageContentBeginIndex:&beginIndex endIndex:&endIndex forPage:page contentCount:archiveTextureKeysCount pageSize:pageSize];

  // Select tools for specified page.
  NSMutableArray *toolNodes = [NSMutableArray array];
  NSMutableArray *toolTags = [NSMutableArray array];
  // note: First "main".
  NSString *textureKey = @"main";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:[HLTextureStore sharedStore]]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  // note: Next "previous".
  if (page != 0) {
    textureKey = @"previous";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:[HLTextureStore sharedStore]]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  }
  // note: The page might end up with no tools if the requested page is too
  // large.  Caller beware.
  for (NSUInteger i = beginIndex; i < endIndex; ++i) {
    textureKey = archiveTextureKeys[i];
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:_constructionToolbarState.toolArchiveTextureStore]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeActionPan);
  }
  if (endIndex < archiveTextureKeysCount) {
    textureKey = @"next";
    [toolTags addObject:textureKey];
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:[HLTextureStore sharedStore]]];
    _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);
  }

  // Set tools.
  [_constructionToolbarState.toolbarNode setTools:toolNodes tags:toolTags animation:animation];
}

- (int)FL_constructionToolbarArchivesPageMax:(NSString *)archiveDirectory
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *archiveFiles = [fileManager contentsOfDirectoryAtPath:archiveDirectory error:nil];
  NSUInteger pageSize = [self FL_constructionToolbarPageSize];
  NSUInteger archiveFilesCount = [archiveFiles count];
  // note: Basic number of archives that can fit on a page is (pageSize - 3), leaving room for a main button,
  // a previous button, and a next button.  But subtract one from the total because first page gets an
  // extra archive button (because no need for previous); subtract one more for the last page (no next);
  // and subtract one more so the integer math gives a zero-indexed result.
  return int((archiveFilesCount - 3) / (pageSize - 3));
}

- (NSUInteger)FL_constructionToolbarPageSize
{
  CGFloat backgroundBorderSize = _constructionToolbarState.toolbarNode.backgroundBorderSize;
  CGFloat squareSeparatorSize = _constructionToolbarState.toolbarNode.squareSeparatorSize;
  CGFloat toolbarHeight = (_interfaceSizeClass == UIUserInterfaceSizeClassCompact ? FLMainToolbarHeightCompact : FLMainToolbarHeightRegular);
  NSUInteger pageSize = (NSUInteger)((_constructionToolbarState.toolbarNode.size.width + squareSeparatorSize - 2.0f * backgroundBorderSize) / (toolbarHeight - 2.0f * backgroundBorderSize + squareSeparatorSize));
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
  HLTextureStore *sharedTextureStore = [HLTextureStore sharedStore];

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
  [selectedToolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  _constructionToolbarState.toolTypes[textureKey] = @(FLToolbarToolTypeNavigation);

  // Next tool is "previous" if not on first page.
  if (page != 0) {
    textureKey = @"previous";
    [selectedToolTags addObject:textureKey];
    [selectedToolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
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
    [selectedToolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
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
  // note: First page has room for an extra tool, so add one to index.
  // (Subtract it out below if we're on the first page.)
  *beginIndex = contentPerMiddlePage * (NSUInteger)page + 1;
  *endIndex = *beginIndex + contentPerMiddlePage;
  if (page == 0) {
    --(*beginIndex);
  }
  // note: Last page has room for an extra tool, so add one if we're
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
  if (_interfaceSizeClass == UIUserInterfaceSizeClassCompact) {
    _simulationToolbarState.toolbarNode.size = CGSizeMake(self.size.width, FLMainToolbarHeightCompact);
  } else {
    _simulationToolbarState.toolbarNode.size = CGSizeMake(self.size.width, FLMainToolbarHeightRegular);
  }
  [self FL_simulationToolbarUpdateTools];
}

- (void)FL_simulationToolbarUpdateTools
{
  HLTextureStore *sharedTextureStore = [HLTextureStore sharedStore];
  NSMutableArray *toolNodes = [NSMutableArray array];
  NSMutableArray *toolTags = [NSMutableArray array];

  NSString *textureKey = @"menu";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];

  if (_simulationRunning) {
    textureKey = @"pause";
  } else {
    textureKey = @"play";
  }
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];

  if (_simulationSpeed <= 1) {
    textureKey = @"ff";
  } else {
    textureKey = @"fff";
  }
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  NSString *speedToolTextureKey = textureKey;

  textureKey = @"center";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];

  textureKey = @"goals";
  [toolTags addObject:textureKey];
  [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];

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
  CGFloat mainToolbarHeight;
  CGFloat trackEditMenuHeight;
  if (_interfaceSizeClass == UIUserInterfaceSizeClassCompact) {
    mainToolbarHeight = FLMainToolbarHeightCompact;
    trackEditMenuHeight = FLTrackEditMenuHeightCompact;
  } else {
    mainToolbarHeight = FLMainToolbarHeightRegular;
    trackEditMenuHeight = FLTrackEditMenuHeightRegular;
  }
  CGFloat y = (FLMessageHeight - self.size.height) / 2.0f
    + mainToolbarHeight
    + FLMessageSpacer
    + trackEditMenuHeight
    + FLTrackEditMenuSpacer;
  _messageNode.position = CGPointMake(0.0f, y);
  _messageNode.size = CGSizeMake(self.size.width, FLMessageHeight);
}

- (void)FL_goalsShowWithSplash:(BOOL)splash
{
  [self timerPause];

  // Always show results if this goals screen is being shown by a command from the
  // user.  Otherwise, only show results if this is an old (loaded or application
  // restored) game.
  BOOL showResults = !splash || !_gameIsNew;

  _goalsNode = [[FLGoalsNode alloc] initWithSceneSize:self.size gameType:_gameType gameLevel:_gameLevel];
  _goalsNode.delegate = self;
  
  [_goalsNode createIntro];

  BOOL victory = NO;
  if (showResults) {
    FLTrackTruthTable *trackTruthTable = trackGridGenerateTruthTable(*_trackGrid, _links, true);
    victory = [_goalsNode createTruthWithTrackTruthTable:trackTruthTable];
    if (victory) {
      NSArray *userUnlocks = FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsVictoryUserUnlocks);
      // note: The unlocks are done here, immediately upon goals showing, and repeatedly upon
      // goals showing.  No big deal.
      FLUserUnlocksUnlock(userUnlocks);
      NSMutableArray *unlockTexts = [NSMutableArray array];
      for (NSString *unlockKey in userUnlocks) {
        NSString *unlockText = [self FL_unlockText:unlockKey];
        if (unlockText) {
          [unlockTexts addObject:unlockText];
        }
      }
      NSArray *recordTexts;
      NSArray *recordNewValues;
      NSArray *recordOldValues;
      NSArray *recordValueFormats;
      [self FL_recordSubmitAll:@[ @(FLRecordSegmentsFewest), @(FLRecordJoinsFewest), @(FLRecordSolutionFastest) ]
                   recordTexts:&recordTexts
                     newValues:&recordNewValues
                     oldValues:&recordOldValues
                  valueFormats:&recordValueFormats];
      [_goalsNode createVictoryWithUnlockTexts:unlockTexts
                                   recordTexts:recordTexts
                               recordNewValues:recordNewValues
                               recordOldValues:recordOldValues
                            recordValueFormats:recordValueFormats];
    }
  }

  [_goalsNode layout];

  [_goalsNode hlSetGestureTarget:_goalsNode];
  [self registerDescendant:_goalsNode withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];

  [self presentModalNode:_goalsNode animation:HLScenePresentationAnimationFade];

  // Do some special animation for victory.
  if (!splash && victory) {
    [_goalsNode reveal];
  }
}

- (void)FL_goalsUpdateGeometry
{
  if (!_goalsNode) {
    return;
  }
  _goalsNode.sceneSize = self.size;
  [_goalsNode layout];
}

- (void)FL_goalsDismissWithNextLevel:(BOOL)nextLevel
{
  if (!_goalsNode) {
    return;
  }
  if (self->_tutorialState.tutorialActive) {
    [self FL_tutorialRecognizedAction:FLTutorialActionGoalsDismissed withArguments:nil];
  }
  [self timerResume];
  [self unregisterDescendant:_goalsNode];
  [self dismissModalNodeAnimation:HLScenePresentationAnimationNone];
  if (nextLevel) {
    id<FLTrackSceneDelegate> delegate = self.trackSceneDelegate;
    if (delegate) {
      // noob: So is this dangerous?  The delegate is probably going to delete this scene.
      // Need to dispatch_async?
      // Got a EXC_BAD_ACCESS here after clicking Next Level button, 11/5/2014.
      // Got a EXC_BAD_ACCESS on _nextLevelMessageNode._backgroundNode.scene after clicking the Next Level button, 12/17/2014
      // (and then rotating device or having view controller try to set geometry on _nextLevelOverlay before it was presented).
      // TODO: A little hard to reproduce the bad access errors; I'm trying something else to fix them,
      // but if they come back then try doing this async as a policy.
      [delegate performSelector:@selector(trackSceneDidTapNextLevelButton:) withObject:self];
    }
  }
  _goalsNode = nil;
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

/**
 * Returns the segment that appears visually closest to the passed world location,
 * or nil for none.
 *
 * In particular: Note that trackGridConvertGet returns the segment in the grid
 * square containing the passed point.  But that result can be very surprising
 * because of the way that segments visually overlap.  For example, consider
 * two grid squares next to each other, both containing a straight track segment
 * centered on the colon (:) but rotated so the track is drawn on the line (|):
 *
 *                 |:|:
 *
 * In this case, a tap on the right-handle line (as it is drawn) might technically
 * be inside the left-hand segment.  This result is not appropriate for most
 * user-interaction.
 *
 * note: Right now the implementation includes SKNode-specific techniques and
 * information outside of the FLTrackGrid.  If, however, we resort to an implementation
 * that relies only on segment type (and rotation) to make decisions about visual
 * closeness, this routine should be pushed down into FLTrackGrid, perhaps called
 * trackGridFindVisualNearest.
 */
- (FLSegmentNode *)FL_trackFindSegmentNearLocation:(CGPoint)worldLocation
{
  // note: This works pretty well as a first pass at implementation.  Perhaps it
  // will be improved in the future.

  NSArray *nodesAtPoint = [_trackNode nodesAtPoint:worldLocation];
  for (SKNode *nodeAtPoint in nodesAtPoint) {
    if (![nodeAtPoint isKindOfClass:[FLSegmentNode class]]) {
      continue;
    }
    FLSegmentNode *segmentNode = (FLSegmentNode *)nodeAtPoint;
    FLSegmentType segmentType = segmentNode.segmentType;
    if (segmentType == FLSegmentTypeStraight
        || segmentType == FLSegmentTypePlatformLeft || segmentType == FLSegmentTypePlatformRight
        || segmentType == FLSegmentTypePlatformStartLeft || segmentType == FLSegmentTypePlatformStartRight) {
      return segmentNode;
    }
  }

  return trackGridConvertGet(*_trackGrid, worldLocation);
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

- (void)FL_exportWithDescription:(NSString *)trackDescription
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
  
  [self FL_segments:_trackSelectState.selectedSegments
writeArchiveWithPath:exportPath
    segmentPointers:_trackSelectState.selectedSegmentPointers
        description:trackDescription];
  
  [self FL_messageShow:[NSString stringWithFormat:NSLocalizedString(@"Exported “%@”.",
                                                                    @"Message to user: Shown after a successful export of {export name}."),
                        trackDescription]];
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
    int pageMax = [self FL_constructionToolbarArchivesPageMax:FLExportsDirectoryPath];
    if (_constructionToolbarState.currentPage > pageMax) {
      _constructionToolbarState.currentPage = pageMax;
    }
    [self FL_constructionToolbarShowExports:_constructionToolbarState.currentPage animation:HLToolbarNodeAnimationNone];
  }
}

- (NSUInteger)FL_deleteSegments:(NSArray *)segmentNodes pointers:(NSSet *)segmentPointers
{
  NSMutableArray *doNotEraseSegments = nil;
  if (_gameType != FLGameTypeSandbox) {
    NSMutableArray *eraseSegments = [NSMutableArray array];
    NSMutableSet *eraseSegmentPointers = [NSMutableSet set];
    doNotEraseSegments = [NSMutableArray array];
    for (FLSegmentNode *segmentNode in segmentNodes) {
      if ([self FL_gameTypeChallengeCanEraseSegment:segmentNode.segmentType]) {
        [eraseSegments addObject:segmentNode];
        [eraseSegmentPointers addObject:[NSValue valueWithPointer:(void *)segmentNode]];
      } else {
        [doNotEraseSegments addObject:segmentNode];
      }
    }
    if ([eraseSegments count] == 0) {
      return 0;
    }
    segmentNodes = eraseSegments;
    segmentPointers = eraseSegmentPointers;
  }
  
  if ([segmentNodes count] > 1) {
    [self FL_deletionsWriteSegments:segmentNodes segmentPointers:segmentPointers];
    _deleteState.dirtyTextures = YES;
  }
  
  [self FL_trackEraseSegments:segmentNodes animated:YES];
  [self FL_trackSelectClear];
  if (doNotEraseSegments && [doNotEraseSegments count] > 0) {
    [self FL_trackSelect:doNotEraseSegments];
    [self FL_trackEditMenuShowAnimated:YES];
  } else {
    [self FL_trackEditMenuHideAnimated:YES];
  }

  return [segmentNodes count];
}

- (void)FL_deletionsWriteSegments:(NSArray *)segmentNodes segmentPointers:(NSSet *)segmentPointers
{
  const int FLDeletionsSlotCount = 5;
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:FLDeletionsDirectoryPath]) {
    [fileManager createDirectoryAtPath:FLDeletionsDirectoryPath withIntermediateDirectories:NO attributes:nil error:NULL];
  }
  
  int useDeletionSlot = 0;
  for (int d = 0; d <= FLDeletionsSlotCount; ++d) {
    NSString *deletionSlotName = [NSString stringWithFormat:@"track-erase-%d", d];
    NSString *deletionSlotPath = [FLDeletionsDirectoryPath stringByAppendingPathComponent:[deletionSlotName stringByAppendingPathExtension:@"archive"]];
    if (![fileManager fileExistsAtPath:deletionSlotPath]) {
      useDeletionSlot = d;
      break;
    }
  }
  
  int purgeDeletionSlot = useDeletionSlot + 1;
  if (purgeDeletionSlot > FLDeletionsSlotCount) {
    purgeDeletionSlot = 0;
  }
  NSString *purgeDeletionSlotName = [NSString stringWithFormat:@"track-erase-%d", purgeDeletionSlot];
  NSString *purgeDeletionSlotPath = [FLDeletionsDirectoryPath stringByAppendingPathComponent:[purgeDeletionSlotName stringByAppendingPathExtension:@"archive"]];
  [fileManager removeItemAtPath:purgeDeletionSlotPath error:NULL];
  
  static NSDateFormatter *dateFormatter = nil;
  if (!dateFormatter) {
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
  }
  NSString *trackDescription = [dateFormatter stringFromDate:[NSDate date]];
  NSString *useDeletionSlotName = [NSString stringWithFormat:@"track-erase-%d", useDeletionSlot];
  NSString *useDeletionSlotPath = [FLDeletionsDirectoryPath stringByAppendingPathComponent:[useDeletionSlotName stringByAppendingPathExtension:@"archive"]];
  [self FL_segments:segmentNodes writeArchiveWithPath:useDeletionSlotPath segmentPointers:segmentPointers description:trackDescription];
}

- (void)FL_trackSelect:(NSArray *)segmentNodes
{
  if (!_trackSelectState.visualParentNode) {
    _trackSelectState.visualParentNode = [SKNode node];
    _trackSelectState.visualParentNode.zPosition = FLZPositionWorldSelectBelow;

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
      if (segmentNode.segmentType != FLSegmentTypePixel) {
        selectionSquare = [SKSpriteNode spriteNodeWithColor:[SKColor colorWithWhite:0.2f alpha:1.0f]
                                                       size:CGSizeMake(FLSegmentArtSizeBasic * FLTrackArtScale,
                                                                       FLSegmentArtSizeBasic * FLTrackArtScale)];
        selectionSquare.blendMode = SKBlendModeAdd;
      } else {
        selectionSquare = [SKSpriteNode spriteNodeWithColor:[SKColor colorWithWhite:0.5f alpha:0.6f]
                                                       size:CGSizeMake(FLSegmentArtSizeBasic * FLTrackArtScale,
                                                                       FLSegmentArtSizeBasic * FLTrackArtScale)];
        selectionSquare.blendMode = SKBlendModeAlpha;
        selectionSquare.zPosition = FLZPositionWorldSelectAbove - _trackSelectState.visualParentNode.zPosition;
      }
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
    NSEnumerator *selectionSquareEnumerator = [_trackSelectState.visualSquareNodes objectEnumerator];
    SKSpriteNode *selectionSquare;
    while ((selectionSquare = [selectionSquareEnumerator nextObject])) {
      [selectionSquare removeFromParent];
    }
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
  FLSegmentNode *segmentNode = [self FL_trackFindSegmentNearLocation:worldLocation];
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

  FLSegmentNode *segmentNode = [self FL_trackFindSegmentNearLocation:worldLocation];
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
  if (segmentNode.segmentType != FLSegmentTypePixel) {
    conflictNode.zPosition = FLZPositionWorldSelectBelow;
  } else {
    conflictNode.zPosition = FLZPositionWorldSelectAbove;
  }
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
  return placedSegmentNodes;
}

- (NSArray *)FL_trackMoveEndedCommonWithLocation:(CGPoint)worldLocation
{
  // noob: Does the platform guarantee this behavior already, to wit, that an "ended" call
  // with a certain location will always be preceeded by a "moved" call at that same
  // location?
  [self FL_trackMoveUpdateWithLocation:worldLocation];

  [self FL_trackConflictClear];

  if (_trackMoveState.completion) {
    _trackMoveState.completion(_trackMoveState.placed);
  }

  [self FL_trackEditMenuUpdateAnimated:YES];

  NSArray *placedSegmentNodes = nil;
  if (_trackMoveState.placed) {
    placedSegmentNodes = _trackMoveState.segmentNodes;
  }

  [_trackMoveState.cursorNode removeAllChildren];
  [_trackMoveState.cursorNode removeFromParent];

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
    [self FL_linkRedrawForSegment:segmentNode];
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
    _trackEditMenuState.editMenuNode.anchorPoint = CGPointMake(0.5f, 0.0f);
    _trackEditMenuState.editMenuNode.backgroundBorderSize = FLTrackEditMenuBackgroundBorderSize;
    _trackEditMenuState.editMenuNode.squareSeparatorSize = FLTrackEditMenuSquareSeparatorSize;
    _trackEditMenuState.editMenuNode.backgroundColor = [SKColor colorWithWhite:0.8f alpha:0.6f];
    _trackEditMenuState.editMenuNode.squareColor = [SKColor colorWithWhite:0.2f alpha:0.5f];
    [self FL_trackEditMenuUpdateGeometry];
  } else {
    [self FL_trackEditMenuUpdateTools];
  }

  // Show menu.
  if (!_trackEditMenuState.showing) {
    // note: Track menu might still be in the process of animating hidden; in that case (and
    // only that case), the node will have a parent even though it's not .showing.  The animation
    // does not need to be explicitly canceled; showWithOrigin:finalPosition:fullScale:animated:
    // doesn't assume the hide animation has been completed.
    if (!_trackEditMenuState.editMenuNode.parent) {
      [_hudNode addChild:_trackEditMenuState.editMenuNode];
    }
    _trackEditMenuState.showing = YES;
  }
  [_trackEditMenuState.editMenuNode showWithOrigin:_trackEditMenuState.editMenuNode.position
                                     finalPosition:_trackEditMenuState.editMenuNode.position
                                         fullScale:1.0f
                                          animated:animated];
}

- (void)FL_trackEditMenuUpdateGeometry
{
  _trackEditMenuState.editMenuNode.automaticWidth = YES;
  _trackEditMenuState.editMenuNode.automaticHeight = NO;
  if (_interfaceSizeClass == UIUserInterfaceSizeClassCompact) {
    _trackEditMenuState.editMenuNode.size = CGSizeMake(0.0f, FLTrackEditMenuHeightCompact);
    _trackEditMenuState.editMenuNode.position = CGPointMake(0.0f,
                                                            - self.size.height / 2.0f + FLMainToolbarHeightCompact + FLTrackEditMenuSpacer);
  } else {
    _trackEditMenuState.editMenuNode.size = CGSizeMake(0.0f, FLTrackEditMenuHeightRegular);
    _trackEditMenuState.editMenuNode.position = CGPointMake(0.0f,
                                                            - self.size.height / 2.0f + FLMainToolbarHeightRegular + FLTrackEditMenuSpacer);
  }
  [_trackEditMenuState.editMenuNode showUpdateOrigin:_trackEditMenuState.editMenuNode.position];
  [self FL_trackEditMenuUpdateTools];
}

- (void)FL_trackEditMenuUpdateTools
{
  HLTextureStore *sharedTextureStore = [HLTextureStore sharedStore];

  // Collect information about selected segments.
  NSArray *segmentNodes = _trackSelectState.selectedSegments;
  BOOL canSwitchAny;
  BOOL hidesSwitchAll;
  BOOL canLabelAny;
  BOOL canDeleteAny;
  BOOL canFlipAny;
  [self FL_trackEditMenuGetTraitsForSegments:segmentNodes
                                canSwitchAny:&canSwitchAny
                              hidesSwitchAll:&hidesSwitchAll
                                 canLabelAny:&canLabelAny
                                canDeleteAny:&canDeleteAny
                                  canFlipAny:&canFlipAny];
  
  // Update tools.
  NSMutableArray *textureKeys = [NSMutableArray array];
  [textureKeys addObject:@"rotate-ccw"];
  if (canSwitchAny) {
    [textureKeys addObject:@"toggle-switch"];
  }
  if (canLabelAny) {
    [textureKeys addObject:@"set-label"];
  }
  [textureKeys addObject:@"export"];
  [textureKeys addObject:@"delete"];
  if (canFlipAny) {
    [textureKeys addObject:@"flip-horizontal"];
    [textureKeys addObject:@"flip-vertical"];
  }
  [textureKeys addObject:@"rotate-cw"];
  NSMutableArray *toolNodes = [NSMutableArray array];
  for (NSString *textureKey in textureKeys) {
    [toolNodes addObject:[self FL_createToolNodeForTextureKey:textureKey textureStore:sharedTextureStore]];
  }
  [_trackEditMenuState.editMenuNode setTools:toolNodes tags:textureKeys animation:HLToolbarNodeAnimationNone];
  if (canSwitchAny) {
    [_trackEditMenuState.editMenuNode setEnabled:(!hidesSwitchAll) forTool:@"toggle-switch"];
  }
  [_trackEditMenuState.editMenuNode setEnabled:canDeleteAny forTool:@"delete"];
}

- (void)FL_trackEditMenuGetTraitsForSegments:(NSArray *)segmentNodes
                                canSwitchAny:(BOOL *)canSwitchAny
                              hidesSwitchAll:(BOOL *)hidesSwitchAll
                                 canLabelAny:(BOOL *)canLabelAny
                                canDeleteAny:(BOOL *)canDeleteAny
                                  canFlipAny:(BOOL *)canFlipAny
{
  *canSwitchAny = NO;
  *hidesSwitchAll = YES;
  for (FLSegmentNode *segmentNode in segmentNodes) {
    if ([segmentNode canSwitch]) {
      *canSwitchAny = YES;
      if (![self FL_segmentCanHideSwitch:segmentNode.segmentType]
          || segmentNode.mayShowSwitch) {
        *hidesSwitchAll = NO;
        break;
      }
    }
  }
  *canLabelAny = (_gameType == FLGameTypeSandbox);
  *canDeleteAny = NO;
  if (_gameType == FLGameTypeSandbox) {
    *canDeleteAny = YES;
  } else {
    for (FLSegmentNode *segmentNode in segmentNodes) {
      if ([self FL_gameTypeChallengeCanEraseSegment:segmentNode.segmentType]) {
        *canDeleteAny = YES;
        break;
      }
    }
  }
  *canFlipAny = NO;
  for (FLSegmentNode *segmentNode in segmentNodes) {
    if ([segmentNode canFlip]) {
      *canFlipAny = YES;
      break;
    }
  }
}

- (void)FL_trackEditMenuHideAnimated:(BOOL)animated
{
  if (!_trackEditMenuState.showing) {
    return;
  }
  _trackEditMenuState.showing = NO;
  [_trackEditMenuState.editMenuNode hideAnimated:animated];
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
    SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:segmentNode.switchLinkLocation toLocation:link.switchLinkLocation linkErase:NO];
    _links.set(segmentNode, link, connectorNode);
  }
}

- (void)FL_linkHideForSegment:(FLSegmentNode *)segmentNode
{
  // note: FL_linkRedrawForSegment will be called for this segmentNode soon, but in the meantime
  // we want the link connectorNodes hidden.  Not deleted; just hidden.  Could use SKNode's hidden,
  // or alpha, or something else, but instead remove from parent and try to fix up other places
  // where it is assumed the connectorNode is always added to parent.
  vector<FLSegmentNode *> links;
  _links.get(segmentNode, &links);
  for (auto link : links) {
    SKShapeNode *connectorNode = _links.get(segmentNode, link);
    [connectorNode removeFromParent];
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
  if (endNode && endNode != _linkEditState.beginNode && [endNode canSwitch]) {
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
  CGPoint beginSwitchLocation = _linkEditState.beginNode.switchLinkLocation;
  CGPoint endSwitchLocation;
  BOOL linkErase;
  if (_linkEditState.endNode) {
    endSwitchLocation = _linkEditState.endNode.switchLinkLocation;
    linkErase = (_links.get(_linkEditState.beginNode, _linkEditState.endNode) != nil);
  } else {
    endSwitchLocation = worldLocation;
    linkErase = NO;
  }
  SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:beginSwitchLocation toLocation:endSwitchLocation linkErase:linkErase];
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
      if (!segmentNode || !segmentNode.canSwitch) {
        continue;
      }
      // note: This is slightly debatable; maybe want to have a node linked even if the switch
      // is hidden.
      if ([self FL_segmentCanHideSwitch:segmentNode.segmentType] && !segmentNode.mayShowSwitch) {
        continue;
      }
      CGPoint switchLocation = segmentNode.switchLinkLocation;
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
  const CGFloat FLLinkSwitchFindDistanceMax = FLTrackSegmentSize * 0.9f;
  if (!closestSegmentNode || closestDistanceSquared > FLLinkSwitchFindDistanceMax * FLLinkSwitchFindDistanceMax) {
    return nil;
  } else {
    return closestSegmentNode;
  }
}

- (BOOL)FL_linksToggle
{
  if (_linksVisible) {
    [self FL_linksHide];
    return NO;
  } else {
    [self FL_linksShow];
    return YES;
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

- (BOOL)FL_labelsToggle
{
  _labelsVisible = !_labelsVisible;
  [_constructionToolbarState.toolbarNode setHighlight:_labelsVisible forTool:@"show-labels"];
  for (auto s : *_trackGrid) {
    FLSegmentNode *segmentNode = s.second;
    segmentNode.mayShowLabel = _labelsVisible;
  }
  return _labelsVisible;
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
                                                        anchorPoint:CGPointMake(0.5f, 0.5f)
                                                         layoutMode:HLGridNodeLayoutModeFill
                                                         squareSize:CGSizeMake(squareEdgeSize, squareEdgeSize)
                                               backgroundBorderSize:5.0f
                                                squareSeparatorSize:1.0f];
    [_labelState.labelPicker hlSetGestureTarget:_labelState.labelPicker];
    _labelState.labelPicker.backgroundColor = FLInterfaceColorDark();
    _labelState.labelPicker.squareColor = FLInterfaceColorMedium();
    _labelState.labelPicker.highlightColor = FLInterfaceColorLight();
    _labelState.labelPicker.content = letterNodes;
    // note: Could easily store references to segmentNodes in the block for each invocation,
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

    _labelState.backdropNode = [SKSpriteNode spriteNodeWithColor:[SKColor clearColor] size:self.size];
    [_labelState.backdropNode hlSetGestureTarget:[HLTapGestureTarget tapGestureTargetWithHandleGestureBlock:^(UIGestureRecognizer *gestureRecognizer){
      [self FL_labelPicked:-1];
    }]];
    [self registerDescendant:_labelState.backdropNode withOptions:[NSSet setWithObjects:HLSceneChildGestureTarget, HLSceneChildResizeWithScene, nil]];
    [_labelState.backdropNode addChild:_labelState.labelPicker];
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
  [self presentModalNode:_labelState.backdropNode animation:HLScenePresentationAnimationFade];
}

- (void)FL_labelPicked:(int)squareIndex
{
  if (squareIndex >= 0) {
    [_labelState.labelPicker setSelectionForSquare:squareIndex];
    for (FLSegmentNode *segmentNode in _labelState.segmentNodesToBeLabeled) {
      segmentNode.label = FLLabelPickerLabels[squareIndex];
    }
  }
  _labelState.segmentNodesToBeLabeled = nil;
  [self dismissModalNodeAnimation:HLScenePresentationAnimationFade];
}

- (BOOL)FL_valuesToggle
{
  _valuesVisible = !_valuesVisible;
  [_constructionToolbarState.toolbarNode setHighlight:_valuesVisible forTool:@"show-values"];
  for (auto s : *_trackGrid) {
    FLSegmentNode *segmentNode = s.second;
    if (![self FL_segmentCanHideSwitch:segmentNode.segmentType] || segmentNode.mayShowSwitch) {
      segmentNode.mayShowBubble = _valuesVisible;
    }
  }
  return _valuesVisible;
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
    [self FL_linkHideForSegment:segmentNode];
    segmentNode.mayShowLabel = NO;
    segmentNode.mayShowBubble = NO;
    [segmentNode runAction:[SKAction rotateToAngle:(newRotationQuarters * (CGFloat)M_PI_2) duration:FLTrackRotateDuration shortestUnitArc:YES] completion:^{
      [self FL_linkRedrawForSegment:segmentNode];
      segmentNode.mayShowLabel = self->_labelsVisible;
      segmentNode.mayShowBubble = self->_valuesVisible;
    }];
    [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-click-1.caf" waitForCompletion:NO]];
  }
}

- (void)FL_trackRotateSegments:(NSArray *)segmentNodes pointers:(NSSet *)segmentNodePointers rotateBy:(int)rotateBy animated:(BOOL)animated
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
  };

  // Rotate.
  if (animated) {

    [self FL_trackSelectClear];

    // Copy segments into a temporary parent node.
    SKNode *rotateNode = [SKNode node];
    [_trackNode addChild:rotateNode];
    for (FLSegmentNode *segmentNode in segmentNodes) {
      [segmentNode removeFromParent];
      // noob: Unless I make a copy, something gets screwed up with my segmentNodes: They end up
      // with a null self.scene, and the coordinate conversions (e.g. by the segmentNode's
      // switchLinkLocation method, trying to use [self.parent convert*]) give bogus results in
      // some circumstances (e.g. in the completion block of the rotation action, below).  This
      // copying business is a workaround, but it seems low-impact, so I'm not pursuing it further
      // for now.
      FLSegmentNode *segmentNodeCopy = [segmentNode copy];
      segmentNodeCopy.position = CGPointMake(segmentNode.position.x - pivot.x, segmentNode.position.y - pivot.y);
      [rotateNode addChild:segmentNodeCopy];
      [self FL_linkHideForSegment:segmentNode];
      segmentNodeCopy.mayShowLabel = NO;
      segmentNodeCopy.mayShowBubble = NO;
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

- (void)FL_trackFlipSegment:(FLSegmentNode *)segmentNode direction:(FLSegmentFlipDirection)direction
{
  [segmentNode flip:direction];
  [self FL_linkRedrawForSegment:segmentNode];
  [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-click-1.caf" waitForCompletion:NO]];
}

- (void)FL_trackFlipSegments:(NSArray *)segmentNodes
                    pointers:(NSSet *)segmentNodePointers
                   direction:(FLSegmentFlipDirection)direction
{
  if ([segmentNodes count] == 1) {
    [self FL_trackFlipSegment:[segmentNodes firstObject] direction:direction];
    return;
  }

  // Collect information about segments.
  CGFloat segmentsPositionLeft;
  CGFloat segmentsPositionRight;
  CGFloat segmentsPositionTop;
  CGFloat segmentsPositionBottom;
  [self FL_segments:segmentNodes getExtremesLeft:&segmentsPositionLeft right:&segmentsPositionRight top:&segmentsPositionTop bottom:&segmentsPositionBottom];

  // Check proposed flip for conflicts.
  BOOL hasConflict = NO;
  for (FLSegmentNode *segmentNode in segmentNodes) {
    CGPoint finalPosition;
    if (direction == FLSegmentFlipHorizontal) {
      finalPosition.x = segmentsPositionLeft + segmentsPositionRight - segmentNode.position.x;
      finalPosition.y = segmentNode.position.y;
    } else {
      finalPosition.x = segmentNode.position.x;
      finalPosition.y = segmentsPositionBottom + segmentsPositionTop - segmentNode.position.y;
    }
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

  // Flip.
  for (FLSegmentNode *segmentNode in segmentNodes) {
    trackGridConvertErase(*(self->_trackGrid), segmentNode.position);
  }
  for (FLSegmentNode *segmentNode in segmentNodes) {
    CGPoint finalPosition;
    if (direction == FLSegmentFlipHorizontal) {
      finalPosition.x = segmentsPositionLeft + segmentsPositionRight - segmentNode.position.x;
      finalPosition.y = segmentNode.position.y;
    } else {
      finalPosition.x = segmentNode.position.x;
      finalPosition.y = segmentsPositionBottom + segmentsPositionTop - segmentNode.position.y;
    }
    segmentNode.position = finalPosition;
    [segmentNode flip:direction];
    trackGridConvertSet(*(self->_trackGrid), segmentNode.position, segmentNode);
  }
  for (FLSegmentNode *segmentNode in segmentNodes) {
    [self FL_linkRedrawForSegment:segmentNode];
  }
  [self FL_trackSelect:segmentNodes];

  [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-click-1.caf" waitForCompletion:NO]];
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
    NSTimeInterval sleeperParticleLifetimeMax = sleeperDestruction.particleLifetime + sleeperDestruction.particleLifetimeRange / 2.0f;
    [sleeperDestruction runAction:[SKAction waitForDuration:sleeperParticleLifetimeMax] completion:^{
      [sleeperDestruction removeFromParent];
    }];
    NSTimeInterval railParticleLifetimeMax = railDestruction.particleLifetime + railDestruction.particleLifetimeRange / 2.0f;
    [railDestruction runAction:[SKAction waitForDuration:railParticleLifetimeMax] completion:^{
      [railDestruction removeFromParent];
    }];
  }
  trackGridConvertErase(*_trackGrid, segmentNode.position);
  _links.erase(segmentNode);
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
        return FLUserUnlocksUnlocked(@"FLUserUnlockCircuitHalfAdder");
      case FLUnlockCircuitFullAdder:
        return FLUserUnlocksUnlocked(@"FLUserUnlockCircuitFullAdder");
      default:
        [NSException raise:@"FLUnlockItemUnknown" format:@"Unknown unlock item %ld.", (long)item];
    }
  }
  return NO;
}

- (NSString *)FL_unlockText:(NSString *)unlockKey
{
  if ([unlockKey hasPrefix:@"FLUserUnlockLevel"]) {
    // commented out: This unlock isn't generally worth telling the user about.  Return nil instead.
    //NSString *gameLevel = [unlockKey substringFromIndex:17];
    //return [NSString stringWithFormat:NSLocalizedString(@"Unlocked: Level %@",
    //                                                    @"Game information: displayed when a new challenge level (with {level number}) is unlocked by successfully completing a level."),
    //        gameLevel];
    return nil;
  } else if ([unlockKey isEqualToString:@"FLUserUnlockGateNot"]) {
    return NSLocalizedString(@"NOT Gate",
                             @"Game information: displayed when the NOT gate is unlocked by successfully completing a level.");
  } else if ([unlockKey isEqualToString:@"FLUserUnlockGateAnd"]) {
    return NSLocalizedString(@"AND Gate",
                             @"Game information: displayed when the AND gate is unlocked by successfully completing a level.");
  } else if ([unlockKey isEqualToString:@"FLUserUnlockGateOr"]) {
    return NSLocalizedString(@"OR Gate",
                             @"Game information: displayed when the OR gate is unlocked by successfully completing a level.");
  } else if ([unlockKey isEqualToString:@"FLUserUnlockGateXor"]) {
    return NSLocalizedString(@"XOR Gate",
                             @"Game information: displayed when the XOR gate is unlocked by successfully completing a level.");
  } else if ([unlockKey isEqualToString:@"FLUserUnlockCircuitXor"]) {
    return NSLocalizedString(@"XOR Circuit: “The Rocket”",
                             @"Game information: displayed when the XOR circuit (“The Rocket”) is unlocked by successfully completing a level.");
  } else if ([unlockKey isEqualToString:@"FLUserUnlockCircuitHalfAdder"]) {
    return NSLocalizedString(@"Half Adder Circuit",
                             @"Game information: displayed when the half adder circuit is unlocked by successfully completing a level.");
  } else if ([unlockKey isEqualToString:@"FLUserUnlockCircuitFullAdder"]) {
    return NSLocalizedString(@"Full Adder Circuit",
                             @"Game information: displayed when the full adder circuit is unlocked by successfully completing a level.");
  }
  [NSException raise:@"FLUnlockTextUnknownUnlockKey" format:@"Missing unlock text for unlock key '%@'.", unlockKey];
  return nil;
}

- (void)FL_recordSubmitAll:(NSArray *)recordItems
               recordTexts:(NSArray * __autoreleasing *)recordTexts
                 newValues:(NSArray * __autoreleasing *)newValues
                 oldValues:(NSArray * __autoreleasing *)oldValues
              valueFormats:(NSArray * __autoreleasing *)valueFormats
{
  NSMutableArray *mutableRecordTexts = [NSMutableArray array];
  NSMutableArray *mutableNewValues = [NSMutableArray array];
  NSMutableArray *mutableOldValues = [NSMutableArray array];
  NSMutableArray *mutableValueFormats = [NSMutableArray array];
  for (NSNumber *ri in recordItems) {
    FLRecordItem recordItem = (FLRecordItem)[ri integerValue];
    NSString *recordText;
    NSInteger newValue;
    NSNumber *oldValue;
    FLGoalsNodeRecordFormat valueFormat;
    if ([self FL_recordSubmit:recordItem text:&recordText newValue:&newValue oldValue:&oldValue valueFormat:&valueFormat]) {
      [mutableRecordTexts addObject:recordText];
      [mutableNewValues addObject:@(newValue)];
      if (oldValue) {
        [mutableOldValues addObject:oldValue];
      } else {
        [mutableOldValues addObject:[NSNull null]];
      }
      [mutableValueFormats addObject:@(valueFormat)];
    }
  }
  *recordTexts = mutableRecordTexts;
  *newValues = mutableNewValues;
  *oldValues = mutableOldValues;
  *valueFormats = mutableValueFormats;
}

- (BOOL)FL_recordSubmit:(FLRecordItem)recordItem
                   text:(NSString * __autoreleasing *)recordText
               newValue:(NSInteger *)newValue
               oldValue:(NSNumber * __autoreleasing *)oldValue
            valueFormat:(FLGoalsNodeRecordFormat *)valueFormat
{
  BOOL returnValue = NO;
  
  NSString *recordKey = nil;
  switch (recordItem) {
    case FLRecordSegmentsFewest:
      recordKey = @"FLUserRecordSegmentsFewest";
      *newValue = (NSInteger)self.regularSegmentCount;
      *recordText = NSLocalizedString(@"Fewest Segments:",
                                      @"Game information: description of the record for solving a level using the fewest segments.");
      *valueFormat = FLGoalsNodeRecordFormatInteger;
      break;
    case FLRecordJoinsFewest:
      recordKey = @"FLUserRecordJoinsFewest";
      *newValue = (NSInteger)self.joinSegmentCount;
      *recordText = NSLocalizedString(@"Fewest Joins:",
                                      @"Game information: description of the record for solving a level using the fewest join segments.");
      *valueFormat = FLGoalsNodeRecordFormatInteger;
      break;
    case FLRecordSolutionFastest:
      recordKey = @"FLUserRecordSolutionFastest";
      *newValue = (NSInteger)[self timerGet];
      *recordText = NSLocalizedString(@"Fastest Solution:",
                                      @"Game information: description of the record for solving a level in the least amount of time.");
      *valueFormat = FLGoalsNodeRecordFormatHourMinuteSecond;
      break;
    default:
      [NSException raise:@"FLRecordSubmitUnknownItem" format:@"Unknown record item %ld.", (long)recordItem];
  }

  // Get current record (used in a couple places below).
  NSNumber *currentRecord = (NSNumber *)FLUserRecordsLevelGet(recordKey, _gameLevel);

  // Get the old record value, if any.
  //
  // note: If we beat the record, then we'll submit it as the new record.
  // However, until the user goes to the next level, we'd still like to
  // keep reporting the same "you beat the old record" value.  So cache
  // the original record -- or cache the fact that there was no record --
  // and keep re-using it.
  NSNumber *cachedRecord = _recordState.cachedRecords[@(recordItem)];
  id testRecord;
  if (cachedRecord) {
    testRecord = cachedRecord;
  } else if (currentRecord) {
    testRecord = currentRecord;
    _recordState.cachedRecords[@(recordItem)] = currentRecord;
  } else {
    testRecord = [NSNull null];
    _recordState.cachedRecords[@(recordItem)] = [NSNull null];
  }
  // note: If no old record, then load a default (which weeds out the records
  // that are not so impressive).
  NSInteger testValue;
  if (testRecord != [NSNull null]) {
    testValue = [testRecord integerValue];
    *oldValue = testRecord;
  } else {
    NSDictionary *recordDefaults = FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsRecordDefaults);
    NSNumber *defaultRecord = recordDefaults[recordKey];
    if (!defaultRecord) {
      [NSException raise:@"FLRecordSubmitMissingDefaultRecord" format:@"Missing default record for %@ on game level %d.", recordKey, _gameLevel];
    }
    testValue = [defaultRecord integerValue];
    *oldValue = nil;
  }

  // Test new record.
  if (*newValue < testValue) {
    returnValue = YES;
  }

  // Submit new record.
  //
  // note: Depending on how things are implemented, it's possible that another
  // game will have submitted a better record during the time we've cached an
  // old record.  So check before subitting, so that we don't accidentally
  // overwrite a better record.
  if (!currentRecord || *newValue < [currentRecord integerValue]) {
    NSNumber *newRecord = [NSNumber numberWithInteger:*newValue];
    FLUserRecordsLevelSet(recordKey, _gameLevel, newRecord);
  }

  return returnValue;
}

- (BOOL)FL_gameTypeChallengeCanEraseSegment:(FLSegmentType)segmentType
{
  // note: If this ends up getting specified per-level, then should put it into the
  // game information plist.  Also, game type logic is scattered around right now,
  // but could make a general system for it like FL_unlocked, where certain named
  // permissions are routed through a single FL_allowed or FL_included or
  // something method.
  return (segmentType != FLSegmentTypeReadoutInput
          && segmentType != FLSegmentTypeReadoutOutput
          && segmentType != FLSegmentTypePlatformStartLeft
          && segmentType != FLSegmentTypePlatformStartRight);
}

- (BOOL)FL_gameTypeChallengeCanCreateSegment:(FLSegmentType)segmentType
{
  return (segmentType != FLSegmentTypeReadoutInput
          && segmentType != FLSegmentTypeReadoutOutput
          && segmentType != FLSegmentTypePlatformStartLeft
          && segmentType != FLSegmentTypePlatformStartRight
          && segmentType != FLSegmentTypePixel);
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

- (void)FL_tutorialCreateStepWithLabel:(NSString *)label annotation:(NSString *)annotation
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
  backdropNode.zPosition = FLZPositionTutorial + FLZPositionTutorialBackdrop;

  DSMultilineLabelNode *labelNode = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  labelNode.zPosition = FLZPositionTutorialContent;
  labelNode.fontSize = 20.0f;
  labelNode.fontColor = [SKColor whiteColor];
  labelNode.text = label;
  // note: Adding a little extra padding to the sides of the text.  Maybe this should be for all paragraphs,
  // but for now it makes sense to me that tutorial messages are supposed to be especially padded.
  const CGFloat FLTutorialLabelPad = 10.0f;
  CGFloat edgeSizeMax = MIN(MIN(sceneSize.width, sceneSize.height) - FLTutorialLabelPad, FLDSMultilineLabelParagraphWidthReadableMax);
  labelNode.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
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

  if (annotation) {
    DSMultilineLabelNode *annotationNode = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    annotationNode.zPosition = FLZPositionTutorialContent;
    annotationNode.fontSize = 14.0f;
    annotationNode.fontColor = FLInterfaceColorLight();
    annotationNode.text = annotation;
    annotationNode.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
    if (_tutorialState.labelPosition == FLTutorialLabelLowerScene) {
      annotationNode.position = CGPointMake(0.0f, labelNode.position.y - (labelNode.size.height + annotationNode.size.height) / 2.0f - FLTutorialLabelPad);
    } else {
      annotationNode.position = CGPointMake(0.0f, -self.size.height / 5.0f);
    }
    [backdropNode addChild:annotationNode];
  }
}

- (void)FL_tutorialShowWithLabel:(NSString *)label
                      annotation:(NSString *)annotation
                   firstPanWorld:(BOOL)firstPanWorld
                     panLocation:(CGPoint)panSceneLocation
                        animated:(BOOL)animated
{
  void (^showBackdrop)(void) = ^{
    // note: Put the creation step in this block so that it happens after the optional firstPanWorld;
    // that ensures the scene locations of the cutouts are converted properly.
    [self FL_tutorialCreateStepWithLabel:label annotation:annotation];
    SKSpriteNode *backdropNode = self->_tutorialState.backdropNode;
    [self addChild:backdropNode];
    if (animated) {
      NSArray *backdropChildrenNodes = backdropNode.children;
      backdropNode.alpha = 0.0f;
      [backdropChildrenNodes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
        [obj setAlpha:0.0f];
      }];
      [backdropNode runAction:[SKAction fadeInWithDuration:FLTutorialStepFadeDuration] completion:^{
        [backdropChildrenNodes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
          [obj runAction:[SKAction fadeInWithDuration:FLTutorialStepFadeDuration]];
        }];
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
                      annotation:nil
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
    [backdropNode runAction:[SKAction fadeOutWithDuration:FLTutorialStepFadeDuration] completion:^{
      [backdropNode removeFromParent];
    }];
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
      NSString *annotation = NSLocalizedString(@"Long-press to skip tutorial.",
                                               @"Tutorial message.");
      _tutorialState.cutouts.emplace_back(_train, [[HLTextureStore sharedStore] imageForKey:@"engine"], NO);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      CGPoint panSceneLocation = [self convertPoint:_train.position fromNode:_worldNode];
      [self FL_tutorialShowWithLabel:label annotation:annotation firstPanWorld:YES panLocation:panSceneLocation animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropLongPress, FLTutorialResultExit);
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
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropLongPress, FLTutorialResultExit);
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
      [self FL_tutorialShowWithLabel:label annotation:nil firstPanWorld:YES panLocation:panSceneLocation animated:YES];
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
      [self FL_tutorialShowWithLabel:label annotation:nil firstPanWorld:YES panLocation:panSceneLocation animated:animated];
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
      _tutorialState.cutouts.emplace_back(segmentNode, [[HLTextureStore sharedStore] imageForKey:@"platform-start-left"], NO);
      _tutorialState.labelPosition = FLTutorialLabelAboveCutouts;
      CGPoint panSceneLocation = [self convertPoint:segmentNode.position fromNode:_trackNode];
      [self FL_tutorialShowWithLabel:label annotation:nil firstPanWorld:YES panLocation:panSceneLocation animated:animated];
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
      [self FL_tutorialShowWithLabel:label annotation:nil firstPanWorld:YES panLocation:panSceneLocation animated:animated];
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
      [self FL_tutorialShowWithLabel:label annotation:nil firstPanWorld:YES panLocation:panSceneLocation animated:animated];
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
      NSString *label = NSLocalizedString(@"The switch flips as Flippy travels over it.",
                                          @"Tutorial message.");
      NSString *annotation = NSLocalizedString(@"Tap to continue, or long-press to watch again.",
                                               @"Tutorial message.");
      _tutorialState.labelPosition = FLTutorialLabelLowerScene;
      [self FL_tutorialShowWithLabel:label annotation:annotation firstPanWorld:NO panLocation:CGPointZero animated:animated];
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
      [self timerReset];
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
      NSString *annotation = NSLocalizedString(@"Long-press to skip tutorial.",
                                               @"Tutorial message.");
      [self FL_tutorialShowWithLabel:label annotation:annotation firstPanWorld:NO panLocation:CGPointZero animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropLongPress, FLTutorialResultExit);
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
      [self FL_tutorialShowWithLabel:label annotation:nil firstPanWorld:YES panLocation:panSceneLocation animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropLongPress, FLTutorialResultExit);
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
      [self FL_tutorialShowWithLabel:label annotation:nil firstPanWorld:YES panLocation:panSceneLocation animated:animated];
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
      NSString *label = NSLocalizedString(@"That’s all for this tutorial. Have fun!",
                                          @"Tutorial message.");
      [self FL_tutorialShowWithLabel:label animated:animated];
      _tutorialState.conditions.emplace_back(FLTutorialActionBackdropTap, FLTutorialResultContinue);
      [self timerReset];
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

  if ((results & FLTutorialResultExit) != 0) {
    [self timerReset];
    dispatch_async(dispatch_get_main_queue(), ^{
      // note: Must advance step to the end of the tutorial, in case someone resets the
      // tutorial; we can't resume tutorial in this level once things have been moved around.
      self->_tutorialState.step = INT_MAX;
      [self FL_tutorialStepAnimated:YES];
    });
  }

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
      NSLog(@"tutorial continue");
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
