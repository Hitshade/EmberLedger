local addonName, EL = ...

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local THEME = EL.THEME_COLORS or {}

local function T(key, ...)
    if EL and EL.T then return EL:T(key, ...) end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, tostring(key), ...)
        if ok then return formatted end
    end
    return tostring(key)
end

local ThemeColor, ThemeAccentRGB, ThemeBorderRGB, ThemeTextRGB, ThemeMutedTextRGB, ThemeValueTextRGB, RegisterThemeText, ApplyThemeTextCollections

local VALID_FRAME_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function SanitizeFramePoint(point, fallback)
    point = tostring(point or "")
    return VALID_FRAME_POINTS[point] and point or fallback or "CENTER"
end

local function SafeSetFramePoint(frame, point, relativeTo, relativePoint, x, y)
    if not frame then return false end
    point = SanitizeFramePoint(point, "CENTER")
    relativePoint = SanitizeFramePoint(relativePoint, point)
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo or UIParent, relativePoint, x, y)
    return true
end

local function SetFramePointFromDB(frame, pos)
    pos = type(pos) == "table" and pos or {}
    SafeSetFramePoint(frame, pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end

local function SaveFramePoint(frame, pos)
    if not frame or type(pos) ~= "table" then return end
    local point, _, relativePoint, x, y = frame:GetPoint()
    pos.point = point or "CENTER"
    pos.relativePoint = relativePoint or "CENTER"
    pos.x = x or 0
    pos.y = y or 0
end

local function AddBackdrop(frame, alpha, borderAlpha)
    return EL.Style:AddBackdrop(frame, alpha, borderAlpha)
end

local function AddHeaderAccent(frame)
    return EL.Style:AddHeaderAccent(frame)
end

local function AddInnerBorder(frame)
    return EL.Style:AddInnerBorder(frame)
end

local function AddEmberLogo(parent, size, layer)
    if EL.Style and EL.Style.AddEmberLogo then return EL.Style:AddEmberLogo(parent, size, layer) end
    if not parent then return nil end
    local tex = parent:CreateTexture(nil, layer or "ARTWORK")
    tex:SetSize(size or 32, size or 32)
    tex:SetTexture((EL and EL.LOGO_TEXTURE) or "Interface\\Icons\\INV_Misc_Book_11")
    return tex
end

local function AddEmberLogoBadge(parent, size, layer)
    if EL.Style and EL.Style.AddEmberLogoBadge then return EL.Style:AddEmberLogoBadge(parent, size, layer) end
    return AddEmberLogo(parent, size, layer)
end

local function AddEmberCornerAccents(frame)
    if EL.Style and EL.Style.AddEmberCornerAccents then return EL.Style:AddEmberCornerAccents(frame) end
end

local function GetPanelOpacity()
    local db = EL and EL.db
    local value = db and db.settings and db.settings.display and db.settings.display.panelOpacity
    return math.max(0.20, math.min(1.00, tonumber(value) or 0.55))
end

local function GetLauncherOpacity()
    local db = EL and EL.db
    local value = db and db.settings and db.settings.display and db.settings.display.launcherOpacity
    return math.max(0.20, math.min(1.00, tonumber(value) or 0.50))
end

local function StyleBlizzardButton(button)
    return EL.Style:StyleBlizzardButton(button)
end

-- Options Panel Helpers
--
-- Reusable controls and helpers used by EmberLedger's configuration panel.
-- Keep these helpers behavior-stable; several reset, visibility, and live
-- refresh flows rely on the same small helper set.
-- ============================================================================

local function MakeSettingsButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 58, 22)
    b:SetText(text)
    b.text = b:GetFontString()
    if b.text then
        b.text:SetPoint("CENTER")
        b.text:SetText(text)
    end
    StyleBlizzardButton(b)
    b:SetScript("OnClick", onClick)
    return b
end


local settingsDropdownCounter = 0
local function MakeSettingsDropdown(parent, width, options, getValue, setValue)
    settingsDropdownCounter = settingsDropdownCounter + 1
    local name = "EmberLedgerSettingsDropdown" .. tostring(settingsDropdownCounter)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd.options = options or {}
    dd.getValue = getValue
    dd.setValue = setValue

    local function getLabel(value)
        for _, opt in ipairs(dd.options) do
            if opt.value == value then return opt.label end
        end
        return dd.options[1] and dd.options[1].label or ""
    end

    function dd:RefreshSelection()
        local value = self.getValue and self.getValue() or (self.options[1] and self.options[1].value)
        if UIDropDownMenu_SetSelectedValue then UIDropDownMenu_SetSelectedValue(self, value) end
        if UIDropDownMenu_SetText then UIDropDownMenu_SetText(self, getLabel(value)) end
    end

    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dd, width or 190) end
    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(dd, function(self, level)
            local selected = self.getValue and self.getValue() or (self.options[1] and self.options[1].value)
            for _, opt in ipairs(self.options) do
                local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
                info.text = opt.label
                info.value = opt.value
                info.checked = selected == opt.value
                info.func = function()
                    if self.setValue then self.setValue(opt.value) end
                    if CloseDropDownMenus then CloseDropDownMenus() end
                    if self.RefreshSelection then self:RefreshSelection() end
                end
                if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info, level) end
            end
        end)
    end
    dd:RefreshSelection()
    return dd
end


local cooldownMultiDropdownCounter = 0
local function MakeCooldownVisibilityDropdown(parent, width)
    cooldownMultiDropdownCounter = cooldownMultiDropdownCounter + 1
    local name = "EmberLedgerCooldownVisibilityDropdown" .. tostring(cooldownMultiDropdownCounter)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetSize(width or 220, 24)

    local function GetVisibleDefinitions()
        if EL.GetProfessionCooldownVisibilityDefinitions then
            return EL:GetProfessionCooldownVisibilityDefinitions() or {}
        end
        return {}
    end

    local function GetSelectionSummary()
        local total, shown = 0, 0
        for _, def in ipairs(GetVisibleDefinitions()) do
            if def and def.key then
                total = total + 1
                if not (EL.IsProfessionCooldownHidden and EL:IsProfessionCooldownHidden(def.key)) then
                    shown = shown + 1
                end
            end
        end
        if total <= 0 then return "No cooldowns in scope" end
        if shown == total then return "All cooldowns tracked" end
        if shown <= 0 then return "None" end
        return "Custom"
    end

    function dd:RefreshSelection()
        -- This dropdown is a multi-select checklist, so do not let the
        -- Blizzard dropdown template keep the last clicked item as the
        -- selected display text.
        self.selectedID = nil
        self.selectedValue = nil
        self.selectedName = nil
        if UIDropDownMenu_SetText then UIDropDownMenu_SetText(self, GetSelectionSummary()) end
        if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(self, width or 220) end
    end

    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dd, width or 220) end
    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(dd, function(self, level)
            local defsByCategory = {}
            local order = {}
            for _, def in ipairs(GetVisibleDefinitions()) do
                if def and def.key then
                    local category = tostring(def.category or def.professionName or "Profession")
                    if not defsByCategory[category] then
                        defsByCategory[category] = {}
                        order[#order + 1] = category
                    end
                    defsByCategory[category][#defsByCategory[category] + 1] = def
                end
            end

            if #order == 0 then
                local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
                info.text = "No cooldowns in this scope"
                info.notCheckable = true
                info.disabled = true
                if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info, level) end
                return
            end

            for groupIndex, category in ipairs(order) do
                local title = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
                title.text = category
                title.notCheckable = true
                title.disabled = true
                if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(title, level) end

                for _, def in ipairs(defsByCategory[category] or {}) do
                    local key = def.key
                    local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
                    info.text = def.label or def.shortLabel or key
                    info.arg1 = key
                    info.keepShownOnClick = true
                    info.isNotRadio = true
                    info.checked = function()
                        return not (EL.IsProfessionCooldownHidden and EL:IsProfessionCooldownHidden(key))
                    end
                    info.func = function(_, clickedKey)
                        clickedKey = clickedKey or key
                        if clickedKey and EL.SetProfessionCooldownHidden then
                            local currentlyHidden = EL.IsProfessionCooldownHidden and EL:IsProfessionCooldownHidden(clickedKey)
                            EL:SetProfessionCooldownHidden(clickedKey, not currentlyHidden)
                        end
                        if dd.RefreshSelection then dd:RefreshSelection() end
                        if UIDropDownMenu_Refresh then UIDropDownMenu_Refresh(dd, nil, 1) end
                        if C_Timer and C_Timer.After then
                            C_Timer.After(0, function()
                                if dd and dd.RefreshSelection then dd:RefreshSelection() end
                            end)
                        end
                    end
                    if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info, level) end
                end

                if groupIndex < #order then
                    local spacer = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
                    spacer.text = " "
                    spacer.notCheckable = true
                    spacer.disabled = true
                    if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(spacer, level) end
                end
            end
        end)
    end
    dd:RefreshSelection()
    return dd
end

