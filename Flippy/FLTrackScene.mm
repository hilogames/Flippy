//
//  FLTrackScene.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLTrackScene.h"

#import "FLTextureStore.h"
#import "FLToolbarNode.h"
#include "QuadTree.h"

using namespace HLCommon;

static const CGFloat FLWorldScaleMin = 0.125f;
static const CGFloat FLWorldScaleMax = 2.0f;
static const CGSize FLWorldSize = { 3000.0f, 3000.0f };

// Main layers.
static const CGFloat FLZPositionWorld = 0.0f;
static const CGFloat FLZPositionHud = 10.0f;
// World sublayers.
static const CGFloat FLZPositionTerrain = 0.0f;
static const CGFloat FLZPositionTrack = 1.0f;
static const CGFloat FLZPositionTrain = 2.0f;
// World-Track sublayers.
static const CGFloat FLZPositionTrackSelect = 0.0f;
static const CGFloat FLZPositionTrackPlaced = 0.1f;
static const CGFloat FLZPositionTrackOverlay = 0.2f;

#pragma mark -
#pragma mark Helpers

// Helpers are functional components of the scene split into classes;
// these are considered to have private access to the scene.

@interface FLTrackScene (Helper)
- (void)FL_trackGridEraseGridX:(int)gridX gridY:(int)gridY animated:(BOOL)animated;
@end

@interface FLTrackEditMenuHelper : NSObject
@property (nonatomic, strong) FLToolbarNode *editMenuNode;
- (id)initWithScene:(SKScene *)scene;
- (void)showOnTrack:(SKNode *)trackNode atSegment:(SKSpriteNode *)segmentNode gridX:(int)gridX gridY:(int)gridY animated:(BOOL)animated;
- (void)hideAnimated:(BOOL)animated;
- (void)scaleToWorld:(SKNode *)worldNode;
- (void)handleTap:(UIGestureRecognizer *)gestureRecognizer;
@end

#pragma mark -
#pragma mark States

// States are functional components of the scene; the data is encapsulated in
// a simple public struct, and the associated functionality is implemented in
// private methods of the scene.

struct FLMainToolbarState
{
  FLMainToolbarState() : toolbarNode(nil), toolInUseNode(nil) {}
  FLToolbarNode *toolbarNode;
  SKSpriteNode *toolInUseNode;
};

struct FLTrackSelectState
{
  FLTrackSelectState() : visualSelectionNode(nil), selected(NO) {}
  SKSpriteNode *visualSelectionNode;
  BOOL selected;
  int gridX;
  int gridY;
};

struct FLTrackMoveState
{
  FLTrackMoveState() : segmentMoving(nil), segmentRemoving(nil) {}
  SKSpriteNode *segmentMoving;
  SKSpriteNode *segmentRemoving;
};

enum FLPanType { FLPanTypeNone, FLPanTypeWorld, FLPanTypeTrackMove };

struct FLGestureRecognizerState
{
  FLGestureRecognizerState() {}
  CGPoint gestureFirstTouchLocation;
  FLPanType panType;
  CGPoint pinchZoomCenter;
};

enum FLCameraMode { FLCameraModeManual, FLCameraModeFollowTrain };

#pragma mark -
#pragma mark Scene

@implementation FLTrackScene
{
  BOOL _contentCreated;

  SKNode *_worldNode;
  SKNode *_trackNode;
  SKSpriteNode *_trainNode;
  SKNode *_hudNode;

  FLGestureRecognizerState _gestureRecognizerState;
  UITapGestureRecognizer *_tapRecognizer;
  UILongPressGestureRecognizer *_longPressRecognizer;
  UIPanGestureRecognizer *_panRecognizer;
  UIPinchGestureRecognizer *_pinchRecognizer;

  CGFloat _artSegmentSizeFull;
  CGFloat _artSegmentSizeBasic;
  CGFloat _artSegmentDrawnTrackNormalWidth;
  CGFloat _gridSize;
  CGFloat _artScale;

  FLCameraMode _cameraMode;

  QuadTree<SKSpriteNode *> _trackGrid;

  FLMainToolbarState _mainToolbarState;
  FLTrackSelectState _trackSelectState;
  FLTrackMoveState _trackMoveState;

  FLTrackEditMenuHelper *_trackEditMenuHelper;
}

- (id)initWithSize:(CGSize)size
{
  self = [super initWithSize:size];
  if (self) {
    _artSegmentSizeFull = 54.0f;
    _artSegmentSizeBasic = 36.0f;
    _artSegmentDrawnTrackNormalWidth = 14.0f;  // the pixel width of the drawn tracks (widest: sleepers) when orthagonal
    _artScale = 2.0f;
    _gridSize = _artSegmentSizeBasic * _artScale;
    _cameraMode = FLCameraModeFollowTrain;
    _trackEditMenuHelper = [[FLTrackEditMenuHelper alloc] initWithScene:self];
  }
  return self;
}

