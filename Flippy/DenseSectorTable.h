//
//  DenseSectorTable.h
//  Flippy
//
//  Created by Karl Voskuil on 1/17/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
//

#ifndef __Flippy__DenseSectorTable__
#define __Flippy__DenseSectorTable__

#include <assert.h>
#include <iostream>
#include <vector>
#include <unordered_map>

namespace HLCommon {

/**
 Implements an infinite integer-indexed two-dimensional grid as a hash table of sectors;
 each sector is a preallocated block of values (which allows dense data in the sector
 without increased memory usage).

 ## Missing Sector (Regional) Interface

 The sector interface is an important part of this structure.  For example, to conserve
 memory, the owner can get a block of values, write them to disk, erase them from the
 table, and then set them again later on-demand.

 Buuuuuut . . . you might notice the interface doesn't yet exist, because it doesn't have
 any current users.  Ideas for the design when it is added:

 - Big question is how to identify sectors in the interface.  Right now the table uses
   "sector coordinates" internally, but that seems unfortunate to expose.  Probably keep
   using point coordinates to find sector iterators.  That would imply we should reuse
   `DenseSectorTableIterator` when doing sector operations; it will return point
   coordinates when dereferenced, which can be used to find the sector again, so good.
   However, it will be slightly annoying for the user to test sector identity: for
   instance, point coordinates `(1,2)` and `(1,3)` might refer to the same sector, but
   `(1,2)` and `(1,4)` might not.

 - Getting and setting sectors: iterator interface.

   For setting, would need a sector insertion method, and also an iterator option for
   iterating through the entire sector including unset points.  This, in turn, would
   obviate the need for returning point coordinates when dereferencing the iterator (which
   currently feels a little dirty, since those coordinates don't actually exist in the
   data structure, and so can't be accessed with operator->().

     iterator beginSector(x, y, iterateOnNullValues = false);
     const_iterator beginSector(x, y, iterateOnNullValues = false);
     iterator endSector(x, y, iterateOnNullValues = false);
     const_iterator endSector(x, y, iterateOnNullValues = false);

     pair<iterator, bool> insertSector(x, y, iterateOnNullValues = false);

 - Erasing sectors: iterator interface and point coordinate interface.

     void eraseSector(x, y);
     void eraseSector(const_iterator);

 - Other non-iterator sector information support (already implemented):

     size_t sectorCount();
     size_t sectorPointCount(x, y);
     bool sectorEmpty(x, y);
     size_t sectorSize();

 ## Not a QuadTree

 The placeholder implementation for this data struture was just an `unordered_map` of
 `pair<int, int>` => `Value`.  And it had a note: "Make a real quadtree.  Hacked for now."

 But this is not a quadtree.  Here's the reasoning:

 - First, note that application memory is dominated by the SpriteKit side of things, but
   it is nevertheless good to do memory planning, especially if we're anticipating an
   infinite grid.

   - In the original naive `unordered_map`, I'm counting 40 bytes per segment node: 16
     bytes for X and Y coordinates; 8 bytes for FLSegmentNode *; 8 bytes for the "next"
     pointer in the linked list; 8 bytes for the bucket if `max_load_factor` is not more
     than 1.  (I couldn't quite see those last 8 bytes, but I found the 32 pretty easily
     running Alloactions instrument.)

   - The current arbitrary world size 101x101 means 10,201 maximum nodes; call it 10K.
     It's not clear how sparse or dense we expect the data to be; the best design should
     benefit/punish sparse and dense tracks equally.  From this point of view, it would
     probably be better to pre-allocate a big array as a constant memory requirement
     (~80KB) rather than having the memory usage increase with track density from empty
     world (0KB) to a full unordered_map (~400KB).

   - Test demonstrating relative memory use of FLTrackGrid to application.

     - Load a saved sandbox with 0 segments:    58MB (debug) 57MB (release)

     - Load a saved sandbox with 800 segments:  61MB (debug) 60MB (release)

     - Load a saved sandbox with 2400 segments: 68MB (debug) 66MB (release)

   So with 2,400 segments we'd expect the `unordered_map` to be taking up about 96KB.
   This is only 1% of the total memory increase.

 - We'd like to do an infinite grid, in which case we need a data structure that handles
   sparse data.  In case the memory overhead gets too large, we'd like to be able to
   persist sectors (regions, cells, blocks) to disk and load them on-demand.

   - A simple `unordered_map` handles sparse data acceptably, but it's hard to picture
     loading and unloading sectors by doing lookups on individual points in the table.

   - Common implementations of a quadtree have leaf nodes which are the equivalent of
     sectors: they hold 1 or 4 or N data points in a certain region; the region is split
     into four new setors when the number of data points in the leaf node gets too large.

   - Considered as collection (or organization) of sectors, then, the quadtree seems
     directly comparable to other ways of organizing sectors: The sectors could be
     organized in a list, (quad)tree, or table, just like anything else.  Organizing them
     in a tree has particular benefits: Trees are ordered, and so better support ranged
     queries.  And trees support arbitrary precision of coordinates in the sector.  These
     two considerations are especially potent in combination: It is difficult and
     inefficient to do a ranged query across data of arbitrary precision using only a
     lookup table.

   - For our purposes, though, we have a fixed precision (x and y coordinates are
     integers), a constant data density expectation (no cities vs. oceans like in
     geographical data), and little need for ranged queries.

   - So for organization of sectors: A table seems simple and efficient.  For now.

 - How should data be represented in the sector, then?  In quadtree implementations I've
   reviewed, it's common to keep the data points in a list in each leaf node -- although
   because of the overall tree shape, and because leaf nodes usually don't hold many data
   points, the essence of the data representation is tree-like.  Discounting lists, then,
   which seem to have little advantage over trees, there are three main choices: tree,
   table, or preallocated block of indexed memory (vector).

   - If the data is very sparse, tree and table will do better than vector in terms of
     memory.

   - Again, tree is the best choice to support ordered queries.

   - Tree and table support iteration/traversal more efficiently than vector, in particular
     for sparse data.

   - Vector requires the caller provide an explicit "unset" or "null" data value.

   - For all the above reasons, tree and table seem better.  Nevertheless, vector (block
     of preallocated values) seems the best for the FLTrackGrid application.  The payload
     value is a 4 byte pointer, and so the overhead of a tree or table is large compared
     to the data.  Compare to a vector, which preallocates and so won't get worse as the
     track gets dense: Say we allow viewing (by zooming out) as much as 101x101 segments
     (our current world maximum); call that a single sector, and we preload the
     surrounding 8 sectors for zooming and panning; that's still only 734KB.  Again, that
     compares unfavorably to a tree or table for sparse data, but it is redeemed by the
     fact that it's constant, and gets no worse as the data gets pathologically dense.
     (At maximum density, the same 8 sectors of data points might take twice or four times
     the space in a tree or table.)

 - For future thought: The FLTrackGrid and SKNode hierarchy should be synchronized; nodes
   should be persisted to disk and removed from memory along with FLTrackGrid sectors.

   - Probably this is an interface/protocol: No matter what the data structure, it should
     implement an interface that supports coordinated "sector loading" between the grid
     and SKNode hierarchy.

   - I've always assumed it's better to track segments in grid location apart from the
     node tree, but who knows: If they've got a quadtree on node position (or an r-tree on
     frame, or whatever), then maybe better to ditch this data structure and just use
     `nodeAtPoint`.
*/
template<typename Value>
class DenseSectorTable
{
private:

