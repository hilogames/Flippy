//
//  FLTrain.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/13/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import "FLTrain.h"

#include <vector>

#include "FLCommon.h"

using namespace std;
using namespace HLCommon;

// note: Path points are drawn within a unit square centered on the origin.
static const CGFloat FLPathPointsCurveK = 4.0f / 3.0f * (M_SQRT2 - 1.0f) - 0.5f;
static const vector<CGPoint> FLPathPointsStraight = { { -0.5f, 0.5f }, { 0.5f, 0.5f } };
static const vector<CGPoint> FLPathPointsCurve = { { 0.5f, -0.5f }, { 0.5f, FLPathPointsCurveK }, { FLPathPointsCurveK, 0.5f }, { -0.5f, 0.5f } };

@implementation FLTrain
{
  shared_ptr<QuadTree<SKSpriteNode *>> _trackGrid;
  CGFloat _gridSize;
  BOOL _running;
}

- (id)initWithTrackGrid:(shared_ptr<QuadTree<SKSpriteNode *>>&)trackGrid gridSize:(CGFloat)gridSize
{
  self = [super initWithColor:[UIColor colorWithRed:0.2f green:0.2f blue:0.2f alpha:1.0f] size:CGSizeMake(60.0f, 20.0f)];
  if (self) {
    self.zRotation = M_PI_2;
    _trackGrid = trackGrid;
    _gridSize = gridSize;
    _running = NO;
  }
  return self;
}

- (void)start
{
  if (_running) {
    return;
  }
  _running = YES;
}

- (void)stop
{
  if (!_running) {
    return;
  }
  _running = NO;
}

- (void)update:(CFTimeInterval)currentTime
{
  if (!_running) {
    return;
  }

  // note: For now, assume that the track can change from frame to frame.  If the overhead
  // is too much, then can impose some editing restrictions (or simpler error checking) on
  // the track.

  int gridX;
  int gridY;
  convertWorldLocationToTrackGrid(self.position, _gridSize, &gridX, &gridY);
  
  SKSpriteNode *segmentNode = _trackGrid->get(gridX, gridY, nil);
  if (!segmentNode) {
    return;
  }

  vector<CGPoint> pathPoints;
  getPathPointsForSegment(&pathPoints, segmentNode, _gridSize);

  CGFloat t = fmodf(currentTime, 3.0f) * 3.0f / 10.0f + 0.05f;
  CGPoint point;
  CGPoint tangent;
  bezierGetPointAndTangent(&point, &tangent, t, pathPoints[0], pathPoints[1], pathPoints[2], pathPoints[3]);
  self.position = CGPointMake(segmentNode.position.x + point.x,
                              segmentNode.position.y + point.y);
  self.zRotation = atanf(tangent.y / tangent.x);
  //NSLog(@"time %.2f train on %@ segment grid %d,%d rotation %d", t, segmentNode.name, gridX, gridY, convertRotationRadiansToQuarters(segmentNode.zRotation));
}

- (BOOL)getClosestOnTrackLocation:(CGPoint *)onTrackLocation forLocation:(CGPoint)worldLocation
{
  int worldLocationGridX = int(floorf(worldLocation.x / _gridSize + 0.5f));
  int worldLocationGridY = int(floorf(worldLocation.y / _gridSize + 0.5f));
  CGPoint segmentLocation = CGPointMake(fmodf(worldLocation.x, _gridSize), fmodf(worldLocation.y, _gridSize));

  CGFloat closestDistance = -1.0f;
  for (int gx = worldLocationGridX - 1; gx <= worldLocationGridX + 1; ++gx) {
    for (int gy = worldLocationGridY - 1; gy <= worldLocationGridY + 1; ++gy) {
      SKSpriteNode *segmentNode = _trackGrid->get(gx, gy, nil);
      if (!segmentNode) {
        continue;
      }
      vector<CGPoint> pathPoints;
      getPathPointsForSegment(&pathPoints, segmentNode, _gridSize);
      CGPoint onPathLocation;
      CGFloat distance = getClosestOnPathLocation(&onPathLocation, pathPoints, segmentLocation);
      if (closestDistance < 0.0f || distance < closestDistance) {
        *onTrackLocation = CGPointMake(gx * _gridSize + onPathLocation.x,
                                       gy * _gridSize + onPathLocation.y);
        closestDistance = distance;
      }
    }
  }

  return (closestDistance >= 0.0f);
}

static
void
getPathPointsForSegment(vector<CGPoint> *pathPoints, SKSpriteNode *segmentNode, CGFloat segmentSize)
{
  if ([segmentNode.name isEqualToString:@"straight"]) {
    *pathPoints = FLPathPointsStraight;
  } else if ([segmentNode.name isEqualToString:@"curve"]) {
    *pathPoints = FLPathPointsCurve;
  } else if ([segmentNode.name isEqualToString:@"join"]) {
    // note: Detect path based on current train position and/or based on switch position.
    // For now, assume always curved.
    *pathPoints = FLPathPointsCurve;
  }
  int rotateBy = convertRotationRadiansToQuarters(segmentNode.zRotation);
  rotateAndScalePathPoints(pathPoints, rotateBy, segmentSize);
}

