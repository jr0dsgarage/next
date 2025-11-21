---@diagnostic disable: undefined-global
local addonName, addon = ...

local wipeTable = addon.WipeTable

-- Texture pooling to avoid memory leaks from constant create/destroy
addon.texturePool = addon.texturePool or {}

local function acquireTexture()
    local texture = table.remove(addon.texturePool)
    if not texture then
        texture = UIParent:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    end
    return texture
end

local function releaseTexture(texture)
    if not texture then
        return
    end
    texture:Hide()
    texture:ClearAllPoints()
    texture:SetParent(nil)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetBlendMode("BLEND")
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetDrawLayer("OVERLAY")
    texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    texture:SetSize(0, 0)
    table.insert(addon.texturePool, texture)
end

local function resolveHealthBar(plate)
    if not plate then
        return nil
    end

    -- Try various known healthbar locations in order of likelihood
    local healthBarPaths = {
        -- Midnight beta / TWW structures
        function() return plate.UnitFrame and plate.UnitFrame.healthBar end,
        function() return plate.UnitFrame and plate.UnitFrame.healthBars and plate.UnitFrame.healthBars.healthBar end,
        function() return plate.UnitFrame and plate.UnitFrame.HealthBarsContainer and plate.UnitFrame.HealthBarsContainer.healthBar end,
        -- Legacy/fallback structure
        function() return plate.healthBar end,
        -- Additional possible locations for future-proofing
        function() return plate.UnitFrame and plate.UnitFrame.Health end,
        function() return plate.UnitFrame and plate.UnitFrame.HealthBar end,
    }

    for _, pathFunc in ipairs(healthBarPaths) do
        local success, healthBar = pcall(pathFunc)
        if success and healthBar and healthBar.GetObjectType then
            -- Verify it's actually a frame before returning
            local isFrame = pcall(function() return healthBar:GetObjectType() end)
            if isFrame then
                return healthBar
            end
        end
    end

    -- Log if we can't find healthbar (helps debug structure changes)
    if addon.debugMode or NextTargetDB.debugMode then
        local unitToken = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        local unitName = unitToken and UnitName(unitToken) or "unknown"
        print(string.format("[next] Warning: Could not resolve healthbar for %s", unitName))
    end

    return nil
end

local function acquireNameplate(unitData)
    if unitData.frame then
        return unitData.frame
    end
    
    -- Safely get nameplate with fallbacks
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local success, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitData.unit)
        if success and plate then
            return plate
        end
    end
    
    return nil
end

-- Shared helper to create and configure a basic texture
local function createStyledTexture(self, healthBar, color)
    local texture = acquireTexture()
    texture:SetParent(healthBar)
    texture:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    texture:Show()
    table.insert(self.highlights, texture)
    return texture
end

local function applyOutlineHighlight(self, healthBar, style, plate)
    local color = style.color
    local thickness = style.thickness or 2
    local offset = style.offset or 1

    local function createTexture(point, relativePoint, xOffset, yOffset, width, height)
        local texture = createStyledTexture(self, healthBar, color)
        texture:SetPoint(point, healthBar, relativePoint, xOffset, yOffset)
        if width then
            texture:SetWidth(width)
        end
        if height then
            texture:SetHeight(height)
        end
        return texture
    end

    local function createCorner(point, relativePoint, xOffset, yOffset)
        local texture = createStyledTexture(self, healthBar, color)
        texture:SetSize(thickness, thickness)
        texture:SetPoint(point, healthBar, relativePoint, xOffset, yOffset)
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

local function applyBlizzardHighlight(self, healthBar, style, plate)
    local color = style.color
    local offset = (style.offset or 0) + 4  -- Remap: user's 0 = actual 4 (Blizzard's size)

    local texture = createStyledTexture(self, healthBar, color)
    texture:SetDrawLayer("OVERLAY", 0)
    texture:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -offset, offset)
    texture:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", offset, -offset)
    
    -- Reset texture coordinates in case this texture was previously used for something else
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetBlendMode("BLEND")
    
    -- Use Blizzard's nameplate selection texture (has rounded corners)
    if texture.SetAtlas then
        local success = pcall(function() 
            texture:SetAtlas("UI-HUD-Nameplates-Selected", true) 
        end)
        if not success then
            -- Fallback to simple white texture
            texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        end
    else
        texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    end
end

