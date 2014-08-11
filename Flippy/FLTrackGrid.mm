//
//  FLTrackGrid.mm
//  Flippy
//
//  Created by Karl Voskuil on 2/27/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#include "FLTrackGrid.h"

#include <tgmath.h>
#include <unordered_set>

#include "FLLinks.h"
#import "FLPath.h"
#include "fnv.h"

using namespace std;
using namespace hash;

const size_t FLTrackGridAdjacentMax = 4;

void
FLTrackGrid::import(SKNode *parentNode)
{
  for (SKNode *childNode in [parentNode children]) {
    if (![childNode isKindOfClass:[FLSegmentNode class]]) {
      continue;
    }
    int gridX;
    int gridY;
    FLTrackGrid::convert(childNode.position, segmentSize_, &gridX, &gridY);
    grid_[{ gridX, gridY }] = (FLSegmentNode *)childNode;
  }
}

vector<int>
FLTruthTable::inputValuesFirst(int inputSize)
{
  vector<int> inputValues(static_cast<size_t>(inputSize), 0);
  return std::move(inputValues);
}

bool
FLTruthTable::inputValuesSuccessor(vector<int>& inputValues, int valueCardinality)
{
  int carryIndex = static_cast<int>(inputValues.size()) - 1;
  while (carryIndex >= 0) {
    if (inputValues[static_cast<size_t>(carryIndex)] == valueCardinality - 1) {
      inputValues[static_cast<size_t>(carryIndex)] = 0;
    } else {
      ++inputValues[static_cast<size_t>(carryIndex)];
      break;
    }
    --carryIndex;
  }
  return (carryIndex >= 0);
}

FLTruthTable::FLTruthTable(int inputSize, int outputSize, int valueCardinality)
  : inputSize_(inputSize), outputSize_(outputSize), valueCardinality_(valueCardinality)
{
  int rowCount = FLTruthTable::getRowCount(inputSize, valueCardinality);
  results_.reserve(static_cast<size_t>(rowCount * outputSize));
}

int
FLTruthTable::getRowCount(int inputSize, int valueCardinality)
{
  int rowCount = 1;
  for (int i = 0; i < inputSize; ++i) {
    rowCount *= valueCardinality;
  }
  return rowCount;
}

int *
FLTruthTable::outputValues(const vector<int>& inputValues)
{
  int row = 0;
  for (auto i : inputValues) {
    row = row * valueCardinality_ + i;
  }
  return results_.data() + row * outputSize_;
}

@implementation FLTrackTruthTable
{
  int _valueCardinality;
  vector<FLTruthTable> _truthTables;
}

- (id)initWithCardinality:(int)valueCardinality
{
  self = [super init];
  if (self) {
    _state = FLTrackTruthTableStateMissingSegments;
    _valueCardinality = valueCardinality;
  }
  return self;
}

- (void)setPlatformStartSegmentNodes:(NSArray *)platformStartSegmentNodes
{
  _platformStartSegmentNodes = platformStartSegmentNodes;
  [self FL_resizeTruthTables];
}

- (void)setInputSegmentNodes:(NSArray *)inputSegmentNodes
{
  _inputSegmentNodes = inputSegmentNodes;
  [self FL_resizeTruthTables];
}

- (void)setOutputSegmentNodes:(NSArray *)outputSegmentNodes
{
  _outputSegmentNodes = outputSegmentNodes;
  [self FL_resizeTruthTables];
}

- (vector<FLTruthTable>&)truthTables
{
  return _truthTables;
}

- (FLTruthTable *)firstTruthTable
{
  if (_truthTables.empty()) {
    return nullptr;
  }
  return &_truthTables[0];
}

- (void)FL_resizeTruthTables
{
  if (!_inputSegmentNodes || !_outputSegmentNodes || !_platformStartSegmentNodes) {
    _state = FLTrackTruthTableStateMissingSegments;
    return;
  }
  _truthTables.clear();
  NSUInteger inputCount = [_inputSegmentNodes count];
  NSUInteger outputCount = [_outputSegmentNodes count];
  NSUInteger platformStartCount = [_platformStartSegmentNodes count];
  if (inputCount == 0 || outputCount == 0 || platformStartCount == 0) {
    _state = FLTrackTruthTableStateMissingSegments;
    return;
  }
  _truthTables.reserve(platformStartCount);
  for (NSUInteger ps = 0; ps < platformStartCount; ++ps) {
    _truthTables.emplace_back(static_cast<int>(inputCount), static_cast<int>(outputCount), _valueCardinality);
  }
  _state = FLTrackTruthTableStateInitialized;
}

