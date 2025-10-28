-- Next Target Highlighter Addon
-- Highlights the target that would be selected when pressing TAB

local addonName, addon = ...

-- Addon variables
addon.frame = CreateFrame("Frame")
addon.highlights = {}
addon.lastTargetGUID = nil -- Track the last targeted enemy
addon.currentTargetGUID = nil -- Track current target to detect changes

-- Default settings
local defaults = {
    enabled = true,
    highlightColor = {r = 1, g = 1, b = 0, a = 0.8}, -- Yellow for next target
    currentTargetColor = {r = 0, g = 1, b = 0, a = 0.8}, -- Green for current target
    previousTargetColor = {r = 0, g = 0.7, b = 1, a = 0.8}, -- Light blue for previous target
    onlyInCombat = false,
    debugMode = false,
    debugFramePosition = nil,
    borderThickness = 2,
    borderOffset = 1,
    currentBorderThickness = 2,
    currentBorderOffset = 1,
    previousBorderThickness = 2,
    previousBorderOffset = 1,
    showCurrentTarget = true,
    showNextTarget = true,
    showPreviousTarget = true,
}

-- Initialize saved variables
function addon:InitializeDB()
    if not NextTargetDB then
        NextTargetDB = CopyTable(defaults)
    else
        -- Merge defaults with saved settings
        for key, value in pairs(defaults) do
            if NextTargetDB[key] == nil then
                NextTargetDB[key] = value
            end
        end
    end
end

-- Create debug frame
function addon:CreateDebugFrame()
    if self.debugFrame then
        return
    end
    
    local frame = CreateFrame("Frame", "NextTargetDebugFrame", UIParent, "BackdropTemplate")
    frame:SetSize(250, 80)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    
    -- Make it moveable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        NextTargetDB.debugFramePosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("|cFF00FF00next - debug|r")
    
    -- Target name text
    local targetText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    targetText:SetPoint("CENTER", 0, -5)
    targetText:SetJustifyH("CENTER")
    targetText:SetWidth(220)
    frame.targetText = targetText
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        NextTargetDB.debugMode = false
        addon:HideDebugFrame()
        print("|cFF00FF00Next Target|r Debug mode disabled")
    end)
    
    -- Set initial position
    if NextTargetDB.debugFramePosition then
        local pos = NextTargetDB.debugFramePosition
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
    
    self.debugFrame = frame
    frame:Show()
end

-- Show debug frame
function addon:ShowDebugFrame()
    if not self.debugFrame then
        self:CreateDebugFrame()
    end
    self.debugFrame:Show()
end

-- Hide debug frame
function addon:HideDebugFrame()
    if self.debugFrame then
        self.debugFrame:Hide()
    end
end

-- Update debug frame text
function addon:UpdateDebugFrame(nextTarget)
    if not NextTargetDB.debugMode or not self.debugFrame then
        return
    end
    
    if nextTarget then
        local targetName = UnitName(nextTarget.unit) or "Unknown"
        local healthPercent = UnitHealth(nextTarget.unit) / UnitHealthMax(nextTarget.unit) * 100
        
        self.debugFrame.targetText:SetText(
            string.format("|cFFFFFF00Next Target:|r\n|cFF00FF00%s|r\n|cFFAAAAAA%.0f%% HP|r",
                targetName, healthPercent)
        )
    else
        self.debugFrame.targetText:SetText("|cFFFF0000No valid targets|r")
    end
end

