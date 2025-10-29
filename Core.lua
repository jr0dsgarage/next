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
    frame:SetSize(500, 400)  -- Much larger to show all enemies
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    
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
    
    -- Create scrollable text area
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -40)
    scroll:SetPoint("BOTTOMRIGHT", -30, 15)
    
    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(450, 350)
    scroll:SetScrollChild(scrollChild)
    
    -- Target info text (scrollable content)
    local targetText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    targetText:SetPoint("TOPLEFT", 5, -5)
    targetText:SetJustifyH("LEFT")
    targetText:SetJustifyV("TOP")
    targetText:SetWidth(440)
    targetText:SetHeight(340)
    targetText:SetMaxLines(50)
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
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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

-- Create visual cone overlay
function addon:CreateConeOverlay()
    if self.coneFrame then
        return
    end
    
    local coneFrame = CreateFrame("Frame", "NextTargetConeFrame", UIParent)
    coneFrame:SetAllPoints(UIParent)
    coneFrame:SetFrameStrata("TOOLTIP")  -- Higher strata so it's visible
    
    -- Create cone boundary lines (make them MUCH more visible)
    coneFrame.leftLine = coneFrame:CreateTexture(nil, "OVERLAY")
    coneFrame.leftLine:SetColorTexture(0, 1, 0, 0.8)  -- Bright green
    coneFrame.leftLine:SetSize(5, UIParent:GetHeight())
    
    coneFrame.rightLine = coneFrame:CreateTexture(nil, "OVERLAY")
    coneFrame.rightLine:SetColorTexture(0, 1, 0, 0.8)  -- Bright green
    coneFrame.rightLine:SetSize(5, UIParent:GetHeight())
    
    -- Center reference line
    coneFrame.centerLine = coneFrame:CreateTexture(nil, "OVERLAY")
    coneFrame.centerLine:SetColorTexture(1, 1, 0, 0.6)  -- Yellow center line
    coneFrame.centerLine:SetSize(3, UIParent:GetHeight())
    coneFrame.centerLine:SetPoint("TOP", UIParent, "CENTER", 0, 0)
    coneFrame.centerLine:SetPoint("BOTTOM", UIParent, "CENTER", 0, 0)
    
    -- Create filled cone area (very transparent)
    coneFrame.fill = coneFrame:CreateTexture(nil, "BACKGROUND")
    coneFrame.fill:SetColorTexture(0, 1, 0, 0.15)  -- More visible green
    
    -- Label at top (will be updated dynamically)
    coneFrame.label = coneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    coneFrame.label:SetPoint("TOP", UIParent, "TOP", 0, -100)
    coneFrame.label:SetText("|cFF00FF00TAB Target Cone|r")
    
    -- Debug info label
    coneFrame.debugLabel = coneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    coneFrame.debugLabel:SetPoint("TOP", coneFrame.label, "BOTTOM", 0, -5)
    coneFrame.debugLabel:SetText("")
    
    self.coneFrame = coneFrame
    coneFrame:Hide()
end

