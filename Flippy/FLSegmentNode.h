//
//  FLSegmentNode.h
//  Flippy
//
//  Created by Karl Voskuil on 2/22/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

#include <vector>

FOUNDATION_EXPORT const CGFloat FLSegmentArtSizeFull;
FOUNDATION_EXPORT const CGFloat FLSegmentArtSizeBasic;
// "Track normal width" is the pixel width of the drawn tracks (widest: sleepers).
FOUNDATION_EXPORT const CGFloat FLSegmentArtDrawnTrackNormalWidth;
FOUNDATION_EXPORT const CGFloat FLSegmentArtBasicInset;
FOUNDATION_EXPORT const CGFloat FLSegmentArtStraightShift;
FOUNDATION_EXPORT const CGFloat FLSegmentArtCurveShift;

FOUNDATION_EXPORT const int FLSegmentSwitchPathIdNone;

enum FLSegmentType {
  FLSegmentTypeNone = 0,
  FLSegmentTypeStraight,
  FLSegmentTypeCurve,
  FLSegmentTypeJoinLeft,
  FLSegmentTypeJoinRight,
  FLSegmentTypeJogLeft,
  FLSegmentTypeJogRight,
  FLSegmentTypeCross
};

inline int
convertRotationRadiansToQuarters(CGFloat radians)
{
  // note: Radians are not constrained in range or sign; the error introduced by
  // the epsilon value would eventually be an issue for large-magnitude radians.
  // (However, choosing a smaller epsilon introduces problems for cumulative
  // floating point error caused by repeatedly adding e.g. M_PI_2 and then hoping
  // to get an exact number by dividing.  So . . . a compromise epsilon.)
  return int(radians / (M_PI_2 - 0.0001f));
}

inline CGFloat
convertRotationQuartersToRadians(int quarters)
{
  return quarters * (CGFloat)M_PI_2;
}

@interface FLSegmentNode : SKSpriteNode <NSCoding>

@property (nonatomic) FLSegmentType segmentType;

@property (nonatomic, readonly) NSString *segmentKey;

@property (nonatomic) int zRotationQuarters;

@property (nonatomic, readonly) int switchPathId;

@property (nonatomic, readonly) CGPoint switchPosition;

+ (NSString *)keyForSegmentType:(FLSegmentType)segmentType;

+ (FLSegmentType)segmentTypeForKey:(NSString *)key;

- (id)initWithSegmentType:(FLSegmentType)segmentType;

- (id)initWithTextureKey:(NSString *)textureKey;

- (void)setSwitchPathId:(int)switchPathId animated:(BOOL)animated;
- (int)toggleSwitchPathIdAnimated:(BOOL)animated;

- (void)getPoint:(CGPoint *)point rotation:(CGFloat *)rotationRadians forPath:(int)pathId progress:(CGFloat)progress scale:(CGFloat)scale;

- (CGFloat)getClosestOnTrackPoint:(CGPoint *)onTrackPoint rotation:(CGFloat *)rotationRadians path:(int *)pathId progress:(CGFloat *)progress forOffTrackPoint:(CGPoint)offSegmentPoint scale:(CGFloat)scale precision:(CGFloat)progressPrecision;

- (BOOL)getPath:(int *)pathId progress:(CGFloat *)progress forEndPoint:(CGPoint)endPoint rotation:(CGFloat)rotationRadians scale:(CGFloat)scale;

- (CGFloat)pathLengthForPath:(int)pathId;

@end
