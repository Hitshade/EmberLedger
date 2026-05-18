local addonName, EL = ...

local ticker
local UIC = EL.UI_CONSTANTS or {}
local PANEL_MIN_W = UIC.PANEL_MIN_W or 352
local TRACKING_DYNAMIC_MIN_W = UIC.TRACKING_DYNAMIC_MIN_W or 260
local TRACKING_COMPACT_MIN_W = UIC.TRACKING_COMPACT_MIN_W or 236
local PANEL_MIN_H = UIC.PANEL_MIN_H or 120
local SESSION_MIN_W = UIC.SESSION_MIN_W or 320
local SESSION_EXPANDED_H = UIC.SESSION_EXPANDED_H or 182
local ACTION_BAR_H = UIC.ACTION_BAR_H or 36
local SESSION_VISIBLE_ITEM_ROWS = UIC.SESSION_VISIBLE_ITEM_ROWS or 4
local SESSION_ITEM_ROW_H = UIC.SESSION_ITEM_ROW_H or 18
local PANEL_DEFAULT_VISIBLE_ROWS = UIC.PANEL_DEFAULT_VISIBLE_ROWS or 12
local TRACKING_ROW_H = 23
local TRACKING_COMPACT_ROW_H = 18
local PANEL_EXPANDED_MIN_H = UIC.PANEL_EXPANDED_MIN_H or 300
local PANEL_MAX_W = UIC.PANEL_MAX_W or 900
local PANEL_MAX_H = UIC.PANEL_MAX_H or 1600
local PANEL_SCREEN_MARGIN = 18
local PANEL_MIN_SCALE = UIC.PANEL_MIN_SCALE or 0.6
local PANEL_MAX_SCALE = UIC.PANEL_MAX_SCALE or 1.4
local READY_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local PIN_GLOW_R, PIN_GLOW_G, PIN_GLOW_B = 1.00, 0.72, 0.18
local PIN_GLOW_ALPHA = 0.060
local PIN_ACCENT_ALPHA = 0.20
local PIN_HOVER_ALPHA = 0.040
local BORDER_R, BORDER_G, BORDER_B = 0.82, 0.66, 0.34
local BORDER_ALPHA_STRONG = 0.78
local BORDER_ALPHA_SOFT = 0.52
local EL_BG_R, EL_BG_G, EL_BG_B = 0.030, 0.024, 0.075
local EL_PANEL_R, EL_PANEL_G, EL_PANEL_B = 0.050, 0.040, 0.115
local EL_HEADER_R, EL_HEADER_G, EL_HEADER_B = 0.030, 0.024, 0.070
local HEADER_LINE_ALPHA_TOP = 0.16
local HEADER_LINE_ALPHA_BOTTOM = 0.30
local ROW_STRIPE_ALPHA = 0.32
local ROW_STRIPE_ALPHA_COMPACT = 0.28
local ROW_SEPARATOR_ALPHA = 0.14

local function UpdateTickerShouldRun()
    return not EL.HasVisibleUpdateConsumers or EL:HasVisibleUpdateConsumers()
end

function EL:RefreshUpdateTicker()
    if not C_Timer or not C_Timer.NewTicker then return end
    if UpdateTickerShouldRun() then
        if not ticker then
            ticker = C_Timer.NewTicker(1, function()
                if UpdateTickerShouldRun() then
                    EL:RequestUpdate()
                elseif EL.RefreshUpdateTicker then
                    EL:RefreshUpdateTicker()
                end
            end)
        end
    elseif ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function SortDashboardConcentrationEntries(a, b)
    local aa = EL:GetProfessionAbbreviation(a)
    local bb = EL:GetProfessionAbbreviation(b)
    if aa == bb then return (a.professionName or "") < (b.professionName or "") end
    return aa < bb
end

local function SortDashboardProfessionEntries(a, b)
    local as = tonumber(a.slot) or 99
    local bs = tonumber(b.slot) or 99
    if as ~= bs then return as < bs end
    return (a.professionName or "") < (b.professionName or "")
end


local function IsCompactModeEnabled()
    local display = EL and EL.db and EL.db.settings and EL.db.settings.display or {}
    return display.compactMode == true
end

local function GetTrackingRowHeight()
    return IsCompactModeEnabled() and TRACKING_COMPACT_ROW_H or TRACKING_ROW_H
end

local function GetTrackingTopPadding()
    return IsCompactModeEnabled() and 42 or 68
end

local function GetTrackingHeaderYOffset()
    return IsCompactModeEnabled() and -42 or -68
end

local function GetTrackingActionBarBottomOffset()
    return IsCompactModeEnabled() and 8 or 10
end

local function IsActionBarAnchoredToPanel()
    return not (EL.IsActionBarFloating and EL:IsActionBarFloating())
end

local function IsAnchoredActionBarShown()
    local enabled = not EL.IsActionBarEnabled or EL:IsActionBarEnabled()
    return enabled and IsActionBarAnchoredToPanel()
end

local function GetTrackingBottomPadding(actionBarShown)
    -- Match the scroll frame's bottom anchor when the action bar is hidden so
    -- auto-height calculations do not clip the last visible character row.
    return actionBarShown and (GetTrackingActionBarBottomOffset() + ACTION_BAR_H + 8) or 34
end

local function ApplyTrackingTextStyle(row)
    if not row then return end
    local fontObject = IsCompactModeEnabled() and GameFontHighlightSmall or GameFontHighlight
    for _, fs in ipairs({row.name, row.prof1, row.conc1, row.prof2, row.conc2, row.moxie, row.moxieLeft, row.moxieSep, row.moxieRight, row.forecast, row.cooldown, row.mulch}) do
        if fs and fs.SetFontObject then fs:SetFontObject(fontObject) end
    end
end

local function ColorTextByRGB(text, r, g, b)
    return EL.Style:ColorTextByRGB(text, r, g, b)
end

local function SetFramePointFromDB(frame, pos)
    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
end

local function SaveFramePoint(frame, pos)
    local point, _, relativePoint, x, y = frame:GetPoint()
    pos.point = point or "CENTER"
    pos.relativePoint = relativePoint or "CENTER"
    pos.x = x or 0
    pos.y = y or 0
end

local function AddBackdrop(frame, alpha, borderAlpha)
    return EL.Style:AddBackdrop(frame, alpha, borderAlpha)
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

local function GetSessionOpacity()
    local db = EL and EL.db
    local value = db and db.settings and db.settings.display and db.settings.display.sessionOpacity
    return math.max(0.20, math.min(1.00, tonumber(value) or 0.55))
end

local function ApplyFrameOpacity(frame, alpha)
    return EL.Style:ApplyFrameOpacity(frame, alpha)
end

local function AddInnerBorder(frame)
    return EL.Style:AddInnerBorder(frame)
end

local function AddHeaderAccent(frame)
    return EL.Style:AddHeaderAccent(frame)
end

local function StyleScrollBar(scrollFrame)
    return EL.Style:StyleScrollBar(scrollFrame)
end

local function DisableButtonArt(button)
    return EL.Style:DisableButtonArt(button)
end

local function GetCurrentPanelMinHeight(panel)
    local db = EL and EL.db
    local settings = db and db.settings and db.settings.panel or {}
    local charShown = settings.charactersShown ~= false
    local actionBarShown = IsAnchoredActionBarShown()

    -- The main window can be used as a compact convenience/action bar when
    -- the character table is hidden from Options. Keep the dynamic minimum
    -- tied to visible content instead of forcing the old tall table height.
    local topPadding = GetTrackingTopPadding()
    local charHeaderH = charShown and (IsCompactModeEnabled() and 28 or 32) or 0
    local charBodyMinH = charShown and (IsCompactModeEnabled() and 54 or 76) or 0
    local bottomPadding = GetTrackingBottomPadding(actionBarShown)
    local compactMin = charShown and (IsCompactModeEnabled() and 156 or 190) or 110

    return math.max(compactMin, topPadding + charHeaderH + charBodyMinH + bottomPadding)
end

local function GetTrackingPanelMaxHeight(panel)
    local minH = GetCurrentPanelMinHeight(panel)
    local screenH = UIParent and UIParent.GetHeight and UIParent:GetHeight()
    if not screenH or screenH <= 0 then
        return math.max(minH, PANEL_MAX_H)
    end

    local screenMax = math.max(minH, screenH - (PANEL_SCREEN_MARGIN * 2))
    local top = panel and panel.GetTop and panel:GetTop()
    if top and top > 0 then
        -- The tracker resizes downward from its current top edge. Limit the
        -- lower edge to the visible screen area instead of using an arbitrary
        -- visible-row cap.
        return math.max(minH, math.min(PANEL_MAX_H, top - PANEL_SCREEN_MARGIN, screenMax))
    end

    return math.max(minH, math.min(PANEL_MAX_H, screenMax))
end

local function ClampPanelSize(panel)
    if not panel then return end
    local minH = GetCurrentPanelMinHeight(panel)
    local minW = (EL.GetTrackingPanelMinWidth and EL:GetTrackingPanelMinWidth()) or PANEL_MIN_W
    local maxW = (EL.GetTrackingPanelMaxWidth and EL:GetTrackingPanelMaxWidth()) or PANEL_MAX_W
    local w = math.max(minW, math.min(maxW, panel:GetWidth() or minW))
    local h = math.max(minH, math.min(GetTrackingPanelMaxHeight(panel), panel:GetHeight() or minH))
    if math.abs((panel:GetWidth() or 0) - w) > 1 or math.abs((panel:GetHeight() or 0) - h) > 1 then
        panel:SetSize(w, h)
    end
end

function EL:GetVisibleTrackingRowCount()
    local allRows = self.GetCharacterRows and self:GetCharacterRows() or {}
    local display = self.db and self.db.settings and self.db.settings.display or {}
    local attentionOnly = display.attentionOnly == true
    local threshold = self.db and self.db.settings and self.db.settings.alerts and self.db.settings.alerts.concentrationThreshold or 360
    local now = time()
    local count = 0
    for _, entry in ipairs(allRows) do
        if entry and entry.key and not self:IsCharacterHidden(entry.key) then
            if not attentionOnly or (self.DoesCharacterNeedAttention and self:DoesCharacterNeedAttention(entry.key, threshold, now)) then
                count = count + 1
            end
        end
    end
    return count
end

function EL:GetTrackingPanelAutoSize()
    local settings = self.db and self.db.settings and self.db.settings.panel or {}
    local charShown = settings.charactersShown ~= false
    local actionBarShown = IsAnchoredActionBarShown()

    local width = (self.GetTrackingPanelMaxWidth and self:GetTrackingPanelMaxWidth()) or PANEL_MIN_W
    local rowCount = charShown and self:GetVisibleTrackingRowCount() or 0
    local tableBodyH = 0
    if charShown then
        tableBodyH = rowCount > 0 and (rowCount * GetTrackingRowHeight()) or 46
    end

    local topPadding = GetTrackingTopPadding()
    local headerAndGapH = charShown and ((IsCompactModeEnabled() and 28 or 32) + 4) or 0
    local bottomPadding = GetTrackingBottomPadding(actionBarShown)
    local height = topPadding + headerAndGapH + tableBodyH + bottomPadding
    local customHeight = tonumber(settings.customHeight)
    if customHeight then
        height = customHeight
    end
    height = math.max(GetCurrentPanelMinHeight(self.panel), math.min(GetTrackingPanelMaxHeight(self.panel), height))
    return math.floor(width + 0.5), math.floor(height + 0.5)
end

function EL:ClearTrackingPanelCustomHeight()
    local settings = self.db and self.db.settings and self.db.settings.panel
    if not settings then return end
    settings.customHeight = nil
    if self.LayoutPanel then self:LayoutPanel() end
    if self.RequestUpdate then self:RequestUpdate(true) end
end

local function SetTrackingPanelVerticalHeight(panel, height)
    local settings = EL and EL.db and EL.db.settings and EL.db.settings.panel
    if not panel or not settings then return end
    local targetW = (EL.GetTrackingPanelMaxWidth and EL:GetTrackingPanelMaxWidth()) or (panel:GetWidth() or PANEL_MIN_W)
    local minH = GetCurrentPanelMinHeight(panel)
    local targetH = math.max(minH, math.min(GetTrackingPanelMaxHeight(panel), tonumber(height) or minH))
    local left, top = panel:GetLeft(), panel:GetTop()
    panel._autoSizingPanel = true
    panel:SetSize(targetW, targetH)
    if left and top then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        SaveFramePoint(panel, settings)
    end
    panel._autoSizingPanel = false
    settings.width = targetW
    settings.height = targetH
    settings.customHeight = targetH
    settings.expandedHeight = targetH
end

function EL:AutoSizeTrackingPanel(reason)
    local panel = self.panel
    local settings = self.db and self.db.settings and self.db.settings.panel
    if not panel or not settings or panel._autoSizingPanel then return end

    local targetW, targetH = self:GetTrackingPanelAutoSize()
    local currentW, currentH = panel:GetWidth() or targetW, panel:GetHeight() or targetH
    if math.abs(currentW - targetW) <= 1 and math.abs(currentH - targetH) <= 1 then return end

    local left, top = panel:GetLeft(), panel:GetTop()
    panel._autoSizingPanel = true
    panel:SetSize(targetW, targetH)
    if left and top then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        SaveFramePoint(panel, settings)
    end
    panel._autoSizingPanel = false

    settings.width = targetW
    settings.height = targetH
    settings.expandedHeight = targetH
end

function EL:SaveExpandedPanelHeight()
    local p = self.panel
    local settings = self.db and self.db.settings and self.db.settings.panel
    if not p or not settings then return end

    -- Remember a useful expanded height so collapsing does not permanently
    -- trap the window at a tiny size when the character list is reopened.
    if not settings.charactersCollapsed then
        local h = math.floor(p:GetHeight() or 0)
        if h and h > PANEL_MIN_H then
            settings.expandedHeight = math.max(PANEL_MIN_H, math.min(GetTrackingPanelMaxHeight(p), h))
        end
    end
end

function EL:ToggleCharacterSectionCollapsed()
    local settings = self.db and self.db.settings and self.db.settings.panel
    if not settings then return end

    local wasCollapsed = settings.charactersCollapsed and true or false
    if not wasCollapsed then
        self:SaveExpandedPanelHeight()
    end

    settings.charactersCollapsed = not wasCollapsed

    if self.LayoutPanel then self:LayoutPanel() end
    if self.AutoSizePanelHeight then
        self:AutoSizePanelHeight(wasCollapsed and "expandCharacter" or "collapseCharacter")
    end
    if self.RequestUpdate then self:RequestUpdate() end
end

local HEADER_LABELS = {
    character = "Character",
    prof1 = "P1",
    conc1 = "Conc 1",
    prof2 = "P2",
    conc2 = "Conc 2",
    moxie = "Moxie",
    forecast = "Next",
    cooldown = "CD",
    mulch = "Mulch",
}

local TRACKING_COLUMN_DEFS = {
    { key = "character", label = "Character", width = 138, minWidth = 118, compactWidth = 112, compactMinWidth = 94, justify = "LEFT", sortKey = "character", alwaysVisible = true },
    { key = "prof1", label = "P1", width = 34, minWidth = 30, compactWidth = 28, compactMinWidth = 26, justify = "CENTER", sortKey = "prof1", setting = "showProfession1Column", toggleLabel = "Prof 1 column" },
    { key = "conc1", label = "Conc 1", width = 86, minWidth = 86, compactWidth = 68, compactMinWidth = 68, justify = "RIGHT", sortKey = "conc1", setting = "showConcentration1Column", toggleLabel = "Conc 1 column" },
    { key = "prof2", label = "P2", width = 34, minWidth = 30, compactWidth = 28, compactMinWidth = 26, justify = "CENTER", sortKey = "prof2", setting = "showProfession2Column", toggleLabel = "Prof 2 column", secondary = true },
    { key = "conc2", label = "Conc 2", width = 86, minWidth = 86, compactWidth = 68, compactMinWidth = 68, justify = "RIGHT", sortKey = "conc2", setting = "showConcentration2Column", toggleLabel = "Conc 2 column", secondary = true },
    { key = "forecast", label = "Next", width = 84, minWidth = 72, compactWidth = 72, compactMinWidth = 64, justify = "RIGHT", sortKey = "forecast", setting = "showForecastColumn", toggleLabel = "Next column" },
    { key = "moxie", label = "Moxie", width = 82, minWidth = 78, compactWidth = 70, compactMinWidth = 64, justify = "RIGHT", sortKey = "moxie", setting = "showMoxieColumn", toggleLabel = "Moxie column" },
    { key = "cooldown", label = "CD", width = 42, minWidth = 36, compactWidth = 34, compactMinWidth = 30, justify = "CENTER", sortKey = "cooldown", setting = "showCooldownColumn", toggleLabel = "Cooldown readiness column", autoHide = true },
    { key = "mulch", label = "Mulch", width = 68, minWidth = 64, compactWidth = 60, compactMinWidth = 58, justify = "RIGHT", sortKey = "mulch", setting = "showMulchColumn", toggleLabel = "Mulch column" },
}

local TRACKING_COLUMN_BY_KEY = {}
for _, def in ipairs(TRACKING_COLUMN_DEFS) do
    TRACKING_COLUMN_BY_KEY[def.key] = def
end

local function GetTrackingColumnWidth(def, useMin)
    if not def then return 40 end
    local compact = IsCompactModeEnabled()
    if def.key == "character" then
        local display = EL.db and EL.db.settings and EL.db.settings.display or {}
        if display.showCharacterRealm == false then
            if compact then return useMin and 74 or 84 end
            return useMin and 82 or 92
        end
    end
    if compact then
        if useMin then return def.compactMinWidth or def.minWidth or def.compactWidth or def.width or 40 end
        return def.compactWidth or def.width or def.compactMinWidth or def.minWidth or 40
    end
    if useMin then return def.minWidth or def.width or 40 end
    return def.width or def.minWidth or 40
end

function EL:HasSecondaryConcentrationColumnData()
    for charKey, list in pairs(self.db and self.db.resources and self.db.resources.professions or {}) do
        if charKey and not self:IsCharacterHidden(charKey) and type(list) == "table" and #list > 1 then
            return true
        end
    end

    local chars = {}
    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        local charKey = data and data.charKey
        if charKey and not self:IsCharacterHidden(charKey) then
            chars[charKey] = (chars[charKey] or 0) + 1
            if chars[charKey] > 1 then return true end
        end
    end
    return false
end

local TRACKING_COLUMN_DEFAULT_SETTINGS = {
    showProfession1Column = true,
    showConcentration1Column = true,
    showProfession2Column = true,
    showConcentration2Column = true,
    showMoxieColumn = false,
    showMulchColumn = true,
    showCooldownColumn = true,
    showForecastColumn = false,
    showCharacterRealm = true,
    showProfessionColumn = true,
    showConcentrationColumn = true,
}

function EL:GetTrackingColumnSettings()
    local settings = self.db and self.db.settings
    local display = settings and settings.display
    if type(display) ~= "table" then return TRACKING_COLUMN_DEFAULT_SETTINGS end
    return display
end

function EL:IsTrackingColumnVisible(key)
    if key == "prof" then key = "prof1" end
    if key == "conc" then key = "conc1" end
    if key == "character" then return true end
    local def = TRACKING_COLUMN_BY_KEY[key]
    if not def or not def.setting then return false end
    if def.secondary and not self:HasSecondaryConcentrationColumnData() then return false end
    if def.key == "cooldown" and def.autoHide and self.HasProfessionCooldownColumnData and not self:HasProfessionCooldownColumnData() then return false end
    local display = self:GetTrackingColumnSettings()
    return display[def.setting] ~= false
end

function EL:GetVisibleTrackingColumns()
    local columns = {}
    for _, def in ipairs(TRACKING_COLUMN_DEFS) do
        if def.alwaysVisible or self:IsTrackingColumnVisible(def.key) then
            table.insert(columns, def)
        end
    end
    return columns
end