@end

void
trackGridIsOnEdge(const FLTrackGrid& trackGrid, CGPoint worldLocation, bool *onEdgeX, bool *onEdgeY)
{
  CGFloat FLEpsilon = 0.001f;
  
  CGFloat segmentSize = trackGrid.segmentSize();
  CGFloat halfSegmentSize = segmentSize / 2.0f;
  
  CGFloat edgeXRemainder = fabs(fmod(worldLocation.x + halfSegmentSize, segmentSize));
  *onEdgeX = (edgeXRemainder < FLEpsilon || edgeXRemainder > segmentSize - FLEpsilon);
  
  CGFloat edgeYRemainder = fabs(fmod(worldLocation.y + halfSegmentSize, segmentSize));
  *onEdgeY = (edgeYRemainder < FLEpsilon || edgeYRemainder > segmentSize - FLEpsilon);
}

size_t
trackGridFindAdjacent(const FLTrackGrid& trackGrid, CGPoint worldLocation, __strong FLSegmentNode *adjacent[])
{
  CGFloat segmentSize = trackGrid.segmentSize();
  CGFloat halfSegmentSize = segmentSize / 2.0f;

  int gridX;
  int gridY;
  trackGrid.convert(worldLocation, &gridX, &gridY);

  bool onEdgeX;
  bool onEdgeY;
  trackGridIsOnEdge(trackGrid, worldLocation, &onEdgeX, &onEdgeY);
  
  size_t adjacentCount = 0;
  if (onEdgeX && onEdgeY) {
    // Corner.
    int rightGridX = int(floor((worldLocation.x + halfSegmentSize) / segmentSize + 0.5f));
    int topGridY = int(floor((worldLocation.y + halfSegmentSize) / segmentSize + 0.5f));
    for (int gx = rightGridX - 1; gx <= rightGridX; ++gx) {
      for (int gy = topGridY - 1; gy <= topGridY; ++gy) {
        adjacent[adjacentCount] = trackGrid.get(gx, gy);
        if (adjacent[adjacentCount]) {
          ++adjacentCount;
        }
      }
    }
  } else if (onEdgeX) {
    // Left or right edge.
    int rightGridX = int(floor((worldLocation.x + halfSegmentSize) / segmentSize + 0.5f));
    adjacent[adjacentCount] = trackGrid.get(rightGridX - 1, gridY);
    if (adjacent[adjacentCount]) {
      ++adjacentCount;
    }
    adjacent[adjacentCount] = trackGrid.get(rightGridX, gridY);
    if (adjacent[adjacentCount]) {
      ++adjacentCount;
    }
  } else if (onEdgeY) {
    // Top or bottom edge.
    int topGridY = int(floor((worldLocation.y + halfSegmentSize) / segmentSize + 0.5f));
    adjacent[adjacentCount] = trackGrid.get(gridX, topGridY - 1);
    if (adjacent[adjacentCount]) {
      ++adjacentCount;
    }
    adjacent[adjacentCount] = trackGrid.get(gridX, topGridY);
    if (adjacent[adjacentCount]) {
      ++adjacentCount;
    }
  } else {
    // Middle.
    adjacent[adjacentCount] = trackGrid.get(gridX, gridY);
    if (adjacent[adjacentCount]) {
      ++adjacentCount;
    }
  }
  return adjacentCount;
}

