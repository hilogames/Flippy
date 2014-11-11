//
//  FLViewController.h
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo Games. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>
#import <UIKit/UIKit.h>

#import "FLTrackScene.h"
#import "HLSpriteKit.h"

@interface FLViewController : UIViewController <HLMenuNodeDelegate, FLTrackSceneDelegate>

@property (nonatomic, readonly) SKView *skView;

@end
