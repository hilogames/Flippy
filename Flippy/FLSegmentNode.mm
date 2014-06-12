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
  NSString *key = [FLSegmentNode keyForSegmentType:segmentType];
  SKTexture *texture = [[HLTextureStore sharedStore] textureForKey:key];
  self = [super initWithTexture:texture];
  if (self) {
    _segmentType = segmentType;
    _switchPathId = FLSegmentSwitchPathIdNone;
    if (segmentType == FLSegmentTypeJoinLeft || segmentType == FLSegmentTypeJoinRight) {
      // noob: Is it okay to be adding children nodes and stuff before finished initializating?
      // Ditto in other init methods.
      [self setSwitchPathId:1 animated:NO];
    }
  }
  return self;
}

- (id)initWithTextureKey:(NSString *)textureKey
{
  FLSegmentType segmentType = [FLSegmentNode segmentTypeForKey:textureKey];
  SKTexture *texture = [[HLTextureStore sharedStore] textureForKey:textureKey];
  self = [super initWithTexture:texture];
  if (self) {
    _segmentType = segmentType;
    _switchPathId = FLSegmentSwitchPathIdNone;
    if (segmentType == FLSegmentTypeJoinLeft || segmentType == FLSegmentTypeJoinRight) {
      [self setSwitchPathId:1 animated:NO];
    }
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {
    _segmentType = (FLSegmentType)[aDecoder decodeIntForKey:@"segmentType"];
    [self setSwitchPathId:[aDecoder decodeIntForKey:@"switchPathId"] animated:NO];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeInt:(int)_segmentType forKey:@"segmentType"];
  [aCoder encodeInt:_switchPathId forKey:@"switchPathId"];
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
  } else {
    [NSException raise:@"FLSegmentNodeTexureKeyUnknown" format:@"Unknown segment texture key."];
  }
  return FLSegmentTypeNone;
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

- (int)switchPathId
{
  return _switchPathId;
}

- (void)setSwitchPathId:(int)switchPathId animated:(BOOL)animated
{
  if (_switchPathId == switchPathId) {
    return;
  }
  SKSpriteNode *switchNode;
  if (_switchPathId == FLSegmentSwitchPathIdNone) {
    switchNode = [SKSpriteNode spriteNodeWithTexture:[[HLTextureStore sharedStore] textureForKey:@"switch"]];
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
  } else {
    switchNode = (SKSpriteNode *)[self childNodeWithName:@"switch"];
  }
  if (switchPathId == FLSegmentSwitchPathIdNone) {
    [switchNode removeFromParent];
  } else {
    CGFloat newZRotation = 0.0f;
    if (_segmentType == FLSegmentTypeJoinLeft) {
      newZRotation = (switchPathId - 1) * (CGFloat)M_PI / 8.0f;
    } else if (_segmentType == FLSegmentTypeJoinRight) {
      newZRotation = (CGFloat)M_PI + (1 - switchPathId) * (CGFloat)M_PI / 8.0f;
    }
    if (_switchPathId == FLSegmentSwitchPathIdNone || !animated) {
      switchNode.zRotation = newZRotation;
    } else {
      [switchNode runAction:[SKAction rotateToAngle:newZRotation duration:0.1 shortestUnitArc:YES]];
    }
  }
  _switchPathId = switchPathId;
}

- (int)toggleSwitchPathIdAnimated:(BOOL)animated
{
  if (_switchPathId == FLSegmentSwitchPathIdNone) {
    return FLSegmentSwitchPathIdNone;
  }
  // note: Currently, there are only two switch positions.
  if (_switchPathId == 0) {
    [self setSwitchPathId:1 animated:animated];
    return 1;
  } else {
    [self setSwitchPathId:0 animated:animated];
    return 0;
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
      if ((rotationDifference > -0.1f && rotationDifference < 0.1f)
          || (rotationDifference > M_PI - 0.1f && rotationDifference < M_PI + 0.1f)) {
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
      if ((rotationDifference > -0.1f && rotationDifference < 0.1f)
          || (rotationDifference > M_PI - 0.1f && rotationDifference < M_PI + 0.1f)) {
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