function EL:GetTrackingPanelMinWidth()
    local columns = self:GetVisibleTrackingColumns()
    local totalWidth = 44
    for _, def in ipairs(columns) do
        totalWidth = totalWidth + GetTrackingColumnWidth(def, true)
    end
    totalWidth = totalWidth + (math.max(0, #columns - 1) * 6)
    local baseMin = IsCompactModeEnabled() and TRACKING_COMPACT_MIN_W or TRACKING_DYNAMIC_MIN_W
    return math.max(baseMin, math.min(PANEL_MAX_W, totalWidth))
end

function EL:GetTrackingPanelMaxWidth()
    local columns = self:GetVisibleTrackingColumns()
    local optionalWidth = 0
    local optionalCount = 0
    for _, def in ipairs(columns) do
        if def.key ~= "character" then
            optionalWidth = optionalWidth + GetTrackingColumnWidth(def, false)
            optionalCount = optionalCount + 1
        end
    end
    local realmShown = self.db and self.db.settings and self.db.settings.display and self.db.settings.display.showCharacterRealm ~= false
    local compact = IsCompactModeEnabled()
    local characterMax = realmShown and (optionalCount <= 1 and (compact and 140 or 176) or GetTrackingColumnWidth(TRACKING_COLUMN_BY_KEY.character, false)) or (optionalCount <= 1 and (compact and 92 or 104) or GetTrackingColumnWidth(TRACKING_COLUMN_BY_KEY.character, false))
    local framePadding = 36
    local tableMargins = 6
    local gaps = math.max(0, #columns - 1) * 6
    local naturalMax = framePadding + tableMargins + characterMax + optionalWidth + gaps
    local minW = self:GetTrackingPanelMinWidth()
    return math.max(minW, math.min(PANEL_MAX_W, naturalMax))
end

local function GetColumnLayout(width)
    width = math.max(1, tonumber(width) or 1)
    local margin = 3
    local gap = 6
    local columns = EL:GetVisibleTrackingColumns()
    local layout = { columns = columns }
    local fixedW = margin * 2
    local optionalCount = 0
    for _, def in ipairs(columns) do
        if def.key ~= "character" then
            fixedW = fixedW + GetTrackingColumnWidth(def, false)
            optionalCount = optionalCount + 1
        end
    end
    fixedW = fixedW + (gap * math.max(0, #columns - 1))
    local characterDef = TRACKING_COLUMN_BY_KEY.character or {}
    local nameMin = GetTrackingColumnWidth(characterDef, true)
    local realmShown = EL.db and EL.db.settings and EL.db.settings.display and EL.db.settings.display.showCharacterRealm ~= false
    local compact = IsCompactModeEnabled()
    local nameMax = realmShown and (optionalCount <= 1 and (compact and 140 or 176) or GetTrackingColumnWidth(characterDef, false)) or (optionalCount <= 1 and (compact and 92 or 104) or GetTrackingColumnWidth(characterDef, false))
    local nameW = math.max(nameMin, width - fixedW)
    layout.nameW = math.min(nameW, math.max(nameMin, nameMax))
    if width - fixedW < layout.nameW then
        layout.nameW = math.max(nameMin, width - fixedW)
    end

    local x = margin
    for _, def in ipairs(columns) do
        local colW = def.key == "character" and layout.nameW or GetTrackingColumnWidth(def, false)
        layout[def.key .. "X"] = x
        layout[def.key .. "W"] = colW
        layout[def.key .. "Def"] = def
        x = x + colW + gap
    end
    layout.nameX = layout.characterX or margin
    layout.prof1X, layout.prof1W = layout.prof1X or 0, layout.prof1W or 1
    layout.conc1X, layout.conc1W = layout.conc1X or 0, layout.conc1W or 1
    layout.prof2X, layout.prof2W = layout.prof2X or 0, layout.prof2W or 1
    layout.conc2X, layout.conc2W = layout.conc2X or 0, layout.conc2W or 1
    layout.moxieX, layout.moxieW = layout.moxieX or 0, layout.moxieW or 1
    layout.forecastX, layout.forecastW = layout.forecastX or 0, layout.forecastW or 1
    layout.cooldownX, layout.cooldownW = layout.cooldownX or 0, layout.cooldownW or 1
    layout.mulchX, layout.mulchW = layout.mulchX or 0, layout.mulchW or 1
    return layout
end

local function AnchorColumnText(fs, parent, x, width, justify)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", parent, "LEFT", x, 0)
    fs:SetPoint("RIGHT", parent, "LEFT", x + width, 0)
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
end

local function AnchorMoxieCell(row, parent, x, width)
    if not row or not parent then return end
    width = math.max(1, tonumber(width) or 1)
    local sepW = math.min(14, math.max(8, math.floor(width * 0.16 + 0.5)))
    local sideW = math.max(1, math.floor((width - sepW) / 2))
    local rightW = math.max(1, width - sepW - sideW)

    AnchorColumnText(row.moxie, parent, x, width, "CENTER")

    if row.moxieLeft then
        AnchorColumnText(row.moxieLeft, parent, x, sideW, "RIGHT")
    end
    if row.moxieSep then
        AnchorColumnText(row.moxieSep, parent, x + sideW, sepW, "CENTER")
    end
    if row.moxieRight then
        AnchorColumnText(row.moxieRight, parent, x + sideW + sepW, rightW, "LEFT")
    end
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

local function GetTextWidth(fs)
    if not fs then return 0 end
    if fs.GetUnboundedStringWidth then return fs:GetUnboundedStringWidth() or 0 end
    return fs:GetStringWidth() or 0
end

local function FormatSessionTime(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    if hours > 0 then
        return string.format("%dh %02dm", hours, mins)
    end
    return string.format("%dm %02ds", mins, secs)
end

local function FormatActionCooldownText(seconds)
    seconds = math.max(0, math.ceil(tonumber(seconds) or 0))
    if seconds <= 1 then return "" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    if days > 0 then return tostring(days) .. "d" end
    if hours > 0 then return tostring(hours) .. "h" end
    if mins > 0 then return tostring(mins) .. "m" end
    return tostring(seconds)
end

local function CreateHeaderButton(parent, fontString, sortKey)
    local b = CreateFrame("Button", nil, parent)
    DisableButtonArt(b)
    b.sortKey = sortKey
    b.fontString = fontString
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(1, 0.72, 0.22, 0)
    b:SetScript("OnClick", function(self)
        EL:SetSortKey(self.sortKey)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Sort by " .. (HEADER_LABELS[self.sortKey] or self.sortKey), 1, 0.82, 0.24)
        GameTooltip:AddLine("Click again to reverse the order.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end


function EL:ApplyDisplaySettings()
    if self.panel then
        ApplyFrameOpacity(self.panel, GetPanelOpacity())
    end
    if self.button then
        ApplyFrameOpacity(self.button, GetLauncherOpacity())
    end
    if self.settingsPanel then
        ApplyFrameOpacity(self.settingsPanel, GetPanelOpacity())
    end
    if self.sessionWindow then
        ApplyFrameOpacity(self.sessionWindow, GetSessionOpacity())
    end
    if self.sessionWindow and self.sessionWindow.sessionPanel then
        ApplyFrameOpacity(self.sessionWindow.sessionPanel, math.max(0.20, GetSessionOpacity() - 0.09))
    end
end


function EL:RefreshLayout(reason)
    if self.IsCombatLocked and self:IsCombatLocked() then
        if self.QueueCombatDeferredWork then self:QueueCombatDeferredWork("layout") end
        return
    end
    if self.ApplyDisplaySettings then self:ApplyDisplaySettings() end
    if self.LayoutPanel then self:LayoutPanel() end
    if self.LayoutSessionWindow then self:LayoutSessionWindow() end
    if self.UpdateActionBar then self:UpdateActionBar() end
    if self.UpdateButton then self:UpdateButton() end
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
end

local function StyleBlizzardButton(button)
    return EL.Style:StyleBlizzardButton(button)
end

local function AddSoftDivider(parent, x, yTop, yBottom)
    local line = parent:CreateTexture(nil, "BORDER")
    line:SetWidth(1)
    line:SetColorTexture(0.95, 0.82, 0.42, 0.22)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, yTop)
    line:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", x, yBottom)
    return line
end

local function CreateMetricBlock(parent, label)
    local f = CreateFrame("Frame", nil, parent)
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.label:SetPoint("TOP", f, "TOP", 0, 0)
    f.label:SetText(label)
    f.label:SetTextColor(0.55, 0.78, 0.98)
    f.value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.value:SetPoint("TOP", f.label, "BOTTOM", 0, -3)
    f.value:SetTextColor(0.92, 0.90, 0.84)
    f.value:SetJustifyH("CENTER")
    return f
end

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


local function ShowSettingsConfirm(text, acceptText, onAccept)
    if not onAccept then return end
    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs["EMBERLEDGER_CONFIRM_ACTION"] = {
            text = text or "Are you sure?",
            button1 = acceptText or YES,
            button2 = CANCEL,
            OnAccept = function() onAccept() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("EMBERLEDGER_CONFIRM_ACTION")
    else
        onAccept()
    end
end

function EL:ConfirmResetWindowPositions()
    ShowSettingsConfirm("Reset all EmberLedger window positions? Scale and visibility settings will be kept.", "Reset", function()
        if EL.ResetWindowPositions then EL:ResetWindowPositions() end
    end)
end

function EL:ConfirmResetSession()
    ShowSettingsConfirm("Reset the current session totals and tracked item list?", "Reset", function()
        if EL.ResetSession then EL:ResetSession() end
    end)
end

function EL:ConfirmResetSessionHistory()
    ShowSettingsConfirm("Clear all saved account-wide session history? This cannot be undone.", "Clear History", function()
        if EL.ResetSessionHistory then EL:ResetSessionHistory() end
    end)
end

function EL:ConfirmResetLifetimeSessionStats()
    ShowSettingsConfirm("Reset EmberLedger lifetime session stats? This cannot be undone. Session history will not be deleted.", "Reset Lifetime", function()
        if EL.ResetLifetimeSessionStats then EL:ResetLifetimeSessionStats() end
    end)
end

function EL:ConfirmRestoreHiddenCharacters()
    ShowSettingsConfirm("Unhide all hidden characters and return them to the main window table?", "Unhide All", function()
        if EL.RestoreHiddenCharacters then EL:RestoreHiddenCharacters() end
    end)
end

function EL:ConfirmResetPinnedCharacters()
    ShowSettingsConfirm("Remove all pinned character markers? Character data will not be deleted.", "Reset", function()
        if EL.ResetPinnedCharacters then EL:ResetPinnedCharacters() end
    end)
end

local function MakeSettingsCheck(parent, text, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb.Text:SetText(text)
    cb.Text:SetTextColor(0.88, 0.86, 0.78)
    cb.Text:SetFontObject(GameFontHighlightSmall)
    cb:SetScript("OnClick", onClick)
    cb.text = cb.Text
    return cb
end

local function SetSettingsTooltip(widget, title, lines)
    if not widget then return end
    widget:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "EmberLedger", 1.00, 0.82, 0.24)
        if lines then
            for _, line in ipairs(lines) do
                GameTooltip:AddLine(line, 0.86, 0.86, 0.78, true)
            end
        end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end


local function IsOptionsWindow(frame)
    return frame and EL and frame == EL.settingsPanel
end

local function BringEmberWindowToFront(frame)
    if not frame or not EL then return end

    -- Keep the Options panel above normal UI because it is a configuration dialog.
    -- All other EmberLedger windows stay below Blizzard's standard panel strata so
    -- character, profession, inventory, and other native windows remain on top.
    if IsOptionsWindow(frame) then
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
    BringEmberWindowToFront(frame)
end

local function HideSessionHistoryDisplayDropdown()
    if EL and EL.sessionHistoryDisplayDropdown then
        EL.sessionHistoryDisplayDropdown:Hide()
    end
end

local function ShowSessionHistoryDisplayDropdown(anchor)
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
                    HideSessionHistoryDisplayDropdown()
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
        AddBackdrop(menu, 0.95, 0.78)
        if menu.SetBackdropColor then menu:SetBackdropColor(0.012, 0.010, 0.024, 0.98) end
        AddInnerBorder(menu)
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
            btn.highlight:SetColorTexture(1.00, 0.78, 0.24, 0.10)
            btn.highlight:Hide()
            btn:SetScript("OnEnter", function(self)
                if self.highlight then self.highlight:Show() end
                if self.text then self.text:SetTextColor(1.00, 0.82, 0.24) end
            end)
            btn:SetScript("OnLeave", function(self)
                local currentMode = (EL.GetSessionHistoryDisplayMode and EL:GetSessionHistoryDisplayMode()) or "30"
                if self.highlight then self.highlight:SetShown(self.mode == currentMode) end
                if self.text then
                    if self.mode == currentMode then
                        self.text:SetTextColor(0.42, 1.00, 0.32)
                    else
                        self.text:SetTextColor(0.92, 0.90, 0.82)
                    end
                end
            end)
            btn:SetScript("OnClick", function(self)
                if EL.SetSessionHistoryDisplayMode then EL:SetSessionHistoryDisplayMode(self.mode) end
                HideSessionHistoryDisplayDropdown()
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
                    btn.text:SetTextColor(0.92, 0.90, 0.82)
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
    box.label:SetTextColor(0.92, 0.86, 0.72)

    box.value = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    box.value:SetPoint("RIGHT", box, "RIGHT", 0, 0)
    box.value:SetWidth(52)
    box.value:SetTextColor(1.00, 0.92, 0.56)
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

local function MakeSettingsSection(parent, title, x, y, w, h)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    section:SetSize(w, h)
    AddBackdrop(section, math.max(0.20, GetPanelOpacity() - 0.10), 0.25)
    section.title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    section.title:SetPoint("TOPLEFT", 12, -9)
    section.title:SetText(title)
    section.title:SetTextColor(1.00, 0.72, 0.18)
    section.line = section:CreateTexture(nil, "BORDER")
    section.line:SetColorTexture(1.00, 0.72, 0.18, 0.18)
    section.line:SetHeight(1)
    section.line:SetPoint("TOPLEFT", 12, -28)
    section.line:SetPoint("TOPRIGHT", -12, -28)
    return section
end

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
    f:SetSize(660, 650)
    f:SetScale(1)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    AddBackdrop(f, GetPanelOpacity(), 0.55)
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

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 16, -12)
    f.title:SetText("EmberLedger Options")
    f.title:SetTextColor(1.00, 0.82, 0.24)

    f.close = MakeSettingsButton(f, "×", 24, function() f:Hide() end)
    f.close:SetPoint("TOPRIGHT", -10, -10)

    f.nav = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.nav:SetPoint("TOPLEFT", 14, -42)
    f.nav:SetSize(140, 560)
    AddBackdrop(f.nav, 0.28, 0.35)

    local navItems = {
        {"General", "Interface\\Icons\\INV_Misc_Gear_01"},
        {"Launcher", "Interface\\Icons\\INV_Misc_Rune_01"},
        {"Session", "Interface\\Icons\\INV_Misc_Coin_01"},
        {"Main Window", "Interface\\Icons\\INV_Inscription_Tradeskill01"},
        {"Action Bar", "Interface\\Icons\\INV_Misc_EngGizmos_17"},
        {"Performance", "Interface\\Icons\\Ability_Rogue_Sprint"},
        {"Maintenance", "Interface\\Icons\\Trade_Engineering"},
    }
    f.navLabels = {}
    local ny = -14
    f.navByName = {}
    for i, data in ipairs(navItems) do
        local row = CreateFrame("Button", nil, f.nav, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 8, ny)
        row:SetSize(124, 30)
        AddBackdrop(row, 0.10, 0.10)
        if row.SetBackdropColor then row:SetBackdropColor(0.02, 0.02, 0.03, 0.00) end
        if row.SetBackdropBorderColor then row:SetBackdropBorderColor(1.0, 0.72, 0.18, 0.00) end
        row.pageName = data[1]
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexture(data[2])
        row.text = row:CreateFontString(nil, "OVERLAY", i == 1 and "GameFontNormalSmall" or "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.text:SetText(data[1])
        row.text:SetTextColor(i == 1 and 1 or 0.86, i == 1 and 0.82 or 0.84, i == 1 and 0.24 or 0.78)
        row:SetScript("OnClick", function(self)
            if EL.SelectSettingsPage then EL:SelectSettingsPage(self.pageName) end
        end)
        row:SetScript("OnEnter", function(self)
            if self.SetBackdropColor and EL.settingsPanel and EL.settingsPanel.currentPage ~= self.pageName then
                self:SetBackdropColor(0.18, 0.10, 0.06, 0.35)
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

    f.generalSection = MakeSettingsSection(f, "General Controls", contentX, -42, contentW, 118)
    f.showLauncher = MakeSettingsCheck(f.generalSection, "Show launcher", function() EL:ToggleSectionSetting("launcher") end)
    f.showLauncher:SetPoint("TOPLEFT", 12, -36)
    f.toggleCharactersSection = MakeSettingsCheck(f.generalSection, "Show main window", function() EL:ToggleSectionSetting("characters") end)
    f.toggleCharactersSection:SetPoint("TOPLEFT", 12, -62)
    f.toggleSessionSection = MakeSettingsCheck(f.generalSection, "Show session window", function() EL:ToggleSectionSetting("session") end)
    f.toggleSessionSection:SetPoint("TOPLEFT", 238, -36)
    SetSettingsTooltip(f.toggleSessionSection, "Show session window", {"Toggles only the standalone Session window.", "Launcher session lines are controlled separately on the Launcher page."})
    f.lockWindows = MakeSettingsCheck(f.generalSection, "Lock windows", function() EL:ToggleLockWindows() end)
    f.lockWindows:SetPoint("TOPLEFT", 238, -62)
    f.toggleAttentionOnly = MakeSettingsCheck(f.generalSection, "Attention Only view", function() EL:ToggleDisplaySetting("attentionOnly") end)
    f.toggleAttentionOnly:SetPoint("TOPLEFT", 12, -88)
    f.showMinimapButton = MakeSettingsCheck(f.generalSection, "Show minimap button", function() if EL.ToggleMinimapButton then EL:ToggleMinimapButton() end end)
    f.showMinimapButton:SetPoint("TOPLEFT", 238, -88)
    f.appearanceSection = MakeSettingsSection(f, "Appearance", contentX, -142, contentW, 150)
    f.launcherOpacitySlider = MakeSettingsSlider(f.appearanceSection, "Launcher opacity", 20, 100, 5, function(v) return string.format("%d%%", v) end, function(v)
        EL:SetAbsoluteSetting("launcherOpacity", v / 100)
    end)
    f.launcherOpacitySlider:SetPoint("TOPLEFT", 12, -38)
    f.panelOpacitySlider = MakeSettingsSlider(f.appearanceSection, "Main window opacity", 20, 100, 5, function(v) return string.format("%d%%", v) end, function(v)
        EL:SetAbsoluteSetting("panelOpacity", v / 100)
    end)
    f.panelOpacitySlider:SetPoint("TOPLEFT", 12, -72)
    f.sessionOpacitySlider = MakeSettingsSlider(f.appearanceSection, "Session opacity", 20, 100, 5, function(v) return string.format("%d%%", v) end, function(v)
        EL:SetAbsoluteSetting("sessionOpacity", v / 100)
    end)
    f.sessionOpacitySlider:SetPoint("TOPLEFT", 12, -106)

    f.scaleSection = MakeSettingsSection(f, "Scale", contentX, -304, contentW, 112)
    f.scaleSlider = MakeSettingsSlider(f.scaleSection, "Main window scale", 60, 140, 5, function(v) return string.format("%d%%", v) end, function(v)
        EL:SetAbsoluteSetting("panelScale", v / 100)
    end)
    f.scaleSlider:SetPoint("TOPLEFT", 12, -38)
    f.sessionScaleSlider = MakeSettingsSlider(f.scaleSection, "Session window scale", 60, 140, 5, function(v) return string.format("%d%%", v) end, function(v)
        EL:SetAbsoluteSetting("sessionScale", v / 100)
    end)
    f.sessionScaleSlider:SetPoint("TOPLEFT", 12, -72)

    f.mainWindowTogglesSection = MakeSettingsSection(f, "Main Window Toggles", contentX, -498, contentW, 122)
    local mainWindowToggleLeftX = 12
    local mainWindowToggleRightX = 250
    f.toggleCompactMode = MakeSettingsCheck(f.mainWindowTogglesSection, "Compact Mode", function() EL:ToggleDisplaySetting("compactMode") end)
    f.toggleCompactMode:SetPoint("TOPLEFT", mainWindowToggleLeftX, -34)
    f.toggleCharacterRealm = MakeSettingsCheck(f.mainWindowTogglesSection, "Show character realm", function() EL:ToggleDisplaySetting("showCharacterRealm") end)
    f.toggleCharacterRealm:SetPoint("TOPLEFT", mainWindowToggleRightX, -34)
    f.togglePinnedFirst = MakeSettingsCheck(f.mainWindowTogglesSection, "Show pinned first", function() EL:ToggleDisplaySetting("showPinnedFirst") end)
    f.togglePinnedFirst:SetPoint("TOPLEFT", mainWindowToggleLeftX, -60)
    f.toggleCurrentCharacterFirst = MakeSettingsCheck(f.mainWindowTogglesSection, "Current character first", function() EL:ToggleDisplaySetting("showCurrentCharacterFirst") end)
    f.toggleCurrentCharacterFirst:SetPoint("TOPLEFT", mainWindowToggleRightX, -60)
    f.toggleCurrentCharacterHighlight = MakeSettingsCheck(f.mainWindowTogglesSection, "Highlight current character", function() EL:ToggleDisplaySetting("highlightCurrentCharacter") end)
    f.toggleCurrentCharacterHighlight:SetPoint("TOPLEFT", mainWindowToggleLeftX, -86)

    f.thresholdSection = MakeSettingsSection(f, "Resource Thresholds", contentX, -632, contentW, 122)
    f.thresholdSlider = MakeSettingsSlider(f.thresholdSection, "Concentration ready threshold", 0, 1000, 10, function(v) return tostring(math.floor(v + 0.5)) end, function(v)
        EL:SetAbsoluteSetting("concThreshold", math.floor(v + 0.5))
    end)
    f.thresholdSlider:SetPoint("TOPLEFT", 12, -38)
    f.moxieThresholdSlider = MakeSettingsSlider(f.thresholdSection, "Moxie spend threshold", 0, 1000, 25, function(v) return tostring(math.floor(v + 0.5)) end, function(v)
        EL:SetAbsoluteSetting("moxieThreshold", math.floor(v + 0.5))
    end)
    f.moxieThresholdSlider:SetPoint("TOPLEFT", 12, -78)

    f.trackingColumnsSection = MakeSettingsSection(f, "Main Window Columns", contentX, -766, contentW, 122)
    local trackingColumnLeftX = 12
    local trackingColumnRightX = 250
    f.toggleProf1Column = MakeSettingsCheck(f.trackingColumnsSection, "Show Prof 1 column", function() EL:ToggleTrackingColumn("prof1") end)
    f.toggleProf1Column:SetPoint("TOPLEFT", trackingColumnLeftX, -34)
    f.toggleConc1Column = MakeSettingsCheck(f.trackingColumnsSection, "Show Conc 1 column", function() EL:ToggleTrackingColumn("conc1") end)
    f.toggleConc1Column:SetPoint("TOPLEFT", trackingColumnRightX, -34)
    f.toggleProf2Column = MakeSettingsCheck(f.trackingColumnsSection, "Allow Prof 2 column", function() EL:ToggleTrackingColumn("prof2") end)
    f.toggleProf2Column:SetPoint("TOPLEFT", trackingColumnLeftX, -60)
    f.toggleConc2Column = MakeSettingsCheck(f.trackingColumnsSection, "Allow Conc 2 column", function() EL:ToggleTrackingColumn("conc2") end)
    f.toggleConc2Column:SetPoint("TOPLEFT", trackingColumnRightX, -60)
    f.toggleMoxieColumn = MakeSettingsCheck(f.trackingColumnsSection, "Show Moxie column", function() EL:ToggleTrackingColumn("moxie") end)
    f.toggleMoxieColumn:SetPoint("TOPLEFT", trackingColumnLeftX, -86)
    f.toggleMulchColumn = MakeSettingsCheck(f.trackingColumnsSection, "Show Imbued Mulch column", function() EL:ToggleTrackingColumn("mulch") end)
    f.toggleMulchColumn:SetPoint("TOPLEFT", trackingColumnRightX, -86)

    f.nextColumnSection = MakeSettingsSection(f, "Next Column", contentX, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_NEXT_COLUMN_Y) or -926, contentW, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_NEXT_COLUMN_H) or 88)
    f.nextColumnDesc = f.nextColumnSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.nextColumnDesc:SetPoint("TOPLEFT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_LEFT) or 12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_TOP) or -36)
    f.nextColumnDesc:SetPoint("TOPRIGHT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_RIGHT) or -12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_TOP) or -36)
    f.nextColumnDesc:SetJustifyH("LEFT")
    if f.nextColumnDesc.SetWordWrap then f.nextColumnDesc:SetWordWrap(true) end
    f.nextColumnDesc:SetTextColor(0.82, 0.82, 0.76)
    f.nextColumnDesc:SetText("Shows the next concentration readiness forecast based on your threshold and regeneration timing.")
    f.toggleForecastColumn = MakeSettingsCheck(f.nextColumnSection, "Show Next column", function() EL:ToggleTrackingColumn("forecast") end)
    f.toggleForecastColumn:SetPoint("TOPLEFT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_LEFT) or 12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_NEXT_COLUMN_CHECK_Y) or -62)

    f.cooldownColumnSection = MakeSettingsSection(f, "Cooldown Readiness Column", contentX, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COOLDOWN_COLUMN_Y) or -1026, contentW, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COOLDOWN_COLUMN_H) or 94)
    f.cooldownColumnDesc = f.cooldownColumnSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.cooldownColumnDesc:SetPoint("TOPLEFT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_LEFT) or 12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_TOP) or -36)
    f.cooldownColumnDesc:SetPoint("TOPRIGHT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_RIGHT) or -12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_TOP) or -36)
    f.cooldownColumnDesc:SetJustifyH("LEFT")
    if f.cooldownColumnDesc.SetWordWrap then f.cooldownColumnDesc:SetWordWrap(true) end
    f.cooldownColumnDesc:SetTextColor(0.82, 0.82, 0.76)
    f.cooldownColumnDesc:SetText("Shows readiness for supported profession cooldown crafts. Hover character rows for details and timers.")
    f.toggleCooldownColumn = MakeSettingsCheck(f.cooldownColumnSection, "Show CD column", function() EL:ToggleTrackingColumn("cooldown") end)
    f.toggleCooldownColumn:SetPoint("TOPLEFT", (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COLUMN_DESC_LEFT) or 12, (EL.UI_CONSTANTS and EL.UI_CONSTANTS.OPTIONS_COOLDOWN_COLUMN_CHECK_Y) or -68)
    SetSettingsTooltip(f.toggleCooldownColumn, "Profession cooldown readiness", {"Adds a compact CD column for supported profession cooldown crafts.", "Details appear in the row tooltip."})
    f.launcherSection = MakeSettingsSection(f, "Launcher Display", contentX, -598, contentW, 88)
    f.toggleConc = MakeSettingsCheck(f.launcherSection, "Concentration alert", function() EL:ToggleDisplaySetting("showLauncherConc") end)
    f.toggleConc:SetPoint("TOPLEFT", 12, -34)
    f.toggleMulch = MakeSettingsCheck(f.launcherSection, "Mulch", function() EL:ToggleDisplaySetting("showLauncherMulch") end)
    f.toggleMulch:SetPoint("TOPLEFT", 178, -34)
    f.toggleSession = MakeSettingsCheck(f.launcherSection, "Session rate", function() EL:ToggleDisplaySetting("showLauncherSession") end)
    f.toggleSession:SetPoint("TOPLEFT", 294, -34)
    f.toggleTotal = MakeSettingsCheck(f.launcherSection, "Session total", function() EL:ToggleDisplaySetting("showLauncherSessionTotal") end)
    f.toggleTotal:SetPoint("TOPLEFT", 12, -56)
    SetSettingsTooltip(f.toggleTotal, "Launcher session total", {"Controls the session total line on the launcher only.", "This does not show or hide the standalone Session window."})
    f.toggleTime = MakeSettingsCheck(f.launcherSection, "Session time", function() EL:ToggleDisplaySetting("showLauncherSessionTime") end)
    f.toggleTime:SetPoint("TOPLEFT", 178, -56)
    SetSettingsTooltip(f.toggleTime, "Launcher session time", {"Controls the session timer line on the launcher only.", "This does not show or hide the standalone Session window."})

    f.sessionOptions = MakeSettingsSection(f, "Session Tracking", contentX, -698, contentW, 166)
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
    f.pricingSourceLabel:SetTextColor(0.76, 0.76, 0.70)
    f.pricingSourceValue = f.sessionOptions:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.pricingSourceValue:SetPoint("LEFT", f.pricingSourceLabel, "RIGHT", 5, 0)
    f.pricingSourceValue:SetTextColor(1.00, 0.92, 0.56)
    f.toggleSessionHistory = MakeSettingsCheck(f.sessionOptions, "Session history", function() if EL.ToggleSessionHistoryEnabled then EL:ToggleSessionHistoryEnabled() end end)
    f.toggleSessionHistory:SetPoint("TOPLEFT", 12, -112)
    SetSettingsTooltip(f.toggleSessionHistory, "Session History", {"Saves account-wide summary records on reset and logout/reload."})
    f.copySummary = MakeSettingsButton(f.sessionOptions, "Copy Summary", 112, function() EL:ShowCopySessionSummaryDialog() end)
    f.copySummary:SetPoint("TOPRIGHT", -12, -132)
    SetSettingsTooltip(f.copySummary, "Copy Summary", {"Copies a quick summary of the current session totals."})

    f.craftedItemsSection = MakeSettingsSection(f, "Crafted Item Tracking", contentX, -898, contentW, 146)
    f.countCraftedItems = MakeSettingsCheck(f.craftedItemsSection, "Count crafted items", function() EL:ToggleSessionMoneySetting("countCraftedItems", false, "Crafted items") end)
    f.countCraftedItems:SetPoint("TOPLEFT", 12, -36)
    SetSettingsTooltip(f.countCraftedItems, "Crafted items", {"Counts crafted outputs added to your bags during tradeskill crafting.", "Off by default. May double-count value if the crafted item is later sold and AH/mail gold is also tracked.", "Reagent costs are not deducted from crafted item value."})
    f.craftedItemsWarning = f.craftedItemsSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.craftedItemsWarning:SetPoint("TOPLEFT", 12, -66)
    f.craftedItemsWarning:SetText("Warning: read before enabling")
    f.craftedItemsWarning:SetTextColor(1.00, 0.82, 0.24)
    f.craftedItemsBody = f.craftedItemsSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.craftedItemsBody:SetPoint("TOPLEFT", 12, -86)
    f.craftedItemsBody:SetWidth(contentW - 24)
    f.craftedItemsBody:SetJustifyH("LEFT")
    f.craftedItemsBody:SetText("Most users should leave this off. Use it only when you specifically want crafted outputs counted at craft time. It may double-count value if the crafted item is later sold and AH/mail gold is also tracked, and reagent costs are not deducted.")
    f.craftedItemsBody:SetTextColor(0.76, 0.76, 0.70)

    f.actionPlacementSection = MakeSettingsSection(f, "Placement", contentX, -42, contentW, 132)
    f.actionPlacementDesc = f.actionPlacementSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.actionPlacementDesc:SetPoint("TOPLEFT", 12, -34)
    f.actionPlacementDesc:SetWidth(contentW - 24)
    f.actionPlacementDesc:SetJustifyH("LEFT")
    f.actionPlacementDesc:SetTextColor(0.76, 0.76, 0.70)
    f.actionPlacementDesc:SetText("Anchor the action bar inside the main tracker, or let it float as a small draggable utility strip.")
    f.actionBarFloating = MakeSettingsCheck(f.actionPlacementSection, "Floating action bar", function() EL:ToggleActionBarFloating() end)
    f.actionBarFloating:SetPoint("TOPLEFT", 12, -72)
    f.actionBarLocked = MakeSettingsCheck(f.actionPlacementSection, "Lock floating bar", function() EL:ToggleFloatingActionBarLocked() end)
    f.actionBarLocked:SetPoint("TOPLEFT", 178, -72)
    f.resetActionBarPosition = MakeSettingsButton(f.actionPlacementSection, "Reset Position", 118, function() EL:ResetFloatingActionBarPosition() end)
    f.resetActionBarPosition:SetPoint("TOPLEFT", 12, -100)

    f.actionButtonsSection = MakeSettingsSection(f, "Button Visibility", contentX, -188, contentW, 232)
    f.actionGeneralLabel = f.actionButtonsSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.actionGeneralLabel:SetPoint("TOPLEFT", 12, -32)
    f.actionGeneralLabel:SetText("General")
    f.actionGeneralLabel:SetTextColor(1.00, 0.82, 0.24)
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
    f.actionSeedsLabel:SetTextColor(1.00, 0.82, 0.24)
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

    f.performanceSection = MakeSettingsSection(f, "Performance", contentX, -42, contentW, 334)
    f.performanceWarningTitle = f.performanceSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.performanceWarningTitle:SetPoint("TOPLEFT", 12, -36)
    f.performanceWarningTitle:SetText("Warning: read first")
    f.performanceWarningTitle:SetTextColor(1.00, 0.22, 0.18)

    f.performanceWarningText = f.performanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.performanceWarningText:SetPoint("TOPLEFT", 12, -56)
    f.performanceWarningText:SetWidth(contentW - 24)
    f.performanceWarningText:SetJustifyH("LEFT")
    f.performanceWarningText:SetTextColor(0.88, 0.84, 0.74)
    f.performanceWarningText:SetText("The defaults are recommended for nearly everyone. These controls are only for reducing background work or limiting visible session-log size if you understand the tradeoff.")

    f.enableSessionTracking = MakeSettingsCheck(f.performanceSection, "Enable session tracking", function() EL:TogglePerformanceSetting("sessionTracking") end)
    f.enableSessionTracking:SetPoint("TOPLEFT", 12, -106)
    f.sessionTrackingTip = f.performanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sessionTrackingTip:SetPoint("TOPLEFT", 34, -130)
    f.sessionTrackingTip:SetWidth(contentW - 46)
    f.sessionTrackingTip:SetJustifyH("LEFT")
    f.sessionTrackingTip:SetTextColor(0.76, 0.74, 0.66)
    f.sessionTrackingTip:SetText("Leave this on for gold/hour, item value, session history, stats, and bag summaries. Turn it off only if you do not want EmberLedger tracking session activity.")

    f.enableActionBar = MakeSettingsCheck(f.performanceSection, "Enable action bar", function() EL:TogglePerformanceSetting("actionBar") end)
    f.enableActionBar:SetPoint("TOPLEFT", 12, -172)
    f.actionBarTip = f.performanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.actionBarTip:SetPoint("TOPLEFT", 34, -196)
    f.actionBarTip:SetWidth(contentW - 46)
    f.actionBarTip:SetJustifyH("LEFT")
    f.actionBarTip:SetTextColor(0.76, 0.74, 0.66)
    f.actionBarTip:SetText("Disable this if you do not use EmberLedger's utility buttons or want to skip action-bar refresh work. This does not affect profession tracking.")

    f.historyCapTip = f.performanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.historyCapTip:SetPoint("TOPLEFT", 12, -246)
    f.historyCapTip:SetWidth(contentW - 24)
    f.historyCapTip:SetJustifyH("LEFT")
    f.historyCapTip:SetTextColor(0.88, 0.84, 0.74)
    f.historyCapTip:SetText("Session history cap: 500 is already enough for almost everyone, including extreme players, because stats use compact aggregates. Increase this only if you specifically want a deeper visible Sessions list and do not mind larger SavedVariables.")

    SetSettingsTooltip(f.enableSessionTracking, "Enable session tracking", {"Tracks session time, gathered items, session value, bag summaries, and recent/lifetime stats.", "Turn off to stop most background loot and bag processing."})
    SetSettingsTooltip(f.enableActionBar, "Enable action bar", {"Allows EmberLedger utility buttons in the main window or floating action bar.", "Turn off to hide the bar and skip action bar refresh work."})

    f.historyMaxEntriesSlider = MakeSettingsSlider(f.performanceSection, "Session history cap", 50, 3000, 50, function(v) return string.format("%d entries", v) end, function(v)
        if EL.SetSessionHistoryMaxEntries then EL:SetSessionHistoryMaxEntries(v) end
    end)
    f.historyMaxEntriesSlider:SetPoint("TOPLEFT", f.performanceSection, "TOPLEFT", 12, -294)
    SetSettingsTooltip(f.historyMaxEntriesSlider, "Session history cap", {"Limits the visible saved session list after the 30-day retention filter is applied.", "Default: 500. Stats remain accurate through compact aggregates even when old visible list entries are pruned."})

    f.maintenanceSection = MakeSettingsSection(f, "Maintenance / Resets", contentX, -438, contentW, 184)
    f.hiddenStatus = f.maintenanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hiddenStatus:SetPoint("TOPLEFT", 12, -36)
    f.hiddenStatus:SetWidth(contentW - 24)
    f.hiddenStatus:SetJustifyH("LEFT")
    f.hiddenStatus:SetTextColor(0.88, 0.86, 0.78)
    f.resetPos = MakeSettingsButton(f.maintenanceSection, "Reset Windows", 138, function() EL:ConfirmResetWindowPositions() end)
    f.resetPos:SetPoint("TOPLEFT", 12, -62)
    f.resetSession = MakeSettingsButton(f.maintenanceSection, "Reset Session", 138, function() EL:ConfirmResetSession() end)
    f.resetSession:SetPoint("LEFT", f.resetPos, "RIGHT", 12, 0)
    f.resetHidden = MakeSettingsButton(f.maintenanceSection, "Unhide All", 138, function() EL:ConfirmRestoreHiddenCharacters() end)
    f.resetHidden:SetPoint("TOPLEFT", 12, -96)
    f.resetPinned = MakeSettingsButton(f.maintenanceSection, "Reset Pinned", 138, function() EL:ConfirmResetPinnedCharacters() end)
    f.resetPinned:SetPoint("LEFT", f.resetHidden, "RIGHT", 12, 0)
    f.resetHistory = MakeSettingsButton(f.maintenanceSection, "Clear History", 138, function() if EL.ConfirmResetSessionHistory then EL:ConfirmResetSessionHistory() end end)
    f.resetHistory:SetPoint("TOPLEFT", 12, -130)
    f.resetLifetimeStats = MakeSettingsButton(f.maintenanceSection, "Reset Lifetime", 138, function() if EL.ConfirmResetLifetimeSessionStats then EL:ConfirmResetLifetimeSessionStats() end end)
    f.resetLifetimeStats:SetPoint("LEFT", f.resetHistory, "RIGHT", 12, 0)
    SetSettingsTooltip(f.resetPos, "Reset Windows", {"Returns EmberLedger windows to their default screen positions.", "Scale and visibility settings are kept."})
    SetSettingsTooltip(f.resetSession, "Reset Session", {"Clears current session totals and tracked items."})
    SetSettingsTooltip(f.resetHidden, "Unhide All", {"Restores every hidden character to the main window table."})
    SetSettingsTooltip(f.resetPinned, "Reset Pinned", {"Removes all pinned character markers without deleting character data."})
    SetSettingsTooltip(f.resetHistory, "Clear History", {"Deletes all saved account-wide session history data.", "This does not reset the current active session."})
    SetSettingsTooltip(f.resetLifetimeStats, "Reset Lifetime", {"Resets only the lifetime aggregate stats.", "Session history and the current active session are not deleted."})

    f.footerSection = MakeSettingsSection(f, "Information", contentX, -846, contentW, 78)
    f.versionLabel = f.footerSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.versionLabel:SetPoint("TOPLEFT", 12, -34)
    f.versionLabel:SetText("Version: " .. tostring(EL.version or "1.20.2"))
    f.versionLabel:SetTextColor(0.88, 0.86, 0.78)

    f.allSettingsSections = {
        f.generalSection,
        f.appearanceSection,
        f.scaleSection,
        f.mainWindowTogglesSection,
        f.thresholdSection,
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
        ["Main Window"] = {f.mainWindowTogglesSection, f.thresholdSection, f.trackingColumnsSection, f.nextColumnSection, f.cooldownColumnSection},
        ["Action Bar"] = {f.actionPlacementSection, f.actionButtonsSection},
        Performance = {f.performanceSection},
        Maintenance = {f.maintenanceSection},
    }

    -- The sidebar is now a real category menu. Show one module at a time rather than
    -- stacking every option into one oversized page.
    self:SelectSettingsPage("General")
    return f
end

function EL:UpdateSettingsNavHighlight()
    local f = self.settingsPanel
    if not f or not f.navLabels then return end
    for _, row in ipairs(f.navLabels) do
        local selected = f.currentPage == row.pageName
        if row.SetBackdropColor then
            row:SetBackdropColor(selected and 0.45 or 0.02, selected and 0.10 or 0.02, selected and 0.04 or 0.03, selected and 0.72 or 0.00)
        end
        if row.SetBackdropBorderColor then
            row:SetBackdropBorderColor(1.0, 0.72, 0.18, selected and 0.45 or 0.00)
        end
        if row.text then
            row.text:SetFontObject(selected and GameFontNormalSmall or GameFontHighlightSmall)
            row.text:SetTextColor(selected and 1.00 or 0.86, selected and 0.82 or 0.84, selected and 0.24 or 0.78)
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
        local y = -42
        local spacing = 12
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
    if f.thresholdValue then f.thresholdValue:SetText(tostring(tonumber(alerts.concentrationThreshold) or 360)) end
    if f.moxieThresholdValue then f.moxieThresholdValue:SetText(tostring(tonumber(alerts.moxieThreshold) or 600)) end
    SetSliderValue(f.panelOpacitySlider, math.floor((tonumber(display.panelOpacity) or 0.55) * 100 + 0.5))
    SetSliderValue(f.launcherOpacitySlider, math.floor((tonumber(display.launcherOpacity) or 0.50) * 100 + 0.5))
    SetSliderValue(f.sessionOpacitySlider, math.floor((tonumber(display.sessionOpacity) or 0.55) * 100 + 0.5))
    SetSliderValue(f.thresholdSlider, tonumber(alerts.concentrationThreshold) or 360)
    SetSliderValue(f.moxieThresholdSlider, tonumber(alerts.moxieThreshold) or 600)
    SetSliderValue(f.scaleSlider, math.floor(((self.db.settings.panel and tonumber(self.db.settings.panel.scale)) or 1) * 100 + 0.5))
    SetSliderValue(f.sessionScaleSlider, math.floor(((self.db.settings.session and tonumber(self.db.settings.session.scale)) or 1) * 100 + 0.5))
    SetSliderValue(f.historyMaxEntriesSlider, (self.GetSessionHistoryMaxEntries and self:GetSessionHistoryMaxEntries()) or 500)
    local function setToggle(btn, on)
        if not btn then return end
        if btn.SetChecked then btn:SetChecked(on and true or false) end
        if btn.text then btn.text:SetTextColor(on and 0.95 or 0.55, on and 0.92 or 0.58, on and 0.80 or 0.62) end
    end
    setToggle(f.showLauncher, self.db.settings.button and self.db.settings.button.shown ~= false)
    local minimapSettings = self.db.settings.minimap or {}
    setToggle(f.showMinimapButton, minimapSettings.hide ~= true)
    setToggle(f.toggleConc, display.showLauncherConc ~= false)
    setToggle(f.toggleMulch, display.showLauncherMulch ~= false)
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
    local sessionControlsAlpha = (performanceSettings.sessionTracking ~= false) and 1.0 or 0.45
    for _, btn in ipairs({ f.toggleSessionSection, f.filterHerbs, f.filterOre, f.filterCloth, f.filterLeather, f.filterEnchanting, f.filterFish, f.filterOther, f.trackRawGoldGains, f.trackGoldSpent, f.countTrustedMailRewards, f.countCraftedItems, f.toggleSessionHistory, f.resetSession, f.historyMaxEntriesSlider }) do
        if btn and btn.SetAlpha then btn:SetAlpha(sessionControlsAlpha) end
    end
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
        self.db.settings.alerts.concentrationThreshold = math.max(0, math.min(1000, math.floor((tonumber(value) or 360) + 0.5)))
    elseif kind == "moxieThreshold" then
        self.db.settings.alerts.moxieThreshold = math.max(0, math.min(1000, math.floor((tonumber(value) or 600) + 0.5)))
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
        if self.RefreshPanel then self:RefreshPanel() end
        if self.UpdateSortHeaders then self:UpdateSortHeaders() end
    end
    self:RequestUpdate()
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
        local v = tonumber(self.db.settings.alerts.concentrationThreshold) or 360
        self.db.settings.alerts.concentrationThreshold = math.max(0, math.min(1000, v + (delta or 0)))
    elseif kind == "moxieThreshold" then
        local v = tonumber(self.db.settings.alerts.moxieThreshold) or 600
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
        if self.RefreshPanel then self:RefreshPanel() end
        if self.UpdateSortHeaders then self:UpdateSortHeaders() end
    end
    self:RequestUpdate()
end

local DISPLAY_TOGGLE_LABELS = {
    showLauncherConc = "Launcher concentration alert",
    showLauncherMulch = "Launcher mulch line",
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
    return value and "ON" or "OFF"
end

function EL:NotifyToggle(label, enabled)
    if not label then return end
    self:Print(label .. " " .. OnOffText(enabled))
end


local TRACKING_COLUMN_TOGGLE_LABELS = {
    prof = "Prof 1 column",
    conc = "Conc 1 column",
    prof1 = "Prof 1 column",
    conc1 = "Conc 1 column",
    prof2 = "Prof 2 column",
    conc2 = "Conc 2 column",
    moxie = "Moxie column",
    mulch = "Mulch column",
    forecast = "Next column",
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
        for _, def in ipairs(TRACKING_COLUMN_DEFS) do
            if def.setting and def.setting ~= settingKey and display[def.setting] ~= false and (not def.secondary or hasSecondaryData) then
                remaining = remaining + 1
            end
        end
        if remaining <= 0 then
            display[settingKey] = true
            self:Print("At least one optional tracking column must remain visible.")
            self:RefreshSettingsPanel()
            return
        end
    end
    display[settingKey] = enabled
    self:Print((TRACKING_COLUMN_TOGGLE_LABELS[key] or key) .. " " .. OnOffText(enabled))
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
    if (key == "showCurrentCharacterFirst" or key == "highlightCurrentCharacter") and self.RefreshPanel then
        self:RefreshPanel()
    end
    self:RefreshSettingsPanel()
    if self.LayoutPanel then self:LayoutPanel() end
    self:RequestUpdate()
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
                if self.ShowSessionWindowFromSavedState then self:ShowSessionWindowFromSavedState() end
            elseif self.RefreshSessionPanel then
                self:RefreshSessionPanel()
            end
        else
            sessionSettings.reopenAfterPerformanceEnable = (self.sessionWindow and self.sessionWindow:IsShown()) or sessionSettings.windowOpen == true
            if self.sessionWindow then
                self._suppressSessionWindowHideSetting = true
                self.sessionWindow:Hide()
                self._suppressSessionWindowHideSetting = false
            end
            sessionSettings.windowOpen = false
        end
    elseif key == "actionBar" then
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
            if self.ShowSessionWindowFromSavedState then self:ShowSessionWindowFromSavedState() end
        else
            if self.sessionWindow then self.sessionWindow:Hide() end
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

function EL:RegisterBlizzardSettings()
    if self.blizzardSettingsRegistered then return end
    self.blizzardSettingsRegistered = true

    local canvas = CreateFrame("Frame", "EmberLedgerBlizzardSettingsCanvas")
    canvas.name = "EmberLedger"
    canvas:SetSize(620, 420)

    canvas.title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    canvas.title:SetPoint("TOP", 0, -55)
    canvas.title:SetText("EmberLedger")
    canvas.title:SetTextColor(1.00, 0.42, 0.08)

    canvas.version = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    canvas.version:SetPoint("TOP", canvas.title, "BOTTOM", 0, -12)
    canvas.version:SetText("Version " .. tostring(self.version or "1.20.2"))

    canvas.desc = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    canvas.desc:SetPoint("TOP", canvas.version, "BOTTOM", 0, -16)
    canvas.desc:SetWidth(420)
    canvas.desc:SetJustifyH("CENTER")
    canvas.desc:SetText("Profession tracking, Imbued Mulch cooldowns, and session analytics for your alt army.")

    canvas.open = MakeSettingsButton(canvas, "Open EmberLedger Settings", 260, function()
        if EL.ShowSettingsPanel then EL:ShowSettingsPanel() elseif EL.ToggleSettingsPanel then EL:ToggleSettingsPanel() end
    end)
    canvas.open:SetPoint("TOP", canvas.desc, "BOTTOM", 0, -28)

    canvas.reset = MakeSettingsButton(canvas, "Reset Window Positions", 220, function()
        if EL.ConfirmResetWindowPositions then EL:ConfirmResetWindowPositions() elseif EL.ResetWindowPositions then EL:ResetWindowPositions() end
    end)
    canvas.reset:SetPoint("TOP", canvas.open, "BOTTOM", 0, -14)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(canvas, "EmberLedger")
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(canvas)
        self.settingsCategory = canvas
    end
end


local SESSION_HISTORY_ROWS = UIC.SESSION_HISTORY_ROWS or 8

function EL:CreateSessionHistoryWindow()
    if self.sessionHistoryWindow then return end
    local frame = CreateFrame("Frame", "EmberLedgerSessionHistoryWindow", UIParent, "BackdropTemplate")
    self.sessionHistoryWindow = frame
    frame:SetSize(700, 510)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnShow", function(self) BringEmberWindowToFront(self) end)
    frame:SetScript("OnMouseDown", function(self) BringEmberWindowToFront(self) end)
    AddBackdrop(frame, GetPanelOpacity(), 0.55)
    AddInnerBorder(frame)
    frame:SetScript("OnDragStart", function(self) BringEmberWindowToFront(self); self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()

    frame.header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.header:SetPoint("TOPLEFT", 8, -8)
    frame.header:SetPoint("TOPRIGHT", -8, -8)
    frame.header:SetHeight(44)
    AddBackdrop(frame.header, 0.96, 0.66)
    if frame.header.SetBackdropColor then frame.header:SetBackdropColor(0.010, 0.008, 0.020, 0.96) end
    AddHeaderAccent(frame.header)

    frame.title = frame.header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.title:SetPoint("CENTER", frame.header, "CENTER", 0, 1)
    frame.title:SetText("EmberLedger - Stats")
    frame.title:SetTextColor(1.00, 0.82, 0.24)

    frame.close = CreateFrame("Button", nil, frame.header, "UIPanelCloseButton")
    frame.close:SetSize(24, 24)
    frame.close:SetPoint("RIGHT", frame.header, "RIGHT", -6, 0)
    frame.close:SetScript("OnClick", function()
        EL._suppressSessionWindowHideSetting = true
        frame:Hide()
        EL._suppressSessionWindowHideSetting = false
        if EL.db and EL.db.settings and EL.db.settings.session then
            -- shown is preserved by the suppress flag above; this write is defensive.
            EL.db.settings.session.shown = true
            EL.db.settings.session.windowOpen = false
        end
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
        if EL.RefreshUpdateTicker then EL:RefreshUpdateTicker() end
    end)
    frame:SetScript("OnHide", function()
        HideSessionHistoryDisplayDropdown()
    end)


    frame.viewMode = "stats"
    frame.statsView = CreateFrame("Button", nil, frame.header, "UIPanelButtonTemplate")
    frame.statsView:SetSize(58, 21)
    frame.statsView:SetPoint("LEFT", frame.header, "LEFT", 10, 0)
    frame.statsView:SetText("Stats")
    StyleBlizzardButton(frame.statsView)
    frame.statsView:SetScript("OnClick", function()
        frame.viewMode = "stats"
        if EL.RefreshSessionHistoryWindow then EL:RefreshSessionHistoryWindow() end
    end)

    frame.historyView = CreateFrame("Button", nil, frame.header, "UIPanelButtonTemplate")
    frame.historyView:SetSize(70, 21)
    frame.historyView:SetPoint("LEFT", frame.statsView, "RIGHT", 6, 0)
    frame.historyView:SetText("Sessions")
    StyleBlizzardButton(frame.historyView)
    frame.historyView:SetScript("OnClick", function()
        frame.viewMode = "history"
        if EL.RefreshSessionHistoryWindow then EL:RefreshSessionHistoryWindow() end
    end)

    frame.bagView = CreateFrame("Button", nil, frame.header, "UIPanelButtonTemplate")
    frame.bagView:SetSize(104, 21)
    frame.bagView:SetPoint("RIGHT", frame.close, "LEFT", -8, 0)
    frame.bagView:SetText("Bag Summary")
    StyleBlizzardButton(frame.bagView)
    frame.bagView:SetScript("OnClick", function()
        frame.viewMode = "bag"
        if EL.RefreshSessionHistoryWindow then EL:RefreshSessionHistoryWindow() end
    end)

    frame.infoBox = CreateFrame("Frame", nil, frame)
    frame.infoBox:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 12, -8)
    frame.infoBox:SetPoint("TOPRIGHT", frame.header, "BOTTOMRIGHT", -12, -8)
    frame.infoBox:SetHeight(34)

    frame.info = frame.infoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.info:SetPoint("TOPLEFT", frame.infoBox, "TOPLEFT", 0, -2)
    frame.info:SetPoint("TOPRIGHT", frame.infoBox, "TOPRIGHT", 0, -2)
    frame.info:SetHeight(30)
    frame.info:SetJustifyH("LEFT")
    frame.info:SetJustifyV("TOP")
    if frame.info.SetWordWrap then frame.info:SetWordWrap(true) end
    frame.info:SetTextColor(0.86, 0.86, 0.84)
    frame.info:SetText("Account-wide session history for all characters.")

    frame.rangeBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.rangeBox:SetPoint("TOPLEFT", frame.infoBox, "BOTTOMLEFT", -2, -6)
    frame.rangeBox:SetPoint("TOPRIGHT", frame.infoBox, "BOTTOMRIGHT", 2, -6)
    frame.rangeBox:SetHeight(36)
    AddBackdrop(frame.rangeBox, 0.92, 0.66)
    if frame.rangeBox.SetBackdropColor then frame.rangeBox:SetBackdropColor(0.012, 0.010, 0.024, 0.92) end
    AddInnerBorder(frame.rangeBox)

    frame.rangeIcon = frame.rangeBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.rangeIcon:SetPoint("LEFT", frame.rangeBox, "LEFT", 14, 0)
    frame.rangeIcon:SetText("|TInterface\\Icons\\INV_Misc_PocketWatch_01:14:14:0:0|t")

    frame.rangeText = frame.rangeBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.rangeText:SetPoint("LEFT", frame.rangeIcon, "RIGHT", 10, 0)
    frame.rangeText:SetPoint("RIGHT", frame.rangeBox, "RIGHT", -300, 0)
    frame.rangeText:SetJustifyH("LEFT")
    frame.rangeText:SetTextColor(1.00, 0.82, 0.24)

    frame.displayRange = CreateFrame("Button", nil, frame.rangeBox, "BackdropTemplate")
    frame.displayRange:SetSize(190, 24)
    frame.displayRange:SetPoint("RIGHT", frame.rangeBox, "RIGHT", -12, 0)
    AddBackdrop(frame.displayRange, 0.86, 0.70)
    if frame.displayRange.SetBackdropColor then frame.displayRange:SetBackdropColor(0.020, 0.016, 0.030, 0.92) end

    frame.displayLabel = frame.rangeBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.displayLabel:SetPoint("RIGHT", frame.displayRange, "LEFT", -8, 0)
    frame.displayLabel:SetWidth(58)
    frame.displayLabel:SetJustifyH("RIGHT")
    frame.displayLabel:SetText("Display:")
    frame.displayLabel:SetTextColor(1.00, 0.82, 0.24)

    frame.displayRange.selectedText = frame.displayRange:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.displayRange.selectedText:SetPoint("LEFT", frame.displayRange, "LEFT", 10, 0)
    frame.displayRange.selectedText:SetPoint("RIGHT", frame.displayRange, "RIGHT", -30, 0)
    frame.displayRange.selectedText:SetJustifyH("LEFT")
    frame.displayRange.selectedText:SetTextColor(0.92, 0.90, 0.82)

    frame.displayRange.arrowBox = CreateFrame("Frame", nil, frame.displayRange, "BackdropTemplate")
    frame.displayRange.arrowBox:SetSize(22, 20)
    frame.displayRange.arrowBox:SetPoint("RIGHT", frame.displayRange, "RIGHT", -2, 0)
    if frame.displayRange.arrowBox.SetBackdrop then
        frame.displayRange.arrowBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame.displayRange.arrowBox:SetBackdropColor(0.035, 0.028, 0.045, 0.85)
        frame.displayRange.arrowBox:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0.55)
    end
    frame.displayRange.arrowTexture = frame.displayRange.arrowBox:CreateTexture(nil, "ARTWORK")
    frame.displayRange.arrowTexture:SetSize(12, 12)
    frame.displayRange.arrowTexture:SetPoint("CENTER", frame.displayRange.arrowBox, "CENTER", 0, -1)
    frame.displayRange.arrowTexture:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    frame.displayRange.arrowTexture:SetTexCoord(0.20, 0.80, 0.20, 0.80)

    frame.displayRange:SetScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(1.00, 0.82, 0.24, 0.85) end
        if self.selectedText then self.selectedText:SetTextColor(1.00, 0.82, 0.24) end
        if self.arrowBox and self.arrowBox.SetBackdropBorderColor then self.arrowBox:SetBackdropBorderColor(1.00, 0.82, 0.24, 0.85) end
    end)
    frame.displayRange:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0.70) end
        if self.selectedText then self.selectedText:SetTextColor(0.92, 0.90, 0.82) end
        if self.arrowBox and self.arrowBox.SetBackdropBorderColor then self.arrowBox:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0.55) end
    end)
    frame.displayRange:SetScript("OnClick", function(self) ShowSessionHistoryDisplayDropdown(self) end)

    frame.statsRange = "30"
    frame.statsRangeButtons = {}
    local statsRanges = {
        { key = "today", label = "Today" },
        { key = "week", label = "This Week" },
        { key = "30", label = "30 Days" },
        { key = "lifetime", label = "Lifetime" },
    }
    local statsButtonX = 12
    for _, option in ipairs(statsRanges) do
        local btn = CreateFrame("Button", nil, frame.rangeBox, "UIPanelButtonTemplate")
        btn:SetSize(option.key == "week" and 92 or 78, 21)
        btn:SetPoint("LEFT", frame.rangeBox, "LEFT", statsButtonX, 0)
        btn:SetText(option.label)
        StyleBlizzardButton(btn)
        btn.rangeKey = option.key
        btn:SetScript("OnClick", function(self)
            frame.statsRange = self.rangeKey or "30"
            if EL.RefreshSessionHistoryWindow then EL:RefreshSessionHistoryWindow() end
        end)
        frame.statsRangeButtons[option.key] = btn
        statsButtonX = statsButtonX + (option.key == "week" and 98 or 84)
    end

    frame.table = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.table:SetPoint("TOPLEFT", frame.rangeBox, "BOTTOMLEFT", 0, -8)
    frame.table:SetPoint("TOPRIGHT", frame.rangeBox, "BOTTOMRIGHT", 0, -8)
    frame.table:SetHeight(214)
    AddBackdrop(frame.table, 0.88, 0.64)
    if frame.table.SetBackdropColor then frame.table:SetBackdropColor(0.012, 0.010, 0.024, 0.88) end
    AddInnerBorder(frame.table)
    frame.historyOffset = 0

    local function ScrollHistory(delta)
        local total = #(EL.GetSessionHistoryList and EL:GetSessionHistoryList() or {})
        local maxOffset = math.max(0, total - SESSION_HISTORY_ROWS)
        frame.historyOffset = math.max(0, math.min(maxOffset, (frame.historyOffset or 0) - (delta or 0)))
        if EL.RefreshSessionHistoryWindow then EL:RefreshSessionHistoryWindow() end
    end
    frame.table:EnableMouseWheel(true)
    frame.table:SetScript("OnMouseWheel", function(_, delta) ScrollHistory(delta) end)

    frame.scrollBar = CreateFrame("Slider", nil, frame.table, "UIPanelScrollBarTemplate")
    frame.scrollBar:SetPoint("TOPRIGHT", frame.table, "TOPRIGHT", -12, -30)
    frame.scrollBar:SetPoint("BOTTOMRIGHT", frame.table, "BOTTOMRIGHT", -12, 30)
    frame.scrollBar:SetMinMaxValues(0, 0)
    frame.scrollBar:SetValueStep(1)
    if frame.scrollBar.SetObeyStepOnDrag then frame.scrollBar:SetObeyStepOnDrag(true) end
    frame.scrollBar:SetScript("OnValueChanged", function(self, value)
        if frame._updatingScrollBar then return end
        frame.historyOffset = math.floor(tonumber(value) or 0)
        if EL.RefreshSessionHistoryWindow then EL:RefreshSessionHistoryWindow() end
    end)

    local columns = {
        {"Date", 18, 128, "LEFT"},
        {"Character", 158, 156, "LEFT"},
        {"Time", 330, 60, "CENTER"},
        {"Total", 404, 122, "RIGHT"},
        {"Gold/hr", 522, 80, "RIGHT"},
    }
    frame.columns = columns
    frame.headers = {}
    for _, col in ipairs(columns) do
        local fs = frame.table:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame.table, "TOPLEFT", col[2], -9)
        fs:SetWidth(col[3])
        fs:SetJustifyH(col[4])
        fs:SetText(col[1])
        fs:SetTextColor(1.00, 0.82, 0.24)
        table.insert(frame.headers, fs)
    end

    frame.rows = {}
    for i = 1, SESSION_HISTORY_ROWS do
        local row = CreateFrame("Frame", nil, frame.table, "BackdropTemplate")
        row:SetPoint("TOPLEFT", frame.table, "TOPLEFT", 10, -32 - ((i - 1) * 21))
        row:SetPoint("RIGHT", frame.table, "RIGHT", -42, 0)
        row:SetHeight(20)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.018, 0.014, 0.030, i % 2 == 0 and 0.30 or 0.42)
        row.highlight = row:CreateTexture(nil, "BORDER")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1.0, 0.68, 0.08, 0.14)
        row.highlight:Hide()
        row.texts = {}
        for _, col in ipairs(columns) do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("LEFT", row, "LEFT", col[2] - 10, 0)
            fs:SetWidth(col[3])
            fs:SetJustifyH(col[4])
            fs:SetTextColor(0.90, 0.91, 0.92)
            table.insert(row.texts, fs)
        end
        row:EnableMouse(true)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta) ScrollHistory(delta) end)
        row:SetScript("OnEnter", function(self)
            if self.highlight then self.highlight:Show() end
            local entry = self.entry
            if not entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Session Details")
            GameTooltip:AddLine((entry.character or "Unknown") .. " - " .. (entry.realm or "Unknown"), 0.90, 0.90, 0.90)
            GameTooltip:AddLine("Duration: " .. EL:FormatDuration(tonumber(entry.duration) or 0), 0.76, 0.76, 0.70)
            GameTooltip:AddLine("Item value: " .. EL:FormatMoneyText(tonumber(entry.itemValueSilver) or 0), 0.76, 0.76, 0.70)
            GameTooltip:AddLine("Raw gold: " .. EL:FormatMoneyText(tonumber(entry.rawGoldGainedSilver) or 0), 0.76, 0.76, 0.70)
            GameTooltip:AddLine("Spent: " .. EL:FormatMoneyText(-(tonumber(entry.goldSpentSilver) or 0)), 0.95, 0.55, 0.45)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self) if self.highlight then self.highlight:Hide() end GameTooltip:Hide() end)
        frame.rows[i] = row
    end

    frame.statsPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.statsPanel:SetPoint("TOPLEFT", frame.rangeBox, "BOTTOMLEFT", 0, -8)
    frame.statsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    AddBackdrop(frame.statsPanel, 0.90, 0.66)
    if frame.statsPanel.SetBackdropColor then frame.statsPanel:SetBackdropColor(0.012, 0.010, 0.024, 0.90) end
    AddInnerBorder(frame.statsPanel)

    frame.statsTitle = frame.statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.statsTitle:SetPoint("TOPLEFT", frame.statsPanel, "TOPLEFT", 16, -12)
    frame.statsTitle:SetText("Aggregated Session Stats")
    frame.statsTitle:SetTextColor(1.00, 0.82, 0.24)

    frame.statsNote = frame.statsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statsNote:SetPoint("TOPLEFT", frame.statsTitle, "BOTTOMLEFT", 0, -4)
    frame.statsNote:SetPoint("TOPRIGHT", frame.statsPanel, "TOPRIGHT", -16, -34)
    frame.statsNote:SetJustifyH("LEFT")
    frame.statsNote:SetTextColor(0.74, 0.74, 0.70)

    -- Session history layout constants. These preserve the existing visual layout
    -- while making the remaining UI-owned frame creation easier to adjust later.
    local STATS_CARD_W, STATS_CARD_H = UIC.SESSION_STATS_CARD_W or 205, UIC.SESSION_STATS_CARD_H or 54
    local STATS_CARD_LEFT, STATS_CARD_TOP = UIC.SESSION_STATS_CARD_LEFT or 16, UIC.SESSION_STATS_CARD_TOP or -70
    local STATS_CARD_STEP_X, STATS_CARD_STEP_Y = UIC.SESSION_STATS_CARD_STEP_X or 219, UIC.SESSION_STATS_CARD_STEP_Y or 70
    local BAG_CARD_W, BAG_CARD_H = UIC.SESSION_BAG_CARD_W or 205, UIC.SESSION_BAG_CARD_H or 44
    local BAG_CARD_LEFT, BAG_CARD_TOP = UIC.SESSION_BAG_CARD_LEFT or 16, UIC.SESSION_BAG_CARD_TOP or -58
    local BAG_CARD_STEP_X = UIC.SESSION_BAG_CARD_STEP_X or 219
    local TOTAL_CARD_W, TOTAL_CARD_H = UIC.SESSION_TOTAL_CARD_W or 205, UIC.SESSION_TOTAL_CARD_H or 36
    local TOTAL_CARD_LEFT, TOTAL_CARD_TOP = UIC.SESSION_TOTAL_CARD_LEFT or 14, UIC.SESSION_TOTAL_CARD_TOP or -34
    local TOTAL_CARD_STEP_X, TOTAL_CARD_STEP_Y = UIC.SESSION_TOTAL_CARD_STEP_X or 219, UIC.SESSION_TOTAL_CARD_STEP_Y or 46

    local function MakeStatsCard(icon, label, col, row)
        local cardW, cardH = STATS_CARD_W, STATS_CARD_H
        local x = STATS_CARD_LEFT + ((col - 1) * STATS_CARD_STEP_X)
        local y = STATS_CARD_TOP - ((row - 1) * STATS_CARD_STEP_Y)
        local card = CreateFrame("Frame", nil, frame.statsPanel, "BackdropTemplate")
        card:SetPoint("TOPLEFT", frame.statsPanel, "TOPLEFT", x, y)
        card:SetSize(cardW, cardH)
        AddBackdrop(card, 0.94, 0.68)
        if card.SetBackdropColor then card:SetBackdropColor(0.014, 0.012, 0.028, 0.94) end
        AddInnerBorder(card)

        local iconText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        iconText:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -7)
        iconText:SetText(EL:SessionHistoryIcon(icon))

        local labelText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        labelText:SetPoint("TOPLEFT", card, "TOPLEFT", 34, -7)
        labelText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -7)
        labelText:SetJustifyH("LEFT")
        labelText:SetText(label)
        labelText:SetTextColor(0.86, 0.84, 0.78)

        local valueText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valueText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 34, 10)
        valueText:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 10)
        valueText:SetJustifyH("RIGHT")
        valueText:SetTextColor(0.92, 0.93, 0.94)
        return valueText, card
    end

    frame.statGold = MakeStatsCard("Interface\\Icons\\INV_Misc_Coin_17", "Gold Earned", 1, 1)
    frame.statTime = MakeStatsCard("Interface\\Icons\\INV_Misc_PocketWatch_01", "Session Time", 2, 1)
    frame.statRate = MakeStatsCard("Interface\\Icons\\INV_Misc_Coin_01", "Gold / Hour", 3, 1)
    frame.statSessions = MakeStatsCard("Interface\\Icons\\INV_Misc_Note_01", "Sessions", 1, 2)
    frame.statItems = MakeStatsCard("Interface\\Icons\\INV_Misc_Bag_10", "Items Gathered", 2, 2)
    frame.statRaw = MakeStatsCard("Interface\\Icons\\INV_Misc_Coin_02", "Raw Gold", 3, 2)

    frame.statsFootnote = frame.statsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statsFootnote:SetPoint("BOTTOMLEFT", frame.statsPanel, "BOTTOMLEFT", 16, 14)
    frame.statsFootnote:SetPoint("BOTTOMRIGHT", frame.statsPanel, "BOTTOMRIGHT", -16, 14)
    frame.statsFootnote:SetJustifyH("LEFT")
    frame.statsFootnote:SetTextColor(0.68, 0.68, 0.64)

    frame.bagPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.bagPanel:SetPoint("TOPLEFT", frame.rangeBox, "BOTTOMLEFT", 0, -8)
    frame.bagPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    AddBackdrop(frame.bagPanel, 0.90, 0.66)
    if frame.bagPanel.SetBackdropColor then frame.bagPanel:SetBackdropColor(0.012, 0.010, 0.024, 0.90) end
    AddInnerBorder(frame.bagPanel)

    frame.bagTitle = frame.bagPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.bagTitle:SetPoint("TOPLEFT", frame.bagPanel, "TOPLEFT", 16, -12)
    frame.bagTitle:SetText("Current Bag Summary")
    frame.bagTitle:SetTextColor(1.00, 0.82, 0.24)

    frame.bagNote = frame.bagPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.bagNote:SetPoint("TOPLEFT", frame.bagTitle, "BOTTOMLEFT", 0, -4)
    frame.bagNote:SetPoint("TOPRIGHT", frame.bagPanel, "TOPRIGHT", -16, -34)
    frame.bagNote:SetJustifyH("LEFT")
    frame.bagNote:SetTextColor(0.74, 0.74, 0.70)
    frame.bagNote:SetText("Read-only estimate of currently held tracked materials. This does not change session history or lifetime stats.")

    local function MakeBagCard(icon, label, col)
        local cardW, cardH = BAG_CARD_W, BAG_CARD_H
        local x = BAG_CARD_LEFT + ((col - 1) * BAG_CARD_STEP_X)
        local card = CreateFrame("Frame", nil, frame.bagPanel, "BackdropTemplate")
        card:SetPoint("TOPLEFT", frame.bagPanel, "TOPLEFT", x, BAG_CARD_TOP)
        card:SetSize(cardW, cardH)
        AddBackdrop(card, 0.94, 0.68)
        if card.SetBackdropColor then card:SetBackdropColor(0.014, 0.012, 0.028, 0.94) end
        AddInnerBorder(card)

        local iconText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        iconText:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
        iconText:SetText(EL:SessionHistoryIcon(icon))

        local labelText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        labelText:SetPoint("TOPLEFT", card, "TOPLEFT", 34, -6)
        labelText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -6)
        labelText:SetJustifyH("LEFT")
        labelText:SetText(label)
        labelText:SetTextColor(0.86, 0.84, 0.78)

        local valueText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valueText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 34, 7)
        valueText:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 7)
        valueText:SetJustifyH("RIGHT")
        valueText:SetTextColor(0.92, 0.93, 0.94)
        return valueText, card
    end

    frame.bagValue = MakeBagCard("Interface\\Icons\\INV_Misc_Bag_10", "Current Bag Value", 1)
    frame.bagProjected = MakeBagCard("Interface\\Icons\\INV_Misc_Coin_17", "Projected Total", 2)
    frame.bagQuantity = MakeBagCard("Interface\\Icons\\INV_Misc_Note_01", "Tracked Items Held", 3)

    frame.bagTable = CreateFrame("Frame", nil, frame.bagPanel, "BackdropTemplate")
    frame.bagTable:SetPoint("TOPLEFT", frame.bagPanel, "TOPLEFT", 14, -116)
    frame.bagTable:SetPoint("BOTTOMRIGHT", frame.bagPanel, "BOTTOMRIGHT", -14, 42)
    AddBackdrop(frame.bagTable, 0.86, 0.58)
    if frame.bagTable.SetBackdropColor then frame.bagTable:SetBackdropColor(0.010, 0.008, 0.020, 0.86) end
    AddInnerBorder(frame.bagTable)

    frame.bagHeaders = {}
    local bagColumns = {
        { key = "item", label = "Item", left = 16, width = 300, justify = "LEFT" },
        { key = "qty", label = "Qty", right = -404, width = 78, justify = "RIGHT" },
        { key = "unit", label = "Value", right = -268, width = 112, justify = "RIGHT" },
        { key = "total", label = "Total", right = -16, width = 230, justify = "RIGHT" },
    }
    frame.bagColumns = bagColumns

    local function AnchorBagCell(fs, parent, col, y)
        fs:ClearAllPoints()
        if col.left then
            fs:SetPoint("LEFT", parent, "LEFT", col.left, y or 0)
        else
            fs:SetPoint("RIGHT", parent, "RIGHT", col.right, y or 0)
        end
        fs:SetWidth(col.width)
        fs:SetJustifyH(col.justify)
    end

    for _, col in ipairs(bagColumns) do
        local fs = frame.bagTable:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if col.left then
            fs:SetPoint("TOPLEFT", frame.bagTable, "TOPLEFT", col.left, -9)
        else
            fs:SetPoint("TOPRIGHT", frame.bagTable, "TOPRIGHT", col.right, -9)
        end
        fs:SetWidth(col.width)
        fs:SetJustifyH(col.justify)
        fs:SetText(col.label)
        fs:SetTextColor(1.00, 0.82, 0.24)
        table.insert(frame.bagHeaders, fs)
    end

    frame.bagRows = {}
    for i = 1, 7 do
        local row = CreateFrame("Frame", nil, frame.bagTable, "BackdropTemplate")
        row:SetPoint("TOPLEFT", frame.bagTable, "TOPLEFT", 0, -32 - ((i - 1) * 23))
        row:SetPoint("RIGHT", frame.bagTable, "RIGHT", 0, 0)
        row:SetHeight(22)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.018, 0.014, 0.030, i % 2 == 0 and 0.30 or 0.42)
        row.texts = {}
        for _, col in ipairs(bagColumns) do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            AnchorBagCell(fs, row, col, 0)
            fs:SetTextColor(0.90, 0.91, 0.92)
            table.insert(row.texts, fs)
        end
        frame.bagRows[i] = row
    end

    frame.bagFootnote = frame.bagPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.bagFootnote:SetPoint("BOTTOMLEFT", frame.bagPanel, "BOTTOMLEFT", 16, 14)
    frame.bagFootnote:SetPoint("BOTTOMRIGHT", frame.bagPanel, "BOTTOMRIGHT", -16, 14)
    frame.bagFootnote:SetJustifyH("LEFT")
    frame.bagFootnote:SetTextColor(0.68, 0.68, 0.64)

    frame.totals = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.totals:SetPoint("TOPLEFT", frame.table, "BOTTOMLEFT", 0, -10)
    frame.totals:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    AddBackdrop(frame.totals, 0.90, 0.66)
    if frame.totals.SetBackdropColor then frame.totals:SetBackdropColor(0.012, 0.010, 0.024, 0.90) end
    AddInnerBorder(frame.totals)

    frame.totalsTitle = frame.totals:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.totalsTitle:SetPoint("TOPLEFT", frame.totals, "TOPLEFT", 14, -10)
    frame.totalsTitle:SetText("Sessions Total")
    frame.totalsTitle:SetTextColor(1.00, 0.82, 0.24)

    local function MakeTotalCard(icon, label, col, row)
        local cardW, cardH = TOTAL_CARD_W, TOTAL_CARD_H
        local x = TOTAL_CARD_LEFT + ((col - 1) * TOTAL_CARD_STEP_X)
        local y = TOTAL_CARD_TOP - ((row - 1) * TOTAL_CARD_STEP_Y)
        local card = CreateFrame("Frame", nil, frame.totals, "BackdropTemplate")
        card:SetPoint("TOPLEFT", frame.totals, "TOPLEFT", x, y)
        card:SetSize(cardW, cardH)
        AddBackdrop(card, 0.94, 0.68)
        if card.SetBackdropColor then card:SetBackdropColor(0.014, 0.012, 0.028, 0.94) end
        AddInnerBorder(card)

        local iconText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        iconText:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
        iconText:SetText(EL:SessionHistoryIcon(icon))

        local labelText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        labelText:SetPoint("TOPLEFT", card, "TOPLEFT", 34, -6)
        labelText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -6)
        labelText:SetJustifyH("LEFT")
        labelText:SetText(label)
        labelText:SetTextColor(0.86, 0.84, 0.78)

        local valueText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valueText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 34, 7)
        valueText:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 7)
        valueText:SetJustifyH("RIGHT")
        valueText:SetTextColor(0.92, 0.93, 0.94)
        return valueText, card
    end
    frame.totalSessions = MakeTotalCard("Interface\\Icons\\INV_Misc_Note_01", "Sessions", 1, 1)
    frame.totalItems = MakeTotalCard("Interface\\Icons\\INV_Misc_Bag_10", "Item Value", 2, 1)
    frame.totalSpent = MakeTotalCard("Interface\\Icons\\INV_Misc_Coin_02", "Gold Spent", 3, 1)
    frame.totalDuration = MakeTotalCard("Interface\\Icons\\INV_Misc_PocketWatch_01", "Duration", 1, 2)
    frame.totalRaw = MakeTotalCard("Interface\\Icons\\INV_Misc_Coin_01", "Raw Gold", 2, 2)
    frame.totalNet = MakeTotalCard("Interface\\Icons\\INV_Misc_Coin_17", "Net Total", 3, 2)
