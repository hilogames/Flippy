//
//  FLGoalsNode.h
//  Flippy
//
//  Created by Karl Voskuil on 10/31/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import <HLSpriteKit/HLSpriteKit.h>

#import "FLConstants.h"

@class FLTrackTruthTable;
@protocol FLGoalsNodeDelegate;

@interface FLGoalsNode : HLScrollNode

@property (nonatomic, weak) id <FLGoalsNodeDelegate> delegate;

@property (nonatomic, assign) CGSize sceneSize;

- (instancetype)initWithSceneSize:(CGSize)sceneSize
                         gameType:(FLGameType)gameType
                        gameLevel:(int)gameLevel;

- (void)createIntro;

- (BOOL)createTruthWithTrackTruthTable:(FLTrackTruthTable *)trackTruthTable;

- (void)createVictoryWithUnlockTexts:(NSArray *)unlockTexts
                         recordTexts:(NSArray *)recordTexts
                     recordNewValues:(NSArray *)recordNewValues
                     recordOldValues:(NSArray *)recordOldValues;

- (void)layout;

- (void)reveal;

@end

@protocol FLGoalsNodeDelegate <NSObject>

- (void)goalsNode:(FLGoalsNode *)goalsNode didDismissWithNextLevel:(BOOL)nextLevel;

@end
