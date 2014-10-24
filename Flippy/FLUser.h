//
//  FLUser.h
//  Flippy
//
//  Created by Karl Voskuil on 10/23/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Checks a user unlock; returns YES if the unlockKey has been unlocked by FLUserUnlocksUnlock()
 * since the time user unlocks were reset (or the application data was cleared).
 *
 * "User unlocks" are global flags used to allow access to new parts of the application.  They
 * persist on a device through multiple invocations of the application.
 */
FOUNDATION_EXPORT BOOL FLUserUnlocksUnlocked(NSString *unlockKey);

FOUNDATION_EXPORT void FLUserUnlocksUnlock(NSArray *unlockKeys);

FOUNDATION_EXPORT void FLUserUnlocksResetAll();
FOUNDATION_EXPORT void FLUserUnlocksReset(NSString *unlockKey);

/**
 * Gets a user record, returning the value last set by FLUserRecordSet() since the last time
 * user records were reset (or the application data was cleared).
 *
 * Many records are recorded per-game-level; for convenience, the parameterization of gameLevel
 * is made part of the records interface here.
 *
 * "User records" are global values used to record user performance in the application.  They
 * persist on a device through multiple invocations of the application.
 */
FOUNDATION_EXPORT id FLUserRecordsGet(NSString *recordKey);
FOUNDATION_EXPORT id FLUserRecordsLevelGet(NSString *recordKey, int gameLevel);

FOUNDATION_EXPORT void FLUserRecordsSet(NSString *recordKey, id value);
FOUNDATION_EXPORT void FLUserRecordsLevelSet(NSString *recordKey, int gameLevel, id value);

FOUNDATION_EXPORT void FLUserRecordsResetAll();
