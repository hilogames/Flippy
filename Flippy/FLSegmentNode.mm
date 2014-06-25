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

    // TODO: Some old archives were encoded with child nodes named "switch".  Get rid
    // of it, if it's there, so that it doesn't interfere with our assumption that we
    // do not encode child "content".  (And don't try to reuse it in the new content,
    // since the old "switch" node texture size is wrong.)  REMOVE THIS CHECK ONCE
    // ALL THE OLD ARCHIVES HAVE BEEN RECREATED.
    SKNode *switchNode = [self childNodeWithName:@"switch"];
    if (switchNode) {
      [switchNode removeFromParent];
    }

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
  CGFloat FLSegmentArtReadoutComponentInset = FLSegmentArtBasicInset;

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

  UIImage *value0Image = [textureStore imageForKey:@"value-0"];
  CGRect value0Rect = CGRectMake((FLSegmentArtSizeFull - value0Image.size.height) / 2.0f * scale,
                                 FLSegmentArtReadoutComponentInset * scale,
                                 value0Image.size.height * scale,
                                 value0Image.size.width * scale);
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
  CGRect value1Rect = CGRectMake((FLSegmentArtSizeFull - FLSegmentArtReadoutComponentInset) * scale,
                                 (FLSegmentArtSizeFull - FLSegmentArtReadoutComponentInset) * scale,
                                 -value1Image.size.height * scale,
                                 -value1Image.size.width * scale);
  if ([textureStore textureForKey:@"value-1"].filteringMode == SKTextureFilteringNearest) {
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
  } else {
    CGContextSetInterpolationQuality(context, kCGInterpolationDefault);
  }
  CGContextDrawImage(context, value1Rect, [value1Image CGImage]);

  UIImage *switchImage = [textureStore imageForKey:@"switch"];
  CGRect switchRect = CGRectMake((FLSegmentArtReadoutComponentInset + value0Image.size.width / 4.0f - switchImage.size.height / 2.0f) * scale,
                                 (FLSegmentArtSizeFull - FLSegmentArtReadoutComponentInset - (value1Image.size.height + switchImage.size.width) / 2.0f) * scale,
                                 switchImage.size.height * scale,
                                 switchImage.size.width * scale);
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
  if (_showsSwitchValue) {
    SKNode *valueNode = [self childNodeWithName:@"value"];
    if (valueNode) {
      valueNode.zRotation = (CGFloat)M_PI_2 - zRotation;
    }
  }
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
    if (_showsSwitchValue) {
      [self FL_deleteContentValue];
    }
  }

  int oldSwitchPathId = _switchPathId;
  _switchPathId = switchPathId;
  
  if (oldSwitchPathId == FLSegmentSwitchPathIdNone) {
    [self FL_createContentSwitch];
    if (_showsSwitchValue) {
      [self FL_createContentValue];
    }
  } else {
    [self FL_updateContentSwitchAnimated:animated];
    if (_showsSwitchValue) {
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
    [NSException raise:@"FLSegmentNodeSwitchPathIdInvalid" format:@"Invalid switch path id; must be 0 or 1 to toggle."];
    return -1;
  }
}