local function ShowSettingsConfirm(text, acceptText, onAccept, popupKey, requireDialog)
    if not onAccept then return end
    local key = popupKey or "EMBERLEDGER_CONFIRM_ACTION"
    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs[key] = {
            text = text or "Are you sure?",
            button1 = acceptText or YES,
            button2 = CANCEL,
            OnAccept = function() onAccept() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show(key)
    elseif requireDialog then
        if EL and EL.Print then EL:Print(T("Confirmation dialog unavailable. No data was removed.")) end
    else
        onAccept()
    end
end

function EL:ConfirmResetWindowPositions()
    ShowSettingsConfirm(T("Reset all EmberLedger window positions? Scale and visibility settings will be kept."), T("Reset"), function()
        if EL.ResetWindowPositions then EL:ResetWindowPositions() end
    end)
end

function EL:ConfirmResetUISettings()
    ShowSettingsConfirm(T("Reset EmberLedger UI settings and window positions to default? Tracked characters, profession data, cooldowns, mulch data, session history, hidden characters, and pinned characters will not be deleted."), T("Reset UI"), function()
        if EL.ResetUISettingsToDefaults then EL:ResetUISettingsToDefaults() end
    end, "EMBERLEDGER_CONFIRM_RESET_UI_SETTINGS", true)
end

function EL:ConfirmResetSession()
    ShowSettingsConfirm(T("Reset the current session totals and tracked item list?"), T("Reset"), function()
        if EL.ResetSession then EL:ResetSession() end
    end)
end

function EL:ConfirmResetSessionHistory()
    ShowSettingsConfirm(T("Clear all saved account-wide session history? This cannot be undone."), T("Clear History"), function()
        if EL.ResetSessionHistory then EL:ResetSessionHistory() end
    end)
end

function EL:ConfirmResetLifetimeSessionStats()
    ShowSettingsConfirm(T("Reset EmberLedger lifetime session stats? This cannot be undone. Session history will not be deleted."), T("Reset Lifetime"), function()
        if EL.ResetLifetimeSessionStats then EL:ResetLifetimeSessionStats() end
    end)
end

function EL:ConfirmRestoreHiddenCharacters()
    ShowSettingsConfirm(T("Unhide all hidden characters and return them to the main window table?"), T("Unhide All"), function()
        if EL.RestoreHiddenCharacters then EL:RestoreHiddenCharacters() end
    end)
end

function EL:ConfirmRemoveHiddenCharacterData()
    ShowSettingsConfirm(T("Remove tracked EmberLedger character data for currently hidden characters? Account-wide session history is kept. This cannot be undone."), T("Remove Data"), function()
        if EL.RemoveHiddenCharacterData then EL:RemoveHiddenCharacterData() end
    end, "EMBERLEDGER_CONFIRM_REMOVE_HIDDEN_DATA", true)
end

function EL:ConfirmRemoveCharacterData(charKey, displayName)
    if not charKey then return end
    ShowSettingsConfirm(T("Remove tracked EmberLedger character data for %s? Account-wide session history is kept. This cannot be undone.", tostring(displayName or charKey)), T("Remove Data"), function()
        if EL.ResetCharacterData then EL:ResetCharacterData(charKey) end
    end, "EMBERLEDGER_CONFIRM_REMOVE_CHARACTER_DATA", true)
end

function EL:ConfirmResetPinnedCharacters()
    ShowSettingsConfirm(T("Remove all pinned character markers? Character data will not be deleted."), T("Reset"), function()
        if EL.ResetPinnedCharacters then EL:ResetPinnedCharacters() end
    end)
end

local function MakeSettingsCheck(parent, text, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb.Text:SetText(text)
    local tr, tg, tb = ThemeTextRGB()
    cb.Text:SetTextColor(tr, tg, tb)
    cb.Text:SetFontObject(GameFontHighlightSmall)
    RegisterThemeText(cb.Text, "themeTextWidgets")
    cb:SetScript("OnClick", onClick)
    cb.text = cb.Text
    return cb
end

local function SetSettingsTooltip(widget, title, lines)
    if not widget then return end
    widget:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ar, ag, ab = ThemeAccentRGB()
        GameTooltip:SetText(title or "EmberLedger", ar, ag, ab)
        if lines then
            for _, line in ipairs(lines) do
                local mr, mg, mb = ThemeMutedTextRGB()
                GameTooltip:AddLine(line, mr, mg, mb, true)
            end
        end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end


local function BringEmberWindowToFront(frame)
    if EL and EL.Style and EL.Style.BringWindowToFront then
        return EL.Style:BringWindowToFront(frame)
    end
end

local function HideSessionHistoryDisplayDropdown()
    if EL and EL.Style and EL.Style.HideSessionHistoryDisplayDropdown then
        return EL.Style:HideSessionHistoryDisplayDropdown()
    end
end

local function ShowSessionHistoryDisplayDropdown(anchor)
    if EL and EL.Style and EL.Style.ShowSessionHistoryDisplayDropdown then
        return EL.Style:ShowSessionHistoryDisplayDropdown(anchor)
    end
end

ThemeColor = function(key, fallback)
    if EL and EL.Style and EL.Style.ThemeColor then return EL.Style:ThemeColor(key, fallback) end
    local colors = EL and EL.THEME_COLORS or THEME or {}
    return tonumber(colors[key]) or fallback
end

ThemeAccentRGB = function()
    if EL and EL.Style and EL.Style.ThemeAccentRGB then return EL.Style:ThemeAccentRGB() end
    return ThemeColor("ACCENT_R", 0.68), ThemeColor("ACCENT_G", 0.68), ThemeColor("ACCENT_B", 0.70)
end

ThemeBorderRGB = function()
    if EL and EL.Style and EL.Style.ThemeBorderRGB then return EL.Style:ThemeBorderRGB() end
    return ThemeColor("BORDER_R", 0.42), ThemeColor("BORDER_G", 0.42), ThemeColor("BORDER_B", 0.44)
end

ThemeTextRGB = function()
    if EL and EL.Style and EL.Style.ThemeTextRGB then return EL.Style:ThemeTextRGB() end
    return ThemeColor("TEXT_R", 0.88), ThemeColor("TEXT_G", 0.89), ThemeColor("TEXT_B", 0.91)
end

ThemeMutedTextRGB = function()
    if EL and EL.Style and EL.Style.ThemeMutedTextRGB then return EL.Style:ThemeMutedTextRGB() end
    return ThemeColor("MUTED_TEXT_R", 0.76), ThemeColor("MUTED_TEXT_G", 0.77), ThemeColor("MUTED_TEXT_B", 0.80)
end

ThemeValueTextRGB = function()
    if EL and EL.Style and EL.Style.ThemeValueTextRGB then return EL.Style:ThemeValueTextRGB() end
    return ThemeColor("VALUE_TEXT_R", 0.90), ThemeColor("VALUE_TEXT_G", 0.91), ThemeColor("VALUE_TEXT_B", 0.93)
end

RegisterThemeText = function(fontString, bucket)
    if EL and EL.Style and EL.Style.RegisterThemeText then return EL.Style:RegisterThemeText(fontString, bucket) end
end

ApplyThemeTextCollections = function(frame)
    if EL and EL.Style and EL.Style.ApplyThemeTextCollections then return EL.Style:ApplyThemeTextCollections(frame) end
end

local function MakeSettingsSlider(parent, labelText, minValue, maxValue, step, valueFormatter, onValueChanged)
    local box = CreateFrame("Frame", nil, parent)
    local parentWidth = (parent and parent.GetWidth and parent:GetWidth()) or 476
    box:SetSize(math.max(320, parentWidth - 32), 32)

    -- Keep slider rows inline so labels, controls, and values read as one row
    -- and never spill below their shaded section. The min/max numbers are
    -- intentionally hidden to reduce clutter; the value label carries the
    -- useful information.
    box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.label:SetPoint("LEFT", box, "LEFT", 0, 0)
    box.label:SetWidth(156)
    box.label:SetJustifyH("LEFT")
    box.label:SetText(labelText)
    local tr, tg, tb = ThemeTextRGB()
    box.label:SetTextColor(tr, tg, tb)
    RegisterThemeText(box.label, "themeTextWidgets")

    box.value = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    box.value:SetPoint("RIGHT", box, "RIGHT", 0, 0)
    box.value:SetWidth(52)
    local vr, vg, vb = ThemeValueTextRGB()
    box.value:SetTextColor(vr, vg, vb)
    RegisterThemeText(box.value, "themeValueTextWidgets")
    box.value:SetJustifyH("RIGHT")

    local slider = CreateFrame("Slider", nil, box, "OptionsSliderTemplate")
    slider:SetPoint("LEFT", box.label, "RIGHT", 10, 0)
    slider:SetPoint("RIGHT", box.value, "LEFT", -10, 0)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    if slider.Text then slider.Text:SetText("") end
    if slider.Low then slider.Low:SetText("") end
    if slider.High then slider.High:SetText("") end

    box.slider = slider
    box.formatter = valueFormatter
    box.setting = true
    slider:SetScript("OnValueChanged", function(self, value, userInput)
        if box.suppress then return end
        if step and step > 0 then
            value = math.floor((value / step) + 0.5) * step
        end
        if box.formatter then box.value:SetText(box.formatter(value)) end
        if onValueChanged then onValueChanged(value) end
    end)
    return box
end

local function SetSliderValue(box, value)
    if not box or not box.slider then return end
    box.suppress = true
    box.slider:SetValue(value)
    box.suppress = false
    if box.formatter then box.value:SetText(box.formatter(value)) end
end


local function ApplySettingsSectionTheme(section)
    if not section then return end
    AddBackdrop(section, math.max(0.24, GetPanelOpacity() - 0.08), 0.42)
    local bgR, bgG, bgB = ThemeColor("BG_R", 0.020), ThemeColor("BG_G", 0.016), ThemeColor("BG_B", 0.040)
    local accentR, accentG, accentB = ThemeAccentRGB()
    if section.SetBackdropColor then section:SetBackdropColor(bgR, bgG, bgB, math.max(0.56, GetPanelOpacity())) end
    if section.SetBackdropBorderColor then
        local borderR, borderG, borderB = ThemeBorderRGB()
        section:SetBackdropBorderColor(borderR, borderG, borderB, 0.42)
    end
    if section.sideAccent then section.sideAccent:SetColorTexture(accentR, accentG, accentB, 0.28) end
    if section.title then section.title:SetTextColor(accentR, accentG, accentB) end
    if section.line then section.line:SetColorTexture(accentR, accentG, accentB, 0.18) end
    if section.accentTop then section.accentTop:SetColorTexture(accentR, accentG, accentB, 0.34) end
end

local function MakeSettingsSection(parent, title, x, y, w, h)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    section:SetSize(w, h)
    AddBackdrop(section, math.max(0.24, GetPanelOpacity() - 0.08), 0.42)
    AddHeaderAccent(section)
    section.sideAccent = section:CreateTexture(nil, "ARTWORK")
    section.sideAccent:SetWidth(2)
    section.sideAccent:SetPoint("TOPLEFT", section, "TOPLEFT", 5, -8)
    section.sideAccent:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", 5, 8)
    section.title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    section.title:SetPoint("TOPLEFT", 14, -9)
    section.title:SetText(title)
    section.line = section:CreateTexture(nil, "BORDER")
    section.line:SetHeight(1)
    section.line:SetPoint("TOPLEFT", 14, -28)
    section.line:SetPoint("TOPRIGHT", -14, -28)
    ApplySettingsSectionTheme(section)
    return section
end


-- ============================================================================
-- Options Panel Construction
--
-- EL:CreateSettingsPanel owns the full options window build, navigation pages,
-- controls, reset buttons, and wiring for live option updates.
-- ============================================================================

function EL:CreateSettingsPanel(parent)
    if self.settingsPanel then
        self.settingsPanel:SetParent(UIParent)
        self.settingsPanel:SetScale(1)
        return self.settingsPanel
    end
    -- Keep the Options panel parented to UIParent so Main window scale changes do not affect it.
    local f = CreateFrame("Frame", "EmberLedgerSettingsPanel", UIParent, "BackdropTemplate")
    self.settingsPanel = f
    if type(UISpecialFrames) == "table" and not f._emberLedgerEscRegistered then
        local registered = false
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == "EmberLedgerSettingsPanel" then
                registered = true
                break
            end
        end
        if not registered then
            table.insert(UISpecialFrames, "EmberLedgerSettingsPanel")
        end
        f._emberLedgerEscRegistered = true
    end
    f:SetSize(660, 760) -- v1.31.6 options layout height pass
    f:SetScale(1)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    AddBackdrop(f, GetPanelOpacity(), 0.72)
    if f.SetBackdropColor then f:SetBackdropColor(0.014, 0.010, 0.030, GetPanelOpacity()) end
    AddInnerBorder(f)
    AddEmberCornerAccents(f)
    self.db.settings.options = self.db.settings.options or {}
    if self.db.settings.options.point then
        SetFramePointFromDB(f, self.db.settings.options)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    f:SetScript("OnMouseDown", function(self)
        BringEmberWindowToFront(self)
    end)
    f:SetScript("OnDragStart", function(self) if not (EL.db.settings.lockWindows == true) or IsShiftKeyDown() then BringEmberWindowToFront(self); self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        EL.db.settings.options = EL.db.settings.options or {}
        SaveFramePoint(self, EL.db.settings.options)
    end)
    f:Hide()

    f.headerPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.headerPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    f.headerPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    f.headerPanel:SetHeight(48)
    AddBackdrop(f.headerPanel, 0.96, 0.58)
    if f.headerPanel.SetBackdropColor then f.headerPanel:SetBackdropColor(0.006, 0.007, 0.010, 0.96) end
    if f.headerPanel.SetBackdropBorderColor then
        local borderR, borderG, borderB = ThemeBorderRGB()
        f.headerPanel:SetBackdropBorderColor(borderR, borderG, borderB, 0.58)
    end
    AddHeaderAccent(f.headerPanel)

    f.headerGlow = f.headerPanel:CreateTexture(nil, "BACKGROUND")
    f.headerGlow:SetPoint("TOPLEFT", f.headerPanel, "TOPLEFT", 6, -5)
    f.headerGlow:SetPoint("BOTTOMRIGHT", f.headerPanel, "BOTTOMRIGHT", -6, 5)
    local headerGlowR, headerGlowG, headerGlowB = ThemeAccentRGB()
    f.headerGlow:SetColorTexture(headerGlowR, headerGlowG, headerGlowB, 0.040)

    f.logo = AddEmberLogoBadge(f.headerPanel, 38, "ARTWORK")
    if f.logo then f.logo:SetPoint("LEFT", f.headerPanel, "LEFT", 10, 0) end

    f.title = f.headerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f.headerPanel, "TOPLEFT", 58, -9)
    f.title:SetText(T("EmberLedger Options"))
    f.title:SetTextColor(ThemeAccentRGB())

    f.subtitle = f.headerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
    f.subtitle:SetText(T("Configure profession tracking, cooldowns, sessions, and display polish."))
    f.subtitle:SetTextColor(0.84, 0.78, 0.66)

    f.close = CreateFrame("Button", nil, f.headerPanel, "UIPanelCloseButton")
    f.close:SetSize(24, 24)
    f.close:SetPoint("RIGHT", f.headerPanel, "RIGHT", -6, 0)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.close:SetFrameLevel(((f.headerPanel.GetFrameLevel and f.headerPanel:GetFrameLevel()) or 1) + 5)

    f.nav = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.nav:SetPoint("TOPLEFT", 14, -58)
    f.nav:SetSize(140, 674)
    AddBackdrop(f.nav, 0.42, 0.48)
    if f.nav.SetBackdropColor then f.nav:SetBackdropColor(0.012, 0.010, 0.026, 0.78) end
    AddInnerBorder(f.nav)

    local navItems = {
        {"General", "Interface\\Icons\\INV_Misc_Gear_01"},
        {"Modules", "Interface\\Icons\\INV_Misc_EngGizmos_30"},
        {"Launcher", "Interface\\Icons\\INV_Misc_Rune_01"},
        {"Session", "Interface\\Icons\\INV_Misc_Coin_01"},
        {"Main Window", "Interface\\Icons\\INV_Inscription_Tradeskill01"},
        {"Thresholds", "Interface\\Icons\\Ability_Mage_BrainFreeze"},
        {"Action Bar", "Interface\\Icons\\INV_Misc_EngGizmos_17"},
        {"Maintenance", "Interface\\Icons\\Trade_Engineering"},
    }
    f.navLabels = {}
    local ny = -14
    f.navByName = {}
    for i, data in ipairs(navItems) do
        local row = CreateFrame("Button", nil, f.nav, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 8, ny)
        row:SetSize(124, 32)
        AddBackdrop(row, 0.16, 0.16)
        if row.SetBackdropColor then row:SetBackdropColor(0.02, 0.018, 0.030, 0.20) end
        if row.SetBackdropBorderColor then row:SetBackdropBorderColor(0.70, 0.78, 0.88, 0.10) end
        row.selectedBar = row:CreateTexture(nil, "ARTWORK")
        row.selectedBar:SetWidth(3)
        row.selectedBar:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -4)
        row.selectedBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 4)
        local r, g, b = ThemeAccentRGB(); row.selectedBar:SetColorTexture(r, g, b, 0.70)
        row.selectedBar:Hide()
        row.pageName = data[1]
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 8, 0)
        row.icon:SetTexture(data[2])
        row.text = row:CreateFontString(nil, "OVERLAY", i == 1 and "GameFontNormalSmall" or "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
        row.text:SetText(T(data[1]))
        row.text:SetTextColor(i == 1 and 1 or 0.86, i == 1 and 0.82 or 0.84, i == 1 and 0.24 or 0.78)
        row:SetScript("OnClick", function(self)
            if EL.SelectSettingsPage then EL:SelectSettingsPage(self.pageName) end
        end)
        row:SetScript("OnEnter", function(self)
            if self.SetBackdropColor and EL.settingsPanel and EL.settingsPanel.currentPage ~= self.pageName then
                local r, g, b = ThemeAccentRGB()
                self:SetBackdropColor(r * 0.18, g * 0.14, b * 0.10, 0.35)
            end
        end)
        row:SetScript("OnLeave", function(self)
            if EL.UpdateSettingsNavHighlight then EL:UpdateSettingsNavHighlight() end
        end)
        f.navLabels[i] = row
        f.navByName[data[1]] = row
        ny = ny - 36
    end

    local contentX = 168
    local contentW = 476

    f.generalSection = MakeSettingsSection(f, "Window Behavior", contentX, -42, contentW, 92)
    f.showLauncher = MakeSettingsCheck(f.generalSection, "Show launcher", function() EL:ToggleSectionSetting("launcher") end)
    f.showLauncher:SetPoint("TOPLEFT", 12, -36)
    f.toggleCharactersSection = MakeSettingsCheck(f.generalSection, "Show main window", function() EL:ToggleSectionSetting("characters") end)
    f.toggleCharactersSection:SetPoint("TOPLEFT", 12, -62)
    f.toggleSessionSection = MakeSettingsCheck(f.generalSection, "Show session window", function() EL:ToggleSectionSetting("session") end)
    f.toggleSessionSection:SetPoint("TOPLEFT", 238, -36)
    SetSettingsTooltip(f.toggleSessionSection, "Show session window", {"Toggles only the standalone Session window.", "Launcher session lines are controlled separately on the Launcher page."})
    f.lockWindows = MakeSettingsCheck(f.generalSection, "Lock windows", function() EL:ToggleLockWindows() end)
    f.lockWindows:SetPoint("TOPLEFT", 12, -36)
    f.showMinimapButton = MakeSettingsCheck(f.generalSection, "Show minimap button", function() if EL.ToggleMinimapButton then EL:ToggleMinimapButton() end end)
    f.showMinimapButton:SetPoint("TOPLEFT", 238, -88)
    -- These visibility/module switches are now consolidated on the Modules page.
    f.showLauncher:Hide()
    f.toggleCharactersSection:Hide()
    f.toggleSessionSection:Hide()
    f.showMinimapButton:Hide()
    f.appearanceSection = MakeSettingsSection(f, "Appearance", contentX, -118, contentW, 178)
    f.launcherOpacitySlider = MakeSettingsSlider(f.appearanceSection, "Launcher opacity", 20, 100, 5, function(v) return string.format("%d%%", v) end, function(v)
        EL:SetAbsoluteSetting("launcherOpacity", v / 100)
    end)
    f.launcherOpacitySlider:SetPoint("TOPLEFT", 12, -40)
    f.panelOpacitySlider = MakeSettingsSlider(f.appearanceSection, "Main window opacity", 20, 100, 5, function(v) return string.format("%d%%", v) end, function(v)
        EL:SetAbsoluteSetting("panelOpacity", v / 100)
    end)
    f.panelOpacitySlider:SetPoint("TOPLEFT", 12, -74)
    f.sessionOpacitySlider = MakeSettingsSlider(f.appearanceSection, "Session opacity", 20, 100, 5, function(v) return string.format("%d%%", v) end, function(v)
        EL:SetAbsoluteSetting("sessionOpacity", v / 100)
    end)
    f.sessionOpacitySlider:SetPoint("TOPLEFT", 12, -108)
    f.matchOpacityButton = MakeSettingsButton(f.appearanceSection, "Match Main", 112, function()
        if EL.MatchOpacityToMainWindow then EL:MatchOpacityToMainWindow() end
    end)
    f.matchOpacityButton:SetPoint("TOPLEFT", 12, -142)
    f.resetOpacityButton = MakeSettingsButton(f.appearanceSection, "Reset Opacity", 122, function()
        if EL.ResetOpacityDefaults then EL:ResetOpacityDefaults() end
    end)
    f.resetOpacityButton:SetPoint("LEFT", f.matchOpacityButton, "RIGHT", 12, 0)
    SetSettingsTooltip(f.matchOpacityButton, "Match Main", {"Sets launcher and session opacity to the current main-window opacity."})
    SetSettingsTooltip(f.resetOpacityButton, "Reset Opacity", {"Restores default opacity values for launcher, main window, and session window."})

    f.scaleSection = MakeSettingsSection(f, "Scale", contentX, -278, contentW, 112)
    f.scaleSlider = MakeSettingsSlider(f.scaleSection, "Main window scale", 60, 140, 5, function(v) return string.format("%d%%", v) end, function(v)
        EL:SetAbsoluteSetting("panelScale", v / 100)
    end)
    f.scaleSlider:SetPoint("TOPLEFT", 12, -38)
    f.sessionScaleSlider = MakeSettingsSlider(f.scaleSection, "Session window scale", 60, 140, 5, function(v) return string.format("%d%%", v) end, function(v)
        EL:SetAbsoluteSetting("sessionScale", v / 100)
    end)
    f.sessionScaleSlider:SetPoint("TOPLEFT", 12, -72)

    f.moduleSection = MakeSettingsSection(f, "Feature Modules", contentX, -42, contentW, 166)
    f.moduleDesc = f.moduleSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.moduleDesc:SetPoint("TOPLEFT", 12, -36)
    f.moduleDesc:SetWidth(contentW - 24)
    f.moduleDesc:SetJustifyH("LEFT")
    f.moduleDesc:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.moduleDesc, "themeMutedTextWidgets")
    f.moduleDesc:SetText("Enable only the EmberLedger systems you care about. These controls collect only the top-level systems. Column visibility and detailed display options remain on their own pages.")
    f.moduleMainWindow = MakeSettingsCheck(f.moduleSection, "Main tracker", function() EL:ToggleSectionSetting("characters") end)
    f.moduleMainWindow:SetPoint("TOPLEFT", 12, -78)
    f.moduleSessionTracking = MakeSettingsCheck(f.moduleSection, "Session tracking", function() EL:TogglePerformanceSetting("sessionTracking") end)
    f.moduleSessionTracking:SetPoint("TOPLEFT", 238, -78)
    f.moduleActionBar = MakeSettingsCheck(f.moduleSection, "Action Bar", function() EL:TogglePerformanceSetting("actionBar") end)
    f.moduleActionBar:SetPoint("TOPLEFT", 12, -104)
    f.moduleLauncher = MakeSettingsCheck(f.moduleSection, "Launcher", function() EL:ToggleSectionSetting("launcher") end)
    f.moduleLauncher:SetPoint("TOPLEFT", 238, -104)
    f.moduleMinimap = MakeSettingsCheck(f.moduleSection, "Minimap button", function() if EL.ToggleMinimapButton then EL:ToggleMinimapButton() end end)
    f.moduleMinimap:SetPoint("TOPLEFT", 12, -130)
    SetSettingsTooltip(f.moduleMainWindow, "Main tracker", {"Shows the main profession dashboard window."})
    SetSettingsTooltip(f.moduleSessionTracking, "Session tracking", {"Enables session value, item tracking, bag summaries, and session history processing."})
    SetSettingsTooltip(f.moduleActionBar, "Action Bar", {"Enables EmberLedger utility button processing."})
    SetSettingsTooltip(f.moduleLauncher, "Launcher", {"Shows the compact EmberLedger launcher button."})
    SetSettingsTooltip(f.moduleMinimap, "Minimap button", {"Shows or hides EmberLedger's minimap button."})
    f.mainWindowTogglesSection = MakeSettingsSection(f, "Main Window Toggles", contentX, -498, contentW, 136)
    local mainWindowToggleLeftX = 12
    local mainWindowToggleRightX = 250
    f.toggleCompactMode = MakeSettingsCheck(f.mainWindowTogglesSection, "Compact Mode", function() EL:ToggleDisplaySetting("compactMode") end)
    f.toggleCompactMode:SetPoint("TOPLEFT", mainWindowToggleLeftX, -34)
    f.toggleCharacterRealm = MakeSettingsCheck(f.mainWindowTogglesSection, "Show character realm", function() EL:ToggleDisplaySetting("showCharacterRealm") end)
    f.toggleCharacterRealm:SetPoint("TOPLEFT", mainWindowToggleRightX, -34)
    f.togglePinnedFirst = MakeSettingsCheck(f.mainWindowTogglesSection, "Show pinned first", function() EL:ToggleDisplaySetting("showPinnedFirst") end)
    f.togglePinnedFirst:SetPoint("TOPLEFT", mainWindowToggleLeftX, -64)
    f.toggleCurrentCharacterFirst = MakeSettingsCheck(f.mainWindowTogglesSection, "Current character first", function() EL:ToggleDisplaySetting("showCurrentCharacterFirst") end)
    f.toggleCurrentCharacterFirst:SetPoint("TOPLEFT", mainWindowToggleRightX, -64)
    f.toggleCurrentCharacterHighlight = MakeSettingsCheck(f.mainWindowTogglesSection, "Highlight current character", function() EL:ToggleDisplaySetting("highlightCurrentCharacter") end)
    f.toggleCurrentCharacterHighlight:SetPoint("TOPLEFT", mainWindowToggleLeftX, -94)
    f.toggleAttentionOnly = MakeSettingsCheck(f.mainWindowTogglesSection, "Attention Only view", function() EL:ToggleDisplaySetting("attentionOnly") end)
    f.toggleAttentionOnly:SetPoint("TOPLEFT", mainWindowToggleRightX, -94)

    f.thresholdSection = MakeSettingsSection(f, "Resource Thresholds", contentX, -42, contentW, 122)
    f.thresholdSlider = MakeSettingsSlider(f.thresholdSection, "Concentration ready threshold", 0, 1000, 10, function(v) return tostring(math.floor(v + 0.5)) end, function(v)
        EL:SetAbsoluteSetting("concThreshold", math.floor(v + 0.5))
    end)
    f.thresholdSlider:SetPoint("TOPLEFT", 12, -38)
    f.moxieThresholdSlider = MakeSettingsSlider(f.thresholdSection, "Moxie spend threshold", 0, 1000, 25, function(v) return tostring(math.floor(v + 0.5)) end, function(v)
        EL:SetAbsoluteSetting("moxieThreshold", math.floor(v + 0.5))
    end)
    f.moxieThresholdSlider:SetPoint("TOPLEFT", 12, -78)

    f.profThresholdSection = MakeSettingsSection(f, "Profession Threshold Overrides", contentX, -178, contentW, 420)
    f.profThresholdDesc = f.profThresholdSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.profThresholdDesc:SetPoint("TOPLEFT", 12, -34)
    f.profThresholdDesc:SetWidth(contentW - 24)
    f.profThresholdDesc:SetJustifyH("LEFT")
    f.profThresholdDesc:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.profThresholdDesc, "themeMutedTextWidgets")
    f.profThresholdDesc:SetText("Set optional concentration thresholds per profession. Set a profession to 0 to use the global threshold.")
    f.profThresholdSliders = {}
    local thresholdY = -72
    for _, def in ipairs(EL.PROFESSION_THRESHOLD_PROFESSIONS or {}) do
        local slider = MakeSettingsSlider(f.profThresholdSection, def.label, 0, 1000, 10, function(v)
            v = math.floor((tonumber(v) or 0) + 0.5)
            return v <= 0 and "Default" or tostring(v)
        end, function(v)
            if EL.SetProfessionConcentrationThreshold then EL:SetProfessionConcentrationThreshold(def.id, v) end
        end)
        slider:SetPoint("TOPLEFT", 12, thresholdY)
        slider.professionID = def.id
        SetSettingsTooltip(slider, def.label, {"Set to 0 to use the global threshold for this profession."})
        if slider.slider then
            SetSettingsTooltip(slider.slider, def.label, {"Set to 0 to use the global threshold for this profession."})
        end
        f.profThresholdSliders[#f.profThresholdSliders + 1] = slider
        thresholdY = thresholdY - 30
    end

    f.trackingColumnsSection = MakeSettingsSection(f, "Main Window Columns", contentX, -766, contentW, 136)
    local trackingColumnLeftX = 12
    local trackingColumnRightX = 250
    f.toggleProf1Column = MakeSettingsCheck(f.trackingColumnsSection, "Show Prof 1 column", function() EL:ToggleTrackingColumn("prof1") end)
    f.toggleProf1Column:SetPoint("TOPLEFT", trackingColumnLeftX, -34)
    f.toggleConc1Column = MakeSettingsCheck(f.trackingColumnsSection, "Show Conc 1 column", function() EL:ToggleTrackingColumn("conc1") end)
    f.toggleConc1Column:SetPoint("TOPLEFT", trackingColumnRightX, -34)
    f.toggleProf2Column = MakeSettingsCheck(f.trackingColumnsSection, "Allow Prof 2 column", function() EL:ToggleTrackingColumn("prof2") end)
    f.toggleProf2Column:SetPoint("TOPLEFT", trackingColumnLeftX, -64)
    f.toggleConc2Column = MakeSettingsCheck(f.trackingColumnsSection, "Allow Conc 2 column", function() EL:ToggleTrackingColumn("conc2") end)
    f.toggleConc2Column:SetPoint("TOPLEFT", trackingColumnRightX, -64)
    f.toggleMoxieColumn = MakeSettingsCheck(f.trackingColumnsSection, "Show Moxie column", function() EL:ToggleTrackingColumn("moxie") end)
    f.toggleMoxieColumn:SetPoint("TOPLEFT", trackingColumnLeftX, -94)
    f.toggleMulchColumn = MakeSettingsCheck(f.trackingColumnsSection, "Show Imbued Mulch column", function() EL:ToggleTrackingColumn("mulch") end)
    f.toggleMulchColumn:SetPoint("TOPLEFT", trackingColumnRightX, -94)
    SetSettingsTooltip(f.toggleMulchColumn, "Imbued Mulch column", {"Shows or hides the Mulch readiness column without changing saved Mulch tracking data."})

    f.nextColumnSection = MakeSettingsSection(f, "Next Column", contentX, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_NEXT_COLUMN_Y) or -926, contentW, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_NEXT_COLUMN_H) or 88)
    f.nextColumnDesc = f.nextColumnSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.nextColumnDesc:SetPoint("TOPLEFT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_LEFT) or 12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_TOP) or -36)
    f.nextColumnDesc:SetPoint("TOPRIGHT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_RIGHT) or -12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_TOP) or -36)
    f.nextColumnDesc:SetJustifyH("LEFT")
    if f.nextColumnDesc.SetWordWrap then f.nextColumnDesc:SetWordWrap(true) end
    f.nextColumnDesc:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.nextColumnDesc, "themeMutedTextWidgets")
    f.nextColumnDesc:SetText("Shows the next concentration readiness forecast based on your threshold and regeneration timing.")
    f.toggleForecastColumn = MakeSettingsCheck(f.nextColumnSection, "Show Next column", function() EL:ToggleTrackingColumn("forecast") end)
    f.toggleForecastColumn:SetPoint("TOPLEFT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_LEFT) or 12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_NEXT_COLUMN_CHECK_Y) or -62)

    f.cooldownColumnSection = MakeSettingsSection(f, "Cooldown Readiness Column", contentX, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COOLDOWN_COLUMN_Y) or -1026, contentW, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COOLDOWN_COLUMN_H) or 94)
    f.cooldownColumnDesc = f.cooldownColumnSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.cooldownColumnDesc:SetPoint("TOPLEFT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_LEFT) or 12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_TOP) or -36)
    f.cooldownColumnDesc:SetPoint("TOPRIGHT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_RIGHT) or -12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_TOP) or -36)
    f.cooldownColumnDesc:SetJustifyH("LEFT")
    if f.cooldownColumnDesc.SetWordWrap then f.cooldownColumnDesc:SetWordWrap(true) end
    f.cooldownColumnDesc:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.cooldownColumnDesc, "themeMutedTextWidgets")
    f.cooldownColumnDesc:SetText("Shows readiness for supported profession cooldown crafts. Use Expansion Scope to reduce older-expansion cooldown clutter.")
    f.toggleCooldownColumn = MakeSettingsCheck(f.cooldownColumnSection, "Show CD column", function() EL:ToggleTrackingColumn("cooldown") end)
    f.toggleCooldownColumn:SetPoint("TOPLEFT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_LEFT) or 12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COOLDOWN_COLUMN_CHECK_Y) or -68)
    SetSettingsTooltip(f.toggleCooldownColumn, "Profession cooldown readiness", {"Adds a compact CD column for supported profession cooldown crafts.", "Details appear in the row tooltip."})
    f.cooldownScopeLabel = f.cooldownColumnSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.cooldownScopeLabel:SetText("Expansion Scope")
    f.cooldownScopeDropdown = MakeSettingsDropdown(f.cooldownColumnSection, 206, {
        { label = "Current Expansion Only", value = "current" },
        { label = "Current + Previous Expansion", value = "current_previous" },
        { label = "All Supported Cooldowns", value = "all" },
    }, function()
        return (EL.GetCooldownDisplayScope and EL:GetCooldownDisplayScope()) or "current"
    end, function(value)
        if EL.SetCooldownDisplayScope then EL:SetCooldownDisplayScope(value) end
    end)
    f.cooldownScopeDropdown:SetPoint("TOPRIGHT", f.cooldownColumnSection, "TOPRIGHT", -14, -84)
    f.cooldownScopeLabel:SetPoint("RIGHT", f.cooldownScopeDropdown, "LEFT", -8, 2)
    SetSettingsTooltip(f.cooldownScopeDropdown, "Cooldown expansion scope", {"Controls which expansion's profession cooldowns appear in the CD column, row tooltips, and summaries.", "Saved cooldown data is not deleted."})
    f.showAllCooldownsButton = MakeSettingsButton(f.cooldownColumnSection, "Show All Cooldowns", 138, function()
        if EL.ShowAllProfessionCooldowns then EL:ShowAllProfessionCooldowns() end
    end)
    f.showAllCooldownsButton:SetPoint("TOPLEFT", f.cooldownColumnSection, "TOPLEFT", 14, -84)
    SetSettingsTooltip(f.showAllCooldownsButton, "Show All Cooldowns", {"Restores all supported cooldown crafts to the tracker.", "This does not delete saved cooldown data."})

    f.cooldownVisibilityLabel = f.cooldownColumnSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.cooldownVisibilityLabel:SetPoint("TOPLEFT", 14, -120)
    f.cooldownVisibilityLabel:SetText("Tracked Cooldowns")
    f.cooldownVisibilityDesc = f.cooldownColumnSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.cooldownVisibilityDesc:SetPoint("TOPLEFT", 14, -138)
    f.cooldownVisibilityDesc:SetWidth(contentW - 28)
    f.cooldownVisibilityDesc:SetJustifyH("LEFT")
    if f.cooldownVisibilityDesc.SetWordWrap then f.cooldownVisibilityDesc:SetWordWrap(true) end
    f.cooldownVisibilityDesc:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.cooldownVisibilityDesc, "themeMutedTextWidgets")
    f.cooldownVisibilityDesc:SetText("Choose which cooldown crafts appear after Expansion Scope is applied.")
    f.cooldownVisibilityDropdown = MakeCooldownVisibilityDropdown(f.cooldownColumnSection, 206)
    f.cooldownVisibilityDropdown:SetPoint("TOPRIGHT", f.cooldownColumnSection, "TOPRIGHT", -14, -158)
    SetSettingsTooltip(f.cooldownVisibilityDropdown, "Tracked Cooldowns", {"Choose which cooldown crafts appear in EmberLedger after Expansion Scope is applied.", "Checked cooldowns are shown. Unchecked cooldowns are hidden account-wide without deleting saved data."})

    f.launcherSection = MakeSettingsSection(f, "Launcher Display", contentX, -598, contentW, 112)
    f.toggleConc = MakeSettingsCheck(f.launcherSection, "Concentration alert", function() EL:ToggleDisplaySetting("showLauncherConc") end)
    f.toggleConc:SetPoint("TOPLEFT", 12, -34)
    f.toggleMulch = MakeSettingsCheck(f.launcherSection, "Mulch", function() EL:ToggleDisplaySetting("showLauncherMulch") end)
    f.toggleMulch:SetPoint("TOPLEFT", 178, -34)
    f.toggleCooldown = MakeSettingsCheck(f.launcherSection, "Next CD", function() EL:ToggleDisplaySetting("showLauncherCooldown") end)
    f.toggleCooldown:SetPoint("TOPLEFT", 294, -34)
    SetSettingsTooltip(f.toggleCooldown, "Launcher next cooldown", {"Shows the next profession cooldown ready state on the launcher.", "Ready cooldowns show as CD ready; recovering cooldowns show the next character and time."})
    f.toggleSession = MakeSettingsCheck(f.launcherSection, "Session rate", function() EL:ToggleDisplaySetting("showLauncherSession") end)
    f.toggleSession:SetPoint("TOPLEFT", 12, -56)
    f.toggleTotal = MakeSettingsCheck(f.launcherSection, "Session total", function() EL:ToggleDisplaySetting("showLauncherSessionTotal") end)
    f.toggleTotal:SetPoint("TOPLEFT", 178, -56)
    SetSettingsTooltip(f.toggleTotal, "Launcher session total", {"Controls the session total line on the launcher only.", "This does not show or hide the standalone Session window."})
    f.toggleTime = MakeSettingsCheck(f.launcherSection, "Session time", function() EL:ToggleDisplaySetting("showLauncherSessionTime") end)
    f.toggleTime:SetPoint("TOPLEFT", 294, -56)
    SetSettingsTooltip(f.toggleTime, "Launcher session time", {"Controls the session timer line on the launcher only.", "This does not show or hide the standalone Session window."})

    f.sessionOptions = MakeSettingsSection(f, "Session Tracking", contentX, -724, contentW, 190)
    f.filterHerbs = MakeSettingsCheck(f.sessionOptions, "Herbs", function() EL:ToggleSessionFilterSetting("trackHerbs") end)
    f.filterHerbs:SetPoint("TOPLEFT", 12, -34)
    f.filterOre = MakeSettingsCheck(f.sessionOptions, "Ore", function() EL:ToggleSessionFilterSetting("trackOre") end)
    f.filterOre:SetPoint("TOPLEFT", 128, -34)
    f.filterCloth = MakeSettingsCheck(f.sessionOptions, "Cloth", function() EL:ToggleSessionFilterSetting("trackCloth") end)
    f.filterCloth:SetPoint("TOPLEFT", 238, -34)
    f.filterLeather = MakeSettingsCheck(f.sessionOptions, "Leather/skins", function() EL:ToggleSessionFilterSetting("trackLeather") end)
    f.filterLeather:SetPoint("TOPLEFT", 12, -60)
    f.filterEnchanting = MakeSettingsCheck(f.sessionOptions, "Enchanting", function() EL:ToggleSessionFilterSetting("trackEnchanting") end)
    f.filterEnchanting:SetPoint("TOPLEFT", 128, -60)
    f.filterFish = MakeSettingsCheck(f.sessionOptions, "Fish", function() EL:ToggleSessionFilterSetting("trackFish") end)
    f.filterFish:SetPoint("TOPLEFT", 238, -60)
    f.filterOther = MakeSettingsCheck(f.sessionOptions, "Other materials", function() EL:ToggleSessionFilterSetting("trackOtherMaterials") end)
    f.filterOther:SetPoint("TOPLEFT", 12, -86)
    f.trackRawGoldGains = MakeSettingsCheck(f.sessionOptions, "Raw gold gains", function() EL:ToggleSessionMoneySetting("trackRawGoldGains", true, "Raw gold gains") end)
    f.trackRawGoldGains:SetPoint("TOPLEFT", 128, -86)
    SetSettingsTooltip(f.trackRawGoldGains, "Raw gold gains", {"Adds direct wallet gains to the session total outside transaction windows.", "Mailbox item rewards are handled separately by trusted mail rewards."})
    f.trackGoldSpent = MakeSettingsCheck(f.sessionOptions, "Gold spent", function() EL:ToggleSessionMoneySetting("trackGoldSpent", false, "Gold spent") end)
    f.trackGoldSpent:SetPoint("TOPLEFT", 238, -86)
    SetSettingsTooltip(f.trackGoldSpent, "Gold spent", {"Subtracts direct wallet losses from the session total.", "Off by default so repairs and purchases do not surprise users."})
    f.countTrustedMailRewards = MakeSettingsCheck(f.sessionOptions, "Trusted mail rewards", function() EL:ToggleSessionMoneySetting("countTrustedMailRewards", true, "Trusted mail rewards") end)
    f.countTrustedMailRewards:SetPoint("TOPLEFT", 128, -112)
    SetSettingsTooltip(f.countTrustedMailRewards, "Trusted mail rewards", {"Counts profession material attachments from trusted patron or crafting-order reward mail.", "Player mail, auction mail, and normal transfers remain ignored."})
    f.pricingSourceLabel = f.sessionOptions:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.pricingSourceLabel:SetPoint("TOPLEFT", 12, -134)
    f.pricingSourceLabel:SetText("Pricing:")
    f.pricingSourceLabel:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.pricingSourceLabel, "themeMutedTextWidgets")
    f.pricingSourceValue = f.sessionOptions:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.pricingSourceValue:SetPoint("LEFT", f.pricingSourceLabel, "RIGHT", 5, 0)
    f.pricingSourceValue:SetTextColor(1.00, 0.92, 0.56)
    RegisterThemeText(f.pricingSourceValue, "themeValueTextWidgets")
    f.toggleSessionHistory = MakeSettingsCheck(f.sessionOptions, "Session history", function() if EL.ToggleSessionHistoryEnabled then EL:ToggleSessionHistoryEnabled() end end)
    f.toggleSessionHistory:SetPoint("TOPLEFT", 12, -112)
    SetSettingsTooltip(f.toggleSessionHistory, "Session History", {"Saves account-wide summary records on reset and logout/reload."})
    f.copySummary = MakeSettingsButton(f.sessionOptions, "Copy Summary", 112, function() EL:ShowCopySessionSummaryDialog() end)
    f.copySummary:SetPoint("TOPRIGHT", -12, -132)
    SetSettingsTooltip(f.copySummary, "Copy Summary", {"Copies a quick summary of the current session totals."})
    f.sessionDisabledTip = f.sessionOptions:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sessionDisabledTip:SetPoint("TOPLEFT", 12, -162)
    f.sessionDisabledTip:SetWidth(contentW - 24)
    f.sessionDisabledTip:SetJustifyH("LEFT")
    f.sessionDisabledTip:SetTextColor(1.00, 0.74, 0.36)
    f.sessionDisabledTip:SetText("Session Tracking is disabled on the Modules page.")
    f.sessionDisabledTip:Hide()

    f.craftedItemsSection = MakeSettingsSection(f, "Crafted Item Tracking", contentX, -898, contentW, 146)
    f.countCraftedItems = MakeSettingsCheck(f.craftedItemsSection, "Count crafted items", function() EL:ToggleSessionMoneySetting("countCraftedItems", false, "Crafted items") end)
    f.countCraftedItems:SetPoint("TOPLEFT", 12, -36)
    SetSettingsTooltip(f.countCraftedItems, "Crafted items", {"Counts crafted outputs added to your bags during tradeskill crafting.", "Off by default. May double-count value if the crafted item is later sold and AH/mail gold is also tracked.", "Reagent costs are not deducted from crafted item value."})
    f.craftedItemsWarning = f.craftedItemsSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.craftedItemsWarning:SetPoint("TOPLEFT", 12, -66)
    f.craftedItemsWarning:SetText("Warning: read before enabling")
    f.craftedItemsWarning:SetTextColor(ThemeTextRGB())
    f.craftedItemsBody = f.craftedItemsSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.craftedItemsBody:SetPoint("TOPLEFT", 12, -86)
    f.craftedItemsBody:SetWidth(contentW - 24)
    f.craftedItemsBody:SetJustifyH("LEFT")
    f.craftedItemsBody:SetText("Most users should leave this off. Use it only when you specifically want crafted outputs counted at craft time. It may double-count value if the crafted item is later sold and AH/mail gold is also tracked, and reagent costs are not deducted.")
    f.craftedItemsBody:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.craftedItemsBody, "themeMutedTextWidgets")

    f.actionPlacementSection = MakeSettingsSection(f, "Placement", contentX, -42, contentW, 156)
    f.actionPlacementDesc = f.actionPlacementSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.actionPlacementDesc:SetPoint("TOPLEFT", 12, -34)
    f.actionPlacementDesc:SetWidth(contentW - 24)
    f.actionPlacementDesc:SetJustifyH("LEFT")
    f.actionPlacementDesc:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.actionPlacementDesc, "themeMutedTextWidgets")
    f.actionPlacementDesc:SetText("Anchor the action bar inside the main tracker, or let it float as a small draggable utility strip.")
    f.actionBarFloating = MakeSettingsCheck(f.actionPlacementSection, "Floating action bar", function() EL:ToggleActionBarFloating() end)
    f.actionBarFloating:SetPoint("TOPLEFT", 12, -72)
    f.actionBarLocked = MakeSettingsCheck(f.actionPlacementSection, "Lock floating bar", function() EL:ToggleFloatingActionBarLocked() end)
    f.actionBarLocked:SetPoint("TOPLEFT", 178, -72)
    f.resetActionBarPosition = MakeSettingsButton(f.actionPlacementSection, "Reset Position", 118, function() EL:ResetFloatingActionBarPosition() end)
    f.resetActionBarPosition:SetPoint("TOPLEFT", 12, -100)
    f.actionBarDisabledTip = f.actionPlacementSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.actionBarDisabledTip:SetPoint("TOPLEFT", 12, -128)
    f.actionBarDisabledTip:SetWidth(contentW - 24)
    f.actionBarDisabledTip:SetJustifyH("LEFT")
    f.actionBarDisabledTip:SetTextColor(1.00, 0.74, 0.36)
    f.actionBarDisabledTip:SetText("Action Bar is disabled on the Modules page.")
    f.actionBarDisabledTip:Hide()

    f.actionButtonsSection = MakeSettingsSection(f, "Button Visibility", contentX, -188, contentW, 232)
    f.actionGeneralLabel = f.actionButtonsSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.actionGeneralLabel:SetPoint("TOPLEFT", 12, -32)
    f.actionGeneralLabel:SetText("General")
    f.actionGeneralLabel:SetTextColor(ThemeTextRGB())
    f.actionMulchButton = MakeSettingsCheck(f.actionButtonsSection, "Imbued Mulch", function() EL:ToggleActionBarButton("mulch", "Imbued Mulch") end)
    f.actionMulchButton:SetPoint("TOPLEFT", 12, -54)
    SetSettingsTooltip(f.actionMulchButton, "Action bar button visibility", {"Controls whether this button is allowed to appear.", "The button may still hide when the item or spell is unavailable."})
    f.actionGreenThumbButton = MakeSettingsCheck(f.actionButtonsSection, "Green Thumb", function() EL:ToggleActionBarButton("greenThumb", "Green Thumb") end)
    f.actionGreenThumbButton:SetPoint("TOPLEFT", 178, -54)
    f.actionOverloadHerbButton = MakeSettingsCheck(f.actionButtonsSection, "Overload Herb", function() EL:ToggleActionBarButton("overloadHerb", "Overload Herb") end)
    f.actionOverloadHerbButton:SetPoint("TOPLEFT", 12, -80)
    f.actionOverloadOreButton = MakeSettingsCheck(f.actionButtonsSection, "Overload Ore", function() EL:ToggleActionBarButton("overloadOre", "Overload Ore") end)
    f.actionOverloadOreButton:SetPoint("TOPLEFT", 178, -80)
    f.actionParcelButton = MakeSettingsCheck(f.actionButtonsSection, "Interdimensional Parcel", function() EL:ToggleActionBarButton("parcel", "Interdimensional Parcel") end)
    f.actionParcelButton:SetPoint("TOPLEFT", 12, -106)
    f.actionBankButton = MakeSettingsCheck(f.actionButtonsSection, "Warband Bank", function() EL:ToggleActionBarButton("bank", "Warband Bank") end)
    f.actionBankButton:SetPoint("TOPLEFT", 178, -106)

    f.actionSeedsLabel = f.actionButtonsSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.actionSeedsLabel:SetPoint("TOPLEFT", 12, -136)
    f.actionSeedsLabel:SetText("Seeds")
    f.actionSeedsLabel:SetTextColor(ThemeTextRGB())
    f.actionSeedButton = MakeSettingsCheck(f.actionButtonsSection, "Resilient Seed", function() EL:ToggleActionBarButton("seed", "Resilient Seed") end)
    f.actionSeedButton:SetPoint("TOPLEFT", 12, -158)
    f.actionGlowingSeedButton = MakeSettingsCheck(f.actionButtonsSection, "Glowing Resilient Seed", function() EL:ToggleActionBarButton("glowingSeed", "Glowing Resilient Seed") end)
    f.actionGlowingSeedButton:SetPoint("TOPLEFT", 178, -158)
    f.actionWildSeedButton = MakeSettingsCheck(f.actionButtonsSection, "Wild Resilient Seed", function() EL:ToggleActionBarButton("wildSeed", "Wild Resilient Seed") end)
    f.actionWildSeedButton:SetPoint("TOPLEFT", 12, -184)
    f.actionPrimalSeedButton = MakeSettingsCheck(f.actionButtonsSection, "Primal Resilient Seed", function() EL:ToggleActionBarButton("primalSeed", "Primal Resilient Seed") end)
    f.actionPrimalSeedButton:SetPoint("TOPLEFT", 178, -184)



    -- Keep Options help consistent across all checkboxes. These are text-only tooltips.
    SetSettingsTooltip(f.showLauncher, "Show launcher", {"Shows or hides the movable EmberLedger launcher button."})
    SetSettingsTooltip(f.toggleCharactersSection, "Show main window", {"Shows or hides the main EmberLedger window."})
    SetSettingsTooltip(f.toggleSessionSection, "Show session window", {"Toggles only the standalone Session window.", "Launcher session lines are controlled separately on the Launcher page."})
    SetSettingsTooltip(f.showMinimapButton, "Show minimap button", {"Shows or hides the EmberLedger minimap button.", "Uses LibDataBroker/LibDBIcon when available, with a fallback minimap button otherwise.", "Left-click toggles the tracker. Right-click opens Options."})
    SetSettingsTooltip(f.lockWindows, "Lock windows", {"Prevents EmberLedger windows from being dragged unless Shift is held."})
    SetSettingsTooltip(f.toggleAttentionOnly, "Attention Only view", {"Shows only characters with concentration or mulch states that need attention."})
    SetSettingsTooltip(f.toggleCompactMode, "Compact Mode", {"Uses tighter main-window rows and hides extra header text in compact mode."})
    SetSettingsTooltip(f.toggleCurrentCharacterFirst, "Current character first", {"Keeps the character you are currently playing at the top of the main window list.", "This is separate from the current-character highlight option."})
    SetSettingsTooltip(f.togglePinnedFirst, "Show pinned first", {"Keeps pinned characters above unpinned characters when sorting the main window table."})
    SetSettingsTooltip(f.toggleCurrentCharacterHighlight, "Highlight current character", {"Adds a subtle row highlight to the character you are currently playing.", "This does not change sorting or tracking behavior."})

    SetSettingsTooltip(f.toggleProf1Column, "Show Prof 1 column", {"Shows the first tracked profession column in the main window table."})
    SetSettingsTooltip(f.toggleConc1Column, "Show Conc 1 column", {"Shows the first concentration column in the main window table."})
    SetSettingsTooltip(f.toggleProf2Column, "Allow Prof 2 column", {"Allows the second profession column when tracked data needs it."})
    SetSettingsTooltip(f.toggleConc2Column, "Allow Conc 2 column", {"Allows the second concentration column when tracked data needs it."})
    SetSettingsTooltip(f.toggleMoxieColumn, "Show Moxie column", {"Shows profession-specific Artisan Moxie values in the main window table.", "Values update for each character after that character has been logged in."})
    SetSettingsTooltip(f.toggleMulchColumn, "Show Imbued Mulch column", {"Shows or hides the Imbued Mulch readiness column in the main window table."})
    SetSettingsTooltip(f.toggleForecastColumn, "Show Next column", {"Shows an optional concentration forecast in the main window table.", "Uses the configured concentration threshold and fixed concentration regeneration rate.", "Examples: Ready, Full, 7h 48m, or N/A."})
    SetSettingsTooltip(f.toggleCharacterRealm, "Show character realm", {"Shows the realm name beside character names when available."})

    SetSettingsTooltip(f.toggleConc, "Concentration alert", {"Shows the launcher line for characters at or above the concentration threshold."})
    SetSettingsTooltip(f.toggleMulch, "Mulch", {"Shows the launcher line for Imbued Mulch readiness."})
    SetSettingsTooltip(f.toggleSession, "Launcher session rate", {"Controls the gold-per-hour line on the launcher only.", "This does not show or hide the standalone Session window."})
    SetSettingsTooltip(f.toggleTotal, "Launcher session total", {"Controls the session total line on the launcher only.", "This does not show or hide the standalone Session window."})
    SetSettingsTooltip(f.toggleTime, "Launcher session time", {"Controls the session timer line on the launcher only.", "This does not show or hide the standalone Session window."})

    SetSettingsTooltip(f.filterHerbs, "Herbs", {"Includes herb loot in session value tracking."})
    SetSettingsTooltip(f.filterOre, "Ore", {"Includes ore loot in session value tracking."})
    SetSettingsTooltip(f.filterCloth, "Cloth", {"Includes cloth loot in session value tracking."})
    SetSettingsTooltip(f.filterLeather, "Leather/skins", {"Includes leather and skinning loot in session value tracking."})
    SetSettingsTooltip(f.filterEnchanting, "Enchanting", {"Includes enchanting materials in session value tracking."})
    SetSettingsTooltip(f.filterFish, "Fish", {"Includes fish loot in session value tracking."})
    SetSettingsTooltip(f.filterOther, "Other materials", {"Includes other recognized materials in session value tracking."})

    SetSettingsTooltip(f.actionBarFloating, "Floating action bar", {"Detaches the action bar from the main tracker so it can be positioned independently.", "Layout changes are deferred during combat for secure button safety."})
    SetSettingsTooltip(f.actionBarLocked, "Lock floating bar", {"Prevents the floating action bar from being dragged unless Shift is held."})
    SetSettingsTooltip(f.resetActionBarPosition, "Reset floating position", {"Returns the floating action bar to its default screen position."})

    SetSettingsTooltip(f.actionMulchButton, "Imbued Mulch button", {"Allows the Imbued Mulch button to appear on the action bar when available."})
    SetSettingsTooltip(f.actionGreenThumbButton, "Green Thumb button", {"Allows the Green Thumb button to appear on the action bar when available."})
    SetSettingsTooltip(f.actionOverloadHerbButton, "Overload Herb button", {"Allows the Overload Herb button to appear on the action bar when available."})
    SetSettingsTooltip(f.actionOverloadOreButton, "Overload Ore button", {"Allows the Overload Ore button to appear on the action bar when available."})
    SetSettingsTooltip(f.actionParcelButton, "Interdimensional Parcel button", {"Allows the Interdimensional Parcel button to appear on the action bar when available."})
    SetSettingsTooltip(f.actionBankButton, "Warband Bank button", {"Allows the Warband Bank button to appear on the action bar when available."})
    SetSettingsTooltip(f.actionSeedButton, "Resilient Seed button", {"Allows this seed button to appear on the action bar when available."})
    SetSettingsTooltip(f.actionGlowingSeedButton, "Glowing Resilient Seed button", {"Allows this seed button to appear on the action bar when available."})
    SetSettingsTooltip(f.actionWildSeedButton, "Wild Resilient Seed button", {"Allows this seed button to appear on the action bar when available."})
    SetSettingsTooltip(f.actionPrimalSeedButton, "Primal Resilient Seed button", {"Allows this seed button to appear on the action bar when available."})

    f.performanceSection = MakeSettingsSection(f, T("Performance"), contentX, -42, contentW, 224)
    f.performanceWarningTitle = f.performanceSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.performanceWarningTitle:SetPoint("TOPLEFT", 12, -36)
    f.performanceWarningTitle:SetText("Warning: read first")
    f.performanceWarningTitle:SetTextColor(1.00, 0.22, 0.18)

    f.performanceWarningText = f.performanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.performanceWarningText:SetPoint("TOPLEFT", 12, -56)
    f.performanceWarningText:SetWidth(contentW - 24)
    f.performanceWarningText:SetJustifyH("LEFT")
    f.performanceWarningText:SetTextColor(ThemeMutedTextRGB())
    f.performanceWarningText:SetText("The defaults are recommended for nearly everyone. These controls are only for reducing background work or limiting visible session-log size if you understand the tradeoff.")

    f.enableSessionTracking = MakeSettingsCheck(f.performanceSection, "Enable session tracking", function() EL:TogglePerformanceSetting("sessionTracking") end)
    f.enableSessionTracking:SetPoint("TOPLEFT", 12, -106)
    f.sessionTrackingTip = f.performanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sessionTrackingTip:SetPoint("TOPLEFT", 34, -130)
    f.sessionTrackingTip:SetWidth(contentW - 46)
    f.sessionTrackingTip:SetJustifyH("LEFT")
    f.sessionTrackingTip:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.sessionTrackingTip, "themeMutedTextWidgets")
    f.sessionTrackingTip:SetText("Leave this on for gold/hour, item value, session history, stats, and bag summaries. Turn it off only if you do not want EmberLedger tracking session activity.")

    f.enableActionBar = MakeSettingsCheck(f.performanceSection, "Enable action bar", function() EL:TogglePerformanceSetting("actionBar") end)
    f.enableActionBar:SetPoint("TOPLEFT", 12, -172)
    f.actionBarTip = f.performanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.actionBarTip:SetPoint("TOPLEFT", 34, -196)
    f.actionBarTip:SetWidth(contentW - 46)
    f.actionBarTip:SetJustifyH("LEFT")
    f.actionBarTip:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.actionBarTip, "themeMutedTextWidgets")
    f.actionBarTip:SetText("Disable this if you do not use EmberLedger's utility buttons or want to skip action-bar refresh work. This does not affect profession tracking.")
    -- Session tracking and Action Bar module switches are centralized on the Modules page.
    f.enableSessionTracking:Hide()
    f.sessionTrackingTip:Hide()
    f.enableActionBar:Hide()
    f.actionBarTip:Hide()

    f.historyCapTip = f.performanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.historyCapTip:SetPoint("TOPLEFT", 12, -116)
    f.historyCapTip:SetWidth(contentW - 24)
    f.historyCapTip:SetJustifyH("LEFT")
    f.historyCapTip:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.historyCapTip, "themeMutedTextWidgets")
    f.historyCapTip:SetText("Session history cap: 500 is already enough for almost everyone, including extreme players, because stats use compact aggregates. Increase this only if you specifically want a deeper visible Sessions list and do not mind larger SavedVariables.")

    SetSettingsTooltip(f.enableSessionTracking, "Enable session tracking", {"Tracks session time, gathered items, session value, bag summaries, and recent/lifetime stats.", "Turn off to stop most background loot and bag processing."})
    SetSettingsTooltip(f.enableActionBar, "Enable action bar", {"Allows EmberLedger utility buttons in the main window or floating action bar.", "Turn off to hide the bar and skip action bar refresh work."})

    f.historyMaxEntriesSlider = MakeSettingsSlider(f.performanceSection, "Session history cap", 50, 3000, 50, function(v) return string.format("%d entries", v) end, function(v)
        if EL.SetSessionHistoryMaxEntries then EL:SetSessionHistoryMaxEntries(v) end
    end)
    f.historyMaxEntriesSlider:SetPoint("TOPLEFT", f.performanceSection, "TOPLEFT", 12, -164)
    SetSettingsTooltip(f.historyMaxEntriesSlider, "Session history cap", {"Limits the visible saved session list after the 30-day retention filter is applied.", "Default: 500. Stats remain accurate through compact aggregates even when old visible list entries are pruned."})

    f.maintenanceSection = MakeSettingsSection(f, T("Maintenance / Resets"), contentX, -438, contentW, 252)
    f.hiddenStatus = f.maintenanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hiddenStatus:SetPoint("TOPLEFT", 12, -36)
    f.hiddenStatus:SetWidth(contentW - 24)
    f.hiddenStatus:SetJustifyH("LEFT")
    f.hiddenStatus:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.hiddenStatus, "themeMutedTextWidgets")
    f.resetUISettings = MakeSettingsButton(f.maintenanceSection, "Reset UI Settings", 288, function() if EL.ConfirmResetUISettings then EL:ConfirmResetUISettings() end end)
    f.resetUISettings:SetPoint("TOPLEFT", 12, -62)
    f.resetPos = MakeSettingsButton(f.maintenanceSection, "Reset Windows", 138, function() EL:ConfirmResetWindowPositions() end)
    f.resetPos:SetPoint("TOPLEFT", 12, -96)
    f.resetSession = MakeSettingsButton(f.maintenanceSection, "Reset Session", 138, function() EL:ConfirmResetSession() end)
    f.resetSession:SetPoint("LEFT", f.resetPos, "RIGHT", 12, 0)
    f.resetHidden = MakeSettingsButton(f.maintenanceSection, "Unhide All", 138, function() EL:ConfirmRestoreHiddenCharacters() end)
    f.resetHidden:SetPoint("TOPLEFT", 12, -130)
    f.resetPinned = MakeSettingsButton(f.maintenanceSection, "Reset Pinned", 138, function() EL:ConfirmResetPinnedCharacters() end)
    f.resetPinned:SetPoint("LEFT", f.resetHidden, "RIGHT", 12, 0)
    f.resetHistory = MakeSettingsButton(f.maintenanceSection, "Clear History", 138, function() if EL.ConfirmResetSessionHistory then EL:ConfirmResetSessionHistory() end end)
    f.resetHistory:SetPoint("TOPLEFT", 12, -164)
    f.resetLifetimeStats = MakeSettingsButton(f.maintenanceSection, "Reset Lifetime", 138, function() if EL.ConfirmResetLifetimeSessionStats then EL:ConfirmResetLifetimeSessionStats() end end)
    f.resetLifetimeStats:SetPoint("LEFT", f.resetHistory, "RIGHT", 12, 0)
    f.removeHiddenData = MakeSettingsButton(f.maintenanceSection, "Remove Hidden", 138, function() if EL.ConfirmRemoveHiddenCharacterData then EL:ConfirmRemoveHiddenCharacterData() end end)
    f.removeHiddenData:SetPoint("TOPLEFT", 12, -198)
    f.showWelcome = MakeSettingsButton(f.maintenanceSection, "Show Welcome", 138, function() if EL.ShowOnboardingPanel then EL:ShowOnboardingPanel(true) end end)
    f.showWelcome:SetPoint("LEFT", f.removeHiddenData, "RIGHT", 12, 0)
    SetSettingsTooltip(f.resetUISettings, "Reset UI Settings", {"Restores EmberLedger UI options, thresholds, window positions, scales, launcher, minimap, and action-bar settings to defaults.", "Tracked characters, cooldowns, mulch data, session history, hidden characters, and pinned characters are kept."})
    SetSettingsTooltip(f.resetPos, "Reset Windows", {"Returns EmberLedger windows to their default screen positions.", "Scale and visibility settings are kept."})
    SetSettingsTooltip(f.resetSession, "Reset Session", {"Clears current session totals and tracked items."})
    SetSettingsTooltip(f.resetHidden, "Unhide All", {"Restores every hidden character to the main window table."})
    SetSettingsTooltip(f.resetPinned, "Reset Pinned", {"Removes all pinned character markers without deleting character data."})
    SetSettingsTooltip(f.resetHistory, "Clear History", {"Deletes all saved account-wide session history data.", "This does not reset the current active session."})
    SetSettingsTooltip(f.resetLifetimeStats, "Reset Lifetime", {"Resets only the lifetime aggregate stats.", "Session history and the current active session are not deleted."})
    SetSettingsTooltip(f.removeHiddenData, "Remove Hidden", {"Deletes EmberLedger saved data for characters currently hidden from the main table.", "This is useful for deleted or permanently retired alts and cannot be undone."})
    SetSettingsTooltip(f.showWelcome, "Show Welcome", {"Reopens the EmberLedger getting started guide.", "Useful for reviewing how profession characters are scanned."})

    f.footerSection = MakeSettingsSection(f, T("Information"), contentX, -846, contentW, 78)
    f.versionLabel = f.footerSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.versionLabel:SetPoint("TOPLEFT", 12, -34)
    f.versionLabel:SetText(T("Version: %s", tostring(EL.version or "2.0.0")))
    f.versionLabel:SetTextColor(ThemeMutedTextRGB())
    RegisterThemeText(f.versionLabel, "themeMutedTextWidgets")

    f.allSettingsSections = {
        f.generalSection,
        f.appearanceSection,
        f.scaleSection,
        f.moduleSection,
        f.mainWindowTogglesSection,
        f.thresholdSection,
        f.profThresholdSection,
        f.trackingColumnsSection,
        f.nextColumnSection,
        f.cooldownColumnSection,
        f.launcherSection,
        f.sessionOptions,
        f.craftedItemsSection,
        f.actionPlacementSection,
        f.actionButtonsSection,
        f.performanceSection,
        f.maintenanceSection,
        f.footerSection,
    }
    f.settingsPages = {
        General = {f.generalSection, f.appearanceSection, f.scaleSection, f.footerSection},
        Launcher = {f.launcherSection},
        Session = {f.sessionOptions, f.craftedItemsSection},
        Modules = {f.moduleSection},
        Thresholds = {f.thresholdSection, f.profThresholdSection},
        ["Main Window"] = {f.mainWindowTogglesSection, f.trackingColumnsSection, f.nextColumnSection, f.cooldownColumnSection},
        ["Action Bar"] = {f.actionPlacementSection, f.actionButtonsSection},
        Maintenance = {f.performanceSection, f.maintenanceSection},
    }

    -- The sidebar is now a real category menu. Show one module at a time rather than
    -- stacking every option into one oversized page.
    self:SelectSettingsPage("General")
    return f
