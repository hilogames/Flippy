//
//  FLConstants.m
//  Flippy
//
//  Created by Karl Voskuil on 7/10/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import "FLConstants.h"

#import <HLSpriteKit/HLLabelButtonNode.h>

static NSArray *_challengeLevels = nil;

static NSString * const FLChallengeLevelsInfoKeyString[5] = {
  @"title",
  @"goal-short",
  @"goal-long",
  @"goal-values",
  @"victory-user-unlocks",
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

id
FLChallengeLevelsInfo(int gameLevel, FLChallengeLevelsInfoKey infoKey)
{
  // note: Right now the info is a pretty flat dictionary of key-value pairs.
  // If it gets more complex, though -- in particular, with the need for more constants
  // than just top-level keys -- then probably should view the level info as an object
  // with a defined interface (e.g. separate methods to get each property, or perhaps
  // even some kind of class wrapper).
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

static NSMutableDictionary *_userUnlocks = nil;

static void
FLUserUnlocksInit()
{
  NSDictionary *userKeysUnlocked = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"FLUserUnlocks"];
  if (userKeysUnlocked) {
    _userUnlocks = [NSMutableDictionary dictionaryWithDictionary:userKeysUnlocked];
  } else {
    _userUnlocks = [NSMutableDictionary dictionary];
  }
}

BOOL
FLUserUnlocksUnlocked(NSString *unlockKey)
{
  if (!_userUnlocks) {
    FLUserUnlocksInit();
  }
  NSNumber *value = [_userUnlocks objectForKey:unlockKey];
  return (value && [value boolValue]);
}

void
FLUserUnlocksUnlock(NSArray *unlockKeys)
{
  if (!_userUnlocks) {
    FLUserUnlocksInit();
  }
  for (NSString *unlockKey in unlockKeys) {
    [_userUnlocks setValue:[NSNumber numberWithBool:YES] forKey:unlockKey];
  }
  [[NSUserDefaults standardUserDefaults] setObject:_userUnlocks forKey:@"FLUserUnlocks"];
}

void
FLUserUnlocksReset()
{
  _userUnlocks = [NSMutableDictionary dictionary];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"FLUserUnlocks"];
}

NSString *FLInterfaceFontName = @"Courier";

HLLabelButtonNode *
FLInterfaceLabelButton()
{
  HLLabelButtonNode *labelButton = [[HLLabelButtonNode alloc] initWithImageNamed:@"menu-button"];
  labelButton.centerRect = CGRectMake(0.3333333f, 0.3333333f, 0.3333333f, 0.3333333f);
  return labelButton;
}
