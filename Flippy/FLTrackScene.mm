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

static const CGFloat FLZPositionWorld = 0.0f;
static const CGFloat FLZPositionTrack = 1.0f;
static const CGFloat FLZPositionTrain = 2.0f;
static const CGFloat FLZPositionHud = 3.0f;

static const CGFloat FLZPositionTerrain = 0.0f;

static const CGFloat FLZPositionTrackSelection = 0.0f;
static const CGFloat FLZPositionTrackPlaced = 0.1f;
static const CGFloat FLZPositionTrackAdding = 0.2f;

static const CGFloat FLZPositionHudToolInUse = 0.0f;

@implementation FLTrackScene
{
  BOOL _contentCreated;

  CGFloat _artTrackSizeFull;
  CGFloat _artTrackSizeBasic;
  CGFloat _gridSize;
  CGFloat _artScale;
}

- (id)initWithSize:(CGSize)size
{
  self = [super initWithSize:size];
  if (self) {
    _artTrackSizeFull = 54.0f;
    _artTrackSizeBasic = 36.0f;
    _artScale = 2.0f;
    _gridSize = _artTrackSizeBasic * _artScale;
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
  
  // The HUD node contains everything pinned to the scene window, outside the world.
  SKNode *hudNode = [SKNode node];
  hudNode.name = @"hud";
  hudNode.zPosition = 3.0f;
  [self addChild:hudNode];
  
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

  SKNode *trackNode = [SKNode node];
  trackNode.name = @"track";
  trackNode.zPosition = FLZPositionTrack;
  [worldNode addChild:trackNode];

  SKNode *trainNode = [SKNode node];
  trainNode.name = @"train";
  trainNode.zPosition = FLZPositionTrain;
  [worldNode addChild:trainNode];

  // The camera node represents the future position of the world within the scene;
  // rather than move the world around, we move the camera around and then sync
  // the world position to it as needed.  Future: Perhaps have train-camera
  // and user-camera nodes created at all times, and sync to one or the other
  // based on whether the simulation is running or not.
  SKNode *cameraNode = [SKNode node];
  cameraNode.name = @"camera";
  [worldNode addChild:cameraNode];

  // Populate layers with content.

  FLToolbarNode *toolbarNode = [[FLToolbarNode alloc] init];
  toolbarNode.delegate = self;
  toolbarNode.anchorPoint = CGPointMake(0.5f, 0.0f);
  toolbarNode.position = CGPointMake(0.0f, 20.0f - self.size.height / 2.0f);
  // note: Offset calculation for track pieces: The center points of the
  // track pieces start inset nine pixels from the outer edge of the texture.
  // So shifting that point to the middle means offsetting it half of the
  // texture size (54 / 2 = 27) and subtracting the nine already shifted
  // (27 - 9 = 18).  In the other dimension, the track edge starts 2 pixels
  // inset from the texture (meaning a normal track width of 14 pixels).  So
  // shifting ((9 - 2) / 2 = 3.5 ~= 3.0) pixels gives a visual center in some
  // cases.
  [toolbarNode setToolsWithTextureKeys:@[ @"straight", @"curve", @"join" ]
                             rotations:@[ [NSNumber numberWithFloat:M_PI_2],
                                          [NSNumber numberWithFloat:M_PI_2],
                                          [NSNumber numberWithFloat:M_PI_2] ]
                               offsets:@[ [NSValue valueWithCGPoint:CGPointMake(18.0f, 0.0f)],
                                          [NSValue valueWithCGPoint:CGPointMake(3.0f, -3.0f)],
                                          [NSValue valueWithCGPoint:CGPointMake(3.0f, -3.0f)] ]];
  [hudNode addChild:toolbarNode];

  SKSpriteNode *terrainNode = [SKSpriteNode spriteNodeWithImageNamed:@"earth-map.jpg"];
  // noob: Using a tip to use replace blend mode for opaque sprites, but since
  // JPGs don't have an alpha channel in the source, does this really do anything?
  terrainNode.blendMode = SKBlendModeReplace;
  terrainNode.scale = 4.0f;
  [worldNode addChild:terrainNode];
  
  SKLabelNode *train1 = [SKLabelNode labelNodeWithFontNamed:@"Helvetica"];
  train1.text = @"TRAIN";
  train1.fontSize = 30;
  train1.position = CGPointMake(CGRectGetMidX(self.frame),
                                CGRectGetMidY(self.frame));
  [trainNode addChild:train1];

  SKSpriteNode *track1 = [self FL_createTrackSprite:nil withTexture:@"straight" parent:trackNode];
  track1.position = CGPointMake(_gridSize * 1, _gridSize * 1);
  track1.zRotation = M_PI_2;
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

  // TODO: Change to pan gesture; use tap gesture for selection.
  // TODO: Pinch gesture for zoom.

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
  // TODO: Probably move this code out of toolbar node delegate, since it will be the same code
  // for moving any piece in the track layer.  Unclear if the action should happen in the track layer, hud
  // layer, or maybe just in the top-level scene with a high z-position.
  
  SKNode *hudNode = [self childNodeWithName:@"hud"];
  SKNode *toolInUse = [hudNode childNodeWithName:@"toolInUse"];
  if (toolInUse) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" began, but toolInUse node already exists.", tool];
  };
  toolInUse = [self FL_createTrackSprite:@"toolInUse" withTexture:tool parent:hudNode];
  toolInUse.position = [hudNode convertPoint:location fromNode:toolbarNode];
  toolInUse.zRotation = M_PI_2;
  toolInUse.alpha = 0.5f;
  toolInUse.zPosition = FLZPositionHudToolInUse;

  SKNode *worldNode = [self childNodeWithName:@"world"];
  SKNode *trackNode = [worldNode childNodeWithName:@"track"];
  SKNode *trackAdding = [trackNode childNodeWithName:@"trackAdding"];
  if (trackAdding) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" began, but trackAdding node already exists.", tool];
  }
  trackAdding = [self FL_createTrackSprite:@"trackAdding" withTexture:tool parent:trackNode];
  trackAdding.zRotation = M_PI_2;
  trackAdding.zPosition = FLZPositionTrackAdding;
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
  SKNode *trackAdding = [trackNode childNodeWithName:@"trackAdding"];
  if (!trackAdding) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" moved, but no trackAdding node exists.", tool];
  }
  CGPoint trackToolPosition = [trackNode convertPoint:location fromNode:toolbarNode];
  int gridX = int(floorf(trackToolPosition.x / _gridSize + 0.5f));
  int gridY = int(floorf(trackToolPosition.y / _gridSize + 0.5f));
  trackAdding.position = CGPointMake(gridX * _gridSize, gridY * _gridSize);
  // note: The candidate trackAdding piece isn't added until there's some movement on the
  // tool.  A less hacky-looking way to do this would be to more-explicitly test the distance
  // moved since touch began, and add the trackAdding piece to the parent once the movement
  // crosses a threshhold.
  if (![trackAdding parent]) {
    [trackNode addChild:trackAdding];
  }
  // HERE HERE HERE: Temporarily remove/hide any track piece in that grid location.
  // Seems a bit error-prone, since the model isn't separate from our view of it here.
  [self FL_selectTrackGridX:gridX gridY:gridY];
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
  SKNode *trackAdding = [trackNode childNodeWithName:@"trackAdding"];
  if (!trackAdding) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" moved, but no trackAdding node exists.", tool];
  }
  trackAdding.name = nil;
  // note: The added track remains selected.
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
  SKNode *trackAdding = [trackNode childNodeWithName:@"trackAdding"];
  if (!trackAdding) {
    [NSException raise:@"FLBadToolbarState"
                format:@"Toolbar says tool \"%@\" moved, but no trackAdding node exists.", tool];
  }
  [trackAdding removeFromParent];
  [self FL_selectTrackClear];
}

