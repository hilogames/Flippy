//
//  FLConstants.h
//  Flippy
//
//  Created by Karl Voskuil on 7/10/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum FLChallengeLevelsInfoKey {
  FLChallengeLevelsTitle = 0,
  FLChallengeLevelsGoalShort,
  FLChallengeLevelsGoalLong,
  FLChallengeLevelsGoalValues
} FLChallengeLevelsInfoKey;

int
FLChallengeLevelsCount();

FOUNDATION_EXPORT
id
FLChallengeLevelsInfo(int gameLevel, FLChallengeLevelsInfoKey infoKey);