end

function EL:WarnMissingSessionWindowHelper(name)
    if not name then return end
    self._missingSessionWindowHelperWarnings = self._missingSessionWindowHelperWarnings or {}
    if self._missingSessionWindowHelperWarnings[name] then return end
    self._missingSessionWindowHelperWarnings[name] = true
    if self.db and self.db.settings and self.db.settings.debug and self.Print then
        self:Print("SessionWindow helper missing: " .. tostring(name))
    end
end

function EL:RefreshSessionHistoryWindow()
    local frame = self.sessionHistoryWindow
    if not frame then return end
    local displayMode = (self.GetSessionHistoryDisplayMode and self:GetSessionHistoryDisplayMode()) or "30"
    local displayLabel = displayMode == "today" and "Today" or (displayMode == "week" and "This Week" or ("30 days (" .. EL:GetSessionHistoryCapText() .. ")"))
    local enabled = (self.IsSessionHistoryEnabled and self:IsSessionHistoryEnabled()) or false
    if frame.displayRange and frame.displayRange.selectedText then frame.displayRange.selectedText:SetText(displayLabel) end

    local viewMode = frame.viewMode or "stats"
    local statsMode = viewMode == "stats"
    local bagMode = viewMode == "bag"
    local historyMode = not statsMode and not bagMode
    if not historyMode then HideSessionHistoryDisplayDropdown() end
    if frame.displayRange then frame.displayRange:SetShown(historyMode) end
    if frame.displayLabel then frame.displayLabel:SetShown(historyMode) end
    if frame.rangeIcon then frame.rangeIcon:SetShown(historyMode) end
    if frame.rangeText then frame.rangeText:SetShown(historyMode) end
    if frame.table then frame.table:SetShown(historyMode) end
    if frame.totals then frame.totals:SetShown(historyMode) end
    if frame.statsPanel then frame.statsPanel:SetShown(statsMode) end
    if frame.bagPanel then frame.bagPanel:SetShown(bagMode) end
    if frame.statsView then frame.statsView:SetText(statsMode and "* Stats" or "Stats") end
    if frame.historyView then frame.historyView:SetText(historyMode and "* Sessions" or "Sessions") end
    if frame.bagView then frame.bagView:SetText(bagMode and "* Bag Summary" or "Bag Summary") end
    for key, btn in pairs(frame.statsRangeButtons or {}) do
        btn:SetShown(statsMode)
        if btn:GetFontString() then
            local label = EL:GetSessionStatsRangeLabel(key)
            btn:SetText((frame.statsRange or "30") == key and ("* " .. label) or label)
        end
    end

    -- Non-history tabs are delegated to SessionWindow.lua so the tab routing
    -- stays small and all extracted refresh paths are easy to verify.
    if bagMode or statsMode then
        if self.RefreshSessionView then
            self:RefreshSessionView(frame, viewMode)
        elseif self.WarnMissingSessionWindowHelper then
            self:WarnMissingSessionWindowHelper("RefreshSessionView")
        end
        return
    end

    local list = (self.GetSessionHistoryList and self:GetSessionHistoryList()) or {}
    local totals = {duration = 0, item = 0, raw = 0, spent = 0, total = 0}
    for _, entry in ipairs(list) do
        totals.duration = totals.duration + (tonumber(entry.duration) or 0)
        totals.item = totals.item + (tonumber(entry.itemValueSilver) or 0)
        totals.raw = totals.raw + (tonumber(entry.rawGoldGainedSilver) or 0)
        totals.spent = totals.spent + (tonumber(entry.goldSpentSilver) or 0)
        totals.total = totals.total + (tonumber(entry.totalSilver) or 0)
    end
    local maxOffset = math.max(0, #list - SESSION_HISTORY_ROWS)
    frame.historyOffset = math.max(0, math.min(maxOffset, tonumber(frame.historyOffset) or 0))
    if frame.scrollBar then
        frame._updatingScrollBar = true
        frame.scrollBar:SetMinMaxValues(0, maxOffset)
        frame.scrollBar:SetValueStep(1)
        frame.scrollBar:SetValue(frame.historyOffset or 0)
        frame.scrollBar:SetShown(maxOffset > 0)
        frame._updatingScrollBar = false
    end
    for i, row in ipairs(frame.rows or {}) do
        local entry = list[i + (frame.historyOffset or 0)]
        row.entry = entry
        if row.highlight then row.highlight:Hide() end
        if entry then
            row:Show()
            local dateText = date("%b %d %I:%M %p", tonumber(entry.timestamp) or time())
            row.texts[1]:SetText(dateText)
            row.texts[2]:SetText((entry.character or "Unknown") .. "-" .. (entry.realm or ""))
            local classFile = entry.class
            if (not classFile or classFile == "") and self.ResolveSessionHistoryClass then
                classFile = self:ResolveSessionHistoryClass(entry)
                entry.class = classFile or entry.class
            end
            local cr, cg, cb = self:GetClassColor(classFile)
            row.texts[2]:SetTextColor(cr, cg, cb)
            row.texts[3]:SetText(self:FormatDuration(tonumber(entry.duration) or 0))
            row.texts[4]:SetText(EL:FormatSessionHistoryMoneyText(tonumber(entry.totalSilver) or 0))
            row.texts[5]:SetText(self:FormatMoneyRateText(tonumber(entry.goldPerHourSilver) or 0) .. "/hr")
            if (tonumber(entry.totalSilver) or 0) < 0 then
                row.texts[4]:SetTextColor(1.00, 0.34, 0.28)
            else
                row.texts[4]:SetTextColor(0.55, 1.00, 0.36)
            end
            row.texts[1]:SetTextColor(0.90, 0.91, 0.92)
            row.texts[3]:SetTextColor(0.90, 0.91, 0.92)
            row.texts[5]:SetTextColor(0.90, 0.91, 0.92)
        else
            row:Show()
            for _, fs in ipairs(row.texts or {}) do fs:SetText(""); fs:SetTextColor(0.88, 0.90, 0.92) end
        end
    end
    if frame.info then
        local scopeText = displayMode == "today" and "Showing today's saved sessions." or (displayMode == "week" and "Showing sessions since weekly reset." or "Showing last 30 days.")
        frame.info:SetText(scopeText .. " Saved summaries are retained up to 30 days, capped at " .. tostring((self.GetSessionHistoryMaxEntries and self:GetSessionHistoryMaxEntries()) or 500) .. " entries for the visible list. Stats use compact aggregates. " .. (enabled and "Sessions save on reset and logout/reload." or "Session history is currently disabled."))
    end
    if frame.rangeText then frame.rangeText:SetText(EL:FormatSessionHistoryRange(displayMode)) end
    if frame.totalsTitle then frame.totalsTitle:SetText("Sessions Total (" .. displayLabel .. ")") end
    if frame.totalSessions then frame.totalSessions:SetText(tostring(#list) .. (enabled and "" or " (off)")) end
    if frame.totalDuration then frame.totalDuration:SetText(self:FormatDuration(totals.duration)) end
    if frame.totalItems then frame.totalItems:SetText(EL:FormatSessionHistoryMoneyText(totals.item)) end
    if frame.totalRaw then frame.totalRaw:SetText(EL:FormatSessionHistoryMoneyText(totals.raw)) end
    if frame.totalSpent then frame.totalSpent:SetText(EL:FormatSessionHistoryMoneyText(-(totals.spent))) end
    if frame.totalNet then
        frame.totalNet:SetText(EL:FormatSessionHistoryMoneyText(totals.total))
        frame.totalNet:SetTextColor(totals.total < 0 and 1.00 or 0.55, totals.total < 0 and 0.34 or 1.00, totals.total < 0 and 0.28 or 0.36)
    end
end

function EL:ToggleSessionHistoryWindow()
    if not self.sessionHistoryWindow then self:CreateSessionHistoryWindow() end
    if self.sessionHistoryWindow:IsShown() then
        self.sessionHistoryWindow:Hide()
    else
        self:RefreshSessionHistoryWindow()
        self.sessionHistoryWindow:Show()
        BringEmberWindowToFront(self.sessionHistoryWindow)
    end
end


function EL:CreateUI()
    if self.uiCreated then return end
    self.uiCreated = true
    self:CreateMainButton()
    self:CreatePanel()
    self:CreateSessionWindow()
    self:CreateSessionHistoryWindow()
    if self.RegisterBlizzardSettings then self:RegisterBlizzardSettings() end
    if self.db and self.db.settings then
        C_Timer.After(0, function()
            if EL.db.settings.panel and EL.db.settings.panel.windowOpen and EL.ShowPanelFromSavedState then
                EL:ShowPanelFromSavedState()
            end
            if EL.db.settings.session and EL.db.settings.session.windowOpen and EL.ShowSessionWindowFromSavedState then
                EL:ShowSessionWindowFromSavedState()
            end
        end)
    end
    if self.button and self.db and self.db.settings and self.db.settings.button and self.db.settings.button.shown == false then
        self.button:Hide()
    end
    if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
end

function EL:CreateMainButton()
    local s = self.db.settings.button
    local button = CreateFrame("Button", "EmberLedgerButton", UIParent, "BackdropTemplate")
    self.button = button
    button:SetSize(162, 62)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    AddBackdrop(button, GetLauncherOpacity(), BORDER_ALPHA_STRONG)
    AddInnerBorder(button)
    if button.SetBackdropColor then button:SetBackdropColor(EL_BG_R, EL_BG_G, EL_BG_B, GetLauncherOpacity()) end
    if button.SetBackdropBorderColor then button:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, BORDER_ALPHA_STRONG) end

    button.title = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.title:SetPoint("TOPLEFT", 10, -7)
    button.title:SetPoint("TOPRIGHT", -10, -7)
    button.title:SetJustifyH("CENTER")
    button.title:SetText("EmberLedger")
    if button.title.SetFontObject then button.title:SetFontObject(GameFontNormalLarge) end
    button.title:SetTextColor(1.00, 0.82, 0.24)
    button.title:SetShadowColor(0.00, 0.00, 0.00, 1.00)
    button.title:SetShadowOffset(1, -1)
    if button.title.SetWordWrap then button.title:SetWordWrap(false) end

    button.titleGlow = button:CreateTexture(nil, "BACKGROUND")
    button.titleGlow:SetPoint("TOPLEFT", button, "TOPLEFT", 12, -8)
    button.titleGlow:SetPoint("TOPRIGHT", button, "TOPRIGHT", -12, -8)
    button.titleGlow:SetHeight(18)
    button.titleGlow:SetColorTexture(0.00, 0.00, 0.00, 0.16)

    button.titleRule = button:CreateTexture(nil, "ARTWORK")
    button.titleRule:SetPoint("TOPLEFT", button.title, "BOTTOMLEFT", 10, -3)
    button.titleRule:SetPoint("TOPRIGHT", button.title, "BOTTOMRIGHT", -10, -3)
    button.titleRule:SetHeight(1)
    button.titleRule:SetColorTexture(1.00, 0.82, 0.32, 0.38)

    button.line1 = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.line1:SetPoint("TOPLEFT", button.title, "BOTTOMLEFT", 0, -7)
    button.line1:SetPoint("TOPRIGHT", button.title, "BOTTOMRIGHT", 0, -7)
    button.line1:SetJustifyH("CENTER")
    if button.line1.SetWordWrap then button.line1:SetWordWrap(false) end

    button.line2 = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.line2:SetPoint("TOPLEFT", button.line1, "BOTTOMLEFT", 0, -3)
    button.line2:SetPoint("TOPRIGHT", button.line1, "BOTTOMRIGHT", 0, -3)
    button.line2:SetJustifyH("CENTER")
    if button.line2.SetWordWrap then button.line2:SetWordWrap(false) end
    button.line2:SetTextColor(0.90, 0.88, 0.78)

    button.line3 = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.line3:SetPoint("TOPLEFT", button.line2, "BOTTOMLEFT", 0, -3)
    button.line3:SetPoint("TOPRIGHT", button.line2, "BOTTOMRIGHT", 0, -3)
    button.line3:SetJustifyH("CENTER")
    if button.line3.SetWordWrap then button.line3:SetWordWrap(false) end
    button.line3:SetTextColor(0.82, 0.82, 0.76)

    button.line4 = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.line4:SetPoint("TOPLEFT", button.line3, "BOTTOMLEFT", 0, -3)
    button.line4:SetPoint("TOPRIGHT", button.line3, "BOTTOMRIGHT", 0, -3)
    button.line4:SetJustifyH("CENTER")
    if button.line4.SetWordWrap then button.line4:SetWordWrap(false) end
    button.line4:SetTextColor(0.74, 0.76, 0.72)

    button.line5 = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.line5:SetPoint("TOPLEFT", button.line4, "BOTTOMLEFT", 0, -3)
    button.line5:SetPoint("TOPRIGHT", button.line4, "BOTTOMRIGHT", 0, -3)
    button.line5:SetJustifyH("CENTER")
    if button.line5.SetWordWrap then button.line5:SetWordWrap(false) end
    button.line5:SetTextColor(0.78, 0.78, 0.72)

    button.hover = button:CreateTexture(nil, "HIGHLIGHT")
    button.hover:SetAllPoints()
    button.hover:SetColorTexture(1.00, 0.82, 0.32, 0.10)

    button:SetScript("OnDragStart", function(self)
        local settings = EL.db.settings.button
        if not settings.locked and not (EL.db.settings.lockWindows == true) or IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFramePoint(self, EL.db.settings.button)
    end)
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            EL:ToggleLauncherLock()
        else
            if EL.ToggleAllWindows then EL:ToggleAllWindows() else EL:TogglePanel() end
        end
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnEnter", function(self) EL:ShowButtonTooltip(self) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    SetFramePointFromDB(button, s)
end


function EL:CreateSessionPanel(parent)
    local session = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    parent.sessionPanel = session
    session:SetHeight(SESSION_EXPANDED_H)
    AddBackdrop(session, 0.30, 0.28)
    if session.SetBackdropColor then session:SetBackdropColor(EL_BG_R, EL_BG_G, EL_BG_B, 0.46) end
    if session.SetBackdropBorderColor then session:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, BORDER_ALPHA_SOFT) end

    session.header = CreateFrame("Frame", nil, session, "BackdropTemplate")
    session.header:SetHeight(28)
    session.header:SetPoint("TOPLEFT", 4, -4)
    session.header:SetPoint("TOPRIGHT", -4, -4)
    AddBackdrop(session.header, 0.24, 0.18)
    if session.header.SetBackdropColor then session.header:SetBackdropColor(EL_HEADER_R, EL_HEADER_G, EL_HEADER_B, 0.78) end
    if session.header.SetBackdropBorderColor then session.header:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0.38) end
    AddHeaderAccent(session.header)

    session.title = session.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    session.title:SetPoint("LEFT", session.header, "LEFT", 10, 0)
    session.title:SetPoint("RIGHT", session.header, "RIGHT", -32, 0)
    session.title:SetJustifyH("LEFT")
    session.title:SetText("EmberLedger Session")
    session.title:SetTextColor(1.00, 0.82, 0.24)

    session.buttonBar = CreateFrame("Frame", nil, session)
    session.buttonBar:SetPoint("BOTTOMLEFT", session, "BOTTOMLEFT", 6, 6)
    session.buttonBar:SetPoint("BOTTOMRIGHT", session, "BOTTOMRIGHT", -6, 6)
    session.buttonBar:SetHeight(24)

    session.toggle = CreateFrame("Button", nil, session.buttonBar, "UIPanelButtonTemplate")
    session.toggle:SetSize(64, 20)
    session.toggle:SetPoint("CENTER", session.buttonBar, "CENTER", -72, 0)
    StyleBlizzardButton(session.toggle)
    session.toggle.text = session.toggle:GetFontString()
    session.toggle:SetScript("OnClick", function() EL:ToggleSessionPause() end)

    session.reset = CreateFrame("Button", nil, session.buttonBar, "UIPanelButtonTemplate")
    session.reset:SetSize(64, 20)
    session.reset:SetPoint("CENTER", session.buttonBar, "CENTER", 72, 0)
    session.reset:SetText("Reset")
    StyleBlizzardButton(session.reset)
    session.reset.text = session.reset:GetFontString()
    session.reset:SetScript("OnClick", function() if EL.ConfirmResetSession then EL:ConfirmResetSession() else EL:ResetSession() end end)

    session.history = CreateFrame("Button", nil, session.buttonBar, "UIPanelButtonTemplate")
    session.history:SetSize(64, 20)
    session.history:SetPoint("CENTER", session.buttonBar, "CENTER", 0, 0)
    session.history:SetText("Stats")
    StyleBlizzardButton(session.history)
    session.history.text = session.history:GetFontString()
    session.history:SetScript("OnClick", function() if EL.ToggleSessionHistoryWindow then EL:ToggleSessionHistoryWindow() end end)

    session.metrics = CreateFrame("Frame", nil, session)
    session.metrics:SetPoint("TOPLEFT", session.header, "BOTTOMLEFT", 4, -4)
    session.metrics:SetPoint("TOPRIGHT", session.header, "BOTTOMRIGHT", -4, -4)
    session.metrics:SetHeight(42)

    session.metricTime = CreateMetricBlock(session.metrics, "Session time")
    session.metricTime:SetPoint("TOPLEFT", session.metrics, "TOPLEFT", 0, 0)
    session.metricTime:SetSize(74, 38)

    session.metricValue = CreateMetricBlock(session.metrics, "Total")
    session.metricValue:SetPoint("LEFT", session.metricTime, "RIGHT", 6, 0)
    session.metricValue:SetSize(62, 38)

    session.metricRate = CreateMetricBlock(session.metrics, "Rate")
    session.metricRate:SetPoint("LEFT", session.metricValue, "RIGHT", 6, 0)
    session.metricRate:SetSize(72, 38)

    session.metricDiv1 = AddSoftDivider(session.metrics, 96, 0, -36)
    session.metricDiv2 = AddSoftDivider(session.metrics, 174, 0, -36)

    session.summary = session:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    session.summary:SetText("")
    session.summary:Hide()

    session.itemClip = CreateFrame("Frame", nil, session)
    session.itemClip:SetPoint("TOPLEFT", session.metrics, "BOTTOMLEFT", 0, -3)
    session.itemClip:SetPoint("TOPRIGHT", session.metrics, "BOTTOMRIGHT", 0, -3)
    session.itemClip:SetHeight(SESSION_VISIBLE_ITEM_ROWS * SESSION_ITEM_ROW_H)
    session.itemClip:EnableMouse(true)
    session.itemClip:EnableMouseWheel(true)
    session.itemClip:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = math.max(0, (session.itemCount or 0) - SESSION_VISIBLE_ITEM_ROWS)
        session.itemScrollOffset = math.max(0, math.min(maxOffset, (session.itemScrollOffset or 0) - (delta or 0)))
        if EL.RefreshSessionPanel then EL:RefreshSessionPanel() end
    end)
    if session.itemClip.SetClipsChildren then session.itemClip:SetClipsChildren(true) end

    session.items = {}
    for i = 1, SESSION_VISIBLE_ITEM_ROWS do
        local row = CreateFrame("Frame", nil, session.itemClip)
        row:SetSize(1, SESSION_ITEM_ROW_H)
        row:SetPoint("TOPLEFT", session.itemClip, "TOPLEFT", 0, -((i - 1) * SESSION_ITEM_ROW_H))
        row:SetPoint("RIGHT", session.itemClip, "RIGHT", 0, 0)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(12, 12)
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon:Hide()

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetJustifyH("LEFT")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        if row.text.SetWordWrap then row.text:SetWordWrap(false) end

        session.items[i] = row
    end
