-- Options panel for next
---@diagnostic disable: undefined-global
local addonName, addon = ...

local panel = CreateFrame("Frame")
panel.name = "next"

local scrollFrame = CreateFrame("ScrollFrame", addonName .. "SettingsScrollFrame", panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 3, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", -27, 4)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(620, 640)
scrollFrame:SetScrollChild(content)

local ui = {
    built = false,
    highlightRows = {},
    preview = {
        highlights = {},
    },
}

local highlightOptions = {
    { key = "currentTarget", label = "Current Target" },
    { key = "questObjective", label = "Quest Objective Target" },
    { key = "questItem", label = "Quest Item Target" },
    { key = "worldQuest", label = "World Quest Objective Target" },
    { key = "bonusObjective", label = "Bonus Objective Target" },
    { key = "mythicObjective", label = "Mythic+ Dungeon Target" },
}

local highlightStyleChoices = {
    { value = "outline", label = "Outline" },
    { value = "blizzard", label = "Blizzard" },
    { value = "glow", label = "Glow" },
}

local function styleLabelFor(value)
    for _, choice in ipairs(highlightStyleChoices) do
        if choice.value == value then
            return choice.label
        end
    end
    return value or "Outline"
end

local highlightOptionsByKey = {}
for _, option in ipairs(highlightOptions) do
    highlightOptionsByKey[option.key] = option
end

local WHITE_TEXTURE = "Interface\\BUTTONS\\WHITE8X8"
local previewClickSound = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
local max = math.max
local wipe = wipe

local updatePreview
local selectPreviewOption

local function ensurePreviewHighlights()
    if not ui.preview.highlights then
        ui.preview.highlights = {}
    end
end

local function clearPreviewHighlights()
    if not ui.preview or not ui.preview.highlights then
        return
    end
    for _, texture in ipairs(ui.preview.highlights) do
        texture:Hide()
        texture:SetParent(nil)
    end
    wipe(ui.preview.highlights)
end

local function applyOutlinePreview(style)
    if not ui.preview or not ui.preview.healthBar then
        return
    end

    ensurePreviewHighlights()

    local healthBar = ui.preview.healthBar
    local color = style.color or {}
    local r = color.r or 1
    local g = color.g or 1
    local b = color.b or 1
    local a = color.a or 1
    if not style.enabled then
        a = a * 0.35
    end

    local thickness = max(1, style.thickness or 1)
    local offset = max(0, style.offset or 0)

    local function addTexture(point, relativePoint, xOffset, yOffset, width, height)
        local texture = healthBar:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(WHITE_TEXTURE)
        texture:SetVertexColor(r, g, b, a)
        texture:SetPoint(point, healthBar, relativePoint, xOffset, yOffset)
        if width then
            texture:SetWidth(width)
        end
        if height then
            texture:SetHeight(height)
        end
        texture:Show()
        ui.preview.highlights[#ui.preview.highlights + 1] = texture
        return texture
    end

    local top = addTexture("BOTTOMLEFT", "TOPLEFT", -offset, offset, nil, thickness)
    top:SetPoint("BOTTOMRIGHT", healthBar, "TOPRIGHT", offset, offset)

    local bottom = addTexture("TOPLEFT", "BOTTOMLEFT", -offset, -offset, nil, thickness)
    bottom:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", offset, -offset)

    local left = addTexture("TOPRIGHT", "TOPLEFT", -offset, offset, thickness, nil)
    left:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMLEFT", -offset, -offset)

    local right = addTexture("TOPLEFT", "TOPRIGHT", offset, offset, thickness, nil)
    right:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", offset, -offset)

    local function addCorner(point, relativePoint, xOffset, yOffset)
        local texture = healthBar:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(WHITE_TEXTURE)
        texture:SetVertexColor(r, g, b, a)
        texture:SetSize(thickness, thickness)
        texture:SetPoint(point, healthBar, relativePoint, xOffset, yOffset)
        texture:Show()
        ui.preview.highlights[#ui.preview.highlights + 1] = texture
    end

    addCorner("BOTTOMRIGHT", "TOPLEFT", -offset, offset)
    addCorner("BOTTOMLEFT", "TOPRIGHT", offset, offset)
    addCorner("TOPRIGHT", "BOTTOMLEFT", -offset, -offset)
    addCorner("TOPLEFT", "BOTTOMRIGHT", offset, -offset)
end

local function applyBlizzardPreview(style)
    if not ui.preview or not ui.preview.healthBar then
        return
    end

    ensurePreviewHighlights()

    local healthBar = ui.preview.healthBar
    local color = style.color or {}
    local r = color.r or 1
    local g = color.g or 1
    local b = color.b or 1
    local a = color.a or 1
    if not style.enabled then
        a = a * 0.35
    end

    local offset = (style.offset or 0) + 4  -- Remap: user's 0 = actual 4 (Blizzard's size)

    local texture = healthBar:CreateTexture(nil, "OVERLAY")
    texture:SetVertexColor(r, g, b, a)
    texture:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -offset, offset)
    texture:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", offset, -offset)
    
    if texture.SetAtlas then
        pcall(function() texture:SetAtlas("UI-HUD-Nameplates-Selected", true) end)
    end
    
    texture:Show()
    ui.preview.highlights[#ui.preview.highlights + 1] = texture
end

local function applyGlowPreview(style)
    if not ui.preview or not ui.preview.healthBar then
        return
    end

    ensurePreviewHighlights()

    local healthBar = ui.preview.healthBar
    local color = style.color or {}
    local r = color.r or 1
    local g = color.g or 1
    local b = color.b or 1
    local a = color.a or 1
    if not style.enabled then
        a = a * 0.35
    end

    local thickness = style.thickness or 2
    local offset = (style.offset or 0) - 4  -- Reduce offset so glow sits tighter to healthbar

    local function createGlowTexture(atlasName, useAtlasSize)
        local texture = healthBar:CreateTexture(nil, "OVERLAY", nil, 1)
        
        if texture.SetAtlas then
            local success = pcall(function() 
                texture:SetAtlas(atlasName, useAtlasSize or false)
            end)
            if not success then
                texture:SetTexture(WHITE_TEXTURE)
            end
        else
            texture:SetTexture(WHITE_TEXTURE)
        end
        
        texture:SetVertexColor(r, g, b, a)
        texture:SetBlendMode("ADD")
        texture:Show()
        ui.preview.highlights[#ui.preview.highlights + 1] = texture
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

    local bottom = createGlowTexture(edgeAtlases.bottom, false)
    bottom:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", -offset, -offset)
    bottom:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", offset, -offset)
    bottom:SetHeight(16)

    -- Only show left/right edges if offset is greater than 1
    if (style.offset or 0) > 1 then
        local left = createGlowTexture(edgeAtlases.left, false)
        left:SetPoint("TOPRIGHT", healthBar, "TOPLEFT", -offset, offset)
        left:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMLEFT", -offset, -offset)
        left:SetWidth(16)

        local right = createGlowTexture(edgeAtlases.right, false)
        right:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", offset, offset)
        right:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", offset, -offset)
        right:SetWidth(16)
    end

    -- Create corners with proper rotation via texcoords
    local cornerSize = 16
    
    local topLeft = createGlowTexture(cornerAtlas, true)
    topLeft:SetSize(cornerSize, cornerSize)
    topLeft:SetPoint("BOTTOMRIGHT", healthBar, "TOPLEFT", -offset, offset)

    local topRight = createGlowTexture(cornerAtlas, true)
    topRight:SetSize(cornerSize, cornerSize)
    topRight:SetPoint("BOTTOMLEFT", healthBar, "TOPRIGHT", offset, offset)
    topRight:SetTexCoord(1, 0, 0, 1)

    local bottomLeft = createGlowTexture(cornerAtlas, true)
    bottomLeft:SetSize(cornerSize, cornerSize)
    bottomLeft:SetPoint("TOPRIGHT", healthBar, "BOTTOMLEFT", -offset, -offset)
    bottomLeft:SetTexCoord(0, 1, 1, 0)

    local bottomRight = createGlowTexture(cornerAtlas, true)
    bottomRight:SetSize(cornerSize, cornerSize)
    bottomRight:SetPoint("TOPLEFT", healthBar, "BOTTOMRIGHT", offset, -offset)
    bottomRight:SetTexCoord(1, 0, 1, 0)
end

local previewHandlers = {
    outline = applyOutlinePreview,
    blizzard = applyBlizzardPreview,
    glow = applyGlowPreview,
}

local function applyPreviewHighlight(style)
    if not style then
        clearPreviewHighlights()
        return
    end

    local mode = style.mode or "outline"
    if mode == "border" then
        mode = "outline"
    end

    clearPreviewHighlights()

    local handler = previewHandlers[mode]
    if handler then
        handler(style)
    end
end

local function buildStyleData(optionKey)
    local option = highlightOptionsByKey[optionKey]
    if not option then
        return nil
    end

    local colorKey = option.key .. "Color"
    local thicknessKey = option.key .. "Thickness"
    local offsetKey = option.key .. "Offset"
    local styleKey = option.key .. "Style"
    local enabledKey = option.key .. "Enabled"

    local color = NextTargetDB[colorKey]
    if not color then
        color = addon:GetDefault(colorKey)
        NextTargetDB[colorKey] = color
    end
    color = color or { r = 1, g = 1, b = 1, a = 1 }

    local thicknessValue = NextTargetDB[thicknessKey] or addon:GetDefault(thicknessKey) or 1
    local offsetValue = NextTargetDB[offsetKey] or addon:GetDefault(offsetKey) or 0
    local styleValue = NextTargetDB[styleKey] or addon:GetDefault(styleKey) or "outline"
    NextTargetDB[styleKey] = styleValue

    return {
        option = option,
        color = color,
        thickness = thicknessValue,
        offset = offsetValue,
        mode = styleValue,
        enabled = NextTargetDB[enabledKey] ~= false,
    }
end

local function updatePreviewButtonStates(selectedKey)
    for key, row in pairs(ui.highlightRows) do
        local button = row.previewButton
        local indicator = row.previewIndicator
        if button then
            local enabled = NextTargetDB[key .. "Enabled"] ~= false
            local isSelected = (key == selectedKey)

            if isSelected then
                button:Hide()
                if indicator then
                    indicator:Show()
                    indicator:SetAlpha(enabled and 1 or 0.6)
                end
            else
                button:SetAlpha(enabled and 1 or 0.6)
                button:SetEnabled(enabled)
                button:Show()
                if indicator then
                    indicator:Hide()
                end
            end
        end
    end
end

updatePreview = function(optionKey)
    if not ui.preview or not ui.preview.frame then
        return
    end

    optionKey = optionKey or ui.preview.activeKey
    if not optionKey then
        return
    end

    local style = buildStyleData(optionKey)
    if not style then
        return
    end

    ui.preview.activeKey = optionKey

    applyPreviewHighlight(style)
    updatePreviewButtonStates(optionKey)
end

selectPreviewOption = function(optionKey)
    updatePreview(optionKey)
end

local function accentuate()
    if addon.ClearHighlights then
        addon:ClearHighlights()
    end
    if addon.UpdateHighlight then
        addon:UpdateHighlight()
    end
end

local function updateSwatch(button, color)
    button.swatch:SetColorTexture(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

local function useColorPicker(color, onChanged)
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
        return
    end

    local function apply()
        color.r, color.g, color.b = ColorPickerFrame:GetColorRGB()
        color.a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or 1
        onChanged()
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = color.r or 1,
        g = color.g or 1,
        b = color.b or 1,
        opacity = color.a or 1,
        hasOpacity = true,
        swatchFunc = apply,
        opacityFunc = apply,
        cancelFunc = function()
            local previous = ColorPickerFrame.previousValues
            if previous then
                color.r = previous.r
                color.g = previous.g
                color.b = previous.b
                color.a = previous.opacity
                onChanged()
            end
        end,
    })
end

local function createHighlightRow(anchor, option, index)
    local rowOffset = -12 - (index - 1) * 68  -- Increased spacing for two-line layout

    -- Label on first line
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, rowOffset)
    label:SetWidth(600)
    label:SetJustifyH("LEFT")
    label:SetText(option.label)

    -- All controls on second line, below the label
    local controlY = rowOffset - 18

    local checkbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, controlY)
    checkbox.Text:SetText("")  -- Remove text, label is above

    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", checkbox, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(dropdown, 120)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")

    local colorButton = CreateFrame("Button", nil, content)
    colorButton:SetPoint("LEFT", dropdown, "RIGHT", 4, 0)
    colorButton:SetSize(24, 24)

    local border = colorButton:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 0.8)

    local swatch = colorButton:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 1, -1)
    swatch:SetPoint("BOTTOMRIGHT", -1, 1)
    colorButton.swatch = swatch

    local thickness = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    thickness:SetPoint("LEFT", colorButton, "RIGHT", 12, 0)
    thickness:SetMinMaxValues(1, 5)
    thickness:SetValueStep(1)
    thickness:SetObeyStepOnDrag(true)
    thickness:SetWidth(100)
    thickness.Low:SetText("1")
    thickness.High:SetText("5")
    thickness.Text:ClearAllPoints()
    thickness.Text:SetPoint("BOTTOM", thickness, "TOP", 0, 2)
    thickness.Text:SetJustifyH("CENTER")

    local offset = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    offset:SetPoint("LEFT", thickness, "RIGHT", 12, 0)
    offset:SetMinMaxValues(0, 5)
    offset:SetValueStep(1)
    offset:SetObeyStepOnDrag(true)
    offset:SetWidth(100)
    offset.Low:SetText("0")
    offset.High:SetText("5")
    offset.Text:ClearAllPoints()
    offset.Text:SetPoint("BOTTOM", offset, "TOP", 0, 2)
    offset.Text:SetJustifyH("CENTER")

    local previewButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    previewButton:SetPoint("LEFT", offset, "RIGHT", 12, 0)
    previewButton:SetSize(24, 22)
    previewButton:SetMotionScriptsWhileDisabled(true)
    previewButton:SetText("i")
    previewButton:SetNormalFontObject(GameFontHighlightSmall)
    previewButton:SetHighlightFontObject(GameFontHighlightSmall)
    previewButton:SetDisabledFontObject(GameFontDisableSmall)

    local function tintButtonTextures(button, normal, highlight, disabled)
        local normalTexture = button:GetNormalTexture()
        if normalTexture then
            normalTexture:SetVertexColor(normal.r, normal.g, normal.b, normal.a or 1)
        end
        local highlightTexture = button:GetHighlightTexture()
        if highlightTexture then
            highlightTexture:SetVertexColor(highlight.r, highlight.g, highlight.b, highlight.a or 1)
        end
        local disabledTexture = button:GetDisabledTexture()
        if disabledTexture then
            disabledTexture:SetVertexColor(disabled.r, disabled.g, disabled.b, disabled.a or 1)
        end
    end

    tintButtonTextures(previewButton, { r = 0.7, g = 0.1, b = 0.1 }, { r = 1, g = 0.2, b = 0.2 }, { r = 0.3, g = 0.06, b = 0.06 })

    local indicator = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    indicator:SetPoint("CENTER", previewButton, "CENTER", 0, 0)
    indicator:SetSize(24, 22)
    indicator:SetText("i")
    indicator:SetNormalFontObject(GameFontHighlightSmall)
    indicator:SetDisabledFontObject(GameFontDisableSmall)
    indicator:Disable()
    indicator:EnableMouse(false)
    indicator:Hide()
    tintButtonTextures(indicator, { r = 0.65, g = 0.1, b = 0.1 }, { r = 0.9, g = 0.2, b = 0.2 }, { r = 0.35, g = 0.08, b = 0.08 })

    return {
        label = label,
        checkbox = checkbox,
        dropdown = dropdown,
        colorButton = colorButton,
        thickness = thickness,
        offset = offset,
        previewButton = previewButton,
        previewIndicator = indicator,
    }
