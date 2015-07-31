//
//  FLGoalsNode.mm
//  Flippy
//
//  Created by Karl Voskuil on 10/31/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
//

#include <vector>

#import "DSMultilineLabelNode.h"
#import "FLGoalsNode.h"
#include "FLTrackGrid.h"
#import "FLUser.h"

using namespace std;

static const CGFloat FLZPositionContent = 0.0f;
static const CGFloat FLZPositionHappyBursts = 1.0f;
static const CGFloat FLZPositionCoverAll = 2.0f;

static const CGFloat FLLayoutNodeSpacerVertical = 12.0f;
static const CGFloat FLLayoutNodeSpacerHorizontal = 3.0f;
static const CGFloat FLLayoutNodeLabelPad = 3.0f;
static const CGFloat FLLayoutNodeComponentPad = 7.0f;

@implementation FLGoalsNode
{
  FLGameType _gameType;
  int _gameLevel;

  SKLabelNode *_introLevelHeaderNode;
  SKLabelNode *_introLevelTitleNode;
  SKLabelNode *_introGoalsHeaderNode;
  SKLabelNode *_introGoalsShortNode;
  DSMultilineLabelNode *_introGoalsLongNode;
  SKLabelNode *_truthHeaderNode;
  HLGridNode *_truthTableNode;
  DSMultilineLabelNode *_truthFooterNode;
  HLLabelButtonNode *_victoryButton;
  SKNode *_victoryDetailsNode;
}

- (instancetype)initWithSceneSize:(CGSize)sceneSize gameType:(FLGameType)gameType gameLevel:(int)gameLevel
{
  self = [super init];
  if (self) {
    _sceneSize = sceneSize;
    _gameType = gameType;
    _gameLevel = gameLevel;
  }
  return self;
}

- (void)setSceneSize:(CGSize)sceneSize
{
  _sceneSize = sceneSize;
  [self layout];
}

- (void)createIntro
{

  if (_gameType == FLGameTypeChallenge) {
    _introLevelHeaderNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    _introLevelHeaderNode.zPosition = FLZPositionContent;
    _introLevelHeaderNode.fontSize = 18.0f;
    _introLevelHeaderNode.fontColor = FLInterfaceColorMaybe();
    _introLevelHeaderNode.text = [NSString stringWithFormat:NSLocalizedString(@"Level %d",
                                                                              @"Goals screen: a header for the current challenge level with {level number}."),
                                  _gameLevel];
  }

  _introLevelTitleNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  _introLevelTitleNode.zPosition = FLZPositionContent;
  _introLevelTitleNode.fontSize = 18.0f;
  _introLevelTitleNode.fontColor = [SKColor whiteColor];
  if (_gameType == FLGameTypeChallenge) {
    _introLevelTitleNode.text = [NSString stringWithFormat:NSLocalizedString(@"“%@”",
                                                                             @"Goals screen: a way of presenting the current challenge level title."),
                                 FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsTitle)];
  } else {
    _introLevelTitleNode.text = FLGameTypeSandboxTitle();
  }

  if (_gameType == FLGameTypeChallenge) {
    _introGoalsHeaderNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    _introGoalsHeaderNode.zPosition = FLZPositionContent;
    _introGoalsHeaderNode.fontSize = 18.0f;
    _introGoalsHeaderNode.fontColor = FLInterfaceColorMaybe();
    _introGoalsHeaderNode.text = NSLocalizedString(@"Goals",
                                                   @"Goals screen: a title for the goals of the current challenge level.");
  }

  if (_gameType == FLGameTypeChallenge) {
    _introGoalsShortNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceBoldFontName];
    _introGoalsShortNode.zPosition = FLZPositionContent;
    _introGoalsShortNode.fontSize = 18.0f;
    _introGoalsShortNode.fontColor = FLInterfaceColorLight();
    _introGoalsShortNode.text = FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsGoalShort);
  }

  if (_gameType == FLGameTypeChallenge) {
    _introGoalsLongNode = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    _introGoalsLongNode.zPosition = FLZPositionContent;
    _introGoalsLongNode.fontSize = 18.0f;
    _introGoalsLongNode.fontColor = [SKColor whiteColor];
    _introGoalsLongNode.text = FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsGoalLong);
  }
}

