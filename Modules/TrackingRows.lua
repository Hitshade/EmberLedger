local addonName, EL = ...

local CreateFrame = _G.CreateFrame
local IsShiftKeyDown = _G.IsShiftKeyDown
local IsAltKeyDown = _G.IsAltKeyDown
local GameTooltip = _G.GameTooltip
local GameFontHighlight = _G.GameFontHighlight
local GameFontHighlightSmall = _G.GameFontHighlightSmall

local UIC = EL.UI_CONSTANTS or {}
local TRACKING_ROW_H = UIC.TRACKING_ROW_H or 23
local TRACKING_COMPACT_ROW_H = UIC.TRACKING_COMPACT_ROW_H or 18
local READY_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local CD_READY_ICON_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Check"
local CD_READY_ICON_R, CD_READY_ICON_G, CD_READY_ICON_B = 1.00, 0.82, 0.25
local PIN_GLOW_R, PIN_GLOW_G, PIN_GLOW_B = 0.70, 0.78, 0.88
local PIN_GLOW_ALPHA = 0.060
local PIN_ACCENT_ALPHA = 0.20
local TRACKING_ROW_PALETTE = EL.Style and EL.Style.GetTrackingRowPalette and EL.Style:GetTrackingRowPalette() or {}
local CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B = TRACKING_ROW_PALETTE.currentR or 0.42, TRACKING_ROW_PALETTE.currentG or 0.68, TRACKING_ROW_PALETTE.currentB or 1.00
local CURRENT_ROW_BG_ALPHA = TRACKING_ROW_PALETTE.currentBgAlpha or 0.145
local CURRENT_ROW_BG_ALPHA_COMPACT = TRACKING_ROW_PALETTE.currentBgAlphaCompact or 0.125
local CURRENT_ROW_LINE_ALPHA = TRACKING_ROW_PALETTE.currentLineAlpha or 0.44
local CURRENT_ROW_EDGE_ALPHA = TRACKING_ROW_PALETTE.currentEdgeAlpha or 0.70
local TRACKING_ROW_HOVER_R, TRACKING_ROW_HOVER_G, TRACKING_ROW_HOVER_B = TRACKING_ROW_PALETTE.hoverR or 0.50, TRACKING_ROW_PALETTE.hoverG or 0.66, TRACKING_ROW_PALETTE.hoverB or 0.88
local TRACKING_ROW_HOVER_ALPHA = TRACKING_ROW_PALETTE.hoverAlpha or 0.075
local TRACKING_CURRENT_ROW_HOVER_ALPHA = TRACKING_ROW_PALETTE.currentHoverAlpha or 0.115
local ROW_STRIPE_ALPHA = 0.32
local ROW_STRIPE_ALPHA_COMPACT = 0.28
local ROW_SEPARATOR_ALPHA = 0.18

local THEME = EL.THEME_COLORS or {}

local function T(key, ...)
    if EL and EL.T then return EL:T(key, ...) end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, tostring(key), ...)
        if ok then return formatted end
    end
    return tostring(key)
end

local function ThemeColor(key, fallback)
    local current = EL.THEME_COLORS or THEME or {}
    local value = current[key]
    return value ~= nil and value or fallback
end

local function ThemeAccentRGB()
    return ThemeColor("ACCENT_R", 0.68), ThemeColor("ACCENT_G", 0.68), ThemeColor("ACCENT_B", 0.70)
end

local function ThemeBorderRGB()
    return ThemeColor("BORDER_R", 0.42), ThemeColor("BORDER_G", 0.42), ThemeColor("BORDER_B", 0.44)
end

local function ThemeTextRGB()
    return ThemeColor("TEXT_R", 0.90), ThemeColor("TEXT_G", 0.91), ThemeColor("TEXT_B", 0.93)
end

local function ThemeMutedTextRGB()
    return ThemeColor("MUTED_TEXT_R", 0.80), ThemeColor("MUTED_TEXT_G", 0.82), ThemeColor("MUTED_TEXT_B", 0.85)
end

