A Next Target Highlighter

A World of Warcraft addon that visually highlights the next enemy target you would select with TAB, focusing on quest-related objectives.

## Features

- **Quest Highlighting:**
	- Highlights nameplates for mobs relevant to your active quests:
		- Quest objectives
		- Quest items (soft target icon)
		- World quest targets
	- Only highlights the current target if it also matches a quest condition.
- **Customizable Styles:**
	- Configure highlight color, thickness, and offset for each quest type.
	- Settings panel available in Interface > AddOns or via `/next config`.
- **Combat Mode:**
	- Optionally restrict highlights to combat only.
- **Debug Panel:**
	- Toggle with `/next debug`.
	- Shows detailed info for up to 8 tracked units:
		- Highlight status (color-coded)
		- Quest context and reason for highlight or filtering
		- Tooltip lines, quest item icon, quest boss status
- **No Rare/Elite Highlighting:**
	- Addon does not highlight rare/elite mobs unless they are quest-related.
- **Clean, Data-Driven UI:**
	- All settings are managed via a scrollable, robust options panel.

## Usage

- **Commands:**
	- `/next config` — Open settings panel
	- `/next toggle` — Enable/disable addon
	- `/next combat` — Toggle combat-only mode
	- `/next debug` — Toggle debug window
- **Settings:**
	- Adjust highlight styles for quest objectives, quest items, and world quests
	- Enable/disable debug panel and combat-only mode

## How It Works

- Scans nameplates for quest relevance using tooltip and quest log data
- Highlights only mobs that match quest objectives, quest items, or world quests
- Current target is highlighted only if it matches a quest condition
- Debug panel provides color-coded, detailed feedback for each tracked unit

## Installation

1. Download or clone the addon into your `Interface/AddOns/next` folder
2. Restart WoW or reload the UI
3. Configure via `/next config` or Interface > AddOns > Next

## Support

For issues or feature requests, open an issue on GitHub or contact the author.

---

**Next Target Highlighter** — Streamline your questing by seeing exactly which mobs matter for your objectives.