-- Get all hostile units in range that could be tab-targeted
function addon:GetHostileUnitsInRange()
    local units = {}
    
    -- Helper function to get unit distance
    local function GetUnitDistance(unit)
        local distanceSquared, checkedDistance = UnitDistanceSquared(unit)
        if checkedDistance and distanceSquared then
            return math.sqrt(distanceSquared)
        end
        return 999
    end
    
    -- Check nameplates (most reliable for enemies in range)
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            local canAttack = UnitCanAttack("player", unit)
            local reaction = UnitReaction(unit, "player")
            local isEnemy = canAttack or (reaction and reaction <= 4)
            
            if isEnemy then
                local guid = UnitGUID(unit)
                if guid then
                    table.insert(units, {
                        unit = unit,
                        guid = guid,
                        distance = GetUnitDistance(unit),
                        nameplateId = i,
                    })
                end
            end
        end
    end
    
    -- If no nameplates found, try other unit IDs
    if #units == 0 then
        -- Check target
        if UnitExists("target") and UnitCanAttack("player", "target") then
            local guid = UnitGUID("target")
            if guid then
                table.insert(units, {
                    unit = "target",
                    guid = guid,
                    distance = GetUnitDistance("target"),
                    nameplateId = 999,
                })
            end
        end
        
        -- Check mouseover
        if UnitExists("mouseover") and UnitCanAttack("player", "mouseover") then
            local guid = UnitGUID("mouseover")
            if guid then
                table.insert(units, {
                    unit = "mouseover",
                    guid = guid,
                    distance = GetUnitDistance("mouseover"),
                    nameplateId = 998,
                })
            end
        end
    end
    
    return units
end

-- Determine which unit would be targeted next by TAB targeting
function addon:GetNextTabTarget()
    local hostileUnits = self:GetHostileUnitsInRange()
    
    if #hostileUnits == 0 then
        return nil
    end
    
    -- If only one target, that's the next one
    if #hostileUnits == 1 then
        return hostileUnits[1]
    end
    
    local currentTarget = UnitGUID("target")
    
    -- Sort units by WoW's TAB targeting behavior:
    -- Primary: Distance (closer targets first)
    -- Secondary: Nameplate ID (screen position left-to-right, top-to-bottom)
    table.sort(hostileUnits, function(a, b)
        local distDiff = math.abs(a.distance - b.distance)
        
        -- If distance differs by more than 5 yards, sort by distance
        if distDiff > 5 then
            return a.distance < b.distance
        end
        
        -- Similar distance, sort by nameplate ID (screen position)
        return a.nameplateId < b.nameplateId
    end)
    
    -- If no current target, return the first in sorted list
    if not currentTarget then
        return hostileUnits[1]
    end
    
    -- Find current target in sorted list and return the next one
    for i, unitData in ipairs(hostileUnits) do
        if unitData.guid == currentTarget then
            -- Return next unit in the list, or wrap to first
            local nextIndex = (i % #hostileUnits) + 1
            return hostileUnits[nextIndex]
        end
    end
    
    -- Current target not in list, return first in sorted list
    return hostileUnits[1]
end

-- Get the last enemy that was targeted (for showing previous target)
function addon:GetLastTargetedEnemy()
    -- If we don't have a last target, return nil
    if not self.lastTargetGUID then
        return nil
    end
    
    -- Check if the last target still exists and is targetable
    local hostileUnits = self:GetHostileUnitsInRange()
    
    for _, unitData in ipairs(hostileUnits) do
        if unitData.guid == self.lastTargetGUID then
            -- Found the last target and it's still valid
            return unitData
        end
    end
    
    -- Last target is no longer valid/targetable
    return nil
end

-- Track target changes to remember the last enemy
function addon:UpdateTargetTracking()
    local currentGUID = UnitGUID("target")
    
    -- If target changed
    if currentGUID ~= self.currentTargetGUID then
        -- If we had a previous target and it was an enemy, save it
        if self.currentTargetGUID and UnitCanAttack("player", "target") then
            self.lastTargetGUID = self.currentTargetGUID
        end
        
        -- Update current target
        self.currentTargetGUID = currentGUID
    end
end

-- Create or update highlight for a unit
function addon:HighlightUnit(unitData, color, thickness, offset)
    if not NextTargetDB.enabled then
        return
    end
    
    if NextTargetDB.onlyInCombat and not InCombatLockdown() then
        return
    end
    
    if not unitData then
        return
    end
    
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitData.unit)
    if nameplate then
        self:CreateNameplateHighlight(nameplate, unitData.unit, color, thickness, offset)
    end