end

local function bindHighlightRow(option, row)
    local enabledKey = option.key .. "Enabled"
    local colorKey = option.key .. "Color"
    local thicknessKey = option.key .. "Thickness"
    local offsetKey = option.key .. "Offset"
    local styleKey = option.key .. "Style"

    row.checkbox:SetScript("OnClick", function(self)
        NextTargetDB[enabledKey] = self:GetChecked()
        accentuate()
        if ui.preview.activeKey == option.key then
            updatePreview(option.key)
        else
            updatePreviewButtonStates(ui.preview.activeKey or option.key)
        end
    end)

    row.colorButton:SetScript("OnClick", function()
        local color = NextTargetDB[colorKey]
        if not color then
            color = addon:GetDefault(colorKey)
            NextTargetDB[colorKey] = color
        end
        useColorPicker(color, function()
            updateSwatch(row.colorButton, color)
            accentuate()
            if ui.preview.activeKey == option.key then
                updatePreview(option.key)
            end
        end)
    end)

    row.thickness:SetScript("OnValueChanged", function(self, value)
        if self.isUpdating then
            return
        end
        local rounded = math.floor(value + 0.5)
        NextTargetDB[thicknessKey] = rounded
        self.Text:SetText(string.format("Thickness: %d", rounded))
        accentuate()
        if ui.preview.activeKey == option.key then
            updatePreview(option.key)
        end
    end)

    row.offset:SetScript("OnValueChanged", function(self, value)
        if self.isUpdating then
            return
        end
        local rounded = math.floor(value + 0.5)
        NextTargetDB[offsetKey] = rounded
        self.Text:SetText(string.format("Offset: %d", rounded))
        accentuate()
        if ui.preview.activeKey == option.key then
            updatePreview(option.key)
        end
    end)

    UIDropDownMenu_Initialize(row.dropdown, function(_, level)
        if level ~= 1 then
            return
        end
        local current = NextTargetDB[styleKey] or addon:GetDefault(styleKey) or "outline"
        for _, choice in ipairs(highlightStyleChoices) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = choice.label
            info.value = choice.value
            info.func = function()
                NextTargetDB[styleKey] = choice.value
                UIDropDownMenu_SetSelectedValue(row.dropdown, choice.value)
                UIDropDownMenu_SetText(row.dropdown, choice.label)
                
                -- Enable/disable thickness slider based on style
                local isBlizzard = choice.value == "blizzard"
                if isBlizzard then
                    row.thickness:Disable()
                    row.thickness.Text:SetTextColor(0.5, 0.5, 0.5)
                    row.thickness.Low:SetTextColor(0.5, 0.5, 0.5)
                    row.thickness.High:SetTextColor(0.5, 0.5, 0.5)
                else
                    row.thickness:Enable()
                    row.thickness.Text:SetTextColor(1, 1, 1)
                    row.thickness.Low:SetTextColor(1, 1, 1)
                    row.thickness.High:SetTextColor(1, 1, 1)
                end
                
                accentuate()
                if ui.preview.activeKey == option.key then
                    updatePreview(option.key)
                end
            end
            info.checked = (current == choice.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    if row.previewButton then
        row.previewButton.optionKey = option.key
        row.previewButton:SetScript("OnClick", function()
            if PlaySound and previewClickSound then
                PlaySound(previewClickSound)
            end
            selectPreviewOption(option.key)
        end)
        row.previewButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(option.label)
            GameTooltip:AddLine("Click to preview this highlight.", 1, 1, 1)
            GameTooltip:Show()
        end)
        row.previewButton:SetScript("OnLeave", GameTooltip_Hide)
    end
end

local function refreshHighlightRow(option, row)
    local colorKey = option.key .. "Color"
    local thicknessKey = option.key .. "Thickness"
    local offsetKey = option.key .. "Offset"
    local enabledKey = option.key .. "Enabled"
    local styleKey = option.key .. "Style"

    row.checkbox:SetChecked(NextTargetDB[enabledKey] ~= false)

    local color = NextTargetDB[colorKey]
    if not color then
        color = addon:GetDefault(colorKey)
        NextTargetDB[colorKey] = color
    end
    updateSwatch(row.colorButton, color)

    local thicknessValue = NextTargetDB[thicknessKey] or addon:GetDefault(thicknessKey) or 1
    row.thickness.isUpdating = true
    row.thickness:SetValue(thicknessValue)
    row.thickness.Text:SetText(string.format("Thickness: %d", thicknessValue))
    row.thickness.isUpdating = false

    local offsetValue = NextTargetDB[offsetKey] or addon:GetDefault(offsetKey) or 0
    row.offset.isUpdating = true
    row.offset:SetValue(offsetValue)
    row.offset.Text:SetText(string.format("Offset: %d", offsetValue))
    row.offset.isUpdating = false

    local styleValue = NextTargetDB[styleKey] or addon:GetDefault(styleKey) or "outline"
    NextTargetDB[styleKey] = styleValue
    UIDropDownMenu_SetSelectedValue(row.dropdown, styleValue)
    UIDropDownMenu_SetText(row.dropdown, styleLabelFor(styleValue))
    
    -- Enable/disable thickness slider based on style
    local isBlizzard = styleValue == "blizzard"
    if isBlizzard then
        row.thickness:Disable()
        row.thickness.Text:SetTextColor(0.5, 0.5, 0.5)
        row.thickness.Low:SetTextColor(0.5, 0.5, 0.5)
        row.thickness.High:SetTextColor(0.5, 0.5, 0.5)
    else
        row.thickness:Enable()
        row.thickness.Text:SetTextColor(1, 1, 1)
        row.thickness.Low:SetTextColor(1, 1, 1)
        row.thickness.High:SetTextColor(1, 1, 1)
    end
end

local function buildPreviewSection()
    if ui.preview.sectionBuilt then
        return
    end
    ui.preview.sectionBuilt = true

    local frame = CreateFrame("Frame", nil, content)
    frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, -22)
    frame:SetSize(150, 65)  -- Increased height for header
    ui.preview.frame = frame

    -- Add "Preview" header
    local previewHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewHeader:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, -2)
    previewHeader:SetText("Preview")

    local borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    borderFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
    borderFrame:SetSize(132, 7)
    borderFrame:SetBackdrop({
        bgFile = WHITE_TEXTURE,
        edgeFile = WHITE_TEXTURE,
        edgeSize = 2,
    })
    borderFrame:SetBackdropColor(0.08, 0.02, 0.02, 1)
    borderFrame:SetBackdropBorderColor(0, 0, 0, 1)

    local healthFill = CreateFrame("StatusBar", nil, borderFrame)
    healthFill:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 2, -1)
    healthFill:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", -2, 1)
    healthFill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    healthFill:SetStatusBarColor(0.78, 0.06, 0.1, 1)
    healthFill:SetMinMaxValues(0, 100)
    healthFill:SetValue(100)

    local background = healthFill:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    background:SetVertexColor(0.25, 0, 0, 0.8)

    ui.preview.outerFrame = borderFrame
    ui.preview.healthBar = healthFill

    ensurePreviewHighlights()
