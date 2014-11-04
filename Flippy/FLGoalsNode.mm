//
//  FLGoalsNode.mm
//  Flippy
//
//  Created by Karl Voskuil on 10/31/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#include <vector>

#import "DSMultilineLabelNode.h"
#import "FLGoalsNode.h"
#include "FLTrackGrid.h"
#import "FLUser.h"
#import <HLSpriteKit/HLScene.h>

using namespace std;

static const CGFloat FLZPositionGoalsOverlayContent = 0.0f;
static const CGFloat FLZPositionGoalsOverlayDismissNode = 1.0f;
static const CGFloat FLZPositionGoalsOverlayVictoryButton = 2.0f;
static const CGFloat FLZPositionGoalsOverlayHappyBursts = 3.0f;

static const CGFloat FLLayoutNodeSpacerVertical = 10.0f;
static const CGFloat FLLayoutNodeSpacerHorizontal = 5.0f;

@implementation FLGoalsNode
{
  __weak HLScene *_scene;

  FLGameType _gameType;
  int _gameLevel;

  DSMultilineLabelNode *_introNode;
  DSMultilineLabelNode *_truthHeaderNode;
  HLGridNode *_truthTableNode;
  DSMultilineLabelNode *_truthFooterNode;
  HLLabelButtonNode *_victoryButton;
  SKNode *_victoryDetailsNode;
  HLGestureTargetSpriteNode *_dismissNode;
}

- (instancetype)initWithScene:(HLScene *)scene sceneSize:(CGSize)sceneSize gameType:(FLGameType)gameType gameLevel:(int)gameLevel
{
  self = [super init];
  if (self) {
    _scene = scene;
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
  _introNode = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  _introNode.zPosition = FLZPositionGoalsOverlayContent;
  _introNode.fontSize = 18.0f;
  _introNode.fontColor = [SKColor whiteColor];
  if (_gameType == FLGameTypeChallenge) {
    _introNode.text = [NSString stringWithFormat:@"%@ %d:\n“%@”\n\n%@:\n%@\n\n%@",
                       NSLocalizedString(@"Level", @"Goals screen: followed by a level number."),
                       _gameLevel,
                       FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsTitle),
                       NSLocalizedString(@"Goals", @"Goals screen: the header over the description of goals for the current level."),
                       FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsGoalShort),
                       FLChallengeLevelsInfo(_gameLevel, FLChallengeLevelsGoalLong)];
  } else {
    _introNode.text = FLGameTypeSandboxTitle();
  }
}

