local addonName, EL = ...

local CreateFrame = _G.CreateFrame
local IsShiftKeyDown = _G.IsShiftKeyDown
local UIParent = _G.UIParent

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
local SESSION_HISTORY_ROWS = UIC.SESSION_HISTORY_ROWS or 8
local SESSION_ITEM_ROW_H = UIC.SESSION_ITEM_ROW_H or 18
local PANEL_DEFAULT_VISIBLE_ROWS = UIC.PANEL_DEFAULT_VISIBLE_ROWS or 12
local TRACKING_ROW_H = UIC.TRACKING_ROW_H or 23
local TRACKING_COMPACT_ROW_H = UIC.TRACKING_COMPACT_ROW_H or 18
local TRACKING_EMPTY_BODY_H = 28
local TRACKING_COMPACT_EMPTY_BODY_H = 24
local PANEL_EXPANDED_MIN_H = UIC.PANEL_EXPANDED_MIN_H or 300
local PANEL_MAX_W = UIC.PANEL_MAX_W or 900
local PANEL_MAX_H = UIC.PANEL_MAX_H or 1600
local PANEL_SCREEN_MARGIN = 18
local PANEL_MIN_SCALE = UIC.PANEL_MIN_SCALE or 0.6
local PANEL_MAX_SCALE = UIC.PANEL_MAX_SCALE or 1.4
local READY_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local CD_READY_ICON_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Check"
local CD_READY_ICON_R, CD_READY_ICON_G, CD_READY_ICON_B = 1.00, 0.82, 0.25
local PIN_GLOW_R, PIN_GLOW_G, PIN_GLOW_B = 0.70, 0.78, 0.88
local PIN_GLOW_ALPHA = 0.060
local PIN_ACCENT_ALPHA = 0.20
local PIN_HOVER_ALPHA = 0.070
local TRACKING_ROW_PALETTE = EL.Style and EL.Style.GetTrackingRowPalette and EL.Style:GetTrackingRowPalette() or {}
local CURRENT_ROW_R, CURRENT_ROW_G, CURRENT_ROW_B = TRACKING_ROW_PALETTE.currentR or 0.42, TRACKING_ROW_PALETTE.currentG or 0.68, TRACKING_ROW_PALETTE.currentB or 1.00
local CURRENT_ROW_BG_ALPHA = TRACKING_ROW_PALETTE.currentBgAlpha or 0.145
local CURRENT_ROW_BG_ALPHA_COMPACT = TRACKING_ROW_PALETTE.currentBgAlphaCompact or 0.125
local CURRENT_ROW_LINE_ALPHA = TRACKING_ROW_PALETTE.currentLineAlpha or 0.44
local CURRENT_ROW_EDGE_ALPHA = TRACKING_ROW_PALETTE.currentEdgeAlpha or 0.70
local TRACKING_ROW_HOVER_R, TRACKING_ROW_HOVER_G, TRACKING_ROW_HOVER_B = TRACKING_ROW_PALETTE.hoverR or 0.50, TRACKING_ROW_PALETTE.hoverG or 0.66, TRACKING_ROW_PALETTE.hoverB or 0.88
local TRACKING_ROW_HOVER_ALPHA = TRACKING_ROW_PALETTE.hoverAlpha or 0.075
local TRACKING_CURRENT_ROW_HOVER_ALPHA = TRACKING_ROW_PALETTE.currentHoverAlpha or 0.115
local THEME = EL.THEME_COLORS or {}
local BORDER_R, BORDER_G, BORDER_B = THEME.BORDER_R or 0.42, THEME.BORDER_G or 0.42, THEME.BORDER_B or 0.44
local BORDER_ALPHA_STRONG = 0.78
local BORDER_ALPHA_SOFT = 0.52
local EL_BG_R, EL_BG_G, EL_BG_B = THEME.BG_R or 0.000, THEME.BG_G or 0.000, THEME.BG_B or 0.000
local EL_HEADER_R, EL_HEADER_G, EL_HEADER_B = 0.030, 0.024, 0.070
local HEADER_LINE_ALPHA_TOP = 0.16
local HEADER_LINE_ALPHA_BOTTOM = 0.30
local ROW_STRIPE_ALPHA = 0.32
local ROW_STRIPE_ALPHA_COMPACT = 0.28
local ROW_SEPARATOR_ALPHA = 0.18

local ThemeColor, ThemeAccentRGB, ThemeBorderRGB, ThemeTextRGB, ThemeMutedTextRGB, ThemeValueTextRGB, RegisterThemeText, ApplyThemeTextCollections

local function T(key, ...)
    if EL and EL.T then return EL:T(key, ...) end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, tostring(key), ...)
        if ok then return formatted end
    end
    return tostring(key)
end


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


--[[
Tracking Row Ownership

TrackingRows.lua owns tracker row creation, cell rendering, column anchoring,
hover state, and current-character highlighting. UI.lua keeps the main tracker
frame, sizing/layout orchestration, session windows, launcher-facing window
toggles, and shared visual helpers used by multiple modules.

Keep row-specific changes inside Modules/TrackingRows.lua unless they affect
main frame sizing or global layout orchestration.
]]

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
    if EL.GetTrackingRowHeight then
        local ok, value = pcall(EL.GetTrackingRowHeight, EL)
        if ok and tonumber(value) then return tonumber(value) end
    end
    return IsCompactModeEnabled() and TRACKING_COMPACT_ROW_H or TRACKING_ROW_H
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
    -- Keep one compact footer area in both anchored and floating modes. This
    -- prevents the resize grip from looking detached while avoiding the overly
    -- tall empty tray used by older layouts.
    return actionBarShown and (GetTrackingActionBarBottomOffset() + ACTION_BAR_H + 5) or 41
end

local function GetTrackingEmptyBodyHeight()
    return IsCompactModeEnabled() and TRACKING_COMPACT_EMPTY_BODY_H or TRACKING_EMPTY_BODY_H
end

local function SetFontStringTextIfChanged(fs, text)
    if not fs then return end
    text = text == nil and "" or tostring(text)
    if fs._emberLastText ~= text then
        fs._emberLastText = text
        fs:SetText(text)
    end
end

local function ApplyTrackingTextStyle(row)
    if not row then return end
    local fontObject = IsCompactModeEnabled() and GameFontHighlightSmall or GameFontHighlight
    for _, fs in ipairs({row.name, row.prof1, row.conc1, row.prof2, row.conc2, row.moxie, row.moxieLeft, row.moxieSep, row.moxieRight, row.forecast, row.cooldown, row.mulch}) do
        if fs and fs.SetFontObject then fs:SetFontObject(fontObject) end
    end
end


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
    relativeTo = relativeTo or UIParent

    frame:ClearAllPoints()
    local ok = pcall(frame.SetPoint, frame, point, relativeTo, relativePoint, x, y)
    if ok then return true end

    -- Anchor-family conflicts can happen if another frame was reparented or a
    -- stale restore target creates a circular relationship. Fall back to
    -- UIParent so the window remains usable instead of throwing a Lua error.
    frame:ClearAllPoints()
    pcall(frame.SetPoint, frame, "CENTER", UIParent, "CENTER", 0, 0)
    return false
end


local function IsFrameMostlyOnScreen(frame)
    if not frame or not frame.GetLeft then return true end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return true end
    local screenW = UIParent and UIParent.GetWidth and UIParent:GetWidth() or GetScreenWidth and GetScreenWidth() or 0
    local screenH = UIParent and UIParent.GetHeight and UIParent:GetHeight() or GetScreenHeight and GetScreenHeight() or 0
    if screenW <= 0 or screenH <= 0 then return true end
    return right >= 24 and left <= (screenW - 24) and top >= 24 and bottom <= (screenH - 24)
end

local function EnsureFrameOnScreen(frame, pos)
    if not frame then return end
    if IsFrameMostlyOnScreen(frame) then return end
    if type(pos) == "table" then
        pos.point = "CENTER"
        pos.relativePoint = "CENTER"
        pos.x = 0
        pos.y = 0
    end
    SafeSetFramePoint(frame, "CENTER", UIParent, "CENTER", 0, 0)
end

