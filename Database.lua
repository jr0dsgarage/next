---@diagnostic disable: undefined-global
local addonName, addon = ...

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
addon.CloneTable = cloneTable

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
addon.MergeDefaults = mergeDefaults

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
addon.WipeTable = wipeTable

local function sanitizeCommand(text)
    if not text then
        return ""
    end
    return text:match("^%s*(.-)%s*$") or ""
end
addon.SanitizeCommand = sanitizeCommand

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