end

-- Create highlight on nameplate
function addon:CreateNameplateHighlight(nameplate, unit, color, thickness, offset)
    -- Find the nameplate's health bar frame
    local healthBar = nameplate.UnitFrame and nameplate.UnitFrame.healthBar
    
    if not healthBar then
        -- Try alternative nameplate structure
        healthBar = nameplate.healthBar or nameplate.UnitFrame
    end
    
    if not healthBar then
        -- Last resort - use the base nameplate frame
        healthBar = nameplate
    end
    
    -- Use provided color or default to highlight color
    local borderColor = color or NextTargetDB.highlightColor
    
    -- Use provided thickness and offset or defaults
    local borderThickness = thickness or NextTargetDB.borderThickness or 2
    local borderOffset = offset or NextTargetDB.borderOffset or 1
    
    -- Create border edges (top, bottom, left, right) around the health bar
    
    -- Top border
    local topBorder = healthBar:CreateTexture(nil, "OVERLAY")
    topBorder:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    topBorder:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", -borderOffset, borderOffset)
    topBorder:SetPoint("BOTTOMRIGHT", healthBar, "TOPRIGHT", borderOffset, borderOffset)
    topBorder:SetHeight(borderThickness)
    topBorder:SetVertexColor(
        borderColor.r,
        borderColor.g,
        borderColor.b,
        borderColor.a
    )
    table.insert(self.highlights, topBorder)
    
    -- Bottom border
    local bottomBorder = healthBar:CreateTexture(nil, "OVERLAY")
    bottomBorder:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    bottomBorder:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", -borderOffset, -borderOffset)
    bottomBorder:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", borderOffset, -borderOffset)
    bottomBorder:SetHeight(borderThickness)
    bottomBorder:SetVertexColor(
        borderColor.r,
        borderColor.g,
        borderColor.b,
        borderColor.a
    )
    table.insert(self.highlights, bottomBorder)
    
    -- Left border
    local leftBorder = healthBar:CreateTexture(nil, "OVERLAY")
    leftBorder:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    leftBorder:SetPoint("TOPRIGHT", healthBar, "TOPLEFT", -borderOffset, borderOffset)
    leftBorder:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMLEFT", -borderOffset, -borderOffset)
    leftBorder:SetWidth(borderThickness)
    leftBorder:SetVertexColor(
        borderColor.r,
        borderColor.g,
        borderColor.b,
        borderColor.a
    )
    table.insert(self.highlights, leftBorder)
    
    -- Right border
    local rightBorder = healthBar:CreateTexture(nil, "OVERLAY")
    rightBorder:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    rightBorder:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", borderOffset, borderOffset)
    rightBorder:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", borderOffset, -borderOffset)
    rightBorder:SetWidth(borderThickness)
    rightBorder:SetVertexColor(
        borderColor.r,
        borderColor.g,
        borderColor.b,
        borderColor.a
    )
    table.insert(self.highlights, rightBorder)
    
    -- Add pulsing animation to all borders
    for i = #self.highlights - 3, #self.highlights do
        local border = self.highlights[i]
        local animGroup = border:CreateAnimationGroup()
        local fadeOut = animGroup:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1.0)
        fadeOut:SetToAlpha(0.3)
        fadeOut:SetDuration(0.5)
        fadeOut:SetSmoothing("IN_OUT")
        
        local fadeIn = animGroup:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0.3)
        fadeIn:SetToAlpha(1.0)
        fadeIn:SetDuration(0.5)
        fadeIn:SetSmoothing("IN_OUT")
        fadeIn:SetStartDelay(0.5)
        
        animGroup:SetLooping("REPEAT")
        animGroup:Play()
        
        border.animGroup = animGroup
    end
end

-- Clear all highlights
function addon:ClearHighlights()
    for _, highlight in ipairs(self.highlights) do
        if highlight.animGroup then
            highlight.animGroup:Stop()
        end
        highlight:Hide()
        highlight:SetParent(nil)
    end
    self.highlights = {}
