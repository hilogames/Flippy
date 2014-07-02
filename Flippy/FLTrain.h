//
//  FLTrain.h
//  Flippy
//
//  Created by Karl Voskuil on 2/13/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#include <memory>
#import <SpriteKit/SpriteKit.h>

class FLTrackGrid;
@class FLSegmentNode;
@protocol FLTrainDelegate;

/**
 * A train running on a track grid.
 *
 * noob: I could either subclass SKSpriteNode, and then have a documented relationship with
 * the owner, or else subclass NSObject and have an explicit interface with the owner.
 * Though the latter seems like better design, for now I'm going with the former; it seems
 * to me that it's a common pattern, and even comes with a basic convention already in place
 * (e.g. the owner doesn't mess with this node's children).  That said, for my other subclassed
 * nodes, the owner can choose scale and position and rotation and such; this one might be
 * a little more restrictive, since I'm including all that logic inside here.  So, all
 * inherited properties of this class are currently considered read-only for the owner except:
 *
 *    . parent
 *    . scale
 *    . zPosition
 */

FOUNDATION_EXPORT const int FLTrainDirectionForward;
FOUNDATION_EXPORT const int FLTrainDirectionReverse;

@interface FLTrain : SKSpriteNode <NSCoding>

@property (nonatomic, weak) id<FLTrainDelegate> delegate;

@property (nonatomic) BOOL running;

- (id)initWithTrackGrid:(std::shared_ptr<FLTrackGrid>&)trackGrid;

- (void)resetTrackGrid:(std::shared_ptr<FLTrackGrid>&)trackGrid;

- (void)update:(CFTimeInterval)elapsedTime simulationSpeed:(int)simulationSpeed;

- (BOOL)moveToSegment:(FLSegmentNode *)segmentNode pathId:(int)pathId progress:(CGFloat)progress direction:(int)direction;

/**
 * Searches the track grid for a nearby segment with the closest on-track point to the passed point.
 *
 * @param The point for which the search is performed, in world coordinates.
 *
 * @param The "radius" of segments (adjacent to the segment containing the passed point) searched.
 *        More precisely: A square of segments are checked; the square is centered on the segment
 *        that contains the passed point; the square's edge length is (2 * gridSearchDistance) + 1.
 *
 * @param The precision used for searching for points along the track paths of searched segments.
 *        The measurement unit is "progress", since that's the unit used to measure segment paths.
 *        For visual purposes, the caller might choose to pass "progress per pixel": Under normal
 *        circumstances that will be a straight track segment progress length (1.0) divided by the
 *        pixels per (basic) segment edge (_trackGrid->segmentSize()) scaled by current worldScale.
 */
- (BOOL)moveToClosestOnTrackLocationForLocation:(CGPoint)worldLocation gridSearchDistance:(int)gridSearchDistance progressPrecision:(CGFloat)progressPrecision;

@end

@protocol FLTrainDelegate

- (void)train:(FLTrain *)train didSwitchSegment:(FLSegmentNode *)segmentNode toPathId:(int)pathId;

- (void)train:(FLTrain *)train stoppedAtSegment:(FLSegmentNode *)segmentNode;

- (void)train:(FLTrain *)train crashedAtSegment:(FLSegmentNode *)segmentNode;

@end