- (BOOL)createTruthWithTrackTruthTable:(FLTrackTruthTable *)trackTruthTable
{
  BOOL victory = NO;

  // Header.
  _truthHeaderNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  _truthHeaderNode.zPosition = FLZPositionContent;
  _truthHeaderNode.fontSize = 18.0f;
  _truthHeaderNode.fontColor = FLInterfaceColorMaybe();
  _truthHeaderNode.text = NSLocalizedString(@"Current Results",
                                            @"Goals screen: the header over the displayed results of the current level solution.");

  // Truth table (if possible) and footer.
  NSString *truthFooterText = nil;
  SKColor *truthFooterColor = nil;
  if (!trackTruthTable.platformStartSegmentNodes || [trackTruthTable.platformStartSegmentNodes count] != 1) {
    truthFooterText = NSLocalizedString(@"(Results can only be shown when track contains exactly one Starting Platform.)",
                                        @"Goals screen: note explaining that results (including truth table) can't be shown until the track meets certain conditions.");
    truthFooterColor = FLInterfaceColorBad();
  } else if (trackTruthTable.state == FLTrackTruthTableStateMissingSegments) {
    truthFooterText = NSLocalizedString(@"(Results can only be shown when track contains at least one Input Value and one Output Value.)",
                                        @"Goals screen: note explaining that results (including truth table) can't be shown until the track meets certain conditions.");
    truthFooterColor = FLInterfaceColorBad();
  } else {
    NSArray *goalValues = nil;
    if (_gameType == FLGameTypeChallenge) {
      goalValues = FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsGoalValues);
    }
    NSUInteger outputValuesCorrect = 0;
    _truthTableNode = [self FL_truthTableCreateForTable:trackTruthTable index:0 correctValues:goalValues outputValuesCorrect:&outputValuesCorrect];
    if (goalValues) {
      victory = (outputValuesCorrect == [goalValues count]);
    }
    _truthTableNode.zPosition = FLZPositionContent;
    if (_gameType == FLGameTypeChallenge && victory) {
      if (_gameLevel + 1 >= FLChallengeLevelsCount()) {
        truthFooterText = NSLocalizedString(@"Last Level Complete!",
                                            @"Goals screen: displayed when current level solution is correct according to goals and current level is the last level.");
      } else {
        truthFooterText = NSLocalizedString(@"Level Complete!",
                                            @"Goals screen: displayed when current level solution is correct according to goals.");
      }
      truthFooterColor = FLInterfaceColorGood();
    } else if (trackTruthTable.state == FLTrackTruthTableStateInfiniteLoopDetected) {
      truthFooterText = NSLocalizedString(@"Loop detected: The results simulation halted after finding a loop in the track.",
                                          @"Goals screen: displayed when a loop in the track is detected.");
      truthFooterColor = FLInterfaceColorBad();
    } else if (trackTruthTable.state == FLTrackTruthTableStateMissingLinks) {
      if (_gameLevel == 0) {
        // note: Hacky hint for level 0.  This is for the sake of the poor sod who accidentally deletes the pre-created
        // join segments and doesn't know how to do linking (until the tutorial on the next level).
        truthFooterText = NSLocalizedString(@"Warning: At least one of the track inputs or outputs isn’t linked to anything. Restart the level to restore links.",
                                            @"Goals screen: note explaining that some important links are missing on the track.");
        truthFooterColor = [SKColor whiteColor];
      } else {
        truthFooterText = NSLocalizedString(@"Warning: At least one of the track inputs or outputs isn’t linked to anything.",
                                            @"Goals screen: note explaining that some important links are missing on the track.");
        truthFooterColor = [SKColor whiteColor];
      }
    } else if (goalValues) {
      truthFooterText = [NSString stringWithFormat:NSLocalizedString(@"Solution Incomplete\n(%d of %d outputs correct)",
                                                                     @"Goals screen: displayed when current level solution is not yet complete."),
                         outputValuesCorrect,
                         [goalValues count]];
      truthFooterColor = [SKColor whiteColor];
    }
  } // note: ...else no result footer text to display.
  if (truthFooterText) {
    _truthFooterNode = [[DSMultilineLabelNode alloc] initWithFontNamed:FLInterfaceFontName];
    _truthFooterNode.zPosition = FLZPositionContent;
    _truthFooterNode.fontSize = 18.0f;
    _truthFooterNode.fontColor = truthFooterColor;
    _truthFooterNode.text = truthFooterText;
  }

  return victory;
}

- (void)createVictoryWithUnlockTexts:(NSArray *)unlockTexts
                         recordTexts:(NSArray *)recordTexts
                     recordNewValues:(NSArray *)recordNewValues
                     recordOldValues:(NSArray *)recordOldValues
                  recordValueFormats:(NSArray *)recordValueFormats
{
  if (_gameType != FLGameTypeChallenge) {
    return;
  }

  // Victory button.
  if (_gameLevel + 1 < FLChallengeLevelsCount()) {
    _victoryButton = FLInterfaceLabelButton();
    _victoryButton.zPosition = FLZPositionContent;
    _victoryButton.anchorPoint = CGPointMake(0.5f, 1.0f);
    _victoryButton.text = NSLocalizedString(@"Next Level",
                                            @"Goals screen: button that takes you to the next level of a challenge game.");
  }

  // "Details": unlocks and records.
  SKNode *victoryDetailsNode = [SKNode node];
  [self FL_createUnlocks:unlockTexts parent:victoryDetailsNode];
  [self FL_createRecords:recordTexts newValues:recordNewValues oldValues:recordOldValues valueFormats:recordValueFormats parent:victoryDetailsNode];
  if ([victoryDetailsNode.children count] > 0) {
    HLTableLayoutManager *layoutManager = [[HLTableLayoutManager alloc] initWithColumnCount:4
                                                                               columnWidths:@[ @(20.0f), @(0.0f) ]
                                                                         columnAnchorPoints:@[ [NSValue valueWithCGPoint:CGPointMake(0.5f, 0.5f)],
                                                                                               [NSValue valueWithCGPoint:CGPointMake(0.0f, 0.25f)],
                                                                                               [NSValue valueWithCGPoint:CGPointMake(1.0f, 0.25f)] ]
                                                                                 rowHeights:@[ @(20.0f) ]];
    layoutManager.anchorPoint = CGPointMake(0.5f, 1.0f);
    layoutManager.columnSeparator = 8.0f;
    [victoryDetailsNode hlSetLayoutManager:layoutManager];
    [victoryDetailsNode hlLayoutChildren];
    victoryDetailsNode.zPosition = FLZPositionContent;
    _victoryDetailsNode = victoryDetailsNode;
  }
}

