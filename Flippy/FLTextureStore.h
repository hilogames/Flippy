//
//  FLTextureStore.h
//  Flippy
//
//  Created by Karl Voskuil on 12/12/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SpriteKit/SpriteKit.h>

// noob: This texture store supports both UIImages and SKTextures for our textures.
// The textures typically use texture atlases, and there's currently no (good) way
// to draw that texture into a CoreGraphics context (or something similar), so
// instead the expectation is that both UIImage and SKTexture are provided by the
// caller.  When textures are loaded from a texture atlas using a single key, the image
// must exist both as an image in the bundle and as part of the texture atlas.

@interface FLTextureStore : NSObject

+ (FLTextureStore *)sharedStore;

- (SKTexture *)textureForKey:(NSString *)key;

- (UIImage *)imageForKey:(NSString *)key;

- (void)setTextureWithImage:(UIImage *)image forKey:(NSString *)key filteringMode:(SKTextureFilteringMode)filteringMode;

@end
