//
//  FLLinks.mm
//  Flippy
//
//  Created by Karl Voskuil on 3/14/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#include "FLLinks.h"

using namespace std;

bool
FLLinks::insert(FLSegmentNode *a, FLSegmentNode *b, SKShapeNode *connector)
{
  pair<iterator, bool> emplacement = links_.emplace(std::make_pair((__bridge void *)a, (__bridge void *)b), connector);
  return emplacement.second;
}

SKShapeNode *
FLLinks::get(FLSegmentNode *a, FLSegmentNode *b) const
{
  auto link = links_.find(std::make_pair((__bridge void *)a, (__bridge void *)b));
  if (link != links_.end()) {
    return link->second;
  }
  link = links_.find(std::make_pair((__bridge void *)b, (__bridge void *)a));
  if (link != links_.end()) {
    return link->second;
  }
  return nil;
}

//void
//FLLinks::get(FLSegmentNode *a, std::vector<FLSegmentNode *> *b) const
//{
//  // note: It would be faster, but more complicated, to define an iterator interface.
//  
//  // note: Implemented as a nasty linear thing for now.
//  for (auto& link : links_) {
//    if ((__bridge void *)a == link.first.first) {
//      b->emplace_back((__bridge FLSegmentNode *)link.first.second);
//    } else if ((__bridge void *)a == link.first.second) {
//      b->emplace_back((__bridge FLSegmentNode *)link.first.first);
//    }
//  }
//}

void
FLLinks::erase(FLSegmentNode *a, FLSegmentNode *b)
{
  auto link = links_.find(std::make_pair((__bridge void *)a, (__bridge void *)b));
  if (link != links_.end()) {
    [link->second removeFromParent];
    links_.erase(link);
    return;
  }
  link = links_.find(std::make_pair((__bridge void *)b, (__bridge void *)a));
  if (link != links_.end()) {
    [link->second removeFromParent];
    links_.erase(link);
    return;
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