- (void)layout
{
  NSMutableArray *layoutNodes = [NSMutableArray array];
  vector<CGFloat> layoutNodeWidths;
  layoutNodeWidths.reserve(20);
  vector<CGFloat> layoutNodeHeights;
  layoutNodeHeights.reserve(20);

  // note: If a call to layout happens during reveal, then we should layout all nodes, but
  // don't add to parent any nodes that aren't currently added to parent.
  NSArray *previouslyAddedToParent = nil;
  if (self.contentNode) {
    previouslyAddedToParent = self.contentNode.children;
    [self.contentNode removeAllChildren];
    // note: Unset old contentNode so that setting properties won't be repeatedly
    // adjusting out some old content that doesn't matter.
    self.contentNode = nil;
  }

  // note: Usually we show text in a block that doesn't change when device is rotated.
  // But space is precious here, so use all that we've got in terms of width.
  CGFloat edgeSizeMax = MIN(_sceneSize.width - FLLayoutNodeSpacerHorizontal * 2.0f,
                            FLDSMultilineLabelParagraphWidthReadableMax);

  if (_introLevelHeaderNode) {
    [layoutNodes addObject:_introLevelHeaderNode];
    _introLevelHeaderNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeTop;
    layoutNodeWidths.emplace_back(_introLevelHeaderNode.frame.size.width);
    layoutNodeHeights.emplace_back(_introLevelHeaderNode.frame.size.height + FLLayoutNodeLabelPad);
  }
  if (_introLevelTitleNode) {
    [layoutNodes addObject:_introLevelTitleNode];
    _introLevelTitleNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeTop;
    layoutNodeWidths.emplace_back(_introLevelTitleNode.frame.size.width);
    layoutNodeHeights.emplace_back(_introLevelTitleNode.frame.size.height + FLLayoutNodeSpacerVertical);
  }
  if (_introGoalsHeaderNode) {
    [layoutNodes addObject:_introGoalsHeaderNode];
    _introGoalsHeaderNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeTop;
    layoutNodeWidths.emplace_back(_introGoalsHeaderNode.frame.size.width);
    layoutNodeHeights.emplace_back(_introGoalsHeaderNode.frame.size.height + FLLayoutNodeLabelPad);
  }
  if (_introGoalsShortNode) {
    [layoutNodes addObject:_introGoalsShortNode];
    _introGoalsShortNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeTop;
    layoutNodeWidths.emplace_back(_introGoalsShortNode.frame.size.width);
    layoutNodeHeights.emplace_back(_introGoalsShortNode.frame.size.height + FLLayoutNodeLabelPad);
  }
  if (_introGoalsLongNode) {
    [layoutNodes addObject:_introGoalsLongNode];
    _introGoalsLongNode.anchorPoint = CGPointMake(0.5f, 1.0f);
    _introGoalsLongNode.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
    layoutNodeWidths.emplace_back(_introGoalsLongNode.size.width);
    layoutNodeHeights.emplace_back(_introGoalsLongNode.size.height + FLLayoutNodeSpacerVertical);
  }
  if (_truthHeaderNode) {
    [layoutNodes addObject:_truthHeaderNode];
    _truthHeaderNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeTop;
    layoutNodeWidths.emplace_back(_truthHeaderNode.frame.size.width);
    layoutNodeHeights.emplace_back(_truthHeaderNode.frame.size.height + FLLayoutNodeComponentPad);
  }
  if (_truthTableNode) {
    [layoutNodes addObject:_truthTableNode];
    layoutNodeWidths.emplace_back(_truthTableNode.size.width);
    layoutNodeHeights.emplace_back(_truthTableNode.size.height + FLLayoutNodeComponentPad);
  }
  if (_truthFooterNode) {
    [layoutNodes addObject:_truthFooterNode];
    _truthFooterNode.anchorPoint = CGPointMake(0.5f, 1.0f);
    _truthFooterNode.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
    layoutNodeWidths.emplace_back(_truthFooterNode.size.width);
    layoutNodeHeights.emplace_back(_truthFooterNode.size.height + FLLayoutNodeSpacerVertical);
  }
  if (_victoryButton) {
    [layoutNodes addObject:_victoryButton];
    layoutNodeWidths.emplace_back(_victoryButton.size.width);
    layoutNodeHeights.emplace_back(_victoryButton.size.height + FLLayoutNodeSpacerVertical);
  }
  if (_victoryDetailsNode) {
    [layoutNodes addObject:_victoryDetailsNode];
    HLTableLayoutManager *layoutManager = (HLTableLayoutManager *)_victoryDetailsNode.hlLayoutManager;
    layoutNodeWidths.emplace_back(layoutManager.size.width);
    layoutNodeHeights.emplace_back(layoutManager.size.height);
  }

  SKNode *contentNode = [SKNode node];
  CGSize contentSize = CGSizeZero;
  for (CGFloat width : layoutNodeWidths) {
    if (width > contentSize.width) {
      contentSize.width = width;
    }
  }
  for (CGFloat height : layoutNodeHeights) {
    contentSize.height += height;
  }
  contentSize.width += 2.0f * FLLayoutNodeSpacerHorizontal;
  contentSize.height += 2.0f * FLLayoutNodeSpacerVertical;
  CGFloat layoutNodeY = contentSize.height / 2.0f - FLLayoutNodeSpacerVertical;
  for (NSUInteger i = 0; i < [layoutNodes count]; ++i) {
    id layoutNode = layoutNodes[i];
    CGFloat height = layoutNodeHeights[i];
    [layoutNode setPosition:CGPointMake(0.0f, layoutNodeY)];
    if (!previouslyAddedToParent || [previouslyAddedToParent containsObject:layoutNode]) {
      [contentNode addChild:layoutNode];
      // commented out: But useful for debugging layout issues.
      //SKSpriteNode *blocky = [SKSpriteNode spriteNodeWithColor:[SKColor blueColor] size:CGSizeMake(layoutNodeWidths[i], height)];
      //blocky.zPosition = FLZPositionContent - 0.01f;
      //blocky.anchorPoint = CGPointMake(0.5f, 1.0f);
      //blocky.position = CGPointMake(0.0f, layoutNodeY);
      //[contentNode addChild:blocky];
    }
    layoutNodeY -= height;
  }

  // noob: Need to catch gestures outside of the HLScrollNode so that tapping anywhere uninteresting
  // dismisses the goals node.  If the modal presentation code in HLScene did this for us, then we
  // wouldn't have to bother.  Or, if the FLTrackScene did this for us, then we wouldn't have to
  // bother.  But there's an argument for doing it for ourselves: In goals node, we want all pan and
  // pinch actions to be passed along to the HLScrollNode, even if they happen outside the HLScrollNode's
  // area.  (That could also be an argument for using HLScrollNode's insets more effectively, and having
  // it crop to its scroll area.)
  CGSize coverAllNodeSize = CGSizeMake(MAX(_sceneSize.width, contentSize.width),
                                       MAX(_sceneSize.height, contentSize.height));
  SKSpriteNode *coverAllNode = [SKSpriteNode spriteNodeWithColor:[SKColor clearColor] size:coverAllNodeSize];
  coverAllNode.zPosition = FLZPositionCoverAll;
  [contentNode addChild:coverAllNode];

  CGSize scrollNodeSize = CGSizeMake(MIN(_sceneSize.width, contentSize.width),
                                     MIN(_sceneSize.height, contentSize.height));
  self.size = scrollNodeSize;
  self.contentSize = contentSize;
  self.contentScaleMinimum = 0.0f;
  self.contentScaleMinimumMode = HLScrollNodeContentScaleMinimumFitLoose;
  const CGFloat FLGoalsInitialContentScaleMin = 0.25f;
  CGFloat initialContentScaleX = scrollNodeSize.width / contentSize.width;
  CGFloat initialContentScaleY = scrollNodeSize.height / contentSize.height;
  CGFloat initialContentScale = MIN(initialContentScaleX, initialContentScaleY);
  // note: Zoom out to show content initially, but only so far.  Also, prioritize fitting
  // the X dimension, since scrolling up and down seems more natural.  But if fitting
  // everything means zooming out only a tiny bit, then just fit everything and don't
  // allow zooming back in, because it's silly.
  CGFloat contentScaleMaximum = 1.0f;
  if (initialContentScale > 1.0f) {
    initialContentScale = 1.0f;
  } else if (initialContentScale > 0.95f) {
    contentScaleMaximum = initialContentScale;
  } else {
    initialContentScale = MAX(initialContentScaleX, FLGoalsInitialContentScaleMin);
  }
  self.contentScaleMaximum = contentScaleMaximum;
  self.contentScale = initialContentScale;
  // note: Show center if content fits vertically; otherwise show top.
  CGPoint contentOffset = CGPointZero;
  if (contentSize.height * initialContentScale > _sceneSize.height) {
    contentOffset.y = (_sceneSize.height - contentSize.height * initialContentScale) / 2.0f;
  }
  self.contentOffset = contentOffset;
  self.contentNode = contentNode;
}