static
void
rotateAndScalePathPoints(vector<CGPoint> *pathPoints, int rotateBy, CGFloat scaleBy)
{
  // noob: Is this simple-rotation baked into something somewhere?  I assume it's quicker
  // to do a modulo and a switch than to do trigonometry, but I could be wrong.

  // note: As elsewhere, rotateBy is an angle measured in quarters; it is cyclical but
  // not constrained to a particular range (e.g. 0 to 3).
  int rotateByConstrained = rotateBy % 4;
  if (rotateByConstrained < 0) {
    rotateByConstrained += 4;
  }
  switch (rotateByConstrained) {
    case 0:
      return;
    case 1:
      for (CGPoint& pathPoint : *pathPoints) {
        CGFloat newX = -pathPoint.y * scaleBy;
        pathPoint.y = pathPoint.x * scaleBy;
        pathPoint.x = newX;
      }
      return;
    case 2:
      for (CGPoint& pathPoint : *pathPoints) {
        pathPoint.x = -pathPoint.x * scaleBy;
        pathPoint.y = -pathPoint.y * scaleBy;
      }
      return;
    case 3:
      for (CGPoint& pathPoint : *pathPoints) {
        CGFloat newX = pathPoint.y * scaleBy;
        pathPoint.y = -pathPoint.x * scaleBy;
        pathPoint.x = newX;
      }
      return;
  }
}

static
CGFloat
getClosestOnPathLocation(CGPoint *onPathLocation, const vector<CGPoint>& pathPoints, CGPoint offPathLocation)
{
  CGFloat distance = 1.0f;
  onPathLocation->x = 0.0f;
  onPathLocation->y = 0.0f;
  return distance;
}

// TODO: Make a struct for holding Bezier information, including pre-calculated x and y coefficients.
// Put it in a module.  Then maybe make a lookup table for a certain segment type and rotation,
// so they can be reused.

//static
//CGFloat
//bezierGetPoint(CGFloat t, CGFloat a, CGFloat b, CGFloat c, CGFloat d)
//{
//  CGFloat co1 = d - (3.0f * c) + (3.0f * b) - a;
//  CGFloat co2 = (3.0f * c) - (6.0f * b) + (3.0f * a);
//  CGFloat co3 = (3.0f * b) - (3.0f * a);
//  CGFloat co4 = a;
//  return co1 * t * t * t + co2 * t * t + co3 * t + co4;
//}
//
//static
//CGPoint
//bezierGetPoint(CGFloat t, CGPoint a, CGPoint b, CGPoint c, CGPoint d)
//{
//  CGPoint result;
//  result.x = bezierGetPoint(t, a.x, b.x, c.x, d.x);
//  result.y = bezierGetPoint(t, a.y, b.y, c.y, d.y);
//  return result;
//}
//
//static
//CGFloat
//bezierGetTangent(CGFloat t, CGFloat a, CGFloat b, CGFloat c, CGFloat d)
//{
//  CGFloat co1 = d - (3.0f * c) + (3.0f * b) - a;
//  CGFloat co2 = (3.0f * c) - (6.0f * b) + (3.0f * a);
//  CGFloat co3 = (3.0f * b) - (3.0f * a);
//  return 3.0f * co1 * t * t + 2.0f * co2 * t + co3;
//}
//
//static
//CGPoint
//bezierGetTangent(CGFloat t, CGPoint a, CGPoint b, CGPoint c, CGPoint d)
//{
//  CGPoint result;
//  result.x = bezierGetTangent(t, a.x, b.x, c.x, d.x);
//  result.y = bezierGetTangent(t, a.y, b.y, c.y, d.y);
//  return result;
//}

static
void
bezierGetPointAndTangent(CGFloat *point, CGFloat *tangent, CGFloat t, CGFloat a, CGFloat b, CGFloat c, CGFloat d)
{
  CGFloat co1 = d - (3.0f * c) + (3.0f * b) - a;
  CGFloat co2 = (3.0f * c) - (6.0f * b) + (3.0f * a);
  CGFloat co3 = (3.0f * b) - (3.0f * a);
  CGFloat co4 = a;
  *point = co1 * t * t * t + co2 * t * t + co3 * t + co4;
  *tangent = 3.0f * co1 * t * t + 2.0f * co2 * t + co3;
}

static
void
bezierGetPointAndTangent(CGPoint *point, CGPoint *tangent, CGFloat t, CGPoint a, CGPoint b, CGPoint c, CGPoint d)
{
  bezierGetPointAndTangent(&(point->x), &(tangent->x), t, a.x, b.x, c.x, d.x);
  bezierGetPointAndTangent(&(point->y), &(tangent->y), t, a.y, b.y, c.y, d.y);
}

@end
