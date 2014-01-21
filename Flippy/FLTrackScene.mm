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
  SKSpriteNode *visualSelectionNode;
};

struct FLTrackMoveState
{
  SKSpriteNode *segmentMoving;
  SKSpriteNode *segmentRemoving;
};

@implementation FLTrackScene
{
  BOOL _contentCreated;

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
                             rotations:@[ @M_PI_2,
                                          @M_PI_2,
                                          @M_PI_2 ]
                               offsets:@[ [NSValue valueWithCGPoint:CGPointMake(18.0f, 0.0f)],
                                          [NSValue valueWithCGPoint:CGPointMake(3.0f, -3.0f)],
                                          [NSValue valueWithCGPoint:CGPointMake(3.0f, -3.0f)] ]];
  [hudNode addChild:toolbarNode];
}

- (void)didSimulatePhysics
{
  // noob: If camera is following train constantly, then do FL_centerWorldOnCamera here.
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
//  for (UITouch *touch in touches) {
//    CGPoint location = [touch locationInNode:self];
//    SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithImageNamed:@"train"];
//    sprite.position = location;
//    SKAction *action = [SKAction rotateByAngle:M_PI duration:1];
//    [sprite runAction:[SKAction repeatActionForever:action]];
//    [self addChild:sprite];
//  }

//  SKNode *trainNode = [self childNodeWithName:@"train"];
//  if (trainNode) {
//    trainNode.name = nil;
//    SKAction *moveUp = [SKAction moveByX:0 y:100.0 duration:0.5];
//    SKAction *zoom = [SKAction scaleTo:2.0 duration:0.25];
//    SKAction *pause = [SKAction waitForDuration:0.5];
//    SKAction *fadeAway = [SKAction fadeOutWithDuration:0.25];
//    SKAction *remove = [SKAction removeFromParent];
//    SKAction *moveSequence = [SKAction sequence:@[moveUp, zoom, pause, fadeAway, remove]];
//    [trainNode runAction: moveSequence];
//  }

  // TODO: Change to pan gesture; use tap gesture for selection/deselection.
  // TODO: Pinch gesture for zoom.
  // TODO: Rotate gesture for rotating selected object (if any).

  SKNode *worldNode = [self childNodeWithName:@"world"];
  SKNode *cameraNode = [worldNode childNodeWithName:@"camera"];
  UITouch *firstTouch = [touches anyObject];
  cameraNode.position = [firstTouch locationInNode:worldNode];
  [self FL_centerWorldOnCamera];
}

- (void)update:(CFTimeInterval)currentTime
{
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
  [self FL_trackMoveBegan:newSegmentNode location:segmentLocation];
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
  [self FL_trackMoveContinuedWithLocation:segmentLocation];
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
  [self FL_trackMoveEndedWithLocation:segmentLocation];
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
  [self FL_trackMoveCancelledWithLocation:segmentLocation];
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

- (void)FL_selectTrackGridX:(int)gridX gridY:(int)gridY
{
  if (!_trackSelectState.visualSelectionNode) {
    const CGFloat FLTrackSelectAlphaMin = 0.15f;
    const CGFloat FLTrackSelectAlphaMax = 0.2f;
    const CGFloat FLTrackSelectFadeDuration = 0.45f;

    _trackSelectState.visualSelectionNode = [SKSpriteNode spriteNodeWithColor:[UIColor whiteColor]
                                                               size:CGSizeMake(_artSegmentSizeBasic, _artSegmentSizeBasic)];
    _trackSelectState.visualSelectionNode.name = @"selection";
    _trackSelectState.visualSelectionNode.scale = _artScale;
    _trackSelectState.visualSelectionNode.zPosition = FLZPositionTrackSelect;
    _trackSelectState.visualSelectionNode.alpha = FLTrackSelectAlphaMin;
    SKNode *worldNode = [self childNodeWithName:@"world"];
    SKNode *trackNode = [worldNode childNodeWithName:@"track"];
    [trackNode addChild:_trackSelectState.visualSelectionNode];

    SKAction *pulseIn = [SKAction fadeAlphaTo:FLTrackSelectAlphaMax duration:FLTrackSelectFadeDuration];
    pulseIn.timingMode = SKActionTimingEaseOut;
    SKAction *pulseOut = [SKAction fadeAlphaTo:FLTrackSelectAlphaMin duration:FLTrackSelectFadeDuration];
    pulseOut.timingMode = SKActionTimingEaseIn;
    SKAction *pulseOnce = [SKAction sequence:@[ pulseIn, pulseOut ]];
    SKAction *pulseForever = [SKAction repeatActionForever:pulseOnce];
    [_trackSelectState.visualSelectionNode runAction:pulseForever];
  }

  _trackSelectState.visualSelectionNode.position = CGPointMake(gridX * _gridSize, gridY * _gridSize);
}

- (void)FL_selectTrackClear
{
  if (_trackSelectState.visualSelectionNode) {
    [_trackSelectState.visualSelectionNode removeFromParent];
  }
}

/**
 * Begins a move of a track segment sprite.
 *
 * @param The segment sprite, assumed to have no parent and not be part of the grid.
 *
 * @param The location of the start of the move in trackNode coordinates.
 */
- (void)FL_trackMoveBegan:(SKSpriteNode *)segmentMovingNode location:(CGPoint)location
{
  // TODO: Consider encapsulating logic inside of the move state class.

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
  int gridX = int(floorf(location.x / _gridSize + 0.5f));
  int gridY = int(floorf(location.y / _gridSize + 0.5f));
  [self FL_trackMoveUpdateWithGridX:gridX gridY:gridY];
}

- (void)FL_trackMoveContinuedWithLocation:(CGPoint)location
{
  if (!_trackMoveState.segmentMoving) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Continuing track move, but track move not begun."];
  }
  int gridX = int(floorf(location.x / _gridSize + 0.5f));
  int gridY = int(floorf(location.y / _gridSize + 0.5f));
  [self FL_trackMoveUpdateWithGridX:gridX gridY:gridY];
}

- (void)FL_trackMoveEndedWithLocation:(CGPoint)location
{
  if (!_trackMoveState.segmentMoving) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Ended track move, but track move not begun."];
  }

  // noob: Does the platform guarantee this behavior already, to wit, that an "ended" call
  // with a certain location will always be preceeded by a "moved" call at that same
  // location?
  int gridX = int(floorf(location.x / _gridSize + 0.5f));
  int gridY = int(floorf(location.y / _gridSize + 0.5f));
  [self FL_trackMoveUpdateWithGridX:gridX gridY:gridY];

  _trackMoveState.segmentMoving = nil;
  _trackMoveState.segmentRemoving = nil;
  // note: Current selection unchanged.
  
  [self FL_dumpTrackGrid];
}

- (void)FL_trackMoveCancelledWithLocation:(CGPoint)location
{
  if (!_trackMoveState.segmentMoving) {
    [NSException raise:@"FLTrackMoveBadState"
                format:@"Cancelled track move, but track move not begun."];
  }

  // noob: Does the platform guarantee this behavior already, to wit, that an "ended" call
  // with a certain location will always be preceeded by a "moved" call at that same
  // location?
  int gridX = int(floorf(location.x / _gridSize + 0.5f));
  int gridY = int(floorf(location.y / _gridSize + 0.5f));
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

    [self FL_selectTrackClear];
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
  [self FL_selectTrackGridX:gridX gridY:gridY];
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
