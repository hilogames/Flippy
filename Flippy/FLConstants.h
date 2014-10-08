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

typedef NS_ENUM(NSInteger, FLChallengeLevelsInfoKey) {
  FLChallengeLevelsTitle = 0,
  FLChallengeLevelsGoalShort,
  FLChallengeLevelsGoalLong,
  FLChallengeLevelsGoalValues,
  FLChallengeLevelsVictoryUserUnlocks,
};

FOUNDATION_EXPORT int FLChallengeLevelsCount();

/**
 * Returns information about a level in a challenge game.  See
 * FLChallengeLevelsInfoKey for information available.
 */
FOUNDATION_EXPORT id FLChallengeLevelsInfo(int gameLevel, FLChallengeLevelsInfoKey infoKey);

FOUNDATION_EXPORT BOOL FLUserUnlocksUnlocked(NSString *unlockKey);

FOUNDATION_EXPORT void FLUserUnlocksUnlock(NSArray *unlockKeys);

FOUNDATION_EXPORT void FLUserUnlocksResetAll();
FOUNDATION_EXPORT void FLUserUnlocksReset(NSString *unlockKey);

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
 * Creates and returns an HLLabelButtonNode with a background, size, font,
 * font color, and font size used by standard buttons in the application.
 *
 * note: This should be split into more-specific methods if callers so
 * desire, e.g. one for returning buttons of a standard background, and
 * another for also configuring sizes and fonts.  For now, all callers
 * want the full package.
 */
FOUNDATION_EXPORT HLLabelButtonNode *FLInterfaceLabelButton();