local function SetFramePointFromDB(frame, pos)
    pos = type(pos) == "table" and pos or {}
    SafeSetFramePoint(frame, pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
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

local function AddEmberCornerAccents(frame)
    if EL.Style and EL.Style.AddEmberCornerAccents then return EL.Style:AddEmberCornerAccents(frame) end
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
    -- Empty/Attention Only states intentionally use a shorter body minimum.
    local topPadding = GetTrackingTopPadding()
    local charHeaderH = charShown and (IsCompactModeEnabled() and 28 or 32) or 0
    local charBodyMinH = charShown and GetTrackingEmptyBodyHeight() or 0
    local bottomPadding = GetTrackingBottomPadding(actionBarShown)
    local compactMin = charShown and (IsCompactModeEnabled() and 136 or 160) or 104

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
    local threshold = self:GetConcentrationThreshold()
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

function EL:GetTrackingPanelAutoSize(visibleRowCount)
    local settings = self.db and self.db.settings and self.db.settings.panel or {}
    local charShown = settings.charactersShown ~= false
    local actionBarShown = IsAnchoredActionBarShown()

    local width = (self.GetTrackingPanelMaxWidth and self:GetTrackingPanelMaxWidth()) or PANEL_MIN_W
    local rowCount = 0
    if charShown then
        rowCount = tonumber(visibleRowCount)
        if rowCount == nil then
            rowCount = self:GetVisibleTrackingRowCount()
        end
    end
    local tableBodyH = 0
    if charShown then
        tableBodyH = rowCount > 0 and (rowCount * GetTrackingRowHeight()) or GetTrackingEmptyBodyHeight()
    end

    local topPadding = GetTrackingTopPadding()
    local headerAndGapH = charShown and ((IsCompactModeEnabled() and 28 or 32) + 4) or 0
    local bottomPadding = GetTrackingBottomPadding(actionBarShown)
    local height = topPadding + headerAndGapH + tableBodyH + bottomPadding
    local customHeight = tonumber(settings.customHeight)
    -- Ignore saved manual height in zero-row table states so Attention Only,
    -- all-hidden, and fresh installs can shrink to the safe empty-state size
    -- instead of preserving large dead space from a previous populated view.
    if customHeight and not (charShown and rowCount == 0) then
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
        SafeSetFramePoint(panel, "TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        SaveFramePoint(panel, settings)
    end
    panel._autoSizingPanel = false
    settings.width = targetW
    settings.height = targetH
    settings.customHeight = targetH
    if (EL.GetVisibleTrackingRowCount and EL:GetVisibleTrackingRowCount() or 0) > 0 then
        settings.expandedHeight = targetH
    end
end

local function RestoreSavedTrackingHeightIfNeeded(panel, rowCount)
    local settings = EL and EL.db and EL.db.settings and EL.db.settings.panel
    if not panel or not settings or panel._autoSizingPanel then return end
    if not rowCount or rowCount <= 0 then
        panel._emberRestoredSavedHeightWithRows = false
        return
    end
    if panel._emberRestoredSavedHeightWithRows then return end

    local savedHeight = tonumber(settings.customHeight)
    if not savedHeight then return end

    local targetW = (EL.GetTrackingPanelMaxWidth and EL:GetTrackingPanelMaxWidth()) or (panel:GetWidth() or PANEL_MIN_W)
    local targetH = math.max(GetCurrentPanelMinHeight(panel), math.min(GetTrackingPanelMaxHeight(panel), savedHeight))
    local currentH = panel:GetHeight() or targetH
    if math.abs(currentH - targetH) <= 1 then
        panel._emberRestoredSavedHeightWithRows = true
        return
    end

    local left, top = panel:GetLeft(), panel:GetTop()
    panel._autoSizingPanel = true
    panel:SetSize(targetW, targetH)
    if left and top then
        SafeSetFramePoint(panel, "TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        SaveFramePoint(panel, settings)
    end
    panel._autoSizingPanel = false

    settings.width = targetW
    settings.height = targetH
    settings.expandedHeight = targetH
    panel._emberRestoredSavedHeightWithRows = true
end

function EL:RestoreSavedTrackingHeightIfNeeded(panel, rowCount)
    return RestoreSavedTrackingHeightIfNeeded(panel, rowCount)
end

function EL:AutoSizeTrackingPanel(reason, visibleRowCount)
    local panel = self.panel
    local settings = self.db and self.db.settings and self.db.settings.panel
    if not panel or not settings or panel._autoSizingPanel then return end

    local rowCount = tonumber(visibleRowCount)
    local targetW, targetH = self:GetTrackingPanelAutoSize(rowCount)
    local currentW, currentH = panel:GetWidth() or targetW, panel:GetHeight() or targetH
    if math.abs(currentW - targetW) <= 1 and math.abs(currentH - targetH) <= 1 then return end

    local left, top = panel:GetLeft(), panel:GetTop()
    panel._autoSizingPanel = true
    panel:SetSize(targetW, targetH)
    if left and top then
        SafeSetFramePoint(panel, "TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        SaveFramePoint(panel, settings)
    end
    panel._autoSizingPanel = false

    settings.width = targetW
    settings.height = targetH
    if rowCount == nil then
        rowCount = (self.GetVisibleTrackingRowCount and self:GetVisibleTrackingRowCount() or 0)
    end
    if rowCount > 0 then
        settings.expandedHeight = targetH
    end
end

function EL:SaveExpandedPanelHeight()
    local p = self.panel
    local settings = self.db and self.db.settings and self.db.settings.panel
    if not p or not settings then return end

    -- Remember a useful expanded height so collapsing does not permanently
    -- trap the window at a tiny size when the character list is reopened.
    if not settings.charactersCollapsed and (self.GetVisibleTrackingRowCount and self:GetVisibleTrackingRowCount() or 0) > 0 then
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
    character = T("Character"),
    prof1 = T("P1"),
    conc1 = T("Conc 1"),
    prof2 = T("P2"),
    conc2 = T("Conc 2"),
    moxie = T("Moxie"),
    forecast = T("Next"),
    cooldown = T("CD"),
    mulch = T("Mulch"),
}

local HEADER_TOOLTIPS = {
    character = {"Tracked character name.", "Right-click to hide. Alt-click to pin. Shift-right-click to remove saved data."},
    prof1 = {"Primary tracked profession slot."},
    conc1 = {"Concentration for the primary tracked profession.", "Colors use the configured threshold for that profession."},
    prof2 = {"Secondary tracked profession slot, shown only when needed."},
    conc2 = {"Concentration for the secondary tracked profession.", "Colors use the configured threshold for that profession."},
    moxie = {"Artisan Moxie tracked after scanning a profession window."},
    forecast = {"Time until the next concentration threshold or full state is reached."},
    cooldown = {
        "Readiness for supported profession cooldown crafts.",
        function()
            if EL.GetTrackedCooldownProfessionList then
                local professions = EL:GetTrackedCooldownProfessionList()
                if professions and professions ~= "" then
                    return "Tracking: " .. professions
                end
            end
            return "Tracking: none"
        end,
    },
    mulch = {"Imbued Mulch readiness and remaining time."},
}

local TRACKING_COLUMN_DEFS = {
    { key = "character", label = "Character", width = 132, minWidth = 108, compactWidth = 104, compactMinWidth = 88, justify = "LEFT", sortKey = "character", alwaysVisible = true },
    { key = "prof1", label = "P1", width = 30, minWidth = 28, compactWidth = 26, compactMinWidth = 24, justify = "CENTER", sortKey = "prof1", setting = "showProfession1Column", toggleLabel = "Prof 1 column" },
    { key = "conc1", label = "Conc 1", width = 80, minWidth = 76, compactWidth = 64, compactMinWidth = 60, justify = "RIGHT", sortKey = "conc1", setting = "showConcentration1Column", toggleLabel = "Conc 1 column" },
    { key = "prof2", label = "P2", width = 30, minWidth = 28, compactWidth = 26, compactMinWidth = 24, justify = "CENTER", sortKey = "prof2", setting = "showProfession2Column", toggleLabel = "Prof 2 column", secondary = true },
    { key = "conc2", label = "Conc 2", width = 80, minWidth = 76, compactWidth = 64, compactMinWidth = 60, justify = "RIGHT", sortKey = "conc2", setting = "showConcentration2Column", toggleLabel = "Conc 2 column", secondary = true },
    { key = "forecast", label = "Next", width = 76, minWidth = 68, compactWidth = 66, compactMinWidth = 60, justify = "RIGHT", sortKey = "forecast", setting = "showForecastColumn", toggleLabel = "Next column" },
    { key = "moxie", label = "Moxie", width = 74, minWidth = 70, compactWidth = 64, compactMinWidth = 60, justify = "RIGHT", sortKey = "moxie", setting = "showMoxieColumn", toggleLabel = "Moxie column" },
    { key = "cooldown", label = "CD", width = 36, minWidth = 32, compactWidth = 30, compactMinWidth = 28, justify = "CENTER", sortKey = "cooldown", setting = "showCooldownColumn", toggleLabel = "Cooldown readiness column" },
    { key = "mulch", label = "Mulch", width = 58, minWidth = 56, compactWidth = 54, compactMinWidth = 52, justify = "RIGHT", sortKey = "mulch", setting = "showMulchColumn", toggleLabel = "Mulch column" },
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
    cooldownDisplayScope = "current",
    hiddenCooldowns = {},
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
    -- Full UI-layer replacement for the Core fallback used by sort safety checks.
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
    totalWidth = totalWidth + (math.max(0, #columns - 1) * 4)
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
    local framePadding = 16
    local tableMargins = 0
    local gaps = math.max(0, #columns - 1) * 4
    local naturalMax = framePadding + tableMargins + characterMax + optionalWidth + gaps
    local minW = self:GetTrackingPanelMinWidth()
    return math.max(minW, math.min(PANEL_MAX_W, naturalMax))
end

local function GetColumnLayout(width)
    -- v2.0 visual pass 16: keep the Character header and row names aligned with a safe border inset.
    width = math.max(1, tonumber(width) or 1)
    local margin = 6
    local gap = 4
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

function EL:GetTrackingColumnLayout(width)
    return GetColumnLayout(width)
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
    b.bg:SetColorTexture(0.70, 0.78, 0.88, 0)
    b:SetScript("OnClick", function(self)
        EL:SetSortKey(self.sortKey)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local ar, ag, ab = ThemeAccentRGB(); GameTooltip:SetText(T("Sort by %s", HEADER_LABELS[self.sortKey] or self.sortKey), ar, ag, ab)
        local tipLines = HEADER_TOOLTIPS and HEADER_TOOLTIPS[self.sortKey]
        if tipLines then
            for _, line in ipairs(tipLines) do
                local textLine = line
                if type(line) == "function" then
                    local ok, value = pcall(line)
                    textLine = ok and value or nil
                end
                if textLine and textLine ~= "" then
                    local tr, tg, tb = ThemeTextRGB(); GameTooltip:AddLine(T(textLine), tr, tg, tb, true)
                end
            end
        end
        local mr, mg, mb = ThemeMutedTextRGB(); GameTooltip:AddLine(T("Click again to reverse the order."), mr, mg, mb)
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
    local r, g, b = ThemeBorderRGB()
    line:SetColorTexture(r, g, b, 0.34)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, yTop)
    line:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", x, yBottom)
    return line
end

local function CreateMetricBlock(parent, label)
    local f = CreateFrame("Frame", nil, parent)
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.label:SetPoint("TOP", f, "TOP", 0, 0)
    f.label:SetText(label)
    f.label:SetTextColor(ThemeMutedTextRGB())
    f.value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.value:SetPoint("TOP", f.label, "BOTTOM", 0, -3)
    f.value:SetTextColor(ThemeValueTextRGB())
    f.value:SetJustifyH("CENTER")
    return f
end


-- ============================================================================
-- Shared UI Helpers
--
-- Options panel construction now lives in Modules/OptionsPanel.lua. Only helpers
-- still used by the tracker, onboarding, session history dropdown, or shared
-- theme refresh logic remain in UI.lua.
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
-- Options Panel
--
-- Options panel construction/runtime methods were extracted to
-- Modules/OptionsPanel.lua in v2.0.18. Shared visual helpers now route
-- through Modules/Styling.lua to avoid duplicated helper implementations.
-- ============================================================================

function EL:RefreshVisualTheme()
    if self.ApplyVisualTheme then self:ApplyVisualTheme() end
    local accentR, accentG, accentB = ThemeAccentRGB()
    local borderR, borderG, borderB = ThemeBorderRGB()
    local bgR, bgG, bgB = ThemeColor("BG_R", 0.020), ThemeColor("BG_G", 0.016), ThemeColor("BG_B", 0.040)

    local f = self.settingsPanel
    if f then
        AddBackdrop(f, GetPanelOpacity(), 0.62)
        if f.SetBackdropColor then f:SetBackdropColor(bgR, bgG, bgB, GetPanelOpacity()) end
        if f.SetBackdropBorderColor then f:SetBackdropBorderColor(borderR, borderG, borderB, 0.72) end
        if f.nav then
            AddBackdrop(f.nav, 0.44, 0.42)
            if f.nav.SetBackdropColor then f.nav:SetBackdropColor(bgR, bgG, bgB, 0.58) end
            if f.nav.SetBackdropBorderColor then f.nav:SetBackdropBorderColor(borderR, borderG, borderB, 0.48) end
        end
        if f.headerPanel then
            AddBackdrop(f.headerPanel, 0.96, 0.58)
            if f.headerPanel.SetBackdropColor then f.headerPanel:SetBackdropColor(0.006, 0.007, 0.010, 0.96) end
            if f.headerPanel.SetBackdropBorderColor then f.headerPanel:SetBackdropBorderColor(borderR, borderG, borderB, 0.58) end
        end
        if f.headerGlow then f.headerGlow:SetColorTexture(accentR, accentG, accentB, 0.040) end
        if f.title then f.title:SetTextColor(accentR, accentG, accentB) end
        if f.subtitle then local mr, mg, mb = ThemeMutedTextRGB(); f.subtitle:SetTextColor(mr, mg, mb) end
        ApplyThemeTextCollections(f)
        if f.allSettingsSections then
            for _, section in ipairs(f.allSettingsSections) do
                ApplySettingsSectionTheme(section)
            end
        end
        if self.UpdateSettingsNavHighlight then self:UpdateSettingsNavHighlight() end
    end

    if self.panel then
        AddBackdrop(self.panel, GetPanelOpacity(), 0.78)
        if self.panel.SetBackdropColor then self.panel:SetBackdropColor(bgR, bgG, bgB, GetPanelOpacity()) end
        if self.panel.SetBackdropBorderColor then self.panel:SetBackdropBorderColor(borderR, borderG, borderB, 0.88) end
        if self.panel.topBar then
            AddBackdrop(self.panel.topBar, 0.48, 0.52)
            if self.panel.topBar.SetBackdropColor then self.panel.topBar:SetBackdropColor(0.006, 0.007, 0.010, 0.92) end
            if self.panel.topBar.SetBackdropBorderColor then self.panel.topBar:SetBackdropBorderColor(borderR, borderG, borderB, 0.64) end
        end
        if self.panel.topBarGlow then self.panel.topBarGlow:SetColorTexture(accentR, accentG, accentB, 0.055) end
        if self.panel.title then self.panel.title:SetTextColor(accentR, accentG, accentB) end
        if self.panel.subtitle then local mr, mg, mb = ThemeMutedTextRGB(); self.panel.subtitle:SetTextColor(mr, mg, mb) end
        if self.panel.header then
            AddBackdrop(self.panel.header, 0.42, 0.34)
            if self.panel.header.SetBackdropBorderColor then self.panel.header:SetBackdropBorderColor(borderR, borderG, borderB, 0.42) end
        end
        if self.panel.header and self.panel.header.topLine then self.panel.header.topLine:SetColorTexture(accentR, accentG, accentB, HEADER_LINE_ALPHA_TOP) end
        if self.panel.header and self.panel.header.bottomLine then self.panel.header.bottomLine:SetColorTexture(accentR, accentG, accentB, HEADER_LINE_ALPHA_BOTTOM) end
        if self.panel.header and self.panel.header.warmth then self.panel.header.warmth:SetColorTexture(accentR, accentG, accentB, 0.040) end
        if self.panel.footerShade then self.panel.footerShade:SetColorTexture(0.030, 0.032, 0.036, 0.34) end
        if self.panel.footerTopLine then self.panel.footerTopLine:SetColorTexture(borderR, borderG, borderB, 0.22) end
        if self.panel.rows then
            for _, row in ipairs(self.panel.rows) do
                if row and row.hover then ApplyTrackingRowHoverState(row, false) end
                if row and row.sep then row.sep:SetColorTexture(borderR, borderG, borderB, ROW_SEPARATOR_ALPHA) end
                if row and row.edge then row.edge:SetColorTexture(accentR, accentG, accentB, 0.00) end
                if row and row.currentHighlight then row.currentHighlight:SetColorTexture(accentR, accentG, accentB, 0.00) end
                if row and row._highlightLines then
                    for _, line in ipairs(row._highlightLines) do
                        if line then line:SetColorTexture(accentR, accentG, accentB, 0.00) end
                    end
                end
            end
        end
    end

    if self.button then
        AddBackdrop(self.button, GetLauncherOpacity(), 0.58)
        if self.button.SetBackdropColor then self.button:SetBackdropColor(bgR, bgG, bgB, GetLauncherOpacity()) end
        if self.button.SetBackdropBorderColor then self.button:SetBackdropBorderColor(borderR, borderG, borderB, 0.78) end
        if self.button.title then self.button.title:SetTextColor(accentR, accentG, accentB) end
        if self.button.titleRule then self.button.titleRule:SetColorTexture(accentR, accentG, accentB, 0.38) end
        if self.button.hover then self.button.hover:SetColorTexture(accentR, accentG, accentB, 0.10) end
    end

    if self.sessionWindow and self.sessionWindow.sessionPanel then
        local session = self.sessionWindow.sessionPanel
        AddBackdrop(session, 0.30, 0.36)
        if session.SetBackdropColor then session:SetBackdropColor(bgR, bgG, bgB, 0.46) end
        if session.SetBackdropBorderColor then session:SetBackdropBorderColor(borderR, borderG, borderB, 0.52) end
        if session.header then
            AddBackdrop(session.header, 0.24, 0.30)
            if session.header.SetBackdropColor then session.header:SetBackdropColor(bgR, bgG, bgB, 0.78) end
            if session.header.SetBackdropBorderColor then session.header:SetBackdropBorderColor(borderR, borderG, borderB, 0.42) end
        end
        if session.title then session.title:SetTextColor(accentR, accentG, accentB) end
        if session.metrics then
            for _, child in ipairs({session.metricTime, session.metricValue, session.metricRate}) do
                if child and child.label then child.label:SetTextColor(ThemeMutedTextRGB()) end
                if child and child.value then child.value:SetTextColor(ThemeValueTextRGB()) end
            end
        end
        if session.buttonBar then
            for _, btn in ipairs({session.toggle, session.history, session.reset}) do
                if btn and EL.Style and EL.Style.StyleActionBarButton then EL.Style:StyleActionBarButton(btn) end
            end
        end
    end

    local history = self.sessionHistoryWindow or self.sessionHistoryFrame
    if history then
        AddBackdrop(history, GetPanelOpacity(), 0.62)
        if history.SetBackdropColor then history:SetBackdropColor(bgR, bgG, bgB, GetPanelOpacity()) end
        if history.SetBackdropBorderColor then history:SetBackdropBorderColor(borderR, borderG, borderB, 0.78) end
        if history.header then
            AddBackdrop(history.header, 0.96, 0.66)
            if history.header.SetBackdropColor then history.header:SetBackdropColor(bgR, bgG, bgB, 0.96) end
            if history.header.SetBackdropBorderColor then history.header:SetBackdropBorderColor(borderR, borderG, borderB, 0.66) end
        end
        if history.title then history.title:SetTextColor(accentR, accentG, accentB) end
        if history.rangeBox then AddBackdrop(history.rangeBox, 0.92, 0.66) end
        if history.displayRange then AddBackdrop(history.displayRange, 0.86, 0.70) end
        if history.displayRange and history.displayRange.arrowBox and history.displayRange.arrowBox.SetBackdropBorderColor then
            history.displayRange.arrowBox:SetBackdropBorderColor(borderR, borderG, borderB, 0.55)
        end
        if history.table then AddBackdrop(history.table, 0.88, 0.64) end
        if history.tableHeaderGlow then history.tableHeaderGlow:SetColorTexture(accentR, accentG, accentB, 0.055) end
        if history.headers then
            for _, header in ipairs(history.headers) do
                if header and header.SetTextColor then header:SetTextColor(accentR, accentG, accentB) end
            end
        end
    end
end


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

    frame.logo = AddEmberLogoBadge(frame.header, 32, "ARTWORK")
    if frame.logo then frame.logo:SetPoint("LEFT", frame.header, "LEFT", 8, 0) end

    frame.title = frame.header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.title:SetPoint("CENTER", frame.header, "CENTER", 0, 1)
    frame.title:SetText(T("EmberLedger") .. " - Stats")
    frame.title:SetTextColor(ThemeAccentRGB())

    frame.close = CreateFrame("Button", nil, frame.header, "UIPanelCloseButton")
    frame.close:SetSize(24, 24)
    frame.close:SetPoint("RIGHT", frame.header, "RIGHT", -6, 0)
    frame.close:SetScript("OnClick", function()
        frame:Hide()
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
        if EL.LayoutActionBar then EL:LayoutActionBar() end
        if EL.RequestActionBarRefresh then EL:RequestActionBarRefresh(true) end
        if EL.RefreshUpdateTicker then EL:RefreshUpdateTicker() end
    end)
    frame:SetScript("OnHide", function()
        HideSessionHistoryDisplayDropdown()
    end)


    frame.viewMode = "stats"
    frame.statsView = CreateFrame("Button", nil, frame.header, "UIPanelButtonTemplate")
    frame.statsView:SetSize(58, 21)
    frame.statsView:SetPoint("LEFT", frame.header, "LEFT", 54, 0)
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
    frame.info:SetTextColor(ThemeTextRGB())
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
    frame.rangeText:SetTextColor(ThemeTextRGB())

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
    frame.displayLabel:SetTextColor(ThemeTextRGB())

    frame.displayRange.selectedText = frame.displayRange:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.displayRange.selectedText:SetPoint("LEFT", frame.displayRange, "LEFT", 10, 0)
    frame.displayRange.selectedText:SetPoint("RIGHT", frame.displayRange, "RIGHT", -30, 0)
    frame.displayRange.selectedText:SetJustifyH("LEFT")
    frame.displayRange.selectedText:SetTextColor(ThemeTextRGB())

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
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0.82, 0.88, 0.96, 0.85) end
        if self.selectedText then self.selectedText:SetTextColor(0.82, 0.88, 0.96) end
        if self.arrowBox and self.arrowBox.SetBackdropBorderColor then self.arrowBox:SetBackdropBorderColor(0.82, 0.88, 0.96, 0.85) end
    end)
    frame.displayRange:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0.70) end
        if self.selectedText then self.selectedText:SetTextColor(ThemeTextRGB()) end
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
    frame.tableHeaderGlow = frame.table:CreateTexture(nil, "BACKGROUND")
    frame.tableHeaderGlow:SetPoint("TOPLEFT", frame.table, "TOPLEFT", 6, -5)
    frame.tableHeaderGlow:SetPoint("TOPRIGHT", frame.table, "TOPRIGHT", -24, -5)
    frame.tableHeaderGlow:SetHeight(24)
    frame.tableHeaderGlow:SetColorTexture(1.00, 0.62, 0.18, 0.055)
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
        fs:SetTextColor(ThemeTextRGB())
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
            fs:SetTextColor(ThemeTextRGB())
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
            local ar, ag, ab = ThemeAccentRGB()
            local tr, tg, tb = ThemeTextRGB()
            local mr, mg, mb = ThemeMutedTextRGB()
            local vr, vg, vb = ThemeValueTextRGB()
            GameTooltip:SetText("Session Details", ar, ag, ab)
            GameTooltip:AddLine((entry.character or "Unknown") .. " - " .. (entry.realm or "Unknown"), tr, tg, tb)
            GameTooltip:AddLine("Duration: " .. EL:FormatDuration(tonumber(entry.duration) or 0), mr, mg, mb)
            GameTooltip:AddLine("Item value: " .. EL:FormatMoneyText(tonumber(entry.itemValueSilver) or 0), vr, vg, vb)
            GameTooltip:AddLine("Raw gold: " .. EL:FormatMoneyText(tonumber(entry.rawGoldGainedSilver) or 0), vr, vg, vb)
            GameTooltip:AddLine("Spent: " .. EL:FormatMoneyText(-(tonumber(entry.goldSpentSilver) or 0)), 0.85, 0.45, 0.45)
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
    frame.statsTitle:SetTextColor(ThemeTextRGB())

    frame.statsNote = frame.statsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statsNote:SetPoint("TOPLEFT", frame.statsTitle, "BOTTOMLEFT", 0, -4)
    frame.statsNote:SetPoint("TOPRIGHT", frame.statsPanel, "TOPRIGHT", -16, -34)
    frame.statsNote:SetJustifyH("LEFT")
    frame.statsNote:SetTextColor(ThemeMutedTextRGB())

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
        labelText:SetTextColor(ThemeTextRGB())

        local valueText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valueText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 34, 10)
        valueText:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 10)
        valueText:SetJustifyH("RIGHT")
        valueText:SetTextColor(ThemeValueTextRGB())
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
    frame.statsFootnote:SetTextColor(ThemeMutedTextRGB())

    frame.bagPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.bagPanel:SetPoint("TOPLEFT", frame.rangeBox, "BOTTOMLEFT", 0, -8)
    frame.bagPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    AddBackdrop(frame.bagPanel, 0.90, 0.66)
    if frame.bagPanel.SetBackdropColor then frame.bagPanel:SetBackdropColor(0.012, 0.010, 0.024, 0.90) end
    AddInnerBorder(frame.bagPanel)

    frame.bagTitle = frame.bagPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.bagTitle:SetPoint("TOPLEFT", frame.bagPanel, "TOPLEFT", 16, -12)
    frame.bagTitle:SetText("Current Bag Summary")
    frame.bagTitle:SetTextColor(ThemeTextRGB())

    frame.bagNote = frame.bagPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.bagNote:SetPoint("TOPLEFT", frame.bagTitle, "BOTTOMLEFT", 0, -4)
    frame.bagNote:SetPoint("TOPRIGHT", frame.bagPanel, "TOPRIGHT", -16, -34)
    frame.bagNote:SetJustifyH("LEFT")
    frame.bagNote:SetTextColor(ThemeMutedTextRGB())
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
        labelText:SetTextColor(ThemeTextRGB())

        local valueText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valueText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 34, 7)
        valueText:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 7)
        valueText:SetJustifyH("RIGHT")
        valueText:SetTextColor(ThemeValueTextRGB())
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
        { key = "item", label = T("Item"), left = 16, width = 300, justify = "LEFT" },
        { key = "qty", label = T("Qty"), right = -404, width = 78, justify = "RIGHT" },
        { key = "unit", label = T("Value"), right = -268, width = 112, justify = "RIGHT" },
        { key = "total", label = T("Total"), right = -16, width = 230, justify = "RIGHT" },
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
        fs:SetTextColor(ThemeTextRGB())
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
            fs:SetTextColor(ThemeTextRGB())
            table.insert(row.texts, fs)
        end
        frame.bagRows[i] = row
    end

    frame.bagFootnote = frame.bagPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.bagFootnote:SetPoint("BOTTOMLEFT", frame.bagPanel, "BOTTOMLEFT", 16, 14)
    frame.bagFootnote:SetPoint("BOTTOMRIGHT", frame.bagPanel, "BOTTOMRIGHT", -16, 14)
    frame.bagFootnote:SetJustifyH("LEFT")
    frame.bagFootnote:SetTextColor(ThemeMutedTextRGB())

    frame.totals = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.totals:SetPoint("TOPLEFT", frame.table, "BOTTOMLEFT", 0, -10)
    frame.totals:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    AddBackdrop(frame.totals, 0.90, 0.66)
    if frame.totals.SetBackdropColor then frame.totals:SetBackdropColor(0.012, 0.010, 0.024, 0.90) end
    AddInnerBorder(frame.totals)

    frame.totalsTitle = frame.totals:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.totalsTitle:SetPoint("TOPLEFT", frame.totals, "TOPLEFT", 14, -10)
    frame.totalsTitle:SetText("Sessions Total")
    frame.totalsTitle:SetTextColor(ThemeTextRGB())

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
        labelText:SetTextColor(ThemeTextRGB())

        local valueText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valueText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 34, 7)
        valueText:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 7)
        valueText:SetJustifyH("RIGHT")
        valueText:SetTextColor(ThemeValueTextRGB())
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
            row.texts[1]:SetTextColor(ThemeTextRGB())
            row.texts[3]:SetTextColor(ThemeTextRGB())
            row.texts[5]:SetTextColor(ThemeTextRGB())
        else
            row:Show()
            for _, fs in ipairs(row.texts or {}) do fs:SetText(""); fs:SetTextColor(ThemeTextRGB()) end
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