- (BOOL)createTruthWithTrackTruthTable:(FLTrackTruthTable *)trackTruthTable
{
  BOOL victory = NO;

  // Header.
  _truthHeaderNode = [DSMultilineLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
  _truthHeaderNode.zPosition = FLZPositionGoalsOverlayContent;
  _truthHeaderNode.fontSize = 18.0f;
  _truthHeaderNode.fontColor = [SKColor whiteColor];
  _truthHeaderNode.text = NSLocalizedString(@"Current Results:",
                                            @"Goals screen: the header over the displayed results of the current level solution.");

  // Truth table (if possible) and footer.
  NSString *truthFooterText = nil;
  SKColor *truthFooterColor = nil;
  if ([trackTruthTable.platformStartSegmentNodes count] != 1) {
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
    _truthTableNode = [self FL_truthTableCreateForTable:trackTruthTable index:0 correctValues:goalValues correct:&victory];
    _truthTableNode.zPosition = FLZPositionGoalsOverlayContent;
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
    }
    // note: ...else no result footer text to display.
  }
  if (truthFooterText) {
    _truthFooterNode = [[DSMultilineLabelNode alloc] initWithFontNamed:FLInterfaceFontName];
    _truthFooterNode.zPosition = FLZPositionGoalsOverlayContent;
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
{
  if (_gameType != FLGameTypeChallenge) {
    return;
  }

  // Victory button.
  if (_gameLevel + 1 < FLChallengeLevelsCount()) {
    _victoryButton = FLInterfaceLabelButton();
    _victoryButton.zPosition = FLZPositionGoalsOverlayVictoryButton;
    _victoryButton.text = NSLocalizedString(@"Next Level",
                                            @"Goals screen: button that takes you to the next level of a challenge game.");
    [_victoryButton setGestureTargetDelegateStrong:[[HLGestureTargetTapDelegate alloc] initWithHandleGestureBlock:^(UIGestureRecognizer *gestureRecognizer){
      [self FL_dismissWithNextLevel:YES];
    }]];
    // TODO: Rather than register stuff with the scene as gesture targets, should override the gesture
    // target methods here, and take either forward to super or else send to victory button and dismiss
    // node as appropriate.  Then define a proper delegate interface for the dismiss callback, and then
    // we're good.
    HLScene *sceneStrong = _scene;
    [sceneStrong registerDescendant:_victoryButton withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  }

  // "Details": unlocks and records.
  SKNode *victoryDetailsNode = [SKNode node];
  [self FL_createUnlocks:unlockTexts parent:victoryDetailsNode];
  [self FL_createRecords:recordTexts newValues:recordNewValues oldValues:recordOldValues parent:victoryDetailsNode];
  if ([victoryDetailsNode.children count] > 0) {
    HLTableLayoutManager *layoutManager = [[HLTableLayoutManager alloc] initWithColumnCount:4
                                                                               columnWidths:@[ @(20.0f), @(0.0f) ]
                                                                         columnAnchorPoints:@[ [NSValue valueWithCGPoint:CGPointMake(0.5f, 0.5f)],
                                                                                               [NSValue valueWithCGPoint:CGPointMake(0.0f, 0.25f)],
                                                                                               [NSValue valueWithCGPoint:CGPointMake(1.0f, 0.25f)] ]
                                                                                 rowHeights:@[ @(20.0f) ]];
    layoutManager.columnSeparator = 8.0f;
    [victoryDetailsNode setHLLayoutManager:layoutManager];
    [victoryDetailsNode hlLayoutChildren];
    victoryDetailsNode.zPosition = FLZPositionGoalsOverlayContent;
    _victoryDetailsNode = victoryDetailsNode;
  }
}

- (void)layout
{
  HLScene *sceneStrong = _scene;

  NSMutableArray *layoutNodes = [NSMutableArray array];
  vector<CGSize> layoutNodeSizes;
  
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

  // note: Show multiline text in a square that won't have to change size if the interface
  // rotates to a narrower horizontal dimension.
  CGFloat edgeSizeMax = MIN(MIN(_sceneSize.width - FLLayoutNodeSpacerHorizontal * 2.0f,
                                _sceneSize.height - FLLayoutNodeSpacerVertical * 2.0f),
                            FLDSMultilineLabelParagraphWidthReadableMax);
  
  if (_introNode) {
    [layoutNodes addObject:_introNode];
    _introNode.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
    layoutNodeSizes.emplace_back(_introNode.size);
  }
  if (_truthHeaderNode) {
    [layoutNodes addObject:_truthHeaderNode];
    _truthHeaderNode.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
    layoutNodeSizes.emplace_back(_truthHeaderNode.size);
  }
  if (_truthTableNode) {
    [layoutNodes addObject:_truthTableNode];
    layoutNodeSizes.emplace_back(_truthTableNode.size);
  }
  if (_truthFooterNode) {
    [layoutNodes addObject:_truthFooterNode];
    _truthFooterNode.paragraphWidth = edgeSizeMax - FLDSMultilineLabelParagraphWidthBugWorkaroundPad;
    layoutNodeSizes.emplace_back(_truthFooterNode.size);
  }
  if (_victoryButton) {
    [layoutNodes addObject:_victoryButton];
    layoutNodeSizes.emplace_back(_victoryButton.size);
  }
  if (_victoryDetailsNode) {
    [layoutNodes addObject:_victoryDetailsNode];
    HLTableLayoutManager *layoutManager = (HLTableLayoutManager *)_victoryDetailsNode.hlLayoutManager;
    layoutNodeSizes.emplace_back(layoutManager.size);
  }
  
  SKNode *contentNode = [SKNode node];
  CGSize contentSize = CGSizeZero;
  for (NSUInteger i = 0; i < [layoutNodes count]; ++i) {
    CGSize layoutNodeSize = layoutNodeSizes[i];
    if (layoutNodeSize.width > contentSize.width) {
      contentSize.width = layoutNodeSize.width;
    }
    contentSize.height += layoutNodeSize.height;
  }
  contentSize.width += 2.0f * FLLayoutNodeSpacerHorizontal;
  contentSize.height += ([layoutNodes count] + 1) * FLLayoutNodeSpacerVertical;
  CGFloat layoutNodeY = contentSize.height / 2.0f - FLLayoutNodeSpacerVertical;
  for (NSUInteger i = 0; i < [layoutNodes count]; ++i) {
    id layoutNode = layoutNodes[i];
    CGSize layoutNodeSize = layoutNodeSizes[i];
    [layoutNode setPosition:CGPointMake(0.0f, layoutNodeY - layoutNodeSize.height / 2.0f)];
    layoutNodeY -= (layoutNodeSize.height + FLLayoutNodeSpacerVertical);
    if (!previouslyAddedToParent || [previouslyAddedToParent containsObject:layoutNode]) {
      [contentNode addChild:layoutNode];
    }
  }
  
  CGSize dismissSize = CGSizeMake(MAX(_sceneSize.width, contentSize.width),
                                  MAX(_sceneSize.height, contentSize.height));
  if (_dismissNode) {
    [sceneStrong unregisterDescendant:_dismissNode];
  }
  _dismissNode = [HLGestureTargetSpriteNode spriteNodeWithColor:[SKColor clearColor] size:dismissSize];
  _dismissNode.zPosition = FLZPositionGoalsOverlayDismissNode;
  [contentNode addChild:_dismissNode];
  HLGestureTargetTapDelegate *dismissTapDelegate = [[HLGestureTargetTapDelegate alloc] initWithHandleGestureBlock:^(UIGestureRecognizer *gestureRecognizer){
    [self FL_dismissWithNextLevel:NO];
  }];
  // note: Gesture transparency required so that pan and pinch can fall through to HLScrollNode
  // gesture target (for scrolling and scaling).
  dismissTapDelegate.gestureTransparent = YES;
  [_dismissNode setGestureTargetDelegateStrong:dismissTapDelegate];
  [sceneStrong registerDescendant:_dismissNode withOptions:[NSSet setWithObject:HLSceneChildGestureTarget]];
  
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
  CGPoint originalContentOffset = self.contentOffset;
  CGFloat originalContentScale = self.contentScale;
  CGFloat originalContentScaleMaximum = self.contentScaleMaximum;
  HLScrollNodeContentScaleMinimumMode originalContentScaleMinimumMode = self.contentScaleMinimumMode;
  
  const CGFloat FLTruthTableRevealTruthTableFlyUpScale = originalContentScale * 0.8f;
  const CGFloat FLTruthTableRevealTruthTableFlyDownScale = 1.3f;
  const NSTimeInterval FLTruthTableRevealZoomInDuration = 0.8;
  const NSTimeInterval FLTruthTableRevealDramaticPauseDuration = 0.5;
  const NSTimeInterval FLTruthTableRevealCorrectStepDuration = 0.5;
  const NSTimeInterval FLTruthTableRevealCorrectMaxDuration = 3.0;
  const NSTimeInterval FLTruthTableRevealOtherDuration = 0.8;
  const NSTimeInterval FLTruthTableRevealZoomOutDuration = 0.5;
  
  NSMutableArray *revealActions = [NSMutableArray array];
  
  SKEmitterNode *happyBurst = [[HLEmitterStore sharedStore] emitterCopyForKey:@"happyBurst"];
  happyBurst.zPosition = FLZPositionGoalsOverlayHappyBursts;
  // noob: Good practice to remove emitter node once it's finished?
  NSTimeInterval particleLifetimeMax = happyBurst.particleLifetime;
  if (happyBurst.particleLifetimeRange > 0.001f) {
    particleLifetimeMax += (happyBurst.particleLifetimeRange / 2.0f);
  }
  SKAction *removeHappyBurstAfterWait = [SKAction sequence:@[ [SKAction waitForDuration:particleLifetimeMax],
                                                              [SKAction removeFromParent] ]];
  
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
      SKSpriteNode *squareNode = [_truthTableNode squareNodeForSquare:squareIndex];
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
        happyBurstCopy.particlePositionRange = CGVectorMake(squareNode.size.width, squareNode.size.height);
        [self.contentNode addChild:happyBurstCopy];
        [happyBurstCopy runAction:removeHappyBurstAfterWait];
      }]];
      [revealActions addObject:[SKAction waitForDuration:(correctStepDuration * 0.66f)]];
    }
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
      [happyBurstCopy runAction:removeHappyBurstAfterWait];
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
      [happyBurstCopy runAction:removeHappyBurstAfterWait];
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
          [happyBurstCopy runAction:removeHappyBurstAfterWait];
        }]];
        [revealActions addObject:[SKAction waitForDuration:(FLTruthTableRevealOtherDuration * 0.66f)]];
        replaceNodes = [NSMutableArray array];
      }
    }
  }
  
  [revealActions addObject:[SKAction playSoundFileNamed:@"train-whistle-tune-1.caf" waitForCompletion:NO]];
  
  [revealActions addObject:[SKAction runBlock:^{
    [self setContentOffset:originalContentOffset
              contentScale:originalContentScale
          animatedDuration:FLTruthTableRevealZoomOutDuration
                completion:nil];
  }]];
  [revealActions addObject:[SKAction waitForDuration:FLTruthTableRevealZoomOutDuration]];
  
  [revealActions addObject:[SKAction runBlock:^{
    self.contentScaleMaximum = originalContentScaleMaximum;
    self.contentScaleMinimumMode = originalContentScaleMinimumMode;
  }]];
  
  [self runAction:[SKAction sequence:revealActions]];
}

