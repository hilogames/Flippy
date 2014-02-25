//
//  FLTrain.h
//  Flippy
//
//  Created by Karl Voskuil on 2/13/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

#import "FLSegmentNode.h"
#include "QuadTree.h"

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

@interface FLTrain : SKSpriteNode

- (id)initWithTrackGrid:(std::shared_ptr<HLCommon::QuadTree<FLSegmentNode *>>&)trackGrid gridSize:(CGFloat)gridSize;

- (void)start;

- (void)stop;

- (void)update:(CFTimeInterval)currentTime;

- (BOOL)moveToClosestOnTrackLocationForLocation:(CGPoint)worldLocation;

@end
