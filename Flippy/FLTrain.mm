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
#import "FLTextureStore.h"

using namespace std;
using namespace HLCommon;

@implementation FLTrain
{
  shared_ptr<QuadTree<FLSegmentNode *>> _trackGrid;
  CGFloat _gridSize;
  BOOL _running;
}

- (id)initWithTrackGrid:(shared_ptr<QuadTree<FLSegmentNode *>>&)trackGrid gridSize:(CGFloat)gridSize
{
  SKTexture *texture = [[FLTextureStore sharedStore] textureForKey:@"engine"];
  self = [super initWithTexture:texture];
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
  
  FLSegmentNode *segmentNode = _trackGrid->get(gridX, gridY, nil);
  if (!segmentNode) {
    return;
  }

  CGFloat progress = fmodf(currentTime, 3.0f) * 3.0f / 10.0f + 0.05f;
  CGPoint point;
  CGFloat rotationRadians;
  [segmentNode getPoint:&point rotation:&rotationRadians forProgress:progress scale:_gridSize];
  self.position = CGPointMake(segmentNode.position.x + point.x,
                              segmentNode.position.y + point.y);
  self.zRotation = rotationRadians;
}

- (BOOL)moveToClosestOnTrackLocationForLocation:(CGPoint)worldLocation
{
  int worldLocationGridX = int(floorf(worldLocation.x / _gridSize + 0.5f));
  int worldLocationGridY = int(floorf(worldLocation.y / _gridSize + 0.5f));

  // note: Calculate closest point on each of nine closest segments.  The performance
  // seems okay even when calculating the best precision for each, but in order to
  // provide an easy way to tweak performance in the future, do two passes: coarse to
  // find the closest segment, and fine to get the best point on the roughly-closest
  // segment.
  const CGFloat FLPrecisionClosestSegment = 0.1f;
  const CGFloat FLPrecisionClosestLocation = 0.01f;

  FLSegmentNode *closestSegmentNode = nil;
  CGFloat closestDistance;
  for (int gx = worldLocationGridX - 1; gx <= worldLocationGridX + 1; ++gx) {
    for (int gy = worldLocationGridY - 1; gy <= worldLocationGridY + 1; ++gy) {
      FLSegmentNode *segmentNode = _trackGrid->get(gx, gy, nil);
      if (!segmentNode) {
        continue;
      }
      CGFloat distance = [segmentNode getClosestOnSegmentPoint:nil rotation:nil progress:nil forOffSegmentPoint:worldLocation scale:_gridSize precision:FLPrecisionClosestSegment];
      if (!closestSegmentNode || distance < closestDistance) {
        closestSegmentNode = segmentNode;
        closestDistance = distance;
      }
    }
  }
  if (!closestSegmentNode) {
    return NO;
  }

  CGPoint location;
  CGFloat rotationRadians;
  CGFloat progress;
  [closestSegmentNode getClosestOnSegmentPoint:&location rotation:&rotationRadians progress:&progress forOffSegmentPoint:worldLocation scale:_gridSize precision:FLPrecisionClosestLocation];

  // Point train inward.
  //
  // note: Easy way to do this: Currently, all paths are closest to the center of the segment at their
  // halfway point.  Slightly more sophisticated way to do this: Calculate atan2f(location.y - segmentPosition.y,
  // location.x - segmentPosition.x) and get rotationRadians within M_PI radians of that.
  if (progress > 0.5f) {
    rotationRadians += M_PI;
  }

  self.position = location;
  self.zRotation = rotationRadians;
  return YES;
}

@end
