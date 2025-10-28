# kNow Each Exact Target (NEXT)

A World of Warcraft addon that highlights the target that would be selected when pressing TAB.

## Features

- **Visual Highlight**: Shows a pulsing yellow highlight on enemy nameplates
- **Debug Mode**: Displays a moveable frame showing detailed information about the next target
- **Smart Detection**: Uses angle-based targeting logic to match WoW's TAB targeting system
- **Combat Mode**: Optional setting to only show highlights during combat

## Commands

- `/next` or `/next toggle` - Enable/disable the addon
- `/next debug` - Toggle debug mode (shows moveable frame with target info)
- `/next combat` - Toggle combat-only mode
- `/next help` - Show help commands

## Debug Mode

When you enable debug mode with `/next debug`, a moveable frame will appear showing:
- Name of the next target that would be selected
- Distance to the target in yards
- Angle relative to your facing direction

**To move the debug frame**: Click and drag it anywhere on your screen. The position will be saved.

## Troubleshooting

If you don't see highlights:
1. Enable debug mode with `/next debug` to verify the addon is detecting targets
2. Make sure enemy nameplates are enabled in your WoW settings
3. Check that you're facing enemies and they're in range
4. Try toggling combat mode with `/next combat` if you're not in combat

## How It Works

The addon continuously scans visible nameplates for hostile units, calculates their position relative to your character's facing direction, and determines which enemy would be next in WoW's TAB targeting sequence (clockwise rotation).
