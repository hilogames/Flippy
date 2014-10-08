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

typedef NS_ENUM(NSInteger, FLGameType) {
  FLGameTypeChallenge,
  FLGameTypeSandbox,
};

FOUNDATION_EXPORT NSString * const FLGameTypeChallengeTag;
FOUNDATION_EXPORT NSString * const FLGameTypeChallengeTitle;
FOUNDATION_EXPORT NSString * const FLGameTypeSandboxTag;
FOUNDATION_EXPORT NSString * const FLGameTypeSandboxTitle;

@protocol FLTrackSceneDelegate;

@interface FLTrackScene : HLScene <NSCoding, UIAlertViewDelegate, UIGestureRecognizerDelegate, FLTrainDelegate>

@property (nonatomic, weak) id<FLTrackSceneDelegate> delegate;

@property (nonatomic, readonly) FLGameType gameType;
@property (nonatomic, readonly) int gameLevel;
@property (nonatomic, assign) BOOL gameIsNew;

- (instancetype)initWithSize:(CGSize)size gameType:(FLGameType)gameType gameLevel:(int)gameLevel NS_DESIGNATED_INITIALIZER;

// TODO: This is declared for the sake of the NS_DESIGNATED_INITIALIZER; I expected
// a superclass to do this for me.  Give it some time and then try to remove this
// declaration.
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

- (size_t)segmentCount;

@end

@protocol FLTrackSceneDelegate <NSObject>

- (void)trackSceneDidTapMenuButton:(FLTrackScene *)trackScene;

- (void)trackSceneDidTapNextLevelButton:(FLTrackScene *)trackScene;

@end