end

function EL:RefreshSessionPanel()
    local p = self.sessionWindow
    local sp = p and p.sessionPanel
    if not sp then return end
    local shown = self.db and self.db.settings and self.db.settings.session and self.db.settings.session.shown ~= false
    if not shown then return end
    sp:SetShown(true)
    if self.IsSessionTrackingEnabled and not self:IsSessionTrackingEnabled() then
        if sp.summary then
            sp.summary:SetText("Session tracking is disabled.\nEnable it under Performance to track time, gathered items, and value.")
            sp.summary:SetTextColor(0.82, 0.78, 0.68)
            sp.summary:Show()
        end
        if sp.metrics then sp.metrics:SetShown(false) end
        if sp.metricDiv1 then sp.metricDiv1:SetShown(false) end
        if sp.metricDiv2 then sp.metricDiv2:SetShown(false) end
        if sp.toggle then sp.toggle:SetShown(false) end
        if sp.reset then sp.reset:SetShown(false) end
        if sp.history then sp.history:SetShown(false) end
        if sp.buttonBar then sp.buttonBar:SetShown(false) end
        if sp.itemClip then sp.itemClip:SetShown(false) end
        for _, row in ipairs(sp.items or {}) do row:SetShown(false) end
        return
    end
    if sp.metrics then sp.metrics:SetShown(true) end
    if sp.metricDiv1 then sp.metricDiv1:SetShown(true) end
    if sp.metricDiv2 then sp.metricDiv2:SetShown(true) end
    if sp.toggle then sp.toggle:SetShown(true) end
    if sp.reset then sp.reset:SetShown(true) end
    if sp.history then sp.history:SetShown(true) end
    if sp.buttonBar then sp.buttonBar:SetShown(true) end
    for _, row in ipairs(sp.items or {}) do row:SetShown(true) end

    local s = self:GetSessionDB()
    local elapsed = self:GetSessionElapsedSeconds()
    local totalSilver = tonumber(s.totalSilver) or 0
    local value = self:FormatMoneyText(totalSilver)
    local gphSilver = self:GetSessionGoldPerHour()
    local gph = self:FormatMoneyRateText(gphSilver) .. "/hr"
    if sp.summary then sp.summary:SetText(""); sp.summary:Hide() end
    if sp.metricTime and sp.metricTime.value then sp.metricTime.value:SetText(FormatSessionTime(elapsed)) end
    if sp.metricValue and sp.metricValue.value then
        sp.metricValue.value:SetText(value)
        sp.metricValue.value:SetTextColor(totalSilver < 0 and 1.00 or 1.00, totalSilver < 0 and 0.35 or 0.92, totalSilver < 0 and 0.28 or 0.56)
    end
    if sp.metricRate and sp.metricRate.value then
        sp.metricRate.value:SetText(gph)
        sp.metricRate.value:SetTextColor(0.82, 0.78, 0.68)
    end
    if sp.itemClip then sp.itemClip:SetShown(true) end
    sp.toggle:SetText(s.isPaused and "Start" or "Pause")
    if sp.toggle.text then
        sp.toggle.text:SetTextColor(s.isPaused and 0.35 or 1, s.isPaused and 1 or 0.72, s.isPaused and 0.35 or 0.2)
    end

    local warning = self:GetPricingWarning()
    local lootLog = self.GetSessionLootLog and self:GetSessionLootLog(math.max(100, tonumber(self.db.settings.session.topItems) or 0)) or {}
    sp.itemCount = #lootLog
    local maxOffset = math.max(0, #lootLog - SESSION_VISIBLE_ITEM_ROWS)
    sp.itemScrollOffset = math.max(0, math.min(maxOffset, tonumber(sp.itemScrollOffset) or 0))
    local displayTop = {}
    for i = 1, SESSION_VISIBLE_ITEM_ROWS do
        displayTop[i] = lootLog[(sp.itemScrollOffset or 0) + i]
    end
    local function ConfigureSessionRowText(row, wrapped)
        if not row or not row.text then return end
        row:SetHeight(wrapped and (SESSION_ITEM_ROW_H * 2) or SESSION_ITEM_ROW_H)
        if row.text.SetWordWrap then row.text:SetWordWrap(wrapped == true) end
        if row.text.SetMaxLines then row.text:SetMaxLines(wrapped and 2 or 1) end
        if row.text.SetJustifyV then row.text:SetJustifyV(wrapped and "TOP" or "MIDDLE") end
        if row.text.SetHeight then row.text:SetHeight(wrapped and (SESSION_ITEM_ROW_H * 2) or SESSION_ITEM_ROW_H) end
    end

    local function ClearSessionRow(row)
        if not row then return end
        ConfigureSessionRowText(row, false)
        if row.icon then row.icon:Hide(); row.icon:SetTexture(nil) end
        if row.text then row.text:SetText("") end
    end

    local function SetSessionRow(row, text, r, g, b, icon, wrapped)
        if not row then return end
        ConfigureSessionRowText(row, wrapped == true)
        if icon and row.icon then
            row.icon:SetTexture(icon)
            row.icon:Show()
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        else
            if row.icon then row.icon:Hide(); row.icon:SetTexture(nil) end
            row.text:ClearAllPoints()
            if wrapped then
                row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
                row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
            else
                row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            end
        end
        row.text:SetText(text or "")
        row.text:SetTextColor(r or 0.88, g or 0.90, b or 0.92)
    end

    if warning and (tonumber(s.totalItems) or 0) == 0 then
        SetSessionRow(sp.items[1], "Pricing: " .. warning, 0.95, 0.62, 0.26, nil, true)
        for i = 2, #sp.items do ClearSessionRow(sp.items[i]) end
        return
    end
    if #lootLog == 0 then
        SetSessionRow(sp.items[1], s.isPaused and "Session paused. Press Start before gathering." or "No session items yet. Gather profession materials to begin tracking value.", 0.68, 0.70, 0.72, nil, true)
        for i = 2, #sp.items do ClearSessionRow(sp.items[i]) end
        return
    end
    for i, row in ipairs(sp.items) do
        local item = displayTop[i]
        if item then
            local money = item.moneyText or self:FormatMoneyText(item.silver or 0)
            local text
            if item.type == "money" then
                text = string.format("%s  •  %s", item.name or "Gold", money)
            else
                text = string.format("%s x%d  •  %s", item.name or ("item:" .. tostring(item.itemID)), tonumber(item.count or item.qty) or 0, money)
            end
            SetSessionRow(row, text, item.type == "money" and ((tonumber(item.silver) or 0) < 0 and 1.00 or 0.88) or 0.88, item.type == "money" and ((tonumber(item.silver) or 0) < 0 and 0.42 or 0.90) or 0.90, item.type == "money" and ((tonumber(item.silver) or 0) < 0 and 0.36 or 0.92) or 0.92, item.icon)
        else
            ClearSessionRow(row)
        end
    end
end


function EL:CreatePanel()
    local s = self.db.settings.panel
    local panel = CreateFrame("Frame", "EmberLedgerPanel", UIParent, "BackdropTemplate")
    self.panel = panel
    local autoW = (self.GetTrackingPanelMaxWidth and self:GetTrackingPanelMaxWidth()) or PANEL_MIN_W
    panel:SetSize(autoW, math.max(PANEL_MIN_H, tonumber(s.height) or 360))
    if panel.SetResizeBounds then panel:SetResizeBounds(autoW, GetCurrentPanelMinHeight(panel), autoW, GetTrackingPanelMaxHeight(panel)) end
    panel:SetMovable(true)
    panel:SetResizable(false)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)
    AddBackdrop(panel, 0.64, 0.62)
    if panel.SetBackdropColor then panel:SetBackdropColor(EL_BG_R, EL_BG_G, EL_BG_B, GetPanelOpacity()) end
    if panel.SetBackdropBorderColor then panel:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, BORDER_ALPHA_STRONG) end
    AddInnerBorder(panel)
    panel:Hide()
    panel:SetScript("OnShow", function(self)
        BringEmberWindowToFront(self)
        if EL.db and EL.db.settings and EL.db.settings.panel then
            EL.db.settings.panel.windowOpen = true
            EL.db.settings.panel.charactersShown = true
        end
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
        if EL.RefreshUpdateTicker then EL:RefreshUpdateTicker() end
    end)
    panel:SetScript("OnHide", function()
        if EL.db and EL.db.settings and EL.db.settings.panel then
            EL.db.settings.panel.windowOpen = false
            if not EL._suppressPanelWindowHideSetting then
                EL.db.settings.panel.charactersShown = false
            end
        end
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
        if EL.RefreshUpdateTicker then EL:RefreshUpdateTicker() end
    end)
    panel:SetScale(math.max(PANEL_MIN_SCALE, math.min(PANEL_MAX_SCALE, tonumber(s.scale) or 1)))

    panel:SetScript("OnMouseDown", function(self)
        BringEmberWindowToFront(self)
    end)
    panel:SetScript("OnDragStart", function(self) if not (EL.db.settings.lockWindows == true) or IsShiftKeyDown() then BringEmberWindowToFront(self); self:StartMoving() end end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        EL.db.settings.panel.detached = true
        SaveFramePoint(self, EL.db.settings.panel)
    end)
    panel:SetScript("OnSizeChanged", function(self)
        if self._autoSizingPanel or self._autoSizingHeight or not (EL.db and EL.db.settings and EL.db.settings.panel) then return end
        local targetW, targetH = EL:GetTrackingPanelAutoSize()
        if math.abs((self:GetWidth() or 0) - targetW) > 1 or math.abs((self:GetHeight() or 0) - targetH) > 1 then
            if EL.AutoSizeTrackingPanel then EL:AutoSizeTrackingPanel("sizeChanged") end
        end
    end)

    panel.topBar = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.topBar:SetHeight(30)
    panel.topBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    panel.topBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    AddBackdrop(panel.topBar, 0.30, 0.26)
    if panel.topBar.SetBackdropColor then panel.topBar:SetBackdropColor(EL_HEADER_R, EL_HEADER_G, EL_HEADER_B, 0.78) end
    if panel.topBar.SetBackdropBorderColor then panel.topBar:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0.38) end
    AddHeaderAccent(panel.topBar)

    panel.title = panel.topBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("LEFT", panel.topBar, "LEFT", 10, 0)
    panel.title:SetText("EmberLedger")
    panel.title:SetTextColor(1.00, 0.82, 0.24)

    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOPLEFT", panel.topBar, "BOTTOMLEFT", 2, -4)
    panel.subtitle:SetText("Profession Tracking")
    panel.subtitle:SetTextColor(0.78, 0.84, 0.92)

    panel.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.summary:SetPoint("TOPLEFT", panel.subtitle, "BOTTOMLEFT", 0, -2)
    panel.summary:SetJustifyH("LEFT")
    panel.summary:SetTextColor(0.88, 0.86, 0.78)
    panel.summary:SetText("")
    panel.summary:Hide()

    panel.close = CreateFrame("Button", nil, panel.topBar, "UIPanelCloseButton")
    panel.close:SetSize(18, 18)
    panel.close:SetPoint("RIGHT", panel.topBar, "RIGHT", -5, 0)
    panel.close:SetScript("OnClick", function()
        EL._suppressPanelWindowHideSetting = true
        panel:Hide()
        EL._suppressPanelWindowHideSetting = false
        if EL.db and EL.db.settings and EL.db.settings.panel then
            EL.db.settings.panel.charactersShown = true
            EL.db.settings.panel.windowOpen = false
        end
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
        if EL.RefreshUpdateTicker then EL:RefreshUpdateTicker() end
    end)

    panel.settings = CreateFrame("Button", nil, panel.topBar, "UIPanelButtonTemplate")
    panel.settings:SetSize(64, 22)
    panel.settings:SetText("Options")
    StyleBlizzardButton(panel.settings)
    panel.settings:SetPoint("RIGHT", panel.close, "LEFT", -7, 0)
    panel.settings:SetScript("OnClick", function() EL:ToggleSettingsPanel() end)
    panel.settings:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("EmberLedger options", 1, 0.74, 0.32)
        GameTooltip:Show()
    end)
    panel.settings:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Scale controls live in the Options panel.
    panel.scaleDown = nil
    panel.scaleUp = nil

    panel.restore = CreateFrame("Button", nil, panel.topBar or panel, "UIPanelButtonTemplate")
    panel.restore:SetSize(78, 22)
    panel.restore:SetText("Restore")
    StyleBlizzardButton(panel.restore)
    panel.restore:SetPoint("RIGHT", panel.settings, "LEFT", -6, 0)
    panel.restore:SetScript("OnClick", function() EL:RestoreHiddenCharacters() end)
    panel.restore:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Restore hidden characters", 1, 0.55, 0.15)
        GameTooltip:AddLine("Right-click a row to hide a character.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    panel.restore:SetScript("OnLeave", function() GameTooltip:Hide() end)

    panel.characterToggle = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.characterToggle:SetSize(22, 20)
    StyleBlizzardButton(panel.characterToggle)
    panel.characterToggle.text = panel.characterToggle:GetFontString()
    panel.characterToggle:SetScript("OnClick", function() EL:ToggleCharacterSectionCollapsed() end)
    panel.characterToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Collapse or expand character cooldowns", 1, 0.74, 0.32)
        GameTooltip:Show()
    end)
    panel.characterToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.characterToggle:Hide()

    panel.header = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.header:SetHeight(32)
    if panel.header.SetClipsChildren then panel.header:SetClipsChildren(true) end
    AddBackdrop(panel.header, 0.42, 0.30)
    if panel.header.SetBackdropColor then panel.header:SetBackdropColor(EL_HEADER_R, EL_HEADER_G, EL_HEADER_B, 0.74) end
    if panel.header.SetBackdropBorderColor then panel.header:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0.34) end
    panel.header.topLine = panel.header:CreateTexture(nil, "BORDER")
    panel.header.topLine:SetHeight(1)
    panel.header.topLine:SetPoint("TOPLEFT", 2, -1)
    panel.header.topLine:SetPoint("TOPRIGHT", -2, -1)
    panel.header.topLine:SetColorTexture(0.82, 0.74, 0.58, HEADER_LINE_ALPHA_TOP)
    panel.header.bottomLine = panel.header:CreateTexture(nil, "BORDER")
    panel.header.bottomLine:SetHeight(1)
    panel.header.bottomLine:SetPoint("BOTTOMLEFT", 2, 1)
    panel.header.bottomLine:SetPoint("BOTTOMRIGHT", -2, 1)
    panel.header.bottomLine:SetColorTexture(0.82, 0.74, 0.58, HEADER_LINE_ALPHA_BOTTOM)
    panel.header.separators = {}
    panel.header.name = panel.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.header.prof1 = panel.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.header.conc1 = panel.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.header.prof2 = panel.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.header.conc2 = panel.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.header.moxie = panel.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.header.forecast = panel.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.header.cooldown = panel.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.header.mulch = panel.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.header.name:SetText("Character")
    panel.header.prof1:SetText("P1")
    panel.header.conc1:SetText("Conc 1")
    panel.header.prof2:SetText("P2")
    panel.header.conc2:SetText("Conc 2")
    panel.header.moxie:SetText("Moxie")
    panel.header.forecast:SetText("Next")
    panel.header.cooldown:SetText("CD")
    panel.header.mulch:SetText("Mulch")
    for _, fs in pairs({panel.header.name, panel.header.prof1, panel.header.conc1, panel.header.prof2, panel.header.conc2, panel.header.moxie, panel.header.forecast, panel.header.cooldown, panel.header.mulch}) do
        fs:SetTextColor(0.88, 0.84, 0.74)
        fs:SetJustifyH(fs == panel.header.name and "LEFT" or "CENTER")
        if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 0.80) end
        if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
    end
    panel.header.nameButton = CreateHeaderButton(panel.header, panel.header.name, "character")
    panel.header.prof1Button = CreateHeaderButton(panel.header, panel.header.prof1, "prof1")
    panel.header.conc1Button = CreateHeaderButton(panel.header, panel.header.conc1, "conc1")
    panel.header.prof2Button = CreateHeaderButton(panel.header, panel.header.prof2, "prof2")
    panel.header.conc2Button = CreateHeaderButton(panel.header, panel.header.conc2, "conc2")
    panel.header.moxieButton = CreateHeaderButton(panel.header, panel.header.moxie, "moxie")
    panel.header.forecastButton = CreateHeaderButton(panel.header, panel.header.forecast, "forecast")
    panel.header.cooldownButton = CreateHeaderButton(panel.header, panel.header.cooldown, "cooldown")
    panel.header.mulchButton = CreateHeaderButton(panel.header, panel.header.mulch, "mulch")

    panel.scroll = CreateFrame("ScrollFrame", "EmberLedgerScrollFrame", panel, "UIPanelScrollFrameTemplate")
    StyleScrollBar(panel.scroll)
    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.scroll:SetScrollChild(panel.content)
    panel.rows = {}

    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.empty:SetText("No tracked characters yet.\nOpen a profession window on each character to begin tracking.")
    panel.empty:SetTextColor(0.68, 0.70, 0.72)
    panel.empty:SetJustifyH("CENTER")
    panel.empty:SetJustifyV("TOP")
    if panel.empty.SetWordWrap then panel.empty:SetWordWrap(true) end
    if panel.empty.SetSpacing then panel.empty:SetSpacing(4) end
    panel.empty:Hide()

    self:CreateActionBar(panel)

    panel.version = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.version:SetPoint("BOTTOMLEFT", 14, 12)
    panel.version:SetText("")
    panel.version:Hide()

    -- Width remains automatic from the visible columns, but the lower edge can
    -- be dragged to choose how many character rows are visible. Double-click
    -- the resize grip to return to automatic height.
    panel.resize = CreateFrame("Button", nil, panel, "BackdropTemplate")
    panel.resize:SetSize(18, 18)
    panel.resize:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 10)
    panel.resize:SetFrameLevel((panel:GetFrameLevel() or 1) + 20)
    panel.resize.lines = {}
    for i = 1, 3 do
        local line = panel.resize:CreateTexture(nil, "OVERLAY")
        line:SetHeight(2)
        line:SetWidth(7 + ((4 - i) * 4))
        line:SetPoint("BOTTOMRIGHT", panel.resize, "BOTTOMRIGHT", -2, 2 + ((i - 1) * 5))
        line:SetColorTexture(1.00, 0.78, 0.24, 0.58)
        panel.resize.lines[i] = line
    end
    panel.resize.corner = panel.resize:CreateTexture(nil, "BACKGROUND")
    panel.resize.corner:SetPoint("BOTTOMRIGHT", panel.resize, "BOTTOMRIGHT", 0, 0)
    panel.resize.corner:SetSize(18, 18)
    panel.resize.corner:SetColorTexture(0.02, 0.015, 0.01, 0.22)
    panel.resize:RegisterForClicks("LeftButtonUp")
    panel.resize:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Resize tracker height", 1, 0.82, 0.24)
        GameTooltip:AddLine("Drag to change how many character rows are visible.", 0.78, 0.78, 0.72)
        GameTooltip:AddLine("Width remains automatic based on visible columns.", 0.62, 0.68, 0.76)
        GameTooltip:AddLine("Double-click to reset automatic height.", 0.62, 0.68, 0.76)
        GameTooltip:Show()
    end)
    panel.resize:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.resize:SetScript("OnDoubleClick", function()
        if EL.ClearTrackingPanelCustomHeight then EL:ClearTrackingPanelCustomHeight() end
    end)
    panel.resize:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        if EL.db and EL.db.settings and EL.db.settings.lockWindows == true and not (IsShiftKeyDown and IsShiftKeyDown()) then return end
        local parent = self:GetParent()
        if not parent then return end
        local _, cursorY = GetCursorPosition()
        local scale = parent:GetEffectiveScale() or 1
        parent._emberResizeStartY = (cursorY or 0) / scale
        parent._emberResizeStartH = parent:GetHeight() or GetCurrentPanelMinHeight(parent)
        parent._emberVerticalResizing = true
        self:SetScript("OnUpdate", function()
            local _, y = GetCursorPosition()
            local effectiveScale = parent:GetEffectiveScale() or 1
            local currentY = (y or 0) / effectiveScale
            local delta = (parent._emberResizeStartY or currentY) - currentY
            SetTrackingPanelVerticalHeight(parent, (parent._emberResizeStartH or 0) + delta)
            if EL.LayoutPanel then EL:LayoutPanel() end
        end)
    end)
    panel.resize:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        local parent = self:GetParent()
        if parent then
            parent._emberVerticalResizing = nil
            parent._emberResizeStartY = nil
            parent._emberResizeStartH = nil
            if EL.db and EL.db.settings and EL.db.settings.panel then
                EL.db.settings.panel.customHeight = math.floor(parent:GetHeight() or GetCurrentPanelMinHeight(parent))
                EL.db.settings.panel.height = EL.db.settings.panel.customHeight
                SaveFramePoint(parent, EL.db.settings.panel)
            end
            if EL.LayoutPanel then EL:LayoutPanel() end
            if EL.RequestUpdate then EL:RequestUpdate(true) end
        end
    end)

    self:CreateSettingsPanel(UIParent)
    self:ApplyDisplaySettings()
    SetFramePointFromDB(panel, s)
    self:LayoutPanel()
