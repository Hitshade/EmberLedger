local addonName, EL = ...

EL.Style = EL.Style or {}
local Style = EL.Style

local THEME = EL.THEME_COLORS or {}
local BORDER_R, BORDER_G, BORDER_B = THEME.BORDER_R or 0.82, THEME.BORDER_G or 0.66, THEME.BORDER_B or 0.34
local EL_BG_R, EL_BG_G, EL_BG_B = THEME.BG_R or 0.030, THEME.BG_G or 0.024, THEME.BG_B or 0.075

function Style:ColorTextByRGB(text, r, g, b)
    r = math.max(0, math.min(1, tonumber(r) or 1))
    g = math.max(0, math.min(1, tonumber(g) or 1))
    b = math.max(0, math.min(1, tonumber(b) or 1))
    return string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), tostring(text or ""))
end

function Style:AddBackdrop(frame, alpha, borderAlpha)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(EL_BG_R, EL_BG_G, EL_BG_B, alpha or 0.55)
    frame:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, borderAlpha or 0.55)
end

function Style:AddFlatBackdrop(frame, alpha, borderAlpha)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    if frame.SetBackdropColor then frame:SetBackdropColor(EL_BG_R, EL_BG_G, EL_BG_B, alpha or 0.38) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, borderAlpha or 0.46) end
end

function Style:ApplyFrameOpacity(frame, alpha)
    if frame and frame.SetBackdropColor then
        frame:SetBackdropColor(EL_BG_R, EL_BG_G, EL_BG_B, alpha or 0.55)
    end
end

function Style:AddInnerBorder(frame)
    if not frame or frame.innerBorder then return end
    frame.innerBorder = frame:CreateTexture(nil, "BORDER")
    frame.innerBorder:SetPoint("TOPLEFT", 4, -4)
    frame.innerBorder:SetPoint("BOTTOMRIGHT", -4, 4)
    frame.innerBorder:SetColorTexture(1.00, 0.78, 0.28, 0.090)
end

function Style:AddHeaderAccent(frame)
    if not frame or frame._emberHeaderAccent then return end
    frame._emberHeaderAccent = true
    frame.accentTop = frame:CreateTexture(nil, "BORDER")
    frame.accentTop:SetHeight(1)
    frame.accentTop:SetPoint("TOPLEFT", 3, -2)
    frame.accentTop:SetPoint("TOPRIGHT", -3, -2)
    frame.accentTop:SetColorTexture(1.00, 0.78, 0.28, 0.34)
    frame.accentBottom = frame:CreateTexture(nil, "BORDER")
    frame.accentBottom:SetHeight(1)
    frame.accentBottom:SetPoint("BOTTOMLEFT", 3, 2)
    frame.accentBottom:SetPoint("BOTTOMRIGHT", -3, 2)
    frame.accentBottom:SetColorTexture(0.00, 0.00, 0.00, 0.50)
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
        button:SetBackdropColor(THEME.ACTION_BUTTON_BG_R or 0.10, THEME.ACTION_BUTTON_BG_G or 0.08, THEME.ACTION_BUTTON_BG_B or 0.16, 0.86)
    end
    if button.SetBackdropBorderColor then
        button:SetBackdropBorderColor(0.72, 0.56, 0.28, 0.60)
    end
    if button.SetTextColor then button:SetTextColor(THEME.ACTION_BUTTON_TEXT_R or 1.00, THEME.ACTION_BUTTON_TEXT_G or 0.86, THEME.ACTION_BUTTON_TEXT_B or 0.36) end
end

function EL:StyleBlizzardButton(button)
    return Style:StyleBlizzardButton(button)
end