- (void)reveal
{
  CGFloat originalContentScale = self.contentScale;
  CGFloat originalContentScaleMaximum = self.contentScaleMaximum;
  HLScrollNodeContentScaleMinimumMode originalContentScaleMinimumMode = self.contentScaleMinimumMode;

  const CGFloat FLTruthTableRevealTruthTableFlyUpScale = originalContentScale * 0.8f;
  const CGFloat FLTruthTableRevealTruthTableFlyDownScale = 1.3f;
  const NSTimeInterval FLTruthTableRevealZoomInDuration = 0.5;
  const NSTimeInterval FLTruthTableRevealDramaticPauseDuration = 0.2;
  const NSTimeInterval FLTruthTableRevealCorrectStepDuration = 0.4;
  const NSTimeInterval FLTruthTableRevealCorrectMaxDuration = 3.0;
  const NSTimeInterval FLTruthTableRevealOtherDuration = 0.4;
  const NSTimeInterval FLTruthTableRevealZoomOutDuration = 0.3;

  NSMutableArray *revealActions = [NSMutableArray array];

  SKEmitterNode *happyBurst = [[HLEmitterStore sharedStore] emitterCopyForKey:@"happyBurst"];
  happyBurst.zPosition = FLZPositionHappyBursts;
  // noob: Good practice to remove emitter node once it's finished?
  NSTimeInterval particleLifetimeMax = happyBurst.particleLifetime + happyBurst.particleLifetimeRange / 2.0f;

  // Hide truth table correct column, and create actions to re-add them one at a time.
  if (_truthTableNode) {
    int gridWidth = _truthTableNode.gridWidth;
    int gridHeight = _truthTableNode.gridHeight;
    NSTimeInterval correctStepDuration = FLTruthTableRevealCorrectMaxDuration / gridHeight;
    if (correctStepDuration > FLTruthTableRevealCorrectStepDuration) {
      correctStepDuration = FLTruthTableRevealCorrectStepDuration;
    }
    for (int row = 1; row < gridHeight; ++row) {
      int squareIndex = (row + 1) * gridWidth - 1;
      SKNode *squareNode = [_truthTableNode squareNodeForSquare:squareIndex];
      SKLabelNode *resultNode = (SKLabelNode *)[_truthTableNode contentForSquare:squareIndex];
      [_truthTableNode setContent:nil forSquare:squareIndex];

      CGPoint resultContentLocation = [self.contentNode convertPoint:resultNode.position fromNode:squareNode];
      if (row == 1) {
        [revealActions addObject:[SKAction runBlock:^{
          self.contentScaleMinimumMode = HLScrollNodeContentScaleMinimumAsConfigured;
          SKAction *flyUpAction = [self actionForSetContentScale:FLTruthTableRevealTruthTableFlyUpScale
                                                animatedDuration:(FLTruthTableRevealZoomInDuration * 0.6f)];
          flyUpAction.timingMode = SKActionTimingEaseOut;
          [self runAction:flyUpAction];
        }]];
        [revealActions addObject:[SKAction waitForDuration:(FLTruthTableRevealZoomInDuration * 0.6f)]];
        [revealActions addObject:[SKAction runBlock:^{
          self.contentScaleMaximum = FLTruthTableRevealTruthTableFlyDownScale;
          SKAction *flyDownAction = [self actionForScrollContentLocation:resultContentLocation
                                                          toNodeLocation:CGPointZero
                                                      andSetContentScale:FLTruthTableRevealTruthTableFlyDownScale
                                                        animatedDuration:(FLTruthTableRevealZoomInDuration * 0.4f)];
          flyDownAction.timingMode = SKActionTimingEaseIn;
          [self runAction:flyDownAction];
        }]];
        [revealActions addObject:[SKAction waitForDuration:(FLTruthTableRevealZoomInDuration * 0.4f)]];
        [revealActions addObject:[SKAction waitForDuration:FLTruthTableRevealDramaticPauseDuration]];
      } else {
        [revealActions addObject:[SKAction runBlock:^{
          [self scrollContentLocation:resultContentLocation
                       toNodeLocation:CGPointZero
                     animatedDuration:(correctStepDuration * 0.33f)
                           completion:nil];
        }]];
        [revealActions addObject:[SKAction waitForDuration:(correctStepDuration * 0.33f)]];
      }

      [revealActions addObject:[SKAction playSoundFileNamed:@"pop-2.caf" waitForCompletion:NO]];
      [revealActions addObject:[SKAction runBlock:^{
        [self->_truthTableNode setContent:resultNode forSquare:squareIndex];
        SKEmitterNode *happyBurstCopy = [happyBurst copy];
        happyBurstCopy.position = resultContentLocation;
        happyBurstCopy.particlePositionRange = CGVectorMake(resultNode.frame.size.width, resultNode.frame.size.height);
        [self.contentNode addChild:happyBurstCopy];
        [happyBurstCopy runAction:[SKAction waitForDuration:particleLifetimeMax] completion:^{
          [happyBurstCopy removeFromParent];
        }];
      }]];
      [revealActions addObject:[SKAction waitForDuration:(correctStepDuration * 0.66f)]];
    }
    [revealActions addObject:[SKAction runBlock:^{
      [self setContentScale:originalContentScale
           animatedDuration:FLTruthTableRevealZoomOutDuration
                 completion:nil];
    }]];
    [revealActions addObject:[SKAction waitForDuration:FLTruthTableRevealZoomOutDuration]];
    [revealActions addObject:[SKAction runBlock:^{
      self.contentScaleMaximum = originalContentScaleMaximum;
      self.contentScaleMinimumMode = originalContentScaleMinimumMode;
    }]];
  }

  // Hide truth footer node, and create an action to show it.
  if (_truthFooterNode) {
    CGPoint footerContentLocation = _truthFooterNode.position;
    [_truthFooterNode removeFromParent];
    [revealActions addObject:[SKAction runBlock:^{
      [self scrollContentLocation:footerContentLocation
                   toNodeLocation:CGPointZero
                 animatedDuration:(FLTruthTableRevealOtherDuration * 0.33f)
                       completion:nil];
    }]];
    [revealActions addObject:[SKAction waitForDuration:(FLTruthTableRevealOtherDuration * 0.33f)]];
    [revealActions addObject:[SKAction playSoundFileNamed:@"pop-2.caf" waitForCompletion:NO]];
    [revealActions addObject:[SKAction runBlock:^{
      [self.contentNode addChild:self->_truthFooterNode];
      SKEmitterNode *happyBurstCopy = [happyBurst copy];
      happyBurstCopy.position = footerContentLocation;
      happyBurstCopy.particlePositionRange = CGVectorMake(self->_truthFooterNode.size.width, self->_truthFooterNode.size.height);
      [self.contentNode addChild:happyBurstCopy];
      [happyBurstCopy runAction:[SKAction waitForDuration:particleLifetimeMax] completion:^{
        [happyBurstCopy removeFromParent];
      }];
    }]];
    [revealActions addObject:[SKAction waitForDuration:(FLTruthTableRevealOtherDuration * 0.66f)]];
  }

  // Hide victory button, and create an action to show it.
  if (_victoryButton) {
    CGPoint victoryContentLocation = _victoryButton.position;
    [_victoryButton removeFromParent];
    [revealActions addObject:[SKAction runBlock:^{
      [self scrollContentLocation:victoryContentLocation
                   toNodeLocation:CGPointZero
                 animatedDuration:(FLTruthTableRevealOtherDuration * 0.33f)
                       completion:nil];
    }]];
    [revealActions addObject:[SKAction waitForDuration:(FLTruthTableRevealOtherDuration * 0.33f)]];
    [revealActions addObject:[SKAction playSoundFileNamed:@"pop-2.caf" waitForCompletion:NO]];
    [revealActions addObject:[SKAction runBlock:^{
      [self.contentNode addChild:self->_victoryButton];
      SKEmitterNode *happyBurstCopy = [happyBurst copy];
      happyBurstCopy.position = victoryContentLocation;
      happyBurstCopy.particlePositionRange = CGVectorMake(self->_victoryButton.size.width, self->_victoryButton.size.height);
      [self.contentNode addChild:happyBurstCopy];
      [happyBurstCopy runAction:[SKAction waitForDuration:particleLifetimeMax] completion:^{
        [happyBurstCopy removeFromParent];
      }];
    }]];
    [revealActions addObject:[SKAction waitForDuration:(FLTruthTableRevealOtherDuration * 0.66f)]];
  }

  // Hide details (unlocks and records), and create actions to show them.
  if (_victoryDetailsNode) {
    HLTableLayoutManager *layoutManager = (HLTableLayoutManager *)[_victoryDetailsNode hlLayoutManager];
    NSUInteger columnCount = layoutManager.columnCount;
    NSArray *detailsNodes = _victoryDetailsNode.children;
    NSUInteger detailsNodesCount = [detailsNodes count];
    NSMutableArray *replaceNodes = [NSMutableArray array];
    for (NSUInteger rowStartIndex = 0; rowStartIndex + columnCount - 1 < detailsNodesCount; rowStartIndex += columnCount) {
      BOOL isHeaderRow = ![detailsNodes[rowStartIndex] isKindOfClass:[SKSpriteNode class]];
      CGPoint rowContentLocation;
      if (!isHeaderRow) {
        SKNode *iconNode = detailsNodes[rowStartIndex];
        rowContentLocation = [self.contentNode convertPoint:iconNode.position fromNode:_victoryDetailsNode];
        rowContentLocation.x = 0.0f;
      }
      for (NSUInteger column = 0; column < columnCount; ++column) {
        SKNode *node = detailsNodes[rowStartIndex + column];
        [node removeFromParent];
        [replaceNodes addObject:node];
      }
      if (!isHeaderRow) {
        [revealActions addObject:[SKAction runBlock:^{
          [self scrollContentLocation:rowContentLocation
                       toNodeLocation:CGPointZero
                     animatedDuration:(FLTruthTableRevealOtherDuration * 0.33f)
                           completion:nil];
        }]];
        [revealActions addObject:[SKAction waitForDuration:(FLTruthTableRevealOtherDuration * 0.33f)]];
        [revealActions addObject:[SKAction playSoundFileNamed:@"brr-bring.caf" waitForCompletion:NO]];
        [revealActions addObject:[SKAction runBlock:^{
          for (SKNode *node in replaceNodes) {
            [self->_victoryDetailsNode addChild:node];
          }
          SKEmitterNode *happyBurstCopy = [happyBurst copy];
          happyBurstCopy.position = rowContentLocation;
          happyBurstCopy.particlePositionRange = CGVectorMake(layoutManager.size.width, 20.0f);
          [self.contentNode addChild:happyBurstCopy];
          [happyBurstCopy runAction:[SKAction waitForDuration:particleLifetimeMax] completion:^{
            [happyBurstCopy removeFromParent];
          }];
        }]];
        [revealActions addObject:[SKAction waitForDuration:(FLTruthTableRevealOtherDuration * 0.66f)]];
        replaceNodes = [NSMutableArray array];
      }
    }
  }

  [revealActions addObject:[SKAction playSoundFileNamed:@"train-whistle-tune-1.caf" waitForCompletion:NO]];

  [self runAction:[SKAction sequence:revealActions]];
}