end

local function buildSettingsUI()
    if ui.built then
        return
    end
    ui.built = true

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("next")

    local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetText("Highlights the next enemy target that pressing TAB would select.")

    local enable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    enable:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -14)
    enable.Text:SetText("Enable next")
    enable:SetScript("OnClick", function(self)
        NextTargetDB.enabled = self:GetChecked() and true or false
        if NextTargetDB.enabled then
            accentuate()
        elseif addon.ClearHighlights then
            addon:ClearHighlights()
        end
    end)
    ui.enable = enable

    buildPreviewSection()

    local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 0, -18)
    header:SetText("Highlight Styles")

    for index, option in ipairs(highlightOptions) do
        local row = createHighlightRow(header, option, index)
        bindHighlightRow(option, row)
        ui.highlightRows[option.key] = row
    end

    content:SetHeight(240 + #highlightOptions * 68)  -- Updated for two-line layout
end

panel:SetScript("OnShow", function()
    buildSettingsUI()
    panel.refresh()
end)

function panel.refresh()
    buildSettingsUI()

    ui.enable:SetChecked(NextTargetDB.enabled ~= false)

    for _, option in ipairs(highlightOptions) do
        refreshHighlightRow(option, ui.highlightRows[option.key])
    end

    if ui.preview.frame then
        if ui.preview.activeKey then
            updatePreview(ui.preview.activeKey)
        elseif highlightOptions[1] then
            selectPreviewOption(highlightOptions[1].key)
        end
    end
end

panel.okay = function()
    panel.refresh()
    if NextTargetDB.debugMode then
        addon:ShowDebugFrame()
    else
        addon:HideDebugFrame()
    end
    accentuate()
end

panel.cancel = function()
    panel.refresh()
end

panel.default = function()
    NextTargetDB.enabled = addon:GetDefault("enabled")
    NextTargetDB.debugMode = addon:GetDefault("debugMode")

    for _, option in ipairs(highlightOptions) do
        NextTargetDB[option.key .. "Enabled"] = addon:GetDefault(option.key .. "Enabled")
        NextTargetDB[option.key .. "Color"] = addon:GetDefault(option.key .. "Color")
        NextTargetDB[option.key .. "Thickness"] = addon:GetDefault(option.key .. "Thickness")
        NextTargetDB[option.key .. "Offset"] = addon:GetDefault(option.key .. "Offset")
        NextTargetDB[option.key .. "Style"] = addon:GetDefault(option.key .. "Style")
    end

    panel.refresh()
    if NextTargetDB.debugMode then
        addon:ShowDebugFrame()
    else
        addon:HideDebugFrame()
    end
    accentuate()
end

if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
elseif Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    addon.settingsCategory = category
end

addon.settingsPanel = panel

function addon:OpenSettings()
    if Settings and Settings.OpenToCategory then
        if not self.settingsCategory and self.settingsPanel then
            local category = Settings.RegisterCanvasLayoutCategory(self.settingsPanel, self.settingsPanel.name or "next")
            Settings.RegisterAddOnCategory(category)
            self.settingsCategory = category
        end
        if self.settingsCategory and self.settingsCategory.GetID then
            Settings.OpenToCategory(self.settingsCategory:GetID())
            return
        end
    end

    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
