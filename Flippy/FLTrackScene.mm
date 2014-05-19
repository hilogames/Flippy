//
//  FLTrackScene.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLTrackScene.h"

#include <HLSpriteKit/HLTextureStore.h>
#include <memory>
#include <tgmath.h>

#include "FLLinks.h"
#import "FLPath.h"
#import "FLSegmentNode.h"
#include "FLTrackGrid.h"
#import <HLSpriteKit/HLToolbarNode.h>

using namespace std;
using namespace HLCommon;

static const CGFloat FLWorldScaleMin = 0.125f;
static const CGFloat FLWorldScaleMax = 2.0f;
static const CGSize FLWorldSize = { 3000.0f, 3000.0f };

// note: The art scale is used within the track layer to intentionally pixelate
// the art for train and segments.  It should not be considered intrinsic to the
// segment art, but only added privately here when part of the track scene.
static const CGFloat FLTrackArtScale = 2.0f;

// Main layers.
static const CGFloat FLZPositionWorld = 0.0f;
static const CGFloat FLZPositionHud = 10.0f;
// World sublayers.
static const CGFloat FLZPositionWorldTerrain = 0.0f;
static const CGFloat FLZPositionWorldSelect = 1.0f;
static const CGFloat FLZPositionWorldTrack = 2.0f;
static const CGFloat FLZPositionWorldTrain = 3.0f;
static const CGFloat FLZPositionWorldLinks = 4.0f;
static const CGFloat FLZPositionWorldOverlay = 5.0f;

static const NSTimeInterval FLTrackRotateDuration = 0.1;
static const NSTimeInterval FLBlinkHalfCycleDuration = 0.1;

// noob: The tool art uses a somewhat arbitrary size.  The display height is
// chosen based on the screen layout.  Perhaps scaling like that is a bad idea.
const CGFloat FLMainToolbarToolArtSize = 54.0f;
const CGFloat FLMainToolbarToolHeight = 48.0f;
const CGFloat FLMessageSpacer = 1.0f;
const CGFloat FLMessageHeight = 20.0f;

static NSString *FLGatesDirectoryPath;
static NSString *FLCircuitsDirectoryPath;
static NSString *FLExportsDirectoryPath;

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

enum FLToolbarToolType { FLToolbarToolTypeNone, FLToolbarToolTypeActionTap, FLToolbarToolTypeActionPan, FLToolbarToolTypeNavigation, FLToolbarToolTypeMode };

struct FLConstructionToolbarState
{
  FLConstructionToolbarState() : toolbarNode(nil), currentNavigation(@"main"), currentPage(0), deleteExportConfirmAlert(nil) {
    navigationTools = [NSMutableSet set];
    actionTapTools = [NSMutableSet set];
    actionPanTools = [NSMutableDictionary dictionary];
    modeTools = [NSMutableSet set];
  }
  HLToolbarNode *toolbarNode;
  NSString *currentNavigation;
  int currentPage;
  NSMutableSet *navigationTools;
  NSMutableSet *actionTapTools;
  NSMutableDictionary *actionPanTools;
  NSMutableSet *modeTools;
  UIAlertView *deleteExportConfirmAlert;
  NSString *deleteExportName;
  NSString *deleteExportDescription;
};

struct FLSimulationToolbarState
{
  FLSimulationToolbarState() : toolbarNode(nil) {}
  HLToolbarNode *toolbarNode;
};

struct FLMessageState
{
  FLMessageState() : messageNode(nil), labelNode(nil) {}
  SKSpriteNode *messageNode;
  SKLabelNode *labelNode;
};

struct FLTrackSelectState
{
  FLTrackSelectState() : selectedSegments(nil), visualParentNode(nil) {}
  NSMutableSet *selectedSegments;
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
  NSSet *segmentNodes;
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
  SKShapeNode *beginHighlightNode;
  SKShapeNode *endHighlightNode;
};

enum FLWorldPanType { FLWorldPanTypeNone, FLWorldPanTypeScroll, FLWorldPanTypeTrackMove, FLWorldPanTypeLink };

enum FLWorldLongPressMode { FLWorldLongPressModeNone, FLWorldLongPressModeAdd, FLWorldLongPressModeErase };

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

enum FLCameraMode { FLCameraModeManual, FLCameraModeFollowTrain };

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

  UITapGestureRecognizer *_tapRecognizer;
  UITapGestureRecognizer *_doubleTapRecognizer;
  UILongPressGestureRecognizer *_longPressRecognizer;
  UIPanGestureRecognizer *_panRecognizer;
  UIPinchGestureRecognizer *_pinchRecognizer;

  FLCameraMode _cameraMode;
  BOOL _simulationRunning;
  int _simulationSpeed;
  CFTimeInterval _updateLastTime;

  shared_ptr<FLTrackGrid> _trackGrid;
  FLLinks _links;

  FLExportState _exportState;
  FLWorldGestureState _worldGestureState;
  FLConstructionToolbarState _constructionToolbarState;
  FLSimulationToolbarState _simulationToolbarState;
  FLMessageState _messageState;
  FLTrackEditMenuState _trackEditMenuState;
  FLTrackSelectState _trackSelectState;
  FLTrackConflictState _trackConflictState;
  FLTrackMoveState _trackMoveState;
  FLLinkEditState _linkEditState;

  FLTrain *_train;
}

+ (void)initialize
{
  NSString *bundleDirectory = [[NSBundle mainBundle] bundlePath];
  FLGatesDirectoryPath = [bundleDirectory stringByAppendingPathComponent:@"gates"];
  FLCircuitsDirectoryPath = [bundleDirectory stringByAppendingPathComponent:@"circuits"];
  NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
  FLExportsDirectoryPath = [documentsDirectory stringByAppendingPathComponent:@"exports"];
}

+ (FLTrackScene *)load:(NSString *)saveName
{
  NSString *savePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
                        stringByAppendingPathComponent:[saveName stringByAppendingPathExtension:@"archive"]];
  if (![[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
    return nil;
  }
  return [NSKeyedUnarchiver unarchiveObjectWithFile:savePath];
}

- (void)save:(NSString *)saveName
{
  NSString *savePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
                        stringByAppendingPathComponent:[saveName stringByAppendingPathExtension:@"archive"]];
  [NSKeyedArchiver archiveRootObject:self toFile:savePath];
}

