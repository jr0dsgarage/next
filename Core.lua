-- Next Target Highlighter Addon
---@diagnostic disable: undefined-global, param-type-mismatch
local addonName, addon = ...

addon.frame = addon.frame or CreateFrame("Frame")
addon.highlights = addon.highlights or {}
addon.currentTargetGUID = addon.currentTargetGUID or nil
addon.pendingUpdate = addon.pendingUpdate or false

local DEFAULTS = {
    enabled = true,
    onlyInCombat = false,
    debugMode = false,
    debugFramePosition = nil,
    currentTargetEnabled = true,
    currentTargetColor = { r = 0, g = 1, b = 0, a = 0.8 },
    currentTargetThickness = 2,
    currentTargetOffset = 1,
    questObjectiveEnabled = true,
    questObjectiveColor = { r = 1, g = 1, b = 0, a = 0.9 },
    questObjectiveThickness = 3,
    questObjectiveOffset = 2,
    questItemEnabled = true,
    questItemColor = { r = 1, g = 0, b = 1, a = 0.9 },
    questItemThickness = 3,
    questItemOffset = 2,
    worldQuestEnabled = true,
    worldQuestColor = { r = 0.3, g = 0.7, b = 1, a = 0.9 },
    worldQuestThickness = 3,
    worldQuestOffset = 2,
}

addon.DEFAULTS = DEFAULTS

local MIGRATION_MAP = {
    showCurrentTarget = "currentTargetEnabled",
    showQuestObjective = "questObjectiveEnabled",
    showQuestItem = "questItemEnabled",
    showWorldQuestHighlight = "worldQuestEnabled",
    currentBorderThickness = "currentTargetThickness",
    currentBorderOffset = "currentTargetOffset",
    questObjectiveBorderThickness = "questObjectiveThickness",
    questObjectiveBorderOffset = "questObjectiveOffset",
    questItemBorderThickness = "questItemThickness",
    questItemBorderOffset = "questItemOffset",
    worldQuestBorderThickness = "worldQuestThickness",
    worldQuestBorderOffset = "worldQuestOffset",
}

local function cloneTable(source)
    if type(source) ~= "table" then
        return source
    end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = cloneTable(value)
    end
    return copy
end

local function mergeDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = cloneTable(value)
            else
                mergeDefaults(target[key], value)
            end
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function wipeTable(tbl)
    if table.wipe then
        table.wipe(tbl)
    elseif type(wipe) == "function" then
        wipe(tbl)
    else
        for key in pairs(tbl) do
            tbl[key] = nil
        end
    end
end

local function sanitizeCommand(text)
    if not text then
        return ""
    end
    return text:match("^%s*(.-)%s*$") or ""
end

function addon:GetDefault(key)
    return cloneTable(DEFAULTS[key])
end

function addon:InitializeDB()
    NextTargetDB = NextTargetDB or {}

    for oldKey, newKey in pairs(MIGRATION_MAP) do
        if NextTargetDB[oldKey] ~= nil and NextTargetDB[newKey] == nil then
            NextTargetDB[newKey] = NextTargetDB[oldKey]
        end
        NextTargetDB[oldKey] = nil
    end

    mergeDefaults(NextTargetDB, DEFAULTS)

    NextTargetDB.rareEliteEnabled = nil
    NextTargetDB.rareEliteColor = nil
    NextTargetDB.rareEliteThickness = nil
    NextTargetDB.rareEliteOffset = nil

    local questColor = NextTargetDB.questObjectiveColor
    if questColor and questColor.r == 1 and questColor.g == 0.5 and questColor.b == 0 then
        questColor.r = DEFAULTS.questObjectiveColor.r
        questColor.g = DEFAULTS.questObjectiveColor.g
        questColor.b = DEFAULTS.questObjectiveColor.b
        questColor.a = DEFAULTS.questObjectiveColor.a
    end
end

local tooltipScanner = CreateFrame("GameTooltip", addonName .. "TooltipScanner", UIParent, "GameTooltipTemplate")
tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")

local QUEST_CACHE_SECONDS = 5
local UNIT_CACHE_SECONDS = 2

local questCache = { timestamp = 0, entries = {} }
local unitCache = {}

local function resetCaches()
    questCache.timestamp = 0
    wipeTable(questCache.entries)
    unitCache = {}
