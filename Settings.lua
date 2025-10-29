-- Settings Panel for next addon

local addonName, addon = ...

-- Create the main settings panel
local panel = CreateFrame("Frame")
panel.name = "next"

-- Create a scroll frame to hold all the settings
local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 3, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", -27, 4)

-- Create the content frame that will hold all the UI elements
local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(620, 600) -- Adjusted width to fit better
scrollFrame:SetScrollChild(content)

-- Variables to hold UI elements
local enableCheckbox, combatCheckbox, debugCheckbox
local showCurrentCheck, showNextCheck, showPreviousCheck
local currentColorPicker, nextColorPicker, prevColorPicker
local currentThicknessSlider, currentOffsetSlider
local nextThicknessSlider, nextOffsetSlider
local prevThicknessSlider, prevOffsetSlider

-- Function to build the settings UI (called on first show)
local function BuildSettingsUI()
    if panel.isBuilt then return end
    panel.isBuilt = true

    -- Title
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("next")

    -- Subtitle
    local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Highlights the next target that would be selected when pressing TAB")

    -- Enable/Disable Checkbox
    enableCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    enableCheckbox.Text:SetText("Enable Addon")

    -- Combat Only Checkbox
    combatCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    combatCheckbox:SetPoint("TOPLEFT", enableCheckbox, "BOTTOMLEFT", 0, -4)
    combatCheckbox.Text:SetText("Only Show in Combat")

    -- Debug Mode Checkbox
    debugCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", combatCheckbox, "BOTTOMLEFT", 0, -4)
    debugCheckbox.Text:SetText("Debug Mode")

-- Helper function to create color picker button
local function CreateColorPicker(parent, anchorPoint, label, colorTable, xOffset, yOffset)
    local colorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", parent, anchorPoint, xOffset, yOffset)
    colorLabel:SetText(label)

    local colorButton = CreateFrame("Button", nil, content)
    colorButton:SetPoint("LEFT", colorLabel, "RIGHT", 8, 0)
    colorButton:SetSize(24, 24)
    
    -- Create border
    local border = colorButton:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    -- Create inner color texture
    local innerTexture = colorButton:CreateTexture(nil, "ARTWORK")
    innerTexture:SetPoint("TOPLEFT", 2, -2)
    innerTexture:SetPoint("BOTTOMRIGHT", -2, 2)
    innerTexture:SetColorTexture(colorTable.r or 1, colorTable.g or 1, colorTable.b or 0, colorTable.a or 1)
    colorButton.texture = innerTexture
    
    colorButton:SetScript("OnClick", function()
        if _G.ColorPickerFrame and _G.ColorPickerFrame.SetupColorPickerAndShow then
            _G.ColorPickerFrame:SetupColorPickerAndShow({
                r = colorTable.r,
                g = colorTable.g,
                b = colorTable.b,
                opacity = colorTable.a,
                hasOpacity = true,
                swatchFunc = function()
                    local r, g, b = _G.ColorPickerFrame:GetColorRGB()
                    local a = _G.ColorPickerFrame:GetColorAlpha()
                    colorTable.r = r
                    colorTable.g = g
                    colorTable.b = b
                    colorTable.a = a
                    innerTexture:SetColorTexture(r, g, b, a)
                    addon:ClearHighlights()
                    addon:UpdateHighlight()
                end,
                opacityFunc = function()
                    local r, g, b = _G.ColorPickerFrame:GetColorRGB()
                    local a = _G.ColorPickerFrame:GetColorAlpha()
                    colorTable.r = r
                    colorTable.g = g
                    colorTable.b = b
                    colorTable.a = a
                    innerTexture:SetColorTexture(r, g, b, a)
                    addon:ClearHighlights()
                    addon:UpdateHighlight()
                end,
                cancelFunc = function()
                    local prev = _G.ColorPickerFrame.previousValues
                    colorTable.r = prev.r
                    colorTable.g = prev.g
                    colorTable.b = prev.b
                    colorTable.a = prev.opacity or 1
                    innerTexture:SetColorTexture(prev.r, prev.g, prev.b, prev.opacity or 1)
                    addon:ClearHighlights()
                    addon:UpdateHighlight()
                end,
            })
        end
    end)
    
    return colorButton, colorLabel
end

-- Helper function to create slider
local function CreateSlider(parent, anchorPoint, label, minVal, maxVal, dbKey, xOffset, yOffset)
    local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, anchorPoint, xOffset, yOffset)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(160)
    slider.Low:SetText(tostring(minVal))
    slider.High:SetText(tostring(maxVal))
    slider.Text:SetText(label .. ": " .. (NextTargetDB[dbKey] or minVal))
    slider.dbKey = dbKey
    
    slider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value + 0.5)
        NextTargetDB[self.dbKey] = val
        self.Text:SetText(label .. ": " .. val)
        addon:ClearHighlights()
        addon:UpdateHighlight()
    end)
    
    return slider
