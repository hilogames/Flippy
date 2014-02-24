//
//  FLPath.h
//  Flippy
//
//  Created by Karl Voskuil on 2/21/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#include <memory>

enum FLPathType { FLPathTypeNone, FLPathTypeStraight, FLPathTypeCurve, FLPathTypeJog };

class FLPath
{
public:
  FLPath() : pathType_(FLPathTypeNone) {}
  FLPath(FLPathType pathType, int rotationQuarters);
  CGPoint getPoint(CGFloat progress) const;
  CGFloat getTangent(CGFloat progress) const;
  CGFloat getClosestOnPathPoint(CGPoint *onPathPoint, CGFloat *onPathProgress, CGPoint offPathPoint, CGFloat progressPrecision) const;
private:
  CGPoint getPointLinear(CGFloat progress) const;
  CGPoint getPointCubic(CGFloat progress) const;
  
  FLPathType pathType_;
  CGPoint points_[4];
  CGFloat coefficientsX_[3];
  CGFloat coefficientsY_[3];
};

class FLPathStore
{
public:
  static std::shared_ptr<FLPathStore> sharedStore();
  FLPathStore();
  const FLPath *getPath(FLPathType pathType, int rotationQuarters);
private:
  FLPath straightPaths_[4];
  FLPath curvePaths_[4];
  FLPath jogPaths_[4];
};
