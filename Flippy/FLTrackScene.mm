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
    _artTrackSizeBasic = 32.0f;
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
  worldNode.zPosition = 0.0f;
  [self addChild:worldNode];

  SKNode *trackNode = [SKNode node];
  trackNode.name = @"track";
  trackNode.zPosition = 1.0f;
  [worldNode addChild:trackNode];

  SKNode *trainNode = [SKNode node];
  trainNode.name = @"train";
  trainNode.zPosition = 2.0f;
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

  [self FL_createTrackSprite:nil withTexture:@"straight" parent:trackNode x:0 y:0];
}

/**
 * Creates a sprite using the shared texture store, and configures it to be placed in the track layer.
 *
 * @param The name of the sprite; nil for none.
 * @param The texture key used by the texture store.
 */
- (SKSpriteNode *)FL_createTrackSprite:(NSString *)spriteName withTexture:(NSString *)textureKey parent:(SKNode *)parent x:(int)x y:(int)y
{
  SKTexture *texture = [[FLTextureStore sharedStore] textureForKey:textureKey];
  SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithTexture:texture];
  sprite.name = spriteName;
  [parent addChild:sprite];
  sprite.scale = _artScale;
  sprite.anchorPoint = CGPointMake(0.0f, 0.0f);
  sprite.position = CGPointMake(_gridSize * x, _gridSize * y);
  return sprite;
}

- (void)didSimulatePhysics
{
  // noob: If camera is following train constantly, then do FL_centerWorldOnCamera here.
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

  SKNode *worldNode = [self childNodeWithName:@"world"];
  SKNode *cameraNode = [worldNode childNodeWithName:@"camera"];
  UITouch *firstTouch = [touches anyObject];
  cameraNode.position = [firstTouch locationInNode:worldNode];
  [self FL_centerWorldOnCamera];
}

- (void)update:(CFTimeInterval)currentTime
{
}

@end