- (id)initWithSize:(CGSize)size
{
  self = [super initWithSize:size];
  if (self) {
    _cameraMode = FLCameraModeManual;
    _simulationRunning = NO;
    _simulationSpeed = 0;
    _trackGrid.reset(new FLTrackGrid(FLSegmentArtSizeBasic * FLTrackArtScale));
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {
    _contentCreated = YES;
    [self FL_preloadTextures];
    [self FL_preloadSound];

    _cameraMode = (FLCameraMode)[aDecoder decodeIntForKey:@"cameraMode"];
    _simulationRunning = [aDecoder decodeBoolForKey:@"simulationRunning"];
    _simulationSpeed = [aDecoder decodeIntForKey:@"simulationSpeed"];
    [self FL_simulationToolbarUpdateTools];

    // Re-link special node pointers to objects already decoded in hierarchy.
    _worldNode = [aDecoder decodeObjectForKey:@"worldNode"];
    _trackNode = [aDecoder decodeObjectForKey:@"trackNode"];

    // Re-create nodes from the hierarchy that were removed during encoding.
    [self FL_createTerrainNode];
    [self FL_createHudNode];
    [self FL_createLinksNode];
    [self FL_constructionToolbarSetVisible:YES];
    [self FL_simulationToolbarSetVisible:YES];

    // Re-create track grid based on segments in track node.
    _trackGrid.reset(new FLTrackGrid(FLSegmentArtSizeBasic * FLTrackArtScale));
    _trackGrid->import(_trackNode);

    // Decode links model and re-create links layer.
    NSArray *links = [aDecoder decodeObjectForKey:@"links"];
    NSUInteger l = 0;
    while (l + 1 < [links count]) {
      FLSegmentNode *a = [links objectAtIndex:l];
      ++l;
      FLSegmentNode *b = [links objectAtIndex:l];
      ++l;
      SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:a.switchPosition toLocation:b.switchPosition];
      _links.insert(a, b, connectorNode);
    }

    // Decode train.
    _train = [aDecoder decodeObjectForKey:@"train"];
    _train.delegate = self;
    [_train resetTrackGrid:_trackGrid];

    // Decode current selection.
    NSMutableSet *selectedSegments = [aDecoder decodeObjectForKey:@"trackSelectStateSelectedSegments"];
    if (selectedSegments && [selectedSegments count] > 0) {
      [self FL_trackSelect:selectedSegments];
    }

    // Decode current track edit menu.
    if ([aDecoder decodeBoolForKey:@"trackEditMenuStateShowing"]) {
      [self FL_trackEditMenuShowAnimated:NO];
    }

    // Decode current construction toolbar state.
    //
    // note: A bit awkward.  The various subtoolbars initialize themselves on-demand before being shown; we
    // must traverse the hierarchy in order to initialize the parents before attempting to show the current
    // toolbar.  This seems a bit silly, since we're messing with display.  But right now it's pretty simple:
    // The main toolbar was already shown with the call to FL_constructionToolbarSetVisible above, and now
    // we merely have to traverse down one level if required.
    _constructionToolbarState.currentNavigation = [aDecoder decodeObjectForKey:@"constructionToolbarStateCurrentNavigation"];
    _constructionToolbarState.currentPage = [aDecoder decodeIntForKey:@"constructionToolbarStateCurrentPage"];
    if (![_constructionToolbarState.currentNavigation isEqualToString:@"main"]
        || _constructionToolbarState.currentPage != 0) {
      [self FL_constructionToolbarUpdateToolsAnimation:HLToolbarNodeAnimationNone];
    }
    BOOL linksVisible = [aDecoder decodeBoolForKey:@"constructionToolbarStateLinksVisible"];
    if (linksVisible) {
      [_constructionToolbarState.toolbarNode setHighlight:YES forTool:@"link"];
      [_worldNode addChild:_linksNode];
    }
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  if (!_contentCreated) {
    return;
  }

  // noob: Call [super] and do opt-out, or skip [super] and do opt-in?  Going with
  // the former for now.

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
  BOOL linksVisible = (_linksNode.parent != nil);
  if (linksVisible) {
    [_linksNode removeFromParent];
  }
  [self FL_simulationToolbarSetVisible:NO];
  [self FL_constructionToolbarSetVisible:NO];
  [self FL_trackConflictClear];

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
  if (linksVisible) {
    [_worldNode addChild:_linksNode];
  }
  [self FL_simulationToolbarSetVisible:YES];
  [self FL_constructionToolbarSetVisible:YES];

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
  [aCoder encodeInt:(int)_cameraMode forKey:@"cameraMode"];
  [aCoder encodeBool:_simulationRunning forKey:@"simulationRunning"];
  [aCoder encodeInt:_simulationSpeed forKey:@"simulationSpeed"];
  [aCoder encodeObject:_train forKey:@"train"];
  [aCoder encodeObject:_trackSelectState.selectedSegments forKey:@"trackSelectStateSelectedSegments"];
  [aCoder encodeBool:_trackEditMenuState.showing forKey:@"trackEditMenuStateShowing"];
  [aCoder encodeBool:linksVisible forKey:@"constructionToolbarStateLinksVisible"];
  [aCoder encodeObject:_constructionToolbarState.currentNavigation forKey:@"constructionToolbarStateCurrentNavigation"];
  [aCoder encodeInt:_constructionToolbarState.currentPage forKey:@"constructionToolbarStateCurrentPage"];
}

- (void)didMoveToView:(SKView *)view
{
  if (!_contentCreated) {
    [self FL_createSceneContents];
    _contentCreated = YES;
  }

  // note: No need for cancelsTouchesInView: Not currently handling any touches in the view.

  _doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleWorldDoubleTap:)];
  _doubleTapRecognizer.delegate = self;
  _doubleTapRecognizer.numberOfTapsRequired = 2;
  [view addGestureRecognizer:_doubleTapRecognizer];

  _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleWorldTap:)];
  _tapRecognizer.delegate = self;
  // note: This slows down the single-tap recognizer noticeably.  And yet it's not really nice to have
  // the tap and double-tap fire together.  Consider not using double-tap for these reasons.
  //[_tapRecognizer requireGestureRecognizerToFail:_doubleTapRecognizer];
  [view addGestureRecognizer:_tapRecognizer];

  _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleWorldLongPress:)];
  _longPressRecognizer.delegate = self;
  [view addGestureRecognizer:_longPressRecognizer];

  _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleWorldPan:)];
  _panRecognizer.delegate = self;
  _panRecognizer.maximumNumberOfTouches = 1;
  [view addGestureRecognizer:_panRecognizer];

  _pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleWorldPinch:)];
  _pinchRecognizer.delegate = self;
  [view addGestureRecognizer:_pinchRecognizer];
}

- (void)willMoveFromView:(SKView *)view
{
  [view removeGestureRecognizer:_doubleTapRecognizer];
  [view removeGestureRecognizer:_tapRecognizer];
  [view removeGestureRecognizer:_longPressRecognizer];
  [view removeGestureRecognizer:_panRecognizer];
  [view removeGestureRecognizer:_pinchRecognizer];
}

- (void)didChangeSize:(CGSize)oldSize
{
  [self FL_constructionToolbarUpdateGeometry];
  [self FL_simulationToolbarUpdateGeometry];
  [self FL_messageUpdateGeometry];
}

- (void)FL_createSceneContents
{
  self.backgroundColor = [SKColor colorWithRed:0.4f green:0.6f blue:0.0f alpha:1.0f];
  self.anchorPoint = CGPointMake(0.5f, 0.5f);

  [self FL_preloadTextures];
  [self FL_preloadSound];

  // Create basic layers.

  // The large world is moved around within the scene; the scene acts as a window
  // into the world.  The scene always fits the view/screen, and it is centered at
  // in the middle of the screen; the coordinate system goes positive up and to the
  // right.  So, for example, if we want to show the portion of the world around
  // the point (100,-50) in world coordinates, then we set the _worldNode.position
  // to (-100,50) in scene coordinates.
  //
  // noob: Consider using our QuadTree not just for the track but for the whole
  // world, and remove from the game engine (node tree) any nodes which are far
  // away.  Our QuadTree implementation should have an interface to easily identify
  // the eight "tiles" or "cells" surrounding a given tile (given a certain tile
  // size, which we can proscribe based on memory/performance).  This is marked
  // "noob" because I'm not sure how effective this would be for different kinds
  // of resources.  For instance, I'm pretty sure that removing lots of distant
  // SKNodes from the tree would improve speed and memory usage.  I'm guessing that
  // breaking up a single large SKSpriteNode with a big image would save on memory,
  // but perhaps not make anything much faster.
  _worldNode = [SKNode node];
  _worldNode.zPosition = FLZPositionWorld;
  [self addChild:_worldNode];

  // noob: See note near _worldNode above: We will probaly want to add/remove near/distant
  // child nodes based on our current camera location in the world.  Use our QuadTree
  // to implement, I expect.
  _trackNode = [SKNode node];
  _trackNode.zPosition = FLZPositionWorldTrack;
  [_worldNode addChild:_trackNode];

  [self FL_createTerrainNode];

  [self FL_createLinksNode];

  // The HUD node contains everything pinned to the scene window, outside the world.
  [self FL_createHudNode];

  // Create other content.

  _train = [[FLTrain alloc] initWithTrackGrid:_trackGrid];
  _train.delegate = self;
  _train.scale = FLTrackArtScale;
  _train.zPosition = FLZPositionWorldTrain;
  [_worldNode addChild:_train];

  [self FL_constructionToolbarSetVisible:YES];
  [self FL_simulationToolbarSetVisible:YES];
}

- (void)FL_createTerrainNode
{
  UIImage *terrainTileImage = [UIImage imageNamed:@"grass"];
  CGRect terrainTileRect = CGRectMake(0.0f, 0.0f, terrainTileImage.size.width, terrainTileImage.size.height);
  CGImageRef terrainTileRef = [terrainTileImage CGImage];

  UIGraphicsBeginImageContext(FLWorldSize);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextDrawTiledImage(context, terrainTileRect, terrainTileRef);
  UIImage *terrainImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  SKTexture *terrainTexture = [SKTexture textureWithCGImage:[terrainImage CGImage]];

  SKSpriteNode *terrainNode = [SKSpriteNode spriteNodeWithTexture:terrainTexture];
  terrainNode.name = @"terrain";
  terrainNode.zPosition = FLZPositionWorldTerrain;
  // noob: Using a tip to use replace blend mode for opaque sprites, but since
  // JPEGs don't have an alpha channel in the source, does this really do anything
  // for JPEGs?
  terrainNode.blendMode = SKBlendModeReplace;
//
//  SKSpriteNode *terrainNode = [SKSpriteNode spriteNodeWithColor:[UIColor purpleColor] size:self.size];
//  terrainNode.zPosition = FLZPositionWorldTerrain;
//
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
      _worldNode.position = CGPointMake(_worldNode.position.x - trainSceneLocation.x,
                                        _worldNode.position.y - trainSceneLocation.y);
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
    [_train update:elapsedTime simulationSpeed:_simulationSpeed];
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
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
  FLSegmentNode *segmentNode = trackGridConvertGet(*_trackGrid, worldLocation);

  if (!segmentNode || [self FL_trackSelected:segmentNode]) {
    [self FL_trackSelectClear];
    [self FL_trackEditMenuHideAnimated:YES];
  } else {
    [self FL_trackSelectClear];
    NSSet *segmentNodeSet = [NSSet setWithObject:segmentNode];
    [self FL_trackSelect:segmentNodeSet];
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
  NSLog(@"double tapped %d,%d", gridX, gridY);

  FLSegmentNode *segmentNode = _trackGrid->get(gridX, gridY);
  if (segmentNode && segmentNode.switchPathId != FLSegmentSwitchPathIdNone) {
    [self FL_linkToggleSwitch:segmentNode animated:YES];
  }
}

- (void)handleWorldLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

    CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
    CGPoint sceneLocation = [self convertPointFromView:viewLocation];
    CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
    FLSegmentNode *segmentNode = trackGridConvertGet(*_trackGrid, worldLocation);
    if (segmentNode) {
      if ([self FL_trackSelected:segmentNode]) {
        _worldGestureState.longPressMode = FLWorldLongPressModeErase;
        [self FL_trackSelectErase:segmentNode];
      } else {
        _worldGestureState.longPressMode = FLWorldLongPressModeAdd;
        [self FL_trackSelect:[NSSet setWithObject:segmentNode]];
      }
      [self FL_trackEditMenuHideAnimated:YES];
    } else {
      _worldGestureState.longPressMode = FLWorldLongPressModeNone;
    }

  } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {

    if (_worldGestureState.longPressMode != FLWorldLongPressModeNone) {
      CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
      CGPoint sceneLocation = [self convertPointFromView:viewLocation];
      CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
      FLSegmentNode *segmentNode = trackGridConvertGet(*_trackGrid, worldLocation);
      if (segmentNode) {
        if (_worldGestureState.longPressMode == FLWorldLongPressModeAdd) {
          [self FL_trackSelect:[NSSet setWithObject:segmentNode]];
        } else {
          [self FL_trackSelectErase:segmentNode];
        }
      }
    }

  } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
    [self FL_trackEditMenuUpdateAnimated:YES];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
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
    FLSegmentNode *segmentNode = trackGridConvertGet(*_trackGrid, firstTouchWorldLocation);
    if (_linksNode.parent) {
      if (segmentNode && segmentNode.switchPathId != FLSegmentSwitchPathIdNone) {
        // Pan begins with link tool inside a segment that has a switch.
        _worldGestureState.panType = FLWorldPanTypeLink;
        [self FL_linkEditBeganWithNode:segmentNode];
      } else {
        // Pan begins with link tool in a segment without a switch.
        _worldGestureState.panType = FLWorldPanTypeScroll;
      }
    } else {
      // Pan is not using link tool.
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
        break;
      }
      case FLWorldPanTypeScroll: {
        CGPoint translation = [gestureRecognizer translationInView:self.view];
        CGPoint worldPosition = CGPointMake(_worldNode.position.x + translation.x / self.xScale,
                                            _worldNode.position.y - translation.y / self.yScale);
        _worldNode.position = worldPosition;
        [gestureRecognizer setTranslation:CGPointZero inView:self.view];
        break;
      }
      case FLWorldPanTypeLink: {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
        [self FL_linkEditChangedWithLocation:worldLocation];
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
        break;
      }
      case FLWorldPanTypeScroll:
        // note: Nothing to do here.
        break;
      case FLWorldPanTypeLink:
        [self FL_linkEditEnded];
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
        break;
      }
      case FLWorldPanTypeScroll:
        // note: Nothing to do here.
        break;
      case FLWorldPanTypeLink:
        [self FL_linkEditCancelled];
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

  CGFloat worldScaleCurrent = handlePinchWorldScaleBegin * gestureRecognizer.scale;
  if (worldScaleCurrent > FLWorldScaleMax) {
    worldScaleCurrent = FLWorldScaleMax;
  } else if (worldScaleCurrent < FLWorldScaleMin) {
    worldScaleCurrent = FLWorldScaleMin;
  }
  _worldNode.xScale = worldScaleCurrent;
  _worldNode.yScale = worldScaleCurrent;
  [self FL_trackEditMenuScaleToWorld];
  CGFloat scaleFactor = worldScaleCurrent / handlePinchWorldScaleBegin;

  // Zoom around previously-chosen center point.
  CGPoint worldPosition;
  worldPosition.x = (handlePinchWorldPositionBegin.x - _worldGestureState.pinchZoomCenter.x) * scaleFactor + _worldGestureState.pinchZoomCenter.x;
  worldPosition.y = (handlePinchWorldPositionBegin.y - _worldGestureState.pinchZoomCenter.y) * scaleFactor + _worldGestureState.pinchZoomCenter.y;
  _worldNode.position = worldPosition;
}

