//
//  FLConstants.h
//  Flippy
//
//  Created by Karl Voskuil on 7/10/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
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
  FLChallengeLevelsRecordDefaults,
};

FOUNDATION_EXPORT int FLChallengeLevelsCount(void);

/**
 * Returns information about a level in a challenge game.  See
 * FLChallengeLevelsInfoKey for information available.
 */
FOUNDATION_EXPORT id FLChallengeLevelsInfo(int gameLevel, FLChallengeLevelsInfoKey infoKey);

/**
 * The standard application font.
 */
FOUNDATION_EXPORT NSString *FLInterfaceFontName;

/**
 * The bold application font.
 */
FOUNDATION_EXPORT NSString *FLInterfaceBoldFontName;

/**
 * Standard application colors.
 */
FOUNDATION_EXPORT SKColor *FLInterfaceColorDark(void);
FOUNDATION_EXPORT SKColor *FLInterfaceColorMedium(void);
FOUNDATION_EXPORT SKColor *FLInterfaceColorLight(void);
FOUNDATION_EXPORT SKColor *FLInterfaceColorSunny(void);
FOUNDATION_EXPORT SKColor *FLInterfaceColorGood(void);
FOUNDATION_EXPORT SKColor *FLInterfaceColorMaybe(void);
FOUNDATION_EXPORT SKColor *FLInterfaceColorBad(void);

/**
 * Creates and returns an HLLabelButtonNode with a background, size, font,
 * font color, and font size used by standard buttons in the application.
 *
 * note: This should be split into more-specific methods if callers so
 * desire, e.g. one for returning buttons of a standard background, and
 * another for also configuring sizes and fonts.  For now, all callers
 * want the full package.
 */
FOUNDATION_EXPORT HLLabelButtonNode *FLInterfaceLabelButton(void);

/**
 * Interface standards for dealing with DSMultilineLabelNodes.
 */
FOUNDATION_EXPORT const CGFloat FLDSMultilineLabelParagraphWidthReadableMax;
// note: I've seen strings display wider than the paragraph width specified;
// so pad it a little.
FOUNDATION_EXPORT const CGFloat FLDSMultilineLabelParagraphWidthBugWorkaroundPad;

/**
 * Game information.
 */

typedef NS_ENUM(NSInteger, FLGameType) {
  FLGameTypeChallenge,
  FLGameTypeSandbox,
};

FOUNDATION_EXPORT NSString * const FLGameTypeChallengeTag;
FOUNDATION_EXPORT NSString *FLGameTypeChallengeTitle(void);
FOUNDATION_EXPORT NSString * const FLGameTypeSandboxTag;
FOUNDATION_EXPORT NSString *FLGameTypeSandboxTitle(void);