- (void)didMoveToView:(SKView *)view
{
  if (!_contentCreated) {
    [self FL_createSceneContents];
    _contentCreated = YES;
  }

  _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleWorldTap:)];
  _tapRecognizer.delegate = self;
  _tapRecognizer.cancelsTouchesInView = NO;
  [view addGestureRecognizer:_tapRecognizer];

  _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleWorldLongPress:)];
  _longPressRecognizer.delegate = self;
  _longPressRecognizer.cancelsTouchesInView = NO;
  [view addGestureRecognizer:_longPressRecognizer];

  _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleWorldPan:)];
  _panRecognizer.delegate = self;
  _panRecognizer.maximumNumberOfTouches = 1;
  _panRecognizer.cancelsTouchesInView = NO;
  [view addGestureRecognizer:_panRecognizer];

  _pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleWorldPinch:)];
  _pinchRecognizer.delegate = self;
  _pinchRecognizer.cancelsTouchesInView = NO;
  [view addGestureRecognizer:_pinchRecognizer];

  [self FL_preloadSound];
}

- (void)willMoveFromView:(SKView *)view
{
  [view removeGestureRecognizer:_tapRecognizer];
  [view removeGestureRecognizer:_longPressRecognizer];
  [view removeGestureRecognizer:_panRecognizer];
  [view removeGestureRecognizer:_pinchRecognizer];
}

- (void)FL_createSceneContents
{
  self.backgroundColor = [SKColor colorWithRed:0.4 green:0.6 blue:0.0 alpha:1.0];
  self.anchorPoint = CGPointMake(0.5f, 0.5f);

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
  _worldNode.name = @"world";
  _worldNode.zPosition = FLZPositionWorld;
  [self addChild:_worldNode];

  UIImage *terrainTileImage = [UIImage imageNamed:@"grass.png"];
  CGRect terrainTileRect = CGRectMake(0.0f, 0.0f, terrainTileImage.size.width, terrainTileImage.size.height);
  CGImageRef terrainTileRef = [terrainTileImage CGImage];
  // TODO: Begin context with scaling options for Retina display.
  UIGraphicsBeginImageContext(FLWorldSize);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextDrawTiledImage(context, terrainTileRect, terrainTileRef);
  UIImage *terrainImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  SKTexture *terrainTexture = [SKTexture textureWithCGImage:[terrainImage CGImage]];
  SKSpriteNode *terrainNode = [SKSpriteNode spriteNodeWithTexture:terrainTexture];
  terrainNode.zPosition = FLZPositionTerrain;
  // noob: Using a tip to use replace blend mode for opaque sprites, but since
  // JPEGs don't have an alpha channel in the source, does this really do anything
  // for JPEGs?
  terrainNode.blendMode = SKBlendModeReplace;
  [_worldNode addChild:terrainNode];

  // noob: See note near _worldNode above: We will probaly want to add/remove near/distant
  // child nodes based on our current camera location in the world.  Use our QuadTree
  // to implement, I expect.
  _trackNode = [SKNode node];
  _trackNode.name = @"track";
  _trackNode.zPosition = FLZPositionTrack;
  [_worldNode addChild:_trackNode];

  _trainNode = [SKSpriteNode spriteNodeWithColor:[UIColor redColor] size:CGSizeMake(20.0f, 20.0f)];
  _trainNode.name = @"train";
  _trainNode.zPosition = FLZPositionTrain;
  SKAction *trainMove1 = [SKAction moveByX:200.0f y:0.0f duration:8.0];
  SKAction *trainMove2 = [SKAction moveByX:0.0f y:200.0f duration:8.0];
  SKAction *trainMove3 = [SKAction moveByX:-200.0f y:0.0f duration:8.0];
  SKAction *trainMove4 = [SKAction moveByX:0.0f y:-200.0f duration:8.0];
  SKAction *trainLap = [SKAction sequence:@[ trainMove1, trainMove2, trainMove3, trainMove4 ]];
  [_trainNode runAction:[SKAction repeatActionForever:trainLap]];
  [_worldNode addChild:_trainNode];

  // The HUD node contains everything pinned to the scene window, outside the world.
  _hudNode = [SKNode node];
  _hudNode.name = @"hud";
  _hudNode.zPosition = FLZPositionHud;
  [self addChild:_hudNode];

  // Create other content.

  [self FL_mainToolbarSetVisible:YES];
}

