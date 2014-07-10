//
//  FLConstants.m
//  Flippy
//
//  Created by Karl Voskuil on 7/10/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import "FLConstants.h"

static NSArray *_challengeLevels = nil;

static NSString * const FLChallengeLevelsInfoKeyString[3] = {
  @"title",
  @"goal-short",
  @"goal-long",
};

static void
FLChallangeLevelsInit()
{
  NSString *path = [[NSBundle mainBundle] pathForResource:@"ChallengeLevels" ofType:@"plist"];
  NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
  _challengeLevels = (NSArray *)[NSPropertyListSerialization propertyListFromData:data
                                                                 mutabilityOption:NSPropertyListImmutable
                                                                           format:NULL
                                                                 errorDescription:NULL];
}

int
FLChallengeLevelsCount()
{
  if (!_challengeLevels) {
    FLChallangeLevelsInit();
  }
  return (int)[_challengeLevels count];
}

NSString *
FLChallengeLevelsInfo(int gameLevel, FLChallengeLevelsInfoKey infoKey)
{
  if (!_challengeLevels) {
    FLChallangeLevelsInit();
  }
  if (gameLevel < 0 || gameLevel >= (int)[_challengeLevels count]) {
    [NSException raise:@"FLChallengeLevelsLevelInvalid" format:@"Invalid level for challenge game."];
  }
  NSDictionary *challengeLevel = (NSDictionary *)[_challengeLevels objectAtIndex:(NSUInteger)gameLevel];
  NSString *infoKeyString = FLChallengeLevelsInfoKeyString[(int)infoKey];
  return [challengeLevel objectForKey:infoKeyString];
}
