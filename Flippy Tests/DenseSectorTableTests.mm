//
//  DenseSectorTableTests.m
//  Flippy
//
//  Created by Karl Voskuil on 11/25/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <unordered_set>
#import <XCTest/XCTest.h>

#include "DenseSectorTable.h"

using namespace std;
using namespace HLCommon;

@interface DenseSectorTableTests : XCTestCase

@end

//  0  1  2    3  4  5    6  7  8
//  9 10 11   12 13 14   15 16 17
// 18 19 20   21 22 23   24 25 26
//
// 27 28 29   30 31 32   33 34 35
// 36 37 38   39 40 41   42 43 44
// 45 46 47   48 49 50   51 52 53
//
// 54 55 56   57 58 59   60 61 62
// 63 64 65   66 67 68   69 70 71
// 72 73 74   75 76 77   78 79 80

@implementation DenseSectorTableTests

- (void)testSetPoint
{
  DenseSectorTable<int> denseSectorTable(3, 9, -1);

  denseSectorTable.setPoint(3, 5, 48);
  XCTAssertEqual(denseSectorTable.getPoint(3, 5), 48);
  XCTAssertEqual(denseSectorTable.pointCount(), 1UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 1UL);
  XCTAssertEqual(denseSectorTable.sectorPointCount(3, 5), 1UL);

  auto i = denseSectorTable.findPoint(3, 5);
  XCTAssertNotEqual(i, denseSectorTable.endPoint());
  XCTAssertEqual((*i).first.first, 3);
  XCTAssertEqual((*i).first.second, 5);
  XCTAssertEqual((*i).second, 48);
}

- (void)testSetPointTwice
{
  DenseSectorTable<int> denseSectorTable(3, 9, -1);

  denseSectorTable.setPoint(4, 4, 40);
  XCTAssertEqual(denseSectorTable.getPoint(4, 4), 40);
  XCTAssertEqual(denseSectorTable.pointCount(), 1UL);
  denseSectorTable.setPoint(4, 4, 99);
  XCTAssertEqual(denseSectorTable.getPoint(4, 4), 99);
  XCTAssertEqual(denseSectorTable.pointCount(), 1UL);
}

- (void)testSetMultiplePoints
{
  DenseSectorTable<int> denseSectorTable(3, 9, -1);
  
  denseSectorTable.setPoint(6, 4, 33);
  XCTAssertEqual(denseSectorTable.getPoint(6, 4), 33);
  XCTAssertEqual(denseSectorTable.pointCount(), 1UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 1UL);
  XCTAssertEqual(denseSectorTable.sectorPointCount(6, 4), 1UL);

  denseSectorTable[{4, 1}] = 13;
  XCTAssertEqual(denseSectorTable.getPoint(4, 1), 13);
  XCTAssertEqual(denseSectorTable.pointCount(), 2UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 2UL);
  XCTAssertEqual(denseSectorTable.sectorPointCount(4, 1), 1UL);
  
  denseSectorTable[{5, 2}] = 23;
  XCTAssertEqual(denseSectorTable.getPoint(5, 2), 23);
  XCTAssertEqual(denseSectorTable.pointCount(), 3UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 2UL);
  XCTAssertEqual(denseSectorTable.sectorPointCount(5, 2), 2UL);
}

- (void)testErasePoint
{
  DenseSectorTable<int> denseSectorTable(3, 9, -1);

  // Erase by explicitly setting to nullValue.
  denseSectorTable.setPoint(0, 8, 72);
  XCTAssertEqual(denseSectorTable.getPoint(0, 8), 72);
  XCTAssertEqual(denseSectorTable.pointCount(), 1UL);
  denseSectorTable.setPoint(0, 8, -1);
  XCTAssertEqual(denseSectorTable.getPoint(0, 8), -1);
  XCTAssertEqual(denseSectorTable.pointCount(), 0UL);

  // Erase by erasePoint(x, y).
  denseSectorTable.setPoint(0, 8, 72);
  XCTAssertEqual(denseSectorTable.getPoint(0, 8), 72);
  XCTAssertEqual(denseSectorTable.pointCount(), 1UL);
  denseSectorTable.erasePoint(0, 8);
  XCTAssertEqual(denseSectorTable.getPoint(0, 8), -1);
  XCTAssertEqual(denseSectorTable.pointCount(), 0UL);

  // Erase by erasePoint(const_iterator).
  denseSectorTable.setPoint(0, 8, 72);
  DenseSectorTable<int>::const_iterator i = denseSectorTable.findPoint(0, 8);
  XCTAssertNotEqual(i, denseSectorTable.endPoint());
  XCTAssertEqual((*i).first.first, 0);
  XCTAssertEqual((*i).first.second, 8);
  XCTAssertEqual((*i).second, 72);
  XCTAssertEqual(denseSectorTable.pointCount(), 1UL);
  denseSectorTable.erasePoint(i);
  XCTAssertEqual(denseSectorTable.getPoint(0, 8), -1);
  XCTAssertEqual(denseSectorTable.pointCount(), 0UL);
}