- (void)handleConstructionToolbarTap:(UITapGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_constructionToolbarState.toolbarNode convertPoint:sceneLocation fromNode:self];
  NSString *tool = [_constructionToolbarState.toolbarNode toolAtLocation:toolbarLocation];
  if (!tool) {
    return;
  }

  FLToolbarToolType toolType = FLToolbarToolTypeNone;
  if ([_constructionToolbarState.navigationTools containsObject:tool]) {
    toolType = FLToolbarToolTypeNavigation;
  } else if ([_constructionToolbarState.actionTapTools containsObject:tool]) {
    toolType = FLToolbarToolTypeActionTap;
  } else if ([_constructionToolbarState.actionPanTools objectForKey:tool]) {
    toolType = FLToolbarToolTypeActionPan;
  } else if ([_constructionToolbarState.modeTools containsObject:tool]) {
    toolType = FLToolbarToolTypeMode;
  } else {
    [NSException raise:@"FLToolbarToolTypeUnknown" format:@"Tool '%@' not registered with a tool type.", tool];
  }

  // Reset state on all mode buttons.
  if (![tool isEqualToString:@"link"] && _linksNode.parent) {
    [_linksNode removeFromParent];
    // note: Right now, must be looking at main toolbar tools, or else links node
    // wouldn't have been added to parent.  So no need to check.
    [_constructionToolbarState.toolbarNode setHighlight:NO forTool:@"link"];
  }

  if (toolType == FLToolbarToolTypeNavigation) {

    NSString *newNavigation;
    int newPage;
    HLToolbarNodeAnimation animation = HLToolbarNodeAnimationNone;
    if ([tool isEqualToString:@"next"]) {
      newNavigation = _constructionToolbarState.currentNavigation;
      newPage = _constructionToolbarState.currentPage + 1;
      animation = HLToolbarNodeAnimationSlideLeft;
    } else if ([tool isEqualToString:@"previous"]) {
      newNavigation = _constructionToolbarState.currentNavigation;
      newPage = _constructionToolbarState.currentPage - 1;
      animation = HLToolbarNodeAnimationSlideRight;
    } else if ([tool isEqualToString:@"main"]) {
      newNavigation = @"main";
      newPage = 0;
      animation = HLToolbarNodeAnimationSlideUp;
    } else {
      newNavigation = tool;
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
      [self FL_messageShow:@"No exports found."];
    }

  } else if (toolType == FLToolbarToolTypeActionTap) {

    if ([tool isEqualToString:@"export"]) {
      if ([self FL_trackSelectedNone]) {
        [self FL_messageShow:@"Export: Make a selection."];
      } else {
        [self FL_export];
      }
    }

  } else if (toolType == FLToolbarToolTypeActionPan) {

    [self FL_messageShow:[_constructionToolbarState.actionPanTools objectForKey:tool]];

  } else if (toolType == FLToolbarToolTypeMode) {

    if ([tool isEqualToString:@"link"]) {
      [_constructionToolbarState.toolbarNode setHighlight:(_linksNode.parent == nil) forTool:@"link"];
      if (_linksNode.parent) {
        [_linksNode removeFromParent];
      } else {
        [_worldNode addChild:_linksNode];
      }
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
  NSString *tool = [_constructionToolbarState.toolbarNode toolAtLocation:toolbarLocation];
  if (!tool) {
    return;
  }

  NSString *description = [_constructionToolbarState.actionPanTools objectForKey:tool];
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
  _constructionToolbarState.deleteExportName = tool;
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
    NSString *tool = [_constructionToolbarState.toolbarNode toolAtLocation:firstTouchToolbarLocation];
    if (!tool || ![_constructionToolbarState.actionPanTools objectForKey:tool]) {
      _worldGestureState.panType = FLWorldPanTypeNone;
      return;
    }
    [self FL_trackSelectClear];
    _worldGestureState.panType = FLWorldPanTypeTrackMove;

    if ([_constructionToolbarState.currentNavigation isEqualToString:@"segments"]) {

      FLSegmentNode *newSegmentNode = [self FL_createSegmentWithTextureKey:tool];
      newSegmentNode.zRotation = (CGFloat)M_PI_2;
      // note: Locate the new segment underneath the current touch, even though it's
      // not yet added to the node hierarchy.  (The track move routines translate nodes
      // relative to their current position.)
      int gridX;
      int gridY;
      _trackGrid->convert(worldLocation, &gridX, &gridY);
      newSegmentNode.position = _trackGrid->convert(gridX, gridY);
      [self FL_trackMoveBeganWithNodes:[NSSet setWithObject:newSegmentNode] location:worldLocation completion:nil];

    } else {

      NSString *importPath;
      if ([_constructionToolbarState.currentNavigation isEqualToString:@"gates"]) {
        importPath = [FLGatesDirectoryPath stringByAppendingPathComponent:[tool stringByAppendingPathExtension:@"archive"]];
      } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"circuits"]) {
        importPath = [FLCircuitsDirectoryPath stringByAppendingPathComponent:[tool stringByAppendingPathExtension:@"archive"]];
      } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"exports"]) {
        importPath = [FLExportsDirectoryPath stringByAppendingPathComponent:[tool stringByAppendingPathExtension:@"archive"]];
      } else {
        [NSException raise:@"FLConstructionToolbarInvalidNavigation" format:@"Unrecognized navigation '%@'.", _constructionToolbarState.currentNavigation];
      }
      NSString *description;
      NSArray *links;
      NSSet *newSegmentNodes = [self FL_importWithPath:importPath description:&description links:&links];

      // Find position-aligned center point of the imported segment set.
      //
      // note: Locate the new segments underneath the current touch, even though they
      // are not yet added to the node hierarchy.  (The track move routines translate nodes
      // relative to their current position.)
      CGFloat segmentsPositionTop;
      CGFloat segmentsPositionBottom;
      CGFloat segmentsPositionLeft;
      CGFloat segmentsPositionRight;
      [self FL_getSegmentsExtremes:newSegmentNodes left:&segmentsPositionLeft right:&segmentsPositionRight top:&segmentsPositionTop bottom:&segmentsPositionBottom];
      CGFloat segmentSize = _trackGrid->segmentSize();
      int widthUnits = int((segmentsPositionRight - segmentsPositionLeft + 0.00001f) / segmentSize);
      int heightUnits = int((segmentsPositionTop - segmentsPositionBottom + 0.00001f) / segmentSize);
      // note: Width and height of position differences, so for instance a width of one means
      // the group is two segments wide.
      CGPoint segmentsAlignedCenter = CGPointMake((segmentsPositionLeft + segmentsPositionRight) / 2.0f,
                                                  (segmentsPositionBottom + segmentsPositionTop) / 2.0f);
      if (widthUnits % 2 == 1) {
        segmentsAlignedCenter.x -= (segmentSize / 2.0f);
      }
      if (heightUnits % 2 == 1) {
        segmentsAlignedCenter.y -= (segmentSize / 2.0f);
      }

      // Shift segments to the touch gesture (using calculated center).
      int gridX;
      int gridY;
      _trackGrid->convert(worldLocation, &gridX, &gridY);
      CGPoint touchAlignedCenter = _trackGrid->convert(gridX, gridY);
      CGPoint shift = CGPointMake(touchAlignedCenter.x - segmentsAlignedCenter.x,
                                  touchAlignedCenter.y - segmentsAlignedCenter.y);
      for (FLSegmentNode *segmentNode in newSegmentNodes) {
        segmentNode.position = CGPointMake(segmentNode.position.x + shift.x,
                                           segmentNode.position.y + shift.y);
      }

      [self FL_messageShow:[NSString stringWithFormat:@"Added '%@' to track." , description]];
      [self FL_trackMoveBeganWithNodes:newSegmentNodes location:worldLocation completion:^(BOOL placed){
        if (placed) {
          NSUInteger l = 0;
          while (l + 1 < [links count]) {
            FLSegmentNode *a = [links objectAtIndex:l];
            ++l;
            FLSegmentNode *b = [links objectAtIndex:l];
            ++l;
            SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:a.switchPosition toLocation:b.switchPosition];
            // note: Explicit "self" to make it obvious we are retaining it.
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
  } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
    [self FL_trackMoveEndedWithLocation:worldLocation];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
    [self FL_trackMoveCancelledWithLocation:worldLocation];
  }
}

