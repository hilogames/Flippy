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
 * Overrides the parent implementation to stop the simulation and provide zPosition values.
 * The zPosition values passed as parameters are ignored.
 */
- (void)presentModalNode:(SKNode *)node zPositionMin:(CGFloat)zPositionMin zPositionMax:(CGFloat)zPositionMax;

@end

@protocol FLTrackSceneDelegate <NSObject>

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene;

@end
