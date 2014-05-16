//
//  FLPath.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/21/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#include "FLPath.h"

#include <tgmath.h>

using namespace std;

void
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
  rotationQuarters = normalizeRotationQuarters(rotationQuarters);

  bool precomputeCoefficients = true;
  switch (pathType_) {
    case FLPathTypeStraight: {
      points_[0] = { -0.5f, 0.5f };
      points_[1] = { 0.5f, 0.5f };
      rotatePoints(points_, 2, rotationQuarters);
      precomputeCoefficients = false;
      break;
    }
    case FLPathTypeCurve: {
      const CGFloat FLPathPointsCurveK = 4.0f / 3.0f * ((CGFloat)M_SQRT2 - 1.0f);
      points_[0] = { 0.5f, -0.5f };
      points_[1] = { 0.5f, -0.5f + FLPathPointsCurveK };
      points_[2] = { -0.5f + FLPathPointsCurveK, 0.5f };
      points_[3] = { -0.5f, 0.5f };
      rotatePoints(points_, 4, rotationQuarters);
      break;
    }
    case FLPathTypeJogLeft: {
      const CGFloat FLPathPointsJogK = 0.6f;
      points_[0] = { -0.5f, -0.5f };
      points_[1] = { -0.5f + FLPathPointsJogK, -0.5f };
      points_[2] = { 0.5f - FLPathPointsJogK, 0.5f };
      points_[3] = { 0.5f, 0.5f };
      rotatePoints(points_, 4, rotationQuarters);
      break;
    }
    case FLPathTypeJogRight: {
      const CGFloat FLPathPointsJogK = 0.6f;
      points_[0] = { -0.5f, 0.5f };
      points_[1] = { -0.5f + FLPathPointsJogK, 0.5f };
      points_[2] = { 0.5f - FLPathPointsJogK, -0.5f };
      points_[3] = { 0.5f, -0.5f };
      rotatePoints(points_, 4, rotationQuarters);
      break;
    }
    case FLPathTypeNone:
    default:
      precomputeCoefficients = false;
      break;
  }
  if (precomputeCoefficients) {
    coefficientsX_[0] = points_[3].x - 3.0f * points_[2].x + 3.0f * points_[1].x - points_[0].x;
    coefficientsX_[1] = 3.0f * points_[2].x - 6.0f * points_[1].x + 3.0f * points_[0].x;
    coefficientsX_[2] = 3.0f * points_[1].x - 3.0f * points_[0].x;
    coefficientsY_[0] = points_[3].y - 3.0f * points_[2].y + 3.0f * points_[1].y - points_[0].y;
    coefficientsY_[1] = 3.0f * points_[2].y - 6.0f * points_[1].y + 3.0f * points_[0].y;
    coefficientsY_[2] = 3.0f * points_[1].y - 3.0f * points_[0].y;
  }
}

CGPoint
FLPath::getPoint(CGFloat progress) const
{
  switch (pathType_) {
    case FLPathTypeStraight:
      return getPointLinear(progress);
    case FLPathTypeCurve:
    case FLPathTypeJogLeft:
    case FLPathTypeJogRight:
      return getPointCubic(progress);
    default:
      return CGPointZero;
  }
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
    case FLPathTypeCurve:
    case FLPathTypeJogLeft:
    case FLPathTypeJogRight: {
      // Cubic.
      CGFloat progressSquared = progress * progress;
      tangentPoint.x = 3.0f * coefficientsX_[0] * progressSquared + 2.0f * coefficientsX_[1] * progress + coefficientsX_[2];
      tangentPoint.y = 3.0f * coefficientsY_[0] * progressSquared + 2.0f * coefficientsY_[1] * progress + coefficientsY_[2];
      break;
    }
    default:
      tangentPoint = CGPointZero;
      break;
  }
  return atan2(tangentPoint.y, tangentPoint.x);
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
        return sqrt((offPathPoint.x - points_[0].x) * (offPathPoint.x - points_[0].x) + (offPathPoint.y - points_[0].y) * (offPathPoint.y - points_[0].y));
      } else if (t > 1.0f) {
        *onPathPoint = points_[1];
        *onPathProgress = 1.0f;
        return sqrt((offPathPoint.x - points_[1].x) * (offPathPoint.x - points_[1].x) + (offPathPoint.y - points_[1].y) * (offPathPoint.y - points_[1].y));
      }
      *onPathPoint = getPointLinear(t);
      *onPathProgress = t;
      return sqrt((offPathPoint.x - onPathPoint->x) * (offPathPoint.x - onPathPoint->x) + (offPathPoint.y - onPathPoint->y) * (offPathPoint.y - onPathPoint->y));
    }
    case FLPathTypeCurve:
    case FLPathTypeJogLeft:
    case FLPathTypeJogRight: {
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
      return sqrt(midDistanceSquared);
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
      return (CGFloat)M_PI_2;
    case FLPathTypeJogLeft:
    case FLPathTypeJogRight:
      // note: Using a K value of 0.6 (for constant FLPathPointsJogK above), I used
      // the graphical representation of Legendre-Gauss approximation on the Bezier
      // curves primer page (<http://pomax.github.io/bezierinfo/#arclength>).  Shameful,
      // but good enough for rock and roll.  Note M_PI_2 is reasonably close also, but
      // that's an even more baseless way to approximate.
      return 1.52f;
    default:
      return 0.0f;
  }
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
  
  // Jog-left paths.
  jogLeftPaths_[0] = { FLPathTypeJogLeft, 0 };
  jogLeftPaths_[1] = { FLPathTypeJogLeft, 1 };

  // Jog-right paths.
  jogRightPaths_[0] = { FLPathTypeJogRight, 0 };
  jogRightPaths_[1] = { FLPathTypeJogRight, 1 };
}

shared_ptr<FLPathStore>
FLPathStore::sharedStore()
{
  // note: Declared on heap to avoid exit-time destructor warning.
  static shared_ptr<FLPathStore> *sharedStore = new shared_ptr<FLPathStore>(new FLPathStore);
  return *sharedStore;
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
  rotationQuarters = normalizeRotationQuarters(rotationQuarters);

  switch (pathType) {
    case FLPathTypeStraight:
      return &straightPaths_[rotationQuarters];
    case FLPathTypeCurve:
      return &curvePaths_[rotationQuarters];
    case FLPathTypeJogLeft:
      return &jogLeftPaths_[rotationQuarters % 2];
    case FLPathTypeJogRight:
      return &jogRightPaths_[rotationQuarters % 2];
    default:
      return nullptr;
  }
}