end


-- ============================================================================
-- Options Panel Runtime Methods
--
-- These methods refresh the options window, switch pages, and expose the panel
-- through slash commands, minimap interactions, and launcher buttons.
-- ============================================================================

function EL:UpdateSettingsNavHighlight()
    local f = self.settingsPanel
    if not f or not f.navLabels then return end
    local accentR, accentG, accentB = ThemeAccentRGB()
    local borderR, borderG, borderB = ThemeBorderRGB()
    for _, row in ipairs(f.navLabels) do
        local selected = f.currentPage == row.pageName
        if row.SetBackdropColor then
            row:SetBackdropColor(selected and (accentR * 0.34) or 0.02, selected and (accentG * 0.18) or 0.018, selected and (accentB * 0.12) or 0.030, selected and 0.82 or 0.20)
        end
        if row.SetBackdropBorderColor then
            row:SetBackdropBorderColor(borderR, borderG, borderB, selected and 0.66 or 0.10)
        end
        if row.selectedBar then
            row.selectedBar:SetShown(selected and true or false)
            if row.selectedBar.SetColorTexture then row.selectedBar:SetColorTexture(accentR, accentG, accentB, 0.78) end
        end
        if row.icon and row.icon.SetVertexColor then row.icon:SetVertexColor(1.00, 1.00, 1.00, selected and 1.00 or 0.86) end
        if row.text then
            row.text:SetFontObject(selected and GameFontNormalSmall or GameFontHighlightSmall)
            local tr, tg, tb = ThemeTextRGB(); row.text:SetTextColor(selected and accentR or tr, selected and accentG or tg, selected and accentB or tb)
        end
    end