- (void)didSimulatePhysics
{
  switch (_cameraMode) {
    case FLCameraModeFollowTrain: {
      // note: Set world position based on train position.  Note that the
      // train is in the world, but the world is in the scene, so convert.
      CGPoint trainSceneLocation = [self convertPoint:_trainNode.position fromNode:_worldNode];
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
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
}

#pragma mark -
#pragma mark UIGestureRecognizerDelegate

- (void)handleWorldTap:(UIGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint trackLocation = [_trackNode convertPoint:sceneLocation fromNode:self];

  int gridX = int(floorf(trackLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(trackLocation.y / _gridSize + 0.5f));

  int selectedGridX;
  int selectedGridY;
  if ([self FL_trackSelectGetCurrentGridX:&selectedGridX gridY:&selectedGridY]
      && selectedGridX == gridX
      && selectedGridY == gridY) {
    [self FL_trackSelectClear];
    [_trackEditMenuHelper hideAnimated:YES];
  } else {
    [self FL_trackSelectGridX:gridX gridY:gridY];
    SKSpriteNode *segmentNode = _trackGrid.get(gridX, gridY, nil);
    if (segmentNode) {
      [_trackEditMenuHelper showOnTrack:_trackNode atSegment:segmentNode gridX:gridX gridY:gridY animated:YES];
    } else {
      [_trackEditMenuHelper hideAnimated:YES];
    }
  }
}

- (void)handleWorldLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint trackLocation = [_trackNode convertPoint:sceneLocation fromNode:self];

  int gridX = int(floorf(trackLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(trackLocation.y / _gridSize + 0.5f));

  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
    [self FL_trackSelectGridX:gridX gridY:gridY];
    SKSpriteNode *segmentNode = _trackGrid.get(gridX, gridY, nil);
    if (segmentNode) {
      [_trackEditMenuHelper showOnTrack:_trackNode atSegment:segmentNode gridX:gridX gridY:gridY animated:YES];
    }
  }
}

- (void)handleWorldPan:(UIPanGestureRecognizer *)gestureRecognizer
{
  _cameraMode = FLCameraModeManual;

  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

    // Determine type of pan.
    //
    // note: The decision is based on the location of the first touch in the gesture, not the
    // current location (when the gesture is fully identified); they can be quite different.
    // (We could also set the initial translation of the pan based on the former, but instead we
    // let the gesture recognizer do its thing, assuming that's the interface standard.)
    CGPoint viewLocation = _gestureRecognizerState.gestureFirstTouchLocation;
    CGPoint sceneLocation = [self convertPointFromView:viewLocation];
    CGPoint trackLocation = [_trackNode convertPoint:sceneLocation fromNode:self];
    int gridX = int(floorf(trackLocation.x / _gridSize + 0.5f));
    int gridY = int(floorf(trackLocation.y / _gridSize + 0.5f));
    int selectedGridX;
    int selectedGridY;
    if ([self FL_trackSelectGetCurrentGridX:&selectedGridX gridY:&selectedGridY]
        && selectedGridX == gridX
        && selectedGridY == gridY) {
      SKSpriteNode *selectedSegmentNode = _trackGrid.get(gridX, gridY, nil);
      if (selectedSegmentNode) {
        // Pan begins inside a selected track segment.
        _gestureRecognizerState.panType = FLPanTypeTrackMove;
        [selectedSegmentNode removeFromParent];
        _trackGrid.erase(gridX, gridY);
        [self FL_trackMoveBeganWithNode:selectedSegmentNode gridX:gridX gridY:gridY];
      } else {
        // Pan begins inside a track selection that has no segment.
        _gestureRecognizerState.panType = FLPanTypeNone;
      }
    } else {
      // Pan begins not inside a selected track segment.  Note that this currently means
      // it must be in the world somewhere, since touches outside the world (e.g. on the
      // HUD layer) are blocked from the gesture recognizer.
      _gestureRecognizerState.panType = FLPanTypeWorld;
    }

  } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {

    switch (_gestureRecognizerState.panType) {
      case FLPanTypeTrackMove: {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        CGPoint trackLocation = [_trackNode convertPoint:sceneLocation fromNode:self];
        int gridX = int(floorf(trackLocation.x / _gridSize + 0.5f));
        int gridY = int(floorf(trackLocation.y / _gridSize + 0.5f));
        [self FL_trackMoveContinuedWithGridX:gridX gridY:gridY];
        break;
      }
      case FLPanTypeWorld: {
        CGPoint translation = [gestureRecognizer translationInView:self.view];
        CGPoint worldPosition = CGPointMake(_worldNode.position.x + translation.x / self.xScale,
                                            _worldNode.position.y - translation.y / self.yScale);
        _worldNode.position = worldPosition;
        [gestureRecognizer setTranslation:CGPointZero inView:self.view];
        break;
      }
      default:
        // note: This means the pan gesture was not actually doing anything,
        // but was allowed to continue.
        break;
    }

  } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {

    switch (_gestureRecognizerState.panType) {
      case FLPanTypeTrackMove: {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        CGPoint trackLocation = [_trackNode convertPoint:sceneLocation fromNode:self];
        int gridX = int(floorf(trackLocation.x / _gridSize + 0.5f));
        int gridY = int(floorf(trackLocation.y / _gridSize + 0.5f));
        [self FL_trackMoveEndedWithGridX:gridX gridY:gridY];
        break;
      }
      case FLPanTypeWorld:
        // note: Nothing to do here.
        break;
      default:
        // note: This means the pan gesture was not actually doing anything,
        // but was allowed to continue.
        break;
    }

  } else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {

    switch (_gestureRecognizerState.panType) {
      case FLPanTypeTrackMove: {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        CGPoint trackLocation = [_trackNode convertPoint:sceneLocation fromNode:self];
        int gridX = int(floorf(trackLocation.x / _gridSize + 0.5f));
        int gridY = int(floorf(trackLocation.y / _gridSize + 0.5f));
        [self FL_trackMoveCancelledWithGridX:gridX gridY:gridY];
        break;
      }
      case FLPanTypeWorld:
        // note: Nothing to do here.
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
    _gestureRecognizerState.pinchZoomCenter = CGPointZero;
    if (_cameraMode == FLCameraModeManual) {
      CGPoint centerViewLocation = [gestureRecognizer locationInView:self.view];
      _gestureRecognizerState.pinchZoomCenter = [self convertPointFromView:centerViewLocation];
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
  [_trackEditMenuHelper scaleToWorld:_worldNode];
  CGFloat scaleFactor = worldScaleCurrent / handlePinchWorldScaleBegin;

  // Zoom around previously-chosen center point.
  CGPoint worldPosition;
  worldPosition.x = (handlePinchWorldPositionBegin.x - _gestureRecognizerState.pinchZoomCenter.x) * scaleFactor + _gestureRecognizerState.pinchZoomCenter.x;
  worldPosition.y = (handlePinchWorldPositionBegin.y - _gestureRecognizerState.pinchZoomCenter.y) * scaleFactor + _gestureRecognizerState.pinchZoomCenter.y;
  _worldNode.position = worldPosition;
}

- (void)handleMainToolbarPan:(UIGestureRecognizer *)gestureRecognizer
{
  // TODO: This should pan the world when tool is dragged to edge of scene.
  // Also, should perhaps recenter world as needed when tool is released,
  // if track is placed, so that the track edit popup menu can fit fully
  // into the scene.  (This could be the purview of either selection, or
  // track edit menu, or track move.  Since it's not clear, we could order
  // it explicitly -- get track edit menu to calculate it the centering
  // factor for us, then tell the world to fit a certain point.  Or something.)
  CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint trackLocation = [_trackNode convertPoint:sceneLocation fromNode:self];
  int gridX = int(floorf(trackLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(trackLocation.y / _gridSize + 0.5f));

  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

    CGPoint firstTouchSceneLocation = [self convertPointFromView:_gestureRecognizerState.gestureFirstTouchLocation];
    CGPoint firstTouchToolbarLocation = [_mainToolbarState.toolbarNode convertPoint:firstTouchSceneLocation fromNode:self];
    NSString *tool = [_mainToolbarState.toolbarNode toolAtLocation:firstTouchToolbarLocation];
    _mainToolbarState.toolInUseNode = [self FL_createSprite:nil withTexture:tool parent:_hudNode];
    _mainToolbarState.toolInUseNode.zRotation = M_PI_2;
    _mainToolbarState.toolInUseNode.alpha = 0.5f;
    _mainToolbarState.toolInUseNode.position = sceneLocation;
    
    SKSpriteNode *newSegmentNode = [self FL_createSprite:nil withTexture:tool parent:nil];
    newSegmentNode.zPosition = FLZPositionTrackPlaced;
    newSegmentNode.zRotation = M_PI_2;
    [self FL_trackMoveBeganWithNode:newSegmentNode gridX:gridX gridY:gridY];

    // note: This isn't really used for anything during a main toolbar pan, since all pans are track moves,
    // but I'm still trying to figure out the relationship between gestureRecognizerState and mainToolbarState,
    // so I'm setting it for consistency.
    _gestureRecognizerState.panType = FLPanTypeTrackMove;
    
  } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {

    _mainToolbarState.toolInUseNode.position = sceneLocation;
    [self FL_trackMoveContinuedWithGridX:gridX gridY:gridY];

  } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {

    [_mainToolbarState.toolInUseNode removeFromParent];
    _mainToolbarState.toolInUseNode = nil;
    [self FL_trackMoveEndedWithGridX:gridX gridY:gridY];
    
  } else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {

    [_mainToolbarState.toolInUseNode removeFromParent];
    _mainToolbarState.toolInUseNode = nil;
    [self FL_trackMoveCancelledWithGridX:gridX gridY:gridY];

  }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  // A pan motion after a long press begins currently is considered the same as a regular pan,
  // and so it is best recognized by the pan gesture recognizer.
  if (gestureRecognizer == _panRecognizer && otherGestureRecognizer == _longPressRecognizer) {
    return YES;
  }
  // I think this helps.  Otherwise it seems my pinch gesture sometimes gets interpreted as a pan.
  // I think.
  if (gestureRecognizer == _panRecognizer && otherGestureRecognizer == _pinchRecognizer) {
    return YES;
  }
  return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
  CGPoint viewLocation = [touch locationInView:self.view];
  CGPoint sceneLocation = [self convertPointFromView:viewLocation];
  CGPoint trackLocation = [_trackNode convertPoint:sceneLocation fromNode:self];

  // note: Remembering the first touch location is useful, for example, for a pan gesture recognizer,
  // which only knows where the gesture was first recognized (after possibly significant movement).
  _gestureRecognizerState.gestureFirstTouchLocation = viewLocation;

  // noob: Right now we just do a linear search through the various interface components/helpers to
  // see who wants to receive which gestures.  This could be replaced by some kind of general-purpose
  // registration system, where the component registers itself, or defines an interface by which it
  // may be asked if it wants a particular gesture, and if so, which method to call.

  // Main toolbar.
  if (_mainToolbarState.toolbarNode
      && _mainToolbarState.toolbarNode.parent
      && [_mainToolbarState.toolbarNode containsPoint:sceneLocation]) {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
      [gestureRecognizer removeTarget:nil action:nil];
      [gestureRecognizer addTarget:self action:@selector(handleMainToolbarPan:)];
      return YES;
    }
    return NO;
  }
  
  // Track edit menu.
  if (_trackEditMenuHelper.editMenuNode
      && _trackEditMenuHelper.editMenuNode.parent
      && [_trackEditMenuHelper.editMenuNode containsPoint:trackLocation]) {
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
      [gestureRecognizer removeTarget:nil action:nil];
      [gestureRecognizer addTarget:_trackEditMenuHelper action:@selector(handleTap:)];
      return YES;
    }
    return NO;
  }

  // World.
  if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
    [gestureRecognizer removeTarget:nil action:nil];
    [gestureRecognizer addTarget:self action:@selector(handleWorldTap:)];
    return YES;
  }
  if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
    [gestureRecognizer removeTarget:nil action:nil];
    [gestureRecognizer addTarget:self action:@selector(handleWorldLongPress:)];
    return YES;
  }
  if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
    [gestureRecognizer removeTarget:nil action:nil];
    [gestureRecognizer addTarget:self action:@selector(handleWorldPan:)];
    return YES;
  }
  if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
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
//  // responds to zooming, panning, and track selection; the main and popup toolbars respond to taps and pans.
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
#pragma mark Common

