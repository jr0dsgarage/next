-- Options panel for next
---@diagnostic disable: undefined-global
local addonName, addon = ...

local panel = CreateFrame("Frame")
panel.name = "next"

local scrollFrame = CreateFrame("ScrollFrame", addonName .. "SettingsScrollFrame", panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 3, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", -27, 4)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(620, 560)
scrollFrame:SetScrollChild(content)

local ui = {
    built = false,
    highlightRows = {},
}

local highlightOptions = {
    { key = "currentTarget", label = "Current Target" },
    { key = "questObjective", label = "Quest Objectives" },
    { key = "questItem", label = "Quest Items" },
    { key = "worldQuest", label = "World Quests" },
    { key = "mythicObjective", label = "Mythic Dungeon Objectives" },
}

local highlightStyleChoices = {
    { value = "outline", label = "Outline" },
}

local function styleLabelFor(value)
    for _, choice in ipairs(highlightStyleChoices) do
        if choice.value == value then
            return choice.label
        end
    end
    return value or "Outline"
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
    local rowOffset = -12 - (index - 1) * 56

    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, rowOffset)
    label:SetWidth(140)
    label:SetJustifyH("LEFT")
    label:SetText(option.label)

    local checkbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("LEFT", label, "RIGHT", 2, 0)

    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", checkbox, "RIGHT", -4, -2)
    UIDropDownMenu_SetWidth(dropdown, 120)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")

    local colorButton = CreateFrame("Button", nil, content)
    colorButton:SetPoint("LEFT", dropdown, "RIGHT", 6, 0)
    colorButton:SetSize(26, 26)

    local border = colorButton:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 0.8)

    local swatch = colorButton:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 2, -2)
    swatch:SetPoint("BOTTOMRIGHT", -2, 2)
    colorButton.swatch = swatch

    local thickness = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    thickness:SetPoint("LEFT", colorButton, "RIGHT", 18, 0)
    thickness:SetPoint("CENTER", label, "CENTER", 0, -2)
    thickness:SetMinMaxValues(1, 5)
    thickness:SetValueStep(1)
    thickness:SetObeyStepOnDrag(true)
    thickness:SetWidth(110)
    thickness.Low:SetText("1")
    thickness.High:SetText("5")
    thickness.Text:ClearAllPoints()
    thickness.Text:SetPoint("BOTTOM", thickness, "TOP", 0, 2)
    thickness.Text:SetJustifyH("CENTER")

    local offset = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    offset:SetPoint("LEFT", thickness, "RIGHT", 18, 0)
    offset:SetPoint("CENTER", thickness, "CENTER", 0, 0)
    offset:SetMinMaxValues(0, 5)
    offset:SetValueStep(1)
    offset:SetObeyStepOnDrag(true)
    offset:SetWidth(110)
    offset.Low:SetText("0")
    offset.High:SetText("5")
    offset.Text:ClearAllPoints()
    offset.Text:SetPoint("BOTTOM", offset, "TOP", 0, 2)
    offset.Text:SetJustifyH("CENTER")

    return {
        label = label,
        checkbox = checkbox,
        dropdown = dropdown,
        colorButton = colorButton,
        thickness = thickness,
        offset = offset,
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
    end)

    row.offset:SetScript("OnValueChanged", function(self, value)
        if self.isUpdating then
            return
        end
        local rounded = math.floor(value + 0.5)
        NextTargetDB[offsetKey] = rounded
        self.Text:SetText(string.format("Offset: %d", rounded))
        accentuate()
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
                accentuate()
            end
            info.checked = (current == choice.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
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

    local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 0, -18)
    header:SetText("Highlight Styles")

    for index, option in ipairs(highlightOptions) do
        local row = createHighlightRow(header, option, index)
        bindHighlightRow(option, row)
        ui.highlightRows[option.key] = row
    end

    content:SetHeight(220 + #highlightOptions * 56)
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
