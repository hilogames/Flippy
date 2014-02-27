//
//  FLTrackGrid.h
//  Flippy
//
//  Created by Karl Voskuil on 2/27/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#ifndef __Flippy__FLTrackGrid__
#define __Flippy__FLTrackGrid__

#include <iostream>

#import "FLSegmentNode.h"
#include "QuadTree.h"

/**
 * Represents square segments that occupy a two-dimensional world.
 * The track grid deals in integer grid coordinates, and, given a
 * segment edge size, floating point world coordinates.  (The grid and
 * world share the same origin.)
 *
 * note: Consider a generic implementation that in place of "track"
 * and "segment" and "world" uses terms like "field" or "square" or
 * "cell".
 *
 * Alternate Implementation
 *
 * The current implementation models a track composed of square
 * pieces.  In particular, it's good for an interface where you place
 * square track pieces into the grid, and then rotate them around as
 * necessary so that their corners hook together.
 *
 * An alternate model would support the actual mechanics and
 * computations a little better -- though it might lead to a different
 * interface paradigm, also, and so might involve a pretty serious
 * rewrite.  Like this:
 *
 *  . The model tracks vertices/intersections in a quadtree square
 *    grid.  (Or on a hex field, or whatever.)
 *
 *  . Each vertex contains a few edges which link the vertex to any of
 *    the eight surrounding vertices.  (Or to any arbitrary vertex on
 *    the grid, though I have a feeling it will always be better to do
 *    it in little pieces.)  The edge is linked from the other vertex,
 *    too.
 *
 *  . The edge knows its end point vertices (either pointers back to
 *    the two vertices, or grid coordinates, or perhaps even a single
 *    vertex plus a direction).  For each end point it also knows the
 *    tangent -- probably just in four or eight or twelve discrete
 *    compass points, so probably stored as an integer direction
 *    (e.g. rotationQuarters).
 *
 *  . When adding a new edge to a vertex, then, it would be pretty
 *    easy to detect if any other existing edges had the same tangent,
 *    which would mean they (as a group) would need a switch; and it
 *    would be easy to detect if any other existing edges had an
 *    opposite tangent, which would mean they connect.
 *
 *  . Furthermore, it would be easy to lookup/generate the
 *    corresponding cubic Bezier curve to use as a continuous path for
 *    the edge, since the first and fourth control points would be the
 *    vertices, and the middle control points could be easily
 *    generated to produce the correct tangents.  If the number of
 *    connectable vertices and discrete tangents were limited, then
 *    these paths would be fairly easily enumerable: straight, curve,
 *    S-curve, question mark curve, etc.
 *
 *  . For the graphics, each path would have a graphic, and then a
 *    switch could be positioned dynamically where needed, and certain
 *    path combinations would be replaced by a compound graphic -- or
 *    maybe the intersection would be drawn over top of the two paths
 *    in the right location and rotation, either a right angle
 *    intersection, 45 degree intersection, or whatever.
 *
 *  . In the interface, track would be added by drawing connections
 *    between vertices.  Connections in the middle of the drawing
 *    would have their tangents determined by the outer connections.
 *    Endpoints of the drawn line would not necessarily know how to
 *    shape themselves, but could be patched up by selection edits.
 *    Track edges/curves/unions (i.e. pieces of track) could be
 *    selected and dragged around, possibly by using SpriteKits hit
 *    test abilities (since the determination of edge selection has
 *    more to do with its visible sprite than its grid position).
 *
 * Anyway, I think I'm going to pass on this for now, even though it
 * would be pretty clearly awesome.
 */

class FLTrackGrid
{
public:

  inline static void convert(CGPoint worldLocation, CGFloat segmentSize, int *gridX, int *gridY) {
    *gridX = int(floorf(worldLocation.x / segmentSize + 0.5f));
    *gridY = int(floorf(worldLocation.y / segmentSize + 0.5f));
  }

  inline static CGPoint convert(int gridX, int gridY, CGFloat segmentSize) {
    return CGPointMake(gridX * segmentSize, gridY * segmentSize);
  }

  FLTrackGrid(CGFloat segmentSize) : segmentSize_(segmentSize) {}

  FLSegmentNode *get(int gridX, int gridY) const { return grid_.get(gridX, gridY, nil); }

  void set(int gridX, int gridY, FLSegmentNode *value) { grid_[{ gridX, gridY }] = value; }

  void erase(int gridX, int gridY) { grid_.erase(gridX, gridY); }

  CGFloat segmentSize() { return segmentSize_; }