  struct DenseSectorTableKeyHash
  {
    size_t operator()(const std::pair<int, int>& key) const {
      size_t h = (size_t)((key.first & 0xFFFF) << 16) | (key.second & 0xFFFF);
      h = ((h >> 16) ^ h) * 0x45d9f3b;
      h = ((h >> 16) ^ h) * 0x45d9f3b;
      h = ((h >> 16) ^ h);
      return h;
    }
  };

  typedef std::unordered_map<std::pair<int, int>, std::vector<Value>, DenseSectorTableKeyHash> DenseSectorTableSectorTable;

  template <typename QualifiedValue, typename QualifiedDenseSectorTable, typename QualifiedDenseSectorTableSectorTableIterator>
  class DenseSectorTableIterator : std::iterator<std::forward_iterator_tag, QualifiedValue>
  {
  public:
    DenseSectorTableIterator() {}
    DenseSectorTableIterator(QualifiedDenseSectorTable *denseSectorTable,
                             const QualifiedDenseSectorTableSectorTableIterator& sectorIterator,
                             size_t pointIndexInSector)
    : denseSectorTable_(denseSectorTable),
    sectorIterator_(sectorIterator),
    pointIndexInSector_(pointIndexInSector) {}
    //~DenseSectorTableIterator();
    DenseSectorTableIterator(const DenseSectorTableIterator& rhs) {
      denseSectorTable_ = rhs.denseSectorTable_;
      sectorIterator_ = rhs.sectorIterator_;
      pointIndexInSector_ = rhs.pointIndexInSector_;
    }
    // note: Allow conversion from iterator to const_iterator.
    operator DenseSectorTableIterator<Value const, DenseSectorTable const, typename DenseSectorTableSectorTable::const_iterator>() const {
      return DenseSectorTableIterator<Value const, DenseSectorTable const, typename DenseSectorTableSectorTable::const_iterator>(denseSectorTable_,
                                                                                                                                 sectorIterator_,
                                                                                                                                 pointIndexInSector_);
    }
    DenseSectorTableIterator& operator=(const DenseSectorTableIterator& rhs) {
      if (this != &rhs) {
        denseSectorTable_ = rhs.denseSectorTable_;
        sectorIterator_ = rhs.sectorIterator_;
        pointIndexInSector_ = rhs.pointIndexInSector_;
      }
      return *this;
    }
    DenseSectorTableIterator& operator++() {
      size_t sectorLength = denseSectorTable_->sectorSize_ * denseSectorTable_->sectorSize_;
      size_t p = pointIndexInSector_ + 1;
      while (sectorIterator_ != denseSectorTable_->sectorTable_.end()) {
        auto& sector = sectorIterator_->second;
        while (p < sectorLength) {
          if (sector[p] != denseSectorTable_->nullValue_) {
            pointIndexInSector_ = p;
            return *this;
          }
          ++p;
        }
        ++sectorIterator_;
        p = 0;
      }
      pointIndexInSector_ = 0;
      return *this;
    }
    std::pair<std::pair<int, int>, QualifiedValue&> operator*() {
      assert(sectorIterator_ != denseSectorTable_->sectorTable_.end());
      auto& sector = sectorIterator_->second;
      assert(pointIndexInSector_ < denseSectorTable_->sectorSize_ * denseSectorTable_->sectorSize_);
      assert(sector[pointIndexInSector_] != denseSectorTable_->nullValue_);
      return std::pair<std::pair<int, int>, QualifiedValue&>(denseSectorTable_->getXY(sectorIterator_->first, pointIndexInSector_),
                                                             sector[pointIndexInSector_]);
    }
    QualifiedValue *operator->() {
      assert(sectorIterator_ != denseSectorTable_->sectorTable_.end());
      auto& sector = sectorIterator_->second;
      assert(pointIndexInSector_ < denseSectorTable_->sectorSize_ * denseSectorTable_->sectorSize_);
      assert(sector[pointIndexInSector_] != denseSectorTable_->nullValue_);
      return &sector[pointIndexInSector_];
    }
    bool operator==(const DenseSectorTableIterator& rhs) const {
      // note: End iterator is always represented with pointIndexInSector == 0.
      return denseSectorTable_ == rhs.denseSectorTable_
        && sectorIterator_ == rhs.sectorIterator_
        && pointIndexInSector_ == rhs.pointIndexInSector_;
    }
    bool operator!=(const DenseSectorTableIterator& rhs) const { return !(*this == rhs); }
  private:
    friend class DenseSectorTable;
    QualifiedDenseSectorTable *denseSectorTable_;
    QualifiedDenseSectorTableSectorTableIterator sectorIterator_;
    size_t pointIndexInSector_;
  };

