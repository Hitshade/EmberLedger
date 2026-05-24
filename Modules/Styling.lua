local addonName, EL = ...

EL.Style = EL.Style or {}
local Style = EL.Style

local THEME = EL.THEME_COLORS or {}

local function ThemeValue(key, fallback)
    local colors = EL and EL.THEME_COLORS or THEME or {}
    return tonumber(colors[key]) or fallback
end

local function BorderRGB()
    return ThemeValue("BORDER_R", 0.42), ThemeValue("BORDER_G", 0.42), ThemeValue("BORDER_B", 0.44)
end

local function BackgroundRGB()
    return ThemeValue("BG_R", 0.020), ThemeValue("BG_G", 0.016), ThemeValue("BG_B", 0.040)
end

local function AccentRGB()
    return ThemeValue("ACCENT_R", 0.68), ThemeValue("ACCENT_G", 0.68), ThemeValue("ACCENT_B", 0.70)
end

local function GlowRGB()
    return ThemeValue("GLOW_R", 1.00), ThemeValue("GLOW_G", 0.46), ThemeValue("GLOW_B", 0.10)
end

Style.TrackingRowPalette = Style.TrackingRowPalette or {
    currentR = 0.42, currentG = 0.68, currentB = 1.00,
    currentBgAlpha = 0.145,
    currentBgAlphaCompact = 0.125,
    currentLineAlpha = 0.44,
    currentEdgeAlpha = 0.70,
    hoverR = 0.50, hoverG = 0.66, hoverB = 0.88,
    hoverAlpha = 0.075,
    currentHoverAlpha = 0.115,
}

function Style:GetTrackingRowPalette()
    return self.TrackingRowPalette
end

Style.MoxieTextColor = Style.MoxieTextColor or { r = 0.66, g = 0.78, b = 0.88 }

function Style:GetMoxieTextColor()
    local color = self.MoxieTextColor or {}
    return tonumber(color.r) or 0.66, tonumber(color.g) or 0.78, tonumber(color.b) or 0.88
end


function Style:ThemeColor(key, fallback)
    return ThemeValue(key, fallback)
end

function Style:ThemeAccentRGB()
    return AccentRGB()
end

function Style:ThemeBorderRGB()
    return BorderRGB()
end

function Style:ThemeTextRGB()
    return ThemeValue("TEXT_R", 0.88), ThemeValue("TEXT_G", 0.89), ThemeValue("TEXT_B", 0.91)
end

function Style:ThemeMutedTextRGB()
    return ThemeValue("MUTED_TEXT_R", 0.76), ThemeValue("MUTED_TEXT_G", 0.77), ThemeValue("MUTED_TEXT_B", 0.80)
end

function Style:ThemeValueTextRGB()
    return ThemeValue("VALUE_TEXT_R", 0.90), ThemeValue("VALUE_TEXT_G", 0.91), ThemeValue("VALUE_TEXT_B", 0.93)
end