bool
trackGridFindClosestOnTrackPoint(const FLTrackGrid& trackGrid,
                                 CGPoint worldLocation,
                                 int gridSearchDistance, CGFloat progressPrecision,
                                 CGFloat *onTrackDistance, CGPoint *onTrackPoint, CGFloat *onTrackRotation,
                                 FLSegmentNode **onTrackSegment, int *onTrackPathId, CGFloat *onTrackProgress)
{
  int gridX;
  int gridY;
  trackGrid.convert(worldLocation, &gridX, &gridY);

  CGFloat segmentSize = trackGrid.segmentSize();

  // Do a less-precise search among all nearby segments.
  CGFloat closestSegmentPrecision = progressPrecision * 10.0f;
  FLSegmentNode *closestSegmentNode = nil;
  CGFloat closestDistance;
  for (int gx = gridX - gridSearchDistance; gx <= gridX + gridSearchDistance; ++gx) {
    for (int gy = gridY - gridSearchDistance; gy <= gridY + gridSearchDistance; ++gy) {
      FLSegmentNode *segmentNode = trackGrid.get(gx, gy);
      if (!segmentNode) {
        continue;
      }
      CGFloat distance;
      if ([segmentNode getClosestOnTrackPoint:nil distance:&distance rotation:nil path:nil progress:nil
                             forOffTrackPoint:worldLocation scale:segmentSize precision:closestSegmentPrecision]) {
        if (!closestSegmentNode || distance < closestDistance) {
          closestSegmentNode = segmentNode;
          closestDistance = distance;
        }
      }
    }
  }
  if (!closestSegmentNode) {
    return NO;
  }

  // Do a precise search on the closest segment.
  *onTrackSegment = closestSegmentNode;
  [closestSegmentNode getClosestOnTrackPoint:onTrackPoint distance:onTrackDistance rotation:onTrackRotation path:onTrackPathId progress:onTrackProgress
                            forOffTrackPoint:worldLocation scale:segmentSize precision:progressPrecision];

  return YES;
}

bool
trackGridFindConnecting(const FLTrackGrid& trackGrid,
                        FLSegmentNode *startSegmentNode, int startPathId, CGFloat startProgress,
                        FLSegmentNode **connectingSegmentNode, int *connectingPathId, CGFloat *connectingProgress,
                        const unordered_map<void *, int> *switchPathIds)
{
  // note: The paths know statically whether or not they connect at a particular corner, and what their
  // tangent is at that point.  However, that would require extending their interface (as well as adding
  // more compile-time information to the file), and it appeals to me to figure out what we need to know
  // at runtime using getPoint() and getTangent() and testing all endpoints.  My instinct is that it won't
  // be much slower.

  CGFloat segmentSize = trackGrid.segmentSize();
  CGPoint endPoint;
  CGFloat startRotation;
  [startSegmentNode getPoint:&endPoint rotation:&startRotation forPath:startPathId progress:startProgress scale:segmentSize];

  // note: Currently segments only connect at corners.  If the end point isn't on a corner (e.g.
  // for the end of a platform) then it doesn't connect to anything.
  bool onEdgeX;
  bool onEdgeY;
  trackGridIsOnEdge(trackGrid, endPoint, &onEdgeX, &onEdgeY);
  if (!onEdgeX || !onEdgeY) {
    return false;
  }

  CGFloat halfSegmentSize = segmentSize / 2.0f;
  int rightGridX = int(floor((endPoint.x + halfSegmentSize) / segmentSize + 0.5f));
  int topGridY = int(floor((endPoint.y + halfSegmentSize) / segmentSize + 0.5f));

  for (int gx = rightGridX - 1; gx <= rightGridX; ++gx) {
    for (int gy = topGridY - 1; gy <= topGridY; ++gy) {

      FLSegmentNode *segmentNode = trackGrid.get(gx, gy);
      if (!segmentNode || segmentNode == startSegmentNode) {
        continue;
      }

      int switchPathId = segmentNode.switchPathId;
      if (switchPathIds && switchPathId != FLSegmentSwitchPathIdNone) {
        auto spi = switchPathIds->find((__bridge void *)segmentNode);
        if (spi != switchPathIds->end()) {
          switchPathId = spi->second;
        }
      }

      if ([segmentNode getConnectingPath:connectingPathId
                                progress:connectingProgress
                             forEndPoint:endPoint
                                rotation:startRotation
                                progress:startProgress
                                   scale:segmentSize
                            switchPathId:switchPathId]) {
        *connectingSegmentNode = segmentNode;
        return true;
      }
    }
  }
  return false;
}

