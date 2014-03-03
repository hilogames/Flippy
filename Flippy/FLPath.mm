//
//  FLPath.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/21/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#include "FLPath.h"

using namespace std;

/**
 * @param Array of points.
 * @param Number of points in array.
 * @param Quarters for rotation; must be between 0 and 3 inclusive.
 */
static void
rotatePoints(CGPoint *points, int pointCount, int rotateQuarters)
{
  switch (rotateQuarters) {
    case 0:
      return;
    case 1:
      for (int p = 0; p < pointCount; ++p) {
        CGFloat newX = -points[p].y;
        points[p].y = points[p].x;
        points[p].x = newX;
      }
      return;
    case 2:
      for (int p = 0; p < pointCount; ++p) {
        points[p].x = -points[p].x;
        points[p].y = -points[p].y;
      }
      return;
    case 3:
      for (int p = 0; p < pointCount; ++p) {
        CGFloat newX = points[p].y;
        points[p].y = -points[p].x;
        points[p].x = newX;
      }
      return;
  }
}

FLPath::FLPath(FLPathType pathType, int rotationQuarters) : pathType_(pathType)
{
  // note: Normalize rotation within [0,3].
  rotationQuarters = rotationQuarters % 4;
  if (rotationQuarters < 0) {
    rotationQuarters += 4;
  }

  switch (pathType_) {
    case FLPathTypeStraight: {
      points_[0] = { -0.5f, 0.5f };
      points_[1] = { 0.5f, 0.5f };
      rotatePoints(points_, 2, rotationQuarters);
      break;
    }
    case FLPathTypeCurve: {
      const CGFloat FLPathPointsCurveK = 4.0f / 3.0f * (M_SQRT2 - 1.0f) - 0.5f;
      points_[0] = { 0.5f, -0.5f };
      points_[1] = { 0.5f, FLPathPointsCurveK };
      points_[2] = { FLPathPointsCurveK, 0.5f };
      points_[3] = { -0.5f, 0.5f };
      rotatePoints(points_, 4, rotationQuarters);
      coefficientsX_[0] = points_[3].x - 3.0f * points_[2].x + 3.0f * points_[1].x - points_[0].x;
      coefficientsX_[1] = 3.0f * points_[2].x - 6.0f * points_[1].x + 3.0f * points_[0].x;
      coefficientsX_[2] = 3.0f * points_[1].x - 3.0f * points_[0].x;
      coefficientsY_[0] = points_[3].y - 3.0f * points_[2].y + 3.0f * points_[1].y - points_[0].y;
      coefficientsY_[1] = 3.0f * points_[2].y - 6.0f * points_[1].y + 3.0f * points_[0].y;
      coefficientsY_[2] = 3.0f * points_[1].y - 3.0f * points_[0].y;
      break;
    }
    case FLPathTypeJog:
    case FLPathTypeNone:
    default:
      break;
  }
}

CGPoint
FLPath::getPoint(CGFloat progress) const
{
  // note: Assuming that a switch is faster than virtual function table lookup.
  // Consider templates if performance is an issue.
  CGPoint result;
  switch (pathType_) {
    case FLPathTypeStraight:
      return getPointLinear(progress);
    case FLPathTypeCurve:
      return getPointCubic(progress);
    case FLPathTypeJog:
    default:
      break;
  }
  return result;
}

CGPoint
FLPath::getPointLinear(CGFloat progress) const
{
  return CGPointMake(points_[0].x + progress * (points_[1].x - points_[0].x),
                     points_[0].y + progress * (points_[1].y - points_[1].x));
}

CGPoint
FLPath::getPointCubic(CGFloat progress) const
{
  // note: Uh, splitting this out for private use because of the whole "not using
  // real templates" thing.  Probably an indicator I'm being lazy.
  CGFloat progressSquared = progress * progress;
  CGFloat progressCubed = progressSquared * progress;
  return CGPointMake(coefficientsX_[0] * progressCubed + coefficientsX_[1] * progressSquared + coefficientsX_[2] * progress + points_[0].x,
                     coefficientsY_[0] * progressCubed + coefficientsY_[1] * progressSquared + coefficientsY_[2] * progress + points_[0].y);
}

CGFloat
FLPath::getTangent(CGFloat progress) const
{
  CGPoint tangentPoint;
  switch (pathType_) {
    case FLPathTypeStraight:
      // Linear.
      tangentPoint.x = points_[1].x - points_[0].x;
      tangentPoint.y = points_[1].y - points_[0].y;
      break;
    case FLPathTypeCurve: {
      // Cubic.
      CGFloat progressSquared = progress * progress;
      tangentPoint.x = 3.0f * coefficientsX_[0] * progressSquared + 2.0f * coefficientsX_[1] * progress + coefficientsX_[2];
      tangentPoint.y = 3.0f * coefficientsY_[0] * progressSquared + 2.0f * coefficientsY_[1] * progress + coefficientsY_[2];
      break;
    }
    case FLPathTypeJog:
    default:
      break;
  }
  return atan2f(tangentPoint.y, tangentPoint.x);
}

