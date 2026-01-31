# next - Quest Target Nameplate Highlighter

## Architecture Overview

World of Warcraft addon that highlights enemy nameplates based on quest relevance. Analyzes quest log and nameplate tooltips to determine which enemies are quest objectives, quest item droppers, world quest targets, or bonus objectives, then applies customizable visual highlights.

**Core Components:**
- [`Core.lua`](../Core.lua): Event registration, update scheduling, slash commands
- [`Database.lua`](../Database.lua): Settings persistence, defaults, migrations, table utilities
- [`Classification.lua`](../Classification.lua): Quest data parsing, nameplate tooltip analysis, caching
- [`Highlights.lua`](../Highlights.lua): Visual rendering, texture pooling, healthbar resolution
- [`Settings.lua`](../Settings.lua): Settings panel UI with per-highlight-type customization
- [`Debug.lua`](../Debug.lua): Debug window showing real-time classification results

**Load Order:** [`next.toc`](../next.toc) - Database → Classification → Highlights → Debug → Core → Settings

## Data Flow Architecture

**Update Pipeline:**
```
WoW Event → RequestUpdate() → 0.05s debounce → UpdateHighlight()
  ↓
CollectHighlights() reads quest log + scans nameplates
  ↓
Classification.lua parses tooltips, matches quest data
  ↓
Highlights.lua applies textures to healthbars
```

**Caching Strategy:**
- Quest cache: `Classification.lua` caches quest objectives/items in `addon.questCache`
- Cache invalidates on any quest-related event (QUEST_ACCEPTED, QUEST_REMOVED, etc.)
- `ResetCaches()` called before collecting new highlights
- Prevents redundant tooltip scanning/parsing per frame

## Nameplate Healthbar Resolution

**API Breaking Changes:**
WoW frequently restructures nameplate frame hierarchy. Current paths checked in order:
```lua
-- Highlights.lua:37-51
plate.UnitFrame.healthBar  -- Current (Midnight/TWW)
plate.UnitFrame.healthBars.healthBar
plate.UnitFrame.HealthBarsContainer.healthBar
plate.healthBar  -- Legacy fallback
```

**Caching Pattern:**
```lua
-- Cache resolved healthbar on plate frame to avoid repeated traversal
if plate.next_healthBar and plate.next_healthBar:IsVisible() then
    return plate.next_healthBar
end
-- ... resolution logic ...
plate.next_healthBar = healthBar  -- Store for next access
```

**Why This Matters:** Nameplate updates happen frequently. Without caching, we'd traverse the frame tree 100+ times per second.

## Tooltip Analysis Pattern

**Critical Implementation ([`Classification.lua`](../Classification.lua)):**
```lua
-- WoW doesn't provide APIs to check "is this mob a quest objective"
-- Must scan the actual tooltip text that appears on mouseover
local tooltip = _G["NextTargetTooltip"] or CreateFrame("GameTooltip", "NextTargetTooltip", nil, "GameTooltipTemplate")
tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
tooltip:SetUnit(unitToken)  -- e.g., "nameplate1"

-- Scan tooltip lines for quest indicators
for i = 1, tooltip:NumLines() do
    local line = _G["NextTargetTooltipTextLeft" .. i]
    local text = line and line:GetText()
    -- Look for: quest names, "Quest Item" text, progress bars
end
```

**Quest Item Detection:**
- Items shown in tooltip section with item icons
- Must check `GetTooltipData()` item sections
- Fallback: scan for tooltip region textures (item icons appear as textures)

## Highlight Style System

**Three Style Types:**
1. **"blizzard"**: Uses native `SetTargetingTexture()` (clean, integrated)
2. **"outline"**: Custom border textures around healthbar edges
3. **"glow"**: Soft glow effect via textured overlay

**Per-Type Configuration:**
Each highlight type (currentTarget, questObjective, questItem, worldQuest, bonusObjective) has:
- `*Style`: "blizzard" | "outline" | "glow"
- `*Color`: {r, g, b, a}
- `*Thickness`: Border width (outline mode)
- `*Offset`: Spacing from healthbar edge