  void convert(CGPoint worldLocation, int *gridX, int *gridY) {
    return FLTrackGrid::convert(worldLocation, segmentSize_, gridX, gridY);
  }

  CGPoint convert(int gridX, int gridY) {
    return FLTrackGrid::convert(gridX, gridY, segmentSize_);
  }

private:

  HLCommon::QuadTree<FLSegmentNode *> grid_;
  CGFloat segmentSize_;
};

/**
 * Convenience method for converting a world location to grid coordinates and then
 * calling get().  Useful when the caller has no use for the grid coordinates.
 */
inline FLSegmentNode *
trackGridConvertGet(FLTrackGrid& trackGrid, CGPoint worldLocation)
{
  int gridX;
  int gridY;
  trackGrid.convert(worldLocation, &gridX, &gridY);
  return trackGrid.get(gridX, gridY);
}

/**
 * Convenience method for converting a world location to grid coordinates and then
 * calling set().  Useful when the caller has no use for the grid coordinates.
 */
inline void
trackGridConvertSet(FLTrackGrid& trackGrid, CGPoint worldLocation, FLSegmentNode *segmentNode)
{
  int gridX;
  int gridY;
  trackGrid.convert(worldLocation, &gridX, &gridY);
  return trackGrid.set(gridX, gridY, segmentNode);
}

/**
 * Convenience method for converting a world location to grid coordinates and then
 * calling erase().  Useful when the caller has no use for the grid coordinates.
 */
inline void
trackGridConvertErase(FLTrackGrid& trackGrid, CGPoint worldLocation)
{
  int gridX;
  int gridY;
  trackGrid.convert(worldLocation, &gridX, &gridY);
  trackGrid.erase(gridX, gridY);
}

/**
 * Convenience method for returning any segments "adjacent" to a provided point.
 * To be precise:
 *
 *   . If the point is (very close to) a corner of the segment, then up to four
 *     segments that share that corner on the grid are returned.
 *
 *   . Otherwise, if the point is (very close to) an edge of the segment, then
 *     up to two segments that share that edge on the grid are returned.
 *
 *   . Otherwise, the segment containing the point (if set in the grid) is
 *     returned.
 *
 * The maximum number of segments returned is four, represented by the constant
 * FLTrackGridAdjacentMax.
 */
FOUNDATION_EXPORT const size_t FLTrackGridAdjacentMax;
size_t
trackGridFindAdjacent(FLTrackGrid& trackGrid, CGPoint worldLocation, __strong FLSegmentNode *adjacent[]);

/**
 * Convenience method for finding the closest on-track point from among segments
 * nearby the passed world location (within a square defined by gridSearchDistance).
 * The point returned might be limited in precision by the passed progressPrecision
 * (if the closest path being searched rather than solved for closeness, e.g. for
 * some Bezier curve paths).  Returns false if no point could be found within the
 * search area.
 *
 * note: In future, might be a nice feature to accept a search radius in world
 * distance rather than a gridSearchDistance defining a square.
 */
bool
trackGridFindClosestOnTrackPoint(FLTrackGrid& trackGrid,
                                 CGPoint worldLocation,
                                 int gridSearchDistance, CGFloat progressPrecision,
                                 CGFloat *onTrackDistance, CGPoint *onTrackPoint, CGFloat *onTrackRotation,
                                 FLSegmentNode **onTrackSegment, int *onTrackPathId, CGFloat *onTrackProgress);

/**
 * Convenience method for finding segments that connect to a certain progress
 * on a certain path on a certain segment.  The connecting segment must have
 * a path containing the same (or nearly the same) point; the tangent of the
 * two intersecting paths at that point must be the same (or exactly opposite
 * in case the paths progress in separate directions).  Returns false if no
 * connecting segment was found.  (It is assumed that the track will be managed
 * in such a way that there won't be more than one connecting path, but if there
 * is, then only the first one found will be returned.)
 *
 * note: Currently hardcoded to assume that paths only connect at endpoints
 * of the path (i.e. where progress is either 0.0 or 1.0), and also that all
 * path endpoints occur at segment corners.  (In other words: Don't bother
 * to call this function unless you pass startProgress as either 0.0 or 1.0.)
 */
bool
trackGridFindConnecting(FLTrackGrid& trackGrid,
                        FLSegmentNode *startSegmentNode, int startPathId, CGFloat startProgress,
                        FLSegmentNode **connectingSegmentNode, int *connectingPathId, CGFloat *connectingProgress);

#endif /* defined(__Flippy__FLTrackGrid__) */