end

-- Update the highlight (main function called by events)
function addon:UpdateHighlight()
    -- Update target tracking to remember last enemy
    self:UpdateTargetTracking()
    
    -- Clear all previous highlights
    self:ClearHighlights()
    
    local nextTarget = self:GetNextTabTarget()
    local prevTarget = self:GetLastTargetedEnemy()
    local currentTargetGUID = UnitGUID("target")
    
    -- Update debug frame
    if NextTargetDB.debugMode then
        self:UpdateDebugFrame(nextTarget)
    end
    
    -- Highlight current target (green)
    if NextTargetDB.showCurrentTarget and currentTargetGUID then
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if UnitExists(unit) and UnitGUID(unit) == currentTargetGUID then
                local unitData = {unit = unit, guid = currentTargetGUID}
                self:HighlightUnit(unitData, NextTargetDB.currentTargetColor, NextTargetDB.currentBorderThickness, NextTargetDB.currentBorderOffset)
                break
            end
        end
    end
    
    -- Highlight next target (yellow) - but not if it's the current target
    if NextTargetDB.showNextTarget and nextTarget and (not currentTargetGUID or nextTarget.guid ~= currentTargetGUID) then
        self:HighlightUnit(nextTarget, NextTargetDB.highlightColor, NextTargetDB.borderThickness, NextTargetDB.borderOffset)
    end
    
    -- Highlight last targeted enemy (light blue) - but not if it's current or next
    if NextTargetDB.showPreviousTarget and prevTarget then
        local shouldHighlight = true
        
        -- Don't highlight if it's the current target
        if currentTargetGUID and prevTarget.guid == currentTargetGUID then
            shouldHighlight = false
        end
        
        -- Don't highlight if it's the same as next target
        if nextTarget and prevTarget.guid == nextTarget.guid then
            shouldHighlight = false
        end
        
        if shouldHighlight then
            self:HighlightUnit(prevTarget, NextTargetDB.previousTargetColor, NextTargetDB.previousBorderThickness, NextTargetDB.previousBorderOffset)
        end
    end
end

-- Event handling
function addon:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            self:InitializeDB()
            print("|cFF00FF00[next]|r Addon loaded successfully!")
            print("|cFF00FF00[next]|r Type |cFFFFFF00/next config|r to open settings or |cFFFFFF00/next help|r for commands")
            
            -- Start debug update timer
            if NextTargetDB.debugMode then
                self:ShowDebugFrame()
            end
            self:StartDebugTimer()
        end
    elseif event == "PLAYER_TARGET_CHANGED" or 
           event == "NAME_PLATE_UNIT_ADDED" or
           event == "NAME_PLATE_UNIT_REMOVED" or
           event == "PLAYER_REGEN_ENABLED" or
           event == "PLAYER_REGEN_DISABLED" then
        -- Small delay to ensure nameplate data is updated
        C_Timer.After(0.1, function()
            self:UpdateHighlight()
        end)
    end
end

-- Start timer for debug mode updates
function addon:StartDebugTimer()
    -- Update debug frame regularly when in debug mode
    C_Timer.NewTicker(0.1, function()
        if NextTargetDB.debugMode then
            addon:UpdateHighlight()
        end
    end)
end

-- Register events
addon.frame:SetScript("OnEvent", function(self, event, ...)
    addon:OnEvent(event, ...)
end)

addon.frame:RegisterEvent("ADDON_LOADED")
addon.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
addon.frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
addon.frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
addon.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
addon.frame:RegisterEvent("PLAYER_REGEN_DISABLED")

-- Slash commands
SLASH_NEXTTARGET1 = "/next"
SLASH_NEXTTARGET2 = "/nexttarget"