end

function EL:SelectSettingsPage(pageName)
    local f = self.settingsPanel
    if not f then return end
    pageName = pageName or f.currentPage or "General"
    if pageName == "Actions" then pageName = "Action Bar" end
    if pageName == "Tracking" then pageName = "Main Window" end
    if pageName == "Display" then pageName = "General" end
    f.currentPage = pageName

    if f.allSettingsSections then
        for _, section in ipairs(f.allSettingsSections) do
            if section then section:Hide() end
        end
    end

    local sections = f.settingsPages and f.settingsPages[pageName]
    if sections then
        local contentX = 168
        local y = -64
        local spacing = 14
        for _, section in ipairs(sections) do
            if section then
                section:ClearAllPoints()
                section:SetPoint("TOPLEFT", f, "TOPLEFT", contentX, y)
                section:Show()
                y = y - section:GetHeight() - spacing
            end
        end
    end

    if self.UpdateSettingsNavHighlight then self:UpdateSettingsNavHighlight() end
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
end

function EL:RefreshSettingsPanel()
    local f = self.settingsPanel
    if not f then return end
    if f.IsShown and not f:IsShown() then return end
    local display = self.db and self.db.settings and self.db.settings.display or {}
    local alerts = self.db and self.db.settings and self.db.settings.alerts or {}
    if f.panelOpacityValue then f.panelOpacityValue:SetText(string.format("%d%%", math.floor((tonumber(display.panelOpacity) or 0.55) * 100 + 0.5))) end
    if f.launcherOpacityValue then f.launcherOpacityValue:SetText(string.format("%d%%", math.floor((tonumber(display.launcherOpacity) or 0.50) * 100 + 0.5))) end
    if f.sessionOpacityValue then f.sessionOpacityValue:SetText(string.format("%d%%", math.floor((tonumber(display.sessionOpacity) or 0.55) * 100 + 0.5))) end
    if f.thresholdValue then f.thresholdValue:SetText(tostring(tonumber(alerts.concentrationThreshold) or self.CONCENTRATION_THRESHOLD_DEFAULT or 900)) end
    if f.moxieThresholdValue then f.moxieThresholdValue:SetText(tostring(tonumber(alerts.moxieThreshold) or (EL.MOXIE_THRESHOLD_DEFAULT or 600))) end
    SetSliderValue(f.panelOpacitySlider, math.floor((tonumber(display.panelOpacity) or 0.55) * 100 + 0.5))
    SetSliderValue(f.launcherOpacitySlider, math.floor((tonumber(display.launcherOpacity) or 0.50) * 100 + 0.5))
    SetSliderValue(f.sessionOpacitySlider, math.floor((tonumber(display.sessionOpacity) or 0.55) * 100 + 0.5))
    ApplyThemeTextCollections(f) -- keep all option tabs theme text refreshed
    SetSliderValue(f.thresholdSlider, tonumber(alerts.concentrationThreshold) or self.CONCENTRATION_THRESHOLD_DEFAULT or 900)
    SetSliderValue(f.moxieThresholdSlider, tonumber(alerts.moxieThreshold) or (EL.MOXIE_THRESHOLD_DEFAULT or 600))
    if f.profThresholdSliders then
        for _, slider in ipairs(f.profThresholdSliders) do
            local value = alerts.professionThresholds and alerts.professionThresholds[slider.professionID] or 0
            SetSliderValue(slider, tonumber(value) or 0)
        end
    end
    SetSliderValue(f.scaleSlider, math.floor(((self.db.settings.panel and tonumber(self.db.settings.panel.scale)) or 1) * 100 + 0.5))
    SetSliderValue(f.sessionScaleSlider, math.floor(((self.db.settings.session and tonumber(self.db.settings.session.scale)) or 1) * 100 + 0.5))
    SetSliderValue(f.historyMaxEntriesSlider, (self.GetSessionHistoryMaxEntries and self:GetSessionHistoryMaxEntries()) or 500)
    local function setToggle(btn, on)
        if not btn then return end
        if btn.SetChecked then btn:SetChecked(on and true or false) end
        if btn.text then
            if on then
                btn.text:SetTextColor(ThemeTextRGB())
            else
                local r, g, b = ThemeMutedTextRGB()
                btn.text:SetTextColor(r * 0.72, g * 0.72, b * 0.72)
            end
        end
    end
    setToggle(f.showLauncher, self.db.settings.button and self.db.settings.button.shown ~= false)
    local minimapSettings = self.db.settings.minimap or {}
    setToggle(f.showMinimapButton, minimapSettings.hide ~= true)
    setToggle(f.moduleMainWindow, self.db.settings.panel and self.db.settings.panel.charactersShown ~= false)
    setToggle(f.moduleSessionTracking, self.db.settings.performance and self.db.settings.performance.sessionTracking ~= false)
    setToggle(f.moduleActionBar, self.db.settings.performance and self.db.settings.performance.actionBar ~= false)
    setToggle(f.moduleLauncher, self.db.settings.button and self.db.settings.button.shown ~= false)
    setToggle(f.moduleMinimap, minimapSettings.hide ~= true)
    setToggle(f.toggleConc, display.showLauncherConc ~= false)
    setToggle(f.toggleMulch, display.showLauncherMulch ~= false)
    setToggle(f.toggleCooldown, display.showLauncherCooldown == true)
    setToggle(f.toggleSession, display.showLauncherSession ~= false)
    setToggle(f.toggleTotal, display.showLauncherSessionTotal ~= false)
    setToggle(f.toggleTime, display.showLauncherSessionTime ~= false)
    local trackingDisplay = self:GetTrackingColumnSettings()
    setToggle(f.toggleProf1Column, trackingDisplay.showProfession1Column ~= false)
    setToggle(f.toggleConc1Column, trackingDisplay.showConcentration1Column ~= false)
    setToggle(f.toggleProf2Column, trackingDisplay.showProfession2Column ~= false)
    setToggle(f.toggleConc2Column, trackingDisplay.showConcentration2Column ~= false)
    setToggle(f.toggleMoxieColumn, trackingDisplay.showMoxieColumn == true)
    setToggle(f.toggleMulchColumn, trackingDisplay.showMulchColumn ~= false)
    setToggle(f.toggleCooldownColumn, trackingDisplay.showCooldownColumn ~= false)
    if f.cooldownScopeDropdown and f.cooldownScopeDropdown.RefreshSelection then
        f.cooldownScopeDropdown:RefreshSelection()
    end
    if f.cooldownVisibilityDropdown and f.cooldownVisibilityDropdown.RefreshSelection then
        f.cooldownVisibilityDropdown:RefreshSelection()
    end
    setToggle(f.toggleForecastColumn, trackingDisplay.showForecastColumn == true)
    setToggle(f.toggleCharacterRealm, display.showCharacterRealm ~= false)
    setToggle(f.toggleAttentionOnly, display.attentionOnly == true)
    setToggle(f.toggleCompactMode, display.compactMode == true)
    setToggle(f.toggleCurrentCharacterFirst, display.showCurrentCharacterFirst == true)
    setToggle(f.togglePinnedFirst, display.showPinnedFirst ~= false)
    setToggle(f.toggleCurrentCharacterHighlight, display.highlightCurrentCharacter ~= false)
    local panelSettings = self.db.settings.panel or {}
    local sessionSettings = self.db.settings.session or {}
    local performanceSettings = self.db.settings.performance or {}
    setToggle(f.enableSessionTracking, performanceSettings.sessionTracking ~= false)
    setToggle(f.enableActionBar, performanceSettings.actionBar ~= false)
    setToggle(f.toggleCharactersSection, panelSettings.charactersShown ~= false)
    setToggle(f.toggleSessionSection, sessionSettings.shown ~= false)
    local actionButtons = panelSettings.actionButtons or {}
    setToggle(f.actionMulchButton, actionButtons.mulch ~= false)
    setToggle(f.actionSeedButton, actionButtons.seed ~= false)
    setToggle(f.actionGlowingSeedButton, actionButtons.glowingSeed ~= false)
    setToggle(f.actionWildSeedButton, actionButtons.wildSeed ~= false)
    setToggle(f.actionPrimalSeedButton, actionButtons.primalSeed ~= false)
    setToggle(f.actionGreenThumbButton, actionButtons.greenThumb ~= false)
    setToggle(f.actionOverloadHerbButton, actionButtons.overloadHerb ~= false)
    setToggle(f.actionOverloadOreButton, actionButtons.overloadOre ~= false)
    setToggle(f.actionParcelButton, actionButtons.parcel ~= false)
    setToggle(f.actionBankButton, actionButtons.bank ~= false)
    setToggle(f.actionBarFloating, panelSettings.actionBarFloating == true)
    setToggle(f.actionBarLocked, panelSettings.actionBarLocked == true)
    local actionControlsAlpha = (performanceSettings.actionBar ~= false) and 1.0 or 0.45
    for _, btn in ipairs({ f.actionBarFloating, f.actionBarLocked, f.resetActionBarPosition, f.actionMulchButton, f.actionSeedButton, f.actionGlowingSeedButton, f.actionWildSeedButton, f.actionPrimalSeedButton, f.actionGreenThumbButton, f.actionOverloadHerbButton, f.actionOverloadOreButton, f.actionParcelButton, f.actionBankButton }) do
        if btn and btn.SetAlpha then btn:SetAlpha(actionControlsAlpha) end
    end
    if f.actionBarDisabledTip then f.actionBarDisabledTip:SetShown(performanceSettings.actionBar == false) end
    local sessionControlsAlpha = (performanceSettings.sessionTracking ~= false) and 1.0 or 0.45
    for _, btn in ipairs({ f.toggleSessionSection, f.filterHerbs, f.filterOre, f.filterCloth, f.filterLeather, f.filterEnchanting, f.filterFish, f.filterOther, f.trackRawGoldGains, f.trackGoldSpent, f.countTrustedMailRewards, f.countCraftedItems, f.toggleSessionHistory, f.resetSession, f.historyMaxEntriesSlider }) do
        if btn and btn.SetAlpha then btn:SetAlpha(sessionControlsAlpha) end
    end
    if f.sessionDisabledTip then f.sessionDisabledTip:SetShown(performanceSettings.sessionTracking == false) end
    setToggle(f.filterHerbs, sessionSettings.trackHerbs ~= false)
    setToggle(f.filterOre, sessionSettings.trackOre ~= false)
    setToggle(f.filterCloth, sessionSettings.trackCloth ~= false)
    setToggle(f.filterLeather, sessionSettings.trackLeather ~= false)
    setToggle(f.filterEnchanting, sessionSettings.trackEnchanting ~= false)
    setToggle(f.filterFish, sessionSettings.trackFish ~= false)
    setToggle(f.filterOther, sessionSettings.trackOtherMaterials ~= false)
    setToggle(f.trackRawGoldGains, sessionSettings.trackRawGoldGains ~= false)
    setToggle(f.trackGoldSpent, sessionSettings.trackGoldSpent == true)
    setToggle(f.countTrustedMailRewards, sessionSettings.countTrustedMailRewards ~= false)
    setToggle(f.countCraftedItems, sessionSettings.countCraftedItems == true)
    if f.toggleSessionHistory and f.toggleSessionHistory.SetChecked then
        f.toggleSessionHistory:SetChecked((self.IsSessionHistoryEnabled and self:IsSessionHistoryEnabled()) or false)
    end
    if f.pricingSourceValue then
        f.pricingSourceValue:SetText((self.GetActivePricingSourceLabel and self:GetActivePricingSourceLabel()) or "Unknown")
    end
    local hiddenCount = self.CountHiddenCharacters and self:CountHiddenCharacters() or 0
    if f.hiddenStatus then
        f.hiddenStatus:SetText("Hidden characters: " .. tostring(hiddenCount))
        f.hiddenStatus:SetTextColor(hiddenCount > 0 and 1.00 or 0.72, hiddenCount > 0 and 0.86 or 0.72, hiddenCount > 0 and 0.48 or 0.68)
    end
    if f.resetHidden and f.resetHidden.SetAlpha then
        f.resetHidden:SetAlpha(hiddenCount > 0 and 1.0 or 0.55)
    end
    if f.removeHiddenData and f.removeHiddenData.SetAlpha then
        f.removeHiddenData:SetAlpha(hiddenCount > 0 and 1.0 or 0.55)
    end
    local locked = self.db.settings.lockWindows == true
    if f.lockWindows and f.lockWindows.text then
        f.lockWindows.text:SetText(locked and "Lock windows: On" or "Lock windows: Off")
    end
    setToggle(f.lockWindows, locked)