#pragma mark -
#pragma mark HLGestureTarget

- (BOOL)addToGesture:(UIGestureRecognizer *)gestureRecognizer firstTouch:(UITouch *)touch isInside:(BOOL *)isInside
{
  if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]
      || [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
    return [super addToGesture:gestureRecognizer firstTouch:touch isInside:isInside];
  } else {
    // note: The coverAllNode is designed to catch *all* gestures on the device, so naturally,
    // any gesture is "inside".
    *isInside = YES;
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
      [gestureRecognizer addTarget:self action:@selector(handleTap:)];
      return YES;
    }
  }
  return NO;
}

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer
{
  CGPoint viewLocation = [gestureRecognizer locationInView:self.scene.view];
  CGPoint sceneLocation = [self.scene convertPointFromView:viewLocation];
  CGPoint contentNodeLocation = [self.contentNode convertPoint:sceneLocation fromNode:self.scene];

  if (_victoryButton && [_victoryButton containsPoint:contentNodeLocation]) {
    [self FL_dismissWithNextLevel:YES];
  } else {
    [self FL_dismissWithNextLevel:NO];
  }
}

#pragma mark -
#pragma mark Private

- (HLGridNode *)FL_truthTableCreateForTable:(FLTrackTruthTable *)trackTruthTable
                                      index:(NSUInteger)truthTableIndex
                              correctValues:(NSArray *)correctValues
                        outputValuesCorrect:(NSUInteger *)outputValuesCorrect
{
  FLTruthTable& truthTable = trackTruthTable.truthTables[truthTableIndex];

  int inputSize = truthTable.getInputSize();
  int outputSize = truthTable.getOutputSize();
  NSMutableArray *contentTexts = [NSMutableArray array];
  NSMutableArray *contentColors = [NSMutableArray array];
  int gridWidth = inputSize + outputSize;
  if (correctValues) {
    ++gridWidth;
  }

  // Specify content for header row.
  for (FLSegmentNode *inputSegmentNode in trackTruthTable.inputSegmentNodes) {
    [contentTexts addObject:[NSString stringWithFormat:@"%c", inputSegmentNode.label]];
    [contentColors addObject:[SKColor blackColor]];
  }
  for (FLSegmentNode *outputSegmentNode in trackTruthTable.outputSegmentNodes) {
    [contentTexts addObject:[NSString stringWithFormat:@"%c", outputSegmentNode.label]];
    [contentColors addObject:[SKColor blackColor]];
  }
  if (correctValues) {
    [contentTexts addObject:@""];
    [contentColors addObject:[SKColor blackColor]];
  }

  // Specify content for value rows.
  if (correctValues) {
    *outputValuesCorrect = 0;
  }
  vector<int> inputValues = truthTable.inputValuesFirst();
  NSUInteger cv = 0;
  do {
    BOOL rowCorrect = YES;
    for (auto iv : inputValues) {
      [contentTexts addObject:[NSString stringWithFormat:@"%d", iv]];
      [contentColors addObject:[SKColor whiteColor]];
    }
    int *outputValues = truthTable.outputValues(inputValues);
    for (int ov = 0; ov < outputSize; ++ov) {
      [contentTexts addObject:[NSString stringWithFormat:@"%d", outputValues[ov]]];
      if (!correctValues) {
        [contentColors addObject:FLInterfaceColorLight()];
      } else {
        int correctValue = [correctValues[cv++] intValue];
        if (outputValues[ov] == correctValue) {
          [contentColors addObject:FLInterfaceColorGood()];
          ++(*outputValuesCorrect);
        } else {
          [contentColors addObject:FLInterfaceColorBad()];
          rowCorrect = NO;
        }
      }
    }
    if (correctValues) {
      if (rowCorrect) {
        [contentTexts addObject:@"✓"];
        [contentColors addObject:FLInterfaceColorGood()];
      } else {
        [contentTexts addObject:@"✗"];
        [contentColors addObject:FLInterfaceColorBad()];
      }
    }
  } while (truthTable.inputValuesSuccessor(inputValues));

  // Create all content nodes for the grid.
  CGFloat labelWidthMax = 0.0f;
  CGFloat labelHeightMax = 0.0f;
  NSMutableArray *contentNodes = [NSMutableArray array];
  for (NSUInteger c = 0; c < [contentTexts count]; ++c) {
    SKLabelNode *labelNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    labelNode.fontColor = contentColors[c];
    labelNode.fontSize = 24.0f;
    labelNode.text = contentTexts[c];
    if (labelNode.frame.size.width > labelWidthMax) {
      labelWidthMax = labelNode.frame.size.width;
    }
    if (labelNode.frame.size.height > labelHeightMax) {
      labelHeightMax = labelNode.frame.size.height;
    }
    labelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    labelNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    [contentNodes addObject:labelNode];
  }

  // Create grid.
  int squareCount = gridWidth * (truthTable.getRowCount() + 1);
  HLGridNode *gridNode = [[HLGridNode alloc] initWithGridWidth:gridWidth
                                                   squareCount:squareCount
                                                   anchorPoint:CGPointMake(0.5f, 1.0f)
                                                    layoutMode:HLGridNodeLayoutModeAlignLeft
                                                    squareSize:CGSizeMake(labelWidthMax + 6.0f, labelHeightMax + 6.0f)
                                          backgroundBorderSize:1.0f
                                           squareSeparatorSize:0.0f];
  gridNode.backgroundColor = [SKColor blackColor];
  gridNode.squareColor = [SKColor colorWithWhite:0.2f alpha:1.0f];
  gridNode.highlightColor = [SKColor colorWithWhite:0.8f alpha:1.0f];
  gridNode.content = contentNodes;
  for (int s = 0; s < gridWidth; ++s) {
    [gridNode setHighlight:YES forSquare:s];
  }
  // note: For bigger tables, try highlighting every other row:
  //  for (int s = 0; s < squareCount; ++s) {
  //    if (s / gridWidth % 2 == 0) {
  //      [gridNode setHighlight:YES forSquare:s];
  //    }
  //  }

  return gridNode;
}

