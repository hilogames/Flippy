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

@implementation FLTrain
{
  shared_ptr<QuadTree<FLSegmentNode *>> _trackGrid;
  CGFloat _gridSize;
  BOOL _running;
}

- (id)initWithTrackGrid:(shared_ptr<QuadTree<FLSegmentNode *>>&)trackGrid gridSize:(CGFloat)gridSize
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

  CGFloat closestDistance = -1.0f;
  CGPoint closestLocation;
  CGFloat closestRotation;
  for (int gx = worldLocationGridX - 1; gx <= worldLocationGridX + 1; ++gx) {
    for (int gy = worldLocationGridY - 1; gy <= worldLocationGridY + 1; ++gy) {
      FLSegmentNode *segmentNode = _trackGrid->get(gx, gy, nil);
      if (!segmentNode) {
        continue;
      }
      CGPoint onTrackLocation;
      CGFloat onTrackRotation;
      CGFloat distance = [segmentNode getClosestOnSegmentPoint:&onTrackLocation rotation:&onTrackRotation forOffSegmentPoint:worldLocation scale:_gridSize precision:0.01f];
      if (closestDistance < 0.0f || distance < closestDistance) {
        closestDistance = distance;
        closestLocation = onTrackLocation;
        closestRotation = onTrackRotation;
      }
    }
  }

  if (closestDistance >= 0.0f) {
    self.position = closestLocation;
    self.zRotation = closestRotation;
    return YES;
  } else {
    return NO;
  }
}

@end
