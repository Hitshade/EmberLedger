local addonName, EL = ...

EL.Style = EL.Style or {}
local Style = EL.Style

local THEME = EL.THEME_COLORS or {}

local function ThemeValue(key, fallback)
    local colors = EL and EL.THEME_COLORS or THEME or {}
    return tonumber(colors[key]) or fallback
end

local function BorderRGB()
    return ThemeValue("BORDER_R", 0.82), ThemeValue("BORDER_G", 0.66), ThemeValue("BORDER_B", 0.34)
end

local function BackgroundRGB()
    return ThemeValue("BG_R", 0.020), ThemeValue("BG_G", 0.016), ThemeValue("BG_B", 0.040)
end

local function AccentRGB()
    return ThemeValue("ACCENT_R", 1.00), ThemeValue("ACCENT_G", 0.72), ThemeValue("ACCENT_B", 0.18)
end

local function GlowRGB()
    return ThemeValue("GLOW_R", 1.00), ThemeValue("GLOW_G", 0.46), ThemeValue("GLOW_B", 0.10)
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