- (void)handleSimulationToolbarTap:(UIGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_simulationToolbarState.toolbarNode convertPoint:sceneLocation fromNode:self];
  NSString *tool = [_simulationToolbarState.toolbarNode toolAtLocation:toolbarLocation];
  if (!tool) {
    return;
  }

  if ([tool isEqualToString:@"menu"]) {

    // TODO: Autosave or prompt to save.
    id<FLTrackSceneDelegate> delegate = self.delegate;
    if (delegate) {
      [delegate trackSceneDidTapMenuButton:self];
    }

  } else if ([tool isEqualToString:@"play"]) {

    _simulationRunning = YES;
    _train.running = YES;
    [self FL_simulationToolbarUpdateTools];

  } else if ([tool isEqualToString:@"pause"]) {

    _simulationRunning = NO;
    _train.running = NO;
    [self FL_simulationToolbarUpdateTools];

  } else if ([tool isEqualToString:@"ff"]) {

    if (_simulationSpeed == 0) {
      _simulationSpeed = 1;
    } else {
      _simulationSpeed = 2;
    }
    [self FL_simulationToolbarUpdateTools];

  } else if ([tool isEqualToString:@"fff"]) {

    _simulationSpeed = 0;
    [self FL_simulationToolbarUpdateTools];

  } else if ([tool isEqualToString:@"center"]) {

    CGPoint trainSceneLocation = [self convertPoint:_train.position fromNode:_worldNode];
    CGPoint worldPosition = CGPointMake(_worldNode.position.x - trainSceneLocation.x,
                                        _worldNode.position.y - trainSceneLocation.y);
    SKAction *move = [SKAction moveTo:worldPosition duration:0.5];
    move.timingMode = SKActionTimingEaseInEaseOut;
    [_worldNode runAction:move completion:^{
      self->_cameraMode = FLCameraModeFollowTrain;
    }];
  }
}

- (void)handleTrackEditMenuTap:(UIGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_trackEditMenuState.editMenuNode convertPoint:sceneLocation fromNode:self];
  NSString *button = [_trackEditMenuState.editMenuNode toolAtLocation:toolbarLocation];

  if ([button isEqualToString:@"rotate-cw"]) {
    [self FL_trackRotateSegments:_trackSelectState.selectedSegments rotateBy:-1 animated:YES];
  } else if ([button isEqualToString:@"rotate-ccw"]) {
    [self FL_trackRotateSegments:_trackSelectState.selectedSegments rotateBy:1 animated:YES];
  } else if ([button isEqualToString:@"toggle-switch"]) {
    for (FLSegmentNode *segmentNode in _trackSelectState.selectedSegments) {
      [self FL_linkToggleSwitch:segmentNode animated:YES];
    }
  } else if ([button isEqualToString:@"delete"]) {
    [self FL_trackEraseSegments:_trackSelectState.selectedSegments animated:YES];
    [self FL_trackEditMenuHideAnimated:NO];
    [self FL_trackSelectClear];
  }
}

- (void)handleTrainPan:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state != UIGestureRecognizerStateCancelled) {
    CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
    CGPoint sceneLocation = [self convertPointFromView:viewLocation];
    CGPoint worldLocation = [_worldNode convertPoint:sceneLocation fromNode:self];
    [_train moveToClosestOnTrackLocationForLocation:worldLocation];
  }
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

  // TODO: Tap gesture recognizers on button-like things should highlight on touch-down, activate on touch-up.

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

// Commented out: Started building this way of separating gesture delegate from target, but I'm not sure
// it's going to be used.  Still, keep the code around for a while in case I want it.
//
//- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
//{
//  // noob: The scene contains a few different components which respond to gestures.  For instance, the world
//  // responds to zooming, panning, and track selection; the toolbars respond to taps and pans.
//  // So the SKScene is the delegate and owner of all gesture recognizers; that seems right.  But if I set it
//  // as the only target of each gesture, then each target selector will be doing some kind of search to see
//  // which component of the scene should be receiving (and responding to) the gesture.  Further, it seems
//  // that "search" will either be a big linear switch statement in each method, or else something more
//  // sophisiticated which would be repeated in each method.
//  //
//  // So, let's make the SKScene responsible for maintaining state about the current target of the gesture
//  // recognizer objects, and the components responsible for implementing target methods.
//  //
//  // More ideas for loose-coupling: The components could excplicitly subscribe to receive particular gestures
//  // from the SKScene, through an interface.  Then the SKScene could add the required gesture recognizers
//  // as needed.
//  //
//  // For now, I don't mind hardcoding some of the knowledge about components here in the scene.  After all,
//  // the scene created these guys, so it knows something about them.
//  //
//  // Also, rather than do linear search, let's assume that hit-testing the initial touch to a particular
//  // SKNode is optimized to be fast.  I guess this is how SKScene (SKView?) forwards UIResponder touches*
//  // methods to a particular SKNode: It gets the highest-position node for the touch, then walks up the node
//  // tree looking for userInteractionEnabled.
//
//  // noob: It appears that this is only called for initial touches, and not for continued touches that
//  // the gesture recognizer has already started recognizing.  So, for example, a pan begun on one side
//  // of the toolbar, and continuing through it, continues to be recognized by the pan gesture
//  // recognizer.  This is good.  Otherwise, I suppose I would be doing explicit checks of the
//  // recognizer's state here.
//
//  CGPoint sceneLocation = [touch locationInNode:self];
//  SKNode *node = [self nodeAtPoint:sceneLocation];
//  SKNode <FLGestureTarget> *target = self;
//  while (node != self) {
//    if ([node conformsToProtocol:@protocol(FLGestureTarget) ]) {
//      target = (SKNode <FLGestureTarget> *)node;
//      break;
//    }
//    node = node.parent;
//  }
//
//  // noob: If this idea of a gesture-forwarding system works out in the long run, I might make a real
//  // subscription system, and if so then the naming of the action handler method will be a natural
//  // part of it.  (For instance, a particular toolbar will subscribe for tap gestures with selector
//  // handleTap:, both of which will be parameters here.)  For now, let's just use something clumsy
//  // and hardcoded.
//  SEL action;
//  if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
//    action = @selector(handleTap:);
//  } else if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
//    action = @selector(handlePan:);
//  } else if (...) {
//    ...
//  } else {
//    action = @selector(handleGesture:);
//  }
//
//  [gestureRecognizer removeTarget:nil action:nil];
//  [gestureRecognizer addTarget:target action:action];
//
//  if (target == self) {
//    return YES;
//  } else {
//    // noob: We're splitting gesture delegate from delegate target, but the target might want input
//    // into certain delegate-ish things.  This is an example.  It's either an example of discomfort,
//    // because maybe target shouldn't be split from delegate, or else an example of elegance, because
//    // we can cleanly separate the concerns by a registered interface of FLGestureTarget.
//    return [target shouldHandleGesture:gestureRecognizer firstTouch:touch];
//  }
//}

#pragma mark -
#pragma mark FLTrainDelegate

- (void)train:(FLTrain *)train didSwitchSegment:(FLSegmentNode *)segmentNode toPathId:(int)pathId
{
  [self FL_linkSetSwitch:segmentNode pathId:pathId animated:YES];
}

- (void)train:(FLTrain *)train crashedAtSegment:(FLSegmentNode *)segmentNode
{
  // note: Currently only one train, so if train stops then stop the whole simulation.
  _simulationRunning = NO;
  [self FL_simulationToolbarUpdateTools];
}

#pragma mark -
#pragma mark Common

