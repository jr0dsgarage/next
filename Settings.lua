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
content:SetSize(600, 800) -- Fixed width and initial height
scrollFrame:SetScrollChild(content)

-- Variables to hold UI elements
local enableCheckbox, combatCheckbox, debugCheckbox
local showCurrentCheck, showPreviousCheck
local currentColorPicker, nextColorPicker, prevColorPicker
local currentThicknessSlider, currentOffsetSlider
local nextThicknessSlider, nextOffsetSlider
local prevThicknessSlider, prevOffsetSlider
local lastElement

-- Function to build the settings UI (called on first show)
local function BuildSettingsUI()
    if panel.isBuilt then return end
    panel.isBuilt = true
    
    print("[next] Building settings UI...") -- Debug output

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

    lastElement = debugCheckbox

-- Helper function to create color picker button
local function CreateColorPicker(label, colorTable, yOffset)
    local colorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, yOffset)
    colorLabel:SetText(label)

    local colorButton = CreateFrame("Button", nil, content)
    colorButton:SetPoint("LEFT", colorLabel, "RIGHT", 8, 0)
    colorButton:SetSize(24, 24)
    
    -- Create border
    local border = colorButton:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    -- Create inner color texture with proper initialization
    local innerTexture = colorButton:CreateTexture(nil, "ARTWORK")
    innerTexture:SetPoint("TOPLEFT", 2, -2)
    innerTexture:SetPoint("BOTTOMRIGHT", -2, 2)
    innerTexture:SetColorTexture(colorTable.r or 1, colorTable.g or 1, colorTable.b or 0)
    colorButton.texture = innerTexture
    
    colorButton:SetScript("OnClick", function()
        local function OnColorChanged()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            colorTable.r = r
            colorTable.g = g
            colorTable.b = b
            innerTexture:SetColorTexture(r, g, b)
            addon:ClearHighlights()
            addon:UpdateHighlight()
        end
        
        ColorPickerFrame:SetColorRGB(colorTable.r, colorTable.g, colorTable.b)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = OnColorChanged
        ColorPickerFrame.opacityFunc = OnColorChanged
        ColorPickerFrame.cancelFunc = function()
            innerTexture:SetColorTexture(colorTable.r, colorTable.g, colorTable.b)
        end
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)
    
    lastElement = colorLabel
    return colorButton
end

-- Helper function to create slider
local function CreateSlider(label, minVal, maxVal, dbKey, yOffset)
    local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 16, yOffset)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(180)
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
    
    lastElement = slider
    return slider
end

-- Helper function to create section header
local function CreateHeader(text, yOffset)
    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", -16, yOffset or -16)
    header:SetText(text)
    lastElement = header
    return header
end

-- Helper function to create checkbox
local function CreateCheckbox(label, dbKey, yOffset)
    local checkbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, yOffset or -4)
    checkbox.Text:SetText(label)
    checkbox.dbKey = dbKey
    
    checkbox:SetScript("OnClick", function(self)
        NextTargetDB[self.dbKey] = self:GetChecked()
        addon:ClearHighlights()
        addon:UpdateHighlight()
    end)
    
    lastElement = checkbox
    return checkbox
end

-- Current Target section
CreateHeader("Current Target", -16)
showCurrentCheck = CreateCheckbox("Show current target border", "showCurrentTarget", -4)
currentColorPicker = CreateColorPicker("Border Color:", NextTargetDB.currentTargetColor, -4)
currentThicknessSlider = CreateSlider("Thickness", 1, 5, "currentBorderThickness", -28)
currentOffsetSlider = CreateSlider("Offset", 0, 5, "currentBorderOffset", -32)

-- Next Target section
CreateHeader("Next Target", -12)
nextColorPicker = CreateColorPicker("Border Color:", NextTargetDB.highlightColor, -4)
nextThicknessSlider = CreateSlider("Thickness", 1, 5, "borderThickness", -28)
nextOffsetSlider = CreateSlider("Offset", 0, 5, "borderOffset", -32)

-- Previous Target section
CreateHeader("Previous Target", -12)
showPreviousCheck = CreateCheckbox("Show previous target border", "showPreviousTarget", -4)
prevColorPicker = CreateColorPicker("Border Color:", NextTargetDB.previousTargetColor, -4)
prevThicknessSlider = CreateSlider("Thickness", 1, 5, "previousBorderThickness", -28)
prevOffsetSlider = CreateSlider("Offset", 0, 5, "previousBorderOffset", -32)

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
-- Calculate height needed based on the last element's position
local totalHeight = 500 -- Reduced height with tighter spacing
content:SetHeight(totalHeight)

print("[next] Settings UI built successfully!") -- Debug output

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
