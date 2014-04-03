//
//  FLToolbarNode.m
//  Flippy
//
//  Created by Karl Voskuil on 12/12/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

// noob: See notes in notes/objective-c.txt.  I spent time thinking about how this
// SKNode subclass should detect and respond to gestures from gesture recognizers.
// Seems a bit awkward and tightly-coupled.

#import "FLToolbarNode.h"

#import "FLTextureStore.h"

static const CGFloat FLToolbarBorderSize = 3.0f;
static const CGFloat FLToolbarToolSeparatorSize = 3.0f;

static UIColor *FLToolbarColorBackground;
static UIColor *FLToolbarColorButtonNormal;
static UIColor *FLToolbarColorButtonHighlighted;

@implementation FLToolbarNode
{
  NSMutableArray *_toolButtonNodes;
  CGPoint _lastOrigin;
}

+ (void)initialize
{
  FLToolbarColorBackground = [UIColor colorWithWhite:0.0f alpha:0.2f];
  FLToolbarColorButtonNormal = [UIColor colorWithWhite:1.0f alpha:0.3f];
  FLToolbarColorButtonHighlighted = [UIColor colorWithWhite:1.0f alpha:0.7f];
}

- (id)init
{
  CGSize emptySize = CGSizeMake(FLToolbarBorderSize * 2, FLToolbarBorderSize * 2);
  self = [super initWithColor:FLToolbarColorBackground size:emptySize];
  if (self) {
    _toolPad = 0.0f;
  }
  return self;
}

- (void)setToolsWithTextureKeys:(NSArray *)keys sizes:(NSArray *)sizes rotations:(NSArray *)rotations offsets:(NSArray *)offsets
{
  // noob: If we can assume properties of the toolbar node, like anchorPoint and zPosition,
  // then we could use simpler calculations here.  But no, for now assume those properties
  // should be determined by the owner, and we should always set our children relative.
  
  [self removeAllChildren];
  _toolButtonNodes = [NSMutableArray array];
  
  NSMutableArray *toolNodes = [NSMutableArray array];
  CGFloat toolsWidth = 0.0f;
  CGFloat toolsHeight = 0.0f;
  for (int i = 0; i < [keys count]; ++i) {
    NSString *key = [keys objectAtIndex:i];
    SKTexture *toolTexture = [[FLTextureStore sharedStore] textureForKey:key];
    CGSize size = toolTexture.size;
    if (sizes) {
      [[sizes objectAtIndex:i] getValue:&size];
    }
    SKSpriteNode *toolNode = [SKSpriteNode spriteNodeWithTexture:toolTexture size:size];
    [toolNodes addObject:toolNode];
    toolsWidth += toolNode.size.width;
    if (toolNode.size.height > toolsHeight) {
      toolsHeight = toolNode.size.height;
    }
  }

  NSUInteger toolsCount = [toolNodes count];
  CGFloat toolbarWidth = toolsWidth
    + FLToolbarToolSeparatorSize * (toolsCount - 1)
    + _toolPad * (toolsCount * 2)
    + FLToolbarBorderSize * 2;
  CGFloat toolbarHeight = toolsHeight
    + _toolPad * 2
    + FLToolbarBorderSize * 2;
  self.size = CGSizeMake(toolbarWidth, toolbarHeight);

  CGFloat x = self.anchorPoint.x * toolbarWidth * -1 + FLToolbarBorderSize;
  CGFloat y = self.anchorPoint.y * toolbarHeight * -1 + FLToolbarBorderSize;
  for (int i = 0; i < [toolNodes count]; ++i) {
    NSString *key = [keys objectAtIndex:i];
    SKSpriteNode *toolNode = [toolNodes objectAtIndex:i];
    CGFloat rotation = [[rotations objectAtIndex:i] floatValue];
    CGPoint offset = CGPointZero;
    if (offsets) {
      [[offsets objectAtIndex:i] getValue:&offset];
    }
    
    SKSpriteNode *toolButtonNode = [SKSpriteNode spriteNodeWithColor:FLToolbarColorButtonNormal
                                                                size:CGSizeMake(toolNode.size.width + _toolPad * 2,
                                                                                toolsHeight + _toolPad * 2)];
    toolButtonNode.name = key;
    toolButtonNode.zPosition = 0.1f;
    toolButtonNode.anchorPoint = CGPointMake(0.0f, 0.0f);
    toolButtonNode.position = CGPointMake(x, y);
    [self addChild:toolButtonNode];
    [_toolButtonNodes addObject:toolButtonNode];

    toolNode.zPosition = 0.1f;
    toolNode.anchorPoint = CGPointMake(0.5f, 0.5f);
    toolNode.position = CGPointMake(toolNode.size.width / 2.0f + _toolPad + offset.x,
                                    toolNode.size.height / 2.0f + _toolPad + offset.y);
    toolNode.zRotation = rotation;
    [toolButtonNode addChild:toolNode];

    x += toolNode.size.width + _toolPad * 2 + FLToolbarToolSeparatorSize;
  }
}

