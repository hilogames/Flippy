//
//  FLConstants.h
//  Flippy
//
//  Created by Karl Voskuil on 7/10/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SpriteKit/SpriteKit.h>

@class HLLabelButtonNode;

typedef enum FLChallengeLevelsInfoKey {
  FLChallengeLevelsTitle = 0,
  FLChallengeLevelsGoalShort,
  FLChallengeLevelsGoalLong,
  FLChallengeLevelsGoalValues,
  FLChallengeLevelsVictoryUserUnlocks,
} FLChallengeLevelsInfoKey;

FOUNDATION_EXPORT int FLChallengeLevelsCount();

/**
 * Returns information about a level in a challenge game.  See
 * FLChallengeLevelsInfoKey for information available.
 */
FOUNDATION_EXPORT id FLChallengeLevelsInfo(int gameLevel, FLChallengeLevelsInfoKey infoKey);

FOUNDATION_EXPORT BOOL FLUserUnlocksUnlocked(NSString *unlockKey);

FOUNDATION_EXPORT void FLUserUnlocksUnlock(NSArray *unlockKeys);

FOUNDATION_EXPORT void FLUserUnlocksReset();

/**
 * The standard application font.
 */
FOUNDATION_EXPORT NSString *FLInterfaceFontName;

/**
 * Standard application colors.
 */
FOUNDATION_EXPORT SKColor *FLInterfaceColorDark();
FOUNDATION_EXPORT SKColor *FLInterfaceColorMedium();
FOUNDATION_EXPORT SKColor *FLInterfaceColorLight();
FOUNDATION_EXPORT SKColor *FLInterfaceColorGood();
FOUNDATION_EXPORT SKColor *FLInterfaceColorMaybe();
FOUNDATION_EXPORT SKColor *FLInterfaceColorBad();

/**
 * Creates and returns an HLLabelButtonNode with a background used by
 * standard buttons in the application.
 */
FOUNDATION_EXPORT HLLabelButtonNode *FLInterfaceLabelButton();
