//
//  FLConstants.h
//  Flippy
//
//  Created by Karl Voskuil on 7/10/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HLLabelButtonNode;

typedef enum FLChallengeLevelsInfoKey {
  FLChallengeLevelsTitle = 0,
  FLChallengeLevelsGoalShort,
  FLChallengeLevelsGoalLong,
  FLChallengeLevelsGoalValues
} FLChallengeLevelsInfoKey;

int FLChallengeLevelsCount();

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
 * Creates and returns an HLLabelButtonNode with a background used by
 * standard buttons in the application.
 */
FOUNDATION_EXPORT HLLabelButtonNode *FLInterfaceLabelButton();
