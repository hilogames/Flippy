//
//  FLMyScene.mm
//  Flippy
//
//  Created by Karl Voskuil on 11/19/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLMyScene.h"

@implementation FLMyScene

- (id)initWithSize:(CGSize)size
{
  self = [super initWithSize:size];
  if (self) {
    self.backgroundColor = [SKColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    
    SKLabelNode *myLabel = [SKLabelNode labelNodeWithFontNamed:@"Helvetica"];
    
    myLabel.text = @"Hello, World!";
    myLabel.fontSize = 30;
    myLabel.position = CGPointMake(CGRectGetMidX(self.frame),
                                   CGRectGetMidY(self.frame));
    
    [self addChild:myLabel];
  }
  return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  for (UITouch *touch in touches) {
    CGPoint location = [touch locationInNode:self];
    SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithImageNamed:@"Spaceship"];
    sprite.position = location;
    SKAction *action = [SKAction rotateByAngle:M_PI duration:1];
    [sprite runAction:[SKAction repeatActionForever:action]];
    [self addChild:sprite];
  }
}

- (void)update:(CFTimeInterval)currentTime
{
}

@end
