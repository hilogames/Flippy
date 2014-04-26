//
//  FLTrackGrid.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/27/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#include "FLTrackGrid.h"

using namespace std;

const size_t FLTrackGridAdjacentMax = 4;

void
FLTrackGrid::import(SKNode *parentNode)
{
  for (SKNode *childNode in [parentNode children]) {
    if (![childNode isKindOfClass:[FLSegmentNode class]]) {
      continue;
    }
    int gridX;
    int gridY;
    FLTrackGrid::convert(childNode.position, segmentSize_, &gridX, &gridY);
    grid_[{ gridX, gridY }] = (FLSegmentNode *)childNode;
  }
}

size_t
trackGridFindAdjacent(FLTrackGrid& trackGrid, CGPoint worldLocation, __strong FLSegmentNode *adjacent[])
{
  CGFloat FLEpsilon = 0.001f;
  CGFloat segmentSize = trackGrid.segmentSize();
  CGFloat halfSegmentSize = segmentSize / 2.0f;

  int gridX;
  int gridY;
  trackGrid.convert(worldLocation, &gridX, &gridY);

  CGFloat edgeXRemainder = fmodf(worldLocation.x + halfSegmentSize, segmentSize);
  bool onEdgeX = (edgeXRemainder > -FLEpsilon && edgeXRemainder < FLEpsilon)
                 || (edgeXRemainder > segmentSize - FLEpsilon && edgeXRemainder < segmentSize + FLEpsilon);
  CGFloat edgeYRemainder = fmodf(worldLocation.y + halfSegmentSize, segmentSize);
  bool onEdgeY = (edgeYRemainder > -FLEpsilon && edgeYRemainder < FLEpsilon)
                 || (edgeYRemainder > segmentSize - FLEpsilon && edgeYRemainder < segmentSize + FLEpsilon);

  size_t adjacentCount = 0;
  if (onEdgeX && onEdgeY) {
    // Corner.
    int rightGridX = int(floorf((worldLocation.x + halfSegmentSize) / segmentSize + 0.5f));
    int topGridY = int(floorf((worldLocation.y + halfSegmentSize) / segmentSize + 0.5f));
    for (int gx = rightGridX - 1; gx <= rightGridX; ++gx) {
      for (int gy = topGridY - 1; gy <= topGridY; ++gy) {
        adjacent[adjacentCount] = trackGrid.get(gx, gy);
        if (adjacent[adjacentCount]) {
          ++adjacentCount;
        }
      }
    }
  } else if (onEdgeX) {
    // Left or right edge.
    int rightGridX = int(floorf((worldLocation.x + halfSegmentSize) / segmentSize + 0.5f));
    adjacent[adjacentCount] = trackGrid.get(rightGridX - 1, gridY);
    if (adjacent[adjacentCount]) {
      ++adjacentCount;
    }
    adjacent[adjacentCount] = trackGrid.get(rightGridX, gridY);
    if (adjacent[adjacentCount]) {
      ++adjacentCount;
    }
  } else if (onEdgeY) {
    // Top or bottom edge.
    int topGridY = int(floorf((worldLocation.y + halfSegmentSize) / segmentSize + 0.5f));
    adjacent[adjacentCount] = trackGrid.get(gridX, topGridY - 1);
    if (adjacent[adjacentCount]) {
      ++adjacentCount;
    }
    adjacent[adjacentCount] = trackGrid.get(gridX, topGridY);
    if (adjacent[adjacentCount]) {
      ++adjacentCount;
    }
  } else {
    // Middle.
    adjacent[adjacentCount] = trackGrid.get(gridX, gridY);
    if (adjacent[adjacentCount]) {
      ++adjacentCount;
    }
  }
  return adjacentCount;
}

