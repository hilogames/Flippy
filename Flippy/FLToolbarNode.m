//
//  FLToolbarNode.m
//  Flippy
//
//  Created by Karl Voskuil on 12/12/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLToolbarNode.h"

#import "FLTextureStore.h"

static const CGFloat FLToolbarBorderSize = 3.0f;
static const CGFloat FLToolbarToolSeparatorSize = 3.0f;
static const CGFloat FLToolbarToolPadSize = -1.0f;

@implementation FLToolbarNode
{
  NSMutableArray *_toolButtonNodes;
  NSString *_toolMoving;
}

- (id)init
{
  CGSize emptySize = CGSizeMake(FLToolbarBorderSize * 2, FLToolbarBorderSize * 2);
  self = [super initWithColor:[UIColor colorWithWhite:0.0f alpha:0.2f] size:emptySize];
  if (self) {
    self.userInteractionEnabled = YES;
  }
  return self;
}

- (void)setToolsWithTextureKeys:(NSArray *)keys rotations:(NSArray *)rotations offsets:(NSArray *)offsets
{
  // noob: If we can assume properties of the toolbar node, like anchorPoint and zPosition,
  // then we could use simpler calculations here.  But no, for now assume those properties
  // should be determined by the owner, and we should always set our children relative.
  
  [self removeAllChildren];
  _toolButtonNodes = [NSMutableArray array];
  
  NSMutableArray *toolNodes = [NSMutableArray array];
  CGFloat toolsWidth = 0.0f;
  CGFloat toolsHeight = 0.0f;
  for (NSString *key in keys) {
    SKTexture *toolTexture = [[FLTextureStore sharedStore] textureForKey:key];
    SKSpriteNode *toolNode = [SKSpriteNode spriteNodeWithTexture:toolTexture];
    [toolNodes addObject:toolNode];
    toolsWidth += toolNode.size.width;
    if (toolNode.size.height > toolsHeight) {
      toolsHeight = toolNode.size.height;
    }
  }

  NSUInteger toolsCount = [toolNodes count];
  CGFloat toolbarWidth = toolsWidth
    + FLToolbarToolSeparatorSize * (toolsCount - 1)
    + FLToolbarToolPadSize * (toolsCount * 2)
    + FLToolbarBorderSize * 2;
  CGFloat toolbarHeight = toolsHeight
    + FLToolbarToolPadSize * 2
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
    
    SKSpriteNode *toolButtonNode = [SKSpriteNode spriteNodeWithColor:[UIColor colorWithWhite:1.0f alpha:0.3f]
                                                                size:CGSizeMake(toolNode.size.width + FLToolbarToolPadSize * 2,
                                                                                toolsHeight + FLToolbarToolPadSize * 2)];
    toolButtonNode.name = key;
    toolButtonNode.zPosition = self.zPosition + 1.0f;
    toolButtonNode.anchorPoint = CGPointMake(0.0f, 0.0f);
    toolButtonNode.position = CGPointMake(x, y);
    [self addChild:toolButtonNode];
    [_toolButtonNodes addObject:toolButtonNode];

    toolNode.zPosition = self.zPosition + 2.0f;
    toolNode.anchorPoint = CGPointMake(0.5f, 0.5f);
    toolNode.position = CGPointMake(x + toolNode.size.width / 2.0f + FLToolbarToolPadSize + offset.x,
                                    y + toolNode.size.height / 2.0f + FLToolbarToolPadSize + offset.y);
    toolNode.zRotation = rotation;
    [self addChild:toolNode];

    x += toolNode.size.width + FLToolbarToolPadSize * 2 + FLToolbarToolSeparatorSize;
  }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  if (!self.delegate) {
    return;
  }

  _toolMoving = nil;

  UITouch *touch = [touches anyObject];
  // noob: I was confused by doing the [child containsPoint] test using
  // a locationInNode:child, which didn't work.  But I think it makes
  // sense that the contains test is in the parent's coordinates; after
  // all, the child always thinks of itself in terms of position, which
  // is in the parent's coordinate system.
  CGPoint location = [touch locationInNode:self];
  // note: If tool buttons were uniform width, then could easily avoid linear
  // search.  Can certainly change to binary search if this proves too slow.
  for (SKSpriteNode *toolButtonNode in _toolButtonNodes) {
    if ([toolButtonNode containsPoint:location]) {
      _toolMoving = toolButtonNode.name;
      [self.delegate toolBarNode:self toolBegan:toolButtonNode.name location:location];
      break;
    }
  }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  if (!self.delegate) {
    return;
  }
  if (!_toolMoving) {
    return;
  }
  UITouch *touch = [touches anyObject];
  CGPoint location = [touch locationInNode:self];
  [self.delegate toolBarNode:self toolMoved:_toolMoving location:location];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  if (!self.delegate) {
    return;
  }
  if (!_toolMoving) {
    return;
  }
  UITouch *touch = [touches anyObject];
  CGPoint location = [touch locationInNode:self];
  [self.delegate toolBarNode:self toolEnded:_toolMoving location:location];
  _toolMoving = nil;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  if (!self.delegate) {
    return;
  }
  if (!_toolMoving) {
    return;
  }
  UITouch *touch = [touches anyObject];
  CGPoint location = [touch locationInNode:self];
  [self.delegate toolBarNode:self toolCancelled:_toolMoving location:location];
  _toolMoving = nil;
}

@end
