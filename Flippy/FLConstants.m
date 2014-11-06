//
//  FLConstants.m
//  Flippy
//
//  Created by Karl Voskuil on 7/10/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
//

#import "FLConstants.h"

#import <HLSpriteKit/HLLabelButtonNode.h>

static NSArray *_challengeLevels = nil;

static NSString * const FLChallengeLevelsInfoKeyString[6] = {
  @"title",
  @"goal-short",
  @"goal-long",
  @"goal-values",
  @"victory-user-unlocks",
  @"record-defaults",
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
  NSDictionary *challengeLevel = (NSDictionary *)_challengeLevels[(NSUInteger)gameLevel];
  NSString *infoKeyString = FLChallengeLevelsInfoKeyString[(NSInteger)infoKey];
  return challengeLevel[infoKeyString];
}

NSString *FLInterfaceFontName = @"Courier";

SKColor *
FLInterfaceColorDark()
{
  static SKColor *color = nil;
  if (!color) {
    color = [SKColor colorWithRed:0.2f green:0.25f blue:0.4f alpha:1.0f];
  }
  return color;
}

SKColor *
FLInterfaceColorMedium()
{
  static SKColor *color = nil;
  if (!color) {
    color = [SKColor colorWithRed:0.4f green:0.5f blue:0.8f alpha:1.0f];
  }
  return color;
}

SKColor *
FLInterfaceColorLight()
{
  static SKColor *color = nil;
  if (!color) {
    color = [SKColor colorWithRed:0.6f green:0.75f blue:1.0f alpha:1.0f];
  }
  return color;
}

SKColor *
FLInterfaceColorSunny()
{
  static SKColor *color = nil;
  if (!color) {
    color = [SKColor colorWithRed:1.0f green:0.9f blue:0.5f alpha:1.0f];
  }
  return color;
}

SKColor *
FLInterfaceColorGood()
{
  static SKColor *color = nil;
  if (!color) {
    color = [SKColor colorWithRed:0.3f green:1.0f blue:0.3f alpha:1.0f];
  }
  return color;
}

SKColor *
FLInterfaceColorMaybe()
{
  static SKColor *color = nil;
  if (!color) {
    color = [SKColor colorWithRed:1.0f green:0.7f blue:0.3f alpha:1.0f];
  }
  return color;
}

SKColor *
FLInterfaceColorBad()
{
  static SKColor *color = nil;
  if (!color) {
    color = [SKColor colorWithRed:1.0f green:0.3f blue:0.3f alpha:1.0f];
  }
  return color;
}

HLLabelButtonNode *
FLInterfaceLabelButton()
{
  HLLabelButtonNode *labelButton = [[HLLabelButtonNode alloc] initWithImageNamed:@"menu-button"];
  labelButton.centerRect = CGRectMake(0.3333333f, 0.3333333f, 0.3333333f, 0.3333333f);
  labelButton.size = CGSizeMake(240.0f, 36.0f);
  labelButton.fontName = FLInterfaceFontName;
  labelButton.fontSize = 20.0f;
  labelButton.fontColor = [UIColor whiteColor];
  return labelButton;
}

const CGFloat FLDSMultilineLabelParagraphWidthReadableMax = 480.0f;
const CGFloat FLDSMultilineLabelParagraphWidthBugWorkaroundPad = 10.0f;

NSString * const FLGameTypeChallengeTag = @"challenge";

NSString *
FLGameTypeChallengeTitle()
{
  static NSString *title = nil;
  if (!title) {
    title = NSLocalizedString(@"Game", @"Game information: the label used for a challenge game.");
  }
  return title;
}

NSString * const FLGameTypeSandboxTag = @"sandbox";

NSString *
FLGameTypeSandboxTitle()
{
  static NSString *title = nil;
  if (!title) {
    title = NSLocalizedString(@"Sandbox", @"Game information: the label used for a sandbox game.");
  }
  return title;
}
