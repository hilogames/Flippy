//
//  FLTextureStore.h
//  Flippy
//
//  Created by Karl Voskuil on 12/12/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SpriteKit/SpriteKit.h>

@interface FLTextureStore : NSObject

+ (FLTextureStore *)sharedStore;

- (SKTexture *)textureForKey:(NSString *)key;

@end
