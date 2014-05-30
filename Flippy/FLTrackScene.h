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

+ (FLTrackScene *)load:(NSString *)saveName;

- (void)save:(NSString *)saveName;

/**
 * Presents a node modally above the current scene, pausing the scene and disabling
 * other interaction.  See documentation in HLGestureScene; this is intended to be a
 * slightly altered way of achieving the same functionality in a non-HLGestureScene.
 */
- (void)presentModalNode:(SKNode <HLGestureTarget> *)node;

/**
 * Dismisses the node currently presented by presentModalNode (if any).  See
 * documentation in HLGestureScene; this is intended to be a slightly altered way of
 * achieving the same functionality in a non-HLGestureScene.
 */
- (void)dismissModalNode;

@end

@protocol FLTrackSceneDelegate <NSObject>

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene;

@end
