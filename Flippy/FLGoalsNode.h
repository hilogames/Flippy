//
//  FLGoalsNode.h
//  Flippy
//
//  Created by Karl Voskuil on 10/31/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
//

#import "HLSpriteKit.h"

#import "FLConstants.h"

typedef NS_ENUM(NSInteger, FLGoalsNodeRecordFormat) {
  FLGoalsNodeRecordFormatInteger,
  FLGoalsNodeRecordFormatHourMinuteSecond,
};

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
                     recordOldValues:(NSArray *)recordOldValues
                  recordValueFormats:(NSArray *)recordValueFormats;

- (void)layout;

- (void)reveal;

@end

@protocol FLGoalsNodeDelegate <NSObject>

- (void)goalsNode:(FLGoalsNode *)goalsNode didDismissWithNextLevel:(BOOL)nextLevel;

@end