- (void)FL_preloadSound
{
  // noob: Could make a store to control this, but it would be a weird store, since the
  // references to the sounds don't actually need to be tracked.
  [SKAction playSoundFileNamed:@"wooden-click-1.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"wooden-click-2.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"wooden-clickity-2.caf" waitForCompletion:NO];
  [SKAction playSoundFileNamed:@"wooden-clatter-1.caf" waitForCompletion:NO];
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
  SKTexture *texture = [[FLTextureStore sharedStore] textureForKey:textureKey];
  SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithTexture:texture];
  sprite.name = spriteName;
  sprite.scale = _artScale;
  // note: The textureKey in user data is currently only used for debugging.
  sprite.userData = [NSMutableDictionary dictionaryWithDictionary:@{ @"textureKey" : textureKey }];
  [parent addChild:sprite];
  return sprite;
}

- (void)FL_mainToolbarSetVisible:(BOOL)visible
{
  if (!_mainToolbarState.toolbarNode) {
    const CGFloat FLMainToolbarBottomPad = 20.0f;

    _mainToolbarState.toolbarNode = [[FLToolbarNode alloc] init];
    _mainToolbarState.toolbarNode.anchorPoint = CGPointMake(0.5f, 0.0f);
    _mainToolbarState.toolbarNode.position = CGPointMake(0.0f, FLMainToolbarBottomPad - self.size.height / 2.0f);
    _mainToolbarState.toolbarNode.toolPad = -1.0f;

    CGFloat artSegmentBasicInset = (_artSegmentSizeFull - _artSegmentSizeBasic) / 2.0f;
    // note: The straight segment runs along the visual edge of a square; we'd like to shift
    // it to the visual center of the tool image.  Half the full texture size is the middle,
    // but need to subtract out the amount that the (centerpoint of the) drawn tracks are already
    // inset from the edge of the texture.
    CGFloat straightShift = (_artSegmentSizeFull / 2.0f) - artSegmentBasicInset;
    // note: For the curves: The track textures don't appear visually centered because the
    // drawn track is a full inset away from any perpendicular edge and only a small pad away
    // from any parallel edge.  The pad is the difference between the drawn track centerpoint
    // inset and half the width of the normal drawn track width.  So shift it inwards by half
    // the difference between the edges.  The math simplifies down a bit.  Rounded to prevent
    // aliasing (?).
    CGFloat curveShift = floorf(_artSegmentDrawnTrackNormalWidth / 4.0f);
    [_mainToolbarState.toolbarNode setToolsWithTextureKeys:@[ @"straight", @"curve", @"join" ]
                                                     sizes:nil
                                                 rotations:@[ @M_PI_2, @M_PI_2, @M_PI_2 ]
                                                   offsets:@[ [NSValue valueWithCGPoint:CGPointMake(straightShift, 0.0f)],
                                                              [NSValue valueWithCGPoint:CGPointMake(curveShift, -curveShift)],
                                                              [NSValue valueWithCGPoint:CGPointMake(curveShift, -curveShift)] ]];
  }

  if (visible) {
    if (!_mainToolbarState.toolbarNode.parent) {
      [_hudNode addChild:_mainToolbarState.toolbarNode];
    }
  } else {
    if (_mainToolbarState.toolbarNode.parent) {
      [_mainToolbarState.toolbarNode removeFromParent];
    }
  }
}