struct FLRunState
{
  FLRunState(void *currentSegmentNode_, int currentPathId_, int currentDirection_) : currentSegmentNode(currentSegmentNode_), currentPathId(currentPathId_), currentDirection(currentDirection_) {}
  bool operator==(const FLRunState& rhs) const {
    return currentSegmentNode == rhs.currentSegmentNode
      && currentPathId == rhs.currentPathId
      && currentDirection == rhs.currentDirection;
  }
  void *currentSegmentNode;
  int currentPathId;
  int currentDirection;
};

struct FLRunStateHasher
{
  size_t operator()(const FLRunState& runState) const {
    fnv<sizeof(size_t) * 8> hasher;
    hasher(reinterpret_cast<const char *>(&runState.currentSegmentNode), sizeof(runState.currentSegmentNode));
    hasher(reinterpret_cast<const char *>(&runState.currentPathId), sizeof(runState.currentPathId));
    return hasher(reinterpret_cast<const char *>(&runState.currentDirection), sizeof(runState.currentDirection));
  }
};

static bool
FL_runInputsToOutputs(const FLTrackGrid& trackGrid,
                      const FLLinks& links,
                      unordered_map<void *, int>& switchPathIds,
                      FLSegmentNode *platformStartSegmentNode,
                      NSArray *inputSegmentNodes,
                      const vector<int>& inputValues,
                      NSArray *outputSegmentNodes,
                      int *outputValues,
                      bool *infiniteLoopDetected)
{
  // Set input values and propagate via links.
  size_t i = 0;
  for (FLSegmentNode *inputSegmentNode in inputSegmentNodes) {
    linksSetSwitchPathId(links, inputSegmentNode, inputValues[i], &switchPathIds);
    ++i;
  }

  unordered_set<FLRunState, FLRunStateHasher> previousRunStates;

  FLSegmentNode *currentSegmentNode = platformStartSegmentNode;
  int currentPathId = 0;
  CGFloat currentProgress = 1.0f;

  while (true) {

    // Trigger switch on current segment node if appropriate.
    //
    // note: Going "against" the switch, not "with" it, triggers it to change value according
    // to the path just taken.
    int currentDirection = (currentProgress > 0.5f ? FLPathDirectionIncreasing : FLPathDirectionDecreasing);
    if (currentSegmentNode.switchPathId != FLSegmentSwitchPathIdNone) {
      int goingWithSwitchDirection = [currentSegmentNode pathDirectionGoingWithSwitchForPath:currentPathId];
      if (currentDirection != goingWithSwitchDirection) {
        linksSetSwitchPathId(links, currentSegmentNode, currentPathId, &switchPathIds);
      }
    }
    
    // Detect infinite loop.
    //
    // note: Infinite loop detection is non-trivial.  Machine state is represented by the value
    // of every switch and the current segment/path/direction of the train.  This could be
    // reduced a bit by not considering segments that have only one path; are there other ways
    // to reduce the state size?  No matter what, it's potentially a lot of data to be storing
    // and checking.  For now, just do a simplistic check based on segment/path/direction.
    if (currentSegmentNode.pathCount > 1) {
      auto emplacement = previousRunStates.emplace((__bridge void *)currentSegmentNode, currentPathId, currentDirection);
      if (!emplacement.second) {
        *infiniteLoopDetected = true;
        break;
      }
    }
    
    FLSegmentNode *connectingSegmentNode;
    int connectingPathId;
    CGFloat connectingProgress;
    if (!trackGridFindConnecting(trackGrid,
                                 currentSegmentNode, currentPathId, currentProgress,
                                 &connectingSegmentNode, &connectingPathId, &connectingProgress,
                                 &switchPathIds)) {
      break;
    }

    currentSegmentNode = connectingSegmentNode;
    currentPathId = connectingPathId;
    currentProgress = (connectingProgress < 0.01f ? 1.0f : 0.0f);
  }

  // Copy output values.
  size_t o = 0;
  for (FLSegmentNode *outputSegmentNode in outputSegmentNodes) {
    outputValues[o] = switchPathIds[(__bridge void *)outputSegmentNode];
    ++o;
  }
  return true;
}