end

local function parseTooltip(unit)
    local info = {
        hasQuestObjective = false,
        hasCompletedObjective = false,
        lines = {},
    }

    tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    tooltipScanner:SetUnit(unit)

    local lineCount = tooltipScanner:NumLines() or 0
    for index = 2, lineCount do
        local line = _G[tooltipScanner:GetName() .. "TextLeft" .. index]
        if line then
            local text = line:GetText()
            if text and text ~= "" then
                local current, total = text:match("(%d+)%s*/%s*(%d+)")
                if current and total then
                    local currentNum = tonumber(current)
                    local totalNum = tonumber(total)
                    info.lines[#info.lines + 1] = text
                    if currentNum and totalNum then
                        if currentNum >= totalNum then
                            info.hasCompletedObjective = true
                        else
                            info.hasQuestObjective = true
                        end
                    end
                elseif text:find("|c") then
                    info.lines[#info.lines + 1] = text
                end
            end
        end
    end

    tooltipScanner:Hide()
    return info
end

local function hasQuestItemIcon(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
        return false
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    local frame = nameplate and nameplate.UnitFrame and nameplate.UnitFrame.SoftTargetFrame
    if frame and frame:IsShown() and frame.Icon and frame.Icon:IsShown() then
        return true
    end

    return false
end

local function refreshQuestCache()
    local now = GetTime()
    if now - questCache.timestamp < QUEST_CACHE_SECONDS then
        return questCache.entries
    end

    questCache.timestamp = now
    wipeTable(questCache.entries)

    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then
        return questCache.entries
    end

    if not GetQuestObjectiveInfo then
        return questCache.entries
    end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for index = 1, numEntries do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and info.questID then
            local questID = info.questID
            local isComplete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)
            if not isComplete then
                local entry = {
                    questID = questID,
                    questName = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or "Unknown Quest",
                    isWorldQuest = C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) or false,
                    objectives = {},
                }

                local objectiveCount = C_QuestLog.GetNumQuestObjectives and C_QuestLog.GetNumQuestObjectives(questID) or 0
                for objectiveIndex = 1, objectiveCount do
                    local text, _, finished = GetQuestObjectiveInfo(questID, objectiveIndex, false)
                    if text and text ~= "" and not finished then
                        entry.objectives[#entry.objectives + 1] = text
                    end
                end

                if #entry.objectives > 0 then
                    questCache.entries[#questCache.entries + 1] = entry
                end
            end
        end
    end

    return questCache.entries
end

local function objectiveMatches(unitName, tooltipLines, questEntries)
    for _, entry in ipairs(questEntries) do
        for _, objective in ipairs(entry.objectives) do
            if objective:find(unitName, 1, true) then
                return true, entry.isWorldQuest, entry.questName
            end
            for _, tooltipLine in ipairs(tooltipLines) do
                if tooltipLine == objective then
                    return true, entry.isWorldQuest, entry.questName
                end
            end
        end
    end

    return false, false, nil
end

local function classifyUnit(unitData)
    local guid = unitData.guid
    if not guid then
        return nil
    end

    local now = GetTime()
    local cached = unitCache[guid]
    if cached and now - cached.time < UNIT_CACHE_SECONDS then
        return cached.result
    end

    local unit = unitData.unit
    local unitName = UnitName(unit)
    if not unitName or unitName == "" then
        unitCache[guid] = { time = now, result = nil }
        return nil
    end

    local tooltipInfo = parseTooltip(unit)
    local questEntries = refreshQuestCache()
    local hasObjective, isWorldQuest, questName = objectiveMatches(unitName, tooltipInfo.lines, questEntries)
    local hasSoftTarget = hasQuestItemIcon(unit)
    local isQuestBoss = UnitIsQuestBoss and UnitIsQuestBoss(unit)

    local classification = UnitClassification and UnitClassification(unit)
    local isRare = classification == "rare" or classification == "rareelite" or classification == "elite"

    local reason
    if hasSoftTarget then
        reason = "Has Quest Item"
    elseif hasObjective or tooltipInfo.hasQuestObjective or isQuestBoss then
        reason = isWorldQuest and "World Quest" or "Quest Objective"
    end

    local result = {
        unit = unit,
        guid = guid,
        frame = unitData.frame,
        name = unitName,
        reason = reason,
        questName = questName,
        tooltipLines = tooltipInfo.lines,
        isWorldQuest = isWorldQuest,
        hasSoftTarget = hasSoftTarget,
        isQuestBoss = isQuestBoss,
        hasQuestObjectiveMatch = hasObjective,
        hasTooltipObjective = tooltipInfo.hasQuestObjective,
        hasCompletedObjective = tooltipInfo.hasCompletedObjective,
        isRare = isRare,
    }

    if not reason then
        if tooltipInfo.hasCompletedObjective then
            result.note = "Quest objective already complete"
        elseif hasObjective then
            result.note = "Quest objective match, but filtered"
        elseif isRare then
            result.note = "Rare/Elite (quest highlighting only)"
        end
    end

    unitCache[guid] = { time = now, result = result }
    return result
end

local function addUnit(target, unitToken, frame)
    if not unitToken or not UnitExists(unitToken) then
        return
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unitToken) then
        return
    end

    local reaction = UnitReaction and UnitReaction(unitToken, "player")
    if reaction and reaction > 4 then
        return
    end

    local guid = UnitGUID(unitToken)
    if not guid then
        return
    end

    for _, data in ipairs(target) do
        if data.guid == guid then
            return
        end
    end

    target[#target + 1] = {
        unit = unitToken,
        guid = guid,
        frame = frame,
    }
end

function addon:GetRelevantUnits()
    local units = {}

    addUnit(units, "target")
    addUnit(units, "focus")
    addUnit(units, "mouseover")

    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.displayedUnit)
            addUnit(units, token, plate)
        end
    end

    return units
end

local function resolveHealthBar(plate)
    if not plate then
        return nil
    end

    if plate.UnitFrame then
        if plate.UnitFrame.healthBar then
            return plate.UnitFrame.healthBar
        end
        if plate.UnitFrame.healthBars and plate.UnitFrame.healthBars.healthBar then
            return plate.UnitFrame.healthBars.healthBar
        end
        if plate.UnitFrame.HealthBarsContainer and plate.UnitFrame.HealthBarsContainer.healthBar then
            return plate.UnitFrame.HealthBarsContainer.healthBar
        end
    end

    return plate.healthBar
end

local function acquireNameplate(unitData)
    if unitData.frame then
        return unitData.frame
    end
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        return C_NamePlate.GetNamePlateForUnit(unitData.unit)
    end
    return nil
end

local function applyBorderTextures(self, healthBar, style)
    local color = style.color
    local thickness = style.thickness or 2
    local offset = style.offset or 1

    local function createTexture(point, relativePoint, xOffset, yOffset, width, height)
        local texture = healthBar:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        texture:SetVertexColor(color.r, color.g, color.b, color.a or 1)
        texture:SetPoint(point, healthBar, relativePoint, xOffset, yOffset)
        if width then
            texture:SetWidth(width)
        end
        if height then
            texture:SetHeight(height)
        end
        texture:Show()
        table.insert(self.highlights, texture)
    end

    local function createCorner(point, relativePoint, xOffset, yOffset)
        local texture = healthBar:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        texture:SetVertexColor(color.r, color.g, color.b, color.a or 1)
        texture:SetSize(thickness, thickness)
        texture:SetPoint(point, healthBar, relativePoint, xOffset, yOffset)
        texture:Show()
        table.insert(self.highlights, texture)
    end

    createTexture("BOTTOMLEFT", "TOPLEFT", -offset, offset, nil, thickness)
    self.highlights[#self.highlights]:SetPoint("BOTTOMRIGHT", healthBar, "TOPRIGHT", offset, offset)

    createTexture("TOPLEFT", "BOTTOMLEFT", -offset, -offset, nil, thickness)
    self.highlights[#self.highlights]:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", offset, -offset)

    createTexture("TOPRIGHT", "TOPLEFT", -offset, offset, thickness, nil)
    self.highlights[#self.highlights]:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMLEFT", -offset, -offset)

    createTexture("TOPLEFT", "TOPRIGHT", offset, offset, thickness, nil)
    self.highlights[#self.highlights]:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", offset, -offset)

    createCorner("BOTTOMRIGHT", "TOPLEFT", -offset, offset)
    createCorner("BOTTOMLEFT", "TOPRIGHT", offset, offset)
    createCorner("TOPRIGHT", "BOTTOMLEFT", -offset, -offset)
    createCorner("TOPLEFT", "BOTTOMRIGHT", offset, -offset)
end

local function determineStyle(result, currentGuid)
    local baseStyle

    if result.reason == "Has Quest Item" and NextTargetDB.questItemEnabled then
        baseStyle = {
            color = NextTargetDB.questItemColor,
            thickness = NextTargetDB.questItemThickness,
            offset = NextTargetDB.questItemOffset,
            origin = "questItem",
        }
    elseif result.reason == "World Quest" and NextTargetDB.worldQuestEnabled then
        baseStyle = {
            color = NextTargetDB.worldQuestColor,
            thickness = NextTargetDB.worldQuestThickness,
            offset = NextTargetDB.worldQuestOffset,
            origin = "worldQuest",
        }
    elseif result.reason == "Quest Objective" and NextTargetDB.questObjectiveEnabled then
        baseStyle = {
            color = NextTargetDB.questObjectiveColor,
            thickness = NextTargetDB.questObjectiveThickness,
            offset = NextTargetDB.questObjectiveOffset,
            origin = "questObjective",
        }
    end

    if not baseStyle then
        return nil
    end

    if result.guid == currentGuid and NextTargetDB.currentTargetEnabled then
        return {
            color = NextTargetDB.currentTargetColor,
            thickness = NextTargetDB.currentTargetThickness,
            offset = NextTargetDB.currentTargetOffset,
            origin = "currentTarget",
            baseReason = result.reason,
        }
    end

    return baseStyle
end

function addon:ClearHighlights()
    for _, texture in ipairs(self.highlights) do
        texture:Hide()
        texture:SetParent(nil)
    end
    wipeTable(self.highlights)
end

local function collectHighlights(self)
    local relevantUnits = self:GetRelevantUnits()
    local results = {}
    local currentGuid = UnitGUID("target")

    for _, unitData in ipairs(relevantUnits) do
        local classification = classifyUnit(unitData)
        if classification then
            classification.frame = classification.frame or unitData.frame
            classification.highlighted = false
            classification.isCurrentTarget = classification.guid == currentGuid
            results[#results + 1] = classification

            local style = determineStyle(classification, currentGuid)
            if style then
                classification.highlighted = true
                if classification.note == "Disabled in settings" then
                    classification.note = nil
                end
                classification.highlightStyle = style
                local plate = acquireNameplate(classification)
                local healthBar = resolveHealthBar(plate)
                if healthBar then
                    applyBorderTextures(self, healthBar, style)
                end
            elseif classification.reason then
                if not classification.note then
                    classification.note = "Disabled in settings"
                end
                classification.suppressedReason = classification.reason
            elseif classification.isCurrentTarget and NextTargetDB.currentTargetEnabled and not classification.note then
                classification.note = "Current target without quest highlight"
            end
        end
    end

    return results
end

local function ensureDebugFrame()
    if addon.debugFrame then
        return addon.debugFrame
    end

    local frame = CreateFrame("Frame", addonName .. "DebugFrame", UIParent, "BackdropTemplate")
    frame:SetSize(360, 300)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        NextTargetDB.debugFramePosition = { point, relativeTo and relativeTo:GetName(), relativePoint, xOfs, yOfs }
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("next debug")

    local reload = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reload:SetSize(80, 22)
    reload:SetPoint("TOPRIGHT", -38, -12)
    reload:SetText("Reload UI")
    reload:SetScript("OnClick", ReloadUI)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function()
        NextTargetDB.debugMode = false
        addon:HideDebugFrame()
        print("|cFF00FF00[next]|r debug mode disabled")
    end)

    local scroll = CreateFrame("ScrollFrame", addonName .. "DebugScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -8)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 16)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetWidth(300)
    editBox:SetHeight(400)
    editBox:SetHyperlinksEnabled(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
    editBox:SetScript("OnEnterPressed", editBox.ClearFocus)
    editBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)
    scroll:SetScrollChild(editBox)

    frame.editBox = editBox
    addon.debugFrame = frame
    return frame
end

function addon:ShowDebugFrame()
    local frame = ensureDebugFrame()
    frame:Show()

    local position = NextTargetDB.debugFramePosition
    if position and position[1] then
        frame:ClearAllPoints()
        local relative = position[2] and _G[position[2]] or UIParent
        frame:SetPoint(position[1], relative, position[3], position[4], position[5])
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function addon:HideDebugFrame()
    if self.debugFrame then
        self.debugFrame:Hide()
    end
end

function addon:UpdateDebugFrame(results)
    if not NextTargetDB.debugMode then
        self:HideDebugFrame()
        return
    end

    local frame = ensureDebugFrame()
    if not frame:IsShown() then
        self:ShowDebugFrame()
    end

    local lines = {}
    local targetName = UnitName("target") or "none"
    lines[#lines + 1] = "Target: " .. targetName
    lines[#lines + 1] = "Tracked units: " .. tostring(#results)

    local totalNameplates, hostileNameplates = 0, 0
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            totalNameplates = totalNameplates + 1
            local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.displayedUnit)
            if token and UnitExists(token) then
                local reaction = UnitReaction and UnitReaction(token, "player")
                if not reaction or reaction <= 4 then
                    hostileNameplates = hostileNameplates + 1
                end
            end
        end
    end

    local highlightedCount, filteredCount = 0, 0
    for _, info in ipairs(results) do
        if info.highlighted then
            highlightedCount = highlightedCount + 1
        elseif info.reason or info.note or info.hasTooltipObjective or info.hasCompletedObjective then
            filteredCount = filteredCount + 1
        end
    end

    lines[#lines + 1] = string.format("Nameplates: %d (hostile: %d) | Highlights: %d", totalNameplates, hostileNameplates, highlightedCount)
    if filteredCount > 0 then
        lines[#lines + 1] = "Filtered units: " .. filteredCount
    end
    lines[#lines + 1] = ""

    local function questLabelFor(info)
        if info.questName and info.questName ~= "" then
            return info.questName
        end
        if info.isWorldQuest then
            return "World Quest"
        end
        if info.hasQuestObjectiveMatch or info.hasTooltipObjective then
            return "Quest Objective"
        end
        if info.hasSoftTarget then
            return "Quest Item"
        end
        return "n/a"
    end

    for index, info in ipairs(results) do
        if index > 8 then
            lines[#lines + 1] = "... (" .. (#results - 8) .. " more)"
            break
        end

        local summary = string.format("%d) %s", index, info.name or "Unknown")
        lines[#lines + 1] = summary

        local highlightExplanation
        if info.highlighted then
            local reason = info.reason or "Active highlight"
            if info.highlightStyle and info.highlightStyle.origin == "currentTarget" then
                local base = info.highlightStyle.baseReason or reason
                reason = string.format("%s (current target style)", base)
            end
            highlightExplanation = string.format(
                "    Highlight: |cFF00FF00ON|r - %s - Quest: %s",
                reason,
                questLabelFor(info)
            )
        else
            local explanation
            if info.suppressedReason then
                explanation = string.format("%s highlight disabled in settings", info.suppressedReason)
            elseif info.note then
                explanation = info.note
            elseif info.reason then
                explanation = string.format("Matches %s but filtered", info.reason)
            elseif info.hasCompletedObjective then
                explanation = "Quest objective already complete"
            elseif info.hasTooltipObjective then
                explanation = "Tooltip contains quest objective text"
            else
                explanation = "No highlight conditions met"
            end
            highlightExplanation = string.format(
                "    Highlight: |cFFFF5555OFF|r - %s - Quest: %s",
                explanation,
                questLabelFor(info)
            )
        end

        lines[#lines + 1] = highlightExplanation

        if info.hasSoftTarget then
            lines[#lines + 1] = "    Has quest item icon"
        end

        if info.isQuestBoss then
            lines[#lines + 1] = "    Quest boss"
        end

        if info.tooltipLines and #info.tooltipLines > 0 then
            lines[#lines + 1] = "    " .. table.concat(info.tooltipLines, " / ")
        end
    end

    local editBox = frame.editBox
    if editBox then
        editBox:SetText(table.concat(lines, "\n"))
        editBox:SetCursorPosition(0)
    end
end

function addon:UpdateHighlight()
    self:ClearHighlights()

    if not NextTargetDB.enabled then
        if NextTargetDB.debugMode then
            self:UpdateDebugFrame({})
        end
        return
    end

    local inCombat = false
    if NextTargetDB.onlyInCombat then
        if InCombatLockdown then
            inCombat = InCombatLockdown() or false
        else
            inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) or false
        end
        if not inCombat then
            if NextTargetDB.debugMode then
                self:UpdateDebugFrame({})
            end
            return
        end
    end

    local results = collectHighlights(self)
    if NextTargetDB.debugMode then
        self:UpdateDebugFrame(results)
    end
end

function addon:RequestUpdate()
    if self.pendingUpdate then
        return
    end

    if not C_Timer or not C_Timer.After then
        self:UpdateHighlight()
        return
    end

    self.pendingUpdate = true
    C_Timer.After(0.05, function()
        addon.pendingUpdate = false
        addon:UpdateHighlight()
    end)
end

local eventHandlers = {}

eventHandlers.ADDON_LOADED = function(self, loadedAddon)
    if loadedAddon ~= addonName then
        return
    end

    self:InitializeDB()

    self.frame:UnregisterEvent("ADDON_LOADED")

    if NextTargetDB.debugMode then
        self:ShowDebugFrame()
    end

    print("|cFF00FF00[next]|r loaded. Type |cFFFFFF00/next help|r for options.")

    self:RequestUpdate()
end

eventHandlers.PLAYER_ENTERING_WORLD = function(self)
    resetCaches()
    self:RequestUpdate()
end

eventHandlers.PLAYER_TARGET_CHANGED = function(self)
    self:RequestUpdate()
end

eventHandlers.NAME_PLATE_UNIT_ADDED = function(self)
    self:RequestUpdate()
end

eventHandlers.NAME_PLATE_UNIT_REMOVED = function(self)
    self:RequestUpdate()
end

eventHandlers.QUEST_ACCEPTED = function(self)
    resetCaches()
    self:RequestUpdate()
end

eventHandlers.QUEST_LOG_UPDATE = eventHandlers.QUEST_ACCEPTED
eventHandlers.QUEST_REMOVED = eventHandlers.QUEST_ACCEPTED
eventHandlers.QUEST_TURNED_IN = eventHandlers.QUEST_ACCEPTED

eventHandlers.PLAYER_REGEN_DISABLED = function(self)
    self:RequestUpdate()
end

eventHandlers.PLAYER_REGEN_ENABLED = function(self)
    self:RequestUpdate()
end

addon.frame:SetScript("OnEvent", function(_, event, ...)
    local handler = eventHandlers[event]
    if handler then
        handler(addon, ...)
    end
end)

addon.frame:RegisterEvent("ADDON_LOADED")
addon.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
addon.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
addon.frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
addon.frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
addon.frame:RegisterEvent("QUEST_ACCEPTED")
addon.frame:RegisterEvent("QUEST_LOG_UPDATE")
addon.frame:RegisterEvent("QUEST_REMOVED")
addon.frame:RegisterEvent("QUEST_TURNED_IN")
addon.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
addon.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_NEXT1 = "/next"

SlashCmdList.NEXT = function(msg)
    msg = sanitizeCommand(msg or "")
    msg = msg:lower()

    if msg == "config" or msg == "options" or msg == "settings" then
        addon:OpenSettings()
        return
    end

    if msg == "toggle" then
        NextTargetDB.enabled = not NextTargetDB.enabled
        print(string.format("|cFF00FF00[next]|r addon %s", NextTargetDB.enabled and "enabled" or "disabled"))
        addon:RequestUpdate()
        return
    end

    if msg == "debug" then
        NextTargetDB.debugMode = not NextTargetDB.debugMode
        if NextTargetDB.debugMode then
            addon:ShowDebugFrame()
        else
            addon:HideDebugFrame()
        end
        addon:RequestUpdate()
        return
    end

    if msg == "combat" then
        NextTargetDB.onlyInCombat = not NextTargetDB.onlyInCombat
        print(string.format("|cFF00FF00[next]|r highlight %s outside combat", NextTargetDB.onlyInCombat and "hidden" or "shown"))
        addon:RequestUpdate()
        return
    end

    print("|cFF00FF00[next]|r commands:")
    print("  |cFFFFFF00/next config|r - open settings")
    print("  |cFFFFFF00/next toggle|r - enable or disable the addon")
    print("  |cFFFFFF00/next combat|r - toggle combat-only mode")
    print("  |cFFFFFF00/next debug|r - toggle debug window")
end