local function ThemeValueTextRGB()
    return ThemeColor("VALUE_TEXT_R", 0.93), ThemeColor("VALUE_TEXT_G", 0.94), ThemeColor("VALUE_TEXT_B", 0.96)
end

local function ThemeMoxieTextRGB()
    if EL.Style and EL.Style.GetMoxieTextColor then
        return EL.Style:GetMoxieTextColor()
    end
    return 0.66, 0.78, 0.88
end

local function IsCompactModeEnabled()
    local display = EL and EL.db and EL.db.settings and EL.db.settings.display or {}
    return display.compactMode == true
end

local function GetTrackingRowHeight()
    return IsCompactModeEnabled() and TRACKING_COMPACT_ROW_H or TRACKING_ROW_H
end

function EL:GetTrackingRowHeight()
    return GetTrackingRowHeight()
end

function EL:GetTrackingRowGap()
    return UIC.TRACKING_ROW_GAP or 0
end

local function SetFontStringTextIfChanged(fs, text)
    if not fs then return end
    text = text == nil and "" or tostring(text)
    if fs._emberLastText ~= text then
        fs._emberLastText = text
        fs:SetText(text)
    end
end

local function ApplyTrackingRowHoverState(row, hovered)
    if not row or not row.hover then return end
    if row.isCurrentCharacter then
        row.hover:SetColorTexture(CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B, TRACKING_CURRENT_ROW_HOVER_ALPHA)
    else
        row.hover:SetColorTexture(TRACKING_ROW_HOVER_R, TRACKING_ROW_HOVER_G, TRACKING_ROW_HOVER_B, TRACKING_ROW_HOVER_ALPHA)
    end
    row.hover:SetShown(hovered and true or false)
end

local function ApplyTrackingTextStyle(row)
    if not row then return end
    local fontObject = IsCompactModeEnabled() and GameFontHighlightSmall or GameFontHighlight
    for _, fs in ipairs({row.name, row.prof1, row.conc1, row.prof2, row.conc2, row.moxie, row.moxieLeft, row.moxieSep, row.moxieRight, row.forecast, row.cooldown, row.mulch}) do
        if fs and fs.SetFontObject then fs:SetFontObject(fontObject) end
    end
end

local function AnchorColumnText(fs, parent, x, width, justify)
    if not fs or not parent then return end
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", parent, "LEFT", x, 0)
    fs:SetPoint("RIGHT", parent, "LEFT", x + width, 0)
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
end

local function AnchorColumnTexture(texture, parent, x, width)
    if not texture or not parent then return end
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", parent, "LEFT", x + (math.max(1, tonumber(width) or 1) / 2), 0)
end

local function AnchorMoxieCell(row, parent, x, width)
    if not row or not parent then return end
    width = math.max(1, tonumber(width) or 1)
    local sepW = math.min(14, math.max(8, math.floor(width * 0.16 + 0.5)))
    local sideW = math.max(1, math.floor((width - sepW) / 2))
    local rightW = math.max(1, width - sepW - sideW)

    AnchorColumnText(row.moxie, parent, x, width, "CENTER")
    AnchorColumnText(row.moxieLeft, parent, x, sideW, "RIGHT")
    AnchorColumnText(row.moxieSep, parent, x + sideW, sepW, "CENTER")
    AnchorColumnText(row.moxieRight, parent, x + sideW + sepW, rightW, "LEFT")
end

local function SetMoxieCellShown(row, visible, split)
    if not row then return end
    visible = visible and true or false
    split = split and true or false
    if row.moxie then row.moxie:SetShown(visible and not split) end
    if row.moxieLeft then row.moxieLeft:SetShown(visible and split) end
    if row.moxieSep then row.moxieSep:SetShown(visible and split) end
    if row.moxieRight then row.moxieRight:SetShown(visible and split) end
end

local function SetMoxieCellColor(row, r, g, b)
    if not row then return end
    for _, fs in ipairs({row.moxie, row.moxieLeft, row.moxieSep, row.moxieRight}) do
        if fs and fs.SetTextColor then fs:SetTextColor(r, g, b) end
    end
