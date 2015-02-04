//
//  HLScene.h
//  HLSpriteKit
//
//  Created by Karl Voskuil on 5/21/14.
//  Copyright (c) 2014 Hilo Games. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

/**
 A mode specifying how hit-testing should work in a gesture recognition system.

 @bug Seemingly obvious, but currently unimplemented, would be a mode where intersecting
      nodes are collected by `[SKNode nodesAtPoint]` and then traversed in order of
      `zPosition` (highest to lowest).  `HLSceneGestureTargetHitTestModeZPosition`,
      presumably.  But parent-traversal is already coded, and works in simple cases, so
      I'm delaying implementation until I have a use-case for `zPosition`-only.
*/
typedef NS_ENUM(NSInteger, HLSceneGestureTargetHitTestMode) {
  /**
   Uses `[SKNode nodeAtPoint]` to find the deepest intersecting node, and then traverses
   up the node tree looking for handlers.  Presumably this mode works best with `SKScene`s
   where `ignoresSiblingOrder` is `NO` (the default), so that this hit-test finds things
   in render order.
  */
  HLSceneGestureTargetHitTestModeDeepestThenParent,
  /**
   Uses `[SKNode nodesAtPoint]` to find the intersecting node with the highest
   `zPosition`, and then traverses up the node tree looking for handlers.  Presumably this
   mode works best with `SKScene`s where `ignoresSiblingOrder` is `YES`, so that this
   hit-test finds things in render order.
  */
  HLSceneGestureTargetHitTestModeZPositionThenParent,
//  HLSceneGestureTargetHitTestModeZPosition,
};

/**
 A style of animation for presentation or dismissal of modal nodes.
*/
typedef NS_ENUM(NSInteger, HLScenePresentationAnimation) {
  /**
   No animation during presentation or dismissal of modal nodes.
  */
  HLScenePresentationAnimationNone,
  /**
   A short fade animation during presentation or dismissal of modal nodes.
  */
  HLScenePresentationAnimationFade,
};

/**
 Optional behaviors for descendant nodes in the scene's node tree.

 Intended for extension by subclasses.  Identifiers for new options should be prefixed
 with class name to namespace them; values should be strings containing the identifier
 name.
*/
/**
 Option for `registerDescendent:withOptions:`: Do not encode this node (or any of its
 children) during <NSCoding> operations.
*/
FOUNDATION_EXPORT NSString * const HLSceneChildNoCoding;
/**
 Option for `registerDescendent:withOptions:`: Set this node's size property with the size
 of the scene when the scene size changes.
*/
FOUNDATION_EXPORT NSString * const HLSceneChildResizeWithScene;
/**
 Option for `registerDescendent:withOptions:`: Considers this child node's gesture target
 (via `[SKNode+HLGestureTarget hlGestureTarget]`) when processing gestures with the
 default `HLScene` gesture recognition system; see `HLGestureTarget`.
*/
FOUNDATION_EXPORT NSString * const HLSceneChildGestureTarget;

/**
 `HLScene` contains functionality useful to many scenes, including but not limited to:

   - loading scene assets in a background thread

   - registration of nodes for common scene-related behaviors (for example, resizing when
     the scene resizes, and not encoding when the scene encodes)

   - a shared gesture recognition system and an `HLGestureTarget`-aware gesture delegate
     implementation

   - modal presentation of a node above the scene

 ## Shared Gesture Recognition System

 `HLScene` implements a gesture recognition system that can forward gestures to
 HLGestureTarget nodes registered with the appropriate option (`HLSceneChildGestureTarget`
 in `registerDescendant:withOptions:`).  The system implementation works by magic and does
 exactly what you want it to without configuration.  If, however, you do not want to
 partake in the mysteries, do not register any nodes with the gesture target option, and
 feel free not to call `super` on any of the `UIGestureRecognizerDelegate` methods (though
 they will try not to do anything surprising if called).

 ### Subclassing Notes for the Shared Gesture Recognition System

 - The `HLScene` calls the `needSharedGestureRecognizers:` method to create gesture
   recognizers for any gesture recognizers needed by `HLGestureTarget` nodes registered
   with `registerDescendant:withOptions:`.

 - Subclasses shall call the `needSharedGestureRecognizers:` to create any other needed
   gesture recognizers.  The method is safe to call multiple times, and will only create
   gesture recognizers if an equivalent one (according to
   `HLGestureTarget_areEquivalentGestureRecognizers()`) is not already created.

 - The `HLScene` implementation of `[SKScene didMoveToView:]` adds any created gesture
   recognizers to the view.  The implementation of `[SKScene willMoveFromView:]` removes
   them.  (Gesture recognizers created in between will add themselves to the scene's view
   automatically.)

 @bug Composition would be better than inheritance.  Consider grouping functionality into
      modules or functions.
*/
@interface HLScene : SKScene <NSCoding, UIGestureRecognizerDelegate>
{
  NSMutableArray *_sharedGestureRecognizers;
}