end

function EL:UpdateSortHeaders()
    local p = self.panel
    if not p or not p.header then return end
    local sort = self:GetSortSettings()
    local active = sort.key or "character"
    local arrow = sort.ascending ~= false and "  ^" or "  v"
    if active == "prof" then active = "prof1" end
    if active == "conc" then active = "conc1" end
    local map = {
        character = p.header.name,
        prof1 = p.header.prof1,
        conc1 = p.header.conc1,
        prof2 = p.header.prof2,
        conc2 = p.header.conc2,
        moxie = p.header.moxie,
        forecast = p.header.forecast,
        cooldown = p.header.cooldown,
        mulch = p.header.mulch,
    }
    if not self:IsTrackingColumnVisible(active) then
        local sort = self:GetSortSettings()
        sort.key = "character"
        sort.ascending = true
        active = "character"
    end
    for key, fs in pairs(map) do
        fs:SetText((HEADER_LABELS[key] or key) .. (key == active and arrow or ""))
        local btnName = key == "character" and "nameButton" or (key .. "Button")
        local btn = p.header[btnName]
        if key == active then
            fs:SetTextColor(0.92, 0.78, 0.50)
            if btn and btn.bg then btn.bg:SetColorTexture(0.78, 0.66, 0.46, 0.10) end
        else
            fs:SetTextColor(0.88, 0.84, 0.74)
            if btn and btn.bg then btn.bg:SetColorTexture(1, 0.72, 0.22, 0) end
        end
    end