- (void)FL_createUnlocks:(NSArray *)unlockTexts
                  parent:(SKNode *)parent
{
  BOOL firstOne = YES;
  for (NSString *unlockText in unlockTexts) {

    if (firstOne) {
      [parent addChild:[SKNode node]];
      SKLabelNode *headerNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
      headerNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
      headerNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeBaseline;
      headerNode.fontSize = 14.0f;
      headerNode.fontColor = FLInterfaceColorMaybe();
      headerNode.text = NSLocalizedString(@"Unlocked!",
                                          @"Goals screen: header displayed over a table of game features unlocked by level victory.");
      [parent addChild:headerNode];
      [parent addChild:[SKNode node]];
      [parent addChild:[SKNode node]];
      firstOne = NO;
    }

    SKSpriteNode *iconNode = [SKSpriteNode spriteNodeWithTexture:[[HLTextureStore sharedStore] textureForKey:@"unlock"]
                                                            size:CGSizeMake(25.0f, 25.0f)];
    iconNode.zRotation = (CGFloat)M_PI_2;
    [parent addChild:iconNode];

    SKLabelNode *labelNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    labelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
    labelNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeBaseline;
    labelNode.fontSize = 14.0f;
    labelNode.fontColor = FLInterfaceColorLight();
    labelNode.text = unlockText;
    [parent addChild:labelNode];

    [parent addChild:[SKNode node]];

    [parent addChild:[SKNode node]];
  }
}

