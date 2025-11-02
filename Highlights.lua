---@diagnostic disable: undefined-global
local addonName, addon = ...

local wipeTable = addon.WipeTable

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

local function applyOutlineHighlight(self, healthBar, style, plate)
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

local highlightHandlers = {
    outline = applyOutlineHighlight,
}

local function determineStyle(result, currentGuid)
    local baseStyle

    if result.reason == "Has Quest Item" and NextTargetDB.questItemEnabled then
        baseStyle = {
            color = NextTargetDB.questItemColor,
            thickness = NextTargetDB.questItemThickness,
            offset = NextTargetDB.questItemOffset,
            mode = NextTargetDB.questItemStyle or addon:GetDefault("questItemStyle") or "outline",
            origin = "questItem",
        }
    elseif result.reason == "Bonus Objective" and NextTargetDB.bonusObjectiveEnabled then
        baseStyle = {
            color = NextTargetDB.bonusObjectiveColor,
            thickness = NextTargetDB.bonusObjectiveThickness,
            offset = NextTargetDB.bonusObjectiveOffset,
            mode = NextTargetDB.bonusObjectiveStyle or addon:GetDefault("bonusObjectiveStyle") or "outline",
            origin = "bonusObjective",
        }
    elseif result.reason == "World Quest" and NextTargetDB.worldQuestEnabled then
        baseStyle = {
            color = NextTargetDB.worldQuestColor,
            thickness = NextTargetDB.worldQuestThickness,
            offset = NextTargetDB.worldQuestOffset,
            mode = NextTargetDB.worldQuestStyle or addon:GetDefault("worldQuestStyle") or "outline",
            origin = "worldQuest",
        }
    elseif result.reason == "Quest Objective" and NextTargetDB.questObjectiveEnabled then
        baseStyle = {
            color = NextTargetDB.questObjectiveColor,
            thickness = NextTargetDB.questObjectiveThickness,
            offset = NextTargetDB.questObjectiveOffset,
            mode = NextTargetDB.questObjectiveStyle or addon:GetDefault("questObjectiveStyle") or "outline",
            origin = "questObjective",
        }
    elseif result.reason == "Mythic Objective" and NextTargetDB.mythicObjectiveEnabled then
        baseStyle = {
            color = NextTargetDB.mythicObjectiveColor,
            thickness = NextTargetDB.mythicObjectiveThickness,
            offset = NextTargetDB.mythicObjectiveOffset,
            mode = NextTargetDB.mythicObjectiveStyle or addon:GetDefault("mythicObjectiveStyle") or "outline",
            origin = "mythicObjective",
        }
    end

    if not baseStyle then
        return nil
    end

    if baseStyle.mode == "border" then
        baseStyle.mode = "outline"
    end

    if result.guid == currentGuid and NextTargetDB.currentTargetEnabled then
        local mode = NextTargetDB.currentTargetStyle or addon:GetDefault("currentTargetStyle") or (baseStyle and baseStyle.mode) or "outline"
        if mode == "border" then
            mode = "outline"
        end
        return {
            color = NextTargetDB.currentTargetColor,
            thickness = NextTargetDB.currentTargetThickness,
            offset = NextTargetDB.currentTargetOffset,
            mode = mode,
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

function addon:CollectHighlights()
    local relevantUnits = self:GetRelevantUnits()
    local results = {}
    local currentGuid = UnitGUID("target")

    for _, unitData in ipairs(relevantUnits) do
        local classification = self:ClassifyUnit(unitData)
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
                    local mode = style.mode or "outline"
                    if mode == "border" then
                        mode = "outline"
                        style.mode = "outline"
                    end
                    local handler = highlightHandlers[mode] or applyOutlineHighlight
                    handler(self, healthBar, style)
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