**Applying Highlights:**
See [`Highlights.lua:GetOrCreateHighlight()`](../Highlights.lua) - creates/reuses textures based on style settings.

## Texture Pooling (Memory Management)

**Problem:** Creating/destroying textures every frame causes memory leaks and lag.

**Solution:** Object pooling pattern
```lua
addon.texturePool = {}

local function acquireTexture()
    return table.remove(addon.texturePool) or UIParent:CreateTexture(...)
end

local function releaseTexture(texture)
    texture:Hide()
    texture:ClearAllPoints()
    -- ... reset all properties ...
    table.insert(addon.texturePool, texture)
end
```

Used in [`Highlights.lua:6-33`](../Highlights.lua#L6-L33). Always release textures when clearing highlights.

## Database Migrations

**Migration Pattern ([`Database.lua:40-50`](../Database.lua#L40-L50)):**
```lua
-- Old setting names → New setting names
local MIGRATION_MAP = {
    showCurrentTarget = "currentTargetEnabled",
    currentBorderThickness = "currentTargetThickness",
    -- ...
}
```

When `DB_VERSION` increments:
1. Remap old keys to new keys
2. Sanitize style values (convert invalid values to "blizzard")
3. Merge new defaults for missing keys

**Why:** Users upgrading from old versions shouldn't lose settings or crash.

## Debug Window

**Usage:** `/next debug` toggles debug overlay

**Displays:**
- List of all visible nameplates
- Unit name, unit token (nameplate1, nameplate2, etc.)
- Classification result (Quest Objective, Quest Item, World Quest, etc.)
- Quest name/ID associated with highlight

**Implementation:** Real-time table in draggable frame, updates with every `UpdateHighlight()` call.

## Instance Detection

**Key Optimization:**
```lua
local inInstance, instanceType = IsInInstance()
if inInstance then
    self:ClearHighlights()
    return
end
```

Highlights disabled in dungeons/raids (no quest nameplates there). Prevents wasted processing and visual clutter.

## Slash Commands

- `/next` - Show help, open settings
- `/next config` - Open settings panel
- `/next toggle` - Enable/disable addon
- `/next debug` - Toggle debug window

**Sanitization:** All commands go through `sanitizeCommand()` to handle nil input, trim whitespace, lowercase.

## Common WoW API Patterns

**Event Registration:**
```lua
addon.frame:RegisterEvent("QUEST_LOG_UPDATE")
addon.frame:SetScript("OnEvent", function(_, event, ...)
    eventHandlers[event](addon, ...)
end)
```

**Debouncing Updates:**
```lua
-- Prevent update spam when multiple events fire rapidly
if self.pendingUpdate then return end
self.pendingUpdate = true
C_Timer.After(0.05, function()
    addon.pendingUpdate = false
    addon:UpdateHighlight()
end)
```

**Settings Panel Registration (Dragonflight+):**
```lua
local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
```

## Testing Workflows

1. **Quest Objective Test:**
   - Accept quest with kill objectives
   - Target mob → verify highlight color matches setting
   - Verify current target highlight overrides quest highlight

2. **Quest Item Test:**
   - Accept quest requiring item drops
   - Target mob that drops item but isn't kill objective
   - Verify different color from objective highlight

3. **World Quest Test:**
   - Activate world quest in zone
   - Target relevant mob
   - Verify world quest highlight color

4. **Style Test:**
   - Change style to "outline" → verify border appears
   - Change to "glow" → verify glow effect
   - Change to "blizzard" → verify native targeting texture

5. **Debug Window:**
   - Enable debug window
   - Target various mobs
   - Verify classification matches visual highlights

**Common Issues:**
- Highlights not showing: Check if in instance (auto-disabled), verify nameplate addon compatibility
- Wrong mob highlighted: Quest cache stale → reload UI
- Performance lag: Texture pool full → clear highlights forces cleanup