- (void)FL_preloadTextures
{
  HLTextureStore *sharedStore = [HLTextureStore sharedStore];

  // Train.
  [sharedStore setTextureWithImageNamed:@"engine" forKey:@"engine" filteringMode:SKTextureFilteringNearest];

  // Segments.
  [sharedStore setTextureWithImageNamed:@"straight" andUIImageWithImageNamed:@"straight-nonatlas" forKey:@"straight" filteringMode:SKTextureFilteringNearest];
  [sharedStore setTextureWithImageNamed:@"curve" andUIImageWithImageNamed:@"curve-nonatlas" forKey:@"curve" filteringMode:SKTextureFilteringNearest];
  [sharedStore setTextureWithImageNamed:@"join-left" andUIImageWithImageNamed:@"join-left-nonatlas" forKey:@"join-left" filteringMode:SKTextureFilteringNearest];
  [sharedStore setTextureWithImageNamed:@"join-right" andUIImageWithImageNamed:@"join-right-nonatlas" forKey:@"join-right" filteringMode:SKTextureFilteringNearest];
  [sharedStore setTextureWithImageNamed:@"jog-left" andUIImageWithImageNamed:@"jog-left-nonatlas" forKey:@"jog-left" filteringMode:SKTextureFilteringNearest];
  [sharedStore setTextureWithImageNamed:@"jog-right" andUIImageWithImageNamed:@"jog-right-nonatlas" forKey:@"jog-right" filteringMode:SKTextureFilteringNearest];
  [sharedStore setTextureWithImageNamed:@"cross" andUIImageWithImageNamed:@"cross-nonatlas" forKey:@"cross" filteringMode:SKTextureFilteringNearest];

  // Tools.
  [sharedStore setTextureWithImageNamed:@"menu" forKey:@"menu" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"play" forKey:@"play" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"pause" forKey:@"pause" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"ff" forKey:@"ff" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"fff" forKey:@"fff" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"center" forKey:@"center" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"delete" forKey:@"delete" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"rotate-cw" forKey:@"rotate-cw" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"rotate-ccw" forKey:@"rotate-ccw" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"toggle-switch" forKey:@"toggle-switch" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"main" forKey:@"main" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"next" forKey:@"next" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"previous" forKey:@"previous" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"segments" forKey:@"segments" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"gates" forKey:@"gates" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"circuits" forKey:@"circuits" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"exports" forKey:@"exports" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"link" forKey:@"link" filteringMode:SKTextureFilteringLinear];
  [sharedStore setTextureWithImageNamed:@"export" forKey:@"export" filteringMode:SKTextureFilteringLinear];

  // Other.
  [sharedStore setTextureWithImageNamed:@"switch" forKey:@"switch" filteringMode:SKTextureFilteringNearest];
}

- (void)FL_preloadSound
{
  // noob: Could make a store to control this, but it would be a weird store, since the
  // references to the sounds don't actually need to be tracked.
  [SKAction playSoundFileNamed:@"wooden-click-1.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"wooden-click-2.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"wooden-clickity-2.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"wooden-clatter-1.caf" waitForCompletion:NO];
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
  NSString *exportName = (__bridge NSString *)uuidString;
  CFRelease(uuidString);
  CFRelease(uuid);

  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:FLExportsDirectoryPath]) {
    [fileManager createDirectoryAtPath:FLExportsDirectoryPath withIntermediateDirectories:NO attributes:nil error:NULL];
  }
  NSString *exportPath = [FLExportsDirectoryPath stringByAppendingPathComponent:[exportName stringByAppendingPathExtension:@"archive"]];

  NSMutableData *archiveData = [NSMutableData data];
  NSKeyedArchiver *aCoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archiveData];

  [aCoder encodeObject:trackDescription forKey:@"trackDescription"];
  // note: Could normalize segment position so that, say, the lower-leftmost in the
  // selection had position (0,0), but since a respositioning always happens on import,
  // there doesn't seem to be a need for anything other than preserving relative
  // position.
  [aCoder encodeObject:_trackSelectState.selectedSegments forKey:@"segmentNodes"];
  NSMutableArray *links = [NSMutableArray array];
  for (auto link : _links) {
    FLSegmentNode *fromSegmentNode = (__bridge FLSegmentNode *)link.first.first;
    FLSegmentNode *toSegmentNode = (__bridge FLSegmentNode *)link.first.second;
    if ([_trackSelectState.selectedSegments containsObject:fromSegmentNode]
        && [_trackSelectState.selectedSegments containsObject:toSegmentNode]) {
      [links addObject:fromSegmentNode];
      [links addObject:toSegmentNode];
    }
  }
  [aCoder encodeObject:links forKey:@"links"];
  [aCoder finishEncoding];
  [archiveData writeToFile:exportPath atomically:NO];

  [self FL_messageShow:[NSString stringWithFormat:@"Exported “%@”.", trackDescription]];

  return YES;
}

- (void)FL_exportDelete:(NSString *)exportName description:(NSString *)trackDescription
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *exportPath = [FLExportsDirectoryPath stringByAppendingPathComponent:[exportName stringByAppendingPathExtension:@"archive"]];
  [fileManager removeItemAtPath:exportPath error:nil];

  [self FL_messageShow:[NSString stringWithFormat:@"Deleted “%@”.", trackDescription]];
  if ([_constructionToolbarState.currentNavigation isEqualToString:@"exports"]) {
    // note: Page might be too large as a result of the deletion.
    int pageMax = [self FL_constructionToolbarImportsPageMax:FLExportsDirectoryPath];
    if (_constructionToolbarState.currentPage > pageMax) {
      _constructionToolbarState.currentPage = pageMax;
    }
    [self FL_constructionToolbarShowImports:FLExportsDirectoryPath page:_constructionToolbarState.currentPage animation:HLToolbarNodeAnimationNone];
  }
}

- (NSSet *)FL_importWithPath:(NSString *)path description:(NSString * __autoreleasing *)trackDescription links:(NSArray * __autoreleasing *)links
{
  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
    [NSException raise:@"FLImportPathInvalid" format:@"Invalid import path %@.", path];
  }

  NSData *archiveData = [NSData dataWithContentsOfFile:path];
  NSKeyedUnarchiver *aDecoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:archiveData];

  NSMutableSet *segmentNodes = [aDecoder decodeObjectForKey:@"segmentNodes"];
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

/**
 * Creates a sprite using the shared texture store.
 *
 * @param The name of the sprite; nil for none.
 *
 * @param The texture key used by the texture store.
 */
- (SKSpriteNode *)FL_createSprite:(NSString *)spriteName withTexture:(NSString *)textureKey parent:(SKNode *)parent
{
  SKTexture *texture = [[HLTextureStore sharedStore] textureForKey:textureKey];
  SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithTexture:texture];
  sprite.name = spriteName;
  sprite.scale = FLTrackArtScale;
  //// note: The textureKey in user data is currently only used for debugging.
  //sprite.userData = [NSMutableDictionary dictionaryWithDictionary:@{ @"textureKey" : textureKey }];
  [parent addChild:sprite];
  return sprite;
}

- (FLSegmentNode *)FL_createSegmentWithSegmentType:(FLSegmentType)segmentType
{
  FLSegmentNode *segmentNode = [[FLSegmentNode alloc] initWithSegmentType:segmentType];
  segmentNode.scale = FLTrackArtScale;
  return segmentNode;
}

- (FLSegmentNode *)FL_createSegmentWithTextureKey:(NSString *)textureKey
{
  FLSegmentNode *segmentNode = [[FLSegmentNode alloc] initWithTextureKey:textureKey];
  segmentNode.scale = FLTrackArtScale;
  return segmentNode;
}

- (UIImage *)FL_createImageForSegments:(NSSet *)segmentNodes withSize:(CGFloat)imageSize
{
  CGFloat segmentsPositionTop;
  CGFloat segmentsPositionBottom;
  CGFloat segmentsPositionLeft;
  CGFloat segmentsPositionRight;
  [self FL_getSegmentsExtremes:segmentNodes left:&segmentsPositionLeft right:&segmentsPositionRight top:&segmentsPositionTop bottom:&segmentsPositionBottom];

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

- (void)FL_getSegmentsExtremes:(NSSet *)segmentNodes left:(CGFloat *)left right:(CGFloat *)right top:(CGFloat *)top bottom:(CGFloat *)bottom
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

- (void)FL_constructionToolbarSetVisible:(BOOL)visible
{
  if (!_constructionToolbarState.toolbarNode) {
    _constructionToolbarState.toolbarNode = [[HLToolbarNode alloc] init];
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
  _constructionToolbarState.toolbarNode.size = CGSizeMake(self.size.width, FLMainToolbarToolHeight);

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
    [self FL_constructionToolbarShowImports:FLGatesDirectoryPath page:_constructionToolbarState.currentPage animation:animation];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"circuits"]) {
    [self FL_constructionToolbarShowImports:FLCircuitsDirectoryPath page:_constructionToolbarState.currentPage animation:animation];
  } else if ([_constructionToolbarState.currentNavigation isEqualToString:@"exports"]) {
    [self FL_constructionToolbarShowImports:FLExportsDirectoryPath page:_constructionToolbarState.currentPage animation:animation];
  } else {
    [NSException raise:@"FLConstructionToolbarInvalidNavigation" format:@"Unrecognized navigation '%@'.", _constructionToolbarState.currentNavigation];
  }
}

- (void)FL_constructionToolbarShowMain:(int)page animation:(HLToolbarNodeAnimation)animation
{
  [_constructionToolbarState.toolbarNode setToolsWithTextureKeys:@[ @"segments", @"gates", @"circuits", @"exports", @"link", @"export" ]
                                                           store:[HLTextureStore sharedStore]
                                                       rotations:nil
                                                         offsets:nil
                                                       animation:animation];
  [_constructionToolbarState.navigationTools addObject:@"segments"];
  [_constructionToolbarState.navigationTools addObject:@"gates"];
  [_constructionToolbarState.navigationTools addObject:@"circuits"];
  [_constructionToolbarState.navigationTools addObject:@"exports"];
  [_constructionToolbarState.modeTools addObject:@"link"];
  [_constructionToolbarState.actionTapTools addObject:@"export"];
}

