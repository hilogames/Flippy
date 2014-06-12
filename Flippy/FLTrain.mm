//
//  FLTrain.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/13/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import "FLTrain.h"

#import <HLSpriteKit/HLTextureStore.h>

#include "FLTrackGrid.h"

using namespace std;

const int FLTrainDirectionForward = 1;
const int FLTrainDirectionReverse = -1;

@implementation FLTrain
{
  shared_ptr<FLTrackGrid> _trackGrid;

  BOOL _running;

  FLSegmentNode *_lastSegmentNode;
  int _lastPathId;
  CGFloat _lastPathLength;
  CGFloat _lastProgress;
  int _lastDirection;
}

- (id)initWithTrackGrid:(shared_ptr<FLTrackGrid>&)trackGrid
{
  SKTexture *texture = [[HLTextureStore sharedStore] textureForKey:@"engine"];
  self = [super initWithTexture:texture];
  if (self) {
    self.zRotation = (CGFloat)M_PI_2;
    _trackGrid = trackGrid;
    _running = NO;
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {
    _running = [aDecoder decodeBoolForKey:@"running"];
    _lastSegmentNode = [aDecoder decodeObjectForKey:@"lastSegmentNode"];
    _lastPathId = [aDecoder decodeIntForKey:@"lastPathId"];
    _lastPathLength = [_lastSegmentNode pathLengthForPath:_lastPathId];
    _lastProgress = [aDecoder decodeFloatForKey:@"lastProgress"];
    _lastDirection = [aDecoder decodeIntForKey:@"lastDirection"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  [super encodeWithCoder:aCoder];
  
  [aCoder encodeBool:_running forKey:@"running"];
  [aCoder encodeObject:_lastSegmentNode forKey:@"lastSegmentNode"];
  [aCoder encodeInt:_lastPathId forKey:@"lastPathId"];
  [aCoder encodeDouble:_lastProgress forKey:@"lastProgress"];
  [aCoder encodeInt:_lastDirection forKey:@"lastDirection"];
}

- (void)resetTrackGrid:(std::shared_ptr<FLTrackGrid> &)trackGrid
{
  _trackGrid = trackGrid;
}

- (void)setRunning:(BOOL)running
{
  _running = running;
}

- (void)update:(CFTimeInterval)elapsedTime simulationSpeed:(int)simulationSpeed
{
  if (!_running) {
    return;
  }

  // If never put on track, then crash.
  if (!_lastSegmentNode) {
    [self FL_crash];
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
  for (size_t as = 0; as < adjacentCount; ++as) {
    if (adjacentSegmentNodes[as] == _lastSegmentNode) {
      foundLastSegmentNode = YES;
      break;
    }
  }
  if (!foundLastSegmentNode) {
    [self FL_crash];
    return;
  }

  // Calculate train's new progress along current segment.
  //
  // note: Current speed is constant in terms of progress.  This will be modified in
  // the future to account for path length, and probably also to allow acceleration
  // for fun.
  const CGFloat FLTrainNormalSpeedPathLengthPerSecond = 1.8f;
  CGFloat speedPathLengthPerSecond = FLTrainNormalSpeedPathLengthPerSecond * (1.0f + simulationSpeed * simulationSpeed);
  CGFloat deltaProgress = (speedPathLengthPerSecond / _lastPathLength) * (CGFloat)elapsedTime * _lastDirection;
  _lastProgress += deltaProgress;

  // If this segment has a switch, then set the switch according to the traveled path
  // as we are leaving.
  //
  // note: Once would be enough.  Could set when entering, or when leaving, or at
  // every point in between.  Currently, we set it repeatedly during a range while
  // close to leaving.
  //
  // note: This only applies, of course, if we're traveling "backwards" against the
  // switch; otherwise, the switch already would have chosen our direction for us.
  //
  // note: This operation is extremely important to the basic concept of the
  // game, and so it seems a little funny that the segment doesn't know anything
  // about it.  And yet, the real-life train set (this game is modeled on) behaved
  // that way too: the segment determined the train's direction if it went one way,
  // but the train determined the segment's direction if it went the other way.
  // Another justification for having it here: The segment doesn't know what trains
  // are on it; in order for the segment to effect a change based on the train
  // position, we'd have to have the train give it some kind of callback anyway.
  if (_lastSegmentNode.switchPathId != FLSegmentSwitchPathIdNone
      && _lastSegmentNode.switchPathId != _lastPathId) {
    if (_lastDirection == FLTrainDirectionForward) {
      if (_lastProgress > 0.9f) {
        [_lastSegmentNode setSwitchPathId:_lastPathId animated:YES];
        id<FLTrainDelegate> delegate = _delegate;
        if (delegate) {
          [delegate train:self didSwitchSegment:_lastSegmentNode toPathId:_lastPathId];
        }
      }
    } else {
      if (_lastProgress < 0.1f) {
        [_lastSegmentNode setSwitchPathId:_lastPathId animated:YES];
        id<FLTrainDelegate> delegate = _delegate;
        if (delegate) {
          [delegate train:self didSwitchSegment:_lastSegmentNode toPathId:_lastPathId];
        }
      }
    }
  }
  
  // If train arrived at a platform, then stop it gracefully.
  if (_lastSegmentNode.segmentType == FLSegmentTypePlatform && _lastDirection == FLTrainDirectionReverse && _lastProgress < 0.0f) {
    [self FL_stop];
    return;
  }

  // If the train tries to go past the end of the segment, then attempt to
  // switch to a connecting segment.
  if (_lastProgress < 0.0f || _lastProgress > 1.0f) {
    if (![self FL_switchToConnectingSegment]) {
      [self FL_crash];
      return;
    }
  }

  // Show the train at the new position.
  CGPoint location;
  CGFloat rotationRadians;
  [_lastSegmentNode getPoint:&location rotation:&rotationRadians forPath:_lastPathId progress:_lastProgress scale:_trackGrid->segmentSize()];
  self.position = location;
  self.zRotation = (_lastDirection == FLTrainDirectionForward ? rotationRadians : rotationRadians + (CGFloat)M_PI);
}

- (BOOL)moveToSegment:(FLSegmentNode *)segmentNode pathId:(int)pathId progress:(CGFloat)progress direction:(int)direction
{
  if (pathId >= [segmentNode pathCount]) {
    return NO;
  }
  
  CGPoint location;
  CGFloat rotationRadians;
  [segmentNode getPoint:&location rotation:&rotationRadians forPath:pathId progress:progress scale:_trackGrid->segmentSize()];
  self.position = location;
  self.zRotation = (direction == FLTrainDirectionForward ? rotationRadians : rotationRadians + (CGFloat)M_PI);

  _lastSegmentNode = segmentNode;
  _lastPathId = pathId;
  _lastPathLength = [segmentNode pathLengthForPath:pathId];
  _lastProgress = progress;
  _lastDirection = direction;
  
  return YES;
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
  self.zRotation = (direction == FLTrainDirectionForward ? rotationRadians : rotationRadians + (CGFloat)M_PI);
  //NSLog(@"progress %3.2f zRotation %.2f", progress, rotationRadians / M_PI * 180.0f);

  _lastSegmentNode = segmentNode;
  _lastPathId = pathId;
  _lastPathLength = [segmentNode pathLengthForPath:pathId];
  _lastProgress = progress;
  _lastDirection = direction;

  return YES;
}

- (void)FL_stop
{
  _running = NO;
  id<FLTrainDelegate> delegate = _delegate;
  if (delegate) {
    [delegate train:self stoppedAtSegment:_lastSegmentNode];
  }
}

- (void)FL_crash
{
  _running = NO;
  id<FLTrainDelegate> delegate = _delegate;
  if (delegate) {
    [delegate train:self crashedAtSegment:_lastSegmentNode];
  }
}

- (BOOL)FL_switchToConnectingSegment
{
  CGFloat endPointProgress = (_lastDirection == FLTrainDirectionForward ? 1.0f : 0.0f);
  FLSegmentNode *nextSegmentNode;
  int nextPathId;
  CGFloat nextEndpointProgress;
  if (!trackGridFindConnecting(*_trackGrid,
                               _lastSegmentNode, _lastPathId, endPointProgress,
                               &nextSegmentNode, &nextPathId, &nextEndpointProgress)) {
    return NO;
  }

  CGFloat nextPathLength = [nextSegmentNode pathLengthForPath:nextPathId];
  int nextDirection = (nextEndpointProgress < 0.5f ? FLTrainDirectionForward : FLTrainDirectionReverse);

  // note: lastExcessProgress is magnitude only, and not signed according to direction.
  CGFloat lastExcessProgress;
  if (_lastDirection == FLTrainDirectionForward) {
    lastExcessProgress = _lastProgress - 1.0f;
  } else {
    lastExcessProgress = -_lastProgress;
  }
  CGFloat nextProgress;
  if (nextDirection == FLTrainDirectionForward) {
    nextProgress = lastExcessProgress * _lastPathLength / nextPathLength;
  } else {
    nextProgress = 1.0f - lastExcessProgress * _lastPathLength / nextPathLength;
  }
  
  // commented out: Keep in case ever useful: A cute way to set next progress according
  // to direction.  But doesn't scale according to path length.
  //if (_lastDirection == nextDirection) {
  //  _lastProgress = _lastProgress - _lastDirection;
  //} else {
  //  _lastProgress = 1.0f - _lastProgress + _lastDirection;
  //}

  _lastSegmentNode = nextSegmentNode;
  _lastPathId = nextPathId;
  _lastPathLength = nextPathLength;
  _lastProgress = nextProgress;
  _lastDirection = nextDirection;

  return YES;
}

@end
