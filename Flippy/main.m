//
//  main.m
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "FLAppDelegate.h"

int main(int argc, char * argv[])
{
  @try {
    @autoreleasepool {
      return UIApplicationMain(argc, argv, nil, NSStringFromClass([FLAppDelegate class]));
    }
  } @catch (NSException *e) {
    NSLog(@"Uncaught exception in main: %@", e);
  }
}
