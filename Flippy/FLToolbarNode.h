//
//  FLToolbarNode.h
//  Flippy
//
//  Created by Karl Voskuil on 12/12/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>
#include "FLGestureTarget.h"

@interface FLToolbarNode : SKSpriteNode

/**
 * The extra space added between the edge of the box (made for the tool) and the tool sprite.
 * Negative values mean the box will be drawn smaller than the tool sprite.
 */
@property (nonatomic) CGFloat toolPad;

/**
 * Sets toolbar with tools from the textures specified by the passed keys.
 * Rotations (array of NSNumbers with CGFloats) and offets (array of NSValues
 * with CGPoints) are used to rotate and offset the textures within their
 * allotted toolbar spaces.
 */
- (void)setToolsWithTextureKeys:(NSArray *)keys sizes:(NSArray *)sizes rotations:(NSArray *)rotations offsets:(NSArray *)offsets;

/**
 * Returns the key of the tool at the passed location, or nil for none.  The
 * location is expected to be in the coordinate system of this toolbar node.
 */
- (NSString *)toolAtLocation:(CGPoint)location;

- (void)runShowWithOrigin:(CGPoint)origin;

- (void)runHideWithOrigin:(CGPoint)origin removeFromParent:(BOOL)removeFromParent;

@end