- (void)testSectorEmpty
{
  DenseSectorTable<int> denseSectorTable(3, 9, -1);

  XCTAssertEqual(denseSectorTable.sectorEmpty(2, 3), true);
  denseSectorTable.setPoint(2, 3, 29);
  XCTAssertEqual(denseSectorTable.sectorEmpty(2, 3), false);
  denseSectorTable.erasePoint(2, 3);
  XCTAssertEqual(denseSectorTable.sectorEmpty(2, 3), true);
  denseSectorTable.pruneSector(2, 3);
  XCTAssertEqual(denseSectorTable.sectorEmpty(2, 3), true);
}

- (void)testPruneSector
{
  DenseSectorTable<int> denseSectorTable(3, 9, -1);

  // Prune using option during erase.
  denseSectorTable.setPoint(3, 8, 75);
  XCTAssertEqual(denseSectorTable.pointCount(), 1UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 1UL);
  denseSectorTable.erasePoint(3, 8, /* pruneSector */ true);
  XCTAssertEqual(denseSectorTable.pointCount(), 0UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 0UL);

  // Prune single sector explicitly.
  denseSectorTable.setPoint(3, 8, 75);
  XCTAssertEqual(denseSectorTable.pointCount(), 1UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 1UL);
  denseSectorTable.erasePoint(3, 8, /* pruneSector */ false);
  XCTAssertEqual(denseSectorTable.pointCount(), 0UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 1UL);
  denseSectorTable.pruneSector(3, 8);
  XCTAssertEqual(denseSectorTable.pointCount(), 0UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 0UL);

  // Prune all sectors explicitly.
  denseSectorTable.setPoint(3, 8, 75);
  denseSectorTable.setPoint(6, 6, 60);
  XCTAssertEqual(denseSectorTable.pointCount(), 2UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 2UL);
  denseSectorTable.erasePoint(3, 8, /* pruneSector */ false);
  denseSectorTable.erasePoint(6, 6, /* pruneSector */ false);
  XCTAssertEqual(denseSectorTable.pointCount(), 0UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 2UL);
  denseSectorTable.pruneSectors();
  XCTAssertEqual(denseSectorTable.pointCount(), 0UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 0UL);
}

- (void)testNegativeIndexes
{
  //  0  1   2  3
  //  4  5   6  7
  //
  //  8  9  10 11
  // 12 13  14 15
  DenseSectorTable<int> denseSectorTable(2, 4, -1);

  int value = 0;
  for (int x = -2; x <= 1; ++x) {
    for (int y = -2; y <= 1; ++y) {
      denseSectorTable.setPoint(x, y, value);
      ++value;
    }
  }

  XCTAssertEqual(denseSectorTable.pointCount(), 16UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 4UL);

  value = 0;
  for (int x = -2; x <= 1; ++x) {
    for (int y = -2; y <= 1; ++y) {
      XCTAssertEqual(denseSectorTable.getPoint(x, y), value);
      ++value;
    }
  }
}

- (void)testIteration
{
  DenseSectorTable<int> denseSectorTable(3, 9, -1);

  unordered_set<int> values;
  int value = 0;
  for (int y = -3; y <= 5; ++y) {
    for (int x = -3; x <= 5; ++x) {
      denseSectorTable.setPoint(x, y, value);
      values.insert(value);
      ++value;
    }
  }

  XCTAssertEqual(denseSectorTable.pointCount(), 81UL);
  XCTAssertEqual(denseSectorTable.sectorCount(), 9UL);

  unordered_set<int> notYetFoundValues(values);
  for (auto p = denseSectorTable.beginPoint(); p != denseSectorTable.endPoint(); ++p) {
    auto v = notYetFoundValues.find((*p).second);
    XCTAssertNotEqual(v, notYetFoundValues.end());
    notYetFoundValues.erase(v);
  }
  XCTAssertEqual(notYetFoundValues.size(), 0UL);
}

@end
