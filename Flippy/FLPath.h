//
//  FLPath.h
//  Flippy
//
//  Created by Karl Voskuil on 2/21/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#include <memory>

enum FLPathType { FLPathTypeNone, FLPathTypeStraight, FLPathTypeCurve, FLPathTypeJog };

/**
 * A path is one of a few different discrete curves, and supports some basic
 * geometric operations like finding points and tangents along the curve.
 *
 * The implementation uses either straight line segments or cubic Bezier curves.
 * It is not general, and it takes serious liberties with approximation, and
 * makes some bold assumptions about the kinds of curves supported.  In
 * particular, most of the queries are parameterized in terms of "progress",
 * which is a number between 0 and 1 describing the value of the parameter
 * used to create Bezier curves.  Most callers use it to mean the same as
 * distance along the curve, when in fact Bezier curves in general can be
 * quite non-linear with respect to their parameter.  But we choose curves
 * that aren't horribly locally non-linear, and also we expect the caller
 * doesn't care too much.
 */

class FLPath
{
public:
  FLPath() : pathType_(FLPathTypeNone) {}
  FLPath(FLPathType pathType, int rotationQuarters);
  CGPoint getPoint(CGFloat progress) const;
  // note: Tangent values returned are in the range [-M_PI,+M_PI].
  CGFloat getTangent(CGFloat progress) const;
  CGFloat getLength() const;
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
