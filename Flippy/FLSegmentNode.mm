//
//  FLSegmentNode.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/22/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import "FLSegmentNode.h"

#include <tgmath.h>
#import <HLSpriteKit/HLTextureStore.h>

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

const int FLSegmentSwitchPathIdNone = -1;

static const unsigned int FLSegmentNodePathsMax = 2;

static const CGFloat FLZPositionValue = -0.3f;
static const CGFloat FLZPositionReadoutValueBottom = -0.3f;
static const CGFloat FLZPositionReadoutValueTop = -0.2f;
static const CGFloat FLZPositionValueOverlay = -0.1f;
static const CGFloat FLZPositionSwitch = 0.1f;

static const NSTimeInterval FLFlashDuration = 0.5;

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

using namespace std;

@implementation FLSegmentNode
{
  // note: Every node is storing information about switches, whether
  // they have a switch or not.  The obvious alternative, if space is a problem,
  // is to derive a FLSwitchedSegmentNode from FLSegmentNode.  (The same goes for
  // segmentType.)  Keep in mind that the derived class would be used to represent
  // node types that CAN be switched, whether they are or not, so that, for instance,
  // a particular join segment doesn't have to have a switch.
  int _switchPathId;
}

- (id)initWithSegmentType:(FLSegmentType)segmentType
{
  NSString *textureKey = [FLSegmentNode keyForSegmentType:segmentType];
  return [self initWithSegmentType:segmentType textureKey:textureKey];
}

- (id)initWithTextureKey:(NSString *)textureKey
{
  FLSegmentType segmentType = [FLSegmentNode segmentTypeForKey:textureKey];
  return [self initWithSegmentType:segmentType textureKey:textureKey];
}