end

function EL:ShouldShowMulchColumn(rows)
    if not (self.db and self.db.resources and self.db.resources.mulch) then return false end
    if rows then
        for _, entry in ipairs(rows) do
            local key = entry and entry.key
            if key and not self:IsCharacterHidden(key) and self:HasImbuedMulchAccess(self.db.resources.mulch[key]) then
                return true
            end
        end
        return false
    end
    for key, data in pairs(self.db and self.db.resources and self.db.resources.mulch or {}) do
        if key and not self:IsCharacterHidden(key) and self:HasImbuedMulchAccess(data) then
            return true
        end
    end
    return false
end


local function SetPanelHeightKeepTopLeft(panel, height, settings)
    if not panel then return end
    local left = panel:GetLeft()
    local top = panel:GetTop()

    panel._autoSizingHeight = true
    panel:SetHeight(height)

    -- Resizing a centered/middle-anchored frame can make it appear to move.
    -- Re-anchor by the current top-left corner so collapse/expand only changes
    -- the bottom edge of the EmberLedger window.
    if left and top then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        if settings then
            SaveFramePoint(panel, settings)
        end
    end

    panel._autoSizingHeight = false
end

function EL:AutoSizePanelHeight(reason)
    if self.IsCombatLocked and self:IsCombatLocked() then
        if self.QueueCombatDeferredWork then self:QueueCombatDeferredWork("layout") end
        return
    end
    if self.AutoSizeTrackingPanel then
        self:AutoSizeTrackingPanel(reason or "autoHeight")
    end