/// @name Loading Scene Assets

/**
 Calls `loadSceneAssets` in a background thread, and, when finished, calls the
 `completion` on the main thread.
*/
+ (void)loadSceneAssetsWithCompletion:(void(^)(void))completion;

/**
 Overridden by the `HLScene` subclass to load all scene assets.
 */
+ (void)loadSceneAssets;

/**
 Returns `YES` if `loadSceneAssets` has been called.
*/
+ (BOOL)sceneAssetsLoaded;

/**
 Logs a non-critical error if `loadSceneAssets` has not been called.
*/
+ (void)assertSceneAssetsLoaded;

/// @name Registering Nodes With Custom Behavior

/**
 Convenience method which calls `registerDescendant:withOptions:` when adding a child.
*/
- (void)addChild:(SKNode *)node withOptions:(NSSet *)options;

/**
 Registers a node (a descendant in the scene's node tree) for various automatic behavior
 in the scene.

 See documentation of `HLSceneChild*` values.

 In general it is not strictly required that the node be currently part of the scene's
 node tree, but certain options might assume it.

 Custom behavior attempts to be extremely low-overhead for non-registered nodes, so that
 scenes can subclass `HLScene` and only subscribe to the desired behavior without other
 impact.  Some memory overhead is to be expected, both for the class and for registered
 nodes; nodes can be unregistered by `unregisterDescendant:`.

 Failure to unregister nodes often has little functional impact, but it will retain
 references unnecessarily.

 @bug One problem with the current design, for the record: Each node (usually) gets
      retained in a collection for its feature.  If many nodes are registered, then the
      memory use will be significant.  That said, the options do not lend themselves to
      widespread use on lots and lots of nodes in the scene.

 @bug An alternate design would be to put requests for scene behavior in the nodes
      themselves (perhaps by having them conform to protocols, or perhaps by having them
      subclass a `HLNode` class which can track desired options).  Then, children in the
      scene don't need to be added specially; they can be discovered during normal adding
      with addChild:, or else discovered lazily (by scanning the node tree) when needed.
      The main drawback seems to be an invisible performance impact (no matter how small)
      for the `HLScene` subclass.  With explicit registration, the subclasser can be
      relatively confident that nothing is going on that wasn't requested.  Also with
      explicit registration, the caller is able to override node information, for example
      not registering a child for gesture recognition even though it has an
      `HLGestureTarget`.

 @bug Okay, one more note: I waffle a bit on gesture targets.  They are easily discovered
      implicitly (by `[SKNode+HLGestureTarget hlGestureTarget]` method); the use case for
      adding a gesture target to a scene but not wanting it to receive gestures is small
      (and could be addressed by registering a node to *not* be a target if needed); and
      it's somewhat surprising when you add some kind of interactive node to a scene and
      it doesn't interact.  But, on the other hand: It's really nice having the `HLScene`
      manage the shared gesture recognizer objects during registration (by asking the
      target what recognizers it needs).  So, waffle.
*/
- (void)registerDescendant:(SKNode *)node withOptions:(NSSet *)options;

/**
 Unregisters a node.

 Nodes are registered by `registerDescendant:withOptions:`.  See documentation there for
 comments on unregistration.
*/
- (void)unregisterDescendant:(SKNode *)node;

/// @name Configuring the Shared Gesture Recognizer System