FLTrackTruthTable *
trackGridGenerateTruthTable(const FLTrackGrid& trackGrid, const FLLinks& links, bool sortByLabel)
{
  const int FLValueCardinality = 2;
  unordered_map<void *, int> switchPathIds;

  NSMutableArray *platformStartSegmentNodes = [NSMutableArray array];
  NSMutableArray *inputSegmentNodes = [NSMutableArray array];
  NSMutableArray *outputSegmentNodes = [NSMutableArray array];
  for (auto s : trackGrid) {
    FLSegmentNode *segmentNode = s.second;
    switch (segmentNode.segmentType) {
      case FLSegmentTypeReadoutInput:
        [inputSegmentNodes addObject:segmentNode];
        break;
      case FLSegmentTypeReadoutOutput:
        [outputSegmentNodes addObject:segmentNode];
        break;
      case FLSegmentTypePlatformStart:
        [platformStartSegmentNodes addObject:segmentNode];
        break;
      default:
        break;
    }
    if (segmentNode.switchPathId != FLSegmentSwitchPathIdNone) {
      switchPathIds.emplace((__bridge void *)segmentNode, segmentNode.switchPathId);
    }
  }

  int platformStartCount = static_cast<int>([platformStartSegmentNodes count]);
  int inputCount = static_cast<int>([inputSegmentNodes count]);
  int outputCount = static_cast<int>([outputSegmentNodes count]);
  
  if (sortByLabel) {
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"label" ascending:YES];
    [inputSegmentNodes sortUsingDescriptors:@[ sortDescriptor ]];
    [outputSegmentNodes sortUsingDescriptors:@[ sortDescriptor ]];
  }
  
  FLTrackTruthTable *trackTruthTable = [[FLTrackTruthTable alloc] initWithCardinality:FLValueCardinality];
  trackTruthTable.platformStartSegmentNodes = platformStartSegmentNodes;
  trackTruthTable.inputSegmentNodes = inputSegmentNodes;
  trackTruthTable.outputSegmentNodes = outputSegmentNodes;

  if (platformStartCount == 0 || inputCount == 0 || outputCount == 0) {
    return trackTruthTable;
  }

  vector<int> inputValues = FLTruthTable::inputValuesFirst(inputCount);
  int row = 0;
  do {
    for (int platformStart = 0; platformStart < platformStartCount; ++platformStart) {
      unordered_map<void *, int> switchPathIdsCopy(switchPathIds);
      FLTruthTable& truthTable = trackTruthTable.truthTables[static_cast<size_t>(platformStart)];
      bool infiniteLoopDetected = false;
      FL_runInputsToOutputs(trackGrid,
                            links,
                            switchPathIdsCopy,
                            [platformStartSegmentNodes objectAtIndex:static_cast<NSUInteger>(platformStart)],
                            inputSegmentNodes,
                            inputValues,
                            outputSegmentNodes,
                            truthTable.outputValues(inputValues),
                            &infiniteLoopDetected);
      if (infiniteLoopDetected) {
        // note: For now, no need to say which platform start and set of inputs
        // led to the infinite loop.  If the caller cares, we can certainly return
        // that information.
        trackTruthTable.state = FLTrackTruthTableStateInfiniteLoopDetected;
      }
    }
    ++row;
  } while (FLTruthTable::inputValuesSuccessor(inputValues, FLValueCardinality));

  return trackTruthTable;
}

/*
@implementation FLTrackGridWrapper
{
  const FLTrackGrid *_rawTrackGrid;
  unique_ptr<FLTrackGrid> _trackGrid;
}

- (id)initWithTrackGrid:(std::unique_ptr<FLTrackGrid> &)trackGrid
{
  self = [super init];
  if (self) {
    _trackGrid = std::move(trackGrid);
    _rawTrackGrid = _trackGrid.get();
  }
  return self;
}

- (id)initWithRawTrackGrid:(const FLTrackGrid *)rawTrackGrid
{
  self = [super init];
  if (self) {
    _rawTrackGrid = rawTrackGrid;
  }
  return self;
}

- (unique_ptr<FLTrackGrid>&)trackGrid
{
  return _trackGrid;
}

- (const FLTrackGrid *)rawTrackGrid
{
  if (_trackGrid) {
    [NSException raise:@"FLTrackGridWrapperManaged" format:@"Raw pointer access not allowed when wrapper initialized with a managed pointer."];
  }
  return _rawTrackGrid;
}

@end
*/
