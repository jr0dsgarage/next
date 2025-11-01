---@diagnostic disable: undefined-global
local addonName, addon = ...

local wipeTable = addon.WipeTable
local strgsub = string.gsub
local strlower = string.lower

local questUtilsIsWorldQuest = rawget(_G, "QuestUtils_IsQuestWorldQuest")
local questUtilsIsBonusObjective = rawget(_G, "QuestUtils_IsQuestBonusObjective")

local function trim(value)
    if not value then
        return ""
    end

    local trimmed = value:gsub("^%s+", "")
    trimmed = trimmed:gsub("%s+$", "")
    return trimmed
end

local function stripColorCodes(text)
    if not text or text == "" then
        return text
    end
    text = strgsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = strgsub(text, "|r", "")
    return text
end

local function normalizeText(text)
    if not text or text == "" then
        return nil
    end

    text = stripColorCodes(text)
    if not text or text == "" then
        return nil
    end

    text = strgsub(text, "%b()", " ")
    text = strgsub(text, "[%[%]]", " ")
    text = strgsub(text, "[%p%c]", " ")
    text = strlower(strgsub(text, "%s+", " "))
    text = trim(text)

    if text == "" then
        return nil
    end

    return text
end

local function normalizeLines(lines)
    if not lines or #lines == 0 then
        return nil
    end

    local normalized = {}
    for _, line in ipairs(lines) do
        local normalizedLine = normalizeText(line)
        if normalizedLine and normalizedLine ~= "" then
            normalized[#normalized + 1] = normalizedLine
        end
    end

    if #normalized == 0 then
        return nil
    end

    return normalized
end

local function addObjectiveText(entry, text)
    if not text or text == "" then
        return
    end

    entry.objectives[#entry.objectives + 1] = text

    local normalized = normalizeText(text)
    if normalized then
        entry.normalizedObjectives[#entry.normalizedObjectives + 1] = normalized
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

    local uniqueLines = {}

    tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    tooltipScanner:SetUnit(unit)

    local lineCount = tooltipScanner:NumLines() or 0
    for index = 2, lineCount do
        local line = _G[tooltipScanner:GetName() .. "TextLeft" .. index]
        if line then
            local text = line:GetText()
            if text and text ~= "" then
                local sanitized = stripColorCodes(text)
                if sanitized then
                    sanitized = trim(strgsub(sanitized, "%s+", " "))
                end

                if sanitized and sanitized ~= "" and not uniqueLines[sanitized] then
                    uniqueLines[sanitized] = true
                    info.lines[#info.lines + 1] = sanitized
                end

                local toEvaluate = sanitized or text
                local current, total = toEvaluate:match("(%d+)%s*/%s*(%d+)")
                if current and total then
                    local currentNum = tonumber(current)
                    local totalNum = tonumber(total)
                    if currentNum and totalNum then
                        if currentNum >= totalNum then
                            info.hasCompletedObjective = true
                        else
                            info.hasQuestObjective = true
                        end
                    end
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

    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not GetQuestObjectiveInfo then
        return questCache.entries
    end

    local addedQuestIDs = {}

    local function determineWorldQuestFlag(questID, seedFlag)
        if seedFlag then
            return true
        end

        if not questID then
            return false
        end

        if C_QuestLog and C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) then
            return true
        end

        if questUtilsIsWorldQuest and questUtilsIsWorldQuest(questID) then
            return true
        end

        if questUtilsIsBonusObjective and questUtilsIsBonusObjective(questID) then
            return true
        end

        if C_TaskQuest then
            if C_TaskQuest.IsActive and C_TaskQuest.IsActive(questID) then
                return true
            end

            if C_TaskQuest.GetQuestInfoByQuestID then
                local taskInfo = C_TaskQuest.GetQuestInfoByQuestID(questID)
                if taskInfo and (taskInfo.isDaily or taskInfo.isInvasion or taskInfo.isCombatAllyQuest or taskInfo.isQuestStart) then
                    return true
                end
            end
        end

        return false
    end

    local function addEntry(entry)
        if not entry or not entry.questID then
            return
        end
        addedQuestIDs[entry.questID] = true
        if #entry.objectives > 0 then
            questCache.entries[#questCache.entries + 1] = entry
        end
    end

    local function buildQuestEntry(questID, isWorldQuest)
        if not questID or addedQuestIDs[questID] then
            return nil
        end

        if C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) then
            addedQuestIDs[questID] = true
            return nil
        end

        local entry = {
            questID = questID,
            questName = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or "Unknown Quest",
            isWorldQuest = false,
            objectives = {},
            normalizedObjectives = {},
        }

        entry.isWorldQuest = determineWorldQuestFlag(questID, isWorldQuest)

        if C_QuestLog.GetQuestObjectives then
            local objectives = C_QuestLog.GetQuestObjectives(questID)
            if objectives then
                for _, objective in ipairs(objectives) do
                    if objective and objective.text and objective.text ~= "" and not objective.finished then
                        addObjectiveText(entry, objective.text)
                    end
                end
            end
        end

        if #entry.objectives == 0 then
            local objectiveCount = C_QuestLog.GetNumQuestObjectives and C_QuestLog.GetNumQuestObjectives(questID) or 0
            for objectiveIndex = 1, objectiveCount do
                local text, _, finished = GetQuestObjectiveInfo(questID, objectiveIndex, false)
                if text and text ~= "" and not finished then
                    addObjectiveText(entry, text)
                end
            end
        end

        addedQuestIDs[questID] = true
        return entry
    end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for index = 1, numEntries do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and info.questID then
            local questID = info.questID
            local entry = buildQuestEntry(questID, nil)
            addEntry(entry)
        end
    end

    if C_TaskQuest and C_TaskQuest.GetQuestsForPlayerByMapID and C_Map and C_Map.GetBestMapForUnit then
        local processedMaps = {}

        local function addWorldQuest(questID)
            local entry = buildQuestEntry(questID, true)
            addEntry(entry)
        end

        local function processMap(mapID)
            if not mapID or processedMaps[mapID] then
                return
            end
            processedMaps[mapID] = true

            local tasks = C_TaskQuest.GetQuestsForPlayerByMapID(mapID)
            if tasks then
                for _, taskInfo in ipairs(tasks) do
                    local questID = taskInfo and taskInfo.questId
                    if questID then
                        local isActive
                        if C_TaskQuest.IsActive then
                            isActive = C_TaskQuest.IsActive(questID)
                        else
                            isActive = taskInfo.inProgress ~= false
                        end
                        if isActive then
                            addWorldQuest(questID)
                        end
                    end
                end
            end

            if C_Map.GetMapChildrenInfo and Enum and Enum.UIMapType then
                local children = C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone, false)
                if children then
                    for _, child in ipairs(children) do
                        if child and child.mapID then
                            processMap(child.mapID)
                        end
                    end
                end
            end
        end

        local currentMap = C_Map.GetBestMapForUnit("player")
        local depth = 0
        while currentMap and depth < 6 do
            processMap(currentMap)
            local mapInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(currentMap)
            if mapInfo and mapInfo.parentMapID then
                currentMap = mapInfo.parentMapID
            else
                currentMap = nil
            end
            depth = depth + 1
        end
    end

    return questCache.entries
end

local function objectiveMatches(unit, unitName, tooltipLines, questEntries)
    local unitNameNormalized = normalizeText(unitName)
    local unitIsRelatedToQuest = C_QuestLog and C_QuestLog.UnitIsRelatedToQuest
    local highlightedTooltipLines

    for _, entry in ipairs(questEntries) do
        if entry.questID and unit and unitIsRelatedToQuest then
            local related = unitIsRelatedToQuest(unit, entry.questID)
            if related then
                return true, entry.isWorldQuest, entry.questName, entry.questID
            end
        end

        if entry.normalizedObjectives and unitNameNormalized then
            for _, normalizedObjective in ipairs(entry.normalizedObjectives) do
                if normalizedObjective and normalizedObjective:find(unitNameNormalized, 1, true) then
                    return true, entry.isWorldQuest, entry.questName, entry.questID
                end
            end
        end

        if tooltipLines and entry.normalizedObjectives then
            highlightedTooltipLines = highlightedTooltipLines or normalizeLines(tooltipLines)
            if highlightedTooltipLines then
                for _, tooltipLine in ipairs(highlightedTooltipLines) do
                    for _, normalizedObjective in ipairs(entry.normalizedObjectives) do
                        if normalizedObjective and (normalizedObjective:find(tooltipLine, 1, true) or tooltipLine:find(normalizedObjective, 1, true)) then
                            return true, entry.isWorldQuest, entry.questName, entry.questID
                        end
                    end
                end
            end
        end
    end

    return false, false, nil, nil
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
    local hasObjective, isWorldQuest, questName, questID = objectiveMatches(unit, unitName, tooltipInfo.lines, questEntries)
    local hasSoftTarget = hasQuestItemIcon(unit)
    local isQuestBoss = UnitIsQuestBoss and UnitIsQuestBoss(unit)

    local classification = UnitClassification and UnitClassification(unit)
    local isRare = classification == "rare" or classification == "rareelite" or classification == "elite"

    local reason
    if hasSoftTarget then
        reason = "Has Quest Item"
    elseif hasObjective or tooltipInfo.hasQuestObjective then
        reason = isWorldQuest and "World Quest" or "Quest Objective"
    end

    local result = {
        unit = unit,
        guid = guid,
        frame = unitData.frame,
        name = unitName,
        reason = reason,
        questName = questName,
        questID = questID,
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
        elseif isQuestBoss then
            result.note = "Quest boss for unavailable quest"
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

local function getRelevantUnits()
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

function addon:ResetCaches()
    resetCaches()
end

function addon:GetRelevantUnits()
    return getRelevantUnits()
end

function addon:ClassifyUnit(unitData)
    return classifyUnit(unitData)
end

function addon:GetQuestCache()
    return questCache.entries
end
