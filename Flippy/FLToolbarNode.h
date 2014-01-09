//
//  FLToolbarNode.h
//  Flippy
//
//  Created by Karl Voskuil on 12/12/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface FLToolbarNode : SKSpriteNode

// Sets toolbar with tools from the textures specified by the passed keys.
// Rotations are 
// Offsets are NSValues with CGPoints used to offset the position of each
// texure within its toolbar space.
- (void)setToolsWithTextureKeys:(NSArray *)keys rotations:(NSArray *)rotations offsets:(NSArray *)offsets;

@end
