//
//  FLLinks.h
//  Flippy
//
//  Created by Karl Voskuil on 3/14/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#ifndef __Flippy__FLLinks__
#define __Flippy__FLLinks__

#import <SpriteKit/SpriteKit.h>

#include <unordered_map>
#include <vector>

@class FLSegmentNode;

struct FLLinksPointerPairHash
{
  size_t operator()(const std::pair<void *, void *>& key) const {
    size_t h = ((reinterpret_cast<uintptr_t>(key.first) & 0xFFFF) << 16) | (reinterpret_cast<uintptr_t>(key.second) & 0xFFFF);
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = ((h >> 16) ^ h);
    return h;
  }
};

class FLLinks
{
public:

  typedef std::unordered_map<std::pair<void *, void *>, SKShapeNode *, FLLinksPointerPairHash>::iterator iterator;
  typedef std::unordered_map<std::pair<void *, void *>, SKShapeNode *, FLLinksPointerPairHash>::const_iterator const_iterator;

  bool insert(FLSegmentNode *a, FLSegmentNode *b, SKShapeNode *connector);

  SKShapeNode *get(FLSegmentNode *a, FLSegmentNode *b) const;

  void get(FLSegmentNode *a, std::vector<FLSegmentNode *> *b) const;

  iterator begin() { return links_.begin(); }
  const_iterator begin() const { return links_.begin(); }

  iterator end() { return links_.end(); }
  const_iterator end() const { return links_.end(); }
  
  void erase(FLSegmentNode *a, FLSegmentNode *b);
  
  void erase(FLSegmentNode *a);
  
  size_t size() const { return links_.size(); }

private:
  std::unordered_map<std::pair<void *, void *>, SKShapeNode *, FLLinksPointerPairHash> links_;
};

#endif /* defined(__Flippy__FLLinks__) */
