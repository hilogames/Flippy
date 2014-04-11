//
//  FLTextureStore.m
//  Flippy
//
//  Created by Karl Voskuil on 12/12/13.
//  Copyright (c) 2013 Hilo. All rights reserved.
//

#import "FLTextureStore.h"

@implementation FLTextureStore
{
  NSDictionary *_textures;
  NSDictionary *_images;
}

+ (FLTextureStore *)sharedStore
{
  static FLTextureStore *sharedStore = nil;
  if (!sharedStore) {
    sharedStore = [[FLTextureStore alloc] init];

    // Train.
    [sharedStore loadTextureForKey:@"engine" filteringMode:SKTextureFilteringNearest];

    // Segments.
    [sharedStore loadTextureForKey:@"straight" filteringMode:SKTextureFilteringNearest];
    [sharedStore loadTextureForKey:@"curve" filteringMode:SKTextureFilteringNearest];
    [sharedStore loadTextureForKey:@"join-left" filteringMode:SKTextureFilteringNearest];
    [sharedStore loadTextureForKey:@"join-right" filteringMode:SKTextureFilteringNearest];
    [sharedStore loadTextureForKey:@"jog-left" filteringMode:SKTextureFilteringNearest];
    [sharedStore loadTextureForKey:@"jog-right" filteringMode:SKTextureFilteringNearest];
    [sharedStore loadTextureForKey:@"cross" filteringMode:SKTextureFilteringNearest];

    // Tools.
    [sharedStore loadTextureForKey:@"play" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"pause" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"ff" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"fff" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"center" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"delete" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"rotate-cw" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"rotate-ccw" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"toggle-switch" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"main" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"segments" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"gates" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"circuits" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"exports" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"link" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"export" filteringMode:SKTextureFilteringLinear];
    
    // Other.
    [sharedStore loadTextureForKey:@"switch" filteringMode:SKTextureFilteringNearest];
  }
  return sharedStore;
}

- (id)init
{
  self = [super init];
  if (self) {
    _textures = [[NSMutableDictionary alloc] init];
    _images = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)loadTextureForKey:(NSString *)key filteringMode:(SKTextureFilteringMode)filteringMode
{
  // Load texture first, so that it will look in texture atlases as appropriate.
  SKTexture *texture = [SKTexture textureWithImageNamed:key];
  if (!texture) {
    [NSException raise:@"FLTextureStoreTextureNotFound" format:@"Could not find texture with key '%@'.", key];
  }

  // Now, separately, load the image.  Use a special name to keep it separate from the texture
  // atlas version.  It is only required if requested later, so don't throw an exception until
  // then if not found.
  NSString *imageName = [key stringByAppendingString:@"-nonatlas"];
  UIImage *image = [UIImage imageNamed:imageName];

  texture.filteringMode = filteringMode;
  [_textures setValue:texture forKey:key];
  [_images setValue:image forKey:key];
}

- (SKTexture *)textureForKey:(NSString *)key
{
  return [_textures objectForKey:key];
}

- (void)setTextureWithImage:(UIImage *)image forKey:(NSString *)key filteringMode:(SKTextureFilteringMode)filteringMode
{
  SKTexture *texture = [SKTexture textureWithImage:image];
  if (texture) {
    texture.filteringMode = filteringMode;
    [_textures setValue:texture forKey:key];
    [_images setValue:image forKey:key];
  }
}

- (UIImage *)imageForKey:(NSString *)key
{
  UIImage *image = [_images objectForKey:key];
  if (!image) {
    [NSException raise:@"FLTextureStoreImageNotFound" format:@"Could not find image with key '%@'.  (If the image is part of a texture atlas, it must also be included as a resource in the application bundle with the suffix '-nonatlas'.)", key];
  }
  return [_images objectForKey:key];
}

@end

