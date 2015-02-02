//
//  FLAppDelegate.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo Games. All rights reserved.
//

#import "FLAppDelegate.h"

#import <AVFoundation/AVFoundation.h>
#import <SpriteKit/SpriteKit.h>
#import "FLViewController.h"

@implementation FLAppDelegate
{
  FLViewController *_flViewController;
  BOOL _resignActiveDidPauseSKView;
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  AVAudioSession *sharedSession = [AVAudioSession sharedInstance];
  [sharedSession setCategory:AVAudioSessionCategoryAmbient error:nil];
  [sharedSession setMode:AVAudioSessionModeDefault error:nil];
  // commented out: This line was suggested along with the above code for allowing background music to
  // continue during app execution, but it seems to have no effect.  For a while it seemed that commenting
  // it out was helping with the audio crashes described below, and though ultimately it doesn't really
  // make a difference there either, I'm just leaving it commented out until it proves useful.
  //[sharedSession setActive:YES error:nil];

  // note: A few StackOverflow questions and answers suggest that there is a problem with AVAudioSession crashes
  // on backgrounding a SpriteKit app.  I can reproduce in two different ways:
  //
  //  1) If I explicitly call [[AVAudioSession sharedSession] setActive:YES error:nil] during startup,
  //     as suggested as a solution to other problems (e.g. allowing background audio to continue when
  //     game starts, see code above), then I get a crash when doing this: play game audio; home button;
  //     play game audio; home button; (slight pause); crash.  Only on real device (iPhone 5s), not on
  //     simulator.
  //
  //  2) If I leave out any explicit calls to activate the shared session, then I can only cause the crash
  //     with this: play game audio; sleep button; play game audio; sleep button; crash.
  //
  // It is suggested that the root problem is that the audio session may not be active when the app is
  // backgrounded, and that SpriteKit doesn't do this maintenance for you.  So then the solution would be
  // to deactivate and reactivate the audio along with app events.  This StackOverflow question seems to
  // be at the center of the discussion:
  //
  //   http://stackoverflow.com/q/18976813
  //
  // Deactivating and reactivating at willResignActive, didEnterBackground, and willEnterForeground do
  // indeed prevent both crashes for me.  As of iOS8, they introduce a new error:
  //
  //   "Deactivating an audio session that has running I/O. All I/O should be stopped or
  //    paused prior to deactivating the audio session."
  //
  // If I ignore the error, then every other time I activate the app, the audio will refuse to play.
  // Well, okay, fine, that's better than a crash.
  //
  // One quick modification before continuing: The hypothesis is that the app must not go into the
  // background with active audio, so I don't see why I should deactivate it on willResignActive.
  // If I do it on willResignActive/didBecomeActive vs. didEnterBackground/willEnterForeground,
  // both prevent the crashes, but I get fewer error messages if I use the backgrounding ones, of
  // course.  Maybe that's moot once the error messages are fixed, but for now I'll only bother
  // messing with audio on actual backgrounding/foregrounding events.
  //
  // So, how to avoid the error?  Some people on StackOverflow just need to pause their own
  // explicitly-owned AVAudioPlayers, but what we're trying to do is stop SpriteKit from its private
  // use of AVAudioSession.  There are a number of (competing?) solutions:
  //
  //  . Pause the SKView before making the audio inactive: http://stackoverflow.com/a/22418467
  //  . Remove the whole view (because it doesn't really pause): http://stackoverflow.com/a/19086786
  //  . Tear down all SKViews (because they don't really pause): http://stackoverflow.com/a/23107913
  //  . Try repeatedly (de)activating the audio until it works:  http://stackoverflow.com/a/21349677
  //  . Don't use SpriteKit to play sounds, but direct AVAudioSession: http://stackoverflow.com/a/23580638
  //    (There's some more maybe-better code which can be found on this topic, with searching.)
  //  . Similar: http://iknowsomething.com/ios-sdk-spritekit-sound/
  //
  // Meanwhile! When SpriteKit audio is interrupted, e.g. by phone call or timer, it shows a similar
  // effect: the audio refuses to play until I background-foreground-cycle the app.
  //
  // I tried repeated (de)activating, but it didn't help.  I didn't observe severe memory leaking
  // during the time when sounds weren't playing (which was a concern of one poster, I think).
  //
  // I call this situation tolerable for now, and it seems the bug is in SpriteKit's domain.
  
  return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.backgroundColor = [UIColor whiteColor];

#if TARGET_IPHONE_SIMULATOR
  NSLog(@"Simulator: %@",
        [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject]);
#endif

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
  return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
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
  // Pause SpriteKit scene.  Suggested by:
  //
  //   http://stackoverflow.com/questions/19014012/sprite-kit-the-right-way-to-multitask
  //
  // (Though I have not yet had troubles leading to this as a solution.)
  if (!_flViewController.skView.paused) {
    _resignActiveDidPauseSKView = YES;
    _flViewController.skView.paused = YES;
  }

  // commented out: See notes in applicationWillFinishLoadingWithOptions:.
  //[[AVAudioSession sharedInstance] setActive:NO error:nil];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  // commented out: See notes in applicationWillFinishLoadingWithOptions:.
  //[[AVAudioSession sharedInstance] setActive:YES error:nil];

  // note: See notes in applicationWillResignActive:.
  if (_resignActiveDidPauseSKView) {
    _flViewController.skView.paused = NO;
    _resignActiveDidPauseSKView = NO;
  }
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  // commented in for now: See notes in applicationWillFinishLoadingWithOptions:.
  [[AVAudioSession sharedInstance] setActive:NO error:nil];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  // commented in for now: See notes in applicationWillFinishLoadingWithOptions:.
  [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
  // note: Handled in view controllers, view, and scenes through UIApplicationDidReceiveMemoryWarningNotification.
  // But keeping this here as a reminder to keep thinking of other ways to free up memory.
}

@end