end


function EL:ShowSettingsPanel()
    if not self.settingsPanel then self:CreateSettingsPanel(UIParent) end
    self.settingsPanel:SetParent(UIParent)
    self.settingsPanel:SetScale(1)
    self.settingsPanel:ClearAllPoints()
    self.db.settings.options = self.db.settings.options or {}
    if self.db.settings.options.point then
        SetFramePointFromDB(self.settingsPanel, self.db.settings.options)
    else
        self.settingsPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    self.settingsPanel:Show()
    BringEmberWindowToFront(self.settingsPanel)
    self:SelectSettingsPage(self.settingsPanel.currentPage or "General")
    self:RefreshSettingsPanel()
end

function EL:ToggleSettingsPanel()
    if self.settingsPanel and self.settingsPanel:IsShown() then
        self.settingsPanel:Hide()
    else
        if self.ShowSettingsPanel then self:ShowSettingsPanel() end
    end
end

function EL:MatchOpacityToMainWindow()
    self.db.settings.display = self.db.settings.display or {}
    local mainOpacity = math.max(0.20, math.min(1.00, tonumber(self.db.settings.display.panelOpacity) or 0.55))
    self.db.settings.display.launcherOpacity = mainOpacity
    self.db.settings.display.sessionOpacity = mainOpacity
    self:ApplyDisplaySettings()
    self:RefreshSettingsPanel()
    self:RequestUpdate()
