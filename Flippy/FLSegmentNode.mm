//
//  FLSegmentNode.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/22/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import "FLSegmentNode.h"

#include "FLCommon.h"
#import "FLPath.h"
#import "FLTextureStore.h"

@implementation FLSegmentNode

- (id)initWithSegmentType:(FLSegmentType)segmentType
{
  SKTexture *texture = nil;
  switch (segmentType) {
    case FLSegmentTypeStraight:
      texture = [[FLTextureStore sharedStore] textureForKey:@"straight"];
      break;
    case FLSegmentTypeCurve:
      texture = [[FLTextureStore sharedStore] textureForKey:@"straight"];
      break;
    case FLSegmentTypeJoin:
      texture = [[FLTextureStore sharedStore] textureForKey:@"straight"];
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
  } else if ([textureKey isEqualToString:@"join"]) {
    _segmentType = FLSegmentTypeJoin;
  } else {
    [NSException raise:@"FLSegmentNodeTexureKeyUnknown" format:@"Unknown segment texture key."];
  }
  SKTexture *texture = [[FLTextureStore sharedStore] textureForKey:textureKey];
  self = [super initWithTexture:texture];
  return self;
}

- (void)getPoint:(CGPoint *)point rotation:(CGFloat *)rotationRadians forProgress:(CGFloat)progress scale:(CGFloat)scale
{
  const FLPath *path = [self FL_currentPath];
  CGPoint pathPoint = path->getPoint(progress);
  // note: Scaling would seem to be the segment's job, which is why it's here.  But for space
  // optimizations, the segment doesn't actually know the scale of its own paths.  Either:
  // 1) Do it like this; 2) Pass the scale into the underlying shared paths; 3) Use a class
  // constant to define the scale for all segments; 4) Make the scale inferrable from the
  // segment's texure size, e.g. the pad on the outside is always 20% or whatever.  Meh,
  // whatever.
  point->x = pathPoint.x * scale;
  point->y = pathPoint.y * scale;
  *rotationRadians = path->getTangent(progress);
}

- (CGFloat)getClosestOnSegmentPoint:(CGPoint *)onSegmentPoint rotation:(CGFloat *)rotationRadians forOffSegmentPoint:(CGPoint)offSegmentPoint scale:(CGFloat)scale precision:(CGFloat)precision
{
  const FLPath *path = [self FL_currentPath];
  // note: Again, note that path points are contained within the unit square centered on the origin.
  // Segment points, on the other hand, are in the segment's parent's coordinate system (that is,
  // comparable to the segment's position).
  CGPoint offPathPoint = CGPointMake((offSegmentPoint.x - self.position.x) / scale,
                                     (offSegmentPoint.y - self.position.y) / scale);
  CGPoint onPathPoint;
  CGFloat onPathProgress;
  CGFloat distance = path->getClosestOnPathPoint(&onPathPoint, &onPathProgress, offPathPoint, precision);
  onSegmentPoint->x = onPathPoint.x * scale + self.position.x;
  onSegmentPoint->y = onPathPoint.y * scale + self.position.y;
  *rotationRadians = path->getTangent(onPathProgress);
  return distance;
}

- (const FLPath *)FL_currentPath
{
  FLPathType pathType;
  switch (_segmentType) {
    case FLSegmentTypeStraight:
      pathType = FLPathTypeStraight;
      break;
    case FLSegmentTypeCurve:
    case FLSegmentTypeJoin:
      pathType = FLPathTypeCurve;
      break;
    case FLSegmentTypeNone:
    default:
      [NSException raise:@"FLSegmentNodeSegmentTypeInvalid" format:@"Invalid segment type."];
  }
  int rotationQuarters = convertRotationRadiansToQuarters(self.zRotation);
  return FLPathStore::sharedStore()->getPath(pathType, rotationQuarters);
}

@end