-- Update cone visualization based on nameplate positions
function addon:UpdateConeOverlay()
    if not self.coneFrame or not self.coneFrame:IsShown() then
        return
    end
    
    -- Find the leftmost and rightmost nameplates with ID <= 15
    local leftmost, rightmost = nil, nil
    local count = 0
    local totalHostile = 0
    local debugInfo = {}
    
    for i = 1, 40 do
        local nameplateName = "nameplate" .. i
        if UnitExists(nameplateName) then
            local reaction = UnitReaction(nameplateName, "player")
            local isEnemy = reaction and reaction <= 4
            
            if isEnemy then
                totalHostile = totalHostile + 1
                local nameplate = C_NamePlate.GetNamePlateForUnit(nameplateName)
                local hasNameplate = nameplate ~= nil
                local isShown = nameplate and nameplate:IsShown() or false
                local x, y = nil, nil
                if nameplate and nameplate:IsShown() then
                    x, y = nameplate:GetCenter()
                end
                
                -- Store debug info for first few
                if i <= 5 then
                    local unitName = UnitName(nameplateName) or "Unknown"
                    table.insert(debugInfo, string.format("ID%d %s: plate=%s x=%s", 
                        i, unitName, tostring(hasNameplate), x and string.format("%.0f", x) or "nil"))
                end
                
                if i <= 15 then  -- Only show cone for IDs we consider
                    if x and y then
                        count = count + 1
                        if not leftmost or x < leftmost then
                            leftmost = x
                        end
                        if not rightmost or x > rightmost then
                            rightmost = x
                        end
                    end
                end
            end
        end
    end
    
    -- Update debug label
    if #debugInfo > 0 then
        self.coneFrame.debugLabel:SetText(table.concat(debugInfo, "\n"))
    else
        self.coneFrame.debugLabel:SetText("|cFFAAAAAA(scanning for nameplates...)|r")
    end
    
    -- Show cone lines if we found valid positions
    if leftmost and rightmost and count > 0 then
        -- Add some padding to make it more visible
        local padding = 50
        leftmost = leftmost - padding
        rightmost = rightmost + padding
        
        -- Position the cone boundaries
        self.coneFrame.leftLine:ClearAllPoints()
        self.coneFrame.leftLine:SetPoint("TOP", UIParent, "BOTTOMLEFT", leftmost, 0)
        self.coneFrame.leftLine:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", leftmost, 0)
        
        self.coneFrame.rightLine:ClearAllPoints()
        self.coneFrame.rightLine:SetPoint("TOP", UIParent, "BOTTOMLEFT", rightmost, 0)
        self.coneFrame.rightLine:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", rightmost, 0)
        
        -- Fill the cone area
        local coneWidth = rightmost - leftmost
        self.coneFrame.fill:ClearAllPoints()
        self.coneFrame.fill:SetSize(coneWidth, UIParent:GetHeight())
        self.coneFrame.fill:SetPoint("TOP", UIParent, "BOTTOMLEFT", leftmost, 0)
        
        -- Update label with count
        self.coneFrame.label:SetText(string.format("|cFF00FF00TAB Target Cone|r (%d in cone / %d total)", count, totalHostile))
        
        self.coneFrame.leftLine:Show()
        self.coneFrame.rightLine:Show()
        self.coneFrame.fill:Show()
    else
        -- No valid targets, hide the cone visuals but keep label
        self.coneFrame.leftLine:Hide()
        self.coneFrame.rightLine:Hide()
        self.coneFrame.fill:Hide()
        if totalHostile > 0 then
            self.coneFrame.label:SetText(string.format("|cFFFFAA00TAB Target Cone|r (0 in cone / %d total)", totalHostile))
        else
            self.coneFrame.label:SetText("|cFFFF0000TAB Target Cone|r (no enemies found)")
        end
    end
end

-- Show cone overlay
function addon:ShowConeOverlay()
    if not self.coneFrame then
        self:CreateConeOverlay()
    end
    self.coneFrame:Show()
    
    -- Start a ticker to update the cone
    if self.coneTicker then
        self.coneTicker:Cancel()
    end
    self.coneTicker = C_Timer.NewTicker(0.05, function()
        if self.coneFrame and self.coneFrame:IsShown() then
            self:UpdateConeOverlay()
        else
            if self.coneTicker then
                self.coneTicker:Cancel()
                self.coneTicker = nil
            end
        end
    end)
    
    print("|cFF00FF00Next Target|r Cone overlay shown. Type /next cone to hide.")