- (void)FL_trackSelectGridX:(int)gridX gridY:(int)gridY
{
  NSLog(@"selected %d,%d", gridX, gridY);

  // Create the visuals if not already created.
  if (!_trackSelectState.visualSelectionNode) {
    const CGFloat FLTrackSelectAlphaMin = 0.7f;
    const CGFloat FLTrackSelectAlphaMax = 1.0f;
    const CGFloat FLTrackSelectFadeDuration = 0.45f;

    _trackSelectState.visualSelectionNode = [SKSpriteNode spriteNodeWithColor:[UIColor colorWithWhite:0.2f alpha:1.0f]
                                                               size:CGSizeMake(_artSegmentSizeBasic, _artSegmentSizeBasic)];
    // TODO: This doesn't work well with light backgrounds.
    _trackSelectState.visualSelectionNode.blendMode = SKBlendModeAdd;
    _trackSelectState.visualSelectionNode.name = @"selection";
    _trackSelectState.visualSelectionNode.scale = _artScale;
    _trackSelectState.visualSelectionNode.zPosition = FLZPositionTrackSelect;
    _trackSelectState.visualSelectionNode.alpha = FLTrackSelectAlphaMin;

    SKAction *pulseIn = [SKAction fadeAlphaTo:FLTrackSelectAlphaMax duration:FLTrackSelectFadeDuration];
    pulseIn.timingMode = SKActionTimingEaseOut;
    SKAction *pulseOut = [SKAction fadeAlphaTo:FLTrackSelectAlphaMin duration:FLTrackSelectFadeDuration];
    pulseOut.timingMode = SKActionTimingEaseIn;
    SKAction *pulseOnce = [SKAction sequence:@[ pulseIn, pulseOut ]];
    SKAction *pulseForever = [SKAction repeatActionForever:pulseOnce];
    [_trackSelectState.visualSelectionNode runAction:pulseForever];
  }

  if (!_trackSelectState.visualSelectionNode.parent) {
    [_trackNode addChild:_trackSelectState.visualSelectionNode];
  }
  _trackSelectState.visualSelectionNode.position = CGPointMake(gridX * _gridSize, gridY * _gridSize);
  _trackSelectState.selected = YES;
  _trackSelectState.gridX = gridX;
  _trackSelectState.gridY = gridY;
}

