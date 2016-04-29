//
//  FLSegmentNode.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/22/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
//

#import "FLSegmentNode.h"

#include <tgmath.h>
#import "FLTextureStore.h"

#import "FLPath.h"

const CGFloat FLSegmentArtSizeFull = 54.0f;
const CGFloat FLSegmentArtSizeBasic = 36.0f;
const CGFloat FLSegmentArtDrawnTrackNormalWidth = 14.0f;

const CGFloat FLSegmentArtBasicInset = (FLSegmentArtSizeFull - FLSegmentArtSizeBasic) / 2.0f;
const CGFloat FLSegmentArtInsideDrawnTrackInset = FLSegmentArtBasicInset + FLSegmentArtDrawnTrackNormalWidth / 2.0f;
// note: The straight segment runs along the visual edge of a square; we'd like to shift
// it to the visual center of the tool image.  Half the full texture size is the middle,
// but need to subtract out the amount that the (centerpoint of the) drawn tracks are already
// inset from the edge of the texture.
const CGFloat FLSegmentArtStraightShift = (FLSegmentArtSizeFull / 2.0f) - FLSegmentArtBasicInset;
// note: For the curves: The track textures don't appear visually centered because the
// drawn track is a full inset away from any perpendicular edge and only a small pad away
// from any parallel edge.  The pad is the difference between the drawn track centerpoint
// inset and half the width of the normal drawn track width.  So shift it inwards by half
// the difference between the edges.  The math simplifies down a bit.  Rounded to prevent
// aliasing (?).
const CGFloat FLSegmentArtCurveShift = floorf(FLSegmentArtDrawnTrackNormalWidth / 4.0f);

const char FLSegmentLabelNone = '\0';

static const unsigned int FLSegmentNodePathsMax = 2;

static const CGFloat FLZPositionBubble = -0.3f;
static const CGFloat FLZPositionReadoutValueBottom = -0.3f;
static const CGFloat FLZPositionReadoutValueTop = -0.2f;
static const CGFloat FLZPositionFlashOverlay = -0.1f;
static const CGFloat FLZPositionSwitch = 0.1f;
static const CGFloat FLZPositionLabel = 0.2f;

static const NSTimeInterval FLSwitchRotateDuration = 0.1f;
static const NSTimeInterval FLFlashDuration = 0.5;
static const NSTimeInterval FLColorizeDuration = 0.2f;

// note: Layout of components inside the "readout" (FLSegmentTypeReadout) segment
// are all scaled to a segment size of FLSegmentArtSizeFull x FLSegmentArtSizeFull,
// with origin in the lower left corner and "up" orientation pointing along the
// positive x-axis (as is standard for art assets).
static const CGFloat FLSegmentArtReadoutComponentInset = FLSegmentArtBasicInset;
static const CGFloat FLSegmentArtReadoutValueSize = 22.0f;
static const CGFloat FLSegmentArtReadoutSwitchSize = 39.0f;
static CGPoint FLReadoutValue0Position = {
  FLSegmentArtSizeFull / 2.0f,
  FLSegmentArtReadoutComponentInset + FLSegmentArtReadoutValueSize / 2.0f,
};
static CGPoint FLReadoutValue1Position = {
  FLSegmentArtSizeFull - FLSegmentArtReadoutComponentInset - FLSegmentArtReadoutValueSize / 2.0f,
  FLSegmentArtSizeFull - FLSegmentArtReadoutComponentInset - FLSegmentArtReadoutValueSize / 2.0f
};
static CGPoint FLReadoutSwitchPosition = {
  FLSegmentArtReadoutComponentInset + FLSegmentArtReadoutValueSize / 4.0f,
  FLSegmentArtSizeFull - FLSegmentArtReadoutComponentInset - FLSegmentArtReadoutValueSize / 2.0f
};
static CGPoint FLReadoutInOutPosition = {
  FLSegmentArtReadoutComponentInset,
  FLReadoutValue0Position.y
};

static SKColor *FLSegmentArtPixel0Color;
static SKColor *FLSegmentArtPixel1Color;

using namespace std;

@implementation FLSegmentNode
{
  // note: Some data members are unneeded for some segment types, and so could
  // be so could be encoded by class rather than by data members.  For now,
  // no worries; at the least, making segment type dynamic allows changing
  // segment type on [flip].
  int _switchPathId;
}

+ (void)initialize
{
  FLSegmentArtPixel0Color = [SKColor colorWithWhite:0.0f alpha:0.75f];
  FLSegmentArtPixel1Color = [SKColor colorWithWhite:1.0f alpha:0.75f];
}

- (instancetype)initWithSegmentType:(FLSegmentType)segmentType
{
  if ([FLSegmentNode FL_hasDynamicTexture:segmentType]) {
    self = [super initWithColor:[SKColor clearColor] size:CGSizeMake(FLSegmentArtSizeFull, FLSegmentArtSizeFull)];
  } else {
    NSString *textureKey = [FLSegmentNode keyForSegmentType:segmentType];
    SKTexture *texture = [[FLTextureStore sharedStore] textureForKey:textureKey];
    self = [super initWithTexture:texture];
  }
  if (self) {
    _segmentType = segmentType;
    _switchPathId = 1;
    _mayShowLabel = YES;
    _mayShowSwitch = YES;
    _mayShowBubble = NO;
    [self FL_createContent];
  }
  return self;
}