- (void)FL_createRecords:(NSArray *)recordTexts
               newValues:(NSArray *)newValues
               oldValues:(NSArray *)oldValues
            valueFormats:(NSArray *)valueFormats
                  parent:(SKNode *)parent
{
  BOOL firstOne = YES;
  NSUInteger recordTextsCount = [recordTexts count];
  for (NSUInteger r = 0; r < recordTextsCount; ++r) {

    if (firstOne) {
      [parent addChild:[SKNode node]];
      SKLabelNode *headerNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
      headerNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
      headerNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeBaseline;
      headerNode.fontSize = 14.0f;
      headerNode.fontColor = FLInterfaceColorMaybe();
      if (recordTextsCount == 1) {
        headerNode.text = NSLocalizedString(@"New Record!",
                                            @"Goals screen: header displayed over (exactly one) new record after level victory.");
      } else {
        headerNode.text = NSLocalizedString(@"New Records!",
                                            @"Goals screen: header displayed over a table of (more than one) new records after level victory.");
      }
      [parent addChild:headerNode];
      [parent addChild:[SKNode node]];
      [parent addChild:[SKNode node]];
      firstOne = NO;
    }

    SKSpriteNode *iconNode = [SKSpriteNode spriteNodeWithTexture:[[HLTextureStore sharedStore] textureForKey:@"goals"]
                                                            size:CGSizeMake(22.0f, 22.0f)];
    iconNode.zRotation = (CGFloat)M_PI_2;
    [parent addChild:iconNode];

    SKLabelNode *labelNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    labelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
    labelNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeBaseline;
    labelNode.fontSize = 14.0f;
    labelNode.fontColor = FLInterfaceColorLight();
    labelNode.text = recordTexts[r];
    [parent addChild:labelNode];

    SKLabelNode *newValueNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    newValueNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeRight;
    newValueNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeBaseline;
    newValueNode.fontSize = 14.0f;
    newValueNode.fontColor = FLInterfaceColorGood();
    NSString *formattedNewValue = [self FL_formatRecordValue:[newValues[r] integerValue] withFormat:(FLGoalsNodeRecordFormat)[valueFormats[r] integerValue]];
    newValueNode.text = [NSString stringWithFormat:NSLocalizedString(@"%@",
                                                                     @"Goals screen: displayed in a column of level results to show the {new record value} for a gameplay record."),
                         formattedNewValue];
    [parent addChild:newValueNode];

    if (oldValues[r] == [NSNull null]) {
      [parent addChild:[SKNode node]];
    } else {
      SKLabelNode *oldValueNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
      oldValueNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeRight;
      oldValueNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeBaseline;
      oldValueNode.fontSize = 14.0f;
      oldValueNode.fontColor = FLInterfaceColorLight();
      NSString *formattedOldValue = [self FL_formatRecordValue:[oldValues[r] integerValue] withFormat:(FLGoalsNodeRecordFormat)[valueFormats[r] integerValue]];
      oldValueNode.text = [NSString stringWithFormat:NSLocalizedString(@"(was %@)",
                                                                       @"Goals screen: displayed in a column of level results to show the {old record value} for a gameplay record."),
                           formattedOldValue];
      [parent addChild:oldValueNode];
    }
  }
}

