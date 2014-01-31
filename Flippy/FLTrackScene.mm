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

struct FLMainToolbarState
{
  FLMainToolbarState() : toolbarNode(nil) {}
  FLToolbarNode *toolbarNode;
};

struct FLTrackSelectState
{
  FLTrackSelectState() : visualSelectionNode(nil), selected(NO) {}
  SKSpriteNode *visualSelectionNode;
  BOOL selected;
  int gridX;
  int gridY;
};

struct FLTrackEditMenuState
{
  FLTrackEditMenuState() : editMenuNode(nil) {}
  FLToolbarNode *editMenuNode;
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
  FLGestureRecognizerState() : panType(FLPanTypeNone) {}
  FLPanType panType;
  CGPoint panFirstTouchLocation;
  CGPoint pinchZoomCenter;
};

enum FLCameraMode { FLCameraModeManual, FLCameraModeFollowTrain };

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
  FLTrackEditMenuState _trackEditMenuState;
  FLTrackMoveState _trackMoveState;
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
  }
  return self;
}

- (void)didMoveToView:(SKView *)view
{
  if (!_contentCreated) {
    [self FL_createSceneContents];
    _contentCreated = YES;
  }

  _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
  _tapRecognizer.delegate = self;
  _tapRecognizer.cancelsTouchesInView = NO;
  [view addGestureRecognizer:_tapRecognizer];
  
  _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
  _longPressRecognizer.delegate = self;
  _longPressRecognizer.cancelsTouchesInView = NO;
  [view addGestureRecognizer:_longPressRecognizer];
  
  _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
  _panRecognizer.delegate = self;
  _panRecognizer.maximumNumberOfTouches = 1;
  _panRecognizer.cancelsTouchesInView = NO;
  [view addGestureRecognizer:_panRecognizer];
  
  _pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
  _pinchRecognizer.delegate = self;
  _pinchRecognizer.cancelsTouchesInView = NO;
  [view addGestureRecognizer:_pinchRecognizer];
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
  self.backgroundColor = [SKColor colorWithRed:0.4 green:0.6 blue:0.4 alpha:1.0];
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

  SKSpriteNode *terrainNode = [SKSpriteNode spriteNodeWithImageNamed:@"earth-map.jpg"];
  // noob: Using a tip to use replace blend mode for opaque sprites, but since
  // JPGs don't have an alpha channel in the source, does this really do anything?
  terrainNode.zPosition = FLZPositionTerrain;
  terrainNode.blendMode = SKBlendModeReplace;
  terrainNode.scale = 2.0f;
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

  [self FL_trackEditMenuScaleToWorld];
}

- (void)update:(CFTimeInterval)currentTime
{
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
}

#pragma mark -
#pragma mark UIGestureRecognizerDelegate

- (void)handleTap:(UIGestureRecognizer *)gestureRecognizer
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
    [self FL_trackEditMenuHideAnimated:YES];
  } else {
    [self FL_trackSelectGridX:gridX gridY:gridY];
    SKSpriteNode *segmentNode = _trackGrid.get(gridX, gridY, nil);
    if (segmentNode) {
      [self FL_trackEditMenuShowAtSegment:segmentNode animated:YES];
    } else {
      [self FL_trackEditMenuHideAnimated:YES];
    }
  }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
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
      [self FL_trackEditMenuShowAtSegment:segmentNode animated:YES];
    }
  }
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
  _cameraMode = FLCameraModeManual;
  
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

    // Determine type of pan.
    //
    // note: The decision is based on the location of the first touch in the gesture, not the
    // current location (when the gesture is fully identified); they can be quite different.
    // (We could also set the initial translation of the pan based on the former, but instead we
    // let the gesture recognizer do its thing, assuming that's the interface standard.)
    CGPoint viewLocation = _gestureRecognizerState.panFirstTouchLocation;
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

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
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
    // noob: First test my coding assumption that we have two touches on gesture begin.
    if (gestureRecognizer.numberOfTouches != 2) {
      [NSException raise:@"FLHandlePinchUnexpected" format:@"Code assumes pinch gesture can only begin with two touches."];
    }
    if (_cameraMode == FLCameraModeManual) {
      CGPoint touch1ViewLocation = [gestureRecognizer locationOfTouch:0 inView:self.view];
      CGPoint touch2ViewLocation = [gestureRecognizer locationOfTouch:1 inView:self.view];
      CGPoint centerViewLocation = CGPointMake((touch1ViewLocation.x + touch2ViewLocation.x) / 2.0f,
                                               (touch1ViewLocation.y + touch2ViewLocation.y) / 2.0f);
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
  CGFloat scaleFactor = worldScaleCurrent / handlePinchWorldScaleBegin;

  // Zoom around previously-chosen center point.
  CGPoint worldPosition;
  worldPosition.x = (handlePinchWorldPositionBegin.x - _gestureRecognizerState.pinchZoomCenter.x) * scaleFactor + _gestureRecognizerState.pinchZoomCenter.x;
  worldPosition.y = (handlePinchWorldPositionBegin.y - _gestureRecognizerState.pinchZoomCenter.y) * scaleFactor + _gestureRecognizerState.pinchZoomCenter.y;
  _worldNode.position = worldPosition;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  // A pan motion after a long press begins currently is considered the same as a regular pan,
  // and so it is best recognized by the pan gesture recognizer.
  if (gestureRecognizer == _panRecognizer && otherGestureRecognizer == _longPressRecognizer) {
    return YES;
  }
  return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
  // noob: From the UIGestureRecognizer class reference:
  //
  //     A window delivers touch events to a gesture recognizer before it delivers them to the
  //     hit-tested view attached to the gesture recognizer. Generally, if a gesture recognizer
  //     analyzes the stream of touches in a multi-touch sequence and doesn’t recognize its
  //     gesture, the view receives the full complement of touches. If a gesture recognizer
  //     recognizes its gesture, the remaining touches for the view are cancelled.
  //
  // So if we're using gesture recognizers in this scene, then we need to explicitly exclude regions
  // that should block the gesture from starting (or continuing, or whatever).  For us, that's anything
  // in the HUD layer.

  // noob: It appears that this is only called for initial touches, and not for continued touches that
  // the gesture recognizer has already started recognizing.  So, for example, a pan begun on one side
  // of the toolbar, and continuing through it, continues to be recognized by the pan gesture
  // recognizer.  This is good.  Otherwise, I suppose I would be doing explicit checks of the
  // recognizer's state here.

  CGPoint hudLocation = [touch locationInNode:_hudNode];
  if ([_hudNode nodeAtPoint:hudLocation] != _hudNode) {
    return NO;
  }
  
  if (gestureRecognizer == _panRecognizer) {
    CGPoint location = [touch locationInView:self.view];
    // note: The pan gesture recognizer only recognizes after the touch has
    // moved a bit.  This code could go in touchesBegan:, but it's nice to
    // keep it in the gesture-recognizer-only domain, here.
    _gestureRecognizerState.panFirstTouchLocation = location;
  }
  
  return YES;
}