-- Onboarding panel construction and first-run display scheduling are implemented in
-- Modules/Onboarding.lua. Core.lua retains slash command routing and onboarding
-- SavedVariables helpers.

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
    if self.ScheduleFirstRunOnboarding then self:ScheduleFirstRunOnboarding() end
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
    button.title:SetText(T("EmberLedger"))
    if button.title.SetFontObject then button.title:SetFontObject(GameFontNormalLarge) end
    button.title:SetTextColor(ThemeAccentRGB())
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
    local r, g, b = ThemeAccentRGB(); button.titleRule:SetColorTexture(r, g, b, 0.32)

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
    button.line2:SetTextColor(ThemeTextRGB())

    button.line3 = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.line3:SetPoint("TOPLEFT", button.line2, "BOTTOMLEFT", 0, -3)
    button.line3:SetPoint("TOPRIGHT", button.line2, "BOTTOMRIGHT", 0, -3)
    button.line3:SetJustifyH("CENTER")
    if button.line3.SetWordWrap then button.line3:SetWordWrap(false) end
    button.line3:SetTextColor(ThemeMutedTextRGB())

    button.line4 = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.line4:SetPoint("TOPLEFT", button.line3, "BOTTOMLEFT", 0, -3)
    button.line4:SetPoint("TOPRIGHT", button.line3, "BOTTOMRIGHT", 0, -3)
    button.line4:SetJustifyH("CENTER")
    if button.line4.SetWordWrap then button.line4:SetWordWrap(false) end
    button.line4:SetTextColor(ThemeMutedTextRGB())

    button.line5 = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.line5:SetPoint("TOPLEFT", button.line4, "BOTTOMLEFT", 0, -3)
    button.line5:SetPoint("TOPRIGHT", button.line4, "BOTTOMRIGHT", 0, -3)
    button.line5:SetJustifyH("CENTER")
    if button.line5.SetWordWrap then button.line5:SetWordWrap(false) end
    button.line5:SetTextColor(ThemeMutedTextRGB())

    button.hover = button:CreateTexture(nil, "HIGHLIGHT")
    button.hover:SetAllPoints()
    local r, g, b = ThemeAccentRGB(); button.hover:SetColorTexture(r, g, b, 0.08)

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
    session.title:SetText(T("EmberLedger") .. " " .. T("Session"))
    session.title:SetTextColor(ThemeAccentRGB())

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
            sp.summary:SetText("Session tracking is disabled.\nEnable it under Modules to track time, gathered items, and value.")
            sp.summary:SetTextColor(ThemeMutedTextRGB())
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
        sp.metricRate.value:SetTextColor(ThemeMutedTextRGB())
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
    AddBackdrop(panel, 0.74, 0.74)
    if panel.SetBackdropColor then panel:SetBackdropColor(0.012, 0.010, 0.026, GetPanelOpacity()) end
    if panel.SetBackdropBorderColor then panel:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0.88) end
    AddInnerBorder(panel)
    AddEmberCornerAccents(panel)
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
    panel.topBar:SetHeight(34)
    panel.topBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    panel.topBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    AddBackdrop(panel.topBar, 0.48, 0.48)
    if panel.topBar.SetBackdropColor then panel.topBar:SetBackdropColor(0.020, 0.012, 0.030, 0.90) end
    if panel.topBar.SetBackdropBorderColor then panel.topBar:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 0.58) end
    AddHeaderAccent(panel.topBar)
    panel.topBarGlow = panel.topBar:CreateTexture(nil, "BACKGROUND")
    panel.topBarGlow:SetPoint("TOPLEFT", panel.topBar, "TOPLEFT", 6, -4)
    panel.topBarGlow:SetPoint("BOTTOMRIGHT", panel.topBar, "BOTTOMRIGHT", -6, 4)
    local r, g, b = ThemeAccentRGB(); panel.topBarGlow:SetColorTexture(r, g, b, 0.045)

    panel.logo = AddEmberLogoBadge(panel.topBar, 30, "ARTWORK")
    if panel.logo then panel.logo:SetPoint("LEFT", panel.topBar, "LEFT", 7, 0) end

    panel.title = panel.topBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("LEFT", panel.topBar, "LEFT", 46, 0)
    panel.title:SetText(T("EmberLedger"))
    panel.title:SetTextColor(ThemeAccentRGB())

    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOPLEFT", panel.topBar, "BOTTOMLEFT", 2, -4)
    panel.subtitle:SetText(T("Profession Tracking"))
    panel.subtitle:SetTextColor(0.78, 0.84, 0.92)

    panel.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.summary:SetPoint("TOPLEFT", panel.subtitle, "BOTTOMLEFT", 0, -2)
    panel.summary:SetJustifyH("LEFT")
    panel.summary:SetTextColor(ThemeMutedTextRGB())
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
    panel.settings:SetText(T("Options"))
    StyleBlizzardButton(panel.settings)
    panel.settings:SetPoint("RIGHT", panel.close, "LEFT", -7, 0)
    panel.settings:SetScript("OnClick", function() EL:ToggleSettingsPanel() end)

    -- Scale controls live in the Options panel.
    panel.scaleDown = nil
    panel.scaleUp = nil

    panel.restore = CreateFrame("Button", nil, panel.topBar or panel, "UIPanelButtonTemplate")
    panel.restore:SetSize(78, 22)
    panel.restore:SetText(T("Restore"))
    StyleBlizzardButton(panel.restore)
    panel.restore:SetPoint("RIGHT", panel.settings, "LEFT", -6, 0)
    panel.restore:SetScript("OnClick", function() EL:RestoreHiddenCharacters() end)
    panel.restore:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("Restore hidden characters"), 1, 0.55, 0.15)
        GameTooltip:AddLine(T("Right-click a row to hide a character."), 0.7, 0.7, 0.7)
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
        GameTooltip:SetText(T("Collapse or expand character cooldowns"), 1, 0.74, 0.32)
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
    panel.header.warmth = panel.header:CreateTexture(nil, "BACKGROUND")
    panel.header.warmth:SetPoint("TOPLEFT", panel.header, "TOPLEFT", 5, -5)
    panel.header.warmth:SetPoint("BOTTOMRIGHT", panel.header, "BOTTOMRIGHT", -5, 5)
    local r, g, b = ThemeAccentRGB(); panel.header.warmth:SetColorTexture(r, g, b, 0.035)
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
    panel.header.name:SetText(T("Character"))
    panel.header.prof1:SetText(T("P1"))
    panel.header.conc1:SetText(T("Conc 1"))
    panel.header.prof2:SetText(T("P2"))
    panel.header.conc2:SetText(T("Conc 2"))
    panel.header.moxie:SetText(T("Moxie"))
    panel.header.forecast:SetText(T("Next"))
    panel.header.cooldown:SetText(T("CD"))
    panel.header.mulch:SetText(T("Mulch"))
    for _, fs in pairs({panel.header.name, panel.header.prof1, panel.header.conc1, panel.header.prof2, panel.header.conc2, panel.header.moxie, panel.header.forecast, panel.header.cooldown, panel.header.mulch}) do
        fs:SetTextColor(ThemeMutedTextRGB())
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
    panel.empty:SetText(T("No characters tracked yet. Open the Trade Skill window (K) on each profession alt."))
    panel.empty:SetTextColor(0.68, 0.70, 0.72)
    panel.empty:SetJustifyH("CENTER")
    panel.empty:SetJustifyV("TOP")
    if panel.empty.SetWordWrap then panel.empty:SetWordWrap(true) end
    if panel.empty.SetSpacing then panel.empty:SetSpacing(4) end
    panel.empty:Hide()

    panel.footerShade = panel:CreateTexture(nil, "BACKGROUND")
    panel.footerShade:SetColorTexture(0.030, 0.032, 0.036, 0.34)
    panel.footerTopLine = panel:CreateTexture(nil, "BORDER")
    panel.footerTopLine:SetHeight(1)
    panel.footerTopLine:SetColorTexture(0.68, 0.68, 0.70, 0.18)

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
        line:SetColorTexture(0.76, 0.82, 0.92, 0.58)
        panel.resize.lines[i] = line
    end
    panel.resize.corner = panel.resize:CreateTexture(nil, "BACKGROUND")
    panel.resize.corner:SetPoint("BOTTOMRIGHT", panel.resize, "BOTTOMRIGHT", 0, 0)
    panel.resize.corner:SetSize(18, 18)
    panel.resize.corner:SetColorTexture(0.02, 0.015, 0.01, 0.22)
    panel.resize:RegisterForClicks("LeftButtonUp")
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
    local headerFontObject = IsCompactModeEnabled() and GameFontHighlightSmall or GameFontHighlight
    for key, fs in pairs(map) do
        if fs and fs.SetFontObject then fs:SetFontObject(headerFontObject) end
        fs:SetText((HEADER_LABELS[key] or key) .. (key == active and arrow or ""))
        local btnName = key == "character" and "nameButton" or (key .. "Button")
        local btn = p.header[btnName]
        if key == active then
            fs:SetTextColor(0.92, 0.78, 0.50)
            if btn and btn.bg then btn.bg:SetColorTexture(0.78, 0.66, 0.46, 0.10) end
        else
            fs:SetTextColor(ThemeMutedTextRGB())
            if btn and btn.bg then btn.bg:SetColorTexture(0.70, 0.78, 0.88, 0) end
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
        SafeSetFramePoint(panel, "TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
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
        -- Keep the resize grip visually centered with the footer controls.
        -- When the anchored action bar is visible, center the 18px grip with
        -- the 36px footer button row; otherwise keep it low and compact.
        p.resize:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -10, actionBarShown and 19 or 10)
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
    p.header:SetPoint("TOPLEFT", p, "TOPLEFT", 8, GetTrackingHeaderYOffset())
    p.header:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, GetTrackingHeaderYOffset())
    p.header:SetHeight(compactMode and 28 or 32)

    if p.characterToggle then p.characterToggle:Hide() end

    if p.footerShade then
        p.footerShade:ClearAllPoints()
        p.footerShade:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, 8)
        p.footerShade:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -8, 8)
        p.footerShade:SetHeight(actionBarShown and 36 or 28)
        -- Match the footer tray to the character row shade so the lower area
        -- feels like part of the table instead of a heavy black block.
        local fr = math.min(1, ThemeColor("BG_R", 0.020) + 0.018)
        local fg = math.min(1, ThemeColor("BG_G", 0.018) + 0.018)
        local fb = math.min(1, ThemeColor("BG_B", 0.026) + 0.018)
        p.footerShade:SetColorTexture(fr, fg, fb, 0.34)
        p.footerShade:Show()
    end
    if p.footerTopLine then
        p.footerTopLine:ClearAllPoints()
        if p.footerShade then
            p.footerTopLine:SetPoint("TOPLEFT", p.footerShade, "TOPLEFT", 2, 0)
            p.footerTopLine:SetPoint("TOPRIGHT", p.footerShade, "TOPRIGHT", -2, 0)
            p.footerTopLine:Show()
        else
            p.footerTopLine:Hide()
        end
    end

    if not charShown then
        p.header:Hide()
        p.scroll:Hide()
        if p.empty then p.empty:Hide() end
    else
        p.header:Show()
        p.scroll:Show()
        if p.header.nameButton then p.header.nameButton:Show() end

        local headerW = math.max(1, w - 16)
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
                        AnchorColumnText(fs, p.header, cols[def.key .. "X"] or 0, math.max(1, cols[def.key .. "W"] or 1), "LEFT")
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
            local sr, sg, sb = ThemeBorderRGB(); sep:SetColorTexture(sr, sg, sb, 0.10)
            sep:Show()
        end
        for i = #sepPositions + 1, #(p.header.separators or {}) do
            p.header.separators[i]:Hide()
        end

        p.scroll:ClearAllPoints()
        p.scroll:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 0, -4)
        if actionBarShown then
            p.scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -8, GetTrackingActionBarBottomOffset() + ACTION_BAR_H + 5)
        else
            p.scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -8, 41)
        end
        p.content:SetWidth(math.max(1, p.scroll:GetWidth()))
        self:UpdateSortHeaders()
    end

    if self.RequestUpdate and p:IsShown() then
        self:RequestUpdate(true)
    elseif self.RefreshPanel then
        self:RefreshPanel()
    end