- (void)FL_trackSelectClear
{
  if (_trackSelectState.selected) {
    [_trackSelectState.visualSelectionNode removeFromParent];
    _trackSelectState.selected = NO;
  }
}

- (BOOL)FL_trackSelectGetCurrentGridX:(int *)gridX gridY:(int *)gridY
{
  if (_trackSelectState.selected) {
    if (gridX) {
      *gridX = _trackSelectState.gridX;
    }
    if (gridY) {
      *gridY = _trackSelectState.gridY;
    }
    return YES;
  }
  return NO;
}

/**
 * Begins a move of a track segment sprite.
 *
 * @param The segment sprite, assumed to have no parent and not be part of the grid.
 *
 * @param The location of the start of the move in track grid coordinates.
 *
 * @param The location of the start of the move in track grid coordinates.
 */
- (void)FL_trackMoveBeganWithNode:(SKSpriteNode *)segmentMovingNode gridX:(int)gridX gridY:(int)gridY
{
  if (_trackMoveState.segmentMoving) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Beginning track move, but previous move not completed."];
  }
  if (segmentMovingNode.parent) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Segment node assumed to have no parent on track move begin."];
  }

  _trackMoveState.segmentMoving = segmentMovingNode;

  [_trackEditMenuHelper hideAnimated:YES];

  // note: The update call will detect no parent and know that the segmentMovingNode has
  // not yet been added to the grid.
  [self FL_trackMoveUpdateWithGridX:gridX gridY:gridY];
}

- (void)FL_trackMoveContinuedWithGridX:(int)gridX gridY:(int)gridY
{
  if (!_trackMoveState.segmentMoving) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Continuing track move, but track move not begun."];
  }
  [self FL_trackMoveUpdateWithGridX:gridX gridY:gridY];
}

- (void)FL_trackMoveEndedWithGridX:(int)gridX gridY:(int)gridY
{
  if (!_trackMoveState.segmentMoving) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Ended track move, but track move not begun."];
  }

  // noob: Does the platform guarantee this behavior already, to wit, that an "ended" call
  // with a certain location will always be preceeded by a "moved" call at that same
  // location?
  [self FL_trackMoveUpdateWithGridX:gridX gridY:gridY];

  // note: Current selection unchanged.
  [_trackEditMenuHelper showOnTrack:_trackNode atSegment:_trackMoveState.segmentMoving gridX:gridX gridY:gridY animated:YES];
  _trackMoveState.segmentMoving = nil;
  _trackMoveState.segmentRemoving = nil;
  [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-clickity-2.caf" waitForCompletion:NO]];
}

- (void)FL_trackMoveCancelledWithGridX:(int)gridX gridY:(int)gridY
{
  if (!_trackMoveState.segmentMoving) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Cancelled track move, but track move not begun."];
  }

  // noob: Does the platform guarantee this behavior already, to wit, that an "ended" call
  // with a certain location will always be preceeded by a "moved" call at that same
  // location?
  [self FL_trackMoveUpdateWithGridX:gridX gridY:gridY];

  if (_trackMoveState.segmentMoving.parent) {

    [_trackMoveState.segmentMoving removeFromParent];
    if (!_trackMoveState.segmentRemoving) {
      _trackGrid.erase(gridX, gridY);
    }
    _trackMoveState.segmentMoving = nil;

    if (_trackMoveState.segmentRemoving) {
      _trackGrid[{gridX, gridY}] = _trackMoveState.segmentRemoving;
      [_trackNode addChild:_trackMoveState.segmentRemoving];
      _trackMoveState.segmentRemoving = nil;
    }

    [self FL_trackSelectClear];
  }

  [self FL_trackGridDump];
}

/**
 * Updates the location of the moving track according to the passed grid location.
 *
 * @precondition: The track move state contains a non-nil moving segment.
 *
 * @precondition: The track move segment has no SKNode parent iff this is the first time
 *                this method has been called for this particular move.
 */
