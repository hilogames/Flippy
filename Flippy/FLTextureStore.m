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
    [sharedStore loadTextureForKey:@"link" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"file-operations" filteringMode:SKTextureFilteringLinear];
    [sharedStore loadTextureForKey:@"import" filteringMode:SKTextureFilteringLinear];
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
  }
  return self;
}

- (void)loadTextureForKey:(NSString *)key filteringMode:(SKTextureFilteringMode)filteringMode
{
  // Perhaps we should just allow the object owner to configure the texture arbitrarily
  // before setting it.  But for now, make the store the expert.
  NSString *imageName = [key stringByAppendingPathExtension:@"png"];
  SKTexture *texture = [SKTexture textureWithImageNamed:imageName];
  if (texture) {
    texture.filteringMode = filteringMode;
    [_textures setValue:texture forKey:key];
  }
}

- (SKTexture *)textureForKey:(NSString *)key
{
  SKTexture *texture = [_textures objectForKey:key];
  if (!texture) {
    [NSException raise:@"FLTextureStoreMissingTexture" format:@"Texture key '%@' not found in store.", key];
  }
  return texture;
}

@end

