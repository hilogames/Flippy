//
//  FLSegmentNode.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/22/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import "FLSegmentNode.h"

#import "FLPath.h"
#import "FLTextureStore.h"

static const unsigned int FLSegmentNodePathsMax = 2;

@implementation FLSegmentNode

- (id)initWithSegmentType:(FLSegmentType)segmentType
{
  SKTexture *texture = nil;
  switch (segmentType) {
    case FLSegmentTypeStraight:
      texture = [[FLTextureStore sharedStore] textureForKey:@"straight"];
      break;
    case FLSegmentTypeCurve:
      texture = [[FLTextureStore sharedStore] textureForKey:@"curve"];
      break;
    case FLSegmentTypeJoinLeft:
      texture = [[FLTextureStore sharedStore] textureForKey:@"join-left"];
      break;
    case FLSegmentTypeJoinRight:
      texture = [[FLTextureStore sharedStore] textureForKey:@"join-right"];
      break;
    case FLSegmentTypeJogLeft:
      texture = [[FLTextureStore sharedStore] textureForKey:@"jog-left"];
      break;
    case FLSegmentTypeJogRight:
      texture = [[FLTextureStore sharedStore] textureForKey:@"jog-right"];
      break;
    case FLSegmentTypeCross:
      texture = [[FLTextureStore sharedStore] textureForKey:@"cross"];
      break;
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeUnknown" format:@"Unknown segment type."];
  }
  self = [super initWithTexture:texture];
  if (self) {
    _segmentType = segmentType;
  }
  return self;
}

- (id)initWithTextureKey:(NSString *)textureKey
{
  if ([textureKey isEqualToString:@"straight"]) {
    _segmentType = FLSegmentTypeStraight;
  } else if ([textureKey isEqualToString:@"curve"]) {
    _segmentType = FLSegmentTypeCurve;
  } else if ([textureKey isEqualToString:@"join-left"]) {
    _segmentType = FLSegmentTypeJoinLeft;
  } else if ([textureKey isEqualToString:@"join-right"]) {
    _segmentType = FLSegmentTypeJoinRight;
  } else if ([textureKey isEqualToString:@"jog-left"]) {
    _segmentType = FLSegmentTypeJogLeft;
  } else if ([textureKey isEqualToString:@"jog-right"]) {
    _segmentType = FLSegmentTypeJogRight;
  } else if ([textureKey isEqualToString:@"cross"]) {
    _segmentType = FLSegmentTypeCross;
  } else {
    [NSException raise:@"FLSegmentNodeTexureKeyUnknown" format:@"Unknown segment texture key."];
  }
  SKTexture *texture = [[FLTextureStore sharedStore] textureForKey:textureKey];
  self = [super initWithTexture:texture];
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {
    _segmentType = (FLSegmentType)[aDecoder decodeIntForKey:@"segmentType"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeInt:(int)_segmentType forKey:@"segmentType"];
}

- (int)zRotationQuarters
{
  return convertRotationRadiansToQuarters(self.zRotation);
}

- (void)setZRotationQuarters:(int)zRotationQuarters
{
  self.zRotation = convertRotationQuartersToRadians(zRotationQuarters);
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
  const FLPath *paths[FLSegmentNodePathsMax];
  int pathCount = [self FL_allPaths:paths];

  CGPoint pathEndPoint = CGPointMake((endPoint.x - self.position.x) / scale, (endPoint.y - self.position.y) / scale);

  for (int p = 0; p < pathCount; ++p) {
    const FLPath *path = paths[p];

    // note: End points can (currently) only be in the corner of the unit square.  So no need
    // for a tight comparison; really we just need to be within 0.5f (less an epsilon value
    // for floating point error).  Similarly, rotations at end points can (currently) only
    // be at right angles, so again, no need for a tight comparison.

    CGPoint zeroProgressPoint = path->getPoint(0.0f);
    if (fabsf(pathEndPoint.x - zeroProgressPoint.x) < 0.1f
        && fabsf(pathEndPoint.y - zeroProgressPoint.y) < 0.1f) {
      CGFloat zeroProgressRotation = path->getTangent(0.0f);
      CGFloat rotationDifference = fabsf(fmodf(rotationRadians - zeroProgressRotation, M_PI));
      if ((rotationDifference > -0.1f && rotationDifference < 0.1f)
          || (rotationDifference > M_PI - 0.1f && rotationDifference < M_PI + 0.1f)) {
        *pathId = p;
        *progress = 0.0f;
        return YES;
      }
    }

    CGPoint oneProgressPoint = path->getPoint(1.0f);
    if (fabsf(pathEndPoint.x - oneProgressPoint.x) < 0.1f
        && fabsf(pathEndPoint.y - oneProgressPoint.y) < 0.1f) {
      CGFloat oneProgressRotation = path->getTangent(1.0f);
      CGFloat rotationDifference = fabsf(fmodf(rotationRadians - oneProgressRotation, M_PI));
      if ((rotationDifference > -0.1f && rotationDifference < 0.1f)
          || (rotationDifference > M_PI - 0.1f && rotationDifference < M_PI + 0.1f)) {
        *pathId = p;
        *progress = 1.0f;
        return YES;
      }
    }
  }
  
  return NO;
}

- (CGFloat)pathLengthForPath:(int)pathId
{
  return [self FL_path:pathId]->getLength();
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
    case FLSegmentTypeJoinRight:
      if (pathId == 0) {
        pathType = FLPathTypeCurve;
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
      paths[0] = FLPathStore::sharedStore()->getPath(FLPathTypeCurve, rotationQuarters - 1);
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
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type."];
      return 0;
  }
}

@end