- (void)FL_trackMoveUpdateWithGridX:(int)gridX gridY:(int)gridY
{
  SKSpriteNode *segmentOccupying = _trackGrid.get(gridX, gridY, nil);

  if (segmentOccupying == _trackMoveState.segmentMoving) {
    // The move updated within the same grid square; nothing has changed.
    return;
  }

  // Update the previous grid location.
  if (!_trackMoveState.segmentMoving.parent) {
    // The moving segment has not yet been shown on the track layer, and so nothing needs to
    // be done at the "previous" grid location.  Instead, add the moving segment as a child
    // of the track layer (which is assumed below).
    [_trackNode addChild:_trackMoveState.segmentMoving];
  } else if (_trackMoveState.segmentRemoving) {
    // At the previous grid location, an occupying segment was removed; restore it.  (This
    // will overwrite the moving segment that had been shown there in its place).
    CGPoint oldLocation = _trackMoveState.segmentRemoving.position;
    int oldGridX = int(floorf(oldLocation.x / _gridSize + 0.5f));
    int oldGridY = int(floorf(oldLocation.y / _gridSize + 0.5f));
    _trackGrid[{oldGridX, oldGridY}] = _trackMoveState.segmentRemoving;
    [_trackNode addChild:_trackMoveState.segmentRemoving];
  } else {
    // At the previous grid location, no segment was displaced by the moving segment; clear
    // out the moving segment.
    CGPoint oldLocation = _trackMoveState.segmentMoving.position;
    int oldGridX = int(floorf(oldLocation.x / _gridSize + 0.5f));
    int oldGridY = int(floorf(oldLocation.y / _gridSize + 0.5f));
    _trackGrid.erase(oldGridX, oldGridY);
  }

  // Update the new grid location.
  if (segmentOccupying) {
    [segmentOccupying removeFromParent];
    _trackGrid.erase(gridX, gridY);
    _trackMoveState.segmentRemoving = segmentOccupying;
  } else {
    _trackMoveState.segmentRemoving = nil;
  }
  _trackGrid[{gridX, gridY}] = _trackMoveState.segmentMoving;
  _trackMoveState.segmentMoving.position = CGPointMake(gridX * _gridSize, gridY * _gridSize);
  [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-click-2.caf" waitForCompletion:NO]];

  // Update selection.
  [self FL_trackSelectGridX:gridX gridY:gridY];
}

- (void)FL_trackGridRotateGridX:(int)gridX gridY:(int)gridY rotateBy:(int)rotateBy animated:(BOOL)animated
{
  // note: rotateBy positive means counterclockwise; negative means clockwise.
  SKSpriteNode *segmentNode = _trackGrid.get(gridX, gridY, nil);
  if (segmentNode) {
    if (!animated) {
      // noob: Trying to avoid cumulative floating point error.  Maybe this is overkill.
      segmentNode.zRotation = (int(floorf((segmentNode.zRotation + 0.00001f) / M_PI_2)) + rotateBy) * M_PI_2;
    } else {
      // noob: If this leads to cumulative floating point error, then use rotateToAngle:.
      [segmentNode runAction:[SKAction rotateByAngle:(rotateBy * M_PI_2) duration:0.1]];
      [_trackNode runAction:[SKAction playSoundFileNamed:@"wooden-click-1.caf" waitForCompletion:NO]];
    }
  }
}

- (void)FL_trackGridEraseGridX:(int)gridX gridY:(int)gridY animated:(BOOL)animated
{
  SKSpriteNode *segmentNode = _trackGrid.get(gridX, gridY, nil);
  if (segmentNode) {
    [segmentNode removeFromParent];
    if (animated) {
      SKEmitterNode *sleeperDestruction = [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:@"sleeperDestruction" ofType:@"sks"]];
      SKEmitterNode *railDestruction = [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:@"railDestruction" ofType:@"sks"]];
      // note: This kind of thing makes me think having an _artScale is a bad idea.  Resample the art instead.
      sleeperDestruction.xScale = _artScale;
      sleeperDestruction.yScale = _artScale;
      railDestruction.xScale = _artScale;
      railDestruction.yScale = _artScale;
      CGPoint trackLocation = CGPointMake(gridX * _gridSize, gridY *_gridSize);
      sleeperDestruction.position = trackLocation;
      railDestruction.position = trackLocation;
      [_trackNode addChild:sleeperDestruction];
      [_trackNode addChild:railDestruction];
      // noob: I read it is recommended to remove emitter nodes when they aren't visible.  I'm not sure if that applies
      // to emitter nodes that have reached their numParticlesToEmit maximum, but it certainly seems like a best practice.
      SKAction *removeAfterWait = [SKAction sequence:@[ [SKAction waitForDuration:(sleeperDestruction.particleLifetime * 1.0)],
                                                        [SKAction removeFromParent] ]];
      [sleeperDestruction runAction:removeAfterWait];
      [railDestruction runAction:removeAfterWait];
      SKAction *sound = [SKAction playSoundFileNamed:@"wooden-clatter-1.caf" waitForCompletion:NO];
      [_trackNode runAction:sound];
    }
    _trackGrid.erase(gridX, gridY);
    [_trackEditMenuHelper hideAnimated:YES];
  }
}

