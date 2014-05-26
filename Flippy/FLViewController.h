//
//  FLViewController.h
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <HLSpriteKit/HLSpriteKit.h>
#import <SpriteKit/SpriteKit.h>
#import <UIKit/UIKit.h>
#import "FLTrackScene.h"

@interface FLViewController : UIViewController <HLMenuSceneDelegate, FLTrackSceneDelegate>

@property (nonatomic, readonly) SKView *skView;

@end