function SlashCmdList.NEXTTARGET(msg)
    local command = string.lower(msg:trim())
    
    if command == "toggle" or command == "" then
        NextTargetDB.enabled = not NextTargetDB.enabled
        print("|cFF00FF00[next]|r " .. (NextTargetDB.enabled and "enabled" or "disabled"))
        if not NextTargetDB.enabled then
            addon:ClearHighlights()
        else
            addon:UpdateHighlight()
        end
    elseif command == "config" or command == "settings" or command == "options" then
        if addon.OpenSettings then
            addon:OpenSettings()
        else
            print("|cFFFF0000[next]|r Settings panel not loaded yet. Try typing /next config again.")
        end
    elseif command == "debug" then
        NextTargetDB.debugMode = not NextTargetDB.debugMode
        print("|cFF00FF00[next]|r Debug mode " .. (NextTargetDB.debugMode and "enabled" or "disabled"))
        if NextTargetDB.debugMode then
            addon:ShowDebugFrame()
            addon:UpdateHighlight()
        else
            addon:HideDebugFrame()
        end
    elseif command == "test" or command == "print" then
        -- Simple print-based debug
        print("|cFF00FF00[next]|r ===== DEBUG INFO =====")
        print("|cFF00FF00[next]|r Addon enabled: " .. tostring(NextTargetDB.enabled))
        print("|cFF00FF00[next]|r Debug mode: " .. tostring(NextTargetDB.debugMode))
        print("|cFF00FF00[next]|r Only in combat: " .. tostring(NextTargetDB.onlyInCombat))
        print("|cFF00FF00[next]|r In combat now: " .. tostring(InCombatLockdown()))
        
        -- Check if nameplates are enabled
        local nameplatesEnabled = GetCVar("nameplateShowEnemies")
        print("|cFF00FF00[next]|r Enemy nameplates enabled: " .. tostring(nameplatesEnabled == "1"))
        
        local hostileUnits = addon:GetHostileUnitsInRange()
        print("|cFF00FF00[next]|r Hostile units found: " .. #hostileUnits)
        
        for i, unitData in ipairs(hostileUnits) do
            local name = UnitName(unitData.unit) or "Unknown"
            local hp = UnitHealth(unitData.unit) or 0
            local maxhp = UnitHealthMax(unitData.unit) or 1
            local hpPercent = (hp / maxhp) * 100
            print(string.format("|cFF00FF00[next]|r   %d. %s (%.0f%% HP, GUID: %s)", i, name, hpPercent, unitData.guid or "none"))
        end
        
        local nextTarget = addon:GetNextTabTarget()
        if nextTarget then
            local name = UnitName(nextTarget.unit) or "Unknown"
            print(string.format("|cFFFFFF00[next]|r >> NEXT TARGET: %s", name))
        else
            print("|cFFFF0000[next]|r >> NO NEXT TARGET FOUND")
        end
        
        print("|cFF00FF00[next]|r =====================")
    elseif command == "combat" then
        NextTargetDB.onlyInCombat = not NextTargetDB.onlyInCombat
        print("|cFF00FF00[next]|r Combat only mode " .. (NextTargetDB.onlyInCombat and "enabled" or "disabled"))
        addon:UpdateHighlight()
    elseif command == "help" then
        print("|cFF00FF00[next] commands:|r")
        print("  |cFFFFFF00/next|r or |cFFFFFF00/next toggle|r - Toggle the addon on/off")
        print("  |cFFFFFF00/next config|r - Open settings panel")
        print("  |cFFFFFF00/next test|r - Print debug info to chat (easy debugging!)")
        print("  |cFFFFFF00/next debug|r - Toggle debug frame (shows moveable frame)")
        print("  |cFFFFFF00/next combat|r - Toggle combat-only mode")
        print("  |cFFFFFF00/next help|r - Show this help")
    else
        print("|cFFFF0000[next]|r Unknown command. Type |cFFFFFF00/next help|r for available commands.")
    end
end

-- Initialize highlight when addon is fully loaded
C_Timer.After(1, function()
    if NextTargetDB and NextTargetDB.enabled then
        addon:UpdateHighlight()
    end
end)