end

function EL:ResetOpacityDefaults()
    self.db.settings.display = self.db.settings.display or {}
    self.db.settings.display.launcherOpacity = 0.50
    self.db.settings.display.panelOpacity = 0.55
    self.db.settings.display.sessionOpacity = 0.55
    self:ApplyDisplaySettings()
    self:RefreshSettingsPanel()
    self:RequestUpdate()
end

function EL:SetAbsoluteSetting(kind, value)
    self.db.settings.display = self.db.settings.display or {}
    self.db.settings.alerts = self.db.settings.alerts or {}
    self.db.settings.panel = self.db.settings.panel or {}
    self.db.settings.session = self.db.settings.session or {}
    if kind == "panelOpacity" then
        self.db.settings.display.panelOpacity = math.max(0.20, math.min(1.00, tonumber(value) or 0.55))
    elseif kind == "launcherOpacity" then
        self.db.settings.display.launcherOpacity = math.max(0.20, math.min(1.00, tonumber(value) or 0.50))
    elseif kind == "sessionOpacity" then
        self.db.settings.display.sessionOpacity = math.max(0.20, math.min(1.00, tonumber(value) or 0.55))
    elseif kind == "concThreshold" then
        self.db.settings.alerts.concentrationThreshold = math.max(0, math.min(1000, math.floor((tonumber(value) or self.CONCENTRATION_THRESHOLD_DEFAULT or 900) + 0.5)))
    elseif kind == "moxieThreshold" then
        self.db.settings.alerts.moxieThreshold = math.max(0, math.min(1000, math.floor((tonumber(value) or (EL.MOXIE_THRESHOLD_DEFAULT or 600)) + 0.5)))
    elseif kind == "panelScale" then
        self.db.settings.panel.scale = math.max(PANEL_MIN_SCALE, math.min(PANEL_MAX_SCALE, tonumber(value) or 1))
        if self.ApplyPanelScale then self:ApplyPanelScale() end
    elseif kind == "sessionScale" then
        self.db.settings.session.scale = math.max(PANEL_MIN_SCALE, math.min(PANEL_MAX_SCALE, tonumber(value) or 1))
        if self.sessionWindow then self.sessionWindow:SetScale(self.db.settings.session.scale) end
        if self.LayoutSessionWindow then self:LayoutSessionWindow() end
    end
    self:ApplyDisplaySettings()
    self:RefreshSettingsPanel()
    if kind == "concThreshold" or kind == "moxieThreshold" then
        if self.UpdateSortHeaders then self:UpdateSortHeaders() end
        self:RequestUpdate(true)
    else
        self:RequestUpdate()
    end
