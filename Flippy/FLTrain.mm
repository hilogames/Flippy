//
//  FLTrain.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/13/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
//

#import "FLTrain.h"

#import <HLSpriteKit/HLError.h>

#import "FLPath.h"
#include "FLTrackGrid.h"

using namespace std;

@implementation FLTrain
{
  shared_ptr<FLTrackGrid> _trackGrid;

  FLSegmentNode *_lastSegmentNode;
  int _lastPathId;
  CGFloat _lastPathLength;
  CGFloat _lastProgress;
  int _lastDirection;
  BOOL _lastSegmentNodeAlreadySwitched;
}

- (instancetype)initWithTexture:(SKTexture *)texture trackGrid:(shared_ptr<FLTrackGrid>&)trackGrid
{
  self = [super initWithTexture:texture color:[SKColor whiteColor] size:texture.size];
  if (self) {
    self.zRotation = (CGFloat)M_PI_2;
    _trackGrid = trackGrid;
    _running = NO;
    _trainSpeed = 1.0f;
  }
  return self;
}

- (instancetype)initWithTexture:(SKTexture *)texture color:(UIColor *)color size:(CGSize)size
{
  shared_ptr<FLTrackGrid> trackGrid;
  return [self initWithTexture:texture trackGrid:trackGrid];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {
    _running = [aDecoder decodeBoolForKey:@"running"];
    _trainSpeed = (CGFloat)[aDecoder decodeDoubleForKey:@"trainSpeed"];
    _lastSegmentNode = [aDecoder decodeObjectForKey:@"lastSegmentNode"];
    _lastPathId = [aDecoder decodeIntForKey:@"lastPathId"];
    _lastPathLength = [_lastSegmentNode pathLengthForPath:_lastPathId];
    _lastProgress = (CGFloat)[aDecoder decodeDoubleForKey:@"lastProgress"];
    _lastDirection = [aDecoder decodeIntForKey:@"lastDirection"];
    _lastSegmentNodeAlreadySwitched = [aDecoder decodeBoolForKey:@"lastSegmentNodeAlreadySwitched"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  [super encodeWithCoder:aCoder];
  
  [aCoder encodeBool:_running forKey:@"running"];
  [aCoder encodeDouble:_trainSpeed forKey:@"trainSpeed"];
  [aCoder encodeObject:_lastSegmentNode forKey:@"lastSegmentNode"];
  [aCoder encodeInt:_lastPathId forKey:@"lastPathId"];
  [aCoder encodeDouble:_lastProgress forKey:@"lastProgress"];
  [aCoder encodeInt:_lastDirection forKey:@"lastDirection"];
  [aCoder encodeBool:_lastSegmentNodeAlreadySwitched forKey:@"lastSegmentNodeAlreadySwitched"];
}

- (void)resetTrackGrid:(std::shared_ptr<FLTrackGrid> &)trackGrid
{
  _trackGrid = trackGrid;
}

- (void)update:(CFTimeInterval)elapsedTime
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
  CGFloat deltaProgress = (_trainSpeed / _lastPathLength) * (CGFloat)elapsedTime * _lastDirection;
  _lastProgress += deltaProgress;

  // If this segment has a switch, then detect if we are leaving our path in such a
  // way that we should trigger the switch.
  //
  // note: This operation is extremely important to the basic concept of the
  // game, and so it seems a little funny that the segment doesn't know much
  // about it.  And yet, the real-life train set (this game is modeled on) behaved
  // that way too: the segment determined the train's direction if it went one way,
  // but the train determined the segment's direction if it went the other way.
  // Another justification for having it here: The segment doesn't know what trains
  // are on it; in order for the segment to effect a change based on the train
  // position, we'd have to have the train give it some kind of callback anyway.
  if (_lastSegmentNode.switchPathId != FLSegmentSwitchPathIdNone
      && !_lastSegmentNodeAlreadySwitched) {
    // note: This only applies, of course, if we're traveling "against" the switch,
    // not "with" the switch; otherwise, the switch chose our path, not vice versa.
    if (_lastDirection == FLPathDirectionIncreasing) {
      if (_lastProgress > 0.7f
          && [_lastSegmentNode pathDirectionGoingWithSwitchForPath:_lastPathId] == FLPathDirectionDecreasing) {
        id<FLTrainDelegate> delegate = _delegate;
        if (delegate) {
          [delegate train:self triggeredSwitchAtSegment:_lastSegmentNode pathId:_lastPathId];
        }
        _lastSegmentNodeAlreadySwitched = YES;
      }
    } else {
      if (_lastProgress < 0.3f
          && [_lastSegmentNode pathDirectionGoingWithSwitchForPath:_lastPathId] == FLPathDirectionIncreasing) {
        id<FLTrainDelegate> delegate = _delegate;
        if (delegate) {
          [delegate train:self triggeredSwitchAtSegment:_lastSegmentNode pathId:_lastPathId];
        }
        _lastSegmentNodeAlreadySwitched = YES;
      }
    }
  }
  
  // If train arrived at a platform, then stop it gracefully.
  if (_lastProgress < 0.0f && _lastDirection == FLPathDirectionDecreasing) {
    FLSegmentType segmentType = _lastSegmentNode.segmentType;
    if (segmentType == FLSegmentTypePlatformLeft || segmentType == FLSegmentTypePlatformRight
        || segmentType == FLSegmentTypePlatformStartLeft || segmentType == FLSegmentTypePlatformStartRight) {
      _lastProgress = 0.0f;
      [self FL_moveToCurrent];
      [self FL_stop];
      return;
    }
  }

  // If the train tries to go past the end of the segment, then attempt to
  // switch to a connecting segment.
  if (_lastProgress < 0.0f) {
    if (![self FL_switchToConnectingSegment]) {
      _lastProgress = 0.0f;
      [self FL_moveToCurrent];
      [self FL_crash];
      return;
    }
  } else if (_lastProgress > 1.0f) {
    if (![self FL_switchToConnectingSegment]) {
      _lastProgress = 1.0f;
      [self FL_moveToCurrent];
      [self FL_crash];
      return;
    }
  }

  // Show the train at the new position.
  [self FL_moveToCurrent];
}

- (BOOL)moveToSegment:(FLSegmentNode *)segmentNode pathId:(int)pathId progress:(CGFloat)progress direction:(int)direction
{
  if (pathId >= [segmentNode pathCount]
      || progress < 0.0f
      || progress > 1.0f) {
    return NO;
  }
  
  _lastSegmentNode = segmentNode;
  _lastPathId = pathId;
  _lastPathLength = [segmentNode pathLengthForPath:pathId];
  _lastProgress = progress;
  _lastDirection = direction;
  _lastSegmentNodeAlreadySwitched = NO;

  [self FL_moveToCurrent];

  return YES;
}

- (BOOL)moveToClosestOnTrackLocationForLocation:(CGPoint)worldLocation gridSearchDistance:(int)gridSearchDistance progressPrecision:(CGFloat)progressPrecision
{
  CGFloat distance;
  CGPoint location;
  CGFloat rotationRadians;
  FLSegmentNode *segmentNode;
  int pathId;
  CGFloat progress;
  if (!trackGridFindClosestOnTrackPoint(*_trackGrid, worldLocation, gridSearchDistance, progressPrecision,
                                        &distance, &location, &rotationRadians, &segmentNode, &pathId, &progress)) {
    return NO;
  }

  // Choose from among switched paths, if relevant.
  //
  // note: This could alternately be done in FLSegmentNode's getClosestOnTrackPoint
  // (called by the track grid already) which must examine each of the segment paths
  // to see which one is closest.  But: 1) It's hard for that method to be certain
  // about the precisions desired by the caller; 2) We're the ones who will later
  // decide to turn the train in the direction where the switch becomes relevant,
  // and it's only then that this becomes a user-facing problem.
  if (segmentNode.switchPathId != FLSegmentSwitchPathIdNone) {
    if (progress < progressPrecision || progress > 1.0f - progressPrecision) {
      const CGFloat segmentSize = _trackGrid->segmentSize();
      CGPoint endPoint;
      if (progress < progressPrecision) {
        [segmentNode getPoint:&endPoint rotation:NULL forPath:pathId progress:0.0f scale:segmentSize];
      } else {
        [segmentNode getPoint:&endPoint rotation:NULL forPath:pathId progress:1.0f scale:segmentSize];
      }
      int switchedPathId;
      CGFloat switchedProgress;
      if (![segmentNode getConnectingPath:&switchedPathId progress:&switchedProgress forEndPoint:endPoint scale:segmentSize]) {
        HLError(HLLevelError, @"FLTrain moveToClosestOnTrackLocationForLocation:gridSearchDistance:progressPrecision:"
                " Could not find path at end point of already-found path.");
      } else if (pathId != switchedPathId) {
        pathId = switchedPathId;
        // note: Use switchedProgress (that is, either 0 or 1 exactly), even though that was not necessarily the
        // closest on-track point.  Mostly just because it's easier.  But also, the effect, if any, will be a small
        // snap-to-intersection, which might nicely visually cue what is happening.
        progress = switchedProgress;
        // note: Location and rotation probably won't be much different; we would just need to flip rotatation by Pi
        // if progress changed.  But recalculating will be more accurate.
        [segmentNode getPoint:&location rotation:&rotationRadians forPath:pathId progress:progress scale:segmentSize];
      }
    }
  }
  
  // Point train inward.
  //
  // note: Easy way to do this: Currently, all paths are closest to the center of the segment at their
  // halfway point.  Slightly more sophisticated way to do this: Calculate atan2f(location.y - segmentPosition.y,
  // location.x - segmentPosition.x) and choose either rotationRadians or rotationRadians+M_PI as closer.
  int direction = (progress < 0.5f ? FLPathDirectionIncreasing : FLPathDirectionDecreasing);

  self.position = location;
  self.zRotation = (direction == FLPathDirectionIncreasing ? rotationRadians : rotationRadians + (CGFloat)M_PI);
  //NSLog(@"path %d progress %3.2f zRotation %.3f", pathId, progress, rotationRadians / M_PI * 180.0f);

  _lastSegmentNode = segmentNode;
  _lastPathId = pathId;
  _lastPathLength = [segmentNode pathLengthForPath:pathId];
  _lastProgress = progress;
  _lastDirection = direction;
  _lastSegmentNodeAlreadySwitched = NO;
  
  return YES;
}

- (void)FL_moveToCurrent
{
  CGPoint location;
  CGFloat rotationRadians;
  [_lastSegmentNode getPoint:&location rotation:&rotationRadians forPath:_lastPathId progress:_lastProgress scale:_trackGrid->segmentSize()];
  self.position = location;
  self.zRotation = (_lastDirection == FLPathDirectionIncreasing ? rotationRadians : rotationRadians + (CGFloat)M_PI);
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
  CGFloat endPointProgress = (_lastDirection == FLPathDirectionIncreasing ? 1.0f : 0.0f);
  FLSegmentNode *nextSegmentNode;
  int nextPathId;
  CGFloat nextEndpointProgress;
  if (!trackGridFindConnecting(*_trackGrid,
                               _lastSegmentNode, _lastPathId, endPointProgress,
                               &nextSegmentNode, &nextPathId, &nextEndpointProgress,
                               nullptr)) {
    return NO;
  }

  CGFloat nextPathLength = [nextSegmentNode pathLengthForPath:nextPathId];
  int nextDirection = (nextEndpointProgress < 0.5f ? FLPathDirectionIncreasing : FLPathDirectionDecreasing);

  // note: lastExcessProgress is magnitude only, and not signed according to direction.
  CGFloat lastExcessProgress;
  if (_lastDirection == FLPathDirectionIncreasing) {
    lastExcessProgress = _lastProgress - 1.0f;
  } else {
    lastExcessProgress = -_lastProgress;
  }
  CGFloat nextProgress;
  if (nextDirection == FLPathDirectionIncreasing) {
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
  _lastSegmentNodeAlreadySwitched = NO;
  
  return YES;
}

@end
