//
//  FLViewController.h
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SpriteKit/SpriteKit.h>

typedef enum FLViewControllerScene { FLViewControllerSceneNone, FLViewControllerSceneMenu, FLViewControllerSceneTrack } FLViewControllerScene;

@interface FLViewController : UIViewController

@property (nonatomic, readonly) SKView *skView;

- (void)scene:(SKScene *)fromScene didInitiateTransitionToScene:(FLViewControllerScene)toScene;

@end
