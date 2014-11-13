# Flippy the Train Documentation

## Creating a New Challenge Level

Levels must be numbered consecutively.  Your new level number will be
one greater than the previous largest; see `ChallengeLevels.plist`.
In the example below, substitute your level number wherever you see
`99`.

1. Create the level in Sandbox mode in the simulator.

  - Check that switches are in a normal position.

  - Check that the scene is centered and zoomed intelligently for a
    small screen (iPhone 4S, perhaps).

  - Check starting train location.

  - Be sure to include exactly one starting platform.

  - Save the game.

2. Copy the level from the simulator to the project, and rename it as
   a challenge game.

  - Navigate to the simulator documents folder; the location is logged
    to the Xcode console.

  - Copy the file to the `levels` folder in the project:

        cp level-sandbox-0.archive $FLIPPY_ROOT/Flippy/levels/level-challenge-99.archive

3. Hand-edit a couple things in the save game file.

  - Use `plutil` to convert from binary to XML:

        plutil -convert xml1 level-challenge-99.archive -o level-challenge-99.xml

  - Edit the file:

    - Set `gameType` to `0` (changing "sandbox" to "challenge").

    - Set `gameLevel` to your level number.

    - Set `timerElapsed` to 0.

  - Use `plutil` to convert back to binary:

        plutil -convert binary1 level-challenge-99.xml -o level-challenge-99.archive

4. Edit `ChallengeLevels.plist` to include information for your level.