- (void)FL_constructionToolbarShowSegments:(int)page animation:(HLToolbarNodeAnimation)animation
{
  [_constructionToolbarState.toolbarNode setToolsWithTextureKeys:@[ @"main", @"straight", @"curve", @"join-left", @"join-right", @"jog-left", @"jog-right", @"cross" ]
                                                           store:[HLTextureStore sharedStore]
                                                       rotations:nil
                                                         offsets:@[ [NSValue valueWithCGPoint:CGPointZero],
                                                                    [NSValue valueWithCGPoint:CGPointMake(FLSegmentArtStraightShift, 0.0f)],
                                                                    [NSValue valueWithCGPoint:CGPointMake(FLSegmentArtCurveShift, -FLSegmentArtCurveShift)],
                                                                    [NSValue valueWithCGPoint:CGPointMake(FLSegmentArtCurveShift, -FLSegmentArtCurveShift)],
                                                                    [NSValue valueWithCGPoint:CGPointMake(FLSegmentArtCurveShift, FLSegmentArtCurveShift)],
                                                                    [NSValue valueWithCGPoint:CGPointZero],
                                                                    [NSValue valueWithCGPoint:CGPointZero],
                                                                    [NSValue valueWithCGPoint:CGPointZero] ]
                                                        animation:animation];
  [_constructionToolbarState.navigationTools addObject:@"main"];
  [_constructionToolbarState.actionPanTools setObject:@"Straight Track" forKey:@"straight"];
  [_constructionToolbarState.actionPanTools setObject:@"Curved Track" forKey:@"curve"];
  [_constructionToolbarState.actionPanTools setObject:@"Join Left Track" forKey:@"join-left"];
  [_constructionToolbarState.actionPanTools setObject:@"Join Right Track" forKey:@"join-right"];
  [_constructionToolbarState.actionPanTools setObject:@"Jog Left Track" forKey:@"jog-left"];
  [_constructionToolbarState.actionPanTools setObject:@"Jog Right Track" forKey:@"jog-right"];
  [_constructionToolbarState.actionPanTools setObject:@"Cross Track" forKey:@"cross"];
}

- (void)FL_constructionToolbarShowImports:(NSString *)importDirectory page:(int)page animation:(HLToolbarNodeAnimation)animation
{
  // Get a list of all imports (sorted appropriately).
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *importFiles;
  if ([importDirectory isEqualToString:FLExportsDirectoryPath]) {
    // note: For user-exported files, sort by descending creation date.
    NSURL *importURL = [NSURL fileURLWithPath:importDirectory isDirectory:NO];
    NSArray *importFileURLs = [fileManager contentsOfDirectoryAtURL:importURL includingPropertiesForKeys:@[ NSURLCreationDateKey ] options:nil error:nil];
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
      NSLog(@"file %@ created %@", [url lastPathComponent], date);
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
  NSMutableArray *importTextureKeys = [NSMutableArray array];
  for (NSString *importFile in importFiles) {
    NSString *importName = [importFile stringByDeletingPathExtension];
    SKTexture *texture = [[HLTextureStore sharedStore] textureForKey:importName];
    if (!texture) {
      NSString *importPath = [importDirectory stringByAppendingPathComponent:importFile];
      NSString *importDescription = nil;
      NSSet *segmentNodes = [self FL_importWithPath:importPath description:&importDescription links:NULL];
      UIImage *importImage = [self FL_createImageForSegments:segmentNodes withSize:FLMainToolbarToolArtSize];
      [[HLTextureStore sharedStore] setTextureWithImage:importImage forKey:importName filteringMode:SKTextureFilteringNearest];
      // note: With the current code, the description will not get updated in the interface
      // if it has changed on disk.  That said, I don't see how it could change on disk.
      [_constructionToolbarState.actionPanTools setObject:importDescription forKey:importName];
    }
    [importTextureKeys addObject:importName];
  }

  // Calculate page size.
  NSUInteger pageSize = [self FL_constructionToolbarPageSize];

  // Select tools for specified page.
  NSUInteger importTextureKeysCount = [importTextureKeys count];
  NSMutableArray *textureKeys = [NSMutableArray arrayWithObject:@"main"];
  [_constructionToolbarState.navigationTools addObject:@"main"];

  // note: [begin,end)
  const NSUInteger importsPerMiddlePage = pageSize - 3;
  // note: First page has room for an extra import, so add one to index.
  // (Subtract it out below if we're on the first page.)
  NSUInteger beginIndex = importsPerMiddlePage * (NSUInteger)page + 1;
  NSUInteger endIndex = beginIndex + importsPerMiddlePage;
  if (page == 0) {
    --beginIndex;
  } else {
    [textureKeys addObject:@"previous"];
    [_constructionToolbarState.navigationTools addObject:@"previous"];
  }
  // note: Last page has room for an extra import, so add one if we're
  // indexed at the next-to-last; also, stay in bounds for partial last
  // page.
  if (endIndex + 1 >= importTextureKeysCount) {
    endIndex = importTextureKeysCount;
  }
  // note: The page might end up with no imports if the requested page is too
  // large.  Caller beware.
  for (NSUInteger i = beginIndex; i < endIndex; ++i) {
    [textureKeys addObject:[importTextureKeys objectAtIndex:i]];
  }
  if (endIndex < importTextureKeysCount) {
    [textureKeys addObject:@"next"];
    [_constructionToolbarState.navigationTools addObject:@"next"];
  }

  // Set tools.
  [_constructionToolbarState.toolbarNode setToolsWithTextureKeys:textureKeys
                                                           store:[HLTextureStore sharedStore]
                                                       rotations:nil
                                                         offsets:nil
                                                       animation:animation];
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
  CGFloat borderSize = _constructionToolbarState.toolbarNode.borderSize;
  CGFloat toolSeparatorSize = _constructionToolbarState.toolbarNode.toolSeparatorSize;
  NSUInteger pageSize = (NSUInteger)((_constructionToolbarState.toolbarNode.size.width + toolSeparatorSize - 2.0f * borderSize) / (FLMainToolbarToolHeight - 2.0f * borderSize + toolSeparatorSize));
  // note: Need main/previous/next buttons, and then anything less than two remaining is silly.
  if (pageSize < 5) {
    pageSize = 5;
  }
  return pageSize;
}

- (void)FL_simulationToolbarSetVisible:(BOOL)visible
{
  if (!_simulationToolbarState.toolbarNode) {
    _simulationToolbarState.toolbarNode = [[HLToolbarNode alloc] init];
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
  _simulationToolbarState.toolbarNode.size = CGSizeMake(self.size.width, FLMainToolbarToolHeight);
  [self FL_simulationToolbarUpdateTools];
}

- (void)FL_simulationToolbarUpdateTools
{
  NSMutableArray *textureKeys = [NSMutableArray array];
  [textureKeys addObject:@"menu"];
  if (_simulationRunning) {
    [textureKeys addObject:@"pause"];
  } else {
    [textureKeys addObject:@"play"];
  }
  NSString *speedTool;
  if (_simulationSpeed <= 1) {
    speedTool = @"ff";
  } else {
    speedTool = @"fff";
  }
  [textureKeys addObject:speedTool];
  [textureKeys addObject:@"center"];
  [_simulationToolbarState.toolbarNode setToolsWithTextureKeys:textureKeys
                                                         store:[HLTextureStore sharedStore]
                                                     rotations:nil
                                                       offsets:nil
                                                      animation:HLToolbarNodeAnimationNone];
  [_simulationToolbarState.toolbarNode setHighlight:(_simulationSpeed > 0) forTool:speedTool];
}

- (void)FL_messageShow:(NSString *)message
{
  if (!_messageState.messageNode) {
    _messageState.messageNode = [SKSpriteNode spriteNodeWithColor:[UIColor colorWithWhite:0.0f alpha:0.5f] size:CGSizeZero];
    [self FL_messageUpdateGeometry];
  }

  if (!_messageState.labelNode) {
    SKLabelNode *labelNode = [SKLabelNode labelNodeWithFontNamed:@"Courier"];
    labelNode.fontColor = [UIColor whiteColor];
    labelNode.fontSize = 14.0f;
    labelNode.position = CGPointMake(0.0f, -5.0f);
    _messageState.labelNode = labelNode;
    [_messageState.messageNode addChild:labelNode];
  }

  _messageState.labelNode.text = message;

  if (!_messageState.messageNode.parent) {
    [_hudNode addChild:_messageState.messageNode];
    CGPoint messageNodePosition = _messageState.messageNode.position;
    messageNodePosition.x = self.size.width;
    _messageState.messageNode.position = messageNodePosition;
    SKAction *slideIn = [SKAction moveToX:0.0f duration:0.1f];
    SKAction *wait = [SKAction waitForDuration:2.0f];
    SKAction *slideOut = [SKAction moveToX:-self.size.width duration:0.1f];
    SKAction *remove = [SKAction removeFromParent];
    SKAction *show = [SKAction sequence:@[slideIn, wait, slideOut, remove ]];
    [_messageState.messageNode runAction:show withKey:@"show"];
  } else {
    [_messageState.messageNode removeActionForKey:@"show"];
    SKAction *wait = [SKAction waitForDuration:2.0f];
    SKAction *slideOut = [SKAction moveToX:-self.size.width duration:0.1f];
    SKAction *remove = [SKAction removeFromParent];
    SKAction *show = [SKAction sequence:@[ wait, slideOut, remove ]];
    [_messageState.messageNode runAction:show withKey:@"show"];
  }
}

- (void)FL_messageUpdateGeometry
{
  _messageState.messageNode.position = CGPointMake(0.0f, [self FL_messagePositionY]);
  _messageState.messageNode.size = CGSizeMake(self.size.width, FLMessageHeight);
}

- (CGFloat)FL_messagePositionY
{
  CGFloat bottom = (FLMessageHeight - self.size.height) / 2.0f;
  if (_constructionToolbarState.toolbarNode) {
    bottom += _constructionToolbarState.toolbarNode.size.height;
  }
  return bottom + FLMessageSpacer;
}

- (void)FL_trackSelect:(NSSet *)segmentNodes
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
    SKSpriteNode *selectionSquare = [_trackSelectState.visualSquareNodes objectForKey:[NSValue valueWithPointer:(void *)segmentNode]];
    if (!selectionSquare) {
      selectionSquare = [SKSpriteNode spriteNodeWithColor:[UIColor colorWithWhite:0.2f alpha:1.0f]
                                                     size:CGSizeMake(FLSegmentArtSizeBasic * FLTrackArtScale,
                                                                     FLSegmentArtSizeBasic * FLTrackArtScale)];
      selectionSquare.blendMode = SKBlendModeAdd;
      [_trackSelectState.visualSquareNodes setObject:selectionSquare forKey:[NSValue valueWithPointer:(void *)segmentNode]];
      [_trackSelectState.visualParentNode addChild:selectionSquare];
    }
    selectionSquare.position = segmentNode.position;
  }
  if (_trackSelectState.selectedSegments) {
    [_trackSelectState.selectedSegments unionSet:segmentNodes];
  } else {
    _trackSelectState.selectedSegments = [NSMutableSet setWithSet:segmentNodes];
  }
}

