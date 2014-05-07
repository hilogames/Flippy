//
//  FLTrackScene.h
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

#import "FLScene.h"
#import "FLToolbarNode.h"
#import "FLTrain.h"

@interface FLTrackScene : FLScene <NSCoding, UIAlertViewDelegate, UIGestureRecognizerDelegate, FLGestureTarget, FLTrainDelegate>

+ (FLTrackScene *)load:(NSString *)saveName;

- (void)save:(NSString *)saveName;

@end