  inline std::pair<int, int> getSectorCoordinatesInTable(int x, int y) const {
    return std::make_pair((x >= 0 ? x / static_cast<int>(sectorSize_) : (x + 1) / static_cast<int>(sectorSize_) - 1),
                          (y >= 0 ? y / static_cast<int>(sectorSize_) : (y + 1) / static_cast<int>(sectorSize_) - 1));
  }

  inline int getSectorCoordinateInTable(int i) const {
    return (i >= 0 ? i / static_cast<int>(sectorSize_) : (i + 1) / static_cast<int>(sectorSize_) - 1);
  }

  inline size_t getPointIndexInSector(int x, int y) const {
    return static_cast<size_t>((y >= 0 ? y % static_cast<int>(sectorSize_) : static_cast<int>(sectorSize_) + (y + 1) % static_cast<int>(sectorSize_) - 1) * static_cast<int>(sectorSize_)
                               + (x >= 0 ? x % static_cast<int>(sectorSize_) : static_cast<int>(sectorSize_) + (x + 1) % static_cast<int>(sectorSize_) - 1));
  }

  inline std::pair<int, int> getXY(const std::pair<int, int>& sectorCoordinatesInTable,
                                   size_t pointIndexInSector) const {
    return std::make_pair(sectorCoordinatesInTable.first * static_cast<int>(sectorSize_)
                          + static_cast<int>(pointIndexInSector) % static_cast<int>(sectorSize_),
                          sectorCoordinatesInTable.second * static_cast<int>(sectorSize_)
                          + static_cast<int>(pointIndexInSector) / static_cast<int>(sectorSize_));
  }

public:

