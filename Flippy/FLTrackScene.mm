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
  FLGestureRecognizerState() : panType(FLPanTypeNone) {}
  FLPanType panType;
  CGPoint panFirstTouchLocation;
};

@implementation FLTrackScene
{
  BOOL _contentCreated;
  UITapGestureRecognizer *_tapRecognizer;
  UIPanGestureRecognizer *_panRecognizer;
  FLGestureRecognizerState _gestureRecognizerState;

  CGFloat _artSegmentSizeFull;
  CGFloat _artSegmentSizeBasic;
  CGFloat _gridSize;
  CGFloat _artScale;

  QuadTree<SKSpriteNode *> _trackGrid;

  FLTrackSelectState _trackSelectState;
  FLTrackMoveState _trackMoveState;
}

- (id)initWithSize:(CGSize)size
{
  self = [super initWithSize:size];
  if (self) {
    _artSegmentSizeFull = 54.0f;
    _artSegmentSizeBasic = 36.0f;
    _artScale = 2.0f;
    _gridSize = _artSegmentSizeBasic * _artScale;
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
  [view addGestureRecognizer:_tapRecognizer];
  
  _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
  _panRecognizer.delegate = self;
  _panRecognizer.maximumNumberOfTouches = 1;
  _panRecognizer.cancelsTouchesInView = NO;
  [view addGestureRecognizer:_panRecognizer];
}

- (void)willMoveFromView:(SKView *)view
{
  [view removeGestureRecognizer:_tapRecognizer];
  [view removeGestureRecognizer:_panRecognizer];
}

- (void)FL_createSceneContents
{
  self.backgroundColor = [SKColor colorWithRed:0.2 green:0.5 blue:0.2 alpha:1.0];
  self.anchorPoint = CGPointMake(0.5f, 0.5f);

  // Create basic layers.

  // The large world is moved around within the scene, which acts
  // as a window into the world.
  //
  // noob: Consider tiling the world so that distant parts
  // of the world need not be tracked at all by the game engine.
  // Using a single large image in a single terrain node might not affect
  // rendering time, but it would at least require more memory than necessary,
  // right?  And then once you tiled it to reduce memory, then removing
  // nodes from the node tree is a good idea to improve engine performance.
  SKNode *worldNode = [SKNode node];
  worldNode.name = @"world";
  worldNode.zPosition = FLZPositionWorld;
  [self addChild:worldNode];

  SKSpriteNode *terrainNode = [SKSpriteNode spriteNodeWithImageNamed:@"earth-map.jpg"];
  // noob: Using a tip to use replace blend mode for opaque sprites, but since
  // JPGs don't have an alpha channel in the source, does this really do anything?
  terrainNode.zPosition = FLZPositionTerrain;
  terrainNode.blendMode = SKBlendModeReplace;
  terrainNode.scale = 4.0f;
  [worldNode addChild:terrainNode];

  SKNode *trackNode = [SKNode node];
  trackNode.name = @"track";
  trackNode.zPosition = FLZPositionTrack;
  [worldNode addChild:trackNode];

  SKNode *trainNode = [SKNode node];
  trainNode.name = @"train";
  trainNode.zPosition = FLZPositionTrain;
  [worldNode addChild:trainNode];

  // The HUD node contains everything pinned to the scene window, outside the world.
  SKNode *hudNode = [SKNode node];
  hudNode.name = @"hud";
  hudNode.zPosition = FLZPositionHud;
  [self addChild:hudNode];

  // Populate main layers with content.

  // The camera node represents the future position of the world within the scene; rather
  // than move the world around, we move the camera around and then sync the world
  // position to it as needed.  Future: Perhaps have train-camera and user-camera nodes
  // created at all times, and sync to one or the other based on whether the simulation is
  // running or not.
  SKNode *cameraNode = [SKNode node];
  cameraNode.name = @"camera";
  [worldNode addChild:cameraNode];

  FLToolbarNode *toolbarNode = [[FLToolbarNode alloc] init];
  toolbarNode.delegate = self;
  toolbarNode.anchorPoint = CGPointMake(0.5f, 0.0f);
  toolbarNode.position = CGPointMake(0.0f, 20.0f - self.size.height / 2.0f);
  // note: Offset calculation for segments: The center points of the drawn tracks start
  // inset nine pixels from the outer edge of the texture.  So shifting that point to the
  // middle means offsetting it half of the texture size (54 / 2 = 27) and subtracting the
  // nine already shifted (27 - 9 = 18).  In the other dimension, the drawn track edge
  // starts 2 pixels inset from the texture (meaning a normal track width of 14 pixels).
  // So shifting ((9 - 2) / 2 = 3.5 ~= 3.0) pixels gives a visual center in some cases.
  [toolbarNode setToolsWithTextureKeys:@[ @"straight", @"curve", @"join" ]
                             rotations:@[ @M_PI_2, @M_PI_2, @M_PI_2 ]
                               offsets:@[ [NSValue valueWithCGPoint:CGPointMake(18.0f, 0.0f)],
                                          [NSValue valueWithCGPoint:CGPointMake(3.0f, -3.0f)],
                                          [NSValue valueWithCGPoint:CGPointMake(3.0f, -3.0f)] ]];
  [hudNode addChild:toolbarNode];
}

- (void)didSimulatePhysics
{
  // noob: If camera is following train constantly, then do FL_centerWorldOnCamera here.
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
  SKNode *worldNode = [self childNodeWithName:@"world"];
  SKNode *trackNode = [worldNode childNodeWithName:@"track"];
  CGPoint trackLocation = [trackNode convertPoint:sceneLocation fromNode:self];
  
  int gridX = int(floorf(trackLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(trackLocation.y / _gridSize + 0.5f));

  int selectedGridX;
  int selectedGridY;
  if ([self FL_trackSelectGetCurrentGridX:&selectedGridX gridY:&selectedGridY]
      && selectedGridX == gridX
      && selectedGridY == gridY) {
    [self FL_trackSelectClear];
  } else {
    [self FL_trackSelectGridX:gridX gridY:gridY];
  }
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
  SKNode *worldNode = [self childNodeWithName:@"world"];

  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {

    // Determine type of pan.
    //
    // note: The decision is based on the location of the first touch in the gesture, not the
    // current location (when the gesture is fully identified); they can be quite different.
    // (We could also set the initial translation of the pan based on the former, but instead we
    // let the gesture recognizer do its thing, assuming that's the interface standard.)
    CGPoint viewLocation = _gestureRecognizerState.panFirstTouchLocation;
    CGPoint sceneLocation = [self convertPointFromView:viewLocation];
    SKNode *trackNode = [worldNode childNodeWithName:@"track"];
    CGPoint trackLocation = [trackNode convertPoint:sceneLocation fromNode:self];
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
      case FLPanTypeTrackMove:
      {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        SKNode *trackNode = [worldNode childNodeWithName:@"track"];
        CGPoint trackLocation = [trackNode convertPoint:sceneLocation fromNode:self];
        int gridX = int(floorf(trackLocation.x / _gridSize + 0.5f));
        int gridY = int(floorf(trackLocation.y / _gridSize + 0.5f));
        [self FL_trackMoveContinuedWithGridX:gridX gridY:gridY];
        break;
      }
      case FLPanTypeWorld:
      {
        SKNode *cameraNode = [worldNode childNodeWithName:@"camera"];
        // note: Zooming might change this calculation.  We'll see.
        CGPoint translation = [gestureRecognizer translationInView:self.view];
        CGPoint cameraPosition = cameraNode.position;
        cameraPosition.x -= translation.x;
        cameraPosition.y += translation.y;
        cameraNode.position = cameraPosition;
        [gestureRecognizer setTranslation:CGPointZero inView:self.view];
        [self FL_centerWorldOnCamera];
        break;
      }
      default:
        // note: This means the pan gesture was not actually doing anything,
        // but was allowed to continue.
        break;
    }
    
  } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
    
    switch (_gestureRecognizerState.panType) {
      case FLPanTypeTrackMove:
      {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        SKNode *trackNode = [worldNode childNodeWithName:@"track"];
        CGPoint trackLocation = [trackNode convertPoint:sceneLocation fromNode:self];
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
      case FLPanTypeTrackMove:
      {
        CGPoint viewLocation = [gestureRecognizer locationInView:self.view];
        CGPoint sceneLocation = [self convertPointFromView:viewLocation];
        SKNode *trackNode = [worldNode childNodeWithName:@"track"];
        CGPoint trackLocation = [trackNode convertPoint:sceneLocation fromNode:self];
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  // noob: This doesn't seem to make a different so far with just pan and tap.  Try it again later.
  //if (gestureRecognizer == _panRecognizer) {
  //  return YES;
  //}
  //return NO;
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

  SKNode *hudNode = [self childNodeWithName:@"hud"];
  CGPoint hudLocation = [touch locationInNode:hudNode];
  if ([hudNode nodeAtPoint:hudLocation] != hudNode) {
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
  SKNode *hudNode = [self childNodeWithName:@"hud"];
  SKNode *toolInUse = [hudNode childNodeWithName:@"toolInUse"];
  if (toolInUse) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" began, but toolInUse node already exists.", tool];
  };
  toolInUse = [self FL_createSprite:@"toolInUse" withTexture:tool parent:hudNode];
  toolInUse.position = [hudNode convertPoint:location fromNode:toolbarNode];
  toolInUse.zRotation = M_PI_2;
  toolInUse.alpha = 0.5f;

  SKNode *worldNode = [self childNodeWithName:@"world"];
  SKNode *trackNode = [worldNode childNodeWithName:@"track"];
  SKSpriteNode *newSegmentNode = [self FL_createSprite:nil withTexture:tool parent:nil];
  newSegmentNode.userData = [NSMutableDictionary dictionaryWithDictionary:@{ @"segmentType" : tool }];
  newSegmentNode.zPosition = FLZPositionTrackPlaced;
  newSegmentNode.zRotation = M_PI_2;
  CGPoint segmentLocation = [trackNode convertPoint:location fromNode:toolbarNode];
  int gridX = int(floorf(segmentLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(segmentLocation.y / _gridSize + 0.5f));
  [self FL_trackMoveBeganWithNode:newSegmentNode gridX:gridX gridY:gridY];
}

- (void)toolBarNode:(FLToolbarNode *)toolbarNode toolMoved:(NSString *)tool location:(CGPoint)location
{
  SKNode *hudNode = [self childNodeWithName:@"hud"];
  SKNode *toolInUse = [hudNode childNodeWithName:@"toolInUse"];
  if (!toolInUse) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" moved, but no toolInUse node exists.", tool];
  };
  toolInUse.position = [hudNode convertPoint:location fromNode:toolbarNode];

  SKNode *worldNode = [self childNodeWithName:@"world"];
  SKNode *trackNode = [worldNode childNodeWithName:@"track"];
  CGPoint segmentLocation = [trackNode convertPoint:location fromNode:toolbarNode];
  int gridX = int(floorf(segmentLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(segmentLocation.y / _gridSize + 0.5f));
  [self FL_trackMoveContinuedWithGridX:gridX gridY:gridY];
}

- (void)toolBarNode:(FLToolbarNode *)toolbarNode toolEnded:(NSString *)tool location:(CGPoint)location
{
  SKNode *hudNode = [self childNodeWithName:@"hud"];
  SKNode *toolInUse = [hudNode childNodeWithName:@"toolInUse"];
  if (!toolInUse) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" ended, but no toolInUse node exists.", tool];
  };
  [toolInUse removeFromParent];

  SKNode *worldNode = [self childNodeWithName:@"world"];
  SKNode *trackNode = [worldNode childNodeWithName:@"track"];
  CGPoint segmentLocation = [trackNode convertPoint:location fromNode:toolbarNode];
  int gridX = int(floorf(segmentLocation.x / _gridSize + 0.5f));
  int gridY = int(floorf(segmentLocation.y / _gridSize + 0.5f));
  [self FL_trackMoveEndedWithGridX:gridX gridY:gridY];
}

- (void)toolBarNode:(FLToolbarNode *)toolbarNode toolCancelled:(NSString *)tool location:(CGPoint)location
{
  SKNode *hudNode = [self childNodeWithName:@"hud"];
  SKNode *toolInUse = [hudNode childNodeWithName:@"toolInUse"];
  if (!toolInUse) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" cancelled, but no toolInUse node exists.", tool];
  };
  [toolInUse removeFromParent];

  SKNode *worldNode = [self childNodeWithName:@"world"];
  SKNode *trackNode = [worldNode childNodeWithName:@"track"];
  CGPoint segmentLocation = [trackNode convertPoint:location fromNode:toolbarNode];
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

