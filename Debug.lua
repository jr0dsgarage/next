---@diagnostic disable: undefined-global
local addonName, addon = ...

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