function Style:RegisterThemeText(fontString, bucket, panel)
    if not fontString then return end
    panel = panel or (EL and EL.settingsPanel)
    if not panel then return end
    bucket = bucket or "themeTextWidgets"
    panel[bucket] = panel[bucket] or {}
    panel[bucket][#panel[bucket] + 1] = fontString
end

function Style:ApplyThemeTextCollections(frame)
    if not frame then return end
    local r, g, b = self:ThemeTextRGB()
    if frame.themeTextWidgets then
        for _, fs in ipairs(frame.themeTextWidgets) do
            if fs and fs.SetTextColor then fs:SetTextColor(r, g, b) end
        end
    end
    r, g, b = self:ThemeMutedTextRGB()
    if frame.themeMutedTextWidgets then
        for _, fs in ipairs(frame.themeMutedTextWidgets) do
            if fs and fs.SetTextColor then fs:SetTextColor(r, g, b) end
        end
    end
    r, g, b = self:ThemeValueTextRGB()
    if frame.themeValueTextWidgets then
        for _, fs in ipairs(frame.themeValueTextWidgets) do
            if fs and fs.SetTextColor then fs:SetTextColor(r, g, b) end
        end
    end
end

function Style:BringWindowToFront(frame)
    if not frame or not EL then return end

    if frame == EL.settingsPanel then
        EL._emberOptionsFrontLevel = (tonumber(EL._emberOptionsFrontLevel) or 500) + 10
        if EL._emberOptionsFrontLevel > 900 then
            EL._emberOptionsFrontLevel = 510
        end
        if frame.SetFrameStrata then frame:SetFrameStrata("DIALOG") end
        if frame.SetFrameLevel then frame:SetFrameLevel(EL._emberOptionsFrontLevel) end
        return
    end

    EL._emberWindowFrontLevel = (tonumber(EL._emberWindowFrontLevel) or 20) + 5
    if EL._emberWindowFrontLevel > 80 then
        EL._emberWindowFrontLevel = 25
    end
    if frame.SetFrameStrata then frame:SetFrameStrata("MEDIUM") end
    if frame.SetFrameLevel then frame:SetFrameLevel(EL._emberWindowFrontLevel) end
end

function EL:BringWindowToFront(frame)
    if self.Style and self.Style.BringWindowToFront then
        return self.Style:BringWindowToFront(frame)
    end
end

function Style:HideSessionHistoryDisplayDropdown()
    if EL and EL.sessionHistoryDisplayDropdown then
        EL.sessionHistoryDisplayDropdown:Hide()
    end
end

function Style:ShowSessionHistoryDisplayDropdown(anchor)
    if not anchor or not EL or not CreateFrame then return end

    local options = {
        { mode = "today", text = "Today" },
        { mode = "week", text = "This Week" },
        { mode = "30", text = "30 days (" .. ((EL.GetSessionHistoryMaxEntries and EL:GetSessionHistoryMaxEntries()) or 500) .. " max)" },
    }

    local menu = EL.sessionHistoryDisplayDropdown
    if not menu then
        menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu:SetSize(148, 86)
        menu:SetFrameStrata("MEDIUM")
        menu:SetClampedToScreen(true)
        if menu.EnableKeyboard then
            menu:EnableKeyboard(true)
            menu:SetScript("OnKeyDown", function(_, key)
                if key == "ESCAPE" then
                    Style:HideSessionHistoryDisplayDropdown()
                end
            end)
            menu:SetScript("OnShow", function(self)
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
                if self.SetFocus then self:SetFocus() end
            end)
            menu:SetScript("OnHide", function(self)
                if self.ClearFocus then self:ClearFocus() end
            end)
        end
        self:AddBackdrop(menu, 0.95, 0.78)
        if menu.SetBackdropColor then menu:SetBackdropColor(0.012, 0.010, 0.024, 0.98) end
        self:AddInnerBorder(menu)
        menu.buttons = {}
        for i, option in ipairs(options) do
            local btn = CreateFrame("Button", nil, menu)
            btn:SetSize(132, 23)
            btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -7 - ((i - 1) * 24))
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.text:SetPoint("LEFT", btn, "LEFT", 8, 0)
            btn.text:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            btn.text:SetJustifyH("LEFT")
            btn.highlight = btn:CreateTexture(nil, "BACKGROUND")
            btn.highlight:SetAllPoints(btn)
            btn.highlight:SetColorTexture(0.76, 0.82, 0.92, 0.10)
            btn.highlight:Hide()
            btn:SetScript("OnEnter", function(self)
                if self.highlight then self.highlight:Show() end
                if self.text then self.text:SetTextColor(0.82, 0.88, 0.96) end
            end)
            btn:SetScript("OnLeave", function(self)
                local currentMode = (EL.GetSessionHistoryDisplayMode and EL:GetSessionHistoryDisplayMode()) or "30"
                if self.highlight then self.highlight:SetShown(self.mode == currentMode) end
                if self.text then
                    if self.mode == currentMode then
                        self.text:SetTextColor(0.42, 1.00, 0.32)
                    else
                        self.text:SetTextColor(Style:ThemeTextRGB())
                    end
                end
            end)
            btn:SetScript("OnClick", function(self)
                if EL.SetSessionHistoryDisplayMode then EL:SetSessionHistoryDisplayMode(self.mode) end
                Style:HideSessionHistoryDisplayDropdown()
            end)
            menu.buttons[i] = btn
        end
        menu:Hide()
        EL.sessionHistoryDisplayDropdown = menu
    end

    if menu:IsShown() then
        menu:Hide()
        return
    end

    local currentMode = (EL.GetSessionHistoryDisplayMode and EL:GetSessionHistoryDisplayMode()) or "30"
    for i, option in ipairs(options) do
        local btn = menu.buttons and menu.buttons[i]
        if btn then
            btn.mode = option.mode
            if btn.text then
                btn.text:SetText(option.text)
                if currentMode == option.mode then
                    btn.text:SetTextColor(0.42, 1.00, 0.32)
                else
                    btn.text:SetTextColor(self:ThemeTextRGB())
                end
            end
            if btn.highlight then btn.highlight:SetShown(currentMode == option.mode) end
        end
    end

    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    if menu.SetFrameStrata then menu:SetFrameStrata("MEDIUM") end
    if menu.SetFrameLevel then menu:SetFrameLevel(((anchor.GetFrameLevel and anchor:GetFrameLevel()) or 30) + 20) end
    menu:Show()