CGFloat
FLPath::getClosestOnPathPoint(CGPoint *onPathPoint, CGFloat *onPathProgress, CGPoint offPathPoint, CGFloat progressPrecision) const
{
  switch (pathType_) {
    case FLPathTypeStraight: {
      CGFloat t = ((offPathPoint.x - points_[0].x) * (points_[1].x - points_[0].x)
                   + (offPathPoint.y - points_[0].y) * (points_[1].y - points_[0].y));
      if (t < 0.0f) {
        *onPathPoint = points_[0];
        *onPathProgress = 0.0f;
        return sqrtf((offPathPoint.x - points_[0].x) * (offPathPoint.x - points_[0].x) + (offPathPoint.y - points_[0].y) * (offPathPoint.y - points_[0].y));
      } else if (t > 1.0f) {
        *onPathPoint = points_[1];
        *onPathProgress = 1.0f;
        return sqrtf((offPathPoint.x - points_[1].x) * (offPathPoint.x - points_[1].x) + (offPathPoint.y - points_[1].y) * (offPathPoint.y - points_[1].y));
      }
      *onPathPoint = getPointLinear(t);
      *onPathProgress = t;
      return sqrtf((offPathPoint.x - onPathPoint->x) * (offPathPoint.x - onPathPoint->x) + (offPathPoint.y - onPathPoint->y) * (offPathPoint.y - onPathPoint->y));
    }
    case FLPathTypeCurve:
    case FLPathTypeJog: {
      // Binary search on cubic bezier.
      //
      // note: I've read that it's possible to do this closed form, also.  But math is hard.
      CGFloat midT = 0.5f;
      CGFloat intervalT = 0.25f;
      CGPoint midPoint = getPoint(midT);
      CGFloat midDistanceSquared = (offPathPoint.x - midPoint.x) * (offPathPoint.x - midPoint.x) + (offPathPoint.y - midPoint.y) * (offPathPoint.y - midPoint.y);
      while (intervalT > progressPrecision) {
        CGFloat lessT = midT - intervalT;
        CGPoint lessPoint = getPointCubic(lessT);
        CGFloat lessDistanceSquared = (offPathPoint.x - lessPoint.x) * (offPathPoint.x - lessPoint.x) + (offPathPoint.y - lessPoint.y) * (offPathPoint.y - lessPoint.y);
        CGFloat moreT = midT + intervalT;
        CGPoint morePoint = getPointCubic(moreT);
        CGFloat moreDistanceSquared = (offPathPoint.x - morePoint.x) * (offPathPoint.x - morePoint.x) + (offPathPoint.y - morePoint.y) * (offPathPoint.y - morePoint.y);
        if (lessDistanceSquared < midDistanceSquared
            || moreDistanceSquared < midDistanceSquared) {
          CGFloat lessDistanceSquaredImprovement = midDistanceSquared - lessDistanceSquared;
          CGFloat moreDistanceSquaredImprovement = midDistanceSquared - moreDistanceSquared;
          if (lessDistanceSquaredImprovement > moreDistanceSquaredImprovement) {
            midT = lessT;
            midPoint = lessPoint;
            midDistanceSquared = lessDistanceSquared;
          } else {
            midT = moreT;
            midPoint = morePoint;
            midDistanceSquared = moreDistanceSquared;
          }
        }
        intervalT /= 2.0f;
      }
      *onPathPoint = midPoint;
      *onPathProgress = midT;
      return sqrtf(midDistanceSquared);
    }
    default:
      break;
  }
  return 0.0f;
}

CGFloat
FLPath::getLength() const
{
  switch (pathType_) {
    case FLPathTypeStraight:
      return 1.0f;
    case FLPathTypeCurve:
      return M_PI_2;
    case FLPathTypeJog:
    default:
      break;
  }
  return 0.0f;
}

FLPathStore::FLPathStore()
{
  // note: Path points are drawn within a unit square centered on the origin.
  
  // Straight paths.
  straightPaths_[0] = { FLPathTypeStraight, 0 };
  straightPaths_[1] = { FLPathTypeStraight, 1 };
  straightPaths_[2] = { FLPathTypeStraight, 2 };
  straightPaths_[3] = { FLPathTypeStraight, 3 };

  // Curve paths.
  curvePaths_[0] = { FLPathTypeCurve, 0 };
  curvePaths_[1] = { FLPathTypeCurve, 1 };
  curvePaths_[2] = { FLPathTypeCurve, 2 };
  curvePaths_[3] = { FLPathTypeCurve, 3 };
}

shared_ptr<FLPathStore>
FLPathStore::sharedStore()
{
  static shared_ptr<FLPathStore> sharedStore(new FLPathStore);
  return sharedStore;
}

const FLPath *
FLPathStore::getPath(FLPathType pathType, int rotationQuarters)
{
  // note: Normalize rotation within [0,3].
  //
  // note: Also: Like the FLPath constructor, we're choosing here to normalize for the caller
  // rather than request it as a precondition.  This is because our caller is not currently
  // motivated to care.  If, in the future, the caller cares, then it would be better to
  // move this code up the call stack.
  rotationQuarters = rotationQuarters % 4;
  if (rotationQuarters < 0) {
    rotationQuarters += 4;
  }

  switch (pathType) {
    case FLPathTypeStraight:
      return &straightPaths_[rotationQuarters];
    case FLPathTypeCurve:
      return &curvePaths_[rotationQuarters];
    case FLPathTypeJog:
      return &jogPaths_[rotationQuarters];
    default:
      return nullptr;
  }
}
