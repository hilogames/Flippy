//
//  FLTrackScene.h
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo Games. All rights reserved.
//

#import "HLGestureTarget.h"
#import "HLScene.h"
#import <SpriteKit/SpriteKit.h>

#import "FLConstants.h"
#import "FLGoalsNode.h"
#import "FLTrain.h"

@protocol FLTrackSceneDelegate;

@interface FLTrackScene : HLScene <NSCoding, UIAlertViewDelegate, UIGestureRecognizerDelegate, FLTrainDelegate, FLGoalsNodeDelegate>

@property (nonatomic, weak) id<FLTrackSceneDelegate> delegate;

@property (nonatomic, readonly) FLGameType gameType;
@property (nonatomic, readonly) int gameLevel;
@property (nonatomic, assign) BOOL gameIsNew;

- (instancetype)initWithSize:(CGSize)size gameType:(FLGameType)gameType gameLevel:(int)gameLevel NS_DESIGNATED_INITIALIZER;

// TODO: This is declared for the sake of the NS_DESIGNATED_INITIALIZER; I expected
// a superclass to do this for me.  Give it some time and then try to remove this
// declaration.
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

- (NSUInteger)segmentCount;
- (NSUInteger)regularSegmentCount;
- (NSUInteger)joinSegmentCount;

- (void)timerPause;
- (void)timerResume;
- (NSTimeInterval)timerGet;

@end

@protocol FLTrackSceneDelegate <NSObject>

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene;

- (void)trackSceneDidTapNextLevelButton:(FLTrackScene *)trackScene;

@end
