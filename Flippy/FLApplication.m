//
//  FLApplication.m
//  Flippy
//
//  Created by Karl Voskuil on 11/18/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
//

#import "FLApplication.h"

#import "FLUser.h"

@implementation FLApplication

+ (void)applicationReset
{
  FLUserUnlocksResetAll();
  FLUserRecordsResetAll();

  NSString *documentDirectoryPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *documentPaths = [fileManager contentsOfDirectoryAtPath:documentDirectoryPath error:NULL];
  for (NSString *documentPath in documentPaths) {
    [fileManager removeItemAtPath:[documentDirectoryPath stringByAppendingPathComponent:documentPath] error:NULL];
  }
}

@end
