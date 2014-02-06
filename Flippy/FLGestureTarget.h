//
//  FLGestureTarget.h
//  Flippy
//
//  Created by Karl Voskuil on 2/4/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

/**
 * A generic target for UIGestureRecognizers.
 *
 * Use case: A single delegate for a bunch of gesture recognizers creates and maintains the recognizers,
 * but wants to forward the gesture to different targets based on where the gesture starts.  An example
 * might be an SKScene, which has only a single view (and hence only a single set of gesture recognizers),
 * but perhaps many different SKNode components within the scene, like a world, a character, or a toolbar.
 * The SKScene chooses from among its FLGestureTarget components, and adds target/action pairs to the
 * gesture recognizer as appropriate.
 */

#import <Foundation/Foundation.h>

@protocol FLGestureTarget <NSObject>

@optional

- (BOOL)shouldHandleGesture:(UIGestureRecognizer *)gestureRecognizer firstTouch:(UITouch *)touch;

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer;

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer;

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer;

@end