end

local function GetMoxieDisplayValues(charKey, dashboardSlots)
    local values = {}
    if not charKey or type(dashboardSlots) ~= "table" then return values end
    for _, slotData in ipairs(dashboardSlots) do
        local prof = slotData and slotData.prof or slotData
        if EL.GetMoxieCurrencyIDForProfession and EL:GetMoxieCurrencyIDForProfession(prof) then
            local entry = EL.GetMoxieEntryForProfession and EL:GetMoxieEntryForProfession(charKey, prof)
            if entry and type(entry.quantity) == "number" then
                values[#values + 1] = tostring(entry.quantity)
            end
        end
    end
    return values
end

local function AnchorProfessionCell(row, fs, icon, x, width, visible, iconTexture)
    if not row or not fs then return end
    fs:ClearAllPoints()
    fs:SetWidth(width)
    fs:SetJustifyH("CENTER")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end

    local showIcon = visible and icon and iconTexture and iconTexture ~= ""
    fs._emberHasProfessionIcon = showIcon and true or false
    if showIcon then
        local iconSize = IsCompactModeEnabled() and 14 or 16
        icon:ClearAllPoints()
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("CENTER", row, "LEFT", x + (width / 2), 0)
        icon:SetTexture(iconTexture)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:Show()
        fs:Hide()
    else
        if icon then icon:Hide() end
        fs:SetPoint("LEFT", row, "LEFT", x, 0)
        fs:SetPoint("RIGHT", row, "LEFT", x + width, 0)
        fs:SetJustifyH("CENTER")
        fs:SetShown(visible and true or false)
    end
end

local function TrackingLayoutSnapshotChanged(snapshot, width, rowH, cols, visible)
    if not snapshot or snapshot.width ~= width or snapshot.rowH ~= rowH then return true end
    for _, def in ipairs(cols.columns or {}) do
        local key = def.key
        if snapshot.visible[key] ~= (visible[key] and true or false) then return true end
        if snapshot[key .. "X"] ~= cols[key .. "X"] or snapshot[key .. "W"] ~= cols[key .. "W"] then return true end
    end
    return false
end

local function UpdateTrackingLayoutGeneration(owner, width, rowH, cols, visible)
    owner._trackingLayoutGeneration = tonumber(owner._trackingLayoutGeneration) or 0
    if TrackingLayoutSnapshotChanged(owner._trackingLayoutSnapshot, width, rowH, cols, visible) then
        owner._trackingLayoutGeneration = owner._trackingLayoutGeneration + 1
        local snapshot = { width = width, rowH = rowH, visible = {} }
        for _, def in ipairs(cols.columns or {}) do
            local key = def.key
            snapshot.visible[key] = visible[key] and true or false
            snapshot[key .. "X"] = cols[key .. "X"]
            snapshot[key .. "W"] = cols[key .. "W"]
        end
        owner._trackingLayoutSnapshot = snapshot
    end
    return owner._trackingLayoutGeneration
end

function EL:GetRow(i)
    local p = self.panel
    if not p or not p.content then return nil end
    p.rows = p.rows or {}
    if not p.rows[i] then
        local row = CreateFrame("Button", nil, p.content)
        row:SetHeight(GetTrackingRowHeight())
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.edge = row:CreateTexture(nil, "BORDER")
        row.edge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
        row.edge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
        row.edge:SetWidth(3)
        row.edge:SetColorTexture(0.70, 0.78, 0.88, 0.00)
        row.edge:Hide()
        row.currentHighlight = row:CreateTexture(nil, "BORDER")
        row.currentHighlight:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.currentHighlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.currentHighlight:SetColorTexture(CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B, 0.00)
        row.currentHighlight:Hide()
        row.currentHighlightTop = row:CreateTexture(nil, "ARTWORK")
        row.currentHighlightTop:SetHeight(1)
        row.currentHighlightTop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.currentHighlightTop:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        row.currentHighlightTop:SetColorTexture(CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B, 0.00)
        row.currentHighlightTop:Hide()
        row.currentHighlightBottom = row:CreateTexture(nil, "ARTWORK")
        row.currentHighlightBottom:SetHeight(1)
        row.currentHighlightBottom:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.currentHighlightBottom:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.currentHighlightBottom:SetColorTexture(CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B, 0.00)
        row.currentHighlightBottom:Hide()
        row.currentHighlightLeft = row:CreateTexture(nil, "ARTWORK")
        row.currentHighlightLeft:SetWidth(3)
        row.currentHighlightLeft:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.currentHighlightLeft:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.currentHighlightLeft:SetColorTexture(CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B, 0.00)
        row.currentHighlightLeft:Hide()
        row.currentHighlightRight = row:CreateTexture(nil, "ARTWORK")
        row.currentHighlightRight:SetWidth(2)
        row.currentHighlightRight:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        row.currentHighlightRight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.currentHighlightRight:SetColorTexture(CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B, 0.00)
        row.currentHighlightRight:Hide()
        row._highlightLines = { row.currentHighlightTop, row.currentHighlightBottom, row.currentHighlightLeft, row.currentHighlightRight }
        row.pinGlow = row:CreateTexture(nil, "BORDER")
        row.pinGlow:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -2)
        row.pinGlow:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3, 2)
        row.pinGlow:SetColorTexture(PIN_GLOW_R, PIN_GLOW_G, PIN_GLOW_B, 0.00)
        row.pinGlow:Hide()
        row.pinAccent = row:CreateTexture(nil, "ARTWORK")
        row.pinAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -2)
        row.pinAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 2)
        row.pinAccent:SetWidth(2)
        row.pinAccent:SetColorTexture(PIN_GLOW_R, PIN_GLOW_G, PIN_GLOW_B, 0.00)
        row.pinAccent:Hide()
        row.sep = row:CreateTexture(nil, "BORDER")
        row.sep:SetHeight(1)
        row.sep:SetPoint("BOTTOMLEFT", 0, 0)
        row.sep:SetPoint("BOTTOMRIGHT", 0, 0)
        local sr, sg, sb = ThemeBorderRGB(); row.sep:SetColorTexture(sr, sg, sb, ROW_SEPARATOR_ALPHA)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetJustifyH("LEFT")
        row.prof1Icon = row:CreateTexture(nil, "OVERLAY")
        row.prof1Icon:Hide()
        row.prof1 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.prof1:SetJustifyH("CENTER")
        row.conc1 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.conc1:SetJustifyH("CENTER")
        row.prof2Icon = row:CreateTexture(nil, "OVERLAY")
        row.prof2Icon:Hide()
        row.prof2 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.prof2:SetJustifyH("CENTER")
        row.conc2 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.conc2:SetJustifyH("CENTER")
        row.moxie = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.moxie:SetJustifyH("CENTER")
        row.moxieLeft = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.moxieLeft:SetJustifyH("RIGHT")
        row.moxieSep = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.moxieSep:SetJustifyH("CENTER")
        row.moxieSep:SetText("•")
        row.moxieRight = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.moxieRight:SetJustifyH("LEFT")
        row.forecast = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.forecast:SetJustifyH("CENTER")
        row.cooldown = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.cooldown:SetJustifyH("CENTER")
        row.cooldownReadyIcon = row:CreateTexture(nil, "OVERLAY")
        row.cooldownReadyIcon:SetTexture(CD_READY_ICON_TEXTURE)
        row.cooldownReadyIcon:SetVertexColor(CD_READY_ICON_R, CD_READY_ICON_G, CD_READY_ICON_B, 1)
        row.cooldownReadyIcon:Hide()
        row.mulch = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.mulch:SetJustifyH("CENTER")
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if button == "LeftButton" and self.charKey and IsAltKeyDown and IsAltKeyDown() then
                GameTooltip:Hide()
                if EL.ToggleCharacterPinned then EL:ToggleCharacterPinned(self.charKey) end
                return
            end
            if button == "RightButton" and self.charKey then
                local char = EL.db and EL.db.characters and EL.db.characters[self.charKey]
                local displayName = (char and (char.displayName or char.name)) or self.charKey
                GameTooltip:Hide()
                if IsShiftKeyDown and IsShiftKeyDown() then
                    if EL.ConfirmRemoveCharacterData then
                        EL:ConfirmRemoveCharacterData(self.charKey, displayName)
                    elseif EL.Debug then
                        EL:Debug("ConfirmRemoveCharacterData is unavailable. Character data was not removed.")
                    end
                else
                    EL:SetCharacterHidden(self.charKey, true)
                    EL:RequestUpdate()
                    EL:Print("Hidden: " .. tostring(displayName))
                end
            end
        end)
        row:SetScript("OnEnter", function(self)
            ApplyTrackingRowHoverState(self, true)
            if EL.ShowRowTooltip then EL:ShowRowTooltip(self) end
        end)
        row:SetScript("OnLeave", function(self)
            ApplyTrackingRowHoverState(self, false)
            GameTooltip:Hide()
        end)
        row.hover = row:CreateTexture(nil, "HIGHLIGHT")
        row.hover:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.hover:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.hover:SetColorTexture(TRACKING_ROW_HOVER_R, TRACKING_ROW_HOVER_G, TRACKING_ROW_HOVER_B, TRACKING_ROW_HOVER_ALPHA)
        row.hover:Hide()
        p.rows[i] = row
    end
    return p.rows[i]
