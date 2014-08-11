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

typedef enum FLGameType {
  FLGameTypeChallenge,
  FLGameTypeSandbox,
} FLGameType;

FOUNDATION_EXPORT NSString * const FLGameTypeChallengeTag;
FOUNDATION_EXPORT NSString * const FLGameTypeChallengeTitle;
FOUNDATION_EXPORT NSString * const FLGameTypeSandboxTag;
FOUNDATION_EXPORT NSString * const FLGameTypeSandboxTitle;

@protocol FLTrackSceneDelegate;

@interface FLTrackScene : HLScene <NSCoding, UIAlertViewDelegate, UIGestureRecognizerDelegate, FLTrainDelegate>

@property (nonatomic, weak) id<FLTrackSceneDelegate> delegate;

@property (nonatomic, readonly) FLGameType gameType;
@property (nonatomic, readonly) int gameLevel;

- (id)initWithSize:(CGSize)size gameType:(FLGameType)gameType gameLevel:(int)gameLevel;

- (void)notifyGameIsNew;

- (size_t)segmentCount;

@end

@protocol FLTrackSceneDelegate <NSObject>

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene;

- (void)trackSceneDidTapNextLevelButton:(FLTrackScene *)trackScene;

@end