- (void)FL_trackGridDump
{
  std::cout << "dump track grid:" << std::endl;
  for (int y = 3; y >= -4; --y) {
    for (int x = -4; x <= 3; ++x) {
      SKSpriteNode *segmentNode = _trackGrid.get(x, y, nil);
      char c;
      if (segmentNode == nil) {
        c = '.';
      } else {
        NSString *textureKey = [segmentNode.userData objectForKey:@"textureKey"];
        if ([textureKey isEqualToString:@"straight"]) {
          c = '|';
        } else if ([textureKey isEqualToString:@"curve"]) {
          c = '/';
        } else if ([textureKey isEqualToString:@"join"]) {
          c = 'Y';
        } else {
          c = '?';
        }
      }
      std::cout << c;
    }
    std::cout << std::endl;
  }
}

@end

#pragma mark -
#pragma mark FLTrackEditMenuHelper

@implementation FLTrackEditMenuHelper
{
  __weak FLTrackScene *_scene;
  int _lastGridX;
  int _lastGridY;
  CGPoint _lastOrigin;
}

- (id)initWithScene:(FLTrackScene *)scene
{
  self = [super init];
  if (self) {
    _scene = scene;
    CGSize FLTrackEditMenuToolSize = { 48.0f, 48.0f };
    _editMenuNode = [[FLToolbarNode alloc] init];
    _editMenuNode.zPosition = FLZPositionTrackOverlay;
    _editMenuNode.anchorPoint = CGPointMake(0.5f, 0.0f);
    NSValue *toolSize = [NSValue valueWithCGSize:FLTrackEditMenuToolSize];
    [_editMenuNode setToolsWithTextureKeys:@[ @"rotate-ccw", @"delete", @"rotate-cw" ]
                                     sizes:@[ toolSize, toolSize, toolSize ]
                                 rotations:@[ @M_PI_2, @M_PI_2, @M_PI_2 ]
                                   offsets:nil];
  }
  return self;
}

- (void)showOnTrack:(SKNode *)trackNode atSegment:(SKSpriteNode *)segmentNode gridX:(int)gridX gridY:(int)gridY animated:(BOOL)animated
{
  const CGFloat FLTrackEditMenuBottomPad = 0.0f;

  CGPoint trackLocation = CGPointMake(segmentNode.position.x, segmentNode.position.y + segmentNode.size.height / 2.0f + FLTrackEditMenuBottomPad);
  if (!_editMenuNode.parent) {
    [trackNode addChild:_editMenuNode];
  }
  if (!animated) {
    _editMenuNode.position = trackLocation;
  } else {
    CGFloat fullScale = [self scaleForWorld:trackNode.parent];
    [_editMenuNode runShowWithOrigin:segmentNode.position finalPosition:trackLocation fullScale:fullScale];
  }
  _lastOrigin = segmentNode.position;
  _lastGridX = gridX;
  _lastGridY = gridY;
}

- (void)hideAnimated:(BOOL)animated
{
  if (!_editMenuNode.parent) {
    return;
  }
  if (!animated) {
    [_editMenuNode removeFromParent];
  } else {
    [_editMenuNode runHideWithOrigin:_lastOrigin removeFromParent:YES];
  }
}

- (void)scaleToWorld:(SKNode *)worldNode
{
  CGFloat editMenuScale = [self scaleForWorld:worldNode];
  _editMenuNode.xScale = editMenuScale;
  _editMenuNode.yScale = editMenuScale;
}

- (CGFloat)scaleForWorld:(SKNode *)worldNode
{
  // note: The track edit menu scales inversely to the world, but perhaps at a different rate.
  // A value of 1.0f means the edit menu will always maintain the same screen size no matter
  // what the scale of the world.  Values less than one mean less-dramatic scaling than
  // the world, and vice versa.
  const CGFloat FLTrackEditMenuScaleFactor = 0.5f;
  return 1.0f / powf(worldNode.xScale, FLTrackEditMenuScaleFactor);
}

- (void)handleTap:(UIGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:_scene.view];
  CGPoint sceneLocation = [_scene convertPointFromView:viewLocation];
  CGPoint toolbarLocation = [_editMenuNode convertPoint:sceneLocation fromNode:_scene];
  NSString *button = [_editMenuNode toolAtLocation:toolbarLocation];

  // noob: This is a helper, which is supposed to have private access to the scene.  We're faking
  // that right now by passing in all private data that needs to be accessed, but it occurs to me
  // that deleting a track segment might involve a callback to a private method of the scene (in
  // case we want to do some standard things, like animation, when deleting a segment).  Not sure
  // how to fake that.

  if ([button isEqualToString:@"rotate-cw"]) {
    [_scene FL_trackGridRotateGridX:_lastGridX gridY:_lastGridY rotateBy:-1 animated:YES];
  } else if ([button isEqualToString:@"rotate-ccw"]) {
    [_scene FL_trackGridRotateGridX:_lastGridX gridY:_lastGridY rotateBy:1 animated:YES];
  } else if ([button isEqualToString:@"delete"]) {
    [_scene FL_trackGridEraseGridX:_lastGridX gridY:_lastGridY animated:YES];
  }
}

@end