end

function Style:ColorTextByRGB(text, r, g, b)
    text = tostring(text or "")
    r = math.max(0, math.min(1, tonumber(r) or 1))
    g = math.max(0, math.min(1, tonumber(g) or 1))
    b = math.max(0, math.min(1, tonumber(b) or 1))
    local ri, gi, bi = math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
    return string.format("|cff%02x%02x%02x%s|r", ri, gi, bi, text)
end

function Style:AddBackdrop(frame, alpha, borderAlpha)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    local bgR, bgG, bgB = BackgroundRGB()
    local borderR, borderG, borderB = BorderRGB()
    frame:SetBackdropColor(bgR, bgG, bgB, alpha or 0.55)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, borderAlpha or 0.55)
end

function Style:AddFlatBackdrop(frame, alpha, borderAlpha)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local bgR, bgG, bgB = BackgroundRGB()
    local borderR, borderG, borderB = BorderRGB()
    if frame.SetBackdropColor then frame:SetBackdropColor(bgR, bgG, bgB, alpha or 0.38) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(borderR, borderG, borderB, borderAlpha or 0.46) end
end

function Style:ApplyFrameOpacity(frame, alpha)
    if frame and frame.SetBackdropColor then
        local bgR, bgG, bgB = BackgroundRGB()
        frame:SetBackdropColor(bgR, bgG, bgB, alpha or 0.55)
    end
end

function Style:AddInnerBorder(frame)
    if not frame or frame.innerBorder then return end
    frame.innerBorder = frame:CreateTexture(nil, "BORDER")
    frame.innerBorder:SetPoint("TOPLEFT", 4, -4)
    frame.innerBorder:SetPoint("BOTTOMRIGHT", -4, 4)
    local r, g, b = AccentRGB()
    frame.innerBorder:SetColorTexture(r, g, b, 0.12)
end

function Style:AddHeaderAccent(frame)
    if not frame or frame._emberHeaderAccent then return end
    frame._emberHeaderAccent = true
    frame.accentTop = frame:CreateTexture(nil, "BORDER")
    frame.accentTop:SetHeight(1)
    frame.accentTop:SetPoint("TOPLEFT", 3, -2)
    frame.accentTop:SetPoint("TOPRIGHT", -3, -2)
    local r, g, b = AccentRGB()
    frame.accentTop:SetColorTexture(r, g, b, 0.34)
    frame.accentBottom = frame:CreateTexture(nil, "BORDER")
    frame.accentBottom:SetHeight(1)
    frame.accentBottom:SetPoint("BOTTOMLEFT", 3, 2)
    frame.accentBottom:SetPoint("BOTTOMRIGHT", -3, 2)
    frame.accentBottom:SetColorTexture(0.00, 0.00, 0.00, 0.50)
end

function Style:AddEmberCornerAccents(frame)
    if not frame or frame._emberCornerAccents then return end
    frame._emberCornerAccents = true
    local points = {
        {"TOPLEFT", 6, -6}, {"TOPRIGHT", -6, -6}, {"BOTTOMLEFT", 6, 6}, {"BOTTOMRIGHT", -6, 6},
    }
    frame.emberCorners = {}
    for i, point in ipairs(points) do
        local tex = frame:CreateTexture(nil, "BORDER")
        tex:SetSize(14, 14)
        tex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        local r, g, b = AccentRGB()
        tex:SetVertexColor(r, g, b, 0.24)
        tex:SetPoint(point[1], frame, point[1], point[2], point[3])
        frame.emberCorners[i] = tex
    end
end

function Style:AddEmberLogo(parent, size, layer)
    if not parent then return nil end
    local tex = parent:CreateTexture(nil, layer or "ARTWORK")
    tex:SetSize(size or 36, size or 36)
    tex:SetTexture((EL and EL.LOGO_TEXTURE) or "Interface\\Icons\\INV_Misc_Book_11")
    tex:SetTexCoord(0.02, 0.98, 0.02, 0.98)
    tex:SetVertexColor(1.00, 1.00, 1.00, 1.00)
    return tex
