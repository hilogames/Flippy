//
//  QuadTree.h
//  Flippy
//
//  Created by Karl Voskuil on 1/17/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

// TODO: Make a real quadtree.  Hacked for now.

// TODO: An easy intermediate step would be to cut down on the number of pointers in the
// tree/table/whatever by making a basic entry a block of values rather than a single
// value.  Call it a block or sector or slab or cell; 4x4 or 8x8 or something.

#ifndef __Flippy__QuadTree__
#define __Flippy__QuadTree__

#include <iostream>
#include <unordered_map>

namespace HLCommon {

struct QuadTreeKeyHash
{
  size_t operator()(const std::pair<int, int>& key) const {
    size_t h = (size_t)((key.first & 0xFFFF) << 16) | (key.second & 0xFFFF);
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = ((h >> 16) ^ h);
    return h;
  }
};

template<typename Value>
class QuadTree
{
public:

  typedef typename std::unordered_map<std::pair<int, int>, Value, QuadTreeKeyHash>::iterator iterator;
  typedef typename std::unordered_map<std::pair<int, int>, Value, QuadTreeKeyHash>::const_iterator const_iterator;

  iterator begin();
  const_iterator begin() const;
  iterator end();
  const_iterator end() const;

  iterator find(int x, int y);
  const_iterator find(int x, int y) const;

  size_t size() const;

  Value get(int x, int y, Value&& defaultValue) const;

  Value& operator[](std::pair<int, int> xy);

  void erase(int x, int y);

private:
  std::unordered_map<std::pair<int, int>, Value, QuadTreeKeyHash> grid_;
};

template<typename Value>
typename QuadTree<Value>::iterator
QuadTree<Value>::begin()
{
  return grid_.begin();
}

template<typename Value>
typename QuadTree<Value>::const_iterator
QuadTree<Value>::begin() const
{
  return grid_.begin();
}

template<typename Value>
typename QuadTree<Value>::iterator
QuadTree<Value>::end()
{
  return grid_.end();
}

template<typename Value>
typename QuadTree<Value>::const_iterator
QuadTree<Value>::end() const
{
  return grid_.end();
}

template<typename Value>
typename QuadTree<Value>::iterator
QuadTree<Value>::find(int x, int y)
{
  return grid_.find(std::make_pair(x, y));
}

template<typename Value>
typename QuadTree<Value>::const_iterator
QuadTree<Value>::find(int x, int y) const
{
  return grid_.find(std::make_pair(x, y));
}

template<typename Value>
size_t
QuadTree<Value>::size() const
{
  return grid_.size();
}

template<typename Value>
Value
QuadTree<Value>::get(int x, int y, Value&& defaultValue) const
{
  auto i = grid_.find(std::make_pair(x, y));
  if (i != grid_.end()) {
    return i->second;
  }
  return std::move(defaultValue);
}

template<typename Value>
Value&
QuadTree<Value>::operator[](std::pair<int, int> xy)
{
  return grid_[xy];
}

template<typename Value>
void
QuadTree<Value>::erase(int x, int y)
{
  grid_.erase(std::make_pair(x, y));
}

} /* namespace HLCommon */

#endif /* defined(__Flippy__QuadTree__) */