- (NSUInteger)toolCount
{
  return [_toolButtonNodes count];
}

- (NSString *)toolAtLocation:(CGPoint)location
{
  for (SKSpriteNode *toolButtonNode in _toolButtonNodes) {
    if ([toolButtonNode containsPoint:location]) {
      return toolButtonNode.name;
    }
  }
  return nil;
}

- (CGRect)toolFrame:(NSString *)key
{
  for (SKSpriteNode *toolButtonNode in _toolButtonNodes) {
    if ([toolButtonNode.name isEqualToString:key]) {
      return toolButtonNode.frame;
    }
  }
  return CGRectZero;
}

- (void)setHighlight:(BOOL)highlight forTool:(NSString *)key
{
  for (SKSpriteNode *toolButtonNode in _toolButtonNodes) {
    if ([toolButtonNode.name isEqualToString:key]) {
      if (highlight) {
        toolButtonNode.color = FLToolbarColorButtonHighlighted;
      } else {
        toolButtonNode.color = FLToolbarColorButtonNormal;
      }
      break;
    }
  }
}

- (void)setEnabled:(BOOL)enabled forTool:(NSString *)key
{
  for (SKSpriteNode *toolButtonNode in _toolButtonNodes) {
    if ([toolButtonNode.name isEqualToString:key]) {
      if (enabled) {
        toolButtonNode.alpha = 1.0f;
      } else {
        toolButtonNode.alpha = 0.4f;
      }
      break;
    }
  }
}

- (void)showWithOrigin:(CGPoint)origin finalPosition:(CGPoint)finalPosition fullScale:(CGFloat)fullScale animated:(BOOL)animated
{
  // noob: I'm encapsulating this animation within the toolbar, since the toolbar knows cool ways to make itself
  // appear, and can track some useful state.  But the owner of this toolbar knows the anchor, position, size, and
  // scale of this toolbar, which then all needs to be communicated to this animation method.  Kind of a pain.

  // noob: I assume this will always take effect before we are removed from parent (at the end of the hide).
  [self removeActionForKey:@"hide"];
  
  if (animated) {
    const NSTimeInterval FLToolbarNodeShowDuration = 0.15;
    self.xScale = 0.0f;
    self.yScale = 0.0f;
    SKAction *grow = [SKAction scaleTo:fullScale duration:FLToolbarNodeShowDuration];
    self.position = origin;
    SKAction *move = [SKAction moveTo:finalPosition duration:FLToolbarNodeShowDuration];
    SKAction *showGroup = [SKAction group:@[ grow, move ]];
    showGroup.timingMode = SKActionTimingEaseOut;
    [self runAction:showGroup];
  } else {
    self.position = finalPosition;
    self.xScale = fullScale;
    self.yScale = fullScale;
  }
  _lastOrigin = origin;
}

- (void)hideAnimated:(BOOL)animated
{
  if (animated) {
    const NSTimeInterval FLToolbarNodeHideDuration = 0.15;
    SKAction *shrink = [SKAction scaleTo:0.0f duration:FLToolbarNodeHideDuration];
    SKAction *move = [SKAction moveTo:_lastOrigin duration:FLToolbarNodeHideDuration];
    SKAction *hideGroup = [SKAction group:@[ shrink, move]];
    hideGroup.timingMode = SKActionTimingEaseIn;
    SKAction *remove = [SKAction removeFromParent];
    SKAction *hideSequence = [SKAction sequence:@[ hideGroup, remove ]];
    [self runAction:hideSequence withKey:@"hide"];
  } else {
    [self removeFromParent];
  }
}

@end