- (void)FL_setSegmentType:(FLSegmentType)segmentType
{
  [self FL_deleteContent];
  if ([FLSegmentNode FL_hasDynamicTexture:segmentType]) {
    self.texture = nil;
    self.color = [SKColor clearColor];
    self.size = CGSizeMake(FLSegmentArtSizeFull, FLSegmentArtSizeFull);
  } else {
    NSString *textureKey = [FLSegmentNode keyForSegmentType:segmentType];
    SKTexture *texture = [[FLTextureStore sharedStore] textureForKey:textureKey];
    self.texture = texture;
  }
  _segmentType = segmentType;
  [self FL_createContent];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {
    _segmentType = (FLSegmentType)[aDecoder decodeIntegerForKey:@"segmentType"];
    _label = (char)[aDecoder decodeIntForKey:@"label"];
    // TODO: Some older archives were created switchPathId of -1 (meaning "no switch").  This
    // is now controlled by mayShowSwitch, instead, so initialize appropriately on decoding.
    // Can delete this code once (if) all archives have been recreated recently.
    int codedSwitchPathId = [aDecoder decodeIntForKey:@"switchPathId"];
    if (codedSwitchPathId == -1) {
      _switchPathId = 1;
    } else {
      _switchPathId = codedSwitchPathId;
    }
    _mayShowLabel = [aDecoder decodeBoolForKey:@"showsLabel"];
    // TODO: Some older archives were created without mayShowSwitch (and instead indicating a
    // hidden switch with a switchPathId of -1).  Initialize appropriately on decoding.
    // Can delete this code once (if) all archives have been recreated recently.
    if ([aDecoder containsValueForKey:@"showsSwitch"]) {
      _mayShowSwitch = [aDecoder decodeBoolForKey:@"showsSwitch"];
    } else {
      _mayShowSwitch = (codedSwitchPathId != -1);
    }
    _mayShowBubble = [aDecoder decodeBoolForKey:@"showsSwitchValue"];

    // note: Content is deleted before encoding; recreate it.
    [self FL_createContent];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  // note: Remove child node "content" (like switch) before encoding; it will be re-created
  // at decoding.  (This saves a little space, but the primary motivation here was to help
  // with the fact that I keep changing the appearance of the child nodes, which was
  // a problem because the textures would be reloaded but with the old texture size.)
  [self FL_deleteContent];
  [super encodeWithCoder:aCoder];
  // note: It might prove slow to delete and recreate; if so, we could remove and re-add
  // children instead, since that's the thing we're really trying to skip here (when we
  // call super).
  [self FL_createContent];

  [aCoder encodeInteger:_segmentType forKey:@"segmentType"];
  [aCoder encodeInt:(char)_label forKey:@"label"];
  [aCoder encodeInt:_switchPathId forKey:@"switchPathId"];
  [aCoder encodeBool:_mayShowLabel forKey:@"showsLabel"];
  [aCoder encodeBool:_mayShowSwitch forKey:@"showsSwitch"];
  // note: Value "bubble" was formerly known as just "switch value" until there was more
  // than one way to graphically show switch value.
  [aCoder encodeBool:_mayShowBubble forKey:@"showsSwitchValue"];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
  FLSegmentNode *copy = [super copyWithZone:zone];
  if (copy) {
    copy->_segmentType = _segmentType;
    copy->_label = _label;
    copy->_switchPathId = _switchPathId;
    copy->_mayShowLabel = _mayShowLabel;
    copy->_mayShowSwitch = _mayShowSwitch;
    copy->_mayShowBubble = _mayShowBubble;
    // note: Not calling [copy createContent] because all content is assumed to be
    // represented in the node tree.
  }
  return copy;
}

+ (NSString *)keyForSegmentType:(FLSegmentType)segmentType
{
  switch (segmentType) {
    case FLSegmentTypeStraight:
      return @"straight";
    case FLSegmentTypeCurve:
      return @"curve";
    case FLSegmentTypeJoinLeft:
      return @"join-left";
    case FLSegmentTypeJoinRight:
      return @"join-right";
    case FLSegmentTypeJogLeft:
      return @"jog-left";
    case FLSegmentTypeJogRight:
      return @"jog-right";
    case FLSegmentTypeCross:
      return @"cross";
    case FLSegmentTypePlatformLeft:
      return @"platform-left";
    case FLSegmentTypePlatformRight:
      return @"platform-right";
    case FLSegmentTypePlatformStartLeft:
      return @"platform-start-left";
    case FLSegmentTypePlatformStartRight:
      return @"platform-start-right";
    case FLSegmentTypeReadoutInput:
      return @"readout-input";
    case FLSegmentTypeReadoutOutput:
      return @"readout-output";
    case FLSegmentTypePixel:
      return @"pixel";
    case FLSegmentTypeNone:
    default:
      return nil;
  }
}

+ (BOOL)canFlip:(FLSegmentType)segmentType
{
  // note: For now, determine canFlip based only on segmentType and not orientation (e.g. for
  // a straight segment at rotation 0, a horizontal flip won't actually change anything, and
  // so could be disallowed).  Keeping flippability separate from orientation makes things
  // easier for our current callers, because then they don't have to keep checking back at
  // each rotation change.
  return (segmentType != FLSegmentTypeReadoutInput && segmentType != FLSegmentTypeReadoutOutput);
}

+ (BOOL)canSwitch:(FLSegmentType)segmentType
{
  return segmentType == FLSegmentTypeJoinLeft
    || segmentType == FLSegmentTypeJoinRight
    || segmentType == FLSegmentTypeReadoutInput
    || segmentType == FLSegmentTypeReadoutOutput
    || segmentType == FLSegmentTypePixel;
}

+ (BOOL)FL_hasDynamicTexture:(FLSegmentType)segmentType
{
  return segmentType == FLSegmentTypeReadoutInput
    || segmentType == FLSegmentTypeReadoutOutput
    || segmentType == FLSegmentTypePixel;
}

+ (BOOL)canShowSwitch:(FLSegmentType)segmentType
{
  // note: canSwitch says whether the segment is able to store a switch value.
  // canShowSwitch refers to whether the segment has a drawn switch or not.
  // Perhaps should rename the drawn switch to "handle" or "lever" or something
  // to reduce confusion.
  return segmentType == FLSegmentTypeJoinLeft
    || segmentType == FLSegmentTypeJoinRight
    || segmentType == FLSegmentTypeReadoutInput
    || segmentType == FLSegmentTypeReadoutOutput;
}

+ (BOOL)canShowBubble:(FLSegmentType)segmentType
{
  return segmentType == FLSegmentTypeJoinLeft
    || segmentType == FLSegmentTypeJoinRight
    || segmentType == FLSegmentTypePixel;
}

+ (UIImage *)createImageForReadoutSegment:(FLSegmentType)segmentType imageSize:(CGFloat)imageSize
{
  // TODO: Or just create a node and call textureFromNode?

  // note: Art constants in file are all scaled to full art size.  Our scaling
  // factor brings everything into imageSize.
  CGFloat scale = imageSize / FLSegmentArtSizeFull;

  FLTextureStore *textureStore = [FLTextureStore sharedStore];

  UIGraphicsBeginImageContext(CGSizeMake(imageSize, imageSize));
  CGContextRef context = UIGraphicsGetCurrentContext();
  // note: Flip, to account for differences in coordinate system for UIImage.
  CGContextTranslateCTM(context, 0.0f, imageSize);
  CGContextScaleCTM(context, 1.0f, -1.0f);
  // note: The images we are composing -- and the image we want to produce -- have a standard
  // "up" pointing to the right of the UIImage; the graphics context has a coordinate system with
  // origin in the lower left.  We could rotate the context and draw with "up" along the positive
  // y-axis, but then we'd have to rotate again in order to draw our images so that their "up" is
  // up.  Instead, let's just do the math so that "up" goes along the positive x-axis of our context:
  // this means you'll see width calculations being used in the y-dimension, and height in the x, etc.
  // Here's the rotating code commented out just in case I change my mind:
  //CGContextTranslateCTM(context, 0.0f, imageSize);
  //CGContextRotateCTM(context, -(CGFloat)M_PI_2);

  const CGFloat scaledReadoutValueSize = FLSegmentArtReadoutValueSize * scale;
  const CGFloat scaledReadoutSwitchSize = FLSegmentArtReadoutSwitchSize * scale;

  UIImage *value0Image = [textureStore imageForKey:@"value-0"];
  CGRect value0Rect = CGRectMake((FLReadoutValue0Position.x - FLSegmentArtReadoutValueSize / 2.0f) * scale,
                                 (FLReadoutValue0Position.y - FLSegmentArtReadoutValueSize / 2.0f) * scale,
                                 scaledReadoutValueSize,
                                 scaledReadoutValueSize);
  // note: The caller has put images into the FLTextureStore alongside textures, and we can use the
  // textures as clues about how to scale the images.  In particular, if the texture uses filtering
  // mode "nearest", then we're looking for a blocky, pixelated look.  Otherwise we want smooth.
  if ([textureStore textureForKey:@"value-0"].filteringMode == SKTextureFilteringNearest) {
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
  } else {
    CGContextSetInterpolationQuality(context, kCGInterpolationDefault);
  }
  CGContextDrawImage(context, value0Rect, [value0Image CGImage]);

  UIImage *value1Image = [textureStore imageForKey:@"value-1"];
  CGRect value1Rect = CGRectMake((FLReadoutValue1Position.x - FLSegmentArtReadoutValueSize / 2.0f) * scale,
                                 (FLReadoutValue1Position.y - FLSegmentArtReadoutValueSize / 2.0f) * scale,
                                 scaledReadoutValueSize,
                                 scaledReadoutValueSize);
  if ([textureStore textureForKey:@"value-1"].filteringMode == SKTextureFilteringNearest) {
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
  } else {
    CGContextSetInterpolationQuality(context, kCGInterpolationDefault);
  }
  CGContextDrawImage(context, value1Rect, [value1Image CGImage]);

  UIImage *switchImage = [textureStore imageForKey:@"switch"];
  CGRect switchRect = CGRectMake((FLReadoutSwitchPosition.x - FLSegmentArtReadoutSwitchSize / 2.0f) * scale,
                                 (FLReadoutSwitchPosition.y - FLSegmentArtReadoutSwitchSize / 2.0f) * scale,
                                 scaledReadoutSwitchSize,
                                 scaledReadoutSwitchSize);
  if ([textureStore textureForKey:@"switch"].filteringMode == SKTextureFilteringNearest) {
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
  } else {
    CGContextSetInterpolationQuality(context, kCGInterpolationDefault);
  }
  CGContextDrawImage(context, switchRect, [switchImage CGImage]);

  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

+ (UIImage *)createImageForPixelSegmentImageSize:(CGFloat)imageSize
{
  // note: Art constants in file are all scaled to full art size.  Our scaling
  // factor brings everything into imageSize.
  CGFloat scale = imageSize / FLSegmentArtSizeFull;

  UIGraphicsBeginImageContext(CGSizeMake(imageSize, imageSize));
  CGContextRef context = UIGraphicsGetCurrentContext();
  // note: Flip, to account for differences in coordinate system for UIImage.
  // commented out: Don't bother, since pixel segment is currently symmetrical.
  //CGContextTranslateCTM(context, 0.0f, imageSize);
  //CGContextScaleCTM(context, 1.0f, -1.0f);
  CGContextSetFillColorWithColor(context, [FLSegmentArtPixel1Color CGColor]);
  CGFloat scaledBasicInset = FLSegmentArtBasicInset * scale;
  CGFloat scaledBasicSize = FLSegmentArtSizeBasic * scale;
  CGContextFillRect(context, CGRectMake(scaledBasicInset, scaledBasicInset, scaledBasicSize, scaledBasicSize));
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

- (NSString *)segmentKey
{
  return [FLSegmentNode keyForSegmentType:_segmentType];
}

- (int)zRotationQuarters
{
  return convertRotationRadiansToQuarters(self.zRotation);
}

- (void)setZRotationQuarters:(int)zRotationQuarters
{
  self.zRotation = convertRotationQuartersToRadians(zRotationQuarters);
}

- (void)setZRotation:(CGFloat)zRotation
{
  [super setZRotation:zRotation];
  // note: The label and bubble both rotate independently from the segment node so that their
  // text is always right-side-up with respect to the scene.
  if (_mayShowLabel && _label != FLSegmentLabelNone) {
    [self FL_rotateContentLabel];
  }
  if (_mayShowBubble && [FLSegmentNode canShowBubble:_segmentType]) {
    [self FL_rotateContentBubble];
  }
}

- (BOOL)canFlip
{
  return [FLSegmentNode canFlip:_segmentType];
}

- (void)flip:(FLSegmentFlipDirection)flipDirection
{
  switch (_segmentType) {
    case FLSegmentTypeStraight: {
      int zRotationQuarters = self.zRotationQuarters;
      if ((zRotationQuarters + flipDirection) % 2 != 0) {
        self.zRotationQuarters = zRotationQuarters + 2;
      }
      break;
    }
    case FLSegmentTypeCurve: {
      int zRotationQuarters = self.zRotationQuarters;
      if ((zRotationQuarters + flipDirection) % 2 != 0) {
        self.zRotationQuarters = zRotationQuarters + 3;
      } else {
        self.zRotationQuarters = zRotationQuarters + 1;
      }
      break;
    }
    case FLSegmentTypeJoinLeft: {
      int zRotationQuarters = self.zRotationQuarters;
      [self FL_setSegmentType:FLSegmentTypeJoinRight];
      if ((zRotationQuarters + flipDirection) % 2 != 0) {
        self.zRotationQuarters = zRotationQuarters + 2;
      }
      break;
    }
    case FLSegmentTypeJoinRight: {
      int zRotationQuarters = self.zRotationQuarters;
      [self FL_setSegmentType:FLSegmentTypeJoinLeft];
      if ((zRotationQuarters + flipDirection) % 2 != 0) {
        self.zRotationQuarters = zRotationQuarters + 2;
      }
      break;
    }
    case FLSegmentTypeJogLeft:
      [self FL_setSegmentType:FLSegmentTypeJogRight];
      break;
    case FLSegmentTypeJogRight:
      [self FL_setSegmentType:FLSegmentTypeJogLeft];
      break;
    case FLSegmentTypeCross:
      // note: Cross has both vertical and horizontal symmetry in all rotations.
      break;
    case FLSegmentTypePlatformLeft: {
      int zRotationQuarters = self.zRotationQuarters;
      [self FL_setSegmentType:FLSegmentTypePlatformRight];
      if ((zRotationQuarters + flipDirection) % 2 != 0) {
        self.zRotationQuarters = zRotationQuarters + 2;
      }
      break;
    }
    case FLSegmentTypePlatformRight: {
      int zRotationQuarters = self.zRotationQuarters;
      [self FL_setSegmentType:FLSegmentTypePlatformLeft];
      if ((zRotationQuarters + flipDirection) % 2 != 0) {
        self.zRotationQuarters = zRotationQuarters + 2;
      }
      break;
    }
    case FLSegmentTypePlatformStartLeft: {
      int zRotationQuarters = self.zRotationQuarters;
      [self FL_setSegmentType:FLSegmentTypePlatformStartRight];
      if ((zRotationQuarters + flipDirection) % 2 != 0) {
        self.zRotationQuarters = zRotationQuarters + 2;
      }
      break;
    }
    case FLSegmentTypePlatformStartRight: {
      int zRotationQuarters = self.zRotationQuarters;
      [self FL_setSegmentType:FLSegmentTypePlatformStartLeft];
      if ((zRotationQuarters + flipDirection) % 2 != 0) {
        self.zRotationQuarters = zRotationQuarters + 2;
      }
      break;
    }
    case FLSegmentTypePixel:
      // note: Pixel has both vertical and horizontal symmetry in all rotations.
      break;
    case FLSegmentTypeReadoutInput:
    case FLSegmentTypeReadoutOutput:
    case FLSegmentTypeNone:
      break;
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type %ld.", (long)_segmentType];
  };
}

- (BOOL)canSwitch
{
  return [FLSegmentNode canSwitch:_segmentType];
}

- (int)switchPathId
{
  return _switchPathId;
}

- (void)setSwitchPathId:(int)switchPathId animated:(BOOL)animated
{
  if (switchPathId != 0 && switchPathId != 1) {
    [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d.", _switchPathId];
  }

  if (_switchPathId == switchPathId) {
    return;
  }

  _switchPathId = switchPathId;

  switch (_segmentType) {
    case FLSegmentTypeReadoutInput:
    case FLSegmentTypeReadoutOutput:
      [self FL_updateContentReadoutAnimated:animated];
      break;
    case FLSegmentTypePixel:
      [self FL_updateContentPixelAnimated:animated];
      break;
    default:
      // No special handling for segment type.
      break;
  }
  if (_mayShowSwitch && [FLSegmentNode canShowSwitch:_segmentType]) {
    [self FL_updateContentSwitchAnimated:animated];
  }
  if (_mayShowBubble && [FLSegmentNode canShowBubble:_segmentType]) {
    [self FL_updateContentBubbleAnimated:animated];
  }
}

- (int)toggleSwitchPathIdAnimated:(BOOL)animated
{
  if (_switchPathId == 1) {
    [self setSwitchPathId:0 animated:animated];
    return 0;
  } else {
    [self setSwitchPathId:1 animated:animated];
    return 1;
  }
}

- (void)setLabel:(char)label
{
  if (_label == label) {
    return;
  }
  if (_mayShowLabel) {
    if (label == FLSegmentLabelNone) {
      [self FL_deleteContentLabel];
    }
  }
  char oldLabel = _label;
  _label = label;
  if (_mayShowLabel) {
    if (oldLabel == FLSegmentLabelNone) {
      [self FL_createContentLabel];
    } else if (_label != FLSegmentLabelNone) {
      [self FL_updateContentLabel];
    }
  }
}

- (void)setMayShowLabel:(BOOL)mayShowLabel
{
  if (mayShowLabel == _mayShowLabel) {
    return;
  }
  if (_mayShowLabel) {
    if (_label != FLSegmentLabelNone) {
      [self FL_deleteContentLabel];
    }
  }
  _mayShowLabel = mayShowLabel;
  if (_mayShowLabel) {
    if (_label != FLSegmentLabelNone) {
      [self FL_createContentLabel];
    }
  }
}

- (BOOL)doesShowLabel
{
  return _mayShowLabel && _label != FLSegmentLabelNone;
}

- (void)setMayShowSwitch:(BOOL)mayShowSwitch
{
  if (mayShowSwitch == _mayShowSwitch) {
    return;
  }
  BOOL canShowSwitch = [FLSegmentNode canShowSwitch:_segmentType];
  if (_mayShowSwitch && canShowSwitch) {
    [self FL_deleteContentSwitch];
  }
  _mayShowSwitch = mayShowSwitch;
  if (_mayShowSwitch && canShowSwitch) {
    [self FL_createContentSwitch];
  }
}

- (BOOL)canShowSwitch
{
  return [FLSegmentNode canShowSwitch:_segmentType];
}

- (BOOL)doesShowSwitch
{
  return _mayShowSwitch && [FLSegmentNode canShowSwitch:_segmentType];
}

- (void)setMayShowBubble:(BOOL)mayShowBubble
{
  if (mayShowBubble == _mayShowBubble) {
    return;
  }
  BOOL canShowBubble = [FLSegmentNode canShowBubble:_segmentType];
  if (_mayShowBubble && canShowBubble) {
    [self FL_deleteContentBubble];
  }
  _mayShowBubble = mayShowBubble;
  if (_mayShowBubble && canShowBubble) {
    [self FL_createContentBubble];
  }
}

- (BOOL)canShowBubble
{
  return [FLSegmentNode canShowBubble:_segmentType];
}

- (BOOL)doesShowBubble
{
  return _mayShowBubble && [FLSegmentNode canShowBubble:_segmentType];
}

- (CGPoint)switchLinkLocation
{
  // note: Properly, should test _mayShowSwitch && [canShowSwitch].
  // But as a shortcut that handles all current situations: Either use
  // the switch node, if found, or else just return the center of the
  // segment node.
  CGPoint switchLinkLocation;
  SKNode *switchNode = [self childNodeWithName:@"switch"];
  if (switchNode) {
    switchLinkLocation = switchNode.position;
  } else {
    switchLinkLocation = CGPointZero;
  }
  return [self.parent convertPoint:switchLinkLocation fromNode:self];
}

- (void)getPoint:(CGPoint *)point rotation:(CGFloat *)rotationRadians forPath:(int)pathId progress:(CGFloat)progress scale:(CGFloat)scale
{
  const FLPath *path = [self FL_path:pathId];
  CGPoint pathPoint = path->getPoint(progress);
  // note: Scaling would seem to be the segment's job, which is why it's here.  But for space
  // optimizations, the segment doesn't actually know the scale of its own paths.  Either:
  // 1) Do it like this; 2) Pass the scale into the underlying shared paths; 3) Use a class
  // constant to define the scale for all segments; 4) Make the scale inferrable from the
  // segment's texure size, e.g. the pad on the outside is always 20% or whatever.  Meh,
  // whatever.
  point->x = self.position.x + pathPoint.x * scale;
  point->y = self.position.y + pathPoint.y * scale;
  if (rotationRadians) {
    *rotationRadians = path->getTangent(progress);
  }
}

- (BOOL)getClosestOnTrackPoint:(CGPoint *)onTrackPoint distance:(CGFloat *)distance rotation:(CGFloat *)rotationRadians path:(int *)pathId progress:(CGFloat *)progress forOffTrackPoint:(CGPoint)offTrackPoint scale:(CGFloat)scale precision:(CGFloat)progressPrecision
{
  const FLPath *paths[FLSegmentNodePathsMax];
  int pathCount = [self FL_allPaths:paths];
  if (pathCount == 0) {
    return NO;
  }

  // note: Again, note that path points are contained within the unit square centered on the origin.
  // Segment points, on the other hand, are in the segment's parent's coordinate system (that is,
  // comparable to the segment's position).
  CGPoint offPathPoint = CGPointMake((offTrackPoint.x - self.position.x) / scale,
                                     (offTrackPoint.y - self.position.y) / scale);

  int closestPathId = -1;
  CGPoint closestPoint;
  CGFloat closestProgress;
  CGFloat closestDistance;
  for (int p = 0; p < pathCount; ++p) {
    const FLPath *path = paths[p];
    CGPoint onPathPoint;
    CGFloat onPathProgress;
    CGFloat onPathDistance = path->getClosestOnPathPoint(&onPathPoint, &onPathProgress, offPathPoint, progressPrecision);
    if (closestPathId == -1 || onPathDistance < closestDistance) {
      closestPathId = p;
      closestPoint = onPathPoint;
      closestProgress = onPathProgress;
      closestDistance = onPathDistance;
    }
  }

  if (onTrackPoint) {
    onTrackPoint->x = closestPoint.x * scale + self.position.x;
    onTrackPoint->y = closestPoint.y * scale + self.position.y;
  }
  if (distance) {
    *distance = closestDistance;
  }
  if (rotationRadians) {
    *rotationRadians = paths[closestPathId]->getTangent(closestProgress);
  }
  if (pathId) {
    *pathId = closestPathId;
  }
  if (progress) {
    *progress = closestProgress;
  }
  return YES;
}

- (BOOL)getConnectingPath:(int *)pathId progress:(CGFloat *)progress forEndPoint:(CGPoint)endPoint scale:(CGFloat)scale
{
  BOOL hasSwitch = [FLSegmentNode canSwitch:_segmentType];
  return [self FL_getConnectingPath:pathId progress:progress forEndPoint:endPoint doRotationCheck:NO rotation:0.0f progress:0.0f scale:scale hasSwitch:hasSwitch switchPathId:_switchPathId];
}

- (BOOL)getConnectingPath:(int *)pathId
                 progress:(CGFloat *)progress
              forEndPoint:(CGPoint)endPoint
                 rotation:(CGFloat)forRotationRadians
                 progress:(CGFloat)forProgress
                    scale:(CGFloat)scale
{
  BOOL hasSwitch = [FLSegmentNode canSwitch:_segmentType];
  return [self FL_getConnectingPath:pathId progress:progress forEndPoint:endPoint doRotationCheck:YES rotation:forRotationRadians progress:forProgress scale:scale hasSwitch:hasSwitch switchPathId:_switchPathId];
}

- (BOOL)getConnectingPath:(int *)pathId
                 progress:(CGFloat *)progress
              forEndPoint:(CGPoint)endPoint
                 rotation:(CGFloat)forRotationRadians
                 progress:(CGFloat)forProgress
                    scale:(CGFloat)scale
                hasSwitch:(BOOL)hasSwitch
             switchPathId:(int)switchPathId
{
  return [self FL_getConnectingPath:pathId progress:progress forEndPoint:endPoint doRotationCheck:YES rotation:forRotationRadians progress:forProgress scale:scale hasSwitch:hasSwitch switchPathId:switchPathId];
}

- (BOOL)hasConnectingPathForEndPoint:(CGPoint)endPoint
                            rotation:(CGFloat)forRotationRadians
                            progress:(CGFloat)forProgress
                               scale:(CGFloat)scale
{
  int pathId;
  CGFloat progress;
  return [self FL_getConnectingPath:&pathId progress:&progress forEndPoint:endPoint doRotationCheck:YES rotation:forRotationRadians progress:forProgress scale:scale hasSwitch:NO switchPathId:0];
}

- (BOOL)FL_getConnectingPath:(int *)pathId
                    progress:(CGFloat *)progress
                 forEndPoint:(CGPoint)endPoint
             doRotationCheck:(BOOL)doRotationCheck
                    rotation:(CGFloat)forRotationRadians
                    progress:(CGFloat)forProgress
                       scale:(CGFloat)scale
                   hasSwitch:(BOOL)hasSwitch
                switchPathId:(int)switchPathId
{
  CGPoint pathEndPoint = CGPointMake((endPoint.x - self.position.x) / scale, (endPoint.y - self.position.y) / scale);

  // note: The required information about the paths -- i.e the path's endpoints, with
  // tangent and progress at those endpoints -- is known statically by the path itself.
  // Switch information -- i.e. which paths are being switched, and at which endpoints --
  // is known statically by the segment.  So this entire function could be written as a
  // single static lookup table.  But it seems like more fun to do all tests dynamically,
  // using simple getPoint() and getTangent() methods.

  // note: End points must be close together in order to connect, but there is currently
  // no need for a tight comparison, since end points are always snapped to a corner or
  // center of an edge.  Similarly, tangents at end points can (currently) only be at
  // right angles, so again, no need for a tight comparison.
  const CGFloat FLEndPointComparisonEpsilon = 0.1f;
  const CGFloat FLTangentComparisonEpsilon = 0.1f;

  // note: Tangents have direction (whatdya call it: theta vs theta+pi) based on progress
  // points.  Connecting paths won't "go back the other direction", e.g. two curve
  // segments placed as in the shape of the number 3.  If the progress points of the two
  // segments are the same, then they connect if the difference between the two tangents
  // is pi.
  const CGFloat FLProgressComparisonEpsilon = 0.1f;
  const BOOL forProgressIsZero = (forProgress < FLProgressComparisonEpsilon);

  // note: If there are two connecting paths from this endpoint, then either there is a
  // switch to choose between them, or else we choose the first one found.

  const FLPath *paths[FLSegmentNodePathsMax];
  int pathCount = [self FL_allPaths:paths];

  const CGFloat FL2Pi = (CGFloat)(M_PI * 2.0);

  BOOL foundOne = NO;
  for (int p = 0; p < pathCount; ++p) {
    const FLPath *path = paths[p];

    CGPoint zeroProgressPoint = path->getPoint(0.0f);
    if (fabs(pathEndPoint.x - zeroProgressPoint.x) < FLEndPointComparisonEpsilon
        && fabs(pathEndPoint.y - zeroProgressPoint.y) < FLEndPointComparisonEpsilon) {
      BOOL isConnectingRotation = NO;
      if (doRotationCheck) {
        CGFloat zeroProgressRotation = path->getTangent(0.0f);
        CGFloat rotationDifference = fabs(fmod(forRotationRadians - zeroProgressRotation, FL2Pi));
        if (forProgressIsZero) {
          isConnectingRotation = (rotationDifference > M_PI - FLTangentComparisonEpsilon
                                  && rotationDifference < M_PI + FLTangentComparisonEpsilon);
        } else {
          isConnectingRotation = (rotationDifference < FLTangentComparisonEpsilon
                                  || rotationDifference > FL2Pi - FLTangentComparisonEpsilon);
        }
      }
      if (isConnectingRotation || !doRotationCheck) {
        if (!hasSwitch || switchPathId == p) {
          // note: The switch might not be relevant, even if set to this path;
          // it might only be for travel in the other direction.  But at least
          // we know there is no other better alternative to consider.
          *pathId = p;
          *progress = 0.0f;
          return YES;
        }
        // note: The switch is set, but not to this path.  So we need to check
        // the path that the switch has selected to see if it's relevant to this
        // intersection.  (It might be inefficient to continue in the loop when
        // in fact there is only exactly one other path that we care about.  But
        // segments generally contain so few paths that it doesn't really matter.)
        // Check foundOne just so that we end up returning "the first one found" if
        // the switch proves not to be relevant.
        if (!foundOne) {
          *pathId = p;
          *progress = 0.0f;
          foundOne = YES;
        }
        // note: No need to check the other endpoint, if this one hooks up.  That said:
        // I can conceive of a switched segment with a path that loops around with both
        // endpoints on the same corner with the same tangent.  So if such a segment
        // exists, then don't continue the loop here (because we need to check the other
        // endpoint).
        continue;
      }
    }

    CGPoint oneProgressPoint = path->getPoint(1.0f);
    if (fabs(pathEndPoint.x - oneProgressPoint.x) < FLEndPointComparisonEpsilon
        && fabs(pathEndPoint.y - oneProgressPoint.y) < FLEndPointComparisonEpsilon) {
      BOOL isConnectingRotation = NO;
      if (doRotationCheck) {
        CGFloat oneProgressRotation = path->getTangent(1.0f);
        CGFloat rotationDifference = fabs(fmod(forRotationRadians - oneProgressRotation, FL2Pi));
        if (forProgressIsZero) {
          isConnectingRotation = (rotationDifference < FLTangentComparisonEpsilon
                                  || rotationDifference > FL2Pi - FLTangentComparisonEpsilon);
        } else {
          isConnectingRotation = (rotationDifference > M_PI - FLTangentComparisonEpsilon
                                  && rotationDifference < M_PI + FLTangentComparisonEpsilon);
        }
      }
      if (isConnectingRotation || !doRotationCheck) {
        if (!hasSwitch || switchPathId == p) {
          *pathId = p;
          *progress = 1.0f;
          return YES;
        }
        if (!foundOne) {
          *pathId = p;
          *progress = 1.0f;
          foundOne = YES;
        }
        continue;
      }
    }
  }

  return foundOne;
}

- (CGFloat)pathLengthForPath:(int)pathId
{
  return [self FL_path:pathId]->getLength();
}

- (int)pathCount
{
  return [self FL_allPathsCount];
}

- (int)pathDirectionGoingWithSwitchForPath:(int)pathId
{
  switch (_segmentType) {
    case FLSegmentTypeJoinLeft:
      if (pathId == 0) {
        return FLPathDirectionDecreasing;
      } else if (pathId == 1) {
        return FLPathDirectionIncreasing;
      }
      break;
    case FLSegmentTypeJoinRight:
      if (pathId == 0) {
        return FLPathDirectionIncreasing;
      } else if (pathId == 1) {
        return FLPathDirectionDecreasing;
      }
      break;
    default:
      break;
  }
  [NSException raise:@"FLSegmentNodePathNotSwitched" format:@"Cannot determine the path direction that 'goes with the switch' for a path that is not switched."];
  return 0;
}

- (void)FL_createContent
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.

  // noob: A less strict and more-explicit way to do this "according to current
  // object state" thing would be to pass the relevant state variables as parameters.

  switch (_segmentType) {
    case FLSegmentTypeReadoutInput:
    case FLSegmentTypeReadoutOutput:
      [self FL_createContentReadout];
      break;
    case FLSegmentTypePixel:
      [self FL_createContentPixel];
      break;
    default:
      // No special content for segment type.
      break;
  }

  if (_mayShowLabel && _label != FLSegmentLabelNone) {
    [self FL_createContentLabel];
  }
  
  if (_mayShowSwitch && [FLSegmentNode canShowSwitch:_segmentType]) {
    [self FL_createContentSwitch];
  }
  
  if (_mayShowBubble && [FLSegmentNode canShowBubble:_segmentType]) {
    [self FL_createContentBubble];
  }
}

- (void)FL_deleteContent
{
  // note: Assume content has been created according to *current* object state.
  // After deletion, the caller should change object state accordingly.

  switch (_segmentType) {
    case FLSegmentTypeReadoutInput:
    case FLSegmentTypeReadoutOutput:
      [self FL_deleteContentReadout];
      break;
    case FLSegmentTypePixel:
      [self FL_deleteContentPixel];
      break;
    default:
      // No special content for segment type.
      break;
  }
  
  if (_mayShowLabel && _label != FLSegmentLabelNone) {
    [self FL_deleteContentLabel];
  }
  
  if (_mayShowSwitch && [FLSegmentNode canShowSwitch:_segmentType]) {
    [self FL_deleteContentSwitch];
  }
  
  if (_mayShowBubble && [FLSegmentNode canShowBubble:_segmentType]) {
    [self FL_deleteContentBubble];
  }
}

- (void)FL_createContentReadout
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.

  // note: Additionally, since this is a helper method, assume _segmentType is
  // FLSegmentTypeReadout*.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)

  FLTextureStore *textureStore = [FLTextureStore sharedStore];

  // note: Art assets assume origin in the lower left; node layout, though, has origin
  // in the center.

  SKSpriteNode *value0Node = [SKSpriteNode spriteNodeWithTexture:[textureStore textureForKey:@"value-0"]];
  value0Node.name = @"readout-value-0";
  value0Node.position = CGPointMake(FLReadoutValue0Position.x - FLSegmentArtSizeFull / 2.0f,
                                    FLReadoutValue0Position.y - FLSegmentArtSizeFull / 2.0f);
  [self addChild:value0Node];

  SKSpriteNode *value1Node = [SKSpriteNode spriteNodeWithTexture:[textureStore textureForKey:@"value-1"]];
  value1Node.name = @"readout-value-1";
  value1Node.position = CGPointMake(FLReadoutValue1Position.x - FLSegmentArtSizeFull / 2.0f,
                                    FLReadoutValue1Position.y - FLSegmentArtSizeFull / 2.0f);
  [self addChild:value1Node];

  SKLabelNode *inOutNode = [SKLabelNode labelNodeWithFontNamed:@"Courier-Bold"];
  inOutNode.zRotation = (CGFloat)(-M_PI_2);
  inOutNode.fontSize = 10.0f;
  inOutNode.fontColor = [SKColor blackColor];
  if (_segmentType == FLSegmentTypeReadoutInput) {
    inOutNode.text = @"IN";
  } else if (_segmentType == FLSegmentTypeReadoutOutput) {
    inOutNode.text = @"OUT";
  } else {
    inOutNode.text = @"???";
  }
  inOutNode.position = CGPointMake(FLReadoutInOutPosition.x - FLSegmentArtSizeFull / 2.0f,
                                   FLReadoutInOutPosition.y - FLSegmentArtSizeFull / 2.0f);
  [self addChild:inOutNode];

  [self FL_updateContentReadoutAnimated:NO];
}

- (void)FL_updateContentReadoutAnimated:(BOOL)animated
{
  // note: Assume content has been created according to current object state
  // with the exception that _switchPathId has changed from one (legal) value to
  // another.

  SKSpriteNode *topValueNode;
  SKSpriteNode *bottomValueNode;
  if (_switchPathId == 0) {
    topValueNode = (SKSpriteNode *)[self childNodeWithName:@"readout-value-0"];
    bottomValueNode = (SKSpriteNode *)[self childNodeWithName:@"readout-value-1"];
  } else if (_switchPathId == 1) {
    topValueNode = (SKSpriteNode *)[self childNodeWithName:@"readout-value-1"];
    bottomValueNode = (SKSpriteNode *)[self childNodeWithName:@"readout-value-0"];
  } else {
    [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d.", _switchPathId];
  }

  topValueNode.zPosition = FLZPositionReadoutValueTop;
  topValueNode.colorBlendFactor = 0.0f;
  topValueNode.xScale = 1.0f;
  topValueNode.yScale = 1.0f;
  bottomValueNode.zPosition = FLZPositionReadoutValueBottom;
  bottomValueNode.color = [SKColor blackColor];
  bottomValueNode.colorBlendFactor = 0.8f;
  bottomValueNode.xScale = 0.8f;
  bottomValueNode.yScale = 0.8f;

  [self FL_removeActionFlashBlackNode:topValueNode];
  [self FL_removeActionFlashWhiteNode:bottomValueNode];
  if (animated) {
    [self FL_runActionFlashWhiteNode:topValueNode];
    [self FL_runActionFlashBlackNode:bottomValueNode];
  }
}

- (void)FL_deleteContentReadout
{
  // note: Assume content has been created according to *current* object state.
  // After deletion, the caller should change object state accordingly.
  SKNode *value0Node = [self childNodeWithName:@"readout-value-0"];
  [value0Node removeFromParent];
  SKNode *value1Node = [self childNodeWithName:@"readout-value-1"];
  [value1Node removeFromParent];
}

- (void)FL_createContentPixel
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.
  
  // note: Additionally, since this is a helper method, assume _segmentType is
  // FLSegmentTypePixel.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)
  
  // note: For now, treat the pixel content not as a decoration that can be added
  // to any segment node, but instead a segment-type-specific way of doing content,
  // like readout segments.  If instead we want it to be something that can be
  // added to other segment nodes, like the "bubble" decoration, then call it
  // something like "block" or "backdrop" or "matte", and make an FL_canShowMatte
  // method a _mayShowMatte variable, and rename colors to FLSegmentNodeMatteColor0,
  // etc.

  SKColor *newColor = nil;
  if (_switchPathId == 0) {
    newColor = FLSegmentArtPixel0Color;
  } else if (_switchPathId == 1) {
    newColor = FLSegmentArtPixel1Color;
  } else {
    [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d.", _switchPathId];
  }
  
  SKSpriteNode *matteNode = [SKSpriteNode spriteNodeWithColor:newColor size:CGSizeMake(FLSegmentArtSizeBasic, FLSegmentArtSizeBasic)];
  matteNode.name = @"pixel-matte";
  [self addChild:matteNode];
}

- (void)FL_updateContentPixelAnimated:(BOOL)animated
{
  // note: Assume content has been created according to current object state
  // with the exception that _switchPathId has changed from one (legal) value to
  // another.

  SKColor *newColor = nil;
  if (_switchPathId == 0) {
    newColor = FLSegmentArtPixel0Color;
  } else if (_switchPathId == 1) {
    newColor = FLSegmentArtPixel1Color;
  } else {
    [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d.", _switchPathId];
  }

  SKSpriteNode *matteNode = (SKSpriteNode *)[self childNodeWithName:@"pixel-matte"];
  [matteNode removeActionForKey:@"matte-fade"];
  if (!animated) {
    matteNode.color = newColor;
  } else {
    [matteNode runAction:[SKAction colorizeWithColor:newColor colorBlendFactor:1.0f duration:FLColorizeDuration] withKey:@"matte-fade"];
  }
}

- (void)FL_deleteContentPixel
{
  // note: Assume content has been created according to *current* object state.
  // After deletion, the caller should change object state accordingly.

  SKSpriteNode *matteNode = (SKSpriteNode *)[self childNodeWithName:@"pixel-matte"];
  [matteNode removeFromParent];
}

- (void)FL_createContentLabel
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.

  // note: Additionally, since this is a helper method, assume _label is not FLSegmentLabelNone
  // and _mayShowLabel is YES.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)
  
  SKLabelNode *labelNode = [SKLabelNode labelNodeWithFontNamed:@"Arial-BoldMT"];
  labelNode.name = @"label";
  labelNode.text = [NSString stringWithFormat:@"%c", _label];
  labelNode.fontSize = FLSegmentArtSizeBasic + FLSegmentArtBasicInset;
  labelNode.fontColor = [SKColor whiteColor];
  labelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
  labelNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
  labelNode.zRotation = -self.zRotation;
  labelNode.zPosition = FLZPositionLabel;
  [self addChild:labelNode];
}

- (void)FL_updateContentLabel
{
  // note: Assume content has been created according to *current* object state.
  
  // note: Additionally, since this is a helper method, assume _label is not FLSegmentLabelNone
  // and _mayShowLabel is YES.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)
  
  SKLabelNode *labelNode = (SKLabelNode *)[self childNodeWithName:@"label"];
  labelNode.text = [NSString stringWithFormat:@"%c", _label];
}

- (void)FL_rotateContentLabel
{
  // note: Assume content has been created according to *current* object state.

  // note: Additionally, since this is a helper method, assume _label is not FLSegmentLabelNone
  // and _mayShowLabel is YES.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)
  
  SKNode *labelNode = [self childNodeWithName:@"label"];
  labelNode.zRotation = -self.zRotation;
}

- (void)FL_deleteContentLabel
{
  // note: Assume content has been created according to *current* object state.  After
  // deletion, the caller should change object state accordingly.  For example, we may
  // assume that _label is not FLSegmentLabelNone, _mayShowLabel is YES, and that the child node "label"
  // exists and has been added to self.
  
  SKNode *labelNode = [self childNodeWithName:@"label"];
  [labelNode removeFromParent];
}

- (void)FL_createContentSwitch
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.

  // note: Additionally, since this is a helper method, assume _mayShowSwitch is YES,
  // and that this segment passes canShowSwitch.  (That is, the caller is responsible
  // to short-circuit the call in cases where it obviously won't do anything; this prevents
  // duplicate checking.)

  SKSpriteNode *switchNode = [SKSpriteNode spriteNodeWithTexture:[[FLTextureStore sharedStore] textureForKey:@"switch"]];
  switchNode.name = @"switch";

  CGFloat halfBasicSize = FLSegmentArtSizeBasic / 2.0f;
  CGFloat switchInset = FLSegmentArtSizeBasic / 6.0f;
  if (_segmentType == FLSegmentTypeJoinLeft) {
    switchNode.position = CGPointMake(-halfBasicSize + switchInset, halfBasicSize);
  } else if (_segmentType == FLSegmentTypeJoinRight) {
    switchNode.position = CGPointMake(halfBasicSize - switchInset, halfBasicSize);
  } else if (_segmentType == FLSegmentTypeReadoutInput || _segmentType == FLSegmentTypeReadoutOutput) {
    switchNode.position = CGPointMake(FLReadoutSwitchPosition.x - FLSegmentArtSizeFull / 2.0f,
                                      FLReadoutSwitchPosition.y - FLSegmentArtSizeFull / 2.0f);
  } else {
    switchNode.position = CGPointZero;
  }
  switchNode.zPosition = FLZPositionSwitch;

  [self addChild:switchNode];

  [self FL_updateContentSwitchAnimated:NO];
}

- (void)FL_updateContentSwitchAnimated:(BOOL)animated
{
  // note: Assume content has been created according to current object state
  // with the exception that _switchPathId has changed from one (legal) value to another.

  // note: Additionally, since this is a helper method, assume _mayShowSwitch is YES,
  // and that this segment passes canShowSwitch.  (That is, the caller is responsible
  // to short-circuit the call in cases where it obviously won't do anything; this prevents
  // duplicate checking.)

  SKSpriteNode *switchNode = (SKSpriteNode *)[self childNodeWithName:@"switch"];

  CGFloat newZRotation = 0.0f;
  const CGFloat switchAngleJoin = (CGFloat)M_PI / 7.4f;
  const CGFloat switchAngleReadout = (CGFloat)M_PI / 3.7f;
  if (_segmentType == FLSegmentTypeJoinLeft) {
    newZRotation = (_switchPathId - 1) * switchAngleJoin;
  } else if (_segmentType == FLSegmentTypeJoinRight) {
    newZRotation = (CGFloat)M_PI + (1 - _switchPathId) * switchAngleJoin;
  } else if (_segmentType == FLSegmentTypeReadoutInput || _segmentType == FLSegmentTypeReadoutOutput) {
    newZRotation = (_switchPathId - 1) * switchAngleReadout;
  } else {
    [NSException raise:@"FLSegmentNodeInvalidSegemntType" format:@"Segment is missing switch display information."];
  }

  [switchNode removeActionForKey:@"switch-rotate"];
  if (!animated) {
    switchNode.zRotation = newZRotation;
  } else {
    [switchNode runAction:[SKAction rotateToAngle:newZRotation duration:FLSwitchRotateDuration shortestUnitArc:YES] withKey:@"switch-rotate"];
  }
}

- (void)FL_deleteContentSwitch
{
  // note: Assume content has been created according to *current* object state.
  // After deletion, the caller should change object state accordingly.
  // For example, we may assume that _mayShowSwitch is YES, this segment passes
  // canShowSwitch, and that the child node "switch" exists and has been added to self.
  SKSpriteNode *switchNode = (SKSpriteNode *)[self childNodeWithName:@"switch"];
  [switchNode removeFromParent];
}

- (void)FL_createContentBubble
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.

  // note: Additionally, since is a helper method, assume _mayShowBubble is YES
  // and this segment passes canShowBubble.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)

  SKTexture *valueTexture;
  if (_switchPathId == 0) {
    valueTexture = [[FLTextureStore sharedStore] textureForKey:@"value-0"];
  } else if (_switchPathId == 1) {
    valueTexture = [[FLTextureStore sharedStore] textureForKey:@"value-1"];
  } else {
    [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d.", _switchPathId];
  }

  SKNode *bubbleNode = [SKSpriteNode spriteNodeWithTexture:valueTexture];
  bubbleNode.name = @"bubble";
  bubbleNode.zPosition = FLZPositionBubble;
  bubbleNode.zRotation = (CGFloat)M_PI_2 - self.zRotation;
  [self addChild:bubbleNode];
}

- (void)FL_updateContentBubbleAnimated:(BOOL)animated
{
  // note: Assume content has been created according to current object state
  // with the exception that _switchPathId has changed from one value to another,
  // neither of them FLSegmentSwitchPathIdNone.  (The old value is currently
  // not tracked or needed.)

  // note: Additionally, since is a helper method, assume _mayShowBubble is YES
  // and this segment passes canShowBubble.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)

  SKTexture *valueTexture;
  if (_switchPathId == 0) {
    valueTexture = [[FLTextureStore sharedStore] textureForKey:@"value-0"];
  } else if (_switchPathId == 1) {
    valueTexture = [[FLTextureStore sharedStore] textureForKey:@"value-1"];
  } else {
    [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d.", _switchPathId];
  }

  SKSpriteNode *bubbleNode = (SKSpriteNode *)[self childNodeWithName:@"bubble"];

  bubbleNode.texture = valueTexture;
  [self FL_removeActionFlashWhiteNode:bubbleNode];
  if (animated) {
    [self FL_runActionFlashWhiteNode:bubbleNode];
  }
}

- (void)FL_rotateContentBubble
{
  // note: Assume content has been created according to *current* object state.

  // note: Additionally, since is a helper method, assume _mayShowBubble is YES
  // and this segment passes canShowBubble.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)

  SKNode *bubbleNode = [self childNodeWithName:@"bubble"];
  bubbleNode.zRotation = (CGFloat)M_PI_2 - self.zRotation;
}

- (void)FL_deleteContentBubble
{
  // note: Assume content has been created according to *current* object state.
  // After deletion, the caller should change object state accordingly.
  // For example, we may assume _mayShowBubble is YES and that the child
  // node "bubble" exists and has been added to self.
  
  SKNode *bubbleNode = [self childNodeWithName:@"bubble"];
  [bubbleNode removeFromParent];
}

- (void)FL_runActionFlashWhiteNode:(SKNode *)node
{
  // noob: Flash-white-and-fade effect.  Easier/better/more-performant/more-standard
  // way to do this?  (n.b. Colorize only works for tinting towards black, not
  // towards white.)

  SKCropNode *whiteLayer = [[SKCropNode alloc] init];
  whiteLayer.name = @"whiteLayer";
  SKSpriteNode *maskNode = [node copy];
  maskNode.position = CGPointZero;
  [maskNode removeFromParent];
  whiteLayer.maskNode = maskNode;
  whiteLayer.zPosition = FLZPositionFlashOverlay - node.zPosition;
  // note: Cheating a bit here by hard-coding 2x node size: We know that sometimes the caller
  // is growing or shrinking the node at the same time it flashes it.
  SKSpriteNode *whiteNode = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor]
                                                         size:CGSizeMake(maskNode.size.width * 2.0f, maskNode.size.height * 2.0f)];
  [whiteLayer addChild:whiteNode];
  [node addChild:whiteLayer];

  SKAction *whiteFlash = [SKAction fadeAlphaTo:0.0f duration:FLFlashDuration];
  whiteFlash.timingMode = SKActionTimingEaseOut;
  [whiteLayer runAction:whiteFlash completion:^{
    [whiteLayer removeFromParent];
  }];
}

- (void)FL_removeActionFlashWhiteNode:(SKSpriteNode *)node
{
  SKNode *whiteLayer = [node childNodeWithName:@"whiteLayer"];
  if (whiteLayer) {
    [whiteLayer removeFromParent];
  }
}

- (void)FL_runActionFlashBlackNode:(SKSpriteNode *)node
{
  SKColor *oldColor = node.color;
  CGFloat oldColorBlendFactor = node.colorBlendFactor;

  node.color = [SKColor blackColor];
  node.colorBlendFactor = 1.0f;
  SKAction *blackFlash = [SKAction colorizeWithColor:oldColor colorBlendFactor:oldColorBlendFactor duration:FLFlashDuration];
  blackFlash.timingMode = SKActionTimingEaseOut;
  [node runAction:blackFlash withKey:@"flashBlack"];
}

- (void)FL_removeActionFlashBlackNode:(SKSpriteNode *)node
{
  [node removeActionForKey:@"flashBlack"];
}

- (const FLPath *)FL_path:(int)pathId
{
  int rotationQuarters = convertRotationRadiansToQuarters(self.zRotation);
  FLPathType pathType;
  switch (_segmentType) {
    case FLSegmentTypeStraight:
      pathType = FLPathTypeStraight;
      break;
    case FLSegmentTypeCurve:
      pathType = FLPathTypeCurve;
      break;
    case FLSegmentTypeJoinLeft:
      if (pathId == 0) {
        pathType = FLPathTypeCurve;
      } else {
        pathType = FLPathTypeStraight;
      }
      break;
    case FLSegmentTypeJoinRight:
      if (pathId == 0) {
        pathType = FLPathTypeCurve;
        ++rotationQuarters;
      } else {
        pathType = FLPathTypeStraight;
      }
      break;
    case FLSegmentTypeJogLeft:
      pathType = FLPathTypeJogLeft;
      break;
    case FLSegmentTypeJogRight:
      pathType = FLPathTypeJogRight;
      break;
    case FLSegmentTypeCross:
      if (pathId == 0) {
        pathType = FLPathTypeJogLeft;
      } else {
        pathType = FLPathTypeJogRight;
      }
      break;
    case FLSegmentTypePlatformLeft:
    case FLSegmentTypePlatformStartLeft:
      pathType = FLPathTypeHalfLeft;
      break;
    case FLSegmentTypePlatformRight:
    case FLSegmentTypePlatformStartRight:
      pathType = FLPathTypeHalfRight;
      break;
    case FLSegmentTypeReadoutInput:
    case FLSegmentTypeReadoutOutput:
    case FLSegmentTypePixel:
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type %ld.", (long)_segmentType];
  }
  return FLPathStore::sharedStore()->getPath(pathType, rotationQuarters);
}

- (int)FL_allPaths:(const FLPath **)paths
{
  // note: Increase FLSegmentNodePathsMax to match largest return value here.
  int rotationQuarters = convertRotationRadiansToQuarters(self.zRotation);
  switch (_segmentType) {
    case FLSegmentTypeStraight:
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeStraight, rotationQuarters);
      return 1;
    case FLSegmentTypeCurve:
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeCurve, rotationQuarters);
      return 1;
    case FLSegmentTypeJoinLeft:
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeCurve, rotationQuarters);
      paths[1] = FLPathStore::sharedStore()->getPath(FLPathTypeStraight, rotationQuarters);
      return 2;
    case FLSegmentTypeJoinRight:
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeCurve, rotationQuarters + 1);
      paths[1] = FLPathStore::sharedStore()->getPath(FLPathTypeStraight, rotationQuarters);
      return 2;
    case FLSegmentTypeJogLeft:
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeJogLeft, rotationQuarters);
      return 1;
    case FLSegmentTypeJogRight:
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeJogRight, rotationQuarters);
      return 1;
    case FLSegmentTypeCross:
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeJogLeft, rotationQuarters);
      paths[1] = FLPathStore::sharedStore()->getPath(FLPathTypeJogRight, rotationQuarters);
      return 2;
    case FLSegmentTypePlatformLeft:
    case FLSegmentTypePlatformStartLeft:
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeHalfLeft, rotationQuarters);
      return 1;
    case FLSegmentTypePlatformRight:
    case FLSegmentTypePlatformStartRight:
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeHalfRight, rotationQuarters);
      return 1;
    case FLSegmentTypeReadoutInput:
    case FLSegmentTypeReadoutOutput:
    case FLSegmentTypePixel:
      return 0;
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type %ld.", (long)_segmentType];
      return 0;
  }
}

- (int)FL_allPathsCount
{
  // note: Increase FLSegmentNodePathsMax to match largest return value here.
  switch (_segmentType) {
    case FLSegmentTypeStraight:
      return 1;
    case FLSegmentTypeCurve:
      return 1;
    case FLSegmentTypeJoinLeft:
      return 2;
    case FLSegmentTypeJoinRight:
      return 2;
    case FLSegmentTypeJogLeft:
      return 1;
    case FLSegmentTypeJogRight:
      return 1;
    case FLSegmentTypeCross:
      return 2;
    case FLSegmentTypePlatformLeft:
    case FLSegmentTypePlatformRight:
    case FLSegmentTypePlatformStartLeft:
    case FLSegmentTypePlatformStartRight:
      return 1;
    case FLSegmentTypeReadoutInput:
    case FLSegmentTypeReadoutOutput:
    case FLSegmentTypePixel:
      return 0;
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type %ld.", (long)_segmentType];
      return 0;
  }
}

@end
