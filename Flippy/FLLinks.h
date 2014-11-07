//
//  FLLinks.h
//  Flippy
//
//  Created by Karl Voskuil on 3/14/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
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

  void set(FLSegmentNode *a, FLSegmentNode *b, SKShapeNode *connector);

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

/**
 * A standard and convenient method for setting the switch path id of a segment
 * and propagating that value according to links.
 *
 * The code is trivial, and yet there are a couple important standards enforced
 * here (which are good to reuse among all callers):
 *
 *   1. It is assumed that it is possible for segments to be linked and yet have
 *      different switch path ids.  Therefore, linked sgements will have their
 *      path ids set to the passed value even if the path id of the main segment
 *      is already set to the passed value.
 *
 *   2. Propagation is not recursive; that is, switch path ids are set for the
 *      main segment and any linked segments, but not for segments linked to the
 *      linked segments.
 *
 * The second version of the function takes a map of segment switch values: It does
 * not get or set switch values on the actual segment nodes, but instead reads and/or
 * changes them in the map.
 */
void linksSetSwitchPathId(const FLLinks& links, FLSegmentNode *segmentNode, int pathId, BOOL animated);
void linksSetSwitchPathId(const FLLinks& links, FLSegmentNode *segmentNode, int pathId, std::unordered_map<void *, int> *switchPathIds);

/**
 * A standard and convenient way to toggle the switch path id of a segment and
 * propagate the new value according to links.
 *
 * Behaves according to the same standards as linksSetSwitchPathId.
 */
int linksToggleSwitchPathId(const FLLinks& links, FLSegmentNode *segmentNode, BOOL animated);

/**
 * Returns a list of segments that are linked in the passed FLLinks and also
 * both exist in the passed segment node collection.
 *
 * note: The operation is fairly trivial; the distinction is mostly in the particular
 * containers passed and returned.  The main reason this is included in FLLinks, though,
 * is because the performance of the implementation might change greatly depending on the
 * implementation of FLLinks.
 *
 * @param Links.
 *
 * @param An NSSet of NSValues representing segment pointers.
 *
 * @return A list of linked segment objects in pairs: The first segment is linked to the
 *         second; the third to the fourth; etc.  (Objects are retained FLSegmentNode pointers.)
 */
NSArray *linksIntersect(const FLLinks& links, NSSet *segmentNodePointers);

#endif /* defined(__Flippy__FLLinks__) */