end


-- Tracking row lifecycle and rendering are owned by Modules/TrackingRows.lua.

local function UpdateTrackingHeader(owner, panel, concReady, concSoon, mulchReady)
    if panel.summary then
        if IsCompactModeEnabled() then
            SetFontStringTextIfChanged(panel.summary, "")
            panel.summary:Hide()
        else
            SetFontStringTextIfChanged(panel.summary, T("Ready: %d | Soon: %d | Mulch: %d", concReady, concSoon, mulchReady))
            panel.summary:SetTextColor(ThemeMutedTextRGB())
            panel.summary:Show()
        end
    end

    local hiddenCount = 0
    for _, hidden in pairs(owner.db and owner.db.settings and owner.db.settings.hiddenCharacters or {}) do
        if hidden then hiddenCount = hiddenCount + 1 end
    end
    if panel.restore then
        panel.restore:SetShown(hiddenCount > 0)
        panel.restore:SetText(hiddenCount > 0 and ("Restore (" .. hiddenCount .. ")") or "Restore")
    end
end

local function UpdateTrackingEmptyState(owner, panel, rows, allRows, visibleRowCount, hiddenRowCount, attentionOnly, width)
    if panel.empty then
        local compactMode = IsCompactModeEnabled()
        panel.empty:ClearAllPoints()
        panel.empty:SetPoint("TOPLEFT", panel.header, "BOTTOMLEFT", 12, compactMode and -8 or -10)
        panel.empty:SetPoint("TOPRIGHT", panel.header, "BOTTOMRIGHT", -12, compactMode and -8 or -10)
        panel.empty:SetHeight(GetTrackingEmptyBodyHeight())
        if panel.empty.SetFontObject then panel.empty:SetFontObject(compactMode and GameFontHighlightSmall or GameFontHighlight) end
        if panel.empty.SetSpacing then panel.empty:SetSpacing(0) end
        if panel.empty.SetWidth then panel.empty:SetWidth(math.max(1, (panel.header:GetWidth() or width) - 24)) end

        local emptyText
        if #allRows == 0 then
            emptyText = T("No characters tracked yet. Open the Trade Skill window (K) on each profession alt.")
        elseif visibleRowCount == 0 and hiddenRowCount == #allRows then
            emptyText = T("All tracked characters are hidden. Use Restore to show them.")
        elseif attentionOnly and hiddenRowCount > 0 then
            emptyText = T("No attention rows. Restore hidden characters or turn off Attention Only.")
        elseif attentionOnly then
            emptyText = T("No characters need attention. Adjust thresholds or turn off Attention Only to view all tracked characters.")
        else
            emptyText = T("No visible character data. Open the Trade Skill window on a character to scan that character.")
        end
        panel.empty:SetText(emptyText)
        panel.empty:SetShown(#rows == 0)
    end
end


-- Main tracker refresh orchestration. Row creation and cell rendering are
-- delegated to Modules/TrackingRows.lua; UI.lua keeps lookup/filter/sort and
-- window auto-sizing ownership.
function EL:RefreshPanel()
    local p = self.panel
    if not p then return end
    local profileStage = self.ProfileStart and self.ProfileStop and self:IsProfilingEnabled()
    local stageProfile = nil
    local function StartStage(label)
        if not profileStage then return nil end
        return self:ProfileStart(label)
    end
    local function StopStage(label, started)
        if started then self:ProfileStop(label, started) end
    end
    local threshold = self:GetConcentrationThreshold()
    local now = time()
    stageProfile = StartStage("RefreshPanel:Lookups")
    local mulchStatus = self.GetMulchStatus and self:GetMulchStatus(now) or nil
    local mulchReady = mulchStatus and mulchStatus.readyCount or 0
    local concReady, concSoon = 0, 0
    local concentrationLookup = {}
    for charKey, entries in pairs(self:GetConcentrationIndex() or {}) do
        if charKey then
            local lookup = { entries = entries or {}, readyCount = 0, soonCount = 0, best = nil, bestQty = nil }
            concentrationLookup[charKey] = lookup
            for _, data in ipairs(entries or {}) do
                local qty = self:GetEstimatedConcentration(data, now) or 0
                local required = self:GetProfessionConcentrationThreshold(data) or threshold
                local soonFloor = math.max(0, math.floor((tonumber(required) or threshold or self.CONCENTRATION_THRESHOLD_DEFAULT or 900) * 0.80 + 0.5))
                if qty >= required then
                    lookup.readyCount = lookup.readyCount + 1
                elseif qty >= soonFloor then
                    lookup.soonCount = lookup.soonCount + 1
                end
                if not lookup.best or qty > (lookup.bestQty or -1) then
                    lookup.best = data
                    lookup.bestQty = qty
                end
            end
            if not self:IsCharacterHidden(charKey) then
                if lookup.readyCount > 0 then
                    concReady = concReady + 1
                elseif lookup.soonCount > 0 then
                    concSoon = concSoon + 1
                end
            end
        end
    end
    StopStage("RefreshPanel:Lookups", stageProfile)
    stageProfile = StartStage("RefreshPanel:Header")
    UpdateTrackingHeader(self, p, concReady, concSoon, mulchReady)
    StopStage("RefreshPanel:Header", stageProfile)

    stageProfile = StartStage("RefreshPanel:GetCharacterRows")
    local allRows = self:GetCharacterRows()
    StopStage("RefreshPanel:GetCharacterRows", stageProfile)

    stageProfile = StartStage("RefreshPanel:RowsFilter")
    local rows = {}
    local display = self.db and self.db.settings and self.db.settings.display or {}
    local attentionOnly = display.attentionOnly == true
    local visibleRowCount = 0
    local hiddenRowCount = 0
    local mulchReadyByChar = mulchStatus and mulchStatus.readyByChar or nil
    local function EntryNeedsAttention(charKey)
        local concLookup = concentrationLookup and concentrationLookup[charKey]
        if concLookup and concLookup.readyCount and concLookup.readyCount > 0 then return true end
        if mulchReadyByChar and mulchReadyByChar[charKey] then return true end
        return false
    end
    for _, entry in ipairs(allRows) do
        if entry and entry.key then
            if self:IsCharacterHidden(entry.key) then
                hiddenRowCount = hiddenRowCount + 1
            else
                visibleRowCount = visibleRowCount + 1
                if not attentionOnly or EntryNeedsAttention(entry.key) then
                    rows[#rows + 1] = entry
                end
            end
        end
    end
    StopStage("RefreshPanel:RowsFilter", stageProfile)

    stageProfile = StartStage("RefreshPanel:ProfessionLookup")
    local professionLookup = self.GetProfessionLookup and self:GetProfessionLookup() or {}
    StopStage("RefreshPanel:ProfessionLookup", stageProfile)

    local dashboardLookups = { concentrationLookup = concentrationLookup, professionLookup = professionLookup }
    stageProfile = StartStage("RefreshPanel:Sort")
    self:SortDashboardRows(rows, dashboardLookups, now)
    self:UpdateSortHeaders()
    StopStage("RefreshPanel:Sort", stageProfile)

    stageProfile = StartStage("RefreshPanel:LayoutPrep")
    local rowH, gap = GetTrackingRowHeight(), (self.GetTrackingRowGap and self:GetTrackingRowGap() or 0)
    local width = math.max(1, p.scroll and p.scroll:GetWidth() or p:GetWidth() - 40)
    local cols = GetColumnLayout(width)
    p.content:SetWidth(width)
    local visible = {}
    for _, def in ipairs(cols.columns or {}) do visible[def.key] = true end
    local layoutGeneration = nil

    local currentCharKey = self.GetCharacterKey and self:GetCharacterKey() or nil
    local highlightCurrent = display.highlightCurrentCharacter ~= false
    StopStage("RefreshPanel:LayoutPrep", stageProfile)

    stageProfile = StartStage("RefreshPanel:RowUpdate")
    local renderedRowCount = #rows
    if self.RefreshTrackingRows then
        local outCount, outRowH, outGap = self:RefreshTrackingRows({
            panel = p,
            rows = rows,
            width = width,
            rowH = rowH,
            gap = gap,
            now = now,
            columns = cols,
            visible = visible,
            layoutGeneration = layoutGeneration,
            currentCharKey = currentCharKey,
            highlightCurrent = highlightCurrent,
            concentrationLookup = concentrationLookup,
            professionLookup = professionLookup,
            dashboardLookups = dashboardLookups,
        })
        renderedRowCount = tonumber(outCount) or renderedRowCount
        rowH = tonumber(outRowH) or rowH
        gap = tonumber(outGap) or gap
    elseif not self._trackingRowsMissingWarned then
        self._trackingRowsMissingWarned = true
        if self.Debug then self:Debug("TrackingRows module is unavailable; tracker rows cannot render.") end
    end
    StopStage("RefreshPanel:RowUpdate", stageProfile)

    stageProfile = StartStage("RefreshPanel:EmptyAutoSize")
    UpdateTrackingEmptyState(self, p, rows, allRows, visibleRowCount, hiddenRowCount, attentionOnly, width)
    p.content:SetHeight(math.max(GetTrackingEmptyBodyHeight(), #rows * (rowH + gap)))
    if #rows > 0 and not p._emberVerticalResizing then RestoreSavedTrackingHeightIfNeeded(p, #rows) end
    if self.AutoSizeTrackingPanel and not p._emberVerticalResizing then self:AutoSizeTrackingPanel("refresh", #rows) end
    StopStage("RefreshPanel:EmptyAutoSize", stageProfile)
end

function EL:UpdateButton()
    local b = self.button
    if not b then return end
    local display = self.db and self.db.settings and self.db.settings.display or {}
    local now = time()
    local concReady = self:GetConcentrationReadyCount(nil, now)
    local mulchStatus = self.GetMulchStatus and self:GetMulchStatus(now) or nil
    local mulchReady = mulchStatus and mulchStatus.readyCount or 0
    local nextMulch = mulchStatus and mulchStatus.next or nil
    ApplyFrameOpacity(b, GetLauncherOpacity())

    if b.title then
        SetFontStringTextIfChanged(b.title, T("EmberLedger"))
        b.title:SetTextColor(ThemeAccentRGB())
        b.title:SetJustifyH("CENTER")
        b.title:SetShadowColor(0.00, 0.00, 0.00, 0.95)
        b.title:SetShadowOffset(1, -1)
    end

    local line1Text = ""
    if display.showLauncherConc ~= false then
        line1Text = "Conc " .. tostring(concReady or 0)
    end
    if display.showLauncherMulch ~= false then
        local mulchText
        if mulchReady and mulchReady > 0 then
            mulchText = "Mulch " .. tostring(mulchReady)
        elseif nextMulch and nextMulch.remaining then
            mulchText = "Mulch " .. self:FormatCountdown(nextMulch.remaining)
        else
            mulchText = "Mulch N/A"
        end
        line1Text = #line1Text > 0 and (line1Text .. "  |  " .. mulchText) or mulchText
    end

    if b.line1 then
        if #line1Text > 0 then
            SetFontStringTextIfChanged(b.line1, line1Text)
            if (concReady and concReady > 0) or (mulchReady and mulchReady > 0) then
                b.line1:SetTextColor(0.35, 1.00, 0.35)
            else
                b.line1:SetTextColor(ThemeTextRGB())
            end
            b.line1:Show()
        else
            SetFontStringTextIfChanged(b.line1, "")
            b.line1:Hide()
        end
    end

    local nextCooldown = display.showLauncherCooldown == true and self.GetNextProfessionCooldownSummary and self:GetNextProfessionCooldownSummary(now) or nil
    local line2Text = ""
    if nextCooldown then
        if nextCooldown.ready then
            line2Text = "CD ready " .. tostring(nextCooldown.readyCount or 1)
            if nextCooldown.characterName then line2Text = line2Text .. " | " .. tostring(nextCooldown.characterName) end
        elseif nextCooldown.remaining and nextCooldown.remaining > 0 then
            line2Text = "CD " .. tostring(nextCooldown.characterName or "Next") .. " " .. self:FormatCountdown(nextCooldown.remaining)
        end
    end

    local sessionEnabled = not self.IsSessionTrackingEnabled or self:IsSessionTrackingEnabled()
    if sessionEnabled and display.showLauncherSession ~= false then
        local rateText = self:FormatMoneyRateText(self:GetSessionGoldPerHour()) .. "/hr"
        line2Text = #line2Text > 0 and (line2Text .. "  |  " .. rateText) or rateText
    end
    if sessionEnabled and display.showLauncherSessionTime ~= false then
        local sessionTimeText = FormatSessionTime(self:GetSessionElapsedSeconds())
        line2Text = #line2Text > 0 and (line2Text .. "  |  " .. sessionTimeText) or sessionTimeText
    end
    if sessionEnabled and display.showLauncherSessionTotal ~= false and display.showLauncherSessionTime == false then
        local sdb = self.GetSessionDB and self:GetSessionDB() or {}
        local totalText = self:FormatMoneyText(sdb.totalSilver or 0) .. " total"
        line2Text = #line2Text > 0 and (line2Text .. "  |  " .. totalText) or totalText
    end

    if b.line2 then
        if #line2Text > 0 then
            SetFontStringTextIfChanged(b.line2, line2Text)
            b.line2:SetTextColor(ThemeMutedTextRGB())
            b.line2:Show()
        else
            SetFontStringTextIfChanged(b.line2, "")
            b.line2:Hide()
        end
    end

    if b.line3 then SetFontStringTextIfChanged(b.line3, ""); b.line3:Hide() end
    if b.line4 then SetFontStringTextIfChanged(b.line4, ""); b.line4:Hide() end
    if b.line5 then SetFontStringTextIfChanged(b.line5, ""); b.line5:Hide() end

    local previous = b.title
    local shownLineCount = 0
    if b.line1 then
        b.line1:ClearAllPoints()
        if b.line1:IsShown() then
            b.line1:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -6)
            b.line1:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -6)
            previous = b.line1
            shownLineCount = shownLineCount + 1
        end
    end
    if b.line2 then
        b.line2:ClearAllPoints()
        if b.line2:IsShown() then
            local yGap = shownLineCount == 0 and -6 or -3
            b.line2:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, yGap)
            b.line2:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, yGap)
            shownLineCount = shownLineCount + 1
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
    self:Print(T("Window scale: %s", string.format("%.2f", self.db.settings.panel.scale)))
end

function EL:ShowPanelFromSavedState()
    if not self.panel then return end
    self.db.settings.panel = self.db.settings.panel or {}
    self.db.settings.panel.charactersShown = true
    self.db.settings.panel.windowOpen = true
    -- Restore the main tracker only against UIParent. Anchoring the tracker
    -- to launcher/action frames can create anchor-family loops after secure
    -- action bar reparenting or third-party frame changes.
    SetFramePointFromDB(self.panel, self.db.settings.panel)
    self:ApplyPanelScale()
    self.panel:Show()
    if self.RequestUpdate then
        self:RequestUpdate(true)
    elseif self.RefreshPanel then
        self:RefreshPanel()
    end
    EnsureFrameOnScreen(self.panel, self.db.settings.panel)
    if self.LayoutActionBar then self:LayoutActionBar() end
    if self.RequestActionBarRefresh then self:RequestActionBarRefresh(true) end
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
    local settings = self.db and self.db.settings
    if not settings then return end

    local panelSettings = settings.panel or {}
    local sessionSettings = settings.session or {}
    local wantMain = panelSettings.charactersShown ~= false
    local wantSession = sessionSettings.shown ~= false and (not self.IsSessionTrackingEnabled or self:IsSessionTrackingEnabled())

    local mainShown = self.panel and self.panel:IsShown()
    local sessionShown = self.sessionWindow and self.sessionWindow:IsShown()
    local desiredWindowHidden = (wantMain and not mainShown) or (wantSession and not sessionShown)

    -- Launcher/minimap clicks should restore any enabled/preferred window that is missing.
    -- This keeps a closed Session window recoverable even while the main tracker is still open.
    if desiredWindowHidden then
        if wantMain and self.ShowPanelFromSavedState then
            self:ShowPanelFromSavedState()
        end
        if wantSession and self.ShowSessionWindow then
            self:ShowSessionWindow(true)
        elseif wantSession and self.ShowSessionWindowFromSavedState then
            self:ShowSessionWindowFromSavedState(true)
        end
        if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
        return
    end

    if mainShown and self.panel then
        self._suppressPanelWindowHideSetting = true
        self.panel:Hide()
        self._suppressPanelWindowHideSetting = false
        if settings.panel then
            settings.panel.charactersShown = true
            settings.panel.windowOpen = false
        end
    end
    if sessionShown and self.HideSessionWindow then
        self:HideSessionWindow(true)
    elseif sessionShown and self.sessionWindow then
        self.sessionWindow:Hide()
        if settings.session then
            settings.session.shown = true
            settings.session.windowOpen = false
        end
    end
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
    if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
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



-- Reset UI Settings is implemented in Modules/OptionsPanel.lua.


function EL:ShowButtonTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("EmberLedger"), 0.82, 0.88, 0.96)
    GameTooltip:AddLine(T("Quick launcher and window toggle."), 0.86, 0.86, 0.78, true)
    if self.GetNextProfessionCooldownSummary then
        local nextCooldown = self:GetNextProfessionCooldownSummary(time())
        if nextCooldown then
            if nextCooldown.ready then
                GameTooltip:AddLine(T("Next CD: Ready on %s", tostring(nextCooldown.characterName or "character")), 0.70, 0.90, 0.70, true)
            elseif nextCooldown.remaining and nextCooldown.remaining > 0 then
                GameTooltip:AddLine(T("Next CD: %s in %s", tostring(nextCooldown.characterName or "character"), self:FormatCountdown(nextCooldown.remaining)), 0.70, 0.90, 0.70, true)
            end
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: show, hide, or restore EmberLedger windows", 0.72, 0.72, 0.72)
    GameTooltip:AddLine("Right-click: lock or unlock launcher", 0.72, 0.72, 0.72)
    GameTooltip:AddLine("Shift-drag: move while locked", 0.72, 0.72, 0.72)
    GameTooltip:Show()
end

