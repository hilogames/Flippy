//
//  FLToolbarNode.h
//  Flippy
//
//  Created by Karl Voskuil on 12/12/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@protocol FLToolbarNodeDelegate;

@interface FLToolbarNode : SKSpriteNode

@property (nonatomic, weak) id <FLToolbarNodeDelegate> delegate;

// Sets toolbar with tools from the textures specified by the passed keys.
// Rotations (array of NSNumbers with CGFloats) and offets (array of NSValues
// with CGPoints) are used to rotate and offset the textures within their
// allotted toolbar spaces.
- (void)setToolsWithTextureKeys:(NSArray *)keys rotations:(NSArray *)rotations offsets:(NSArray *)offsets;

@end

@protocol FLToolbarNodeDelegate <NSObject>

- (void)toolBarNode:(FLToolbarNode *)toolbarNode tapsTool:(NSString *)tool;

@end