- (void)FL_trackSelectErase:(FLSegmentNode *)segmentNode
{
  if (!_trackSelectState.selectedSegments) {
    return;
  }

  SKSpriteNode *selectionSquare = [_trackSelectState.visualSquareNodes objectForKey:[NSValue valueWithPointer:(void *)segmentNode]];
  if (selectionSquare) {
    if ([_trackSelectState.visualSquareNodes count] == 1) {
      _trackSelectState.selectedSegments = nil;
      _trackSelectState.visualSquareNodes = nil;
    } else {
      [_trackSelectState.selectedSegments removeObject:segmentNode];
      [_trackSelectState.visualSquareNodes removeObjectForKey:[NSValue valueWithPointer:(void *)segmentNode]];
    }
    [selectionSquare removeFromParent];
  }
}

- (void)FL_trackSelectClear
{
  _trackSelectState.selectedSegments = nil;
  _trackSelectState.visualSquareNodes = nil;
  [_trackSelectState.visualParentNode removeAllChildren];
}

- (BOOL)FL_trackSelected:(FLSegmentNode *)segmentNode
{
  if (!_trackSelectState.selectedSegments) {
    return NO;
  }
  return [_trackSelectState.selectedSegments containsObject:segmentNode];
}

- (BOOL)FL_trackSelectedNone
{
  return (_trackSelectState.selectedSegments == nil);
}

- (void)FL_trackConflictShow:(FLSegmentNode *)segmentNode
{
  SKSpriteNode *conflictNode = [SKSpriteNode spriteNodeWithColor:[UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:1.0f]
                                                            size:CGSizeMake(FLSegmentArtSizeBasic * FLTrackArtScale,
                                                                            FLSegmentArtSizeBasic * FLTrackArtScale)];
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
- (void)FL_trackMoveBeganWithNodes:(NSSet *)segmentNodes location:(CGPoint)worldLocation completion:(void (^)(BOOL placed))completion
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
  _trackMoveState.completion = completion;

  _trackGrid->convert(worldLocation, &_trackMoveState.beganGridX, &_trackMoveState.beganGridY);
  _trackMoveState.attempted = NO;
  _trackMoveState.attemptedTranslationGridX = 0;
  _trackMoveState.attemptedTranslationGridY = 0;
  FLSegmentNode *anySegmentNode = [segmentNodes anyObject];
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
    _trackMoveState.cursorNode.alpha = 0.4f;
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

- (void)FL_trackMoveEndedWithLocation:(CGPoint)worldLocation
{
  if (!_trackMoveState.segmentNodes) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Ended track move, but track move not begun."];
  }
  [self FL_trackMoveEndedCommonWithLocation:worldLocation];
  [_trackMoveState.cursorNode removeAllChildren];
  [_trackMoveState.cursorNode removeFromParent];
  if (_trackMoveState.placed) {
    [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-clickity-2.caf" waitForCompletion:NO]];
  }
}

- (void)FL_trackMoveCancelledWithLocation:(CGPoint)worldLocation
{
  if (!_trackMoveState.segmentNodes) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Cancelled track move, but track move not begun."];
  }
  [self FL_trackMoveEndedCommonWithLocation:worldLocation];
  [_trackMoveState.cursorNode removeAllChildren];
  [_trackMoveState.cursorNode removeFromParent];
}

- (void)FL_trackMoveEndedCommonWithLocation:(CGPoint)worldLocation
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
  _trackMoveState.segmentNodes = nil;
  _trackMoveState.completion = nil;
}

- (void)FL_trackMoveUpdateWithLocation:(CGPoint)worldLocation
{
  CGFloat segmentSize = _trackGrid->segmentSize();

  // Update cursor.
  //
  // note: Consider having cursor snap to grid alignment.
  _trackMoveState.cursorNode.position = CGPointMake(worldLocation.x - _trackMoveState.beganGridX * segmentSize,
                                                    worldLocation.y - _trackMoveState.beganGridY * segmentSize);

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
    if (occupyingSegmentNode && ![_trackMoveState.segmentNodes containsObject:occupyingSegmentNode]) {
      [self FL_trackConflictShow:occupyingSegmentNode];
      hasConflict = YES;
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
    segmentNode.position = CGPointMake(segmentNode.position.x + deltaTranslationGridX * segmentSize,
                                       segmentNode.position.y + deltaTranslationGridY * segmentSize);
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
    _trackEditMenuState.editMenuNode = [[HLToolbarNode alloc] initWithSize:CGSizeMake(0.0f, 42.0f)];
    _trackEditMenuState.editMenuNode.zPosition = FLZPositionWorldOverlay;
    _trackEditMenuState.editMenuNode.anchorPoint = CGPointMake(0.5f, 0.0f);
    _trackEditMenuState.editMenuNode.automaticWidth = YES;
    _trackEditMenuState.editMenuNode.automaticHeight = NO;
    _trackEditMenuState.editMenuNode.borderSize = 3.0f;
    _trackEditMenuState.editMenuNode.toolSeparatorSize = 3.0f;
  }

  // Collect information about selected segments.
  NSSet *segmentNodes = _trackSelectState.selectedSegments;
  CGFloat segmentsPositionTop;
  CGFloat segmentsPositionBottom;
  CGFloat segmentsPositionLeft;
  CGFloat segmentsPositionRight;
  [self FL_getSegmentsExtremes:segmentNodes left:&segmentsPositionLeft right:&segmentsPositionRight top:&segmentsPositionTop bottom:&segmentsPositionBottom];
  BOOL hasSwitch = NO;
  for (FLSegmentNode *segmentNode in segmentNodes) {
    if (segmentNode.switchPathId != FLSegmentSwitchPathIdNone) {
      hasSwitch = YES;
      break;
    }
  }

  // Update tool list according to selection.
  NSUInteger toolCount = [_trackEditMenuState.editMenuNode toolCount];
  if ((hasSwitch && toolCount != 4)
      || (!hasSwitch && toolCount != 3)) {
    if (!hasSwitch) {
      [_trackEditMenuState.editMenuNode setToolsWithTextureKeys:@[ @"rotate-ccw", @"delete", @"rotate-cw" ]
                                                          store:[HLTextureStore sharedStore]
                                                      rotations:nil
                                                        offsets:nil
                                                      animation:HLToolbarNodeAnimationNone];
    } else {
      [_trackEditMenuState.editMenuNode setToolsWithTextureKeys:@[ @"rotate-ccw", @"toggle-switch", @"delete", @"rotate-cw" ]
                                                          store:[HLTextureStore sharedStore]
                                                      rotations:nil
                                                        offsets:nil
                                                      animation:HLToolbarNodeAnimationNone];
    }
  }

  // Show menu.
  const CGFloat FLTrackEditMenuBottomPad = 20.0f;
  if (!_trackEditMenuState.showing) {
    [_worldNode addChild:_trackEditMenuState.editMenuNode];
    _trackEditMenuState.showing = YES;
  }
  CGFloat segmentsPositionMidX = (segmentsPositionLeft + segmentsPositionRight) / 2.0f;
  CGFloat segmentsPositionMidY = (segmentsPositionBottom + segmentsPositionTop) / 2.0f;
  CGPoint position = CGPointMake(segmentsPositionMidX, segmentsPositionTop + _trackGrid->segmentSize() / 2.0f + FLTrackEditMenuBottomPad);
  CGPoint origin = CGPointMake(segmentsPositionMidX, segmentsPositionMidY);
  CGFloat fullScale = [self FL_trackEditMenuScaleForWorld];
  [_trackEditMenuState.editMenuNode showWithOrigin:origin
                                     finalPosition:position
                                         fullScale:fullScale
                                          animated:animated];
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
  CGFloat editMenuScale = [self FL_trackEditMenuScaleForWorld];
  _trackEditMenuState.editMenuNode.xScale = editMenuScale;
  _trackEditMenuState.editMenuNode.yScale = editMenuScale;
}