end

function EL:AdjustSetting(kind, delta)
    self.db.settings.display = self.db.settings.display or {}
    self.db.settings.alerts = self.db.settings.alerts or {}
    if kind == "panelOpacity" then
        local v = tonumber(self.db.settings.display.panelOpacity) or 0.55
        self.db.settings.display.panelOpacity = math.max(0.20, math.min(1.00, v + (delta or 0)))
    elseif kind == "launcherOpacity" then
        local v = tonumber(self.db.settings.display.launcherOpacity) or 0.50
        self.db.settings.display.launcherOpacity = math.max(0.20, math.min(1.00, v + (delta or 0)))
    elseif kind == "sessionOpacity" then
        local v = tonumber(self.db.settings.display.sessionOpacity) or 0.55
        self.db.settings.display.sessionOpacity = math.max(0.20, math.min(1.00, v + (delta or 0)))
    elseif kind == "concThreshold" then
        local v = tonumber(self.db.settings.alerts.concentrationThreshold) or self.CONCENTRATION_THRESHOLD_DEFAULT or 900
        self.db.settings.alerts.concentrationThreshold = math.max(0, math.min(1000, v + (delta or 0)))
    elseif kind == "moxieThreshold" then
        local v = tonumber(self.db.settings.alerts.moxieThreshold) or (EL.MOXIE_THRESHOLD_DEFAULT or 600)
        self.db.settings.alerts.moxieThreshold = math.max(0, math.min(1000, v + (delta or 0)))
    elseif kind == "panelScale" then
        self.db.settings.panel = self.db.settings.panel or {}
        local v = tonumber(self.db.settings.panel.scale) or 1
        self.db.settings.panel.scale = math.max(PANEL_MIN_SCALE, math.min(PANEL_MAX_SCALE, v + (delta or 0)))
        if self.ApplyPanelScale then self:ApplyPanelScale() end
    elseif kind == "sessionScale" then
        self.db.settings.session = self.db.settings.session or {}
        local v = tonumber(self.db.settings.session.scale) or 1
        self.db.settings.session.scale = math.max(PANEL_MIN_SCALE, math.min(PANEL_MAX_SCALE, v + (delta or 0)))
        if self.sessionWindow then self.sessionWindow:SetScale(self.db.settings.session.scale) end
        if self.LayoutSessionWindow then self:LayoutSessionWindow() end
    end
    self:ApplyDisplaySettings()
    self:RefreshSettingsPanel()
    if kind == "concThreshold" or kind == "moxieThreshold" then
        -- Force an immediate visible recolor when a threshold changes.
        if self.UpdateSortHeaders then self:UpdateSortHeaders() end
        self:RequestUpdate(true)
    else
        self:RequestUpdate()
    end
end

local DISPLAY_TOGGLE_LABELS = {
    showLauncherConc = "Launcher concentration alert",
    showLauncherMulch = "Launcher mulch line",
    showLauncherCooldown = "Launcher next cooldown line",
    showLauncherSession = "Launcher session rate",
    showLauncherSessionTotal = "Launcher session total",
    showLauncherSessionTime = "Launcher session time",
    showCharacterRealm = "Character realm display",
    attentionOnly = "Attention Only view",
    compactMode = "Compact Mode",
    showCurrentCharacterFirst = "Current character first",
    showPinnedFirst = "Pinned first sorting",
    highlightCurrentCharacter = "Current character highlight",
}

local SESSION_FILTER_LABELS = {
    trackHerbs = "Herb tracking",
    trackOre = "Ore tracking",
    trackCloth = "Cloth tracking",
    trackLeather = "Leather/skin tracking",
    trackEnchanting = "Enchanting material tracking",
    trackFish = "Fish tracking",
    trackOtherMaterials = "Other profession material tracking",
}

local SECTION_TOGGLE_LABELS = {
    characters = "Main window",
    session = "Session window",
}

local function OnOffText(value)
    return value and T("ON") or T("OFF")
end

function EL:NotifyToggle(label, enabled)
    if not label then return end
    self:Print(T(tostring(label)) .. " " .. OnOffText(enabled))
end


local TRACKING_COLUMN_TOGGLE_LABELS = {
    prof = "Prof 1 column",
    conc = "Conc 1 column",
    prof1 = "Prof 1 column",
    conc1 = "Conc 1 column",
    prof2 = "Prof 2 column",
    conc2 = "Conc 2 column",
    moxie = "Moxie column",
    cooldown = "Cooldown readiness column",
    mulch = "Mulch column",
    forecast = "Next column",
}


local TRACKING_COLUMN_DEFS = {
    { key = "prof1", setting = "showProfession1Column" },
    { key = "conc1", setting = "showConcentration1Column" },
    { key = "prof2", setting = "showProfession2Column", secondary = true },
    { key = "conc2", setting = "showConcentration2Column", secondary = true },
    { key = "forecast", setting = "showForecastColumn" },
    { key = "moxie", setting = "showMoxieColumn" },
    { key = "cooldown", setting = "showCooldownColumn" },
    { key = "mulch", setting = "showMulchColumn" },
}

local TRACKING_COLUMN_SETTING_KEYS = {
    prof = "showProfession1Column",
    conc = "showConcentration1Column",
    prof1 = "showProfession1Column",
    conc1 = "showConcentration1Column",
    prof2 = "showProfession2Column",
    conc2 = "showConcentration2Column",
    moxie = "showMoxieColumn",
    mulch = "showMulchColumn",
    cooldown = "showCooldownColumn",
    forecast = "showForecastColumn",
}

function EL:ToggleTrackingColumn(key)
    local settingKey = TRACKING_COLUMN_SETTING_KEYS[key]
    if not settingKey then return end
    self.db = self.db or {}
    self.db.settings = self.db.settings or {}
    self.db.settings.display = self.db.settings.display or {}
    local display = self.db.settings.display
    local enabled = not (display[settingKey] ~= false)
    if not enabled then
        local remaining = 0
        local hasSecondaryData = self:HasSecondaryConcentrationColumnData()
        for _, def in ipairs(TRACKING_COLUMN_DEFS or {}) do
            if def.setting and def.setting ~= settingKey and display[def.setting] ~= false and (not def.secondary or hasSecondaryData) then
                remaining = remaining + 1
            end
        end
        if remaining <= 0 then
            display[settingKey] = true
            self:Print(T("At least one optional tracking column must remain visible."))
            self:RefreshSettingsPanel()
            return
        end
    end
    display[settingKey] = enabled
    self:Print(T(TRACKING_COLUMN_TOGGLE_LABELS[key] or key) .. " " .. OnOffText(enabled))
    if key == "prof" then key = "prof1" end
    if key == "conc" then key = "conc1" end
    local sort = self:GetSortSettings()
    if sort and sort.key == key and not enabled then
        sort.key = "character"
        sort.ascending = true
    end
    if self.AutoSizeTrackingPanel then self:AutoSizeTrackingPanel("columnToggle") end
    self:RefreshSettingsPanel()
    if self.LayoutPanel then self:LayoutPanel() end
    self:RequestUpdate()
