//
//  FLMenuScene.h
//  Flippy
//
//  Created by Karl Voskuil on 5/1/14.
//  Copyright (c) 2014 Hilo. All rights reserved.
//

#import <HLSpriteKit/HLSpriteKit.h>
#import <SpriteKit/SpriteKit.h>

#import "FLScene.h"

@class FLMenu;

@interface FLMenuScene : FLScene <NSCoding>

@property (nonatomic, strong) NSString *backgroundImageName;

@property (nonatomic, strong) FLMenu *menu;

@property (nonatomic, assign) CGFloat itemSpacing;

@property (nonatomic, strong) HLLabelButtonNode *buttonPrototype;

@end

@interface FLMenuItem : NSObject <NSCoding>

@property (nonatomic, copy) NSString *text;

@property (nonatomic, strong) HLLabelButtonNode *buttonPrototype;

- (id)initWithText:(NSString *)text;

@end

@interface FLMenu : FLMenuItem <NSCoding>

- (void)addItem:(FLMenuItem *)item;

- (NSUInteger)itemCount;

- (FLMenuItem *)itemAtIndex:(NSUInteger)index;

@end