- (CGFloat)FL_trackEditMenuScaleForWorld
{
  // note: The track edit menu scales inversely to the world, but perhaps at a different rate.
  // A value of 1.0f means the edit menu will always maintain the same screen size no matter
  // what the scale of the world.  Values less than one mean less-dramatic scaling than
  // the world, and vice versa.
  const CGFloat FLTrackEditMenuScaleFactor = 0.5f;
  return 1.0f / pow(_worldNode.xScale, FLTrackEditMenuScaleFactor);
}

- (SKShapeNode *)FL_linkDrawFromLocation:(CGPoint)fromWorldLocation toLocation:(CGPoint)toWorldLocation
{
  SKShapeNode *linkNode = [[SKShapeNode alloc] init];
  linkNode.position = CGPointZero;

  CGMutablePathRef linkPath = CGPathCreateMutable();
  CGPathMoveToPoint(linkPath, NULL, fromWorldLocation.x, fromWorldLocation.y);
  CGPathAddLineToPoint(linkPath, NULL, toWorldLocation.x, toWorldLocation.y);
  linkNode.path = linkPath;
  CGPathRelease(linkPath);

  linkNode.strokeColor = [UIColor redColor];
  linkNode.glowWidth = 2.0f;
  [_linksNode addChild:linkNode];

  return linkNode;
}

- (void)FL_linkRedrawForSegment:(FLSegmentNode *)segmentNode
{
  vector<FLSegmentNode *> links;
  _links.get(segmentNode, &links);
  for (auto link : links) {
    SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:segmentNode.switchPosition toLocation:link.switchPosition];
    _links.set(segmentNode, link, connectorNode);
  }
}

- (void)FL_linkEditBeganWithNode:(FLSegmentNode *)segmentNode
{
  // note: Precondition is that the passed node has a switch.
  _linkEditState.beginNode = segmentNode;

  // Display a begin-segment highlight.
  SKShapeNode *highlightNode = [[SKShapeNode alloc] init];
  highlightNode.position = segmentNode.position;
  CGFloat highlightSideSize = FLSegmentArtSizeFull * FLTrackArtScale;
  CGPathRef highlightPath = CGPathCreateWithRect(CGRectMake(-highlightSideSize / 2.0f,
                                                            -highlightSideSize / 2.0f,
                                                            highlightSideSize,
                                                            highlightSideSize),
                                                 NULL);
  highlightNode.strokeColor = [UIColor redColor];
  highlightNode.glowWidth = 2.0f;
  highlightNode.path = highlightPath;
  CGPathRelease(highlightPath);
  [_linksNode addChild:highlightNode];
  _linkEditState.beginHighlightNode = highlightNode;

  // note: No connector yet, until we move a bit.
  _linkEditState.connectorNode = nil;

  // note: No ending node or highlight yet.
  _linkEditState.endNode = nil;
}

- (void)FL_linkEditChangedWithLocation:(CGPoint)worldLocation
{
  // note: Begin-segment highlight stays the same.

  // Display an end-segment highlight if the current node has a switch.
  FLSegmentNode *endNode = trackGridConvertGet(*_trackGrid, worldLocation);
  if (endNode && endNode.switchPathId != FLSegmentSwitchPathIdNone) {
    if (endNode != _linkEditState.endNode) {
      [_linkEditState.endHighlightNode removeFromParent];
      SKShapeNode *highlightNode = [[SKShapeNode alloc] init];
      highlightNode.position = endNode.position;
      CGFloat highlightSideSize = FLSegmentArtSizeFull * FLTrackArtScale;
      CGPathRef highlightPath = CGPathCreateWithRect(CGRectMake(-highlightSideSize / 2.0f,
                                                                -highlightSideSize / 2.0f,
                                                                highlightSideSize,
                                                                highlightSideSize),
                                                     NULL);
      highlightNode.path = highlightPath;
      highlightNode.strokeColor = [UIColor redColor];
      highlightNode.glowWidth = 2.0f;
      CGPathRelease(highlightPath);
      [_linksNode addChild:highlightNode];
      _linkEditState.endHighlightNode = highlightNode;
      _linkEditState.endNode = endNode;
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
  CGPoint endSwitchPosition = (_linkEditState.endNode ? _linkEditState.endNode.switchPosition : worldLocation);
  SKShapeNode *connectorNode = [self FL_linkDrawFromLocation:beginSwitchPosition toLocation:endSwitchPosition];
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
    } else {
      SKAction *blinkAction = [SKAction sequence:@[ [SKAction fadeOutWithDuration:FLBlinkHalfCycleDuration],
                                                    [SKAction fadeInWithDuration:FLBlinkHalfCycleDuration],
                                                    [SKAction fadeOutWithDuration:FLBlinkHalfCycleDuration],
                                                    [SKAction fadeInWithDuration:FLBlinkHalfCycleDuration] ]];
      [_linkEditState.connectorNode runAction:blinkAction];
      _links.insert(_linkEditState.beginNode, _linkEditState.endNode, _linkEditState.connectorNode);
      preserveConnectorNode = YES;
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

  NSLog(@"%lu links", _links.size());
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

- (void)FL_linkSetSwitch:(FLSegmentNode *)segmentNode pathId:(int)pathId animated:(BOOL)animated
{
  [segmentNode setSwitchPathId:pathId animated:animated];
  vector<FLSegmentNode *> links;
  _links.get(segmentNode, &links);
  for (auto link : links) {
    [link setSwitchPathId:pathId animated:animated];
  }
}

- (void)FL_linkToggleSwitch:(FLSegmentNode *)segmentNode animated:(BOOL)animated
{
  int pathId = [segmentNode toggleSwitchPathIdAnimated:animated];
  vector<FLSegmentNode *> links;
  _links.get(segmentNode, &links);
  for (auto link : links) {
    [link setSwitchPathId:pathId animated:animated];
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
    [segmentNode runAction:[SKAction rotateToAngle:(newRotationQuarters * (CGFloat)M_PI_2) duration:FLTrackRotateDuration shortestUnitArc:YES] completion:^{
      [self FL_linkRedrawForSegment:segmentNode];
    }];
    [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-click-1.caf" waitForCompletion:NO]];
  }
}

- (void)FL_trackRotateSegments:(NSSet *)segmentNodes rotateBy:(int)rotateBy animated:(BOOL)animated
{
  if ([segmentNodes count] == 1) {
    [self FL_trackRotateSegment:[segmentNodes anyObject] rotateBy:rotateBy animated:animated];
    return;
  }

  // Collect information about segments.
  CGFloat segmentsPositionTop;
  CGFloat segmentsPositionBottom;
  CGFloat segmentsPositionLeft;
  CGFloat segmentsPositionRight;
  [self FL_getSegmentsExtremes:segmentNodes left:&segmentsPositionLeft right:&segmentsPositionRight top:&segmentsPositionTop bottom:&segmentsPositionBottom];
  // note: isSymmetryRotation just in terms of the bounding box, which will be the same
  // after the rotation as before the rotation.
  BOOL isSymmetricRotation = (rotateBy % 2 == 0) || (fabs(segmentsPositionRight - segmentsPositionLeft - segmentsPositionTop + segmentsPositionBottom) < 0.001f);

  // Calculate a good pivot point for the group of segments.
  CGPoint pivot = CGPointMake((segmentsPositionLeft + segmentsPositionRight) / 2.0f,
                              (segmentsPositionBottom + segmentsPositionTop) / 2.0f);
  if (!isSymmetricRotation) {
    CGFloat segmentSize = _trackGrid->segmentSize();
    int widthUnits = int((segmentsPositionRight - segmentsPositionLeft + 0.00001f) / segmentSize);
    int heightUnits = int((segmentsPositionTop - segmentsPositionBottom + 0.00001f) / segmentSize);
    if (widthUnits % 2 != heightUnits % 2) {
      // note: Choose a good nearby pivot.  Later we'll check for conflict, where a good pivot will
      // mean a pivot that allows the rotation to occur.  But even if this selection is rotating
      // on a conflict-free field, we still need a good pivot, to wit, such that rotating four times will
      // bring us back to the original position.  For that we need state, at least until the selection
      // changes.  Well, okay, let's steal some state that already exists: The zRotation of the
      // first segment in the set.
      CGPoint offsetPivot = CGPointMake(segmentSize / 2.0f, 0.0f);
      int normalRotationQuarters = normalizeRotationQuarters([[segmentNodes anyObject] zRotationQuarters]);
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
    if (occupyingSegmentNode && ![segmentNodes containsObject:occupyingSegmentNode]) {
      [self FL_trackConflictShow:occupyingSegmentNode];
      hasConflict = YES;
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

- (void)FL_trackEraseSegments:(NSSet *)segmentNodes animated:(BOOL)animated
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
    SKEmitterNode *sleeperDestruction = [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:@"sleeperDestruction" ofType:@"sks"]];
    SKEmitterNode *railDestruction = [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:@"railDestruction" ofType:@"sks"]];
    // note: This kind of thing makes me think having an FLTrackArtScale is a bad idea.  Resample the art instead.
    sleeperDestruction.xScale = FLTrackArtScale;
    sleeperDestruction.yScale = FLTrackArtScale;
    railDestruction.xScale = FLTrackArtScale;
    railDestruction.yScale = FLTrackArtScale;
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

@end