  typedef DenseSectorTableIterator<Value, DenseSectorTable, typename DenseSectorTableSectorTable::iterator> iterator;
  typedef DenseSectorTableIterator<Value const, DenseSectorTable const, typename DenseSectorTableSectorTable::const_iterator> const_iterator;

  DenseSectorTable(size_t sectorSize, size_t initialSectorCount, const Value& nullValue)
    : sectorSize_(sectorSize), sectorTable_(initialSectorCount), nullValue_(nullValue) {}

  size_t sectorSize() const { return sectorSize_; }

  size_t pointCount() const;
  size_t sectorCount() const;
  size_t sectorPointCount(int x, int y) const;
  bool sectorEmpty(int x, int y) const;

  Value getPoint(int x, int y) const;
  void setPoint(int x, int y, const Value& value);
  Value& operator[](std::pair<int, int> xy);

  size_t pruneSectors();
  bool pruneSector(int x, int y);

  iterator beginPoint();
  const_iterator beginPoint() const;
  iterator endPoint();
  const_iterator endPoint() const;
  iterator findPoint(int x, int y);
  const_iterator findPoint(int x, int y) const;

  bool erasePoint(int x, int y, bool pruneSector = false);
  bool erasePoint(const_iterator& position, bool pruneSector = false);

private:

