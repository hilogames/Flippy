
## Known Bugs

- Audio doesn't correctly restart on application interruption.  Er,
  sometimes.  Would seem to be in SpriteKit domain.

- Problems deactivating AVAudioSession on application backgrounding;
  see notes in FLAppDelegate.h.  Would seem to be in SpriteKit domain.

## Small Tasks from User Feedback

- Add visual feedback for first tap on delete button: red background
  or something.

- Leave linking mode on after tutorial in level 1?

- Link to review/rate from About screen.

## Postponed Tasks

- Improve new-user game experience; in particular, it's confusing, and
  unclear what needs to be done to solve the challenge levels.

  - One tester pointed out that using switches for outputs is
    confusing, because it seems like you should manually control a
    switch.  So maybe create a variant of black/white which shows a
    big pink/gray bubble, and no switch?  (They still can be switched
    manually, of course, but they don't *show* a switch.)

  - During tutorial and first level, it should be made clear that the
    position of the train doesn't matter when the solution is checked,
    because the solution-checker looks at all possible train routes.

- Make it an actual game.  You know, for kids.  Ideas:

  - Guns.  A mortar segment which fires and can destroy track when
    activated.  Two tracks face off in a death match.

  - Lights.  Level is dark; lights must be activated in order to allow
    train travel.

  - Monsters.  Combine with guns and monster directional sensors to
    make a program (track) to shoot monsters before they rip up the
    track (program).

  - Robots.  Put track inside a robot, like in Robot Odyssey.  When
    the robot bumps into a wall, the robot's bump sensor flips a
    switch inside where the train is running.  When the train enables
    a direction switch inside the robot, the robot travels in the
    designated direction until another direction switch is enabled.
    The robot moves around a world and performs tasks or challenges.

  - Self-Programming.  Special construction or manipulations segments
    move or rotate or create other segments when activated.

- From goals screen, tap on a results row to show the simulation run.
  Inputs will be set accordingly, and Flippy will be put on the
  starting platform and started.

- Infinite grid.  Restrict minimum zoom, but have no world size.
  Display unused sectors in gray or something, to make it easier to
  find your way back to used sectors.  Or: scroll only to the edge of
  current content plus 10 segments, or something, which then enlarges
  as more segments are added (or even dragged through).  Consider some
  other kind of world navigation tool for navigation between far-flung
  sectors (e.g. an overlay which shows a map of all used sectors on a
  grid, and you can tap the sector to which you want to navigate).
  Persist distant sectors to disk and load on demand.  Remove their
  FLSegmentNodes from the SKScene node tree, and re-add as needed.

- Draw Retina assets for non-pixelated artwork (e.g. toolbar buttons).
  Create tools@2x.atlas and tools@3x atlast.
  Re-create grass textures for 1x 2x and 3x from original 2048 image.
  Re-create loading screen to match.

  - That would meaning providing a 2208x2208 tiled grass image to the
    Launch Screen (so that it matches the 3x retina display on iPhone
    6+).  That might cause troubles; perhaps should switch to using a
    plain green launch screen rather than the tiled grass image.

- Records screen (showing records for all levels).

- Localize the saved circuit/gate names, perhaps in a plist like the
  challenge level information.

- For challenge games, show the level title in the save game slots
  when loading and saving.  (Need to encode the level number
  separately from the track scene, I think, so that the track scene
  doesn't have to be unencoded just to get some meta information.  I
  think it is possible to encode it at the top level of the archive,
  and then open the archive and only decode the meta-information keys,
  without decoding the track scene.  Although: Does prepping an
  NSKeyedUnarchiver with binary XML data, and then scanning through
  it, require too much time even without encoding the track scene
  within?)

- Generate terrain in a way that is less uniform than just a tiled
  image?  At one point I had an idea to do clustered patches of
  squares in earth tones, procedurally generated.

- Destruction of non-track-ish segments (readout, platform) should not
  use the same particle emitters as track-ish segments.

- Prettier Bezier curves for links . . . well, if it does indeed look
  better.  Control points chosen so that the links always curve a bit:
  Perhaps usually normal to the switch dirction, in the direction of
  the other endpoint, but then if the other endpoint has the same X or
  Y coordinate, then bend it 45 degrees or something.

- For import thumbnails: Draw simple CoreGraphics lines tracing track
  segment paths rather than shrinking down textures/images.  The
  result might be better.  (And wouldn't need UIImages anymore in
  FLTextureStore.)

- For multisegment rotation: In case of conflict, search for nearby
  pivot that would work without conflicts.  Shouldn't be hard to check
  a few.

- Inertia for scrolling pan motion.

- Consider doing tutorial stuff for the Half Adder level: Show the
  user how to handle gates/circuits/exports/deletions.

- If multiple trains, then train edit menu for play/pause controls
  (and an explicit way to turn train around, perhaps).

- Draw a line with your finger, segments created automatically.
  Better: A special "auto connect" path subtrack which calculates a
  path between two specified segments and maintains the connection
  following moves and rotations of those segments.

- Undo stack.

- Interface option allowing suppression of interface navigation
  messages.  This would allow perhaps adding a few more navigation
  messages for beginners (which would otherwise certainly be
  annoying), e.g. describing a sub-toolbar (segments, gates, circuits,
  exports, deletions) when navigating to it.

## Release Checklist

- unit test
- analyze code
- genstrings
- increment version and/or build string
- commit
- archive