bool
trackGridFindClosestOnTrackPoint(FLTrackGrid& trackGrid,
                                 CGPoint worldLocation,
                                 int gridSearchDistance, CGFloat progressPrecision,
                                 CGFloat *onTrackDistance, CGPoint *onTrackPoint, CGFloat *onTrackRotation,
                                 FLSegmentNode **onTrackSegment, int *onTrackPathId, CGFloat *onTrackProgress)
{
  int gridX;
  int gridY;
  trackGrid.convert(worldLocation, &gridX, &gridY);

  CGFloat segmentSize = trackGrid.segmentSize();

  // Do a less-precise search among all nearby segments.
  CGFloat closestSegmentPrecision = progressPrecision * 10.0f;
  FLSegmentNode *closestSegmentNode = nil;
  CGFloat closestDistance;
  for (int gx = gridX - gridSearchDistance; gx <= gridX + gridSearchDistance; ++gx) {
    for (int gy = gridY - gridSearchDistance; gy <= gridY + gridSearchDistance; ++gy) {
      FLSegmentNode *segmentNode = trackGrid.get(gx, gy);
      if (!segmentNode) {
        continue;
      }
      CGFloat distance = [segmentNode getClosestOnTrackPoint:nil rotation:nil path:nil progress:nil
                                            forOffTrackPoint:worldLocation scale:segmentSize precision:closestSegmentPrecision];
      if (!closestSegmentNode || distance < closestDistance) {
        closestSegmentNode = segmentNode;
        closestDistance = distance;
      }
    }
  }
  if (!closestSegmentNode) {
    return NO;
  }

  // Do a precise search on the closest segment.
  *onTrackSegment = closestSegmentNode;
  *onTrackDistance = [closestSegmentNode getClosestOnTrackPoint:onTrackPoint rotation:onTrackRotation path:onTrackPathId progress:onTrackProgress
                                               forOffTrackPoint:worldLocation scale:segmentSize precision:progressPrecision];

  return YES;
}

bool
trackGridFindConnecting(FLTrackGrid& trackGrid,
                        FLSegmentNode *startSegmentNode, int startPathId, CGFloat startProgress,
                        FLSegmentNode **connectingSegmentNode, int *connectingPathId, CGFloat *connectingProgress)
{
  // note: The paths know statically whether or not they connect at a particular corner, and what their
  // tangent is at that point.  However, that would require extending their interface (as well as adding
  // more compile-time information to the file), and it appeals to me to figure out what we need to know
  // at runtime using getPoint() and getTangent() and testing all endpoints.  My instinct is that it won't
  // be much slower.

  CGFloat segmentSize = trackGrid.segmentSize();
  CGPoint cornerPoint;
  CGFloat startRotation;
  [startSegmentNode getPoint:&cornerPoint rotation:&startRotation forPath:startPathId progress:startProgress scale:segmentSize];

  CGFloat halfSegmentSize = segmentSize / 2.0f;
  int rightGridX = int(floorf((cornerPoint.x + halfSegmentSize) / segmentSize + 0.5f));
  int topGridY = int(floorf((cornerPoint.y + halfSegmentSize) / segmentSize + 0.5f));

  for (int gx = rightGridX - 1; gx <= rightGridX; ++gx) {
    for (int gy = topGridY - 1; gy <= topGridY; ++gy) {

      FLSegmentNode *segmentNode = trackGrid.get(gx, gy);
      if (!segmentNode || segmentNode == startSegmentNode) {
        continue;
      }

      if ([segmentNode getPath:connectingPathId progress:connectingProgress forEndPoint:cornerPoint rotation:startRotation scale:segmentSize]) {
        *connectingSegmentNode = segmentNode;
        return true;
      }
    }
  }
  return false;
}

/*
@implementation FLTrackGridWrapper
{
  const FLTrackGrid *_rawTrackGrid;
  unique_ptr<FLTrackGrid> _trackGrid;
}

- (id)initWithTrackGrid:(std::unique_ptr<FLTrackGrid> &)trackGrid
{
  self = [super init];
  if (self) {
    _trackGrid = std::move(trackGrid);
    _rawTrackGrid = _trackGrid.get();
  }
  return self;
}

- (id)initWithRawTrackGrid:(const FLTrackGrid *)rawTrackGrid
{
  self = [super init];
  if (self) {
    _rawTrackGrid = rawTrackGrid;
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self) {
    HERE HERE HERE
    segmentSize
    then...i guess a list of nodes in the quadtree.  maybe get quadtree to pack itself into a byte array?
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
}

- (unique_ptr<FLTrackGrid>&)trackGrid
{
  return _trackGrid;
}

- (const FLTrackGrid *)rawTrackGrid
{
  if (_trackGrid) {
    [NSException raise:@"FLTrackGridWrapperManaged" format:@"Raw pointer access not allowed when wrapper initialized with a managed pointer."];
  }
  return _rawTrackGrid;
}

@end
*/
