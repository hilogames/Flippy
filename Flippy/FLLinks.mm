//
//  FLLinks.mm
//  Flippy
//
//  Created by Karl Voskuil on 3/14/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
//

#include "FLLinks.h"

#import "FLSegmentNode.h"

using namespace std;

void
FLLinks::set(FLSegmentNode *a, FLSegmentNode *b, SKShapeNode *connector)
{
  pair<iterator, bool> emplacement;
  if (a < b) {
    emplacement = links_.emplace(std::make_pair((__bridge void *)a, (__bridge void *)b), connector);
  } else {
    emplacement = links_.emplace(std::make_pair((__bridge void *)b, (__bridge void *)a), connector);
  }
  if (!emplacement.second && emplacement.first->second != connector) {
    [emplacement.first->second removeFromParent];
    emplacement.first->second = connector;
  }
}

bool
FLLinks::insert(FLSegmentNode *a, FLSegmentNode *b, SKShapeNode *connector)
{
  pair<iterator, bool> emplacement;
  if (a < b) {
    emplacement = links_.emplace(std::make_pair((__bridge void *)a, (__bridge void *)b), connector);
  } else {
    emplacement = links_.emplace(std::make_pair((__bridge void *)b, (__bridge void *)a), connector);
  }
  return emplacement.second;
}

SKShapeNode *
FLLinks::get(FLSegmentNode *a, FLSegmentNode *b) const
{
  if (a < b) {
    auto link = links_.find(std::make_pair((__bridge void *)a, (__bridge void *)b));
    if (link != links_.end()) {
      return link->second;
    }
  } else {
    auto link = links_.find(std::make_pair((__bridge void *)b, (__bridge void *)a));
    if (link != links_.end()) {
      return link->second;
    }
  }
  return nil;
}

void
FLLinks::get(FLSegmentNode *a, std::vector<FLSegmentNode *> *b) const
{
  // note: It would be faster, but more complicated, to define an iterator interface
  // rather than copying pointers into a vector.
  
  // note: Implemented as a nasty linear thing for now.

  for (auto link = links_.begin(); link != links_.end(); ++link) {
    if ((__bridge void *)a == link->first.first) {
      b->emplace_back((__bridge FLSegmentNode *)link->first.second);
    } else if ((__bridge void *)a == link->first.second) {
      b->emplace_back((__bridge FLSegmentNode *)link->first.first);
    }
  }
}

void
FLLinks::erase(FLSegmentNode *a, FLSegmentNode *b)
{
  if (a < b) {
    auto link = links_.find(std::make_pair((__bridge void *)a, (__bridge void *)b));
    if (link != links_.end()) {
      [link->second removeFromParent];
      links_.erase(link);
      return;
    }
  } else {
    auto link = links_.find(std::make_pair((__bridge void *)b, (__bridge void *)a));
    if (link != links_.end()) {
      [link->second removeFromParent];
      links_.erase(link);
      return;
    }
  }
}

void
FLLinks::erase(FLSegmentNode *a)
{
  // note: Implemented as a nasty linear thing for now.
  auto link = links_.begin();
  while (link != links_.end()) {
    if ((__bridge void *)a == link->first.first) {
      [link->second removeFromParent];
      link = links_.erase(link);
    } else if ((__bridge void *)a == link->first.second) {
      [link->second removeFromParent];
      link = links_.erase(link);
    } else {
      ++link;
    }
  }
}

void
linksSetSwitchPathId(const FLLinks& links, FLSegmentNode *segmentNode, int pathId, BOOL animated)
{
  [segmentNode setSwitchPathId:pathId animated:animated];
  vector<FLSegmentNode *> linkedSegmentNodes;
  links.get(segmentNode, &linkedSegmentNodes);
  for (auto linkedSegmentNode : linkedSegmentNodes) {
    [linkedSegmentNode setSwitchPathId:pathId animated:animated];
  }
}


void
linksSetSwitchPathId(const FLLinks& links, FLSegmentNode *segmentNode, int pathId, unordered_map<void *, int> *switchPathIds)
{
  (*switchPathIds)[(__bridge void *)segmentNode] = pathId;
  vector<FLSegmentNode *> linkedSegmentNodes;
  links.get(segmentNode, &linkedSegmentNodes);
  for (auto linkedSegmentNode : linkedSegmentNodes) {
    (*switchPathIds)[(__bridge void *)linkedSegmentNode] = pathId;
  }
}

int
linksToggleSwitchPathId(const FLLinks& links, FLSegmentNode *segmentNode, BOOL animated)
{
  int pathId = [segmentNode toggleSwitchPathIdAnimated:animated];
  vector<FLSegmentNode *> linkedSegmentNodes;
  links.get(segmentNode, &linkedSegmentNodes);
  for (auto linkedSegmentNode : linkedSegmentNodes) {
    [linkedSegmentNode setSwitchPathId:pathId animated:animated];
  }
  return pathId;
}

NSArray *
linksIntersect(const FLLinks& links, NSSet *segmentNodePointers)
{
  // note: Linear traversal of links, for now, since the FLLinks::get() on a single
  // segment does a linear traversal also.
  NSMutableArray *intersectingLinks = [NSMutableArray array];
  for (auto link : links) {
    FLSegmentNode *fromSegmentNode = (__bridge FLSegmentNode *)link.first.first;
    NSValue *fromSegmentNodePointer = [NSValue valueWithPointer:(void *)fromSegmentNode];
    if (![segmentNodePointers containsObject:fromSegmentNodePointer]) {
      continue;
    }
    FLSegmentNode *toSegmentNode = (__bridge FLSegmentNode *)link.first.second;
    NSValue *toSegmentNodePointer = [NSValue valueWithPointer:(void *)toSegmentNode];
    if (![segmentNodePointers containsObject:toSegmentNodePointer]) {
      continue;
    }
    [intersectingLinks addObject:fromSegmentNode];
    [intersectingLinks addObject:toSegmentNode];
  }
  return intersectingLinks;
}