end

        screenWidth, screenHeight, coneWidth, coneHeight))
    
    table.insert(lines, "")
    table.insert(lines, "|cFFFFFF00=== NAMEPLATE SCAN ===|r")
    
    -- Get current state
    local lines = {}
    local currentTargetGUID = UnitGUID("target")
    local prevTarget = self:GetLastTargetedEnemy()
    local nameplates = C_NamePlate.GetNamePlates()
    table.insert(lines, string.format("Total nameplates: %d", #nameplates))
    for i, nameplateFrame in ipairs(nameplates) do
        local unit = nameplateFrame.namePlateUnitToken
        local name = unit and UnitName(unit) or "Unknown"
        local reaction = unit and UnitReaction(unit, "player") or "?"
        local isEnemy = reaction and reaction <= 4
        local status = isEnemy and "ENEMY" or "FRIEND"
        table.insert(lines, string.format("NP%02d: %s (unit=%s, react=%s)", i, name, tostring(unit), tostring(reaction)))
    end
    table.insert(lines, "")
    local hostileUnits = self:GetHostileUnitsInRange()
    table.insert(lines, string.format("Hostile units found: %d", #hostileUnits))
    for i, unitData in ipairs(hostileUnits) do
        if i <= 10 then
            local name = UnitName(unitData.unit) or "Unknown"
            table.insert(lines, string.format("  %d. %s (unit=%s, NP%d)", i, name, unitData.unit, unitData.nameplateId))
        end
    end
    table.insert(lines, "")
    if currentTargetGUID then
        local currentName = UnitName("target") or "Unknown"
        table.insert(lines, string.format("|cFF00FF00Current target:|r %s", currentName))
    else
        table.insert(lines, "|cFFAAAAAACurrent target: (none)|r")
    end
    if nextTarget then
        local name = UnitName(nextTarget.unit) or "Unknown"
        table.insert(lines, string.format("|cFFFFFF00Next target:|r %s", name))
    else
        table.insert(lines, "|cFFAAAAAANext target: (none)|r")
    end
    if prevTarget then
        local name = UnitName(prevTarget.unit) or "Unknown"
        table.insert(lines, string.format("|cFF00AAFFPrevious target:|r %s", name))
    else
        table.insert(lines, "|cFFAAAAAAPrevious target: (none)|r")
    end
    self.debugFrame.targetText:SetText(table.concat(lines, "\n"))
end

-- Get all hostile units in range that could be tab-targeted
function addon:GetHostileUnitsInRange()
    local hostileUnits = {}
    local nameplates = C_NamePlate.GetNamePlates()
    if not nameplates then
        return hostileUnits
    end
    -- For debug: collect info on all nameplates
    self._lastNameplateScan = {}
    for i, nameplateFrame in ipairs(nameplates) do
        local unit = nameplateFrame.namePlateUnitToken
        local info = {id = i, unit = unit, name = nil, exists = false, reaction = nil, isHostile = false}
        if unit then
            info.name = UnitName(unit)
            info.exists = UnitExists(unit)
            info.reaction = UnitReaction(unit, "player")
            info.isHostile = info.exists and info.reaction and info.reaction <= 4
            if info.isHostile then
                local guid = UnitGUID(unit)
                table.insert(hostileUnits, {
                    unit = unit,
                    guid = guid,
                    nameplateId = i
                })
            end
        end
        table.insert(self._lastNameplateScan, info)
    end
    return hostileUnits
end

-- Determine which unit would be targeted next by TAB targeting
function addon:GetNextTabTarget()
    local hostileUnits = self:GetHostileUnitsInRange()
    
    if #hostileUnits == 0 then
        return nil
    end
    
    local currentTarget = UnitGUID("target")
    
    -- If only one target and it's already our current target, no "next" target exists
    if #hostileUnits == 1 then
        if currentTarget and hostileUnits[1].guid == currentTarget then
            return nil
        else
            return hostileUnits[1]
        end
    end
    
    -- Filter to a narrower horizontal cone using nameplate IDs
    -- Lower nameplate IDs are more centered/important
    -- WoW assigns IDs based on screen position and importance
    local centerConeUnits = {}
    
    for _, unitData in ipairs(hostileUnits) do
        -- Only include nameplates with ID <= 15 (more centered targets)
        -- or if it's the current target (always include)
        -- IDs 1-15 tend to be more central/in-view targets
        -- Higher IDs (16-40) are often peripheral or behind
        if unitData.nameplateId <= 15 or 
           unitData.nameplateId >= 900 or  -- Include special IDs (target/mouseover)
           (currentTarget and unitData.guid == currentTarget) then
            table.insert(centerConeUnits, unitData)
        end
    end
    
    -- If filter removed everything except current target, fall back to closer range
    if #centerConeUnits == 0 or (#centerConeUnits == 1 and currentTarget) then
        centerConeUnits = {}
        for _, unitData in ipairs(hostileUnits) do
            if unitData.nameplateId <= 20 or 
               unitData.nameplateId >= 900 or
               (currentTarget and unitData.guid == currentTarget) then
                table.insert(centerConeUnits, unitData)
            end
        end
    end
    
    -- Sort by distance - closest first
    table.sort(centerConeUnits, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Filter to only closest enemies within the cone
    -- Take only enemies within 120% of the closest enemy's distance
    local closestDistance = centerConeUnits[1].distance
    local filteredUnits = {}
    
    for _, unitData in ipairs(centerConeUnits) do
        -- Include if within 120% of closest, or if it's the current target
        if unitData.distance <= (closestDistance * 1.2) or 
           (currentTarget and unitData.guid == currentTarget) then
            table.insert(filteredUnits, unitData)
        end
    end
    
    -- If no current target, return the closest one
    if not currentTarget then
        return filteredUnits[1]
    end
    
    -- Find current target in filtered list and return the next closest one
    for i, unitData in ipairs(filteredUnits) do
        if unitData.guid == currentTarget then
            -- Return next unit in the list, or wrap to first
            local nextIndex = (i % #filteredUnits) + 1
            return filteredUnits[nextIndex]
        end
    end
    
    -- Current target not in list, return closest in sorted list
    return filteredUnits[1]
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
    if currentGUID ~= self.currentTargetGUID then
        -- Save previous target GUID if it existed
        if self.currentTargetGUID then
            self.lastTargetGUID = self.currentTargetGUID
        end
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
    -- Check if we should even be running
    if not NextTargetDB.enabled then
        return
    end
    
    -- Check combat settings
    if NextTargetDB.onlyInCombat and not InCombatLockdown() then
        return
    end
    
    -- Update target tracking to remember last enemy
    self:UpdateTargetTracking()
    
    -- Clear all previous highlights
    self:ClearHighlights()
    
    local currentTargetGUID = UnitGUID("target")
    local nextTarget = self:GetNextTabTarget()
    local prevTarget = self:GetLastTargetedEnemy()
    
    -- Update debug frame
    if NextTargetDB.debugMode then
        self:UpdateDebugFrame(nextTarget)
    end
    
    -- Highlight current target (green)
    if NextTargetDB.showCurrentTarget and currentTargetGUID then
        -- Find current target in hostile units
        local hostileUnits = self:GetHostileUnitsInRange()
        for _, unitData in ipairs(hostileUnits) do
            if unitData.guid == currentTargetGUID then
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
    -- Update debug frame and highlights regularly
    C_Timer.NewTicker(0.1, function()
        -- Always update if enabled (ignore combat settings for continuous updates)
        if NextTargetDB.enabled then
            -- Check combat settings only for showing highlights
            if not NextTargetDB.onlyInCombat or InCombatLockdown() then
                addon:UpdateHighlight()
            end
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
    -- ...existing code...
    elseif command == "test" or command == "print" then
        print("|cFF00FF00[next]|r ==================== DEBUG INFO ====================")
        print("|cFF00FF00[next]|r Addon enabled: " .. tostring(NextTargetDB.enabled))
        print("|cFF00FF00[next]|r Debug mode: " .. tostring(NextTargetDB.debugMode))
        print("|cFF00FF00[next]|r Only in combat: " .. tostring(NextTargetDB.onlyInCombat))
        print("|cFF00FF00[next]|r In combat now: " .. tostring(InCombatLockdown()))
        local nameplatesEnabled = GetCVar("nameplateShowEnemies")
        print("|cFF00FF00[next]|r Enemy nameplates enabled: " .. tostring(nameplatesEnabled == "1"))
        local hostileUnits = addon:GetHostileUnitsInRange()
        print("|cFF00FF00[next]|r Total hostile units found: " .. #hostileUnits)
        for i, unitData in ipairs(hostileUnits) do
            if i <= 10 then
                local name = UnitName(unitData.unit) or "Unknown"
                print(string.format("  %d. %s (unit=%s, NP%d)", i, name, unitData.unit, unitData.nameplateId))
            end
        end
        local currentTargetGUID = UnitGUID("target")
        local nextTarget = addon:GetNextTabTarget()
        local prevTarget = addon:GetLastTargetedEnemy()
        if currentTargetGUID then
            local currentName = UnitName("target") or "Unknown"
            print(string.format("|cFF00FF00[next]|r Current target: |cFF00FF00%s|r", currentName))
        else
            print("|cFFAAAAAA[next]|r Current target: (none)")
        end
        if nextTarget then
            local name = UnitName(nextTarget.unit) or "Unknown"
            print(string.format("|cFFFFFF00[next]|r >> NEXT TARGET: %s|r", name))
        else
            print("|cFFFF0000[next]|r >> NO NEXT TARGET FOUND")
        end
        if prevTarget then
            local name = UnitName(prevTarget.unit) or "Unknown"
            print(string.format("|cFF00AAFF[next]|r >> PREVIOUS TARGET: %s|r", name))
        else
            print("|cFFAAAAAA[next]|r >> PREVIOUS TARGET: (none)")
        end
        print("|cFF00FF00[next]|r ====================================================")
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
        print("  |cFFFFFF00/next cone|r - Toggle visual cone overlay (shows target search area)")
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