  size_t sectorSize_;
  Value nullValue_;
  DenseSectorTableSectorTable sectorTable_;
};

template<typename Value>
Value
DenseSectorTable<Value>::getPoint(int x, int y) const
{
  auto s = sectorTable_.find(getSectorCoordinatesInTable(x, y));
  if (s != sectorTable_.end()) {
    const std::vector<Value>& sector = s->second;
    const Value& point = sector[getPointIndexInSector(x, y)];
    if (point != nullValue_) {
      return sector[getPointIndexInSector(x, y)];
    }
  }
  return nullValue_;
}

template<typename Value>
void
DenseSectorTable<Value>::setPoint(int x, int y, const Value& value)
{
  auto emplacement = sectorTable_.emplace(std::piecewise_construct,
                                          std::forward_as_tuple(getSectorCoordinateInTable(x),
                                                                getSectorCoordinateInTable(y)),
                                          std::forward_as_tuple(sectorSize_ * sectorSize_, nullValue_));
  std::vector<Value>& sector = emplacement.first->second;
  Value& point = sector[getPointIndexInSector(x, y)];
  point = value;
}

template<typename Value>
Value&
DenseSectorTable<Value>::operator[](std::pair<int, int> xy)
{
  auto emplacement = sectorTable_.emplace(std::piecewise_construct,
                                          std::forward_as_tuple(getSectorCoordinateInTable(xy.first),
                                                                getSectorCoordinateInTable(xy.second)),
                                          std::forward_as_tuple(sectorSize_ * sectorSize_, nullValue_));
  std::vector<Value>& sector = emplacement.first->second;
  return sector[getPointIndexInSector(xy.first, xy.second)];
}

template<typename Value>
bool
DenseSectorTable<Value>::erasePoint(int x, int y, bool pruneSector)
{
  auto s = sectorTable_.find(getSectorCoordinatesInTable(x, y));
  if (s != sectorTable_.end()) {

    std::vector<Value>& sector = s->second;
    Value& point = sector[getPointIndexInSector(x, y)];
    point = nullValue_;

    if (pruneSector) {
      size_t sectorLength = sectorSize_ * sectorSize_;
      bool sectorEmpty = true;
      for (size_t p = 0; p < sectorLength; ++p) {
        if (sector[p] != nullValue_) {
          sectorEmpty = false;
          break;
        }
      }
      if (sectorEmpty) {
        sectorTable_.erase(s);
        return true;
      }
    }
  }
  return false;
}

template<typename Value>
bool
DenseSectorTable<Value>::erasePoint(typename DenseSectorTable<Value>::const_iterator& position, bool pruneSector)
{
  if (position.denseSectorTable_ != this) {
    return false;
  }
  if (position.sectorIterator_ == sectorTable_.end()) {
    return false;
  }

  // note: The const_iterator holds an iterator into the sectorTable_, and we'd like to
  // use it to do the work here.  But, of course, it's const.  So we have to make our own
  // non-const sectorTable_ iterator by doing a lookup.
  const std::pair<int, int>& sectorCoordinates = position.sectorIterator_->first;
  auto s = sectorTable_.find(sectorCoordinates);
  assert(s != sectorTable_.end());

  std::vector<Value>& sector = s->second;
  assert(position.pointIndexInSector_ < sectorSize_ * sectorSize_);
  Value& point = sector[position.pointIndexInSector_];
  point = nullValue_;

  if (pruneSector) {
    size_t sectorLength = sectorSize_ * sectorSize_;
    bool sectorEmpty = true;
    for (size_t p = 0; p < sectorLength; ++p) {
      if (sector[p] != nullValue_) {
        sectorEmpty = false;
        break;
      }
    }
    if (sectorEmpty) {
      sectorTable_.erase(s);
      return true;
    }
  }
  return false;
}

template<typename Value>
size_t
DenseSectorTable<Value>::pointCount() const
{
  size_t pointCount = 0;
  size_t sectorLength = sectorSize_ * sectorSize_;
  for (auto s = sectorTable_.begin(); s != sectorTable_.end(); ++s) {
    const std::vector<Value>& sector = s->second;
    for (size_t p = 0; p < sectorLength; ++p) {
      if (sector[p] != nullValue_) {
        ++pointCount;
      }
    }
  }
  return pointCount;
}

template<typename Value>
size_t
DenseSectorTable<Value>::sectorCount() const
{
  return sectorTable_.size();
}

template<typename Value>
size_t
DenseSectorTable<Value>::sectorPointCount(int x, int y) const
{
  auto s = sectorTable_.find(getSectorCoordinatesInTable(x, y));
  if (s == sectorTable_.end()) {
    return 0;
  }
  size_t sectorLength = sectorSize_ * sectorSize_;
  const std::vector<Value>& sector = s->second;
  size_t sectorPointCount = 0;
  for (size_t p = 0; p < sectorLength; ++p) {
    if (sector[p] != nullValue_) {
      ++sectorPointCount;
    }
  }
  return sectorPointCount;
}

template<typename Value>
bool
DenseSectorTable<Value>::sectorEmpty(int x, int y) const
{
  auto s = sectorTable_.find(getSectorCoordinatesInTable(x, y));
  if (s == sectorTable_.end()) {
    return true;
  }
  size_t sectorLength = sectorSize_ * sectorSize_;
  const std::vector<Value>& sector = s->second;
  for (size_t p = 0; p < sectorLength; ++p) {
    if (sector[p] != nullValue_) {
      return false;
    }
  }
  return true;
}

template<typename Value>
size_t
DenseSectorTable<Value>::pruneSectors()
{
  size_t pruneSectorCount = 0;
  size_t sectorLength = sectorSize_ * sectorSize_;
  auto s = sectorTable_.begin();
  while (s != sectorTable_.end()) {
    std::vector<Value>& sector = s->second;
    bool sectorEmpty = true;
    for (size_t p = 0; p < sectorLength; ++p) {
      if (sector[p] != nullValue_) {
        sectorEmpty = false;
        break;
      }
    }
    if (sectorEmpty) {
      s = sectorTable_.erase(s);
      ++pruneSectorCount;
    } else {
      ++s;
    }
  }
  return pruneSectorCount;
}

template<typename Value>
bool
DenseSectorTable<Value>::pruneSector(int x, int y)
{
  auto s = sectorTable_.find(getSectorCoordinatesInTable(x, y));
  if (s == sectorTable_.end()) {
    return false;
  }
  size_t sectorLength = sectorSize_ * sectorSize_;
  std::vector<Value>& sector = s->second;
  for (size_t p = 0; p < sectorLength; ++p) {
    if (sector[p] != nullValue_) {
      return false;
    }
  }
  sectorTable_.erase(s);
  return true;
}

template<typename Value>
typename DenseSectorTable<Value>::iterator
DenseSectorTable<Value>::beginPoint()
{
  size_t sectorLength = sectorSize_ * sectorSize_;
  for (auto s = sectorTable_.begin(); s != sectorTable_.end(); ++s) {
    std::vector<Value>& sector = s->second;
    for (size_t p = 0; p < sectorLength; ++p) {
      if (sector[p] != nullValue_) {
        return typename DenseSectorTable<Value>::iterator(this, s, p);
      }
    }
  }
  return typename DenseSectorTable<Value>::iterator(this, sectorTable_.end(), 0);
}

template<typename Value>
typename DenseSectorTable<Value>::const_iterator
DenseSectorTable<Value>::beginPoint() const
{
  size_t sectorLength = sectorSize_ * sectorSize_;
  for (auto s = sectorTable_.begin(); s != sectorTable_.end(); ++s) {
    const std::vector<Value>& sector = s->second;
    for (size_t p = 0; p < sectorLength; ++p) {
      if (sector[p] != nullValue_) {
        return typename DenseSectorTable<Value>::const_iterator(this, s, p);
      }
    }
  }
  return typename DenseSectorTable<Value>::const_iterator(this, sectorTable_.end(), 0);
}

template<typename Value>
typename DenseSectorTable<Value>::iterator
DenseSectorTable<Value>::endPoint()
{
  return typename DenseSectorTable<Value>::iterator(this, sectorTable_.end(), 0);
}

template<typename Value>
typename DenseSectorTable<Value>::const_iterator
DenseSectorTable<Value>::endPoint() const
{
  return typename DenseSectorTable<Value>::const_iterator(this, sectorTable_.end(), 0);
}

template<typename Value>
typename DenseSectorTable<Value>::iterator
DenseSectorTable<Value>::findPoint(int x, int y)
{
  auto s = sectorTable_.find(getSectorCoordinatesInTable(x, y));
  if (s == sectorTable_.end()) {
    return typename DenseSectorTable<Value>::iterator(this, s, 0);
  }
  auto& sector = s->second;
  size_t p = getPointIndexInSector(x, y);
  assert(p < sectorSize_ * sectorSize_);
  if (sector[p] == nullValue_) {
    return typename DenseSectorTable<Value>::iterator(this, sectorTable_.end(), 0);
  }
  return typename DenseSectorTable<Value>::iterator(this, s, p);
}

template<typename Value>
typename DenseSectorTable<Value>::const_iterator
DenseSectorTable<Value>::findPoint(int x, int y) const
{
  auto s = sectorTable_.find(getSectorCoordinatesInTable(x, y));
  if (s == sectorTable_.end()) {
    return typename DenseSectorTable<Value>::const_iterator(this, s, 0);
  }
  auto& sector = s->second;
  size_t p = getPointIndexInSector(x, y);
  assert(p < sectorSize_ * sectorSize_);
  if (sector[p] == nullValue_) {
    return typename DenseSectorTable<Value>::const_iterator(this, sectorTable_.end(), 0);
  }
  return typename DenseSectorTable<Value>::const_iterator(this, s, p);
}

} /* namespace HLCommon */

#endif /* defined(__Flippy__DenseSectorTable__) */
