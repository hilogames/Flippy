//
//  FLAppDelegate.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLAppDelegate.h"

#import "FLViewController.h"

@implementation FLAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  // noob: Placeholder to see where the green shows through.
  self.window.backgroundColor = [UIColor greenColor];

  FLViewController *rvc = [[FLViewController alloc] init];
  self.window.rootViewController = rvc;
  
  [self.window makeKeyAndVisible];
  return YES;
}
							
@end
