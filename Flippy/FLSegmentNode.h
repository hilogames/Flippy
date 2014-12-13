//
//  FLSegmentNode.h
//  Flippy
//
//  Created by Karl Voskuil on 2/22/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
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

FOUNDATION_EXPORT const char FLSegmentLabelNone;

typedef NS_ENUM(NSInteger, FLSegmentType) {
  FLSegmentTypeNone = 0,
  FLSegmentTypeStraight,
  FLSegmentTypeCurve,
  FLSegmentTypeJoinLeft,
  FLSegmentTypeJoinRight,
  FLSegmentTypeJogLeft,
  FLSegmentTypeJogRight,
  FLSegmentTypeCross,
  FLSegmentTypePlatformLeft,
  FLSegmentTypePlatformStartLeft,
  FLSegmentTypeReadoutInput,
  FLSegmentTypeReadoutOutput,
  FLSegmentTypePlatformRight,
  FLSegmentTypePlatformStartRight,
  FLSegmentTypePixel,
};

typedef NS_ENUM(NSInteger, FLSegmentFlipDirection) {
  FLSegmentFlipHorizontal = 0,
  FLSegmentFlipVertical = 1,
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

/// @name Creating a Segment

- (instancetype)initWithSegmentType:(FLSegmentType)segmentType;

/// @name Creating Images of Segments

/**
 * Creates an image of the readout segment in one of its possible states.
 * (The readout segment as represented in the node tree, by comparison,
 * is composed of a number of sprites which can change position dynamically.)
 *
 * note: Components of the image (for example, the switch and the value
 * bubble) are scaled to imageSize either with interpolation or without,
 * according to the filteringMode of the texture which corresponds to the
 * component image in the texture store.
 */
+ (UIImage *)createImageForReadoutSegment:(FLSegmentType)segmentType imageSize:(CGFloat)imageSize;

/**
 * Creates an image of the pixel segment in one of its possible states.
 */
+ (UIImage *)createImageForPixelSegmentImageSize:(CGFloat)imageSize;

/// @name Getting Segment Type and Key

@property (nonatomic, readonly) FLSegmentType segmentType;

+ (NSString *)keyForSegmentType:(FLSegmentType)segmentType;

@property (nonatomic, readonly) NSString *segmentKey;

/// @name Configuring Segment Label and Switch Value

@property (nonatomic, assign) char label;

+ (BOOL)canSwitch:(FLSegmentType)segmentType;

- (BOOL)canSwitch;

- (void)setSwitchPathId:(int)switchPathId animated:(BOOL)animated;

- (int)toggleSwitchPathIdAnimated:(BOOL)animated;

@property (nonatomic, readonly) int switchPathId;

/// @name Configuring Segment Geometry

@property (nonatomic) int zRotationQuarters;

+ (BOOL)canFlip:(FLSegmentType)segmentType;

- (BOOL)canFlip;

- (void)flip:(FLSegmentFlipDirection)flipDirection;

/// @name Configuring Segment Appearance

/**
 * Sets visibility of the drawn label for segment types where it is an
 * option.  (For all other segment types, this property is ignored.)
 */
@property (nonatomic, assign) BOOL mayShowLabel;
- (BOOL)doesShowLabel;

/**
 * Sets visibility of the drawn switch for segment types where it is an
 * option.  (For all other segment types, this property is ignored.)
 */
@property (nonatomic, assign) BOOL mayShowSwitch;
+ (BOOL)canShowSwitch:(FLSegmentType)segmentType;
- (BOOL)canShowSwitch;
- (BOOL)doesShowSwitch;

/**
 * Sets visibility of the drawn value bubble for segment types where it is
 * an option.  (For all other segment types, this property is ignored.)
 */
@property (nonatomic, assign) BOOL mayShowBubble;
+ (BOOL)canShowBubble:(FLSegmentType)segmentType;
- (BOOL)canShowBubble;
- (BOOL)doesShowBubble;

/**
 * Returns a location (in this node's parent's coordinates) that can be used
 * by the caller when "linking" this segment for the purpose of "switching".
 *
 * The description is vague, but the current use-case is very specific: The
 * caller would like to draw a line between two segments indicating they
 * switch together, and the caller wants to know a good point to use in each
 * to best show this visually.
 *
 * Note that every segment that returns YES from [canSwitch] should be able
 * to return a valid position, regardless of whether or not it is currently
 * (or ever) drawing a switch on itself.
 */
@property (nonatomic, readonly) CGPoint switchLinkLocation;

/// @name Dealing With Track Points and Paths

- (void)getPoint:(CGPoint *)point rotation:(CGFloat *)rotationRadians forPath:(int)pathId progress:(CGFloat)progress scale:(CGFloat)scale;

- (BOOL)getClosestOnTrackPoint:(CGPoint *)onTrackPoint distance:(CGFloat *)distance rotation:(CGFloat *)rotationRadians path:(int *)pathId progress:(CGFloat *)progress forOffTrackPoint:(CGPoint)offSegmentPoint scale:(CGFloat)scale precision:(CGFloat)progressPrecision;

/**
 * Returns true if a path can be found that connects to the passed end point.
 * Importantly: If more than one path connects at that point, and the segment switches
 * between them, the path selected by the switch will be returned.
 */
- (BOOL)getConnectingPath:(int *)pathId progress:(CGFloat *)progress forEndPoint:(CGPoint)endPoint scale:(CGFloat)scale;

/**
 * Returns true if a path can be found that connects to the passed end point, with
 * the same requirements as getConnectingPath but also matching rotation information.
 *
 * "Matching rotation information" means that the directed tangent of the connecting
 * path must match the directed tangent passed in (by parameters forProgress and
 * rotation).  That is: The passed progress and rotation together imply not just
 * a tangent of a curve but also a *direction* along the curve; the connecting path
 * must (by its calculated progress and tangent) have the same tangent and direction.
 * For example: Imagine two curved segment pieces stacked on top of each other in the
 * shape of a letter C.  The train goes halfway through the curve from the top and
 * wants to connect to the lower segment.  The passed rotation is passed in either
 * PI/2 or -PI/2, depending on implementation; the passed progress is either 0 or
 * or 1, depending on implementation.  The lower segment will match.  A counter
 * example: Picture the same situation but with curved segments stacked in the shape
 * of the number 3.
 */
- (BOOL)getConnectingPath:(int *)pathId progress:(CGFloat *)progress forEndPoint:(CGPoint)endPoint rotation:(CGFloat)rotationRadians progress:(CGFloat)forProgress scale:(CGFloat)scale;

/**
 * Same as getConnectingPath:progress:forEndPoint:rotation:progress:scale:,
 * but allowing the caller to pass in a hypothetical values for hasSwitch and switchPathId
 * used in the computation.
 */
- (BOOL)getConnectingPath:(int *)pathId progress:(CGFloat *)progress forEndPoint:(CGPoint)endPoint rotation:(CGFloat)rotationRadians progress:(CGFloat)forProgress scale:(CGFloat)scale hasSwitch:(BOOL)hasSwitch switchPathId:(int)switchPathId;

/**
 * Same as getConnectingPath:progress:forEndPoint:rotation:progress:scale:hasSwitch:switchPathId,
 * but does not return the connecting path information.
 */
- (BOOL)hasConnectingPathForEndPoint:(CGPoint)endPoint rotation:(CGFloat)rotationRadians progress:(CGFloat)forProgress scale:(CGFloat)scale;

- (int)pathCount;

- (CGFloat)pathLengthForPath:(int)pathId;

/**
 * Returns the path direction for a given path that represents "going with" the segment's
 * switch.
 *
 * Here's the deal: Some segments have multiple paths.  When the multiple paths
 * share an connection point, then the segment has a switch to choose between them.
 * But in that case the switch has a direction: Traveling, say, "with" the switch,
 * the switch determines your path; traveling "against" the switch, all paths end up
 * end up in the same place regardless of the switch setting.
 *
 * So this method answers the question: If I'm traveling along a path that is switched,
 * which direction is the "going with" way?  The answer is provided by a return value
 * of either FLPathDirectionIncreasing or FLPathDirectionDecreasing.
 */
- (int)pathDirectionGoingWithSwitchForPath:(int)pathId;

@end