local function applyGlowHighlight(self, healthBar, style, plate)
    local color = style.color
    local offset = (style.offset or 0) - 4  -- Reduce offset so glow sits tighter to healthbar

    -- Helper to create a glow texture piece using atlas
    local function createGlowTexture(atlasName, useAtlasSize)
        local texture = createStyledTexture(self, healthBar, color)
        texture:SetDrawLayer("OVERLAY", 1)
        texture:SetBlendMode("ADD")
        
        -- Try to set the atlas
        if texture.SetAtlas then
            local success = pcall(function() 
                texture:SetAtlas(atlasName, useAtlasSize or false)
            end)
            if not success then
                texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
            end
        else
            texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        end
        
        return texture
    end

    local edgeAtlases = {
        top = "_ButtonGreenGlow-NineSlice-EdgeTop",
        bottom = "_ButtonGreenGlow-NineSlice-EdgeBottom", 
        left = "!ButtonGreenGlow-NineSlice-EdgeLeft",
        right = "!ButtonGreenGlow-NineSlice-EdgeRight",
    }
    
    local cornerAtlas = "ButtonGreenGlow-NineSlice-Corner"

    -- Create edges
    local top = createGlowTexture(edgeAtlases.top, false)
    top:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", -offset, offset)
    top:SetPoint("BOTTOMRIGHT", healthBar, "TOPRIGHT", offset, offset)
    top:SetHeight(16)
    top:SetTexCoord(1, 0, 0, 1)  -- Flip horizontally

    local bottom = createGlowTexture(edgeAtlases.bottom, false)
    bottom:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", -offset, -offset)
    bottom:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", offset, -offset)
    bottom:SetHeight(16)
    bottom:SetTexCoord(1, 0, 0, 1)  -- Flip horizontally

    -- Always show left/right edges
    local left = createGlowTexture(edgeAtlases.left, false)
    left:SetPoint("TOPRIGHT", healthBar, "TOPLEFT", -offset, offset)
    left:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMLEFT", -offset, -offset)
    left:SetWidth(16)
    left:SetTexCoord(0, 1, 1, 0)  -- Flip vertically

    local right = createGlowTexture(edgeAtlases.right, false)
    right:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", offset, offset)
    right:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", offset, -offset)
    right:SetWidth(16)
    right:SetTexCoord(0, 1, 1, 0)  -- Flip vertically

    -- Create corners with proper rotation via texcoords
    local cornerSize = 16
    local cornerConfigs = {
        { point = "BOTTOMRIGHT", relPoint = "TOPLEFT", x = -offset, y = offset, hFlip = false, vFlip = false },      -- TopLeft
        { point = "BOTTOMLEFT", relPoint = "TOPRIGHT", x = offset, y = offset, hFlip = true, vFlip = false },      -- TopRight
        { point = "TOPRIGHT", relPoint = "BOTTOMLEFT", x = -offset, y = -offset, hFlip = false, vFlip = true },      -- BottomLeft
        { point = "TOPLEFT", relPoint = "BOTTOMRIGHT", x = offset, y = -offset, hFlip = true, vFlip = true },      -- BottomRight
    }

    for _, config in ipairs(cornerConfigs) do
        local tex = createGlowTexture(cornerAtlas, true)
        tex:SetSize(cornerSize, cornerSize)
        tex:SetPoint(config.point, healthBar, config.relPoint, config.x, config.y)
        
        local minX, maxX = config.hFlip and 1 or 0, config.hFlip and 0 or 1
        local minY, maxY = config.vFlip and 1 or 0, config.vFlip and 0 or 1
        tex:SetTexCoord(minX, maxX, minY, maxY)
    end
end

local highlightHandlers = {
    outline = applyOutlineHighlight,
    blizzard = applyBlizzardHighlight,
    glow = applyGlowHighlight,
}

local function determineStyle(result, currentGuid)
    local baseStyle

    local configMap = {
        ["Has Quest Item"] = { prefix = "questItem" },
        ["Bonus Objective"] = { prefix = "bonusObjective" },
        ["World Quest"] = { prefix = "worldQuest" },
        ["Quest Objective"] = { prefix = "questObjective" },
    }

    local config = configMap[result.reason]
    if config then
        local prefix = config.prefix
        if NextTargetDB[prefix .. "Enabled"] then
             baseStyle = {
                color = NextTargetDB[prefix .. "Color"],
                thickness = NextTargetDB[prefix .. "Thickness"],
                offset = NextTargetDB[prefix .. "Offset"],
                mode = NextTargetDB[prefix .. "Style"] or addon:GetDefault(prefix .. "Style") or "outline",
                origin = prefix,
            }
        end
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
        releaseTexture(texture)
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