#pragma mark -
#pragma mark FLToolbarNodeDelegate

- (void)toolBarNode:(FLToolbarNode *)toolbarNode toolBegan:(NSString *)tool location:(CGPoint)location
{
  SKNode *toolInUse = [_hudNode childNodeWithName:@"toolInUse"];
  if (toolInUse) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" began, but toolInUse node already exists.", tool];
  };
  toolInUse = [self FL_createSprite:@"toolInUse" withTexture:tool parent:_hudNode];
  toolInUse.position = [_hudNode convertPoint:location fromNode:toolbarNode];
  toolInUse.zRotation = M_PI_2;
  toolInUse.alpha = 0.5f;

  SKSpriteNode *newSegmentNode = [self FL_createSprite:nil withTexture:tool parent:nil];
  newSegmentNode.userData = [NSMutableDictionary dictionaryWithDictionary:@{ @"segmentType" : tool }];
  newSegmentNode.zPosition = FLZPositionTrackPlaced;
  newSegmentNode.zRotation = M_PI_2;
  CGPoint segmentLocation = [_trackNode convertPoint:location fromNode:toolbarNode];
  int gridX = int(floorf(segmentLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(segmentLocation.y / _gridSize + 0.5f));
  [self FL_trackMoveBeganWithNode:newSegmentNode gridX:gridX gridY:gridY];
}

- (void)toolBarNode:(FLToolbarNode *)toolbarNode toolMoved:(NSString *)tool location:(CGPoint)location
{
  SKNode *toolInUse = [_hudNode childNodeWithName:@"toolInUse"];
  if (!toolInUse) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" moved, but no toolInUse node exists.", tool];
  };
  toolInUse.position = [_hudNode convertPoint:location fromNode:toolbarNode];

  CGPoint segmentLocation = [_trackNode convertPoint:location fromNode:toolbarNode];
  int gridX = int(floorf(segmentLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(segmentLocation.y / _gridSize + 0.5f));
  [self FL_trackMoveContinuedWithGridX:gridX gridY:gridY];
}

- (void)toolBarNode:(FLToolbarNode *)toolbarNode toolEnded:(NSString *)tool location:(CGPoint)location
{
  SKNode *toolInUse = [_hudNode childNodeWithName:@"toolInUse"];
  if (!toolInUse) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" ended, but no toolInUse node exists.", tool];
  };
  [toolInUse removeFromParent];

  CGPoint segmentLocation = [_trackNode convertPoint:location fromNode:toolbarNode];
  int gridX = int(floorf(segmentLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(segmentLocation.y / _gridSize + 0.5f));
  [self FL_trackMoveEndedWithGridX:gridX gridY:gridY];
}

