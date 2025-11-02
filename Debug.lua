---@diagnostic disable: undefined-global
local addonName, addon = ...

local floor = math.floor

local function clamp01(value)
    if not value then
        return 0
    end
    if value <= 0 then
        return 0
    end
    if value >= 1 then
        return 1
    end
    return value
end

local function colorTableToHex(color)
    if not color then
        return "FF00FF00"
    end

    local a = floor(clamp01(color.a or 1) * 255 + 0.5)
    local r = floor(clamp01(color.r or 0) * 255 + 0.5)
    local g = floor(clamp01(color.g or 0) * 255 + 0.5)
    local b = floor(clamp01(color.b or 0) * 255 + 0.5)

    return string.format("%02X%02X%02X%02X", a, r, g, b)
end

local function resolveHighlightReason(info)
    if info.reason and info.reason ~= "" then
        return info.reason
    end
    if info.highlightStyle and info.highlightStyle.baseReason then
        return info.highlightStyle.baseReason
    end
    return nil
end

local function resolveHighlightColor(info)
    local reason = resolveHighlightReason(info)
    if reason == "Has Quest Item" and NextTargetDB.questItemColor then
        return NextTargetDB.questItemColor
    end
    if reason == "World Quest" and NextTargetDB.worldQuestColor then
        return NextTargetDB.worldQuestColor
    end
    if reason == "Bonus Objective" and NextTargetDB.bonusObjectiveColor then
        return NextTargetDB.bonusObjectiveColor
    end
    if reason == "Quest Objective" and NextTargetDB.questObjectiveColor then
        return NextTargetDB.questObjectiveColor
    end
    if reason == "Mythic Objective" and NextTargetDB.mythicObjectiveColor then
        return NextTargetDB.mythicObjectiveColor
    end

    if info.highlightStyle and info.highlightStyle.color then
        return info.highlightStyle.color
    end

    if NextTargetDB.currentTargetColor then
        return NextTargetDB.currentTargetColor
    end

    return { r = 0, g = 1, b = 0, a = 1 }
end

local function buildOnText(info)
    local hex = colorTableToHex(resolveHighlightColor(info))
    return string.format("|c%sON|r", hex)
end

local function ensureDebugFrame()
    if addon.debugFrame then
        return addon.debugFrame
    end

    local frame = CreateFrame("Frame", addonName .. "DebugFrame", UIParent, "BackdropTemplate")
    frame:SetSize(720, 300)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
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

    local config = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    config:SetSize(80, 22)
    config:SetPoint("TOPRIGHT", -126, -12)
    config:SetText("Config")
    config:SetScript("OnClick", function()
        if addon.OpenSettings then
            addon:OpenSettings()
        end
    end)

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
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 32)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetWidth(620)
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
    frame.scroll = scroll

    local resizeHandle = CreateFrame("Frame", nil, frame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)

    local handleTexture = resizeHandle:CreateTexture(nil, "OVERLAY")
    handleTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    handleTexture:SetAllPoints(resizeHandle)

    resizeHandle:EnableMouse(true)
    resizeHandle:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        addon:UpdateDebugFrameLayout()
    end)
    resizeHandle:SetScript("OnEnter", function()
        handleTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end)
    resizeHandle:SetScript("OnLeave", function()
        handleTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end)

    if frame.SetResizeBounds then
        frame:SetResizeBounds(520, 240, 900, 600)
    else
        if frame.SetMinResize then
            frame:SetMinResize(520, 240)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(900, 600)
        end
    end

    frame:SetScript("OnSizeChanged", function()
        addon:UpdateDebugFrameLayout()
    end)

    frame.resizeHandle = resizeHandle
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
    if info.isMythicBoss then
        if info.mythicBossName and info.mythicBossName ~= "" then
            return string.format("Mythic Boss: %s", info.mythicBossName)
        end
        return "Mythic Boss"
    end
    if info.isMythicEnemyForces then
        if info.mythicEnemyForcesTotal and info.mythicEnemyForcesTotal > 0 then
            return string.format("Enemy Forces (%d/%d)", info.mythicEnemyForcesProgress or 0, info.mythicEnemyForcesTotal)
        end
        return "Enemy Forces"
    end
    if info.reason == "Mythic Objective" or info.isMythicObjective then
        return "Mythic Objective"
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
            local highlightOnText = buildOnText(info)
            highlightExplanation = string.format(
                "    Highlight: %s - %s - Quest: %s",
                highlightOnText,
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

    addon:UpdateDebugFrameLayout()
end

function addon:UpdateDebugFrameLayout()
    if not self.debugFrame then
        return
    end

    local frame = self.debugFrame
    local editBox = frame.editBox
    local scroll = frame.scroll
    if not editBox or not scroll then
        return
    end

    local width = math.max(360, frame:GetWidth() - 100)
    local height = math.max(240, frame:GetHeight() - 120)

    editBox:SetWidth(width)
    editBox:SetHeight(height)
end