end

function EL:RefreshTrackingRows(ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local p = ctx.panel or self.panel
    if not p then return 0, GetTrackingRowHeight(), 0 end
    p.rows = p.rows or {}
    local rows = ctx.rows or {}
    local rowH = tonumber(ctx.rowH) or GetTrackingRowHeight()
    local gap = tonumber(ctx.gap) or 0
    local now = tonumber(ctx.now) or time()
    local width = math.max(1, tonumber(ctx.width) or (p.scroll and p.scroll:GetWidth()) or p:GetWidth() or 1)
    local cols = ctx.columns or (self.GetTrackingColumnLayout and self:GetTrackingColumnLayout(width)) or { columns = {} }
    local visible = ctx.visible or {}
    if not ctx.visible then
        for _, def in ipairs(cols.columns or {}) do visible[def.key] = true end
    end
    local layoutGeneration = ctx.layoutGeneration or UpdateTrackingLayoutGeneration(self, width, rowH, cols, visible)
    local concentrationLookup = ctx.concentrationLookup or {}
    local professionLookup = ctx.professionLookup or {}
    local dashboardLookups = ctx.dashboardLookups or {}
    local currentCharKey = ctx.currentCharKey or (self.GetCharacterKey and self:GetCharacterKey() or nil)
    local highlightCurrent = ctx.highlightCurrent
    if highlightCurrent == nil then
        local display = self.db and self.db.settings and self.db.settings.display or {}
        highlightCurrent = display.highlightCurrentCharacter ~= false
    end

    for i, entry in ipairs(rows) do
        local row = self:GetRow(i)
        if row then
            row:SetHeight(rowH)
            ApplyTrackingTextStyle(row)
            local charKey, char = entry.key, entry.char
            local rowCache = dashboardLookups and dashboardLookups.rowCache and dashboardLookups.rowCache[charKey] or nil
            local concLookup = concentrationLookup[charKey]
            local concEntries = rowCache and rowCache.concEntries or (concLookup and concLookup.entries or {})
            local profEntries = rowCache and rowCache.profEntries or professionLookup[charKey]
            if (not profEntries or #profEntries == 0) and concEntries then profEntries = concEntries end
            local slots = rowCache and rowCache.slots or self:GetDashboardProfessionSlots(charKey, profEntries, concEntries) or {}
            local profData1, concData1 = slots[1] and slots[1].prof or nil, slots[1] and slots[1].conc or nil
            local profData2, concData2 = slots[2] and slots[2].prof or nil, slots[2] and slots[2].conc or nil
            local moxieEntries = rowCache and rowCache.moxieEntries or self:GetMoxieEntriesForCharacter(charKey, profEntries)
            local cooldownValue, cooldownSummary = "-", nil
            if type(self.GetProfessionCooldownDisplayText) == "function" then
                local ok, value, summary = pcall(self.GetProfessionCooldownDisplayText, self, charKey, profEntries)
                if ok then
                    cooldownValue, cooldownSummary = value or "-", summary
                elseif self.db and self.db.settings and self.db.settings.debug and self.Print then
                    self:Print("Cooldown display unavailable: " .. tostring(value))
                end
            end
            local mulchData = self.db and self.db.resources and self.db.resources.mulch and self.db.resources.mulch[charKey]
            local profValue1, concValue1, profValue2, concValue2 = "N/A", "N/A", "N/A", "N/A"
            if profData1 then profValue1 = self:GetProfessionAbbreviation(profData1) end
            local concQ1, concQ2 = nil, nil
            if concData1 then
                concQ1 = self:GetEstimatedConcentration(concData1, now) or 0
                concValue1 = tostring(concQ1) .. "/" .. tostring(concData1.maxQuantity or self.CONCENTRATION_MAX_DEFAULT)
            end
            if profData2 then profValue2 = self:GetProfessionAbbreviation(profData2) end
            if concData2 then
                concQ2 = self:GetEstimatedConcentration(concData2, now) or 0
                concValue2 = tostring(concQ2) .. "/" .. tostring(concData2.maxQuantity or self.CONCENTRATION_MAX_DEFAULT)
            end
            local forecastValue = "N/A"
            local forecastData = concLookup and concLookup.best or nil
            local readyConcentrationCount = concLookup and concLookup.readyCount or 0
            if forecastData and self.GetConcentrationForecastText then
                forecastValue = self:GetConcentrationForecastText(forecastData, nil, now)
                if readyConcentrationCount > 1 and forecastValue == "Ready" then forecastValue = tostring(readyConcentrationCount) .. "x Ready" end
            end
            local mulchValue = "N/A"
            if self:HasImbuedMulchAccess(mulchData) then
                local remain = math.max(0, (tonumber(mulchData.readyAt) or 0) - now)
                mulchValue = remain <= 0 and (READY_ICON .. " Ready") or self:FormatCountdown(remain)
            end

            local profIcon1 = profData1 and self:GetProfessionIconTexture(profData1) or nil
            local profIcon2 = profData2 and self:GetProfessionIconTexture(profData2) or nil
            if row._emberLayoutGen ~= layoutGeneration or row._emberLayoutIndex ~= i or row._emberProfIcon1 ~= profIcon1 or row._emberProfIcon2 ~= profIcon2 then
                row:SetWidth(width)
                row:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -((i - 1) * (rowH + gap)))
                AnchorColumnText(row.name, row, cols.nameX or 0, cols.nameW or 1, "LEFT")
                AnchorColumnText(row.conc1, row, cols.conc1X or 0, cols.conc1W or 1, "CENTER")
                AnchorColumnText(row.conc2, row, cols.conc2X or 0, cols.conc2W or 1, "CENTER")
                AnchorMoxieCell(row, row, cols.moxieX or 0, math.max(1, cols.moxieW or 1))
                AnchorColumnText(row.forecast, row, cols.forecastX or 0, math.max(1, cols.forecastW or 1), "CENTER")
                AnchorColumnText(row.cooldown, row, cols.cooldownX or 0, math.max(1, cols.cooldownW or 1), "CENTER")
                AnchorColumnTexture(row.cooldownReadyIcon, row, cols.cooldownX or 0, math.max(1, cols.cooldownW or 1))
                AnchorColumnText(row.mulch, row, cols.mulchX or 0, math.max(1, cols.mulchW or 1), "CENTER")
                AnchorProfessionCell(row, row.prof1, row.prof1Icon, cols.prof1X or 0, cols.prof1W or 1, visible.prof1, profIcon1)
                AnchorProfessionCell(row, row.prof2, row.prof2Icon, cols.prof2X or 0, cols.prof2W or 1, visible.prof2, profIcon2)
                row._emberLayoutGen = layoutGeneration
                row._emberLayoutIndex = i
                row._emberProfIcon1 = profIcon1
                row._emberProfIcon2 = profIcon2
            end
            row.prof1:SetShown(visible.prof1 and not row.prof1._emberHasProfessionIcon)
            row.conc1:SetShown(visible.conc1 and true or false)
            row.prof2:SetShown(visible.prof2 and not row.prof2._emberHasProfessionIcon)
            row.conc2:SetShown(visible.conc2 and true or false)
            SetMoxieCellShown(row, visible.moxie and true or false, row._emberMoxieSplit)
            row.forecast:SetShown(visible.forecast and true or false)
            row.cooldown:SetShown(visible.cooldown and true or false)
            if row.cooldownReadyIcon then row.cooldownReadyIcon:SetShown(false) end
            row.mulch:SetShown(visible.mulch and true or false)

            row.charKey = charKey
            row.concData = concData1
            row.forecastData = forecastData
            row.concEntries = concEntries
            row.profEntries = profEntries
            row.cooldownEntries = cooldownSummary and cooldownSummary.entries or nil
            row.moxieEntries = moxieEntries
            row.mulchData = mulchData
            SetFontStringTextIfChanged(row.name, entry.displayName or self:GetCharacterDisplayName(char, charKey))
            local r, g, b = self:GetClassColor(char.class)
            row.name:SetTextColor(r, g, b)
            local isPinned = self:IsCharacterPinned(charKey)
            local isCurrentCharacter = highlightCurrent and currentCharKey and charKey == currentCharKey
            row.isCurrentCharacter = isCurrentCharacter and true or false
            if row.currentHighlight then
                row.currentHighlight:SetShown(isCurrentCharacter and true or false)
                if isCurrentCharacter then row.currentHighlight:SetColorTexture(CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B, IsCompactModeEnabled() and CURRENT_ROW_BG_ALPHA_COMPACT or CURRENT_ROW_BG_ALPHA) end
            end
            if row.edge then
                row.edge:SetShown(isCurrentCharacter and true or false)
                if isCurrentCharacter then row.edge:SetColorTexture(CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B, CURRENT_ROW_EDGE_ALPHA) end
            end
            for _, line in ipairs(row._highlightLines or {}) do
                if line then
                    line:SetShown(isCurrentCharacter and true or false)
                    if isCurrentCharacter then line:SetColorTexture(CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B, CURRENT_ROW_LINE_ALPHA) end
                end
            end
            ApplyTrackingRowHoverState(row, false)
            row.name:SetShadowColor(0.00, 0.00, 0.00, 0.85)
            row.name:SetShadowOffset(1, -1)
            if row.pinGlow then
                row.pinGlow:SetShown(isPinned)
                if isPinned then row.pinGlow:SetColorTexture(PIN_GLOW_R, PIN_GLOW_G, PIN_GLOW_B, PIN_GLOW_ALPHA) end
            end
            if row.pinAccent then
                row.pinAccent:SetShown(isPinned)
                if isPinned then row.pinAccent:SetColorTexture(PIN_GLOW_R, PIN_GLOW_G, PIN_GLOW_B, PIN_ACCENT_ALPHA) end
            end
            SetFontStringTextIfChanged(row.prof1, profValue1)
            row.prof1:SetTextColor(ThemeTextRGB())
            SetFontStringTextIfChanged(row.prof2, profValue2)
            row.prof2:SetTextColor(ThemeTextRGB())
            SetFontStringTextIfChanged(row.conc1, concValue1)
            if concData1 then
                local cr, cg, cb = self:GetConcentrationColor(concQ1 or 0, concData1.maxQuantity or self.CONCENTRATION_MAX_DEFAULT, self:GetProfessionConcentrationThreshold(concData1))
                row.conc1:SetTextColor(cr, cg, cb)
            else
                row.conc1:SetTextColor(0.7, 0.7, 0.7)
            end
            SetFontStringTextIfChanged(row.conc2, concValue2)
            if concData2 then
                local cr, cg, cb = self:GetConcentrationColor(concQ2 or 0, concData2.maxQuantity or self.CONCENTRATION_MAX_DEFAULT, self:GetProfessionConcentrationThreshold(concData2))
                row.conc2:SetTextColor(cr, cg, cb)
            else
                row.conc2:SetTextColor(0.7, 0.7, 0.7)
            end
            if row.full then row.full:Hide() end
            local moxieValues = GetMoxieDisplayValues(charKey, slots)
            local moxieValue = #moxieValues > 0 and table.concat(moxieValues, " / ") or "N/A"
            local useSplitMoxie = visible.moxie and #moxieValues == 2
            row._emberMoxieSplit = useSplitMoxie and true or false
            SetFontStringTextIfChanged(row.moxie, moxieValue)
            SetFontStringTextIfChanged(row.moxieLeft, moxieValues[1] or "")
            SetFontStringTextIfChanged(row.moxieSep, "•")
            SetFontStringTextIfChanged(row.moxieRight, moxieValues[2] or "")
            SetMoxieCellShown(row, visible.moxie and true or false, useSplitMoxie)
            if moxieValue ~= "N/A" then
                if self.HasMoxieAtThreshold and self:HasMoxieAtThreshold(charKey, moxieEntries) then
                    SetMoxieCellColor(row, 0.35, 1.00, 0.45)
                else
                    SetMoxieCellColor(row, ThemeMoxieTextRGB())
                end
            else
                SetMoxieCellColor(row, ThemeMutedTextRGB())
            end
            SetFontStringTextIfChanged(row.forecast, forecastValue)
            if forecastValue == "Ready" or forecastValue:match("^%d+x Ready$") then
                row.forecast:SetTextColor(0.35, 1.00, 0.45)
            else
                row.forecast:SetTextColor(ThemeMutedTextRGB())
            end
            local cooldownReady = cooldownSummary and cooldownSummary.ready and cooldownSummary.ready > 0
            SetFontStringTextIfChanged(row.cooldown, cooldownReady and "" or (cooldownValue or "-"))
            if row.cooldownReadyIcon then
                local iconSize = IsCompactModeEnabled() and 16 or 18
                row.cooldownReadyIcon:SetSize(iconSize, iconSize)
                row.cooldownReadyIcon:SetVertexColor(CD_READY_ICON_R, CD_READY_ICON_G, CD_READY_ICON_B, 1)
                row.cooldownReadyIcon:SetShown(visible.cooldown and cooldownReady and true or false)
            end
            if cooldownReady then
                row.cooldown:SetTextColor(CD_READY_ICON_R, CD_READY_ICON_G, CD_READY_ICON_B)
            elseif cooldownSummary and cooldownSummary.tracked and cooldownSummary.tracked > 0 then
                local ar, ag, ab = ThemeAccentRGB(); row.cooldown:SetTextColor(ar, ag, ab)
            else
                row.cooldown:SetTextColor(ThemeMutedTextRGB())
            end
            SetFontStringTextIfChanged(row.mulch, mulchValue)
            if self:HasImbuedMulchAccess(mulchData) then
                local remain = math.max(0, (tonumber(mulchData.readyAt) or 0) - now)
                local mr, mg, mb = self:GetMulchCountdownColor(remain)
                row.mulch:SetTextColor(mr, mg, mb)
            else
                row.mulch:SetTextColor(0.7, 0.7, 0.7)
            end
            local stripe = (i % 2 == 0) and 0.026 or 0.010
            local bgR = ThemeColor("BG_R", 0.020)
            local bgG = ThemeColor("BG_G", 0.018)
            local bgB = ThemeColor("BG_B", 0.026)
            row.bg:SetColorTexture(math.min(1, bgR + stripe), math.min(1, bgG + stripe), math.min(1, bgB + stripe), IsCompactModeEnabled() and ROW_STRIPE_ALPHA_COMPACT or ROW_STRIPE_ALPHA)
            row:Show()
        end
    end
    for i = #rows + 1, #p.rows do
        p.rows[i]:Hide()
    end
    return #rows, rowH, gap
end
