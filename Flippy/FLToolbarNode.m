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
  FLToolbarColorBackground = [UIColor colorWithWhite:0.0f alpha:0.5f];
  FLToolbarColorButtonNormal = [UIColor colorWithWhite:0.7f alpha:0.5f];
  FLToolbarColorButtonHighlighted = [UIColor colorWithWhite:1.0f alpha:0.8f];
}

- (id)init
{
  return [self initWithSize:CGSizeZero];
}

- (id)initWithSize:(CGSize)size
{
  self = [super initWithColor:FLToolbarColorBackground size:size];
  if (self) {
    _toolPad = 0.0f;
    _automaticHeight = NO;
    _automaticWidth = NO;
    _justification = FLToolbarNodeJustificationCenter;
    _borderSize = 4.0f;
    _toolSeparatorSize = 4.0f;
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

  // noob: Calculate sizes in an unscaled environment, and then re-apply scale once finished.
  // I'm pretty sure this is a hack, but I'm too lazy to prove it (and fix it).  The self.size
  // and self.frame.size both account for current scale.  Doing the math without changing the
  // current scale should just mean multiplying all the non-scaled values (texture natural size,
  // pads and borders) by self.scale, or, alternately, dividing self.size by self.scale for
  // calculation and then multiplying/dividing right before actually setting dimensions in the
  // scaled world (?).  But a quick attempt to do so didn't give the exact right results, and
  // so I gave up; this is easier, and immediately worked.  Liek I said: probably a hack.
  CGFloat oldXScale = self.xScale;
  CGFloat oldYScale = self.yScale;
  self.xScale = 1.0f;
  self.yScale = 1.0f;
  
  // Find natural tool sizes (based on sizes of textures).
  NSUInteger toolsCount = [keys count];
  CGSize naturalToolsSize = CGSizeZero;
  for (int i = 0; i < toolsCount; ++i) {
    NSString *key = [keys objectAtIndex:i];
    SKTexture *toolTexture = [[FLTextureStore sharedStore] textureForKey:key];
    if (!toolTexture) {
      [NSException raise:@"FLToolbarNodeMissingTexture" format:@"Missing texture for key '%@'.", key];
    }
    CGFloat rotation = M_PI_2;
    if (rotations) {
      rotation = [[rotations objectAtIndex:i] floatValue];
    }
    CGSize naturalToolSize = FL_rotatedSizeBounds(toolTexture.size, rotation);
    naturalToolsSize.width += naturalToolSize.width;
    if (naturalToolSize.height > naturalToolsSize.height) {
      naturalToolsSize.height = naturalToolSize.height;
    }
  }

  // TODO: Some pretty ugly quantization of border sizes and/or tool locations when scaling sizes.
  // I think it's only when the toolbar node itself is scaled (by the owner), but it might also
  // result from any fractional pixel sizes when scaling internally.  Most obvious: As the toolbar
  // increases in size by one full pixel, the extra row of pixels will appear to be allocated to
  // either the top border, or the bottom border, or the tools; the border sizes will look off-by-one.
  // A guess: Try integer rounding on the natural tool size, because the rotation code tends to leave size
  // values looking like 161.9999999985.
  //
  // TODO: It might be the same problem causing e.g. segment tools to look bad when scaled down
  // less than 1.0 to fit the toolbar, but on the other hand, that might just be the "nearest"
  // filtering mode of the texture as specified in the texture store.  However, I tried changing
  // it to "linear" and it didn't antialias as far as I could tell, so maybe there's something else
  // going on, as in the first paragraph above.

  // Calculate tool scale and set toolbar size.
  //
  // note: If caller would like to prevent tools from growing past their natural size,
  // even when a large toolbar size is specified, we could add an option to limit
  // finalToolsScale to 1.0f.
  CGSize toolbarConstantSize = CGSizeMake(_toolSeparatorSize * (toolsCount - 1) + _toolPad * (toolsCount * 2) + _borderSize * 2,
                                          _toolPad * 2 + _borderSize * 2);
  CGFloat finalToolsScale;
  if (_automaticWidth && _automaticHeight) {
    finalToolsScale = 1.0f;
    self.size = CGSizeMake(naturalToolsSize.width + toolbarConstantSize.width,
                           naturalToolsSize.height + toolbarConstantSize.height);
  } else if (_automaticWidth) {
    finalToolsScale = (self.size.height - toolbarConstantSize.height) / naturalToolsSize.height;
    self.size = CGSizeMake(naturalToolsSize.width * finalToolsScale + toolbarConstantSize.width,
                           self.size.height);
  } else if (_automaticHeight) {
    finalToolsScale = (self.size.width - toolbarConstantSize.width) / naturalToolsSize.width;
    self.size = CGSizeMake(self.size.width,
                           naturalToolsSize.height * finalToolsScale + toolbarConstantSize.height);
  } else {
    finalToolsScale = MIN((self.size.width - toolbarConstantSize.width) / naturalToolsSize.width,
                          (self.size.height - toolbarConstantSize.height) / naturalToolsSize.height);
  }

  // Calculate justification offset.
  CGFloat justificationOffset = 0.0f;
  if (_justification == FLToolbarNodeJustificationLeft) {
    justificationOffset = 0.0f;
  } else {
    CGFloat remainingToolsWidth = self.size.width - toolbarConstantSize.width - naturalToolsSize.width * finalToolsScale;
    if (_justification == FLToolbarNodeJustificationCenter) {
      justificationOffset = remainingToolsWidth / 2.0f;
    } else {
      justificationOffset = remainingToolsWidth;
    }
  }
  
  // Set tools (scaled and positioned appropriately).
  CGFloat x = self.anchorPoint.x * self.size.width * -1.0f + _borderSize + justificationOffset;
  CGFloat y = self.anchorPoint.y * self.size.height * -1.0f + self.size.height / 2.0f;
  for (int i = 0; i < toolsCount; ++i) {

    NSString *key = [keys objectAtIndex:i];
    CGFloat rotation = M_PI_2;
    if (rotations) {
      rotation = [[rotations objectAtIndex:i] floatValue];
    }
    CGPoint offset = CGPointZero;
    if (offsets) {
      [[offsets objectAtIndex:i] getValue:&offset];
    }

    // note: Here the "tool" refers to the rectangular button area created in which
    // to draw the tool texture.
    SKTexture *toolTexture = [[FLTextureStore sharedStore] textureForKey:key];
    CGSize naturalToolSize = FL_rotatedSizeBounds(toolTexture.size, rotation);
    CGSize finalToolSize = CGSizeMake(naturalToolSize.width * finalToolsScale,
                                      naturalToolSize.height * finalToolsScale);

    SKSpriteNode *toolButtonNode = [SKSpriteNode spriteNodeWithColor:FLToolbarColorButtonNormal
                                                                size:CGSizeMake(finalToolSize.width + _toolPad * 2,
                                                                                finalToolSize.height + _toolPad * 2)];
    toolButtonNode.name = key;
    toolButtonNode.zPosition = 0.1f;
    toolButtonNode.anchorPoint = CGPointMake(0.0f, 0.5f);
    toolButtonNode.position = CGPointMake(x, y);
    [self addChild:toolButtonNode];
    [_toolButtonNodes addObject:toolButtonNode];

    SKSpriteNode *toolNode = [SKSpriteNode spriteNodeWithTexture:toolTexture size:finalToolSize];
    toolNode.zPosition = 0.1f;
    toolNode.anchorPoint = CGPointMake(0.5f, 0.5f);
    toolNode.position = CGPointMake(offset.x * finalToolsScale + finalToolSize.width / 2.0f + _toolPad,
                                    offset.y * finalToolsScale);
    toolNode.zRotation = rotation;
    [toolButtonNode addChild:toolNode];

    x += finalToolSize.width + _toolPad * 2 + _toolSeparatorSize;
  }
  
  self.xScale = oldXScale;
  self.yScale = oldYScale;
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
  SKSpriteNode *toolButtonNode = nil;
  for (toolButtonNode in _toolButtonNodes) {
    if ([toolButtonNode.name isEqualToString:key]) {
      if (highlight) {
        toolButtonNode.color = FLToolbarColorButtonHighlighted;
      } else {
        toolButtonNode.color = FLToolbarColorButtonNormal;
      }
    }
  }
}

- (void)animateHighlight:(BOOL)finalHighlight count:(int)blinkCount halfCycleDuration:(NSTimeInterval)halfCycleDuration forTool:(NSString *)key
{
  SKSpriteNode *toolButtonNode = nil;
  for (toolButtonNode in _toolButtonNodes) {
    if ([toolButtonNode.name isEqualToString:key]) {
      break;
    }
  }
  if (!toolButtonNode) {
    return;
  }

  BOOL startingHighlight = (toolButtonNode.color == FLToolbarColorButtonHighlighted);
  SKAction *blinkIn = [SKAction colorizeWithColor:(startingHighlight ? FLToolbarColorButtonNormal : FLToolbarColorButtonHighlighted) colorBlendFactor:1.0f duration:halfCycleDuration];
  blinkIn.timingMode = SKActionTimingEaseIn;
  SKAction *blinkOut = [SKAction colorizeWithColor:(startingHighlight ? FLToolbarColorButtonHighlighted : FLToolbarColorButtonNormal) colorBlendFactor:1.0f duration:halfCycleDuration];
  blinkOut.timingMode = SKActionTimingEaseOut;
  NSMutableArray *blinkActions = [NSMutableArray array];
  for (int b = 0; b < blinkCount; ++b) {
    [blinkActions addObject:blinkIn];
    [blinkActions addObject:blinkOut];
  }
  if (startingHighlight != finalHighlight) {
    [blinkActions addObject:blinkIn];
  }

  [toolButtonNode runAction:[SKAction sequence:blinkActions]];
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

CGSize FL_rotatedSizeBounds(CGSize size, CGFloat theta)
{
  CGFloat widthRotatedWidth = size.width * cosf(theta);
  CGFloat widthRotatedHeight = size.width * sinf(theta);
  CGFloat heightRotatedWidth = size.height * sinf(theta);
  CGFloat heightRotatedHeight = size.height * cosf(theta);
  return CGSizeMake(widthRotatedWidth + heightRotatedWidth,
                    widthRotatedHeight + heightRotatedHeight);
}

@end