end

function EL:ToggleDisplaySetting(key)
    self.db.settings.display = self.db.settings.display or {}
    local currentlyEnabled = self.db.settings.display[key] ~= false
    local enabled = not currentlyEnabled
    self.db.settings.display[key] = enabled
    self:NotifyToggle(DISPLAY_TOGGLE_LABELS[key] or key, enabled)
    if (key == "showCharacterRealm" or key == "attentionOnly" or key == "compactMode" or key == "showPinnedFirst") and self.AutoSizeTrackingPanel then
        self:AutoSizeTrackingPanel(key .. "Toggle")
    end
    self:RefreshSettingsPanel()
    if self.LayoutPanel then self:LayoutPanel() end
    if key == "showCurrentCharacterFirst" or key == "highlightCurrentCharacter" then
        self:RequestUpdate(true)
    else
        self:RequestUpdate()
    end
end

function EL:ToggleSessionFilterSetting(key)
    self.db.settings.session = self.db.settings.session or {}
    local enabled = not (self.db.settings.session[key] ~= false)
    self.db.settings.session[key] = enabled
    self:NotifyToggle(SESSION_FILTER_LABELS[key] or key, enabled)
    if self:IsSessionTrackingEnabled() and self.CountSessionItemsInBags then
        local s = self:GetSessionDB()
        s.lastBagCounts = self:CountSessionItemsInBags()
        s.bagBaselineReady = true
    end
    if self.RefreshSessionPanel then self:RefreshSessionPanel() end
    self:RefreshSettingsPanel()
    self:RequestUpdate()
end

function EL:ToggleSessionMoneySetting(key, defaultOn, label)
    self.db.settings.session = self.db.settings.session or {}
    local current = self.db.settings.session[key]
    local enabled
    if defaultOn then
        enabled = not (current ~= false)
    else
        enabled = not (current == true)
    end
    self.db.settings.session[key] = enabled
    if key == "countCraftedItems" and self.GetSessionDB then
        local s = self:GetSessionDB()
        s.pendingCraftedItems = {}
        if self.CountSessionItemsInBags then
            s.lastBagCounts = self:CountSessionItemsInBags()
            s.bagBaselineReady = true
        end
    end
    if self.SyncSessionMoneyBaseline then self:SyncSessionMoneyBaseline() end
    self:NotifyToggle(label or key, enabled)
    if self.RefreshSessionPanel then self:RefreshSessionPanel() end
    self:RefreshSettingsPanel()
    self:RequestUpdate()
end


function EL:ToggleLockWindows()
    self.db.settings.lockWindows = not (self.db.settings.lockWindows == true)
    self:RefreshSettingsPanel()
    self:Print("Windows " .. (self.db.settings.lockWindows and "locked. Hold Shift and drag to move them." or "unlocked."))
end

local PERFORMANCE_TOGGLE_LABELS = {
    sessionTracking = "Session tracking",
    actionBar = "Action bar system",
}

function EL:TogglePerformanceSetting(key)
    if not key then return end
    self.db.settings.performance = self.db.settings.performance or {}
    local enabled = not (self.db.settings.performance[key] ~= false)
    self.db.settings.performance[key] = enabled
    self:NotifyToggle(PERFORMANCE_TOGGLE_LABELS[key] or key, enabled)

    if key == "sessionTracking" then
        self.db.settings.session = self.db.settings.session or {}
        local sessionSettings = self.db.settings.session
        if enabled then
            if self.AutoStartSessionOnLogin then self:AutoStartSessionOnLogin() end
            local s = self.GetSessionDB and self:GetSessionDB()
            if s and self.CountSessionItemsInBags then
                s.lastBagCounts = self:CountSessionItemsInBags()
                s.bagBaselineReady = true
                s.baselinePrimingUntil = nil
            end
            local shouldReopen = sessionSettings.reopenAfterPerformanceEnable == true
            sessionSettings.reopenAfterPerformanceEnable = nil
            if shouldReopen then
                sessionSettings.shown = true
                sessionSettings.windowOpen = true
                if self.ShowSessionWindow then self:ShowSessionWindow() elseif self.ShowSessionWindowFromSavedState then self:ShowSessionWindowFromSavedState() end
            elseif self.RefreshSessionPanel then
                self:RefreshSessionPanel()
            end
        else
            sessionSettings.reopenAfterPerformanceEnable = (self.sessionWindow and self.sessionWindow:IsShown()) or sessionSettings.windowOpen == true
            if self.HideSessionWindow then
                self:HideSessionWindow(true)
            elseif self.sessionWindow then
                self.sessionWindow:Hide()
            end
            sessionSettings.windowOpen = false
        end
    elseif key == "actionBar" then
        if self.IsCombatLocked and self:IsCombatLocked() then
            if self.QueueCombatDeferredWork then self:QueueCombatDeferredWork("layout") end
            if self.RequestActionBarRefresh then self:RequestActionBarRefresh(true) end
        else
            if self.LayoutActionBar then self:LayoutActionBar() end
            if enabled then
                if self:IsActionBarEnabled() and self.RequestActionBarRefresh then self:RequestActionBarRefresh(true) end
            else
                local bar = self.GetActionBarFrame and self:GetActionBarFrame() or (self.panel and self.panel.actionBar)
                if bar then bar:Hide() end
            end
            if self.LayoutPanel then self:LayoutPanel() end
            if self.AutoSizePanelHeight then self:AutoSizePanelHeight("actionBarPerformanceToggle") end
        end
    end

    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
    if self.RequestUpdate then self:RequestUpdate() end
end

function EL:ToggleActionBarButton(key, label)
    if not key then return end
    self.db.settings.panel = self.db.settings.panel or {}
    self.db.settings.panel.actionButtons = self.db.settings.panel.actionButtons or {}
    local buttons = self.db.settings.panel.actionButtons
    buttons[key] = not (buttons[key] ~= false)
    self:NotifyToggle(label or key, buttons[key] ~= false)
    if self:IsActionBarEnabled() and self.RequestActionBarRefresh then self:RequestActionBarRefresh() end
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
    if self.RequestUpdate then self:RequestUpdate() end
end

function EL:ToggleActionBarFloating()
    self.db.settings.panel = self.db.settings.panel or {}
    local panelSettings = self.db.settings.panel
    panelSettings.actionBarFloating = not (panelSettings.actionBarFloating == true)
    self:NotifyToggle("Floating action bar", panelSettings.actionBarFloating == true)
    if self.IsCombatLocked and self:IsCombatLocked() then
        if self.QueueCombatDeferredWork then self:QueueCombatDeferredWork("layout") end
        self:Print("Action bar placement will update after combat.")
    else
        if self.LayoutActionBar then self:LayoutActionBar() end
        if self.LayoutPanel then self:LayoutPanel() end
        if self.AutoSizePanelHeight then self:AutoSizePanelHeight("actionBarFloatingToggle") end
        if self.RequestActionBarRefresh then self:RequestActionBarRefresh(true) end
    end
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
end

function EL:ToggleFloatingActionBarLocked()
    self.db.settings.panel = self.db.settings.panel or {}
    local panelSettings = self.db.settings.panel
    panelSettings.actionBarLocked = not (panelSettings.actionBarLocked == true)
    self:NotifyToggle("Floating action bar lock", panelSettings.actionBarLocked == true)
    if self.IsCombatLocked and self:IsCombatLocked() then
        if self.QueueCombatDeferredWork then self:QueueCombatDeferredWork("layout") end
    else
        if self.LayoutActionBar then self:LayoutActionBar() end
    end
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
end

function EL:ResetFloatingActionBarPosition()
    self.db.settings.panel = self.db.settings.panel or {}
    self.db.settings.panel.actionBarPosition = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -160 }
    if self.IsCombatLocked and self:IsCombatLocked() then
        if self.QueueCombatDeferredWork then self:QueueCombatDeferredWork("layout") end
        if self.RequestActionBarRefresh then self:RequestActionBarRefresh(true) end
        self:Print("Floating action bar position will reset after combat.")
        return
    end
    if self.LayoutActionBar then self:LayoutActionBar() end
    if self.RequestActionBarRefresh then self:RequestActionBarRefresh(true) end
    self:Print("Floating action bar position reset.")
end

function EL:ToggleSectionSetting(section)
    self.db.settings.panel = self.db.settings.panel or {}
    self.db.settings.session = self.db.settings.session or {}
    if section == "launcher" then
        self.db.settings.button = self.db.settings.button or {}
        self.db.settings.button.shown = not (self.db.settings.button.shown ~= false)
        self:NotifyToggle("Launcher", self.db.settings.button.shown ~= false)
        if self.button then
            if self.db.settings.button.shown ~= false then self.button:Show() else self.button:Hide() end
        end
        if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
    elseif section == "characters" then
        local shouldShow = not (self.db.settings.panel.charactersShown ~= false)
        if not shouldShow and self.SaveExpandedPanelHeight then
            self:SaveExpandedPanelHeight()
        end
        self.db.settings.panel.charactersShown = shouldShow
        self.db.settings.panel.charactersCollapsed = false
        self.db.settings.panel.windowOpen = shouldShow
        self:NotifyToggle(SECTION_TOGGLE_LABELS.characters, shouldShow)
        if shouldShow then
            if self.ShowPanelFromSavedState then self:ShowPanelFromSavedState() end
        else
            if self.panel then self.panel:Hide() end
        end
    elseif section == "session" then
        self.db.settings.session.shown = not (self.db.settings.session.shown ~= false)
        self:NotifyToggle(SECTION_TOGGLE_LABELS.session, self.db.settings.session.shown ~= false)
        if self.db.settings.session.shown then
            if self.ShowSessionWindow then self:ShowSessionWindow() elseif self.ShowSessionWindowFromSavedState then self:ShowSessionWindowFromSavedState() end
        else
            if self.HideSessionWindow then
                self:HideSessionWindow(false)
            elseif self.sessionWindow then
                self.sessionWindow:Hide()
            end
        end
    end

    if section == "session" then
        -- Session is now a standalone window. Toggling it from options should
        -- not resize or relayout the main EmberLedger panel.
        if self.LayoutSessionWindow then self:LayoutSessionWindow() end
    else
        if self.LayoutPanel then self:LayoutPanel() end
        if self.AutoSizePanelHeight then self:AutoSizePanelHeight("sectionToggle") end
    end
    self:RefreshSettingsPanel()
    self:RequestUpdate()
end


-- ============================================================================
-- Options Panel Host Integration
-- ============================================================================

function EL:RegisterBlizzardSettings()
    if self.blizzardSettingsRegistered then return end
    self.blizzardSettingsRegistered = true

    local canvas = CreateFrame("Frame", "EmberLedgerBlizzardSettingsCanvas")
    canvas.name = T("EmberLedger")
    canvas:SetSize(620, 420)

    canvas.title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    canvas.title:SetPoint("TOP", 0, -55)
    canvas.title:SetText(T("EmberLedger"))
    canvas.title:SetTextColor(1.00, 0.42, 0.08)

    canvas.version = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    canvas.version:SetPoint("TOP", canvas.title, "BOTTOM", 0, -12)
    canvas.version:SetText(T("Version %s", tostring(self.version or "2.0.0")))

    canvas.desc = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    canvas.desc:SetPoint("TOP", canvas.version, "BOTTOM", 0, -16)
    canvas.desc:SetWidth(420)
    canvas.desc:SetJustifyH("CENTER")
    canvas.desc:SetText(T("Profession tracking, Imbued Mulch cooldowns, and session analytics for your alt army."))

    canvas.open = MakeSettingsButton(canvas, T("Open EmberLedger Settings"), 260, function()
        if EL.ShowSettingsPanel then EL:ShowSettingsPanel() elseif EL.ToggleSettingsPanel then EL:ToggleSettingsPanel() end
    end)
    canvas.open:SetPoint("TOP", canvas.desc, "BOTTOM", 0, -28)

    canvas.reset = MakeSettingsButton(canvas, "Reset Window Positions", 220, function()
        if EL.ConfirmResetWindowPositions then EL:ConfirmResetWindowPositions() elseif EL.ResetWindowPositions then EL:ResetWindowPositions() end
    end)
    canvas.reset:SetPoint("TOP", canvas.open, "BOTTOM", 0, -14)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(canvas, T("EmberLedger"))
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(canvas)
        self.settingsCategory = canvas
    end
end


-- ============================================================================
-- Options Panel Reset Helpers
--
-- These reset only UI/settings state and must not delete tracked characters,
-- cooldowns, mulch, moxie, session history, hidden characters, or pinned
-- characters.
-- ============================================================================

function EL:ResetUISettingsToDefaults()
    local settings = self.db and self.db.settings
    if not settings then return end
    local defaults = self.GetDefaultSettingsSnapshot and self:GetDefaultSettingsSnapshot() or nil
    if type(defaults) ~= "table" then return end

    local keepHidden = settings.hiddenCharacters
    local keepPinned = settings.favoriteCharacters
    local keepSessionHistory = settings.sessionHistory

    settings.sort = defaults.sort
    settings.button = defaults.button
    settings.panel = defaults.panel
    settings.session = defaults.session
    settings.alerts = defaults.alerts
    settings.display = defaults.display
    settings.performance = defaults.performance
    settings.minimap = defaults.minimap
    settings.options = defaults.options
    settings.lockWindows = defaults.lockWindows
    settings.debug = defaults.debug
    settings.onboardingSeen = defaults.onboardingSeen

    settings.hiddenCharacters = keepHidden or {}
    settings.favoriteCharacters = keepPinned or {}
    settings.sessionHistory = keepSessionHistory or {}

    if self.button then SetFramePointFromDB(self.button, settings.button) end
    if self.panel then
        self.panel:SetScale(tonumber(settings.panel.scale) or 1)
        SetFramePointFromDB(self.panel, settings.panel)
    end
    if self.sessionWindow then
        self.sessionWindow:SetScale(tonumber(settings.session.scale) or 1)
        SetFramePointFromDB(self.sessionWindow, settings.session)
    end
    if self.settingsPanel then
        SetFramePointFromDB(self.settingsPanel, settings.options)
    end

    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
    if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
    if self.ForEachModule then self:ForEachModule("Refresh") end
    if self.RefreshLayout then self:RefreshLayout("resetUISettings") end
    if self.RequestUpdate then self:RequestUpdate() end
    self:Print("UI settings reset to defaults. Tracked character and session data was kept.")
end
