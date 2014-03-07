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

const CGFloat FLSegmentArtSizeFull = 54.0f;
const CGFloat FLSegmentArtSizeBasic = 36.0f;
const CGFloat FLSegmentArtDrawnTrackNormalWidth = 14.0f;
const CGFloat FLSegmentArtScale = 2.0f;

const int FLSegmentSwitchPathIdNone = -1;

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
    _switchPathId = FLSegmentSwitchPathIdNone;
    if (segmentType == FLSegmentTypeJoinLeft || segmentType == FLSegmentTypeJoinRight) {
      self.switchPathId = 1;
    }
  }
  return self;
}

- (id)initWithTextureKey:(NSString *)textureKey
{
  FLSegmentType segmentType;
  if ([textureKey isEqualToString:@"straight"]) {
    segmentType = FLSegmentTypeStraight;
  } else if ([textureKey isEqualToString:@"curve"]) {
    segmentType = FLSegmentTypeCurve;
  } else if ([textureKey isEqualToString:@"join-left"]) {
    segmentType = FLSegmentTypeJoinLeft;
  } else if ([textureKey isEqualToString:@"join-right"]) {
    segmentType = FLSegmentTypeJoinRight;
  } else if ([textureKey isEqualToString:@"jog-left"]) {
    segmentType = FLSegmentTypeJogLeft;
  } else if ([textureKey isEqualToString:@"jog-right"]) {
    segmentType = FLSegmentTypeJogRight;
  } else if ([textureKey isEqualToString:@"cross"]) {
    segmentType = FLSegmentTypeCross;
  } else {
    [NSException raise:@"FLSegmentNodeTexureKeyUnknown" format:@"Unknown segment texture key."];
  }
  SKTexture *texture = [[FLTextureStore sharedStore] textureForKey:textureKey];
  self = [super initWithTexture:texture];
  if (self) {
    _segmentType = segmentType;
    _switchPathId = FLSegmentSwitchPathIdNone;
    if (segmentType == FLSegmentTypeJoinLeft || segmentType == FLSegmentTypeJoinRight) {
      self.switchPathId = 1;
    }
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {
    _segmentType = (FLSegmentType)[aDecoder decodeIntForKey:@"segmentType"];
    _switchPathId = FLSegmentSwitchPathIdNone;
    self.switchPathId = [aDecoder decodeIntForKey:@"switchPathId"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeInt:(int)_segmentType forKey:@"segmentType"];
  [aCoder encodeInt:_switchPathId forKey:@"switchPathId"];
}

- (void)setSwitchPathId:(int)switchPathId
{
  if (_switchPathId == switchPathId) {
    return;
  }
  SKSpriteNode *switchNode;
  if (_switchPathId == FLSegmentSwitchPathIdNone) {
    switchNode = [SKSpriteNode spriteNodeWithTexture:[[FLTextureStore sharedStore] textureForKey:@"switch"]];
    switchNode.name = @"switch";
    CGFloat halfBasicSize = FLSegmentArtSizeBasic / 2.0f;
    if (_segmentType == FLSegmentTypeJoinLeft) {
      switchNode.position = CGPointMake(-halfBasicSize, halfBasicSize);
    } else if (_segmentType == FLSegmentTypeJoinRight) {
      switchNode.position = CGPointMake(halfBasicSize, halfBasicSize);
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
    if (_segmentType == FLSegmentTypeJoinLeft) {
      switchNode.zRotation += (switchPathId - 1) * M_PI / 8.0f;
    } else if (_segmentType == FLSegmentTypeJoinRight) {
      switchNode.zRotation += M_PI + (1 - switchPathId) * M_PI / 8.0f;
    }
  }
  _switchPathId = switchPathId;
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

    if (_switchPathId != FLSegmentSwitchPathIdNone && _switchPathId != p) {
      continue;
    }

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
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type."];
      return 0;
  }
}

@end