end

-- Helper function to create section header
local function CreateHeader(parent, anchorPoint, text, xOffset, yOffset)
    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, anchorPoint, xOffset, yOffset)
    header:SetText(text)
    return header
end

-- Helper function to create checkbox
local function CreateCheckbox(parent, anchorPoint, label, dbKey, xOffset, yOffset)
    local checkbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, anchorPoint, xOffset, yOffset)
    checkbox.Text:SetText(label)
    checkbox.dbKey = dbKey
    
    checkbox:SetScript("OnClick", function(self)
        NextTargetDB[self.dbKey] = self:GetChecked()
        addon:ClearHighlights()
        addon:UpdateHighlight()
    end)
    
    return checkbox
end

-- Column starting Y position
local columnStartY = -120

-- Helper function to create column background
local function CreateColumnBG(parent, xOffset, width, height)
    local bg = content:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", xOffset, columnStartY + 20)
    bg:SetSize(width, height)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
    
    -- Create border
    local border = CreateFrame("Frame", nil, content, "BackdropTemplate")
    border:SetPoint("TOPLEFT", bg, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    border:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    return bg
end

-- Create column backgrounds
CreateColumnBG(subtitle, 0, 190, 260)
CreateColumnBG(subtitle, 200, 190, 260)
CreateColumnBG(subtitle, 400, 190, 260)

-- CURRENT TARGET COLUMN (Left)
local currentHeader = CreateHeader(subtitle, "BOTTOMLEFT", "Current Target", 8, columnStartY)
showCurrentCheck = CreateCheckbox(currentHeader, "BOTTOMLEFT", "Show current target border", "showCurrentTarget", 0, -8)
local currentColorLabel
currentColorPicker, currentColorLabel = CreateColorPicker(showCurrentCheck, "BOTTOMLEFT", "Border Color:", NextTargetDB.currentTargetColor, 0, -8)
currentThicknessSlider = CreateSlider(currentColorLabel, "BOTTOMLEFT", "Thickness", 1, 5, "currentBorderThickness", 0, -32)
currentOffsetSlider = CreateSlider(currentThicknessSlider, "BOTTOMLEFT", "Offset", 0, 5, "currentBorderOffset", 0, -36)

-- NEXT TARGET COLUMN (Center)
local nextHeader = CreateHeader(subtitle, "BOTTOMLEFT", "Next Target", 208, columnStartY)
showNextCheck = CreateCheckbox(nextHeader, "BOTTOMLEFT", "Show next target border", "showNextTarget", 0, -8)
local nextColorLabel
nextColorPicker, nextColorLabel = CreateColorPicker(showNextCheck, "BOTTOMLEFT", "Border Color:", NextTargetDB.highlightColor, 0, -8)
nextThicknessSlider = CreateSlider(nextColorLabel, "BOTTOMLEFT", "Thickness", 1, 5, "borderThickness", 0, -32)
nextOffsetSlider = CreateSlider(nextThicknessSlider, "BOTTOMLEFT", "Offset", 0, 5, "borderOffset", 0, -36)

-- PREVIOUS TARGET COLUMN (Right)
local prevHeader = CreateHeader(subtitle, "BOTTOMLEFT", "Previous Target", 408, columnStartY)
showPreviousCheck = CreateCheckbox(prevHeader, "BOTTOMLEFT", "Show last targeted enemy", "showPreviousTarget", 0, -8)
local prevColorLabel
prevColorPicker, prevColorLabel = CreateColorPicker(showPreviousCheck, "BOTTOMLEFT", "Border Color:", NextTargetDB.previousTargetColor, 0, -8)
prevThicknessSlider = CreateSlider(prevColorLabel, "BOTTOMLEFT", "Thickness", 1, 5, "previousBorderThickness", 0, -32)
prevOffsetSlider = CreateSlider(prevThicknessSlider, "BOTTOMLEFT", "Offset", 0, 5, "previousBorderOffset", 0, -36)

-- Checkbox scripts
enableCheckbox:SetScript("OnClick", function(self)
    NextTargetDB.enabled = self:GetChecked()
    if NextTargetDB.enabled then
        addon:UpdateHighlight()
    else
        addon:ClearHighlights()
    end
end)

combatCheckbox:SetScript("OnClick", function(self)
    NextTargetDB.onlyInCombat = self:GetChecked()
    addon:UpdateHighlight()
end)

debugCheckbox:SetScript("OnClick", function(self)
    NextTargetDB.debugMode = self:GetChecked()
    if NextTargetDB.debugMode then
        addon:ShowDebugFrame()
        addon:UpdateHighlight()
    else
        addon:HideDebugFrame()
    end
end)

    -- Set content height to accommodate all elements
    content:SetHeight(450)

end -- End of BuildSettingsUI function

-- Call BuildSettingsUI when panel is first shown
panel:SetScript("OnShow", function(self)
    BuildSettingsUI()
    if panel.refresh then
        panel.refresh()
    end
end)

-- Panel refresh function (called when opening)
panel.refresh = function()
    BuildSettingsUI() -- Ensure UI is built before refreshing
    
    enableCheckbox:SetChecked(NextTargetDB.enabled)
    combatCheckbox:SetChecked(NextTargetDB.onlyInCombat)
    debugCheckbox:SetChecked(NextTargetDB.debugMode)
    showCurrentCheck:SetChecked(NextTargetDB.showCurrentTarget)
    showNextCheck:SetChecked(NextTargetDB.showNextTarget)
    showPreviousCheck:SetChecked(NextTargetDB.showPreviousTarget)
    
    -- Update sliders
    currentThicknessSlider:SetValue(NextTargetDB.currentBorderThickness or 2)
    currentOffsetSlider:SetValue(NextTargetDB.currentBorderOffset or 1)
    nextThicknessSlider:SetValue(NextTargetDB.borderThickness or 2)
    nextOffsetSlider:SetValue(NextTargetDB.borderOffset or 1)
    prevThicknessSlider:SetValue(NextTargetDB.previousBorderThickness or 2)
    prevOffsetSlider:SetValue(NextTargetDB.previousBorderOffset or 1)
    
    -- Update color pickers
    currentColorPicker.texture:SetColorTexture(NextTargetDB.currentTargetColor.r, NextTargetDB.currentTargetColor.g, NextTargetDB.currentTargetColor.b)
    nextColorPicker.texture:SetColorTexture(NextTargetDB.highlightColor.r, NextTargetDB.highlightColor.g, NextTargetDB.highlightColor.b)
    prevColorPicker.texture:SetColorTexture(NextTargetDB.previousTargetColor.r, NextTargetDB.previousTargetColor.g, NextTargetDB.previousTargetColor.b)
end

-- Panel okay function (called when clicking OK)
panel.okay = function()
    -- Settings are already saved via OnClick/OnValueChanged handlers
    if NextTargetDB.debugMode then
        addon:ShowDebugFrame()
    else
        addon:HideDebugFrame()
    end
    
    addon:ClearHighlights()
    addon:UpdateHighlight()
end

-- Panel cancel function (called when clicking Cancel)
panel.cancel = function()
    -- Revert to saved settings
    panel.refresh()
end

-- Panel default function (called when clicking Defaults)
panel.default = function()
    enableCheckbox:SetChecked(true)
    combatCheckbox:SetChecked(false)
    debugCheckbox:SetChecked(false)
    showCurrentCheck:SetChecked(true)
    showNextCheck:SetChecked(true)
    showPreviousCheck:SetChecked(true)
    
    currentThicknessSlider:SetValue(2)
    currentOffsetSlider:SetValue(1)
    nextThicknessSlider:SetValue(2)
    nextOffsetSlider:SetValue(1)
    prevThicknessSlider:SetValue(2)
    prevOffsetSlider:SetValue(1)
    
    -- Reset colors to defaults
    NextTargetDB.currentTargetColor = {r = 0, g = 1, b = 0, a = 0.8}
    NextTargetDB.highlightColor = {r = 1, g = 1, b = 0, a = 0.8}
    NextTargetDB.previousTargetColor = {r = 0, g = 0.7, b = 1, a = 0.8}
    
    currentColorPicker.texture:SetColorTexture(0, 1, 0)
    nextColorPicker.texture:SetColorTexture(1, 1, 0)
    prevColorPicker.texture:SetColorTexture(0, 0.7, 1)
end

-- Register the panel with WoW's interface options
-- This works for both modern and legacy WoW versions
if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
elseif Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    addon.settingsCategory = category
end

-- Store panel reference in addon table
addon.settingsPanel = panel

-- Function to open settings panel
function addon:OpenSettings()
    if Settings and Settings.OpenToCategory and self.settingsCategory then
        Settings.OpenToCategory(self.settingsCategory)
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Open the options to the specific panel
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
        -- Call twice to work around Blizzard bug where it doesn't navigate on first call
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
    else
        -- Fallback: just open the interface options
        if SettingsPanel then
            SettingsPanel:Open()
        end
    end
end
