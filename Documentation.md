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

## Creating a New Icon

The basis for the icon art on the first draft was the
intentionally-pixellated track art, at an original resolution of
54x54, with the track occupying 43x43 of those pixels.  For icon size
29 I resampled (bicubic sharp) to half the size (and then padded out
to 29 in the background); for icon size 40 I resampled (bicubic sharp)
to two-thirds the size (and then padded out in the background).  Icon
sizes 50, 57, 58, 60, 72, 76, 80, and 87 I just padded the background
of the original image (without resizing the track).  Then for all
larger icon sizes I scaled one of those base images an even multiple
using nearest-neighbor sampling:

    convert icon-50.png -filter point -resize 100x100 icon-100.png
    convert icon-57.png -filter point -resize 114x114 icon-114.png
    convert icon-60.png -filter point -resize 120x120 icon-120.png
    convert icon-72.png -filter point -resize 144x144 icon-144.png
    convert icon-76.png -filter point -resize 152x152 icon-152.png
    convert icon-60.png -filter point -resize 180x180 icon-180.png
