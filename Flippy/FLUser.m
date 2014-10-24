//
//  FLUser.m
//  Flippy
//
//  Created by Karl Voskuil on 10/23/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import "FLUser.h"

static NSMutableDictionary *_userUnlocks = nil;

static void
FLUserUnlocksInit()
{
  NSDictionary *userUnlocks = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"FLUserUnlocks"];
  if (userUnlocks) {
    _userUnlocks = [NSMutableDictionary dictionaryWithDictionary:userUnlocks];
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
  NSNumber *value = _userUnlocks[unlockKey];
  return (value && [value boolValue]);
}

void
FLUserUnlocksUnlock(NSArray *unlockKeys)
{
  if (!_userUnlocks) {
    FLUserUnlocksInit();
  }
  for (NSString *unlockKey in unlockKeys) {
    _userUnlocks[unlockKey] = @YES;
  }
  [[NSUserDefaults standardUserDefaults] setObject:_userUnlocks forKey:@"FLUserUnlocks"];
}

void
FLUserUnlocksResetAll()
{
  _userUnlocks = [NSMutableDictionary dictionary];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"FLUserUnlocks"];
}

void
FLUserUnlocksReset(NSString *unlockKey)
{
  [_userUnlocks removeObjectForKey:unlockKey];
  [[NSUserDefaults standardUserDefaults] setObject:_userUnlocks forKey:@"FLUserUnlocks"];
}

static NSMutableDictionary *_userRecords = nil;
static NSMutableDictionary *_userRecordsLevels = nil;

static void
FLUserRecordsInit()
{
  NSDictionary *userRecords = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"FLUserRecords"];
  if (userRecords) {
    _userRecords = [NSMutableDictionary dictionaryWithDictionary:userRecords];
  } else {
    _userRecords = [NSMutableDictionary dictionary];
  }
  NSDictionary *userRecordsLevels = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"FLUserRecordsLevels"];
  if (userRecordsLevels) {
    _userRecordsLevels = [NSMutableDictionary dictionaryWithDictionary:userRecordsLevels];
  } else {
    _userRecordsLevels = [NSMutableDictionary dictionary];
  }
}

id
FLUserRecordsGet(NSString *recordKey)
{
  if (!_userRecords) {
    FLUserRecordsInit();
  }
  return _userRecords[recordKey];
}

id
FLUserRecordsLevelGet(NSString *recordKey, int gameLevel)
{
  if (!_userRecordsLevels) {
    FLUserRecordsInit();
  }
  NSString *levelKey = [NSString stringWithFormat:@"%d", gameLevel];
  NSDictionary *userRecordsLevel = [_userRecordsLevels objectForKey:levelKey];
  if (!userRecordsLevel) {
    return nil;
  }
  return userRecordsLevel[recordKey];
}

void
FLUserRecordsSet(NSString *recordKey, id value)
{
  if (!_userRecords) {
    FLUserRecordsInit();
  }
  _userRecords[recordKey] = value;
  [[NSUserDefaults standardUserDefaults] setObject:_userRecords forKey:@"FLUserRecords"];
}

void
FLUserRecordsLevelSet(NSString *recordKey, int gameLevel, id value)
{
  if (!_userRecordsLevels) {
    FLUserRecordsInit();
  }
  NSString *levelKey = [NSString stringWithFormat:@"%d", gameLevel];
  NSDictionary *userRecordsLevel = [_userRecordsLevels objectForKey:levelKey];
  if (!userRecordsLevel) {
    userRecordsLevel = [NSMutableDictionary dictionaryWithObject:value forKey:recordKey];
    _userRecordsLevels[levelKey] = userRecordsLevel;
  } else {
    if (![userRecordsLevel isKindOfClass:[NSMutableDictionary class]]) {
      userRecordsLevel = [NSMutableDictionary dictionaryWithDictionary:userRecordsLevel];
    }
    [(NSMutableDictionary *)userRecordsLevel setObject:value forKey:recordKey];
  }
  [[NSUserDefaults standardUserDefaults] setObject:_userRecordsLevels forKey:@"FLUserRecordsLevels"];
}

void
FLUserRecordsResetAll()
{
  _userRecords = [NSMutableDictionary dictionary];
  _userRecordsLevels = [NSMutableDictionary dictionary];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"FLUserRecords"];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"FLUserRecordsLevels"];
}
