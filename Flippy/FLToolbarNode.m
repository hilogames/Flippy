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

  // noob: Hacking my own tap vs. pan gesture recognizers here, because we're just an SKNode, and don't
  // control our scene's view.  Other possible (better?) solution: This class (and classes like it)
  // could have gestures routed to them from the main SKScene gesture recognizer delegates; either the
  // scene could explicitly and temporarily set us as the delegate when the gesture starts in our
  // domain, or it could forward each particular gesture callback to us.  Or: This class perhaps cannot
  // be separated completely from the scene because of this kind of thing; it should be implemented as
  // a private subclass (what I'm calling a "Helper") with private access to the scene.  Or: Maybe
  // gesture recognizers need to be rewritten so they can work on an SKNode, not just on a UIView.
  // After all, apparently the view and scene know how to forward touchesBegan for us; why not make
  // it their job to forward gesture recognizers, too?  Check future iOS releases.

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
      if (_delegate && [_delegate respondsToSelector:@selector(toolbarNode:toolMoveBegan:location:)]) {
        [_delegate toolbarNode:self toolMoveBegan:toolButtonNode.name location:location];
      }
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
  if (_delegate && [_delegate respondsToSelector:@selector(toolbarNode:toolMoveChanged:location:)]) {
    [_delegate toolbarNode:self toolMoveChanged:_toolMoving location:location];
  }
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
  if (_delegate && [_delegate respondsToSelector:@selector(toolbarNode:toolMoveEnded:location:)]) {
    [_delegate toolbarNode:self toolMoveEnded:_toolMoving location:location];
  }
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
  if (_delegate && [_delegate respondsToSelector:@selector(toolbarNode:toolMoveCancelled:location:)]) {
    [_delegate toolbarNode:self toolMoveCancelled:_toolMoving location:location];
  }
  _toolMoving = nil;
}

@end