#pragma mark -
#pragma mark Common

/**
 * Creates a sprite using the shared texture store, and configures it to be placed in the track layer.
 *
 * @param The name of the sprite; nil for none.
 * @param The texture key used by the texture store.
 */
- (SKSpriteNode *)FL_createTrackSprite:(NSString *)spriteName withTexture:(NSString *)textureKey parent:(SKNode *)parent
{
  SKTexture *texture = [[FLTextureStore sharedStore] textureForKey:textureKey];
  SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithTexture:texture];
  sprite.name = spriteName;
  [parent addChild:sprite];
  sprite.scale = _artScale;
  sprite.zPosition = FLZPositionTrackPlaced;
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
  SKNode *worldNode = [self childNodeWithName:@"world"];
  SKNode *trackNode = [worldNode childNodeWithName:@"track"];
  SKSpriteNode *selection = (SKSpriteNode *)[trackNode childNodeWithName:@"selection"];
  if (!selection) {
    selection = [SKSpriteNode spriteNodeWithColor:[UIColor colorWithWhite:1.0f alpha:0.3f] size:CGSizeMake(_artTrackSizeBasic, _artTrackSizeBasic)];
    selection.name = @"selection";
    selection.scale = _artScale;
    selection.zPosition = FLZPositionTrackSelection;
    [trackNode addChild:selection];
  }
  selection.position = CGPointMake(gridX * _gridSize, gridY * _gridSize);
}

- (void)FL_selectTrackClear
{
  SKNode *worldNode = [self childNodeWithName:@"world"];
  SKNode *trackNode = [worldNode childNodeWithName:@"track"];
  SKNode *selection = [trackNode childNodeWithName:@"selection"];
  if (selection) {
    [selection removeFromParent];
  }
}

@end