#pragma mark -
#pragma mark Private

- (HLGridNode *)FL_truthTableCreateForTable:(FLTrackTruthTable *)trackTruthTable
                                      index:(NSUInteger)truthTableIndex
                              correctValues:(NSArray *)correctValues
                                    correct:(BOOL *)correct
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
    *correct = YES;
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
        } else {
          [contentColors addObject:FLInterfaceColorBad()];
          rowCorrect = NO;
          *correct = NO;
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
                  parent:(SKNode *)parent
{
  BOOL firstOne = YES;
  for (NSUInteger r = 0; r < [recordTexts count]; ++r) {
    
    if (firstOne) {
      [parent addChild:[SKNode node]];
      SKLabelNode *headerNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
      headerNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
      headerNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeBaseline;
      headerNode.fontSize = 14.0f;
      headerNode.fontColor = FLInterfaceColorMaybe();
      headerNode.text = NSLocalizedString(@"New Records!",
                                          @"Goals screen: header displayed over a table of new records after level victory.");
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
    newValueNode.text = [NSString stringWithFormat:NSLocalizedString(@"%@",
                                                                     @"Goals screen: displayed in a column of level results to show the {new record value} for a gameplay record."),
                         [newValues[r] stringValue]];
    [parent addChild:newValueNode];
    
    SKLabelNode *oldValueNode = [SKLabelNode labelNodeWithFontNamed:FLInterfaceFontName];
    oldValueNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeRight;
    oldValueNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeBaseline;
    oldValueNode.fontSize = 14.0f;
    oldValueNode.fontColor = FLInterfaceColorLight();
    oldValueNode.text = [NSString stringWithFormat:NSLocalizedString(@"(was %@)",
                                                                     @"Goals screen: displayed in a column of level results to show the {old record value} for a gameplay record."),
                         [oldValues[r] stringValue]];
    [parent addChild:oldValueNode];
  }
}

- (void)FL_dismissWithNextLevel:(BOOL)nextLevel
{
  HLScene *sceneStrong = _scene;
  if (sceneStrong) {
    [sceneStrong unregisterDescendant:_victoryButton];
    [sceneStrong unregisterDescendant:_dismissNode];
  }
  id <FLGoalsNodeDelegate> delegate = _delegate;
  if (delegate) {
    // noob: This will typically deallocate this goals node, which means there might be
    // problems.  But I think the blocks that call this successfully retain self, and so
    // it doesn't end up being a problem.
    [delegate goalsNode:self didDismissWithNextLevel:nextLevel];
  }
}

@end
