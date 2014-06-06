//
//  FLTrackScene.h
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <HLSpriteKit/HLGestureTarget.h>
#import <HLSpriteKit/HLScene.h>
#import <SpriteKit/SpriteKit.h>

#import "FLTrain.h"

@protocol FLTrackSceneDelegate;

@interface FLTrackScene : HLScene <NSCoding, UIAlertViewDelegate, UIGestureRecognizerDelegate, FLTrainDelegate>

@property (nonatomic, weak) id<FLTrackSceneDelegate> delegate;

/**
 * Presents a node modally above the current scene, pausing the scene and disabling
 * other interaction.  Overrides the HLScene implementation so that we can hook it
 * into our own gesture handler system.  As a consequence, if the node or any of its
 * children conform to HLGestureTarget, it will receive gestures via the HLGestureTarget.
 */
- (void)presentModalNode:(SKNode *)node zPositionMin:(CGFloat)zPositionMin zPositionMax:(CGFloat)zPositionMax;

/**
 * Dismisses the node currently presented by presentModalNode (if any).  Overrides
 * the HLScene implementation.
 */
- (void)dismissModalNode;

@end

@protocol FLTrackSceneDelegate <NSObject>

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene;

@end