end

function EL:LayoutPanel()
    if self.IsCombatLocked and self:IsCombatLocked() then
        if self.QueueCombatDeferredWork then self:QueueCombatDeferredWork("layout") end
        return
    end
    local p = self.panel
    if not p or not p.header or not p.scroll or not p.content then return end
    if self.AutoSizeTrackingPanel and not p._emberVerticalResizing then self:AutoSizeTrackingPanel("layout") end

    local w, h = p:GetWidth(), p:GetHeight()
    local settings = self.db and self.db.settings and self.db.settings.panel or {}
    local charShown = settings.charactersShown ~= false
    local actionBarShown = IsAnchoredActionBarShown()

    if p.characterToggle then
        p.characterToggle:Hide()
        p.characterToggle:ClearAllPoints()
    end

    if self.LayoutActionBar then self:LayoutActionBar() end
    -- Action bar anchoring/floating layout is owned by Modules/ActionBar.lua.
    if p.resize then
        p.resize:ClearAllPoints()
        if actionBarShown and p.actionBar then
            p.resize:SetPoint("RIGHT", p.actionBar, "RIGHT", -8, 0)
        else
            -- With the action bar hidden, keep the resize grip inside the
            -- lower-right frame border instead of letting it sit on the edge.
            p.resize:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -14, 10)
        end
        p.resize:Show()
    end

    local compactMode = IsCompactModeEnabled()
    if p.subtitle then
        if compactMode then
            p.subtitle:SetText("")
            p.subtitle:Hide()
        else
            p.subtitle:SetText("Profession Tracking")
            p.subtitle:Show()
        end
    end

    p.header:ClearAllPoints()
    p.header:SetPoint("TOPLEFT", p, "TOPLEFT", 14, GetTrackingHeaderYOffset())
    p.header:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, GetTrackingHeaderYOffset())
    p.header:SetHeight(compactMode and 28 or 32)

    if p.characterToggle then p.characterToggle:Hide() end

    if not charShown then
        p.header:Hide()
        p.scroll:Hide()
        if p.empty then p.empty:Hide() end
    else
        p.header:Show()
        p.scroll:Show()
        if p.header.nameButton then p.header.nameButton:Show() end

        local headerW = math.max(1, w - 36)
        local targetW = self:GetTrackingPanelMaxWidth()
        if p.SetResizeBounds then p:SetResizeBounds(targetW, GetCurrentPanelMinHeight(p), targetW, GetTrackingPanelMaxHeight(p)) end
        local cols = GetColumnLayout(headerW)
        local visible = {}
        for _, def in ipairs(cols.columns or {}) do visible[def.key] = true end

        local headerMap = { character = p.header.name, prof1 = p.header.prof1, conc1 = p.header.conc1, prof2 = p.header.prof2, conc2 = p.header.conc2, moxie = p.header.moxie, forecast = p.header.forecast, cooldown = p.header.cooldown, mulch = p.header.mulch }
        local buttonMap = { character = p.header.nameButton, prof1 = p.header.prof1Button, conc1 = p.header.conc1Button, prof2 = p.header.prof2Button, conc2 = p.header.conc2Button, moxie = p.header.moxieButton, forecast = p.header.forecastButton, cooldown = p.header.cooldownButton, mulch = p.header.mulchButton }
        for _, def in ipairs(TRACKING_COLUMN_DEFS) do
            local fs = headerMap[def.key]
            local btn = buttonMap[def.key]
            if fs then
                fs:SetShown(visible[def.key] and true or false)
                if visible[def.key] then
                    if def.key == "character" then
                        AnchorColumnText(fs, p.header, (cols[def.key .. "X"] or 0) + 8, math.max(1, (cols[def.key .. "W"] or 1) - 8), "LEFT")
                    else
                        AnchorColumnText(fs, p.header, cols[def.key .. "X"], cols[def.key .. "W"], "CENTER")
                    end
                end
            end
            if btn then
                btn:ClearAllPoints()
                btn:SetShown(visible[def.key] and true or false)
                if visible[def.key] then
                    btn:SetPoint("LEFT", p.header, "LEFT", cols[def.key .. "X"], 0)
                    btn:SetSize(math.max(1, cols[def.key .. "W"]), IsCompactModeEnabled() and 28 or 32)
                end
            end
        end

        local sepPositions = {}
        for i = 2, #(cols.columns or {}) do
            local def = cols.columns[i]
            table.insert(sepPositions, cols[def.key .. "X"] - 6)
        end
        for i, x in ipairs(sepPositions) do
            local sep = p.header.separators[i]
            if not sep then
                sep = p.header:CreateTexture(nil, "BORDER")
                p.header.separators[i] = sep
            end
            sep:ClearAllPoints()
            sep:SetWidth(1)
            sep:SetPoint("TOPLEFT", p.header, "TOPLEFT", x, -4)
            sep:SetPoint("BOTTOMLEFT", p.header, "BOTTOMLEFT", x, 4)
            sep:SetColorTexture(0.82, 0.74, 0.58, 0.08)
            sep:Show()
        end
        for i = #sepPositions + 1, #(p.header.separators or {}) do
            p.header.separators[i]:Hide()
        end

        p.scroll:ClearAllPoints()
        p.scroll:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 0, -4)
        if p.actionBar and actionBarShown then
            p.scroll:SetPoint("BOTTOMRIGHT", p.actionBar, "TOPRIGHT", -2, 8)
        else
            p.scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -14, 34)
        end
        p.content:SetWidth(math.max(1, p.scroll:GetWidth()))
        self:UpdateSortHeaders()
    end

    self:RefreshPanel()
end

function EL:GetRow(i)
    local p = self.panel
    if not p.rows[i] then
        local row = CreateFrame("Button", nil, p.content)
        row:SetHeight(GetTrackingRowHeight())
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.currentHighlight = row:CreateTexture(nil, "BORDER")
        row.currentHighlight:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.currentHighlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.currentHighlight:SetColorTexture(1.00, 0.78, 0.24, 0.00)
        row.currentHighlight:Hide()
        row.currentHighlightTop = row:CreateTexture(nil, "ARTWORK")
        row.currentHighlightTop:SetHeight(1)
        row.currentHighlightTop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.currentHighlightTop:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        row.currentHighlightTop:SetColorTexture(1.00, 0.84, 0.32, 0.00)
        row.currentHighlightTop:Hide()
        row.currentHighlightBottom = row:CreateTexture(nil, "ARTWORK")
        row.currentHighlightBottom:SetHeight(1)
        row.currentHighlightBottom:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.currentHighlightBottom:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.currentHighlightBottom:SetColorTexture(1.00, 0.84, 0.32, 0.00)
        row.currentHighlightBottom:Hide()
        row.currentHighlightLeft = row:CreateTexture(nil, "ARTWORK")
        row.currentHighlightLeft:SetWidth(2)
        row.currentHighlightLeft:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.currentHighlightLeft:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.currentHighlightLeft:SetColorTexture(1.00, 0.84, 0.32, 0.00)
        row.currentHighlightLeft:Hide()
        row.currentHighlightRight = row:CreateTexture(nil, "ARTWORK")
        row.currentHighlightRight:SetWidth(2)
        row.currentHighlightRight:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        row.currentHighlightRight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.currentHighlightRight:SetColorTexture(1.00, 0.84, 0.32, 0.00)
        row.currentHighlightRight:Hide()
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
        row.sep:SetColorTexture(0.95, 0.82, 0.42, ROW_SEPARATOR_ALPHA)
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
        row.mulch = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.mulch:SetJustifyH("CENTER")
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if button == "LeftButton" and self.charKey and IsAltKeyDown and IsAltKeyDown() then
                GameTooltip:Hide()
                if EL.ToggleCharacterPinned then
                    EL:ToggleCharacterPinned(self.charKey)
                end
                return
            end

            if button == "RightButton" and self.charKey then
                local char = EL.db.characters[self.charKey]
                local displayName = (char and (char.displayName or char.name)) or self.charKey
                GameTooltip:Hide()

                if IsShiftKeyDown and IsShiftKeyDown() then
                    EL:ResetCharacterData(self.charKey)
                else
                    EL:SetCharacterHidden(self.charKey, true)
                    EL:RequestUpdate()
                    EL:Print("Hidden: " .. tostring(displayName))
                end
            end
        end)
        row:SetScript("OnEnter", function(self)
            if self.hover then self.hover:Show() end
            EL:ShowRowTooltip(self)
        end)
        row:SetScript("OnLeave", function(self)
            if self.hover then self.hover:Hide() end
            GameTooltip:Hide()
        end)
        row.hover = row:CreateTexture(nil, "HIGHLIGHT")
        row.hover:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.hover:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.hover:SetColorTexture(1.00, 0.82, 0.24, PIN_HOVER_ALPHA)
        row.hover:Hide()
        p.rows[i] = row
    end
    return p.rows[i]
end

