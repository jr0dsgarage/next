-- Next Target Highlighter Addon
---@diagnostic disable: undefined-global, param-type-mismatch
local addonName, addon = ...

addon.frame = addon.frame or CreateFrame("Frame")
addon.highlights = addon.highlights or {}
addon.currentTargetGUID = addon.currentTargetGUID or nil
addon.pendingUpdate = addon.pendingUpdate or false

local sanitizeCommand = addon.SanitizeCommand

-- Classification helpers moved to Classification.lua

-- Highlight helpers moved to Highlights.lua

-- Debug frame helpers moved to Debug.lua

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

    local results = self:CollectHighlights()
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
    self:ResetCaches()
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
    self:ResetCaches()
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
