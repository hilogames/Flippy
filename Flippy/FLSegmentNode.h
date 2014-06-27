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
// The basic art is centered inside the full art; this is the inset.
FOUNDATION_EXPORT const CGFloat FLSegmentArtBasicInset;
// The inside-drawn-track-inset is the distance from the edge of the full art
// to the inside edge of the drawn track (if the track is drawn along an edge).
FOUNDATION_EXPORT const CGFloat FLSegmentArtInsideDrawnTrackInset;
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
  FLSegmentTypeCross,
  FLSegmentTypePlatform,
  FLSegmentTypeReadout,
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

@interface FLSegmentNode : SKSpriteNode <NSCoding, NSCopying>

@property (nonatomic) FLSegmentType segmentType;

@property (nonatomic, readonly) NSString *segmentKey;

@property (nonatomic) int zRotationQuarters;

@property (nonatomic, readonly) int switchPathId;

@property (nonatomic, readonly) CGPoint switchPosition;

@property (nonatomic, assign) BOOL showsSwitchValue;

+ (NSString *)keyForSegmentType:(FLSegmentType)segmentType;

+ (FLSegmentType)segmentTypeForKey:(NSString *)key;

/**
 * Creates a image of the readout segment in one of its possible states.
 * (The readout segment as represented in the node tree, by comparison,
 * is composed of a number of sprites which can change position dynamically.)
 *
 * note: Components of the image (for example, the switch and the "value"
 * bubbles) are scaled to imageSize either with interpolation or without,
 * according to the filteringMode of the texture which corresponds to the
 * component image in the texture store.
 */
+ (UIImage *)createImageForReadoutSegment:(CGFloat)imageSize;

- (id)initWithSegmentType:(FLSegmentType)segmentType;

- (id)initWithTextureKey:(NSString *)textureKey;

- (void)setSwitchPathId:(int)switchPathId animated:(BOOL)animated;
- (int)toggleSwitchPathIdAnimated:(BOOL)animated;

- (void)getPoint:(CGPoint *)point rotation:(CGFloat *)rotationRadians forPath:(int)pathId progress:(CGFloat)progress scale:(CGFloat)scale;

- (BOOL)getClosestOnTrackPoint:(CGPoint *)onTrackPoint distance:(CGFloat *)distance rotation:(CGFloat *)rotationRadians path:(int *)pathId progress:(CGFloat *)progress forOffTrackPoint:(CGPoint)offSegmentPoint scale:(CGFloat)scale precision:(CGFloat)progressPrecision;

- (BOOL)getPath:(int *)pathId progress:(CGFloat *)progress forEndPoint:(CGPoint)endPoint rotation:(CGFloat)rotationRadians scale:(CGFloat)scale;

- (int)pathCount;

- (CGFloat)pathLengthForPath:(int)pathId;

@end