function EL:RefreshPanel()
    local p = self.panel
    if not p then return end
    local threshold = self.db and self.db.settings and self.db.settings.alerts and self.db.settings.alerts.concentrationThreshold or 360
    local mulchReady = self.GetMulchReadyCount and self:GetMulchReadyCount() or 0
    local concReady, concSoon = 0, 0
    local nowForSummary = time()
    local soonFloor = math.max(0, math.floor((tonumber(threshold) or 360) * 0.80 + 0.5))
    local charSummary = {}
    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        local charKey = data and data.charKey
        if charKey and not self:IsCharacterHidden(charKey) then
            local summary = charSummary[charKey]
            if not summary then
                local char = self.db and self.db.characters and self.db.characters[charKey]
                summary = { name = (char and (char.name or char.displayName)) or data.charName or "Unknown", ready = false, soon = false }
                charSummary[charKey] = summary
            end
            local qty = self:GetEstimatedConcentration(data, nowForSummary) or 0
            if qty >= threshold then
                summary.ready = true
            else
                if qty >= soonFloor then summary.soon = true end
            end
        end
    end
    for _, summary in pairs(charSummary) do
        if summary.ready then
            concReady = concReady + 1
        elseif summary.soon then
            concSoon = concSoon + 1
        end
    end
    if p.summary then
        if IsCompactModeEnabled() then
            p.summary:SetText("")
            p.summary:Hide()
        else
            p.summary:SetText(string.format("Ready: %d | Soon: %d | Mulch: %d", concReady, concSoon, mulchReady))
            p.summary:SetTextColor(0.82, 0.80, 0.72)
            p.summary:Show()
        end
    end
    local hiddenCount = 0
    for _, hidden in pairs(self.db and self.db.settings and self.db.settings.hiddenCharacters or {}) do
        if hidden then hiddenCount = hiddenCount + 1 end
    end
    if p.restore then
        p.restore:SetShown(hiddenCount > 0)
        p.restore:SetText(hiddenCount > 0 and ("Restore (" .. hiddenCount .. ")") or "Restore")
    end

    local now = time()
    local allRows = self:GetCharacterRows()
    local rows = {}
    local display = self.db and self.db.settings and self.db.settings.display or {}
    local attentionOnly = display.attentionOnly == true
    local visibleRowCount = 0
    local hiddenRowCount = 0
    for _, entry in ipairs(allRows) do
        if entry and entry.key then
            if self:IsCharacterHidden(entry.key) then
                hiddenRowCount = hiddenRowCount + 1
            else
                visibleRowCount = visibleRowCount + 1
                if not attentionOnly or (self.DoesCharacterNeedAttention and self:DoesCharacterNeedAttention(entry.key, threshold, now)) then
                    table.insert(rows, entry)
                end
            end
        end
    end
    local concentrationLookup = {}
    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        local charKey = data and data.charKey
        if charKey then
            local lookup = concentrationLookup[charKey]
            if not lookup then
                lookup = { entries = {}, readyCount = 0, best = nil, bestQty = nil }
                concentrationLookup[charKey] = lookup
            end
            table.insert(lookup.entries, data)
            local qty = self:GetEstimatedConcentration(data, now) or 0
            if qty >= threshold then lookup.readyCount = lookup.readyCount + 1 end
            if not lookup.best or qty > (lookup.bestQty or -1) then
                lookup.best = data
                lookup.bestQty = qty
            end
        end
    end
    for _, lookup in pairs(concentrationLookup) do
        table.sort(lookup.entries, SortDashboardConcentrationEntries)
    end

    local professionLookup = {}
    for charKey, stored in pairs(self.db and self.db.resources and self.db.resources.professions or {}) do
        if type(stored) == "table" then
            local list = {}
            for _, data in ipairs(stored) do
                if type(data) == "table" and (data.professionName or data.professionID or data.skillLineID) then
                    table.insert(list, data)
                end
            end
            if #list > 0 then
                table.sort(list, SortDashboardProfessionEntries)
                professionLookup[charKey] = list
            end
        end
    end

    local dashboardLookups = { concentrationLookup = concentrationLookup, professionLookup = professionLookup }
    self:SortDashboardRows(rows, dashboardLookups)
    self:UpdateSortHeaders()
    local rowH, gap = GetTrackingRowHeight(), 0
    local width = math.max(1, p.scroll and p.scroll:GetWidth() or p:GetWidth() - 40)
    local cols = GetColumnLayout(width)
    p.content:SetWidth(width)
    local visible = {}
    for _, def in ipairs(cols.columns or {}) do visible[def.key] = true end

    local currentCharKey = self.GetCharacterKey and self:GetCharacterKey() or nil
    local highlightCurrent = display.highlightCurrentCharacter ~= false

    for i, entry in ipairs(rows) do
        local row = self:GetRow(i)
        row:SetHeight(rowH)
        ApplyTrackingTextStyle(row)
        local charKey, char = entry.key, entry.char
        local concLookup = concentrationLookup[charKey]
        local concEntries = concLookup and concLookup.entries or {}
        local profEntries = professionLookup[charKey]
        if (not profEntries or #profEntries == 0) and concEntries then
            profEntries = concEntries
        end
        local slots = self:GetDashboardProfessionSlots(charKey, profEntries, concEntries)
        local profData1, concData1 = slots[1] and slots[1].prof or nil, slots[1] and slots[1].conc or nil
        local profData2, concData2 = slots[2] and slots[2].prof or nil, slots[2] and slots[2].conc or nil
        local moxieEntries = self:GetMoxieEntriesForCharacter(charKey, profEntries)
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
        local profValue1 = "N/A"
        local concValue1 = "N/A"
        local profValue2 = "N/A"
        local concValue2 = "N/A"
        if profData1 then
            profValue1 = self:GetProfessionAbbreviation(profData1)
        end
        if concData1 then
            local q = self:GetEstimatedConcentration(concData1, now) or 0
            concValue1 = tostring(q) .. "/" .. tostring(concData1.maxQuantity or self.CONCENTRATION_MAX_DEFAULT)
        end
        if profData2 then
            profValue2 = self:GetProfessionAbbreviation(profData2)
        end
        if concData2 then
            local q = self:GetEstimatedConcentration(concData2, now) or 0
            concValue2 = tostring(q) .. "/" .. tostring(concData2.maxQuantity or self.CONCENTRATION_MAX_DEFAULT)
        end
        local forecastValue = "N/A"
        local forecastData = concLookup and concLookup.best or nil
        local readyConcentrationCount = concLookup and concLookup.readyCount or 0
        if forecastData and self.GetConcentrationForecastText then
            forecastValue = self:GetConcentrationForecastText(forecastData, threshold, now)
            if readyConcentrationCount > 1 and forecastValue == "Ready" then
                forecastValue = tostring(readyConcentrationCount) .. "x Ready"
            end
        end
        local mulchValue = "N/A"
        if self:HasImbuedMulchAccess(mulchData) then
            local remain = math.max(0, (tonumber(mulchData.readyAt) or 0) - now)
            mulchValue = remain <= 0 and (READY_ICON .. " Ready") or self:FormatCountdown(remain)
        end

        local profIcon1 = profData1 and self:GetProfessionIconTexture(profData1) or nil
        local profIcon2 = profData2 and self:GetProfessionIconTexture(profData2) or nil
        local layoutKey = table.concat({
            tostring(width), tostring(rowH), tostring(cols.nameX), tostring(cols.nameW),
            tostring(cols.prof1X), tostring(cols.prof1W), tostring(cols.conc1X), tostring(cols.conc1W),
            tostring(cols.prof2X), tostring(cols.prof2W), tostring(cols.conc2X), tostring(cols.conc2W),
            tostring(cols.moxieX), tostring(cols.moxieW), tostring(cols.forecastX), tostring(cols.forecastW),
            tostring(cols.cooldownX), tostring(cols.cooldownW), tostring(cols.mulchX), tostring(cols.mulchW), tostring(visible.prof1), tostring(visible.prof2),
            tostring(visible.conc1), tostring(visible.conc2), tostring(visible.moxie), tostring(visible.forecast), tostring(visible.cooldown), tostring(visible.mulch),
            tostring(profIcon1), tostring(profIcon2)
        }, ":")
        if row._emberLayoutKey ~= layoutKey then
            row:SetWidth(width)
            row:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -((i - 1) * (rowH + gap)))
            AnchorColumnText(row.name, row, cols.nameX, cols.nameW, "LEFT")
            AnchorColumnText(row.conc1, row, cols.conc1X, cols.conc1W, "CENTER")
            AnchorColumnText(row.conc2, row, cols.conc2X, cols.conc2W, "CENTER")
            AnchorMoxieCell(row, row, cols.moxieX, math.max(1, cols.moxieW))
            AnchorColumnText(row.forecast, row, cols.forecastX, math.max(1, cols.forecastW), "CENTER")
            AnchorColumnText(row.cooldown, row, cols.cooldownX, math.max(1, cols.cooldownW), "CENTER")
            AnchorColumnText(row.mulch, row, cols.mulchX, math.max(1, cols.mulchW), "CENTER")
            AnchorProfessionCell(row, row.prof1, row.prof1Icon, cols.prof1X, cols.prof1W, visible.prof1, profIcon1)
            AnchorProfessionCell(row, row.prof2, row.prof2Icon, cols.prof2X, cols.prof2W, visible.prof2, profIcon2)
            row._emberLayoutKey = layoutKey
        end
        row.prof1:SetShown(visible.prof1 and not row.prof1._emberHasProfessionIcon)
        row.conc1:SetShown(visible.conc1 and true or false)
        row.prof2:SetShown(visible.prof2 and not row.prof2._emberHasProfessionIcon)
        row.conc2:SetShown(visible.conc2 and true or false)
        SetMoxieCellShown(row, visible.moxie and true or false, row._emberMoxieSplit)
        row.forecast:SetShown(visible.forecast and true or false)
        row.cooldown:SetShown(visible.cooldown and true or false)
        row.mulch:SetShown(visible.mulch and true or false)

        row.charKey = charKey
        row.concData = concData1
        row.forecastData = forecastData
        row.concEntries = concEntries
        row.profEntries = profEntries
        row.cooldownEntries = cooldownSummary and cooldownSummary.entries or nil
        row.moxieEntries = moxieEntries
        row.mulchData = mulchData
        row.name:SetText(self:GetCharacterDisplayName(char, charKey))
        local r, g, b = self:GetClassColor(char.class)
        row.name:SetTextColor(r, g, b)
        local isPinned = self:IsCharacterPinned(charKey)
        local isCurrentCharacter = highlightCurrent and currentCharKey and charKey == currentCharKey
        row.isCurrentCharacter = isCurrentCharacter and true or false
        if row.currentHighlight then
            row.currentHighlight:SetShown(isCurrentCharacter and true or false)
            if isCurrentCharacter then
                row.currentHighlight:SetColorTexture(1.00, 0.78, 0.24, IsCompactModeEnabled() and 0.13 or 0.16)
            end
        end
        for _, line in ipairs({ row.currentHighlightTop, row.currentHighlightBottom, row.currentHighlightLeft, row.currentHighlightRight }) do
            if line then
                line:SetShown(isCurrentCharacter and true or false)
                if isCurrentCharacter then line:SetColorTexture(1.00, 0.84, 0.32, 0.42) end
            end
        end
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
        row.prof1:SetText(profValue1)
        row.prof1:SetTextColor(0.88, 0.86, 0.76)
        row.prof2:SetText(profValue2)
        row.prof2:SetTextColor(0.88, 0.86, 0.76)
        row.conc1:SetText(concValue1)
        if concData1 then
            local cq = self:GetEstimatedConcentration(concData1, now) or 0
            local cr, cg, cb = self:GetConcentrationColor(cq, concData1.maxQuantity or self.CONCENTRATION_MAX_DEFAULT)
            row.conc1:SetTextColor(cr, cg, cb)
        else
            row.conc1:SetTextColor(0.7, 0.7, 0.7)
        end
        row.conc2:SetText(concValue2)
        if concData2 then
            local cq = self:GetEstimatedConcentration(concData2, now) or 0
            local cr, cg, cb = self:GetConcentrationColor(cq, concData2.maxQuantity or self.CONCENTRATION_MAX_DEFAULT)
            row.conc2:SetTextColor(cr, cg, cb)
        else
            row.conc2:SetTextColor(0.7, 0.7, 0.7)
        end
        if row.full then row.full:Hide() end
        local moxieValues = GetMoxieDisplayValues(charKey, slots)
        local moxieValue = #moxieValues > 0 and table.concat(moxieValues, " • ") or "N/A"
        local useSplitMoxie = visible.moxie and #moxieValues == 2
        row._emberMoxieSplit = useSplitMoxie and true or false
        row.moxie:SetText(moxieValue)
        if row.moxieLeft then row.moxieLeft:SetText(moxieValues[1] or "") end
        if row.moxieSep then row.moxieSep:SetText("•") end
        if row.moxieRight then row.moxieRight:SetText(moxieValues[2] or "") end
        SetMoxieCellShown(row, visible.moxie and true or false, useSplitMoxie)
        if moxieValue ~= "N/A" then
            if self.HasMoxieAtThreshold and self:HasMoxieAtThreshold(charKey, moxieEntries) then
                SetMoxieCellColor(row, 0.35, 1.00, 0.45)
            else
                SetMoxieCellColor(row, 0.88, 0.84, 0.74)
            end
        else
            SetMoxieCellColor(row, 0.70, 0.70, 0.70)
        end
        row.forecast:SetText(forecastValue)
        if forecastValue == "Ready" or forecastValue:match("^%d+x Ready$") then
            row.forecast:SetTextColor(0.35, 1.00, 0.45)
        else
            row.forecast:SetTextColor(0.70, 0.70, 0.70)
        end
        row.cooldown:SetText(cooldownValue or "-")
        if cooldownSummary and cooldownSummary.ready and cooldownSummary.ready > 0 then
            row.cooldown:SetTextColor(0.35, 1.00, 0.45)
        elseif cooldownSummary and cooldownSummary.tracked and cooldownSummary.tracked > 0 then
            row.cooldown:SetTextColor(1.00, 0.82, 0.32)
        else
            row.cooldown:SetTextColor(0.70, 0.70, 0.70)
        end
        row.mulch:SetText(mulchValue)
        if self:HasImbuedMulchAccess(mulchData) then
            local remain = math.max(0, (tonumber(mulchData.readyAt) or 0) - now)
            local mr, mg, mb = self:GetMulchCountdownColor(remain)
            row.mulch:SetTextColor(mr, mg, mb)
        else
            row.mulch:SetTextColor(0.7, 0.7, 0.7)
        end
        local stripe = (i % 2 == 0) and 0.030 or 0
        row.bg:SetColorTexture(0.10 + stripe, 0.10 + stripe, 0.115 + stripe, IsCompactModeEnabled() and ROW_STRIPE_ALPHA_COMPACT or ROW_STRIPE_ALPHA)
        row:Show()
    end
    for i = #rows + 1, #p.rows do
        p.rows[i]:Hide()
    end
    if p.empty then
        p.empty:ClearAllPoints()
        p.empty:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 12, -34)
        p.empty:SetPoint("TOPRIGHT", p.header, "BOTTOMRIGHT", -12, -34)
        p.empty:SetHeight(IsCompactModeEnabled() and 48 or 62)
        if p.empty.SetWidth then p.empty:SetWidth(math.max(1, (p.header:GetWidth() or width) - 24)) end

        local emptyText
        if #allRows == 0 then
            emptyText = "No tracked characters yet.\nOpen a profession window on each character to begin tracking."
        elseif visibleRowCount == 0 and hiddenRowCount > 0 then
            emptyText = "All tracked characters are hidden.\nUse EmberLedger Settings to restore hidden characters."
        elseif attentionOnly then
            emptyText = "No characters currently need attention.\nTurn off Attention Only view to see all tracked characters."
        else
            emptyText = "No visible character data.\nOpen a profession window to refresh tracking."
        end
        p.empty:SetText(emptyText)
        p.empty:SetShown(#rows == 0)
    end
    p.content:SetHeight(math.max(40, #rows * (rowH + gap)))
    if self.AutoSizeTrackingPanel and not p._emberVerticalResizing then self:AutoSizeTrackingPanel("refresh") end
end

function EL:UpdateButton()
    local b = self.button
    if not b then return end
    local display = self.db and self.db.settings and self.db.settings.display or {}
    local threshold = self.db and self.db.settings and self.db.settings.alerts and self.db.settings.alerts.concentrationThreshold or 360
    local concReady = self:GetConcentrationReadyCount(threshold)
    local mulchReady = self:GetMulchReadyCount()
    local nextMulch = self:GetNextMulchSummary()
    ApplyFrameOpacity(b, GetLauncherOpacity())

    if b.title then
        b.title:SetText("EmberLedger")
        b.title:SetTextColor(1.00, 0.82, 0.24)
        b.title:SetJustifyH("CENTER")
        b.title:SetShadowColor(0.00, 0.00, 0.00, 0.95)
        b.title:SetShadowOffset(1, -1)
    end

    local topParts = {}
    if display.showLauncherConc ~= false then
        topParts[#topParts + 1] = "Conc " .. tostring(concReady or 0)
    end
    if display.showLauncherMulch ~= false then
        if mulchReady and mulchReady > 0 then
            topParts[#topParts + 1] = "Mulch " .. tostring(mulchReady)
        elseif nextMulch and nextMulch.remaining then
            topParts[#topParts + 1] = "Mulch " .. self:FormatCountdown(nextMulch.remaining)
        else
            topParts[#topParts + 1] = "Mulch N/A"
        end
    end

    if b.line1 then
        if #topParts > 0 then
            b.line1:SetText(table.concat(topParts, "  |  "))
            if (concReady and concReady > 0) or (mulchReady and mulchReady > 0) then
                b.line1:SetTextColor(0.35, 1.00, 0.35)
            else
                b.line1:SetTextColor(0.86, 0.84, 0.76)
            end
            b.line1:Show()
        else
            b.line1:SetText("")
            b.line1:Hide()
        end
    end

    local sessionEnabled = not self.IsSessionTrackingEnabled or self:IsSessionTrackingEnabled()
    local bottomParts = {}
    if sessionEnabled and display.showLauncherSession ~= false then
        bottomParts[#bottomParts + 1] = self:FormatMoneyRateText(self:GetSessionGoldPerHour()) .. "/hr"
    end
    if sessionEnabled and display.showLauncherSessionTime ~= false then
        bottomParts[#bottomParts + 1] = FormatSessionTime(self:GetSessionElapsedSeconds())
    end
    if sessionEnabled and display.showLauncherSessionTotal ~= false and display.showLauncherSessionTime == false then
        local sdb = self.GetSessionDB and self:GetSessionDB() or {}
        bottomParts[#bottomParts + 1] = self:FormatMoneyText(sdb.totalSilver or 0) .. " total"
    end

    if b.line2 then
        if #bottomParts > 0 then
            b.line2:SetText(table.concat(bottomParts, "  |  "))
            b.line2:SetTextColor(0.78, 0.78, 0.72)
            b.line2:Show()
        else
            b.line2:SetText("")
            b.line2:Hide()
        end
    end

    for _, line in ipairs({ b.line3, b.line4, b.line5 }) do
        if line then
            line:SetText("")
            line:Hide()
        end
    end

    local orderedLines = { b.line1, b.line2 }
    local previous = b.title
    local shownLineCount = 0
    for _, line in ipairs(orderedLines) do
        if line then
            line:ClearAllPoints()
            if line:IsShown() then
                local yGap = shownLineCount == 0 and -6 or -3
                line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, yGap)
                line:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, yGap)
                previous = line
                shownLineCount = shownLineCount + 1
            end
        end
    end

    local textW = math.max(GetTextWidth(b.title), GetTextWidth(b.line1), GetTextWidth(b.line2))
    local targetW = math.ceil(math.max(142, textW + 28))
    local targetH = math.max(50, 28 + (shownLineCount * 14))
    if math.abs((b:GetWidth() or 0) - targetW) > 2 or math.abs((b:GetHeight() or 0) - targetH) > 2 then
        b:SetSize(targetW, targetH)
    end
end

function EL:ApplyPanelScale()
    if not self.panel then return end
    local scale = tonumber(self.db.settings.panel.scale) or 1
    scale = math.max(PANEL_MIN_SCALE, math.min(PANEL_MAX_SCALE, scale))
    self.db.settings.panel.scale = scale
    self.panel:SetScale(scale)
end

function EL:AdjustPanelScale(delta)
    local current = tonumber(self.db.settings.panel.scale) or 1
    self.db.settings.panel.scale = math.max(PANEL_MIN_SCALE, math.min(PANEL_MAX_SCALE, current + (delta or 0)))
    self:ApplyPanelScale()
    self:Print("Window scale: " .. string.format("%.2f", self.db.settings.panel.scale))
end

function EL:ShowPanelFromSavedState()
    if not self.panel then return end
    if not self.db.settings.panel.detached and self.button then
        self.panel:ClearAllPoints()
        self.panel:SetPoint("TOPLEFT", self.button, "BOTTOMLEFT", 0, -8)
    else
        SetFramePointFromDB(self.panel, self.db.settings.panel)
    end
    self:ApplyPanelScale()
    self:RefreshPanel()
    self.panel:Show()
    BringEmberWindowToFront(self.panel)
    if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
end

function EL:ToggleMainPanel()
    if not self.panel then return end
    if self.panel:IsShown() then
        self.panel:Hide()
        if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
        return
    end
    self:ShowPanelFromSavedState()
end

function EL:TogglePanel()
    self:ToggleMainPanel()
end

function EL:ToggleAllWindows()
    local mainShown = self.panel and self.panel:IsShown()
    local sessionShown = self.sessionWindow and self.sessionWindow:IsShown()
    if mainShown or sessionShown then
        if mainShown and self.panel then
            self._suppressPanelWindowHideSetting = true
            self.panel:Hide()
            self._suppressPanelWindowHideSetting = false
            if self.db and self.db.settings and self.db.settings.panel then
                self.db.settings.panel.charactersShown = true
                self.db.settings.panel.windowOpen = true
            end
        end
        if sessionShown and self.sessionWindow then
            self._suppressSessionWindowHideSetting = true
            self.sessionWindow:Hide()
            self._suppressSessionWindowHideSetting = false
            if self.db and self.db.settings and self.db.settings.session then
                self.db.settings.session.shown = true
                self.db.settings.session.windowOpen = true
            end
        end
        if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
        return
    end
    if self.db and self.db.settings then
        if self.db.settings.panel and self.db.settings.panel.charactersShown ~= false and self.ShowPanelFromSavedState then
            self:ShowPanelFromSavedState()
        end
        if self.db.settings.session and self.db.settings.session.shown ~= false and self.ShowSessionWindowFromSavedState then
            self:ShowSessionWindowFromSavedState()
        end
    end
end

function EL:ToggleLauncherLock()
    local s = self.db.settings.button
    s.locked = not s.locked
    self:Print("Launcher " .. (s.locked and "locked. Hold Shift and drag to move it." or "unlocked."))
end

function EL:ResetWindowPositions()
    local settings = self.db and self.db.settings
    if not settings then return end

    settings.button = settings.button or {}
    settings.panel = settings.panel or {}
    settings.session = settings.session or {}
    settings.options = settings.options or {}

    settings.button.point = "CENTER"
    settings.button.relativePoint = "CENTER"
    settings.button.x = 0
    settings.button.y = 120

    settings.panel.point = "CENTER"
    settings.panel.relativePoint = "CENTER"
    settings.panel.x = 0
    settings.panel.y = 0
    settings.panel.detached = true

    settings.session.point = "CENTER"
    settings.session.relativePoint = "CENTER"
    settings.session.x = 260
    settings.session.y = 0

    settings.options.point = "CENTER"
    settings.options.relativePoint = "CENTER"
    settings.options.x = 0
    settings.options.y = 0

    if self.button then SetFramePointFromDB(self.button, settings.button) end
    if self.panel then SetFramePointFromDB(self.panel, settings.panel) end
    if self.sessionWindow then SetFramePointFromDB(self.sessionWindow, settings.session) end
    if self.settingsPanel and self.settingsPanel:IsShown() then
        SetFramePointFromDB(self.settingsPanel, settings.options)
    end

    if self.RefreshLayout then self:RefreshLayout("resetPositions") end
    self:Print("Window positions reset.")
end

function EL:ShowButtonTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("EmberLedger", 1, 0.82, 0.24)
    GameTooltip:AddLine("Quick launcher and window toggle.", 0.86, 0.86, 0.78, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: show, hide, or restore EmberLedger windows", 0.72, 0.72, 0.72)
    GameTooltip:AddLine("Right-click: lock or unlock launcher", 0.72, 0.72, 0.72)
    GameTooltip:AddLine("Shift-drag: move while locked", 0.72, 0.72, 0.72)
    GameTooltip:Show()
end

local function FormatTooltipDate(timestamp)
    timestamp = tonumber(timestamp) or 0
    if timestamp <= 0 then return "Unknown" end
    return date("%b %d, %I:%M %p", timestamp)
end

local function FormatTooltipAgo(timestamp)
    timestamp = tonumber(timestamp) or 0
    if timestamp <= 0 then return "Unknown" end
    local elapsed = math.max(0, time() - timestamp)
    if elapsed < 60 then return "just now" end
    if elapsed < 3600 then return string.format("%dm ago", math.floor(elapsed / 60)) end
    if elapsed < 86400 then return string.format("%dh %02dm ago", math.floor(elapsed / 3600), math.floor((elapsed % 3600) / 60)) end
    return string.format("%dd ago", math.floor(elapsed / 86400))
end

function EL:ShowRowTooltip(row)
    if not row then return end
    local char = self.db and self.db.characters and self.db.characters[row.charKey or ""]
    local displayName = self:GetCharacterDisplayName(char, row.charKey or "Character")
    local r, g, b = self:GetClassColor(char and char.class)
    local threshold = self.db and self.db.settings and self.db.settings.alerts and self.db.settings.alerts.concentrationThreshold or 360
    local now = time()

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(displayName, r, g, b)

    GameTooltip:AddDoubleLine("Realm", (char and char.realm) or "Unknown", 0.82, 0.80, 0.72, 1, 1, 1)
    GameTooltip:AddDoubleLine("Last seen", FormatTooltipAgo(char and char.lastSeen), 0.82, 0.80, 0.72, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Professions", 0.62, 0.78, 0.92)
    if row.profEntries and #row.profEntries > 0 then
        for i, prof in ipairs(row.profEntries) do
            local profName = self:GetCleanProfessionName(prof.professionName)
            local abbrev = self:GetProfessionAbbreviation(prof)
            local conc = self:GetConcentrationEntryForProfession(row.charKey, prof)
            GameTooltip:AddDoubleLine(string.format("%d. %s", i, profName), abbrev, 0.62, 0.78, 0.92, 1, 1, 1)
            if conc then
                local quantity = tonumber(self:GetEstimatedConcentration(conc, now)) or 0
                local maxQuantity = tonumber(conc.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
                GameTooltip:AddDoubleLine("   Concentration", string.format("%d/%d", quantity, maxQuantity), 0.72, 0.72, 0.72, 1, 1, 1)
                if quantity >= maxQuantity then
                    GameTooltip:AddDoubleLine("   Full", "Now", 0.72, 0.72, 0.72, 1, 1, 1)
                elseif quantity >= threshold then
                    GameTooltip:AddDoubleLine("   Ready", "Now", 0.35, 1.00, 0.45, 0.35, 1.00, 0.45)
                    GameTooltip:AddDoubleLine("   Full in", self:GetConcentrationFullIn(conc, now) or "Unknown", 0.72, 0.72, 0.72, 1, 1, 1)
                else
                    local rate = tonumber(self.CONCENTRATION_RATE_PER_HOUR) or 10
                    local readySeconds = math.ceil(math.max(0, threshold - quantity) / rate * 3600)
                    GameTooltip:AddDoubleLine("   Ready at", FormatTooltipDate(now + readySeconds), 0.72, 0.72, 0.72, 1, 1, 1)
                    GameTooltip:AddDoubleLine("   Full in", self:GetConcentrationFullIn(conc, now) or "Unknown", 0.72, 0.72, 0.72, 1, 1, 1)
                end
            else
                GameTooltip:AddLine("   Concentration: not tracked", 0.70, 0.70, 0.70)
            end
            local moxie = self:GetMoxieEntryForProfession(row.charKey, prof)
            if moxie and type(moxie.quantity) == "number" then
                local threshold = self.GetMoxieThreshold and self:GetMoxieThreshold() or 600
                local ready = tonumber(moxie.quantity) and tonumber(moxie.quantity) >= threshold
                GameTooltip:AddDoubleLine("   Moxie", tostring(moxie.quantity), 0.72, 0.72, 0.72, ready and 0.35 or 1, ready and 1 or 1, ready and 0.45 or 1)
            end
        end
    elseif row.concEntries and #row.concEntries > 0 then
        for i, data in ipairs(row.concEntries) do
            local profName = self:GetCleanProfessionName(data.professionName)
            local abbrev = self:GetProfessionAbbreviation(data)
            local quantity = tonumber(self:GetEstimatedConcentration(data, now)) or 0
            local maxQuantity = tonumber(data.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
            GameTooltip:AddDoubleLine(string.format("%d. %s", i, profName), abbrev, 0.62, 0.78, 0.92, 1, 1, 1)
            GameTooltip:AddDoubleLine("   Concentration", string.format("%d/%d", quantity, maxQuantity), 0.72, 0.72, 0.72, 1, 1, 1)
        end
    else
        GameTooltip:AddLine("No professions tracked yet.", 0.7, 0.7, 0.7)
    end

    if type(self.AddProfessionCooldownTooltipLines) == "function" then
        local ok, err = pcall(self.AddProfessionCooldownTooltipLines, self, GameTooltip, row.charKey, row.profEntries)
        if not ok and self.db and self.db.settings and self.db.settings.debug and self.Print then
            self:Print("Cooldown tooltip unavailable: " .. tostring(err))
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Imbued Mulch", 0.95, 0.62, 0.26)
    if self:HasImbuedMulchAccess(row.mulchData) then
        local readyAt = tonumber(row.mulchData.readyAt) or 0
        local remain = math.max(0, readyAt - now)
        GameTooltip:AddDoubleLine("Ready at", remain <= 0 and "Now" or FormatTooltipDate(readyAt), 0.72, 0.72, 0.72, 1, 1, 1)
        GameTooltip:AddDoubleLine("In bags", tostring(row.mulchData.itemCount or 0), 0.72, 0.72, 0.72, 1, 1, 1)
    else
        GameTooltip:AddLine("No Imbued Mulch data tracked.", 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(" ")
    if row.isCurrentCharacter then
        GameTooltip:AddLine("Current character", 0.95, 0.82, 0.38)
    end
    if self:IsCharacterPinned(row.charKey) then
        GameTooltip:AddLine("Pinned", 0.95, 0.82, 0.38)
    end
    GameTooltip:AddLine((self:IsCharacterPinned(row.charKey) and "Alt-click: unpin" or "Alt-click: pin") .. " | Right-click: hide", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Shift-right-click: reset this character", 0.95, 0.62, 0.26)
    GameTooltip:Show()
end