- (NSString *)FL_formatRecordValue:(NSInteger)value withFormat:(FLGoalsNodeRecordFormat)format
{
  switch (format) {
    case FLGoalsNodeRecordFormatInteger:
      return [NSString stringWithFormat:@"%ld", (long)value];
    case FLGoalsNodeRecordFormatHourMinuteSecond: {
      // note: Localization can be accomplished with something like this:
      //    https://github.com/WDUK/WDCountdownFormatter
      NSInteger seconds = value % 60;
      value = value / 60;
      NSInteger minutes = value % 60;
      value = value / 60;
      NSInteger hours = value;
      if (hours == 0) {
        return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, long(seconds)];
      } else {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
      }
    }
  }
}

- (void)FL_dismissWithNextLevel:(BOOL)nextLevel
{
  id <FLGoalsNodeDelegate> delegate = _delegate;
  if (delegate) {
    // noob: This will typically deallocate this goals node, which means there might be
    // problems.  But I think the blocks that call this successfully retain self, and so
    // it doesn't end up being a problem.
    //
    // noob: In fact, there's a chain of self-deletion: The track scene is presenting this
    // goals node "modally", and it removes it from the node hierarchy; then the track scene
    // tells the view controller to present the next level.  Instead, it prepares a new modal
    // overlay called the "next level overlay" for saving the current level, and presents it
    // over the track scene; then, on a delegate call from a menu node in that overlay, the
    // view controller dismisses the modal presentation on the track scene, and loads and
    // presents the next level (another track scene).  And sure enough, somewhere in that mess
    // I'm getting (11/2014) a EXC_BAD_ACCESS.  So perhaps best practice is to always
    // dispatch_async a delegate call that might delete self, but in this case the connection
    // between this goals node and the track scene that owns it doesn't seem as fragile, and
    // it's not directly causing the EXC_BAD_ACCESS.  So still keep it like this.
    [delegate goalsNode:self didDismissWithNextLevel:nextLevel];
  }
}

@end
