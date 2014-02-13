//
//  FLCommon.h
//  Flippy
//
//  Created by Karl Voskuil on 2/20/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#ifndef Flippy_FLCommon_h
#define Flippy_FLCommon_h

inline
void
convertWorldLocationToTrackGrid(CGPoint worldLocation, CGFloat gridSize, int *gridX, int *gridY)
{
  *gridX = int(floorf(worldLocation.x / gridSize + 0.5f));
  *gridY = int(floorf(worldLocation.y / gridSize + 0.5f));
}

inline
int
convertRotationRadiansToQuarters(CGFloat radians)
{
  // note: Radians are not constrained in range or sign; the error introduced by
  // the epsilon value would eventually be an issue for large-magnitude radians.
  // (However, choosing a smaller epsilon introduces problems for cumulative
  // floating point error caused by repeatedly adding e.g. M_PI_2 and then hoping
  // to get an exact number by dividing.  So . . . a compromise epsilon.)
  return int(radians / (M_PI_2 - 0.0001f));
}

#endif
