//
//  FLAppDelegate.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLAppDelegate.h"

#import <AVFoundation/AVFoundation.h>
#import "FLViewController.h"

@implementation FLAppDelegate
{
  FLViewController *_flViewController;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  // noob: Placeholder to see where the green shows through.
  self.window.backgroundColor = [UIColor greenColor];

  // note: Root view controller might already have been created by application
  // state restoration process.
  if (!_flViewController) {
    _flViewController = [[FLViewController alloc] init];
  }
  self.window.rootViewController = _flViewController;
  
  [self.window makeKeyAndVisible];
  return YES;
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
  NSLog(@"saving application state");
  return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
  NSLog(@"restoring application state");
  NSInteger version = [coder decodeIntegerForKey:@"version"];
  return (version == 1);
}

- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder
{
  [coder encodeInteger:1 forKey:@"version"];
}

- (UIViewController *)application:(UIApplication *)application viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
  NSString *lastComponent = [identifierComponents lastObject];
  if ([lastComponent isEqualToString:@"FLViewController"]) {
    _flViewController = [[FLViewController alloc] init];
    return _flViewController;
  }
  return nil;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
  // Make audio (used by SpriteKit) inactive.  Suggested by:
  //
  //   http://stackoverflow.com/questions/18976813/sprite-kit-playing-sound-leads-to-app-termination/19283721
  //
  // (Though I have not yet seen a crash.)
  [[AVAudioSession sharedInstance] setActive:NO error:nil];

  // Pause SpriteKit scene.  Suggested by:
  //
  //   http://stackoverflow.com/questions/19014012/sprite-kit-the-right-way-to-multitask
  //
  // (Though I have not yet had troubles leading to this as a solution.)
  _flViewController.skView.paused = YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  // note: See notes in applicationWillResignActive:.
  _flViewController.skView.paused = NO;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  // note: See notes in applicationWillResignActive:.
  [[AVAudioSession sharedInstance] setActive:NO error:nil];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  // note: See notes in applicationWillResignActive:.
  [[AVAudioSession sharedInstance] setActive:YES error:nil];
}
@end
