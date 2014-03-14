//
//  FLTrackScene.h
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>
#import "FLToolbarNode.h"

@interface FLTrackScene : SKScene <NSCoding, UIGestureRecognizerDelegate, FLGestureTarget>

+ (FLTrackScene *)load:(NSString *)saveName;

- (void)save:(NSString *)saveName;

@end
