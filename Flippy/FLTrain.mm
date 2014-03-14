//
//  FLTrain.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/13/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import "FLTrain.h"

#import "FLTextureStore.h"
#include "FLTrackGrid.h"

using namespace std;

static const int FLTrainDirectionForward = 1;
static const int FLTrainDirectionReverse = -1;

@implementation FLTrain
{
  shared_ptr<FLTrackGrid> _trackGrid;

  BOOL _running;
  BOOL _firstUpdateSinceRunning;

  FLSegmentNode *_lastSegmentNode;
  int _lastPathId;
  CGFloat _lastProgress;
  int _lastDirection;
}

- (id)initWithTrackGrid:(shared_ptr<FLTrackGrid>&)trackGrid
{
  SKTexture *texture = [[FLTextureStore sharedStore] textureForKey:@"engine"];
  self = [super initWithTexture:texture];
  if (self) {
    self.zRotation = M_PI_2;
    _trackGrid = trackGrid;
    _running = NO;
  }
  return self;
}

- (void)setRunning:(BOOL)running
{
  if (!_running && running) {
    _firstUpdateSinceRunning = YES;
  }
  _running = running;
}

- (void)update:(CFTimeInterval)elapsedTime
{
  if (!_running) {
    return;
  }

  // If never put on track, then crash.
  if (!_lastSegmentNode) {
    self.running = NO;
    return;
  }
  
  // If last segment node has been removed or replaced, then crash.
  //
  // note: For now, assuming that the track can change from frame to frame.  If the overhead
  // is too much, then can impose some editing restrictions (or simpler error checking) on
  // the track.
  //
  // note: However, we assume that if we can find the last segment node at least somewhere
  // nearby, then we must still be on track.  So, if the last segment node is just moved
  // a little bit, or if it's rotated, we'll probably happily follow right along.
  //
  // note: Keep in mind that checking if the last segment node is still here isn't as
  // simple as checking at the train's position.  The train runs on edges and corners
  // of segments, and so because of floating point error (and also because of points
  // legitimately shared by multiple segments), we have to look at "adjacent" segments
  // (where adjacent is a bit fuzzy).
  BOOL foundLastSegmentNode = NO;
  FLSegmentNode *adjacentSegmentNodes[FLTrackGridAdjacentMax];
  size_t adjacentCount = trackGridFindAdjacent(*_trackGrid, self.position, adjacentSegmentNodes);
  for (int as = 0; as < adjacentCount; ++as) {
    if (adjacentSegmentNodes[as] == _lastSegmentNode) {
      foundLastSegmentNode = YES;
      break;
    }
  }
  if (!foundLastSegmentNode) {
    self.running = NO;
    return;
  }

  // Calculate train's new progress along current segment.
  //
  // note: Current speed is constant in terms of progress.  This will be modified in
  // the future to account for path length, and probably also to allow acceleration
  // for fun.
  const CGFloat FLTrainSpeedProgressPerSecond = 0.7f;
  CGFloat deltaProgress;
  if (_firstUpdateSinceRunning) {
    deltaProgress = 0.0f;
    _firstUpdateSinceRunning = NO;
  } else {
    deltaProgress = FLTrainSpeedProgressPerSecond * elapsedTime * _lastDirection;
  }
  _lastProgress += deltaProgress;

  // If the train tries to go past the end of the segment, then attempt to
  // switch to a connecting segment.
  if (_lastProgress < 0.0f || _lastProgress > 1.0f) {
    if (![self FL_switchToConnectingSegment]) {
      self.running = NO;
      return;
    }
    // note: One loose end here: The switch method carries over remaining progress
    // from the last segment to the new one.  That will have to modified once
    // path length is taken into account; the switch method should maybe instead
    // return the remaining progress, and let us do the math.  Or maybe better,
    // factor out the code to do the progression math, and both we and the switch
    // method will call it.
  }

  // Show the train at the new position.
  CGPoint location;
  CGFloat rotationRadians;
  [_lastSegmentNode getPoint:&location rotation:&rotationRadians forPath:_lastPathId progress:_lastProgress scale:_trackGrid->segmentSize()];
  self.position = location;
  self.zRotation = (_lastDirection == FLTrainDirectionForward ? rotationRadians : rotationRadians + M_PI);
}

- (BOOL)moveToClosestOnTrackLocationForLocation:(CGPoint)worldLocation
{
  // note: Search distance 1 means we'll look at the 9 segments centered around worldLocation.
  const int FLGridSearchDistance = 1;
  const CGFloat FLProgressPrecision = 0.01f;

  CGFloat distance;
  CGPoint location;
  CGFloat rotationRadians;
  FLSegmentNode *segmentNode;
  int pathId;
  CGFloat progress;
  if (!trackGridFindClosestOnTrackPoint(*_trackGrid, worldLocation, FLGridSearchDistance, FLProgressPrecision,
                                        &distance, &location, &rotationRadians, &segmentNode, &pathId, &progress)) {
    return NO;
  }

  // Point train inward.
  //
  // note: Easy way to do this: Currently, all paths are closest to the center of the segment at their
  // halfway point.  Slightly more sophisticated way to do this: Calculate atan2f(location.y - segmentPosition.y,
  // location.x - segmentPosition.x) and choose either rotationRadians or rotationRadians+M_PI as closer.
  int direction = (progress < 0.5f ? FLTrainDirectionForward : FLTrainDirectionReverse);

  self.position = location;
  self.zRotation = (direction == FLTrainDirectionForward ? rotationRadians : rotationRadians + M_PI);

  _lastSegmentNode = segmentNode;
  _lastPathId = pathId;
  _lastProgress = progress;
  _lastDirection = direction;

  return YES;
}

- (BOOL)FL_switchToConnectingSegment
{
  CGFloat endPointProgress = (_lastDirection == FLTrainDirectionForward ? 1.0f : 0.0f);
  FLSegmentNode *nextSegmentNode;
  int nextPathId;
  CGFloat nextProgress;
  if (!trackGridFindConnecting(*_trackGrid,
                               _lastSegmentNode, _lastPathId, endPointProgress,
                               &nextSegmentNode, &nextPathId, &nextProgress)) {
    return NO;
  }

  int nextDirection = (nextProgress < 0.5f ? FLTrainDirectionForward : FLTrainDirectionReverse);

  _lastSegmentNode = nextSegmentNode;
  _lastPathId = nextPathId;
  if (_lastDirection == nextDirection) {
    _lastProgress = _lastProgress - _lastDirection;
  } else {
    _lastProgress = 1.0f - _lastProgress + _lastDirection;
  }
  _lastDirection = nextDirection;

  return YES;
}

@end