- (id)initWithSegmentType:(FLSegmentType)segmentType textureKey:(NSString *)textureKey
{
  if (segmentType == FLSegmentTypeReadout) {
    self = [super initWithColor:[SKColor clearColor] size:CGSizeMake(FLSegmentArtSizeFull, FLSegmentArtSizeFull)];
  } else {
    SKTexture *texture = [[HLTextureStore sharedStore] textureForKey:textureKey];
    self = [super initWithTexture:texture];
  }
  if (self) {
    _segmentType = segmentType;
    if (_segmentType == FLSegmentTypeJoinLeft || _segmentType == FLSegmentTypeJoinRight || _segmentType == FLSegmentTypeReadout) {
      _switchPathId = 1;
    } else {
      _switchPathId = FLSegmentSwitchPathIdNone;
    }
    _showsSwitchValue = NO;
    [self FL_createContent];
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {
    _segmentType = (FLSegmentType)[aDecoder decodeIntForKey:@"segmentType"];
    _showsSwitchValue = [aDecoder decodeBoolForKey:@"showsSwitchValue"];
    _switchPathId = [aDecoder decodeIntForKey:@"switchPathId"];

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
  // children instead.
  [self FL_createContent];

  [aCoder encodeInt:(int)_segmentType forKey:@"segmentType"];
  [aCoder encodeBool:_showsSwitchValue forKey:@"showsSwitchValue"];
  [aCoder encodeInt:_switchPathId forKey:@"switchPathId"];
}

- (id)copyWithZone:(NSZone *)zone
{
  FLSegmentNode *copy = [super copyWithZone:zone];
  if (copy) {
    copy->_segmentType = _segmentType;
    copy->_switchPathId = _switchPathId;
    copy->_showsSwitchValue = _showsSwitchValue;
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
    case FLSegmentTypePlatform:
      return @"platform";
    case FLSegmentTypeReadout:
      return @"readout";
    case FLSegmentTypeNone:
    default:
      break;
  }
  [NSException raise:@"FLSegmentNodeSegmentTypeUnknown" format:@"Unknown segment type."];
  return nil;
}

+ (FLSegmentType)segmentTypeForKey:(NSString *)key
{
  if ([key isEqualToString:@"straight"]) {
    return FLSegmentTypeStraight;
  } else if ([key isEqualToString:@"curve"]) {
    return FLSegmentTypeCurve;
  } else if ([key isEqualToString:@"join-left"]) {
    return FLSegmentTypeJoinLeft;
  } else if ([key isEqualToString:@"join-right"]) {
    return FLSegmentTypeJoinRight;
  } else if ([key isEqualToString:@"jog-left"]) {
    return FLSegmentTypeJogLeft;
  } else if ([key isEqualToString:@"jog-right"]) {
    return FLSegmentTypeJogRight;
  } else if ([key isEqualToString:@"cross"]) {
    return FLSegmentTypeCross;
  } else if ([key isEqualToString:@"platform"]) {
    return FLSegmentTypePlatform;
  } else if ([key isEqualToString:@"readout"]) {
    return FLSegmentTypeReadout;
  } else {
    [NSException raise:@"FLSegmentNodeTexureKeyUnknown" format:@"Unknown segment texture key."];
  }
  return FLSegmentTypeNone;
}

+ (UIImage *)createImageForReadoutSegment:(CGFloat)imageSize
{
  // note: Art constants in file are all scaled to full art size.  Our scaling
  // factor brings everything into imageSize.
  CGFloat scale = imageSize / FLSegmentArtSizeFull;

  HLTextureStore *textureStore = [HLTextureStore sharedStore];

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
  // note: The caller has put images into the HLTextureStore alongside textures, and we can use the
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
  if (_switchPathId != FLSegmentSwitchPathIdNone && _showsSwitchValue && _segmentType != FLSegmentTypeReadout) {
    [self FL_rotateContentValue];
  }
}

- (BOOL)canHaveSwitch
{
  return _segmentType == FLSegmentTypeJoinLeft
    || _segmentType == FLSegmentTypeJoinRight
    || _segmentType == FLSegmentTypeReadout;
}

- (int)switchPathId
{
  return _switchPathId;
}

- (void)setSwitchPathId:(int)switchPathId animated:(BOOL)animated
{
  if (_switchPathId == switchPathId) {
    return;
  }

  if (switchPathId == FLSegmentSwitchPathIdNone) {
    [self FL_deleteContentSwitch];
    if (_segmentType == FLSegmentTypeReadout) {
      [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d for readout segment.", _switchPathId];
    } else if (_showsSwitchValue) {
      [self FL_deleteContentValue];
    }
  }

  int oldSwitchPathId = _switchPathId;
  _switchPathId = switchPathId;

  if (oldSwitchPathId == FLSegmentSwitchPathIdNone) {
    [self FL_createContentSwitch];
    if (_segmentType == FLSegmentTypeReadout) {
      [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d for readout segment.", _switchPathId];
    } else if (_showsSwitchValue) {
      [self FL_createContentValue];
    }
  } else if (switchPathId != FLSegmentSwitchPathIdNone) {
    [self FL_updateContentSwitchAnimated:animated];
    if (_segmentType == FLSegmentTypeReadout) {
      [self FL_updateContentReadoutAnimated:animated];
    } else if (_showsSwitchValue) {
      [self FL_updateContentValueAnimated:animated];
    }
  }
}

- (int)toggleSwitchPathIdAnimated:(BOOL)animated
{
  if (_switchPathId == FLSegmentSwitchPathIdNone) {
    return FLSegmentSwitchPathIdNone;
  }
  if (_switchPathId == 0) {
    [self setSwitchPathId:1 animated:animated];
    return 1;
  } else if (_switchPathId == 1) {
    [self setSwitchPathId:0 animated:animated];
    return 0;
  } else {
    [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d.", _switchPathId];
    return -1;
  }
}

- (void)setShowsSwitchValue:(BOOL)showsSwitchValue
{
  if (showsSwitchValue == _showsSwitchValue) {
    return;
  }
  if (_showsSwitchValue && _segmentType != FLSegmentTypeReadout) {
    if (_switchPathId != FLSegmentSwitchPathIdNone) {
      [self FL_deleteContentValue];
    }
  }
  _showsSwitchValue = showsSwitchValue;
  if (_showsSwitchValue && _segmentType != FLSegmentTypeReadout) {
    if (_switchPathId != FLSegmentSwitchPathIdNone) {
      [self FL_createContentValue];
    }
  }
}

- (CGPoint)switchPosition
{
  SKNode *switchNode = [self childNodeWithName:@"switch"];
  if (!switchNode) {
    return CGPointZero;
  }
  return [self.parent convertPoint:switchNode.position fromNode:self];
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

- (BOOL)getPath:(int *)pathId progress:(CGFloat *)progress forEndPoint:(CGPoint)endPoint progress:(CGFloat)forProgress rotation:(CGFloat)forRotationRadians scale:(CGFloat)scale
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
      CGFloat zeroProgressRotation = path->getTangent(0.0f);
      CGFloat rotationDifference = fabs(fmod(forRotationRadians - zeroProgressRotation, FL2Pi));
      BOOL isConnectingRotation = NO;
      if (forProgressIsZero) {
        isConnectingRotation = (rotationDifference > M_PI - FLTangentComparisonEpsilon
                                && rotationDifference < M_PI + FLTangentComparisonEpsilon);
      } else {
        isConnectingRotation = (rotationDifference < FLTangentComparisonEpsilon
                                || rotationDifference > FL2Pi - FLTangentComparisonEpsilon);
      }
      if (isConnectingRotation) {
        if (_switchPathId == FLSegmentSwitchPathIdNone || _switchPathId == p) {
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
      CGFloat oneProgressRotation = path->getTangent(1.0f);
      CGFloat rotationDifference = fabs(fmod(forRotationRadians - oneProgressRotation, FL2Pi));
      BOOL isConnectingRotation = NO;
      if (forProgressIsZero) {
        isConnectingRotation = (rotationDifference < FLTangentComparisonEpsilon
                                || rotationDifference > FL2Pi - FLTangentComparisonEpsilon);
      } else {
        isConnectingRotation = (rotationDifference > M_PI - FLTangentComparisonEpsilon
                                && rotationDifference < M_PI + FLTangentComparisonEpsilon);
      }
      if (isConnectingRotation) {
        if (_switchPathId == FLSegmentSwitchPathIdNone || _switchPathId == p) {
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

- (void)FL_createContent
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.

  // noob: A less strict and more-explicit way to do this "according to current
  // object state" thing would be to pass the relevant state variables as parameters.

  if (_segmentType == FLSegmentTypeReadout) {
    [self FL_createContentReadout];
  }

  if (_switchPathId != FLSegmentSwitchPathIdNone) {
    [self FL_createContentSwitch];
    if (_showsSwitchValue && _segmentType != FLSegmentTypeReadout) {
      [self FL_createContentValue];
    }
  }
}

- (void)FL_deleteContent
{
  // note: Assume content has been created according to *current* object state.
  // After deletion, the caller should change object state accordingly.

  if (_segmentType == FLSegmentTypeReadout) {
    [self FL_deleteContentReadout];
  }

  if (_switchPathId != FLSegmentSwitchPathIdNone) {
    [self FL_deleteContentSwitch];
    if (_showsSwitchValue && _segmentType != FLSegmentTypeReadout) {
      [self FL_deleteContentValue];
    }
  }
}

- (void)FL_createContentReadout
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.

  // note: Additionally, since this is a helper method, assume _segmentType is
  // FLSegmentTypeReadout and _switchPathId is not FLSegmentNodeSwitchPathIdNone.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)

  HLTextureStore *textureStore = [HLTextureStore sharedStore];

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

  [self FL_updateContentReadoutAnimated:NO];
}

- (void)FL_updateContentReadoutAnimated:(BOOL)animated
{
  // note: Assume content has been created according to current object state
  // with the exception that _switchPathId has changed from one value to another
  // (neither of them FLSegmentSwitchPathIdNone).

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
  bottomValueNode.zPosition = FLZPositionReadoutValueBottom;

  if (animated) {
    [self FL_runActionFlashWhiteValue:topValueNode];
    [self FL_runActionFlashBlackValue:bottomValueNode];
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

- (void)FL_createContentSwitch
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.

  // note: Additionally, since this is a helper method, assume _switchPathId is
  // not FLSegmentSwitchPathIdNone.  (That is, the caller is responsible to short-
  // circuit the call in cases where it obviously won't do anything; this prevents
  // duplicate checking.)

  SKSpriteNode *switchNode = [SKSpriteNode spriteNodeWithTexture:[[HLTextureStore sharedStore] textureForKey:@"switch"]];
  switchNode.name = @"switch";

  CGFloat halfBasicSize = FLSegmentArtSizeBasic / 2.0f;
  CGFloat switchInset = FLSegmentArtSizeBasic / 6.0f;
  if (_segmentType == FLSegmentTypeJoinLeft) {
    switchNode.position = CGPointMake(-halfBasicSize + switchInset, halfBasicSize);
  } else if (_segmentType == FLSegmentTypeJoinRight) {
    switchNode.position = CGPointMake(halfBasicSize - switchInset, halfBasicSize);
  } else if (_segmentType == FLSegmentTypeReadout) {
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
  // with the exception that _switchPathId has changed from one value to another
  // (neither of them FLSegmentSwitchPathIdNone).

  SKSpriteNode *switchNode = (SKSpriteNode *)[self childNodeWithName:@"switch"];

  CGFloat newZRotation = 0.0f;
  const CGFloat switchAngleJoin = (CGFloat)M_PI / 7.4f;
  const CGFloat switchAngleReadout = (CGFloat)M_PI / 3.7f;
  if (_segmentType == FLSegmentTypeJoinLeft) {
    newZRotation = (_switchPathId - 1) * switchAngleJoin;
  } else if (_segmentType == FLSegmentTypeJoinRight) {
    newZRotation = (CGFloat)M_PI + (1 - _switchPathId) * switchAngleJoin;
  } else if (_segmentType == FLSegmentTypeReadout) {
    newZRotation = (_switchPathId - 1) * switchAngleReadout;
  }

  if (_switchPathId == FLSegmentSwitchPathIdNone || !animated) {
    switchNode.zRotation = newZRotation;
  } else {
    [switchNode runAction:[SKAction rotateToAngle:newZRotation duration:0.1 shortestUnitArc:YES]];
  }
}

- (void)FL_deleteContentSwitch
{
  // note: Assume content has been created according to *current* object state.
  // After deletion, the caller should change object state accordingly.
  // For example, we may assume that _switchPathId is not FLSegmentSwitchPathIdNone,
  // and that the child node "switch" exists and has been added to self.
  SKSpriteNode *switchNode = (SKSpriteNode *)[self childNodeWithName:@"switch"];
  [switchNode removeFromParent];
}

- (void)FL_createContentValue
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.

  // note: Additionally, since is a helper method, assume _showsSwitchValue is YES,
  // _switchPathId is not FLSegmentSwitchPathIdNone, and _segmentType is not
  // FLSegmentTypeReadout.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)

  SKTexture *valueTexture;
  if (_switchPathId == 0) {
    valueTexture = [[HLTextureStore sharedStore] textureForKey:@"value-0"];
  } else if (_switchPathId == 1) {
    valueTexture = [[HLTextureStore sharedStore] textureForKey:@"value-1"];
  } else {
    [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d.", _switchPathId];
  }

  SKNode *valueNode = [SKSpriteNode spriteNodeWithTexture:valueTexture];
  valueNode.name = @"value";
  valueNode.zPosition = FLZPositionValue;
  valueNode.zRotation = (CGFloat)M_PI_2 - self.zRotation;
  [self addChild:valueNode];
}

- (void)FL_updateContentValueAnimated:(BOOL)animated
{
  // note: Assume content has been created according to current object state
  // with the exception that _switchPathId has changed from one value to another,
  // neither of them FLSegmentSwitchPathIdNone.  (The old value is currently
  // not tracked or needed.)

  // note: Additionally, since is a helper method, assume _showsSwitchValue is YES
  // and _segmentType is not FLSegmentTypeReadout.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)

  SKTexture *valueTexture;
  if (_switchPathId == 0) {
    valueTexture = [[HLTextureStore sharedStore] textureForKey:@"value-0"];
  } else if (_switchPathId == 1) {
    valueTexture = [[HLTextureStore sharedStore] textureForKey:@"value-1"];
  } else {
    [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id %d.", _switchPathId];
  }

  SKSpriteNode *valueNode = (SKSpriteNode *)[self childNodeWithName:@"value"];

  valueNode.texture = valueTexture;
  if (animated) {
    [self FL_runActionFlashWhiteValue:valueNode];
  }
}

- (void)FL_rotateContentValue
{
  // note: Assume content has been created according to *current* object state.

  // note: Additionally, since is a helper method, assume _showsSwitchValue is YES,
  // _switchPathId is not FLSegmentSwitchPathIdNone, and _segmentType is not
  // FLSegmentTypeReadout.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)

  SKNode *valueNode = [self childNodeWithName:@"value"];
  valueNode.zRotation = (CGFloat)M_PI_2 - self.zRotation;
}

- (void)FL_deleteContentValue
{
  // note: Assume content has been created according to *current* object state.
  // After deletion, the caller should change object state accordingly.
  // For example, we may assume _showsSwitchValue is YES and that the child
  // node "value" exists and has been added to self.
  SKNode *valueNode = [self childNodeWithName:@"value"];
  [valueNode removeFromParent];
}

- (void)FL_runActionFlashWhiteValue:(SKNode *)valueNode
{
  // noob: Flash-white-and-fade effect.  Easier/better/more-performant/more-standard
  // way to do this?  (n.b. Colorize only works for tinting towards black, not
  // towards white.)

  SKCropNode *whiteLayer = [[SKCropNode alloc] init];
  SKSpriteNode *maskNode = [valueNode copy];
  maskNode.position = CGPointZero;
  [maskNode removeFromParent];
  whiteLayer.maskNode = maskNode;
  whiteLayer.zPosition = FLZPositionValueOverlay - valueNode.zPosition;
  SKSpriteNode *whiteNode = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:maskNode.size];
  [whiteLayer addChild:whiteNode];
  [valueNode addChild:whiteLayer];

  SKAction *whiteFlash = [SKAction sequence:@[ [SKAction fadeAlphaTo:0.0f duration:FLFlashDuration],
                                               [SKAction removeFromParent] ]];
  whiteFlash.timingMode = SKActionTimingEaseOut;
  [whiteLayer runAction:whiteFlash];
}

- (void)FL_runActionFlashBlackValue:(SKSpriteNode *)valueNode
{
  [valueNode removeActionForKey:@"flashBlack"];
  valueNode.color = [SKColor blackColor];
  valueNode.colorBlendFactor = 1.0f;
  SKAction *blackFlash = [SKAction colorizeWithColorBlendFactor:0.0f duration:FLFlashDuration];
  blackFlash.timingMode = SKActionTimingEaseOut;
  [valueNode runAction:blackFlash withKey:@"flashBlack"];
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
    case FLSegmentTypePlatform:
      pathType = FLPathTypeHalf;
      break;
    case FLSegmentTypeReadout:
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type %d.", _segmentType];
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
    case FLSegmentTypePlatform:
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeHalf, rotationQuarters);
      return 1;
    case FLSegmentTypeReadout:
      return 0;
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type %d.", _segmentType];
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
    case FLSegmentTypePlatform:
      return 1;
    case FLSegmentTypeReadout:
      return 0;
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type %d.", _segmentType];
      return 0;
  }
}

@end