- (void)FL_centerWorldOnCamera
{
  SKNode *worldNode = [self childNodeWithName:@"world"];
  if (!worldNode) {
    return;
  }
  SKNode *cameraNode = [worldNode childNodeWithName:@"camera"];
  if (!cameraNode) {
    return;
  }
  CGPoint cameraPositionInScene = [self convertPoint:cameraNode.position fromNode:worldNode];
  worldNode.position = CGPointMake(worldNode.position.x - cameraPositionInScene.x,
                                   worldNode.position.y - cameraPositionInScene.y);
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
    SKNode *worldNode = [self childNodeWithName:@"world"];
    SKNode *trackNode = [worldNode childNodeWithName:@"track"];
    [trackNode addChild:_trackSelectState.visualSelectionNode];
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

  _trackMoveState.segmentMoving = nil;
  _trackMoveState.segmentRemoving = nil;
  // note: Current selection unchanged.
  
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
      SKNode *worldNode = [self childNodeWithName:@"world"];
      SKNode *trackNode = [worldNode childNodeWithName:@"track"];
      _trackGrid[{gridX, gridY}] = _trackMoveState.segmentRemoving;
      [trackNode addChild:_trackMoveState.segmentRemoving];
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
    SKNode *worldNode = [self childNodeWithName:@"world"];
    SKNode *trackNode = [worldNode childNodeWithName:@"track"];
    [trackNode addChild:_trackMoveState.segmentMoving];
  } else if (_trackMoveState.segmentRemoving) {
    // At the previous grid location, an occupying segment was removed; restore it.  (This
    // will overwrite the moving segment that had been shown there in its place).
    CGPoint oldLocation = _trackMoveState.segmentRemoving.position;
    int oldGridX = int(floorf(oldLocation.x / _gridSize + 0.5f));
    int oldGridY = int(floorf(oldLocation.y / _gridSize + 0.5f));
    _trackGrid[{oldGridX, oldGridY}] = _trackMoveState.segmentRemoving;
    SKNode *worldNode = [self childNodeWithName:@"world"];
    SKNode *trackNode = [worldNode childNodeWithName:@"track"];
    [trackNode addChild:_trackMoveState.segmentRemoving];
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