- (void)toolBarNode:(FLToolbarNode *)toolbarNode toolCancelled:(NSString *)tool location:(CGPoint)location
{
  SKNode *toolInUse = [_hudNode childNodeWithName:@"toolInUse"];
  if (!toolInUse) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" cancelled, but no toolInUse node exists.", tool];
  };
  [toolInUse removeFromParent];

  CGPoint segmentLocation = [_trackNode convertPoint:location fromNode:toolbarNode];
  int gridX = int(floorf(segmentLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(segmentLocation.y / _gridSize + 0.5f));
  [self FL_trackMoveCancelledWithGridX:gridX gridY:gridY];
}

#pragma mark -
#pragma mark Common

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
  [parent addChild:sprite];
  return sprite;
}

- (void)FL_mainToolbarSetVisible:(BOOL)visible
{
  if (!_mainToolbarState.toolbarNode) {
    const CGFloat FLMainToolbarBottomPad = 20.0f;
    
    _mainToolbarState.toolbarNode = [[FLToolbarNode alloc] init];
    _mainToolbarState.toolbarNode.delegate = self;
    _mainToolbarState.toolbarNode.anchorPoint = CGPointMake(0.5f, 0.0f);
    _mainToolbarState.toolbarNode.position = CGPointMake(0.0f, FLMainToolbarBottomPad - self.size.height / 2.0f);

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

- (void)FL_trackEditMenuShowAtSegment:(SKSpriteNode *)segmentNode animated:(BOOL)animated
{
  if (!_trackEditMenuState.editMenuNode) {
    _trackEditMenuState.editMenuNode = [[FLToolbarNode alloc] init];
    //_trackEditMenuState.editMenuNode.delegate = self;
    _trackEditMenuState.editMenuNode.zPosition = FLZPositionTrackOverlay;
    _trackEditMenuState.editMenuNode.anchorPoint = CGPointMake(0.5f, 0.0f);
    [_trackEditMenuState.editMenuNode setToolsWithTextureKeys:@[ @"rotate-ccw", @"delete", @"rotate-cw" ]
                                                        sizes:@[ [NSValue valueWithCGSize:CGSizeMake(48.0f, 48.0f)],
                                                                 [NSValue valueWithCGSize:CGSizeMake(48.0f, 48.0f)],
                                                                 [NSValue valueWithCGSize:CGSizeMake(48.0f, 48.0f)] ]
                                                    rotations:@[ @M_PI_2, @M_PI_2, @M_PI_2 ]
                                                      offsets:nil];
  }

  const CGFloat FLTrackEditMenuBottomPad = 0.0f;

  // TODO: Animated.
  CGPoint trackLocation = CGPointMake(segmentNode.position.x, segmentNode.position.y + segmentNode.size.height / 2.0f + FLTrackEditMenuBottomPad);
  _trackEditMenuState.editMenuNode.position = trackLocation;
  if (!_trackEditMenuState.editMenuNode.parent) {
    [_trackNode addChild:_trackEditMenuState.editMenuNode];
  }
}

- (void)FL_trackEditMenuHideAnimated:(BOOL)animated
{
  // TODO: Animated.
  if (!_trackEditMenuState.editMenuNode.parent) {
    return;
  }
  [_trackEditMenuState.editMenuNode removeFromParent];
}

- (void)FL_trackEditMenuScaleToWorld
{
  if (!_trackEditMenuState.editMenuNode) {
    return;
  }

  // note: The track edit menu scales inversely to the world, but perhaps at a different rate.
  // A value of 1.0f means the edit menu will always maintain the same screen size no matter
  // what the scale of the world.  Values less than one mean less-dramatic scaling than
  // the world, and vice versa.
  const CGFloat FLTrackEditMenuScaleFactor = 0.5f;

  CGFloat editMenuScale = 1.0f / powf(_worldNode.xScale, FLTrackEditMenuScaleFactor);
  _trackEditMenuState.editMenuNode.xScale = editMenuScale;
  _trackEditMenuState.editMenuNode.yScale = editMenuScale;
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
  
  [self FL_trackEditMenuHideAnimated:YES];

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
  [self FL_trackEditMenuShowAtSegment:_trackMoveState.segmentMoving animated:YES];
  _trackMoveState.segmentMoving = nil;
  _trackMoveState.segmentRemoving = nil;
  
  [self FL_dumpTrackGrid];
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
  
  [self FL_dumpTrackGrid];
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

  // Update selection.
  [self FL_trackSelectGridX:gridX gridY:gridY];
}

- (void)FL_dumpTrackGrid
{
  std::cout << "dump track grid:" << std::endl;
  for (int y = 3; y >= -4; --y) {
    for (int x = -4; x <= 3; ++x) {
      SKSpriteNode *segmentNode = _trackGrid.get(x, y, nil);
      char c;
      if (segmentNode == nil) {
        c = '.';
      } else {
        NSString *segmentType = [segmentNode.userData objectForKey:@"segmentType"];
        if ([segmentType isEqualToString:@"straight"]) {
          c = '|';
        } else if ([segmentType isEqualToString:@"curve"]) {
          c = '/';
        } else if ([segmentType isEqualToString:@"join"]) {
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