- (void)setShowsSwitchValue:(BOOL)showsSwitchValue
{
  if (showsSwitchValue == _showsSwitchValue) {
    return;
  }
  if (_showsSwitchValue) {
    if (_switchPathId != FLSegmentSwitchPathIdNone) {
      [self FL_deleteContentValue];
    }
  }
  _showsSwitchValue = showsSwitchValue;
  if (_showsSwitchValue) {
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

- (CGFloat)getClosestOnTrackPoint:(CGPoint *)onTrackPoint rotation:(CGFloat *)rotationRadians path:(int *)pathId progress:(CGFloat *)progress forOffTrackPoint:(CGPoint)offTrackPoint scale:(CGFloat)scale precision:(CGFloat)progressPrecision
{
  const FLPath *paths[FLSegmentNodePathsMax];
  int pathCount = [self FL_allPaths:paths];

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
    CGFloat distance = path->getClosestOnPathPoint(&onPathPoint, &onPathProgress, offPathPoint, progressPrecision);
    if (closestPathId == -1 || distance < closestDistance) {
      closestPathId = p;
      closestPoint = onPathPoint;
      closestProgress = onPathProgress;
      closestDistance = distance;
    }
  }

  if (onTrackPoint) {
    onTrackPoint->x = closestPoint.x * scale + self.position.x;
    onTrackPoint->y = closestPoint.y * scale + self.position.y;
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
  return closestDistance;
}

- (BOOL)getPath:(int *)pathId progress:(CGFloat *)progress forEndPoint:(CGPoint)endPoint rotation:(CGFloat)rotationRadians scale:(CGFloat)scale
{
  CGPoint pathEndPoint = CGPointMake((endPoint.x - self.position.x) / scale, (endPoint.y - self.position.y) / scale);

  // note: The required information about the paths -- i.e the path's endpoints, with tangent and progress
  // at those endpoints -- is known statically by the path itself.  Switch information -- i.e. which paths
  // are being switched, and at which endpoints -- is known statically by the segment.  So this entire
  // function could be written as a single static lookup table.  But it seems like more fun to do all
  // tests dynamically, using simple getPoint() and getTangent() methods.

  const FLPath *paths[FLSegmentNodePathsMax];
  int pathCount = [self FL_allPaths:paths];

  BOOL foundOne = NO;
  for (int p = 0; p < pathCount; ++p) {
    const FLPath *path = paths[p];

    // note: End points can are usually in corners of the unit square, but might be elsewhere
    // (e.g. the center of an edge on platforms).  But no need for a tight comparison; if the
    // endpoint is close to a corner, then it's assumed to be on a corner.  Similarly, rotations
    // at end points can (currently) only be at right angles, so again, no need for a tight comparison.

    // note: If there are two paths from this endpoint, then either there is a switch
    // to choose between them, or else we choose the first one found.

    CGPoint zeroProgressPoint = path->getPoint(0.0f);
    if (fabs(pathEndPoint.x - zeroProgressPoint.x) < 0.1f
        && fabs(pathEndPoint.y - zeroProgressPoint.y) < 0.1f) {
      CGFloat zeroProgressRotation = path->getTangent(0.0f);
      CGFloat rotationDifference = fabs(fmod(rotationRadians - zeroProgressRotation, (CGFloat)M_PI));
      if (rotationDifference < 0.1f || rotationDifference > M_PI - 0.1f) {
        if (!foundOne || _switchPathId == p) {
          *pathId = p;
          *progress = 0.0f;
          foundOne = YES;
        }
        if (_switchPathId == FLSegmentSwitchPathIdNone) {
          return YES;
        } else {
          continue;
        }
      }
    }

    CGPoint oneProgressPoint = path->getPoint(1.0f);
    if (fabs(pathEndPoint.x - oneProgressPoint.x) < 0.1f
        && fabs(pathEndPoint.y - oneProgressPoint.y) < 0.1f) {
      CGFloat oneProgressRotation = path->getTangent(1.0f);
      CGFloat rotationDifference = fabs(fmod(rotationRadians - oneProgressRotation, (CGFloat)M_PI));
      if (rotationDifference < 0.1f || rotationDifference > M_PI - 0.1f) {
        if (!foundOne || _switchPathId == p) {
          *pathId = p;
          *progress = 1.0f;
          foundOne = YES;
        }
        if (_switchPathId == FLSegmentSwitchPathIdNone) {
          return YES;
        } else {
          continue;
        }
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

  if (_segmentType == FLSegmentTypeReadout) {
    [self FL_createContentReadout];
  }

  if (_switchPathId != FLSegmentSwitchPathIdNone) {
    [self FL_createContentSwitch];
    if (_showsSwitchValue) {
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
    if (_showsSwitchValue) {
      [self FL_deleteContentValue];
    }
  }
}

- (void)FL_createContentReadout
{
  // note: Assume the content does not already exist.  Create content according to
  // *current* object state.
  
  // note: Additionally, since this is a helper method, assume _segmentType is
  // FLSegmentTypeReadout.   (That is, the caller is responsible to short-circuit
  // the call in cases where it obviously won't do anything; this prevents duplicate
  // checking.)
}

- (void)FL_deleteContentReadout
{
  // note: Assume content has been created according to *current* object state.
  // After deletion, the caller should change object state accordingly.
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
  } else {
    switchNode.position = CGPointZero;
  }
  switchNode.zPosition = 0.1f;

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
  const CGFloat switchAngle = (CGFloat)M_PI / 7.4f;
  if (_segmentType == FLSegmentTypeJoinLeft) {
    newZRotation = (_switchPathId - 1) * switchAngle;
  } else if (_segmentType == FLSegmentTypeJoinRight) {
    newZRotation = (CGFloat)M_PI + (1 - _switchPathId) * switchAngle;
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
  
  // note: Additionally, since is a helper method, assume _showsSwitchValue is YES.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)

  NSString *valueTextureKey;
  if (_switchPathId == 0) {
    valueTextureKey = @"value-0";
  } else if (_switchPathId == 1) {
    valueTextureKey = @"value-1";
  }
  if (valueTextureKey) {
    SKNode *valueNode = [SKSpriteNode spriteNodeWithTexture:[[HLTextureStore sharedStore] textureForKey:valueTextureKey]];
    valueNode.name = @"value";
    valueNode.zPosition = -0.1f;
    valueNode.zRotation = (CGFloat)M_PI_2 - self.zRotation;
    [self addChild:valueNode];
  }
}

- (void)FL_updateContentValueAnimated:(BOOL)animated
{
  // note: Assume content has been created according to current object state
  // with the exception that _switchPathId has changed from one value to another
  // (neither of them FLSegmentSwitchPathIdNone).
  
  // note: Additionally, since is a helper method, assume _showsSwitchValue is YES.
  // (That is, the caller is responsible to short-circuit the call in cases where
  // it obviously won't do anything; this prevents duplicate checking.)

  // TODO: Animation.

  [self FL_deleteContentValue];
  [self FL_createContentValue];
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
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type."];
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
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type."];
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
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type."];
      return 0;
  }
}

@end