/**
 The mode used for hit-testing in the `HLScene` implementation of
 `[UIGestureRecognizerDelegate gestureRecognizer:shouldReceiveTouch:]`.

 `HLScene` implements `gestureRecognizer:shouldReceiveTouch`: to look for
 `HLGestureTarget` nodes which intersect the touch and see if any of them want to handle
 the gesture.  The `HLSceneGestureTargetHitTestMode` determines the way that the method
 finds targets: Should it start with the node deepest in the tree, or with the highest
 `zPosition`?  If not stopping with the first node hit, should it then look for more
 targets by traversing parents in the node tree, or again by `zPosition`?

 See `HLSceneGestureTargetHitTestMode` for the options.
*/
@property (nonatomic, assign) HLSceneGestureTargetHitTestMode gestureTargetHitTestMode;

/**
 Instructs the scene that certain gesture recognizers should be added to the shared
 gesturer recognizer system.

 Before adding, each passed gesture recognizer is checked to see if it is equivalent to a
 gesture recognizer already added to the shared gesture recognizer system.  Equivalent
 gesture recognizer are defined by `HLGestureTarget_areEquivalentGestureRecognizers()`.

 For gesture recognizers not already added, this method:

 - adds the gesture recognizer to the shared list;
 - adds it to the scene's view (if the view exists);
 - sets the `HLScene` as delegate;
 - and removes any existing target/action pairs.

 For gesture recognizers that already have an equivalent added, this method does nothing.

 Recognizers added before the scene's view exists will be added to the view by `[HLScene
 didMoveToView]`.
*/
- (void)needSharedGestureRecognizers:(NSArray *)gestureRecognizer;

/// @name Presenting a Modal Node

/**
 Presents a node modally above the current scene, disabling other interaction.

 By convention, the modal layer is not persisted during scene encoding.

 The goal is to present the modal node "above" the current scene, which may or may not
 require careful handling of `zPosition`, depending on `[SKView ignoresSiblingOrder]`.
 It's left to the caller to provide an appropriate `zPosition` range that can be used by
 this scene to display the presented node and other related decorations and animations.
 The presented node will have its `zPosition` set to a value in the provided range, but
 exactly what value is implementation-specific.  The range may be passed empty; that is,
 min and max may the the same.  If the `zPositionMin` and `zPositionMax` parameters are
 not needed, `presentModalNode:animation:` may be called instead.

 @param node The node to present modally.  The scene will not automatically dismiss the
             presented node.  (As with all `HLScene` nodes, if the node or any of its
             children have `HLGestureTargets` registered with the scene as
             `HLSceneChildGestureTarget` then it will have gestures forwarded to it by the
             `HLScene`'s gesture handling code.)

 @param animation Optional animation for the presentation.  See
                  `HLScenePresentationAnimation`.

 @param zPositionMin A lower bound (inclusive) for a range of `zPosition`s to be used by
                     the presented node and other related decorations and animations.  See
                     note in discussion.

 @param zPositionMax An upper bound (inclusive) for a range of `zPosition`s to be used by
                     the presented node and other related decorations and animations.  See
                     note in discussion.
*/
- (void)presentModalNode:(SKNode *)node
               animation:(HLScenePresentationAnimation)animation
            zPositionMin:(CGFloat)zPositionMin
            zPositionMax:(CGFloat)zPositionMax;

/**
 Convenience method for calling `presentModalNode:animated:zPositionMin:zPositionMax:`
 with `0.0` passed to the last two parameters.

 This is a more readable (more sensible looking) version when the scene does not need
 `zPositions` passed in; usually if the `HLScene` is subclassed, this will be the
 preferred invocation (since the subclass will override the main present modal node method
 to ignore the passed-in `zPositions`).
*/
-(void)presentModalNode:(SKNode *)node
              animation:(HLScenePresentationAnimation)animation;

/**
 Dismisses the node currently presented (if any).
*/
- (void)dismissModalNodeAnimation:(HLScenePresentationAnimation)animation;

/**
 Returns the node currently presented, or `nil` for none.
*/
- (SKNode *)modalNodePresented;

@end
