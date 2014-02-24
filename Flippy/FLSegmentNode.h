//
//  FLSegmentNode.h
//  Flippy
//
//  Created by Karl Voskuil on 2/22/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

enum FLSegmentType { FLSegmentTypeNone, FLSegmentTypeStraight, FLSegmentTypeCurve, FLSegmentTypeJoin };

@interface FLSegmentNode : SKSpriteNode

@property (nonatomic) FLSegmentType segmentType;

- (id)initWithSegmentType:(FLSegmentType)segmentType;

- (id)initWithTextureKey:(NSString *)textureKey;

- (void)getPoint:(CGPoint *)point rotation:(CGFloat *)rotationRadians forProgress:(CGFloat)progress scale:(CGFloat)scale;

- (CGFloat)getClosestOnSegmentPoint:(CGPoint *)onSegmentPoint rotation:(CGFloat *)rotationRadians forOffSegmentPoint:(CGPoint)offSegmentPoint scale:(CGFloat)scale precision:(CGFloat)precision;

@end