end

function Style:AddEmberLogoBadge(parent, size, layer)
    if not parent or not CreateFrame then return nil end
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(size or 42, size or 42)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    if frame.SetBackdropColor then frame:SetBackdropColor(0.015, 0.017, 0.022, 0.82) end
    if frame.SetBackdropBorderColor then
        local borderR, borderG, borderB = BorderRGB()
        frame:SetBackdropBorderColor(borderR, borderG, borderB, 0.82)
    end
    frame.glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.glow:SetSize((size or 42) + 12, (size or 42) + 12)
    frame.glow:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    local glowR, glowG, glowB = GlowRGB()
    frame.glow:SetVertexColor(glowR, glowG, glowB, 0.18)
    frame.logo = self:AddEmberLogo(frame, math.max(16, (size or 42) - 8), layer or "ARTWORK")
    if frame.logo then frame.logo:SetPoint("CENTER", frame, "CENTER", 0, 0) end
    return frame
end

function Style:StyleScrollBar(scrollFrame)
    if not scrollFrame then return end
    local name = scrollFrame:GetName()
    local bar = scrollFrame.ScrollBar or (name and _G[name .. "ScrollBar"])
    if bar then
        bar:Hide()
        if bar.SetAlpha then bar:SetAlpha(0) end
        if bar.EnableMouse then bar:EnableMouse(false) end
    end
    -- Named global children exist on Blizzard's standard named scroll frames. Anonymous custom frames are already handled through scrollFrame.ScrollBar above.
    if name then
        for _, suffix in ipairs({"ScrollUpButton", "ScrollDownButton", "ScrollBarTop", "ScrollBarBottom", "ScrollBarMiddle", "ThumbTexture"}) do
            local region = _G[name .. suffix]
            if region then
                if region.Hide then region:Hide() end
                if region.SetAlpha then region:SetAlpha(0) end
                if region.EnableMouse then region:EnableMouse(false) end
            end
        end
    end
end

function Style:ClearButtonTexture(button, getterName)
    if not button or not getterName or not button[getterName] then return end
    local ok, texture = pcall(button[getterName], button)
    if ok and texture then
        if texture.SetTexture then texture:SetTexture(nil) end
        if texture.SetAlpha then texture:SetAlpha(0) end
    end
end

function Style:DisableButtonArt(button)
    self:ClearButtonTexture(button, "GetNormalTexture")
    self:ClearButtonTexture(button, "GetPushedTexture")
    self:ClearButtonTexture(button, "GetHighlightTexture")
    self:ClearButtonTexture(button, "GetDisabledTexture")
end

function Style:StyleBlizzardButton(button)
    if not button then return end
    if button.SetNormalFontObject then button:SetNormalFontObject(GameFontNormalSmall) end
    if button.SetHighlightFontObject then button:SetHighlightFontObject(GameFontHighlightSmall) end
    if button.SetDisabledFontObject then button:SetDisabledFontObject(GameFontDisableSmall) end
    local fs = button.GetFontString and button:GetFontString()
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", button, "CENTER", 0, 1)
        fs:SetJustifyH("CENTER")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
    end
end

function Style:StyleActionBarButton(button)
    if not button then return end
    self:DisableButtonArt(button)
    self:AddFlatBackdrop(button, 0.86, 0.60)
    if button.SetBackdropColor then
        button:SetBackdropColor(ThemeValue("ACTION_BUTTON_BG_R", 0.10), ThemeValue("ACTION_BUTTON_BG_G", 0.08), ThemeValue("ACTION_BUTTON_BG_B", 0.16), 0.86)
    end
    if button.SetBackdropBorderColor then
        local borderR, borderG, borderB = BorderRGB(); button:SetBackdropBorderColor(borderR, borderG, borderB, 0.68)
    end
    if button.SetTextColor then button:SetTextColor(ThemeValue("ACTION_BUTTON_TEXT_R", 0.86), ThemeValue("ACTION_BUTTON_TEXT_G", 0.90), ThemeValue("ACTION_BUTTON_TEXT_B", 0.96)) end
end

function EL:StyleBlizzardButton(button)
    return Style:StyleBlizzardButton(button)
end
