local addonName, EL = ...

local ticker
local UIC = EL.UI_CONSTANTS or {}
local PANEL_MIN_W = UIC.PANEL_MIN_W or 352
local TRACKING_DYNAMIC_MIN_W = UIC.TRACKING_DYNAMIC_MIN_W or 260
local TRACKING_COMPACT_MIN_W = UIC.TRACKING_COMPACT_MIN_W or 236
local PANEL_MIN_H = UIC.PANEL_MIN_H or 120
local SESSION_MIN_W = UIC.SESSION_MIN_W or 320
local SESSION_EXPANDED_H = UIC.SESSION_EXPANDED_H or 162
local ACTION_BAR_H = UIC.ACTION_BAR_H or 36
local SESSION_VISIBLE_ITEM_ROWS = UIC.SESSION_VISIBLE_ITEM_ROWS or 4
local SESSION_ITEM_ROW_H = UIC.SESSION_ITEM_ROW_H or 18
local PANEL_DEFAULT_VISIBLE_ROWS = UIC.PANEL_DEFAULT_VISIBLE_ROWS or 12
local TRACKING_MAX_VISIBLE_ROWS = 20
local TRACKING_ROW_H = 23
local TRACKING_COMPACT_ROW_H = 18
local PANEL_EXPANDED_MIN_H = UIC.PANEL_EXPANDED_MIN_H or 300
local PANEL_MAX_W = UIC.PANEL_MAX_W or 900
local PANEL_MAX_H = UIC.PANEL_MAX_H or 720
local PANEL_MIN_SCALE = UIC.PANEL_MIN_SCALE or 0.6
local PANEL_MAX_SCALE = UIC.PANEL_MAX_SCALE or 1.4
local READY_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local PIN_GLOW_R, PIN_GLOW_G, PIN_GLOW_B = 1.00, 0.72, 0.18
local PIN_GLOW_ALPHA = 0.060
local PIN_ACCENT_ALPHA = 0.20
local PIN_HOVER_ALPHA = 0.040
local BORDER_R, BORDER_G, BORDER_B = 0.42, 0.36, 0.28
local BORDER_ALPHA_STRONG = 0.58
local BORDER_ALPHA_SOFT = 0.38
local HEADER_LINE_ALPHA_TOP = 0.09
local HEADER_LINE_ALPHA_BOTTOM = 0.18
local ROW_STRIPE_ALPHA = 0.40
local ROW_STRIPE_ALPHA_COMPACT = 0.36
local ROW_SEPARATOR_ALPHA = 0.10


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

local function GetTrackingBottomPadding(actionBarShown)
    -- Match the scroll frame's bottom anchor when the action bar is hidden so
    -- auto-height calculations do not clip the last visible character row.
    return actionBarShown and (GetTrackingActionBarBottomOffset() + ACTION_BAR_H + 8) or 34
end

local function ApplyTrackingTextStyle(row)
    if not row then return end
    local fontObject = IsCompactModeEnabled() and GameFontHighlightSmall or GameFontHighlight
    for _, fs in ipairs({row.name, row.prof1, row.conc1, row.prof2, row.conc2, row.mulch}) do
        if fs and fs.SetFontObject then fs:SetFontObject(fontObject) end
    end
end

local function ColorTextByRGB(text, r, g, b)
    r = math.max(0, math.min(1, tonumber(r) or 1))
    g = math.max(0, math.min(1, tonumber(g) or 1))
    b = math.max(0, math.min(1, tonumber(b) or 1))
    return string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), tostring(text or ""))
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
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    -- Reverted from the grey-stone experiment: keep the cleaner dark backdrop,
    -- while using Blizzard templates for buttons and scrollbars.
    frame:SetBackdropColor(0.018, 0.020, 0.026, alpha or 0.55)
    frame:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, borderAlpha or 0.55)
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
    if frame and frame.SetBackdropColor then
        frame:SetBackdropColor(0.018, 0.020, 0.026, alpha or 0.55)
    end
end

local function AddInnerBorder(frame)
    if not frame or frame.innerBorder then return end
    frame.innerBorder = frame:CreateTexture(nil, "BORDER")
    frame.innerBorder:SetPoint("TOPLEFT", 4, -4)
    frame.innerBorder:SetPoint("BOTTOMRIGHT", -4, 4)
    frame.innerBorder:SetColorTexture(0.75, 0.66, 0.48, 0.045)
end

local function StyleScrollBar(scrollFrame)
    -- Hide the visual scrollbar entirely while preserving normal mousewheel
    -- scrolling on the ScrollFrame/content area. The gutter is also reclaimed
    -- in LayoutPanel by anchoring the scroll frame closer to the right edge.
    if not scrollFrame then return end
    local name = scrollFrame:GetName()
    local bar = scrollFrame.ScrollBar or (name and _G[name .. "ScrollBar"])
    if bar then
        bar:Hide()
        if bar.SetAlpha then bar:SetAlpha(0) end
        if bar.EnableMouse then bar:EnableMouse(false) end
    end
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

local function ClearButtonTexture(button, getterName)
    if not button or not button[getterName] then return end
    local texture = button[getterName](button)
    if texture then
        texture:SetTexture(nil)
        texture:SetAlpha(0)
    end
end

local function DisableButtonArt(button)
    if not button then return end
    ClearButtonTexture(button, "GetNormalTexture")
    ClearButtonTexture(button, "GetPushedTexture")
    ClearButtonTexture(button, "GetHighlightTexture")
    ClearButtonTexture(button, "GetDisabledTexture")
end

local function GetCurrentPanelMinHeight(panel)
    local db = EL and EL.db
    local settings = db and db.settings and db.settings.panel or {}
    local charShown = settings.charactersShown ~= false
    settings.charactersCollapsed = false
    local actionBarShown = settings.actionBarShown ~= false and (not EL.IsActionBarEnabled or EL:IsActionBarEnabled())

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

local function ClampPanelSize(panel)
    if not panel then return end
    local minH = GetCurrentPanelMinHeight(panel)
    local minW = (EL.GetTrackingPanelMinWidth and EL:GetTrackingPanelMinWidth()) or PANEL_MIN_W
    local maxW = (EL.GetTrackingPanelMaxWidth and EL:GetTrackingPanelMaxWidth()) or PANEL_MAX_W
    local w = math.max(minW, math.min(maxW, panel:GetWidth() or minW))
    local h = math.max(minH, math.min(PANEL_MAX_H, panel:GetHeight() or minH))
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
    settings.charactersCollapsed = false
    local actionBarShown = settings.actionBarShown ~= false and (not self.IsActionBarEnabled or self:IsActionBarEnabled())

    local width = (self.GetTrackingPanelMaxWidth and self:GetTrackingPanelMaxWidth()) or PANEL_MIN_W
    local rowCount = charShown and math.min(TRACKING_MAX_VISIBLE_ROWS, self:GetVisibleTrackingRowCount()) or 0
    local tableBodyH = 0
    if charShown then
        tableBodyH = rowCount > 0 and (rowCount * GetTrackingRowHeight()) or 46
    end

    local topPadding = GetTrackingTopPadding()
    local headerAndGapH = charShown and ((IsCompactModeEnabled() and 28 or 32) + 4) or 0
    local bottomPadding = GetTrackingBottomPadding(actionBarShown)
    local height = topPadding + headerAndGapH + tableBodyH + bottomPadding
    height = math.max(GetCurrentPanelMinHeight(self.panel), math.min(PANEL_MAX_H, height))
    return math.floor(width + 0.5), math.floor(height + 0.5)
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
            settings.expandedHeight = math.max(PANEL_MIN_H, math.min(PANEL_MAX_H, h))
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

function EL:ToggleSessionSectionCollapsed()
    local settings = self.db and self.db.settings and self.db.settings.session
    if not settings then return end
    settings.collapsed = not (settings.collapsed and true or false)
    if self.LayoutSessionWindow then self:LayoutSessionWindow() end
    if self.RequestUpdate then self:RequestUpdate() end
end

local HEADER_LABELS = {
    character = "Character",
    prof1 = "P1",
    conc1 = "Conc 1",
    prof2 = "P2",
    conc2 = "Conc 2",
    mulch = "Mulch",
}

local TRACKING_COLUMN_DEFS = {
    { key = "character", label = "Character", width = 138, minWidth = 118, compactWidth = 112, compactMinWidth = 94, justify = "LEFT", sortKey = "character", alwaysVisible = true },
    { key = "prof1", label = "P1", width = 34, minWidth = 30, compactWidth = 28, compactMinWidth = 26, justify = "CENTER", sortKey = "prof1", setting = "showProfession1Column", toggleLabel = "Prof 1 column" },
    { key = "conc1", label = "Conc 1", width = 86, minWidth = 86, compactWidth = 68, compactMinWidth = 68, justify = "RIGHT", sortKey = "conc1", setting = "showConcentration1Column", toggleLabel = "Conc 1 column" },
    { key = "prof2", label = "P2", width = 34, minWidth = 30, compactWidth = 28, compactMinWidth = 26, justify = "CENTER", sortKey = "prof2", setting = "showProfession2Column", toggleLabel = "Prof 2 column", secondary = true },
    { key = "conc2", label = "Conc 2", width = 86, minWidth = 86, compactWidth = 68, compactMinWidth = 68, justify = "RIGHT", sortKey = "conc2", setting = "showConcentration2Column", toggleLabel = "Conc 2 column", secondary = true },
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

function EL:GetTrackingColumnSettings()
    self.db.settings = self.db.settings or {}
    self.db.settings.display = self.db.settings.display or {}
    local display = self.db.settings.display

    if display.showProfession1Column == nil then
        display.showProfession1Column = display.showProfessionColumn ~= false
    end
    if display.showConcentration1Column == nil then
        display.showConcentration1Column = display.showConcentrationColumn ~= false
    end
    if display.showProfession2Column == nil then display.showProfession2Column = true end
    if display.showConcentration2Column == nil then display.showConcentration2Column = true end
    if display.showMulchColumn == nil then display.showMulchColumn = true end
    if display.showCharacterRealm == nil then display.showCharacterRealm = true end

    display.showProfession1Column = display.showProfession1Column ~= false
    display.showConcentration1Column = display.showConcentration1Column ~= false
    display.showProfession2Column = display.showProfession2Column ~= false
    display.showConcentration2Column = display.showConcentration2Column ~= false
    display.showMulchColumn = display.showMulchColumn ~= false
    display.showCharacterRealm = display.showCharacterRealm ~= false

    -- Keep legacy keys in sync for older saved variables and older code paths.
    display.showProfessionColumn = display.showProfession1Column
    display.showConcentrationColumn = display.showConcentration1Column

    if display.showProfession1Column == false and display.showConcentration1Column == false and display.showProfession2Column == false and display.showConcentration2Column == false and display.showMulchColumn == false then
        display.showProfession1Column = true
        display.showProfessionColumn = true
    end
    return display
end

function EL:IsTrackingColumnVisible(key)
    if key == "prof" then key = "prof1" end
    if key == "conc" then key = "conc1" end
    if key == "character" then return true end
    local def = TRACKING_COLUMN_BY_KEY[key]
    if not def or not def.setting then return false end
    if def.secondary and not self:HasSecondaryConcentrationColumnData() then return false end
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
    if self.ApplyDisplaySettings then self:ApplyDisplaySettings() end
    if self.LayoutPanel then self:LayoutPanel() end
    if self.LayoutSessionWindow then self:LayoutSessionWindow() end
    if self.UpdateActionBar then self:UpdateActionBar() end
    if self.UpdateButton then self:UpdateButton() end
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
end

local function StyleBlizzardButton(button)
    if not button then return end
    if button.SetNormalFontObject then button:SetNormalFontObject(GameFontNormalSmall) end
    if button.SetHighlightFontObject then button:SetHighlightFontObject(GameFontHighlightSmall) end
    if button.SetDisabledFontObject then button:SetDisabledFontObject(GameFontDisableSmall) end
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

function EL:ConfirmRestoreHiddenCharacters()
    ShowSettingsConfirm("Unhide all hidden characters and return them to the tracking table?", "Unhide All", function()
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
    f:SetScript("OnDragStart", function(self) if not (EL.db.settings.lockWindows == true) or IsShiftKeyDown() then self:StartMoving() end end)
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
        {"Display", "Interface\\Icons\\INV_Misc_Spyglass_03"},
        {"Launcher", "Interface\\Icons\\INV_Misc_Rune_01"},
        {"Session", "Interface\\Icons\\INV_Misc_Coin_01"},
        {"Tracking", "Interface\\Icons\\INV_Inscription_Tradeskill01"},
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

    f.generalSection = MakeSettingsSection(f, "General Controls", contentX, -42, contentW, 144)
    f.showLauncher = MakeSettingsCheck(f.generalSection, "Show launcher", function() EL:ToggleSectionSetting("launcher") end)
    f.showLauncher:SetPoint("TOPLEFT", 12, -36)
    f.toggleCharactersSection = MakeSettingsCheck(f.generalSection, "Show tracking window", function() EL:ToggleSectionSetting("characters") end)
    f.toggleCharactersSection:SetPoint("TOPLEFT", 12, -62)
    f.toggleSessionSection = MakeSettingsCheck(f.generalSection, "Show session window", function() EL:ToggleSectionSetting("session") end)
    f.toggleSessionSection:SetPoint("TOPLEFT", 238, -36)
    SetSettingsTooltip(f.toggleSessionSection, "Show session window", {"Toggles only the standalone Session window.", "Launcher session lines are controlled separately on the Launcher page."})
    f.lockWindows = MakeSettingsCheck(f.generalSection, "Lock windows", function() EL:ToggleLockWindows() end)
    f.lockWindows:SetPoint("TOPLEFT", 238, -62)
    f.toggleAttentionOnly = MakeSettingsCheck(f.generalSection, "Attention Only view", function() EL:ToggleDisplaySetting("attentionOnly") end)
    f.toggleAttentionOnly:SetPoint("TOPLEFT", 12, -88)
    f.toggleCompactMode = MakeSettingsCheck(f.generalSection, "Compact tracking rows", function() EL:ToggleDisplaySetting("compactMode") end)
    f.toggleCompactMode:SetPoint("TOPLEFT", 238, -88)
    f.togglePinnedFirst = MakeSettingsCheck(f.generalSection, "Show pinned first", function() EL:ToggleDisplaySetting("showPinnedFirst") end)
    f.togglePinnedFirst:SetPoint("TOPLEFT", 12, -114)
    f.toggleCurrentCharacterHighlight = MakeSettingsCheck(f.generalSection, "Highlight current character", function() EL:ToggleDisplaySetting("highlightCurrentCharacter") end)
    f.toggleCurrentCharacterHighlight:SetPoint("TOPLEFT", 238, -114)
    SetSettingsTooltip(f.toggleCurrentCharacterHighlight, "Highlight current character", {"Adds a subtle row highlight to the character you are currently playing.", "This does not change sorting or tracking behavior."})

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

    f.thresholdSection = MakeSettingsSection(f, "Concentration Threshold", contentX, -498, contentW, 92)
    f.thresholdSlider = MakeSettingsSlider(f.thresholdSection, "Concentration ready threshold", 0, 1000, 10, function(v) return tostring(math.floor(v + 0.5)) end, function(v)
        EL:SetAbsoluteSetting("concThreshold", math.floor(v + 0.5))
    end)
    f.thresholdSlider:SetPoint("TOPLEFT", 12, -38)

    f.trackingColumnsSection = MakeSettingsSection(f, "Tracking Table", contentX, -598, contentW, 124)
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
    f.toggleMulchColumn = MakeSettingsCheck(f.trackingColumnsSection, "Show Imbued Mulch column", function() EL:ToggleTrackingColumn("mulch") end)
    f.toggleMulchColumn:SetPoint("TOPLEFT", trackingColumnLeftX, -86)
    f.toggleCharacterRealm = MakeSettingsCheck(f.trackingColumnsSection, "Show character realm", function() EL:ToggleDisplaySetting("showCharacterRealm") end)
    f.toggleCharacterRealm:SetPoint("TOPLEFT", trackingColumnRightX, -86)
    f.launcherSection = MakeSettingsSection(f, "Launcher Display", contentX, -598, contentW, 88)
    f.toggleConc = MakeSettingsCheck(f.launcherSection, "Concentration alert", function() EL:ToggleDisplaySetting("showLauncherConc") end)
    f.toggleConc:SetPoint("TOPLEFT", 12, -34)
    f.toggleMulch = MakeSettingsCheck(f.launcherSection, "Mulch", function() EL:ToggleDisplaySetting("showLauncherMulch") end)
    f.toggleMulch:SetPoint("TOPLEFT", 178, -34)
    f.toggleSession = MakeSettingsCheck(f.launcherSection, "Session rate", function() EL:ToggleDisplaySetting("showLauncherSession") end)
    f.toggleSession:SetPoint("TOPLEFT", 294, -34)
    SetSettingsTooltip(f.toggleSession, "Launcher session rate", {"Controls the gold-per-hour line on the launcher only.", "This does not show or hide the standalone Session window."})
    f.toggleTotal = MakeSettingsCheck(f.launcherSection, "Session total", function() EL:ToggleDisplaySetting("showLauncherSessionTotal") end)
    f.toggleTotal:SetPoint("TOPLEFT", 12, -56)
    SetSettingsTooltip(f.toggleTotal, "Launcher session total", {"Controls the session total line on the launcher only.", "This does not show or hide the standalone Session window."})
    f.toggleTime = MakeSettingsCheck(f.launcherSection, "Session time", function() EL:ToggleDisplaySetting("showLauncherSessionTime") end)
    f.toggleTime:SetPoint("TOPLEFT", 178, -56)
    SetSettingsTooltip(f.toggleTime, "Launcher session time", {"Controls the session timer line on the launcher only.", "This does not show or hide the standalone Session window."})

    f.sessionOptions = MakeSettingsSection(f, "Session Tracking", contentX, -698, contentW, 132)
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
    f.pricingSourceLabel = f.sessionOptions:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.pricingSourceLabel:SetPoint("TOPLEFT", 238, -88)
    f.pricingSourceLabel:SetText("Pricing:")
    f.pricingSourceLabel:SetTextColor(0.76, 0.76, 0.70)
    f.pricingSourceValue = f.sessionOptions:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.pricingSourceValue:SetPoint("LEFT", f.pricingSourceLabel, "RIGHT", 5, 0)
    f.pricingSourceValue:SetTextColor(1.00, 0.92, 0.56)

    f.actionSection = MakeSettingsSection(f, "Action Bar", contentX, -42, contentW, 74)
    f.toggleActionBar = MakeSettingsCheck(f.actionSection, "Show action bar", function() EL:ToggleSectionSetting("actions") end)
    f.toggleActionBar:SetPoint("TOPLEFT", 10, -34)
    SetSettingsTooltip(f.toggleActionBar, "Show action bar", {"Toggles the compact EmberLedger action bar.", "Individual buttons can still be enabled or disabled below."})

    f.actionButtonsSection = MakeSettingsSection(f, "Button Visibility", contentX, -128, contentW, 232)
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
    SetSettingsTooltip(f.toggleCharactersSection, "Show tracking window", {"Shows or hides the main character tracking window."})
    SetSettingsTooltip(f.toggleSessionSection, "Show session window", {"Toggles only the standalone Session window.", "Launcher session lines are controlled separately on the Launcher page."})
    SetSettingsTooltip(f.lockWindows, "Lock windows", {"Prevents EmberLedger windows from being dragged unless Shift is held."})
    SetSettingsTooltip(f.toggleAttentionOnly, "Attention Only view", {"Shows only characters with concentration or mulch states that need attention."})
    SetSettingsTooltip(f.toggleCompactMode, "Compact tracking rows", {"Uses tighter tracking rows and hides extra header text in compact mode."})
    SetSettingsTooltip(f.togglePinnedFirst, "Show pinned first", {"Keeps pinned characters above unpinned characters when sorting the tracking table."})
    SetSettingsTooltip(f.toggleCurrentCharacterHighlight, "Highlight current character", {"Adds a subtle row highlight to the character you are currently playing.", "This does not change sorting or tracking behavior."})

    SetSettingsTooltip(f.toggleProf1Column, "Show Prof 1 column", {"Shows the first tracked profession column in the main tracking table."})
    SetSettingsTooltip(f.toggleConc1Column, "Show Conc 1 column", {"Shows the first concentration column in the main tracking table."})
    SetSettingsTooltip(f.toggleProf2Column, "Allow Prof 2 column", {"Allows the second profession column when tracked data needs it."})
    SetSettingsTooltip(f.toggleConc2Column, "Allow Conc 2 column", {"Allows the second concentration column when tracked data needs it."})
    SetSettingsTooltip(f.toggleMulchColumn, "Show Imbued Mulch column", {"Shows or hides the Imbued Mulch readiness column in the tracking table."})
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

    SetSettingsTooltip(f.toggleActionBar, "Show action bar", {"Toggles the compact EmberLedger action bar.", "Individual buttons can still be enabled or disabled below."})
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

    f.performanceSection = MakeSettingsSection(f, "Performance", contentX, -42, contentW, 124)
    f.enableSessionTracking = MakeSettingsCheck(f.performanceSection, "Enable session tracking", function() EL:TogglePerformanceSetting("sessionTracking") end)
    f.enableSessionTracking:SetPoint("TOPLEFT", 12, -36)
    f.enableActionBar = MakeSettingsCheck(f.performanceSection, "Enable action bar", function() EL:TogglePerformanceSetting("actionBar") end)
    f.enableActionBar:SetPoint("TOPLEFT", 12, -64)
    SetSettingsTooltip(f.enableSessionTracking, "Enable session tracking", {"Tracks session time, gathered items, and session value.", "Turn off to stop most background loot and bag processing."})
    SetSettingsTooltip(f.enableActionBar, "Enable action bar", {"Allows EmberLedger utility buttons in the main window.", "Turn off to hide the bar and skip action bar refresh work."})

    f.maintenanceSection = MakeSettingsSection(f, "Maintenance / Resets", contentX, -372, contentW, 154)
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
    SetSettingsTooltip(f.resetPos, "Reset Windows", {"Returns EmberLedger windows to their default screen positions.", "Scale and visibility settings are kept."})
    SetSettingsTooltip(f.resetSession, "Reset Session", {"Clears current session totals and tracked items."})
    SetSettingsTooltip(f.resetHidden, "Unhide All", {"Restores every hidden character to the main tracking table."})
    SetSettingsTooltip(f.resetPinned, "Reset Pinned", {"Removes all pinned character markers without deleting character data."})

    f.footerSection = MakeSettingsSection(f, "Information", contentX, -846, contentW, 78)
    f.versionLabel = f.footerSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.versionLabel:SetPoint("TOPLEFT", 12, -34)
    f.versionLabel:SetText("Version: " .. tostring(EL.version or "1.3.2"))
    f.versionLabel:SetTextColor(0.88, 0.86, 0.78)
    f.copySummary = MakeSettingsButton(f.footerSection, "Copy Summary", 112, function() EL:ShowCopySessionSummaryDialog() end)
    f.copySummary:SetPoint("TOPRIGHT", -12, -32)

    f.allSettingsSections = {
        f.generalSection,
        f.appearanceSection,
        f.scaleSection,
        f.thresholdSection,
        f.trackingColumnsSection,
        f.launcherSection,
        f.sessionOptions,
        f.actionSection,
        f.actionButtonsSection,
        f.performanceSection,
        f.maintenanceSection,
        f.footerSection,
    }
    f.settingsPages = {
        General = {f.generalSection, f.footerSection},
        Display = {f.appearanceSection, f.scaleSection},
        Launcher = {f.launcherSection},
        Session = {f.sessionOptions},
        Tracking = {f.thresholdSection, f.trackingColumnsSection},
        ["Action Bar"] = {f.actionSection, f.actionButtonsSection},
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
    local display = self.db.settings.display
    local alerts = self.db.settings.alerts
    if f.panelOpacityValue then f.panelOpacityValue:SetText(string.format("%d%%", math.floor((tonumber(display.panelOpacity) or 0.55) * 100 + 0.5))) end
    if f.launcherOpacityValue then f.launcherOpacityValue:SetText(string.format("%d%%", math.floor((tonumber(display.launcherOpacity) or 0.50) * 100 + 0.5))) end
    if f.sessionOpacityValue then f.sessionOpacityValue:SetText(string.format("%d%%", math.floor((tonumber(display.sessionOpacity) or 0.55) * 100 + 0.5))) end
    if f.thresholdValue then f.thresholdValue:SetText(tostring(tonumber(alerts.concentrationThreshold) or 360)) end
    SetSliderValue(f.panelOpacitySlider, math.floor((tonumber(display.panelOpacity) or 0.55) * 100 + 0.5))
    SetSliderValue(f.launcherOpacitySlider, math.floor((tonumber(display.launcherOpacity) or 0.50) * 100 + 0.5))
    SetSliderValue(f.sessionOpacitySlider, math.floor((tonumber(display.sessionOpacity) or 0.55) * 100 + 0.5))
    SetSliderValue(f.thresholdSlider, tonumber(alerts.concentrationThreshold) or 360)
    SetSliderValue(f.scaleSlider, math.floor(((self.db.settings.panel and tonumber(self.db.settings.panel.scale)) or 1) * 100 + 0.5))
    SetSliderValue(f.sessionScaleSlider, math.floor(((self.db.settings.session and tonumber(self.db.settings.session.scale)) or 1) * 100 + 0.5))
    local function setToggle(btn, on)
        if not btn then return end
        if btn.SetChecked then btn:SetChecked(on and true or false) end
        if btn.text then btn.text:SetTextColor(on and 0.95 or 0.55, on and 0.92 or 0.58, on and 0.80 or 0.62) end
    end
    setToggle(f.showLauncher, self.db.settings.button and self.db.settings.button.shown ~= false)
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
    setToggle(f.toggleMulchColumn, trackingDisplay.showMulchColumn ~= false)
    setToggle(f.toggleCharacterRealm, display.showCharacterRealm ~= false)
    setToggle(f.toggleAttentionOnly, display.attentionOnly == true)
    setToggle(f.toggleCompactMode, display.compactMode == true)
    setToggle(f.togglePinnedFirst, display.showPinnedFirst ~= false)
    setToggle(f.toggleCurrentCharacterHighlight, display.highlightCurrentCharacter ~= false)
    local panelSettings = self.db.settings.panel or {}
    local sessionSettings = self.db.settings.session or {}
    local performanceSettings = self.db.settings.performance or {}
    setToggle(f.enableSessionTracking, performanceSettings.sessionTracking ~= false)
    setToggle(f.enableActionBar, performanceSettings.actionBar ~= false)
    setToggle(f.toggleCharactersSection, panelSettings.charactersShown ~= false)
    setToggle(f.toggleSessionSection, sessionSettings.shown ~= false)
    setToggle(f.toggleActionBar, panelSettings.actionBarShown ~= false)
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
    local actionControlsAlpha = (performanceSettings.actionBar ~= false) and 1.0 or 0.45
    for _, btn in ipairs({ f.toggleActionBar, f.actionMulchButton, f.actionSeedButton, f.actionGlowingSeedButton, f.actionWildSeedButton, f.actionPrimalSeedButton, f.actionGreenThumbButton, f.actionOverloadHerbButton, f.actionOverloadOreButton, f.actionParcelButton, f.actionBankButton }) do
        if btn and btn.SetAlpha then btn:SetAlpha(actionControlsAlpha) end
    end
    local sessionControlsAlpha = (performanceSettings.sessionTracking ~= false) and 1.0 or 0.45
    for _, btn in ipairs({ f.toggleSessionSection, f.filterHerbs, f.filterOre, f.filterCloth, f.filterLeather, f.filterEnchanting, f.filterFish, f.filterOther, f.resetSession }) do
        if btn and btn.SetAlpha then btn:SetAlpha(sessionControlsAlpha) end
    end
    setToggle(f.filterHerbs, sessionSettings.trackHerbs ~= false)
    setToggle(f.filterOre, sessionSettings.trackOre ~= false)
    setToggle(f.filterCloth, sessionSettings.trackCloth ~= false)
    setToggle(f.filterLeather, sessionSettings.trackLeather ~= false)
    setToggle(f.filterEnchanting, sessionSettings.trackEnchanting ~= false)
    setToggle(f.filterFish, sessionSettings.trackFish ~= false)
    setToggle(f.filterOther, sessionSettings.trackOtherMaterials ~= false)
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
    self:RefreshSettingsPanel()
    self:SelectSettingsPage(self.settingsPanel.currentPage or "General")
    self.settingsPanel:Show()
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
    if kind == "concThreshold" then
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
    if kind == "concThreshold" then
        -- Force an immediate visible recolor when the dynamic gradient target changes.
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
    compactMode = "Compact tracking rows",
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
    characters = "Tracking window",
    session = "Session window",
    actions = "Action bar",
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
    mulch = "Mulch column",
}

local TRACKING_COLUMN_SETTING_KEYS = {
    prof = "showProfession1Column",
    conc = "showConcentration1Column",
    prof1 = "showProfession1Column",
    conc1 = "showConcentration1Column",
    prof2 = "showProfession2Column",
    conc2 = "showConcentration2Column",
    mulch = "showMulchColumn",
}

function EL:ToggleTrackingColumn(key)
    local settingKey = TRACKING_COLUMN_SETTING_KEYS[key]
    if not settingKey then return end
    local display = self:GetTrackingColumnSettings()
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
    local enabled = not (self.db.settings.display[key] ~= false)
    self.db.settings.display[key] = enabled
    self:NotifyToggle(DISPLAY_TOGGLE_LABELS[key] or key, enabled)
    if (key == "showCharacterRealm" or key == "attentionOnly" or key == "compactMode" or key == "showPinnedFirst") and self.AutoSizeTrackingPanel then
        self:AutoSizeTrackingPanel(key .. "Toggle")
    end
    if key == "highlightCurrentCharacter" and self.RefreshPanel then
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
        if enabled then
            if self:IsActionBarEnabled() and self.RequestActionBarRefresh then self:RequestActionBarRefresh() end
        elseif self.panel and self.panel.actionBar then
            self.panel.actionBar:Hide()
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
    elseif section == "characters" then
        local shouldShow = not (self.db.settings.panel.windowOpen == true and self.panel and self.panel:IsShown())
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
    elseif section == "actions" then
        self.db.settings.panel.actionBarShown = not (self.db.settings.panel.actionBarShown ~= false)
        self:NotifyToggle(SECTION_TOGGLE_LABELS.actions, self.db.settings.panel.actionBarShown ~= false)
    end

    if section == "session" then
        -- Session is now a standalone window. Toggling it from options should
        -- not resize or relayout the main EmberLedger panel.
        if self.LayoutSessionWindow then self:LayoutSessionWindow() end
    elseif self:IsCombatLocked() and section == "actions" then
        self.pendingSecureLayout = true
        self:Print("Convenience bar visibility will update after combat.")
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
    canvas.version:SetText("Version " .. tostring(self.version or "1.3.2"))

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

function EL:CreateUI()
    if self.uiCreated then return end
    self.uiCreated = true
    self:CreateMainButton()
    self:CreatePanel()
    self:CreateSessionWindow()
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
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(1, function() EL:RequestUpdate() end)
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
    AddBackdrop(button, GetLauncherOpacity(), 0.50)
    AddInnerBorder(button)
    if button.SetBackdropColor then button:SetBackdropColor(0.018, 0.020, 0.026, GetLauncherOpacity()) end
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


local function GetItemIconByIDOrName(itemID, itemName, fallback)
    if itemID and GetItemInfoInstant then
        local _, _, _, _, icon = GetItemInfoInstant(itemID)
        if icon then return icon end
    end
    if itemName and GetItemInfoInstant then
        local _, _, _, _, icon = GetItemInfoInstant(itemName)
        if icon then return icon end
    end
    return fallback or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetSpellIconSafe(spellID, spellName, fallback)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID or spellName)
        if ok and info and info.iconID then return info.iconID end
    end
    if GetSpellInfo then
        local ok, _, _, icon = pcall(GetSpellInfo, spellID or spellName)
        if ok and icon then return icon end
    end
    return fallback or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetToyIconSafe(itemID, itemName, fallback)
    if itemID and C_ToyBox and C_ToyBox.GetToyInfo then
        local ok, _, name, icon = pcall(C_ToyBox.GetToyInfo, itemID)
        if ok and icon then return icon end
    end
    return GetItemIconByIDOrName(itemID, itemName, fallback)
end


local ACTION_ZONE_GROUPS = {
    khazAlgar = {
        ["Khaz Algar"] = true,
        ["Isle of Dorn"] = true,
        ["Dornogal"] = true,
        ["The Ringing Deeps"] = true,
        ["Hallowfall"] = true,
        ["Azj-Kahet"] = true,
        ["City of Threads"] = true,
    },
    midnight = {
        ["Midnight"] = true,
        ["Quel'Thalas"] = true,
        ["Eversong Woods"] = true,
        ["Silvermoon City"] = true,
        ["Zul'Aman"] = true,
        ["Harandar"] = true,
        ["Voidstorm"] = true,
    },
}

local function IsActionZoneAllowed(zoneGroup)
    if not zoneGroup then return true end
    local allowed = ACTION_ZONE_GROUPS[zoneGroup]
    if not allowed then return true end
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetMapInfo then return true end

    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not mapID then return true end

    local checked = 0
    while mapID and checked < 8 do
        local okInfo, info = pcall(C_Map.GetMapInfo, mapID)
        if okInfo and info then
            if info.name and allowed[info.name] then return true end
            mapID = info.parentMapID
        else
            break
        end
        checked = checked + 1
    end

    return false
end

local function IsActionVariantZoneAllowed(variant, info)
    local zoneGroup = variant and variant.zoneGroup or info and info.zoneGroup
    return IsActionZoneAllowed(zoneGroup)
end

local ResolveActionSpell

local function GetActionIcon(info)
    if info.kind == "spell" then
        local resolved = ResolveActionSpell and ResolveActionSpell(info)
        if resolved then return GetSpellIconSafe(resolved.spellID, resolved.name, resolved.fallback or info.fallback) end
        return GetSpellIconSafe(info.spellID, info.name, info.fallback)
    elseif info.kind == "toy" then
        return GetToyIconSafe(info.itemID, info.name, info.fallback)
    else
        return GetItemIconByIDOrName(info.itemID, info.name, info.fallback)
    end
end

local function GetItemCountSafe(itemID, itemName)
    local item = itemID or itemName
    if not item then return 0 end
    if C_Item and C_Item.GetItemCount then
        local ok, count = pcall(C_Item.GetItemCount, item, false, false, false, true)
        if ok and tonumber(count) then return tonumber(count) end
        ok, count = pcall(C_Item.GetItemCount, item)
        if ok and tonumber(count) then return tonumber(count) end
    end
    if GetItemCount then
        local ok, count = pcall(GetItemCount, item, false, false, true)
        if ok and tonumber(count) then return tonumber(count) end
        ok, count = pcall(GetItemCount, item)
        if ok and tonumber(count) then return tonumber(count) end
    end
    return 0
end

local function PlayerHasToySafe(itemID)
    if not itemID then return false end
    if C_ToyBox and C_ToyBox.PlayerHasToy then
        local ok, hasToy = pcall(C_ToyBox.PlayerHasToy, itemID)
        if ok then return hasToy and true or false end
    end
    if PlayerHasToy then
        local ok, hasToy = pcall(PlayerHasToy, itemID)
        if ok then return hasToy and true or false end
    end
    return false
end

local function PlayerKnowsSpellSafe(spellID, spellName)
    if spellID then
        if IsPlayerSpell then
            local ok, known = pcall(IsPlayerSpell, spellID)
            if ok and known then return true end
        end
        if C_SpellBook and C_SpellBook.IsSpellKnown then
            local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
            if ok and known then return true end
        end
        if C_SpellBook and C_SpellBook.IsSpellKnownOrOverridesKnown then
            local ok, known = pcall(C_SpellBook.IsSpellKnownOrOverridesKnown, spellID)
            if ok and known then return true end
        end
    end
    if spellName and GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellName)
        if ok and name then return true end
    end
    return false
end

ResolveActionSpell = function(info)
    if not info then return nil end

    if info.spellVariants then
        for _, variant in ipairs(info.spellVariants) do
            local spellID = variant.spellID
            local spellName = variant.name or info.name
            if IsActionVariantZoneAllowed(variant, info) and PlayerKnowsSpellSafe(spellID, spellName) then
                return {
                    spellID = spellID,
                    name = spellName,
                    label = variant.label or info.label or spellName,
                    zoneGroup = variant.zoneGroup or info.zoneGroup,
                    fallback = variant.fallback or info.fallback,
                }
            end
        end
        return nil
    end

    if not IsActionZoneAllowed(info.zoneGroup) then return nil end
    if info.spellID and PlayerKnowsSpellSafe(info.spellID, info.name) then
        return { spellID = info.spellID, name = info.name, label = info.label or info.name, zoneGroup = info.zoneGroup, fallback = info.fallback }
    end
    if info.spellIDs then
        for _, spellID in ipairs(info.spellIDs) do
            if PlayerKnowsSpellSafe(spellID, info.name) then
                return { spellID = spellID, name = info.name, label = info.label or info.name, zoneGroup = info.zoneGroup, fallback = info.fallback }
            end
        end
    end
    if info.name and PlayerKnowsSpellSafe(nil, info.name) then
        return { spellID = nil, name = info.name, label = info.label or info.name, zoneGroup = info.zoneGroup, fallback = info.fallback }
    end
    return nil
end

local function ResolveKnownSpellID(info)
    local resolved = ResolveActionSpell(info)
    return resolved and (resolved.spellID or resolved.name) or nil
end

local function GetActionAvailable(info)
    if info.kind == "toy" then
        return PlayerHasToySafe(info.itemID)
    elseif info.kind == "spell" then
        return ResolveActionSpell(info) ~= nil
    else
        if info.zoneGroup and not IsActionZoneAllowed(info.zoneGroup) then return false end
        return GetItemCountSafe(info.itemID, info.name) > 0
    end
end

local function GetActionCooldownSafe(info)
    if not info then return 0, 0, 0 end
    if info.kind == "spell" then
        local spell = ResolveKnownSpellID(info)
        if not spell then return 0, 0, 0 end
        if C_Spell and C_Spell.GetSpellCooldown then
            local ok, cd = pcall(C_Spell.GetSpellCooldown, spell)
            if ok and cd then
                return cd.startTime or 0, cd.duration or 0, cd.isEnabled and 1 or 0
            end
        end
        if GetSpellCooldown then
            local ok, start, duration, enable = pcall(GetSpellCooldown, spell)
            if ok and start then return start or 0, duration or 0, enable or 0 end
        end
        return 0, 0, 0
    elseif info.kind == "toy" then
        if info.itemID and C_ToyBox and C_ToyBox.GetToyCooldown then
            local ok, start, duration, enable = pcall(C_ToyBox.GetToyCooldown, info.itemID)
            if ok and start then return start or 0, duration or 0, enable or 0 end
        end
        if info.itemID and C_Item and C_Item.GetItemCooldown then
            local ok, start, duration, enable = pcall(C_Item.GetItemCooldown, info.itemID)
            if ok and start then return start or 0, duration or 0, enable or 0 end
        end
        if info.itemID and GetItemCooldown then
            local ok, start, duration, enable = pcall(GetItemCooldown, info.itemID)
            if ok and start then return start or 0, duration or 0, enable or 0 end
        end
        return 0, 0, 0
    else
        local item = info.itemID or info.name
        if not item then return 0, 0, 0 end
        if C_Container and C_Container.GetItemCooldown then
            local ok, start, duration, enable = pcall(C_Container.GetItemCooldown, item)
            if ok and start then return start or 0, duration or 0, enable or 0 end
        end
        if C_Item and C_Item.GetItemCooldown then
            local ok, start, duration, enable = pcall(C_Item.GetItemCooldown, item)
            if ok and start then return start or 0, duration or 0, enable or 0 end
        end
        if GetItemCooldown then
            local ok, start, duration, enable = pcall(GetItemCooldown, item)
            if ok and start then return start or 0, duration or 0, enable or 0 end
        end
        return 0, 0, 0
    end
end


local function SetSpellButtonAttributes(button, info)
    if not button or not info or info.kind ~= "spell" then return end
    local resolved = ResolveActionSpell(info)
    local spellName = (resolved and resolved.name) or info.name or info.label or ""
    local macrotext = "/cast " .. tostring(spellName)
    button:SetAttribute("type", "macro")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext", macrotext)
    button:SetAttribute("macrotext1", macrotext)
    button.resolvedSpell = resolved
end

local function MakeIconActionButton(parent, info)
    -- Secure action buttons must not call UseItemByName or Logout directly.
    -- This mirrors the working MulchTracker pattern, with explicit left-click
    -- attributes added for compatibility with action button handling.
    local name = "EmberLedgerActionButton_" .. tostring(info.key or math.random(100000))
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetSize(26, 26)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:EnableMouse(true)

    if info.kind == "item" then
        local itemRef = info.itemID and ("item:" .. tostring(info.itemID)) or tostring(info.name or info.label or "")
        b:SetAttribute("type", "item")
        b:SetAttribute("type1", "item")
        b:SetAttribute("item", itemRef)
        b:SetAttribute("item1", itemRef)
    elseif info.kind == "toy" then
        local macrotext = info.name and ("/use " .. tostring(info.name)) or (info.itemID and ("/use item:" .. tostring(info.itemID)) or "")
        b:SetAttribute("type", "macro")
        b:SetAttribute("type1", "macro")
        b:SetAttribute("macrotext", macrotext)
        b:SetAttribute("macrotext1", macrotext)
    elseif info.kind == "spell" then
        SetSpellButtonAttributes(b, info)
    else
        local macrotext = "/use " .. tostring(info.name or info.label or "")
        b:SetAttribute("type", "macro")
        b:SetAttribute("type1", "macro")
        b:SetAttribute("macrotext", macrotext)
        b:SetAttribute("macrotext1", macrotext)
    end

    b.actionInfo = info
    b.actionKey = info.key
    b.actionLabel = info.label or info.name
    b.hideWhenMissing = info.hideWhenMissing and true or false

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0, 0, 0, 0.42)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon:SetTexture(GetActionIcon(info))

    b.border = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.border:EnableMouse(false)
    b.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    b.border:SetBackdropBorderColor(0.62, 0.50, 0.25, 0.78)

    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)
    b.cooldown:EnableMouse(false)

    b.highlight = b:CreateTexture(nil, "HIGHLIGHT")
    b.highlight:SetAllPoints(b.icon)
    b.highlight:SetColorTexture(1, 0.82, 0.35, 0.16)

    b:SetScript("OnEnter", function(self)
        local inf = self.actionInfo or {}
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if inf.kind == "spell" then
            local resolved = self.resolvedSpell or ResolveActionSpell(inf)
            if resolved and resolved.spellID and GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(resolved.spellID)
            else
                GameTooltip:SetText((resolved and resolved.label) or self.actionLabel or "Spell", 1, 0.82, 0.24)
            end
            if inf.zoneGroup then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Hidden outside the matching expansion zones.", 0.72, 0.72, 0.72)
            end
        elseif inf.kind == "toy" then
            if inf.itemID then GameTooltip:SetItemByID(inf.itemID) else GameTooltip:SetText(self.actionLabel or "Toy", 1, 0.82, 0.24) end
        else
            if inf.itemID then GameTooltip:SetHyperlink("item:" .. tostring(inf.itemID)) else GameTooltip:SetText(self.actionLabel or "Item", 1, 0.82, 0.24) end
            local count = GetItemCountSafe(inf.itemID, inf.name)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Available", tostring(count or 0), 0.72, 0.72, 0.72, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function MakeLogoutButton(parent)
    -- Visible Blizzard button with a secure child owning the actual hardware click.
    -- This matches the MulchTracker pattern and avoids protected Logout() calls.
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(72, 28)
    button:SetText("Logout")
    StyleBlizzardButton(button)

    local secure = CreateFrame("Button", "EmberLedgerSecureLogoutButton", button, "SecureActionButtonTemplate")
    secure:SetAllPoints(button)
    secure:SetFrameLevel((button:GetFrameLevel() or 1) + 10)
    secure:EnableMouse(true)
    secure:RegisterForClicks("AnyUp", "AnyDown")
    secure:SetAttribute("type", "macro")
    secure:SetAttribute("type1", "macro")
    secure:SetAttribute("macrotext", "/logout")
    secure:SetAttribute("macrotext1", "/logout")

    secure:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Logout", 1, 0.82, 0.24)
        GameTooltip:AddLine("Secure logout button.", 0.72, 0.72, 0.72)
        GameTooltip:Show()
    end)
    secure:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button.secure = secure
    return button
end

local ACTION_ITEM_BUTTONS = {
    { key = "mulch", kind = "item", label = "Imbued Mulch", name = "Imbued Mulch", itemID = EL.IMBUED_MULCH_ITEM_ID, fallback = "Interface\\Icons\\INV_Misc_Herb_01", hideWhenMissing = false },
    { key = "seed", kind = "item", label = "Resilient Seed", name = "Resilient Seed", itemID = 237497, fallback = "Interface\\Icons\\INV_Misc_Herb_06", zoneGroup = "midnight", hideWhenMissing = true },
    { key = "glowingSeed", kind = "item", label = "Glowing Resilient Seed", name = "Glowing Resilient Seed", itemID = 237498, fallback = "Interface\\Icons\\INV_Misc_Herb_06", zoneGroup = "midnight", hideWhenMissing = true },
    { key = "wildSeed", kind = "item", label = "Wild Resilient Seed", name = "Wild Resilient Seed", itemID = 237499, fallback = "Interface\\Icons\\INV_Misc_Herb_06", zoneGroup = "midnight", hideWhenMissing = true },
    { key = "primalSeed", kind = "item", label = "Primal Resilient Seed", name = "Primal Resilient Seed", itemID = 237500, fallback = "Interface\\Icons\\INV_Misc_Herb_06", zoneGroup = "midnight", hideWhenMissing = true },
    {
        key = "greenThumb",
        kind = "spell",
        label = "Green Thumb",
        name = "Green Thumb",
        spellID = 439871,
        fallback = "Interface\\Icons\\INV_Misc_Herb_07",
        hideWhenMissing = true,
        spellVariants = {
            { spellID = 1221172, name = "Green Thumb", label = "Green Thumb", zoneGroup = "midnight" },
            { spellID = 439871, name = "Green Thumb", label = "Green Thumb", zoneGroup = "khazAlgar" },
        },
    },
    {
        key = "overloadHerb",
        kind = "spell",
        label = "Overload Herb",
        name = "Overload Infused Herb",
        spellID = 1223014,
        fallback = "Interface\\Icons\\INV_Misc_Herb_07",
        hideWhenMissing = true,
        spellVariants = {
            { spellID = 1223014, name = "Overload Infused Herb", label = "Overload Herb", zoneGroup = "midnight" },
            { spellID = 423395, name = "Overload Empowered Herb", label = "Overload Herb", zoneGroup = "khazAlgar" },
        },
    },
    {
        key = "overloadOre",
        kind = "spell",
        label = "Overload Ore",
        name = "Overload Infused Deposit",
        spellID = 1225392,
        fallback = "Interface\\Icons\\INV_Ore_Bismuth",
        hideWhenMissing = true,
        spellVariants = {
            { spellID = 1225392, name = "Overload Infused Deposit", label = "Overload Ore", zoneGroup = "midnight" },
            { spellID = 423394, name = "Overload Empowered Deposit", label = "Overload Ore", zoneGroup = "khazAlgar" },
        },
    },
    { key = "parcel", kind = "toy", label = "Interdimensional Parcel Signal", name = "Interdimensional Parcel Signal", itemID = 264695, fallback = "Interface\\Icons\\INV_Misc_EngGizmos_27", hideWhenMissing = true },
    { key = "bank", kind = "spell", label = "Warband Bank Distance Inhibitor", name = "Warband Bank Distance Inhibitor", spellID = 460905, spellIDs = { 460905, 465226, 460925 }, fallback = "Interface\\Icons\\INV_Engineering_90_WormholeGenerator_PortalBlue", hideWhenMissing = true },
}

function EL:CreateActionBar(parent)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    parent.actionBar = bar
    bar:SetHeight(ACTION_BAR_H)
    AddBackdrop(bar, 0.18, 0.18)
    if bar.SetBackdropColor then bar:SetBackdropColor(0.018, 0.020, 0.026, 0.30) end

    bar.itemButtons = {}
    local last
    for _, info in ipairs(ACTION_ITEM_BUTTONS) do
        local b = MakeIconActionButton(bar, info)
        bar.itemButtons[info.key] = b
        if last then
            b:SetPoint("LEFT", last, "RIGHT", 3, 0)
        else
            b:SetPoint("LEFT", bar, "LEFT", 6, 0)
        end
        last = b
    end

    bar.logout = MakeLogoutButton(bar)
    bar.logout:SetPoint("RIGHT", bar, "RIGHT", -6, 0)

    if self:IsActionBarEnabled() then self:RequestActionBarRefresh() end
end

function EL:UpdateActionBar()
    if self.IsActionBarEnabled and not self:IsActionBarEnabled() then
        local bar = self.panel and self.panel.actionBar
        if bar then bar:Hide() end
        return
    end
    local bar = self.panel and self.panel.actionBar
    if not bar or not bar.itemButtons then return end
    local locked = self:IsCombatLocked()
    if locked then self.pendingActionBarRefresh = true end

    local lastVisible
    for _, info in ipairs(ACTION_ITEM_BUTTONS) do
        local b = bar.itemButtons[info.key]
        if b then
            local actionButtons = self.db and self.db.settings and self.db.settings.panel and self.db.settings.panel.actionButtons
            local enabled = (not actionButtons) or actionButtons[info.key] ~= false
            local available = GetActionAvailable(info)
            local show = enabled and ((not b.hideWhenMissing) or available)
            if not locked then
                if info.kind == "spell" then SetSpellButtonAttributes(b, info) end
                b:SetShown(show)
            elseif info.kind == "spell" then
                b.resolvedSpell = ResolveActionSpell(info)
            end
            if show or (locked and b:IsShown()) then
                if not locked then
                    b:ClearAllPoints()
                    if lastVisible then
                        b:SetPoint("LEFT", lastVisible, "RIGHT", 3, 0)
                    else
                        b:SetPoint("LEFT", bar, "LEFT", 6, 0)
                    end
                    lastVisible = b
                end

                if b.icon then
                    if not locked and info.kind == "spell" then b.icon:SetTexture(GetActionIcon(info)) end
                    b.icon:SetDesaturated(not available)
                    b.icon:SetAlpha(available and 1 or 0.38)
                end
                -- Do not Enable/Disable secure action buttons during refresh.
                -- Availability is represented visually, while the secure macro action
                -- remains untouched unless attributes need an out-of-combat update.

                local start, duration, enable = GetActionCooldownSafe(info)
                if b.cooldown and CooldownFrame_Set then
                    if start and duration and duration > 1 then
                        CooldownFrame_Set(b.cooldown, start, duration, enable)
                    else
                        CooldownFrame_Set(b.cooldown, 0, 0, 0)
                    end
                elseif b.cooldown and b.cooldown.SetCooldown then
                    b.cooldown:SetCooldown(start or 0, duration or 0)
                end
            end
        end
    end
end

function EL:CreateSessionPanel(parent)
    local session = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    parent.sessionPanel = session
    session:SetHeight(SESSION_EXPANDED_H)
    AddBackdrop(session, 0.30, 0.28)
    if session.SetBackdropColor then session:SetBackdropColor(0.018, 0.020, 0.026, 0.46) end
    if session.SetBackdropBorderColor then session:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, BORDER_ALPHA_SOFT) end

    session.header = CreateFrame("Frame", nil, session, "BackdropTemplate")
    session.header:SetHeight(28)
    session.header:SetPoint("TOPLEFT", 4, -4)
    session.header:SetPoint("TOPRIGHT", -4, -4)
    AddBackdrop(session.header, 0.24, 0.18)
    if session.header.SetBackdropColor then session.header:SetBackdropColor(0.020, 0.022, 0.028, 0.58) end

    -- The standalone Session window no longer needs an internal collapse
    -- control. Visibility is handled by the window close button and Options.
    session.collapse = CreateFrame("Button", nil, session.header, "UIPanelButtonTemplate")
    session.collapse:SetSize(1, 1)
    session.collapse:Hide()

    session.title = session.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    session.title:SetPoint("LEFT", session.header, "LEFT", 10, 0)
    session.title:SetPoint("RIGHT", session.header, "RIGHT", -210, 0)
    session.title:SetJustifyH("LEFT")
    session.title:SetText("EmberLedger Session")
    session.title:SetTextColor(1.00, 0.82, 0.24)

    session.toggle = CreateFrame("Button", nil, session.header, "UIPanelButtonTemplate")
    session.toggle:SetSize(54, 20)
    session.toggle:SetPoint("RIGHT", session.header, "RIGHT", -66, 1)
    StyleBlizzardButton(session.toggle)
    session.toggle.text = session.toggle:GetFontString()
    session.toggle:SetScript("OnClick", function() EL:ToggleSessionPause() end)

    session.reset = CreateFrame("Button", nil, session.header, "UIPanelButtonTemplate")
    session.reset:SetSize(54, 20)
    session.reset:SetPoint("LEFT", session.toggle, "RIGHT", 6, 0)
    session.reset:SetText("Reset")
    StyleBlizzardButton(session.reset)
    session.reset.text = session.reset:GetFontString()
    session.reset:SetScript("OnClick", function() if EL.ConfirmResetSession then EL:ConfirmResetSession() else EL:ResetSession() end end)

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
        if sp.itemClip then sp.itemClip:SetShown(false) end
        for _, row in ipairs(sp.items or {}) do row:SetShown(false) end
        return
    end
    local collapsed = false
    if sp.collapse then sp.collapse:Hide() end
    if sp.metrics then sp.metrics:SetShown(true) end
    if sp.metricDiv1 then sp.metricDiv1:SetShown(true) end
    if sp.metricDiv2 then sp.metricDiv2:SetShown(true) end
    if sp.toggle then sp.toggle:SetShown(true) end
    if sp.reset then sp.reset:SetShown(true) end
    for _, row in ipairs(sp.items or {}) do row:SetShown(true) end

    local s = self:GetSessionDB()
    local elapsed = self:GetSessionElapsedSeconds()
    local value = self:FormatMoneyText(s.totalSilver or 0)
    local gph = self:FormatMoneyText(self:GetSessionGoldPerHour()) .. "/hr"
    if sp.summary then sp.summary:SetText(""); sp.summary:Hide() end
    if sp.metricTime and sp.metricTime.value then sp.metricTime.value:SetText(FormatSessionTime(elapsed)) end
    if sp.metricValue and sp.metricValue.value then sp.metricValue.value:SetText(value) end
    if sp.metricRate and sp.metricRate.value then sp.metricRate.value:SetText(gph) end
    if sp.itemClip then sp.itemClip:SetShown(not collapsed) end
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
            local text = string.format("%s x%d  •  %s", item.name or ("item:" .. tostring(item.itemID)), tonumber(item.count or item.qty) or 0, money)
            SetSessionRow(row, text, 0.88, 0.90, 0.92, item.icon)
        else
            ClearSessionRow(row)
        end
    end
end


function EL:LayoutSessionWindow()
    local w = self.sessionWindow
    if not w or not w.sessionPanel then return end
    local settings = self.db and self.db.settings and self.db.settings.session or {}
    local collapsed = false
    settings.collapsed = false
    local height = math.max(150, SESSION_EXPANDED_H + 16)
    local trackingWidth = (self.GetTrackingPanelMaxWidth and self:GetTrackingPanelMaxWidth()) or SESSION_MIN_W
    local savedWidth = tonumber(settings.width) or trackingWidth
    -- The Session window is not manually resizable, so keep it visually aligned
    -- with the current adaptive tracking window instead of preserving the older
    -- wide default width forever.
    local width = math.max(SESSION_MIN_W, math.min(savedWidth, trackingWidth))
    settings.width = width
    w:SetSize(width, height)
    ApplyFrameOpacity(w, GetSessionOpacity())
    if w.SetBackdropBorderColor then w:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, BORDER_ALPHA_STRONG) end
    w.sessionPanel:ClearAllPoints()
    w.sessionPanel:SetPoint("TOPLEFT", w, "TOPLEFT", 6, -6)
    w.sessionPanel:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -6, 6)
    w.sessionPanel:SetHeight(height - 12)
    ApplyFrameOpacity(w.sessionPanel, math.max(0.20, GetSessionOpacity() - 0.09))
    if w.sessionPanel.metrics and not collapsed then
        local contentW = math.max(1, width - 20)
        local gap = 8
        local blockW = math.max(62, math.floor((contentW - (gap * 2)) / 3))
        local totalW = (blockW * 3) + (gap * 2)
        local startX = math.floor((contentW - totalW) / 2)
        w.sessionPanel.metricTime:ClearAllPoints()
        w.sessionPanel.metricTime:SetPoint("TOPLEFT", w.sessionPanel.metrics, "TOPLEFT", startX, 0)
        w.sessionPanel.metricTime:SetSize(blockW, 38)
        w.sessionPanel.metricValue:ClearAllPoints()
        w.sessionPanel.metricValue:SetPoint("LEFT", w.sessionPanel.metricTime, "RIGHT", gap, 0)
        w.sessionPanel.metricValue:SetSize(blockW, 38)
        w.sessionPanel.metricRate:ClearAllPoints()
        w.sessionPanel.metricRate:SetPoint("LEFT", w.sessionPanel.metricValue, "RIGHT", gap, 0)
        w.sessionPanel.metricRate:SetSize(blockW, 38)
        if w.sessionPanel.metricDiv1 then
            w.sessionPanel.metricDiv1:ClearAllPoints()
            w.sessionPanel.metricDiv1:SetPoint("TOP", w.sessionPanel.metrics, "TOPLEFT", startX + blockW + math.floor(gap / 2), 0)
            w.sessionPanel.metricDiv1:SetPoint("BOTTOM", w.sessionPanel.metrics, "BOTTOMLEFT", startX + blockW + math.floor(gap / 2), 6)
        end
        if w.sessionPanel.metricDiv2 then
            w.sessionPanel.metricDiv2:ClearAllPoints()
            w.sessionPanel.metricDiv2:SetPoint("TOP", w.sessionPanel.metrics, "TOPLEFT", startX + (blockW * 2) + gap + math.floor(gap / 2), 0)
            w.sessionPanel.metricDiv2:SetPoint("BOTTOM", w.sessionPanel.metrics, "BOTTOMLEFT", startX + (blockW * 2) + gap + math.floor(gap / 2), 6)
        end
    end
    if self.RefreshSessionPanel then self:RefreshSessionPanel() end
end

function EL:CreateSessionWindow()
    if self.sessionWindow then return end
    local s = self.db.settings.session
    local frame = CreateFrame("Frame", "EmberLedgerSessionWindow", UIParent, "BackdropTemplate")
    self.sessionWindow = frame
    frame:SetSize(math.max(SESSION_MIN_W, tonumber(s.width) or SESSION_MIN_W), math.max(150, tonumber(s.height) or 180))
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    AddBackdrop(frame, GetSessionOpacity(), 0.58)
    AddInnerBorder(frame)
    frame:Hide()
    frame:SetScript("OnShow", function()
        if EL.db and EL.db.settings and EL.db.settings.session then
            EL.db.settings.session.windowOpen = true
            EL.db.settings.session.shown = true
        end
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
    end)
    frame:SetScript("OnHide", function()
        if EL.db and EL.db.settings and EL.db.settings.session then
            EL.db.settings.session.windowOpen = false
            if not EL._suppressSessionWindowHideSetting then
                EL.db.settings.session.shown = false
            end
        end
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
    end)
    frame:SetScript("OnDragStart", function(self) if not (EL.db.settings.lockWindows == true) or IsShiftKeyDown() then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFramePoint(self, EL.db.settings.session)
    end)

    self:CreateSessionPanel(frame)
    frame.close = CreateFrame("Button", nil, frame.sessionPanel.header, "UIPanelCloseButton")
    frame.close:SetSize(18, 18)
    frame.close:SetPoint("RIGHT", frame.sessionPanel.header, "RIGHT", -5, 0)
    frame.close:SetFrameLevel((frame.sessionPanel.header:GetFrameLevel() or 1) + 10)
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    if frame.sessionPanel and frame.sessionPanel.reset then
        frame.sessionPanel.reset:ClearAllPoints()
        frame.sessionPanel.reset:SetPoint("RIGHT", frame.close, "LEFT", -5, 0)
    end
    if frame.sessionPanel and frame.sessionPanel.toggle then
        frame.sessionPanel.toggle:ClearAllPoints()
        frame.sessionPanel.toggle:SetPoint("RIGHT", frame.sessionPanel.reset, "LEFT", -5, 0)
    end
    if frame.sessionPanel and frame.sessionPanel.title then
        frame.sessionPanel.title:ClearAllPoints()
        frame.sessionPanel.title:SetPoint("LEFT", frame.sessionPanel.header, "LEFT", 10, 0)
        frame.sessionPanel.title:SetPoint("RIGHT", frame.sessionPanel.toggle, "LEFT", -8, 0)
    end

    SetFramePointFromDB(frame, s)
    frame:SetScale(math.max(PANEL_MIN_SCALE, math.min(PANEL_MAX_SCALE, tonumber(s.scale) or 1)))
    self:LayoutSessionWindow()
end

function EL:ShowSessionWindowFromSavedState()
    if not self.sessionWindow then return end
    if self.db and self.db.settings and self.db.settings.session and self.db.settings.session.shown == false then return end
    SetFramePointFromDB(self.sessionWindow, self.db.settings.session)
    self:LayoutSessionWindow()
    if self.RefreshSessionPanel then self:RefreshSessionPanel() end
    self.sessionWindow:Show()
end

function EL:ToggleSessionWindow()
    if not self.sessionWindow then return end
    if self.sessionWindow:IsShown() then
        self.sessionWindow:Hide()
    else
        self:ShowSessionWindowFromSavedState()
    end
end

function EL:CreatePanel()
    local s = self.db.settings.panel
    local panel = CreateFrame("Frame", "EmberLedgerPanel", UIParent, "BackdropTemplate")
    self.panel = panel
    local autoW = (self.GetTrackingPanelMaxWidth and self:GetTrackingPanelMaxWidth()) or PANEL_MIN_W
    panel:SetSize(autoW, math.max(PANEL_MIN_H, tonumber(s.height) or 360))
    if panel.SetResizeBounds then panel:SetResizeBounds(autoW, GetCurrentPanelMinHeight(panel), autoW, PANEL_MAX_H) end
    panel:SetMovable(true)
    panel:SetResizable(false)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)
    AddBackdrop(panel, 0.64, 0.62)
    if panel.SetBackdropColor then panel:SetBackdropColor(0.018, 0.020, 0.026, GetPanelOpacity()) end
    if panel.SetBackdropBorderColor then panel:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, BORDER_ALPHA_STRONG) end
    AddInnerBorder(panel)
    panel:Hide()
    panel:SetScript("OnShow", function()
        if EL.db and EL.db.settings and EL.db.settings.panel then
            EL.db.settings.panel.windowOpen = true
            EL.db.settings.panel.charactersShown = true
        end
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
    end)
    panel:SetScript("OnHide", function()
        if EL.db and EL.db.settings and EL.db.settings.panel then
            EL.db.settings.panel.windowOpen = false
            EL.db.settings.panel.charactersShown = false
        end
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
    end)
    panel:SetScale(math.max(PANEL_MIN_SCALE, math.min(PANEL_MAX_SCALE, tonumber(s.scale) or 1)))

    panel:SetScript("OnDragStart", function(self) if not (EL.db.settings.lockWindows == true) or IsShiftKeyDown() then self:StartMoving() end end)
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
    AddBackdrop(panel.topBar, 0.24, 0.18)
    if panel.topBar.SetBackdropColor then panel.topBar:SetBackdropColor(0.020, 0.022, 0.028, 0.58) end

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
    panel.close:SetScript("OnClick", function() panel:Hide() end)

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

    -- Scale controls moved to the Options panel in v0.4.24.
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
    AddBackdrop(panel.header, 0.38, 0.20)
    if panel.header.SetBackdropColor then panel.header:SetBackdropColor(0.018, 0.022, 0.030, 0.54) end
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
    panel.header.mulch = panel.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.header.name:SetText("Character")
    panel.header.prof1:SetText("P1")
    panel.header.conc1:SetText("Conc 1")
    panel.header.prof2:SetText("P2")
    panel.header.conc2:SetText("Conc 2")
    panel.header.mulch:SetText("Mulch")
    for _, fs in pairs({panel.header.name, panel.header.prof1, panel.header.conc1, panel.header.prof2, panel.header.conc2, panel.header.mulch}) do
        fs:SetTextColor(0.78, 0.84, 0.92)
    end
    panel.header.nameButton = CreateHeaderButton(panel.header, panel.header.name, "character")
    panel.header.prof1Button = CreateHeaderButton(panel.header, panel.header.prof1, "prof1")
    panel.header.conc1Button = CreateHeaderButton(panel.header, panel.header.conc1, "conc1")
    panel.header.prof2Button = CreateHeaderButton(panel.header, panel.header.prof2, "prof2")
    panel.header.conc2Button = CreateHeaderButton(panel.header, panel.header.conc2, "conc2")
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

    -- The tracking window auto-sizes to its visible columns and up to 20 rows.
    -- Manual resizing was removed to avoid clipped columns and empty table space.
    panel.resize = nil

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
            fs:SetTextColor(0.78, 0.84, 0.92)
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
    if self.AutoSizeTrackingPanel then
        self:AutoSizeTrackingPanel(reason or "autoHeight")
    end
end

function EL:LayoutPanel()
    local p = self.panel
    if not p or not p.header or not p.scroll or not p.content then return end
    if self.AutoSizeTrackingPanel then self:AutoSizeTrackingPanel("layout") end

    local w, h = p:GetWidth(), p:GetHeight()
    local settings = self.db and self.db.settings and self.db.settings.panel or {}
    local charShown = settings.charactersShown ~= false
    settings.charactersCollapsed = false
    local actionBarShown = settings.actionBarShown ~= false and (not self.IsActionBarEnabled or self:IsActionBarEnabled())

    if p.characterToggle then
        p.characterToggle:Hide()
        p.characterToggle:ClearAllPoints()
    end

    if p.actionBar then
        p.actionBar:ClearAllPoints()
        local actionBottom = GetTrackingActionBarBottomOffset()
        p.actionBar:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, actionBottom)
        p.actionBar:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -14, actionBottom)
        p.actionBar:SetHeight(actionBarShown and ACTION_BAR_H or 1)
        p.actionBar:SetShown(actionBarShown)
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
        if p.SetResizeBounds then p:SetResizeBounds(targetW, GetCurrentPanelMinHeight(p), targetW, PANEL_MAX_H) end
        local cols = GetColumnLayout(headerW)
        local visible = {}
        for _, def in ipairs(cols.columns or {}) do visible[def.key] = true end

        local headerMap = { character = p.header.name, prof1 = p.header.prof1, conc1 = p.header.conc1, prof2 = p.header.prof2, conc2 = p.header.conc2, mulch = p.header.mulch }
        local buttonMap = { character = p.header.nameButton, prof1 = p.header.prof1Button, conc1 = p.header.conc1Button, prof2 = p.header.prof2Button, conc2 = p.header.conc2Button, mulch = p.header.mulchButton }
        for _, def in ipairs(TRACKING_COLUMN_DEFS) do
            local fs = headerMap[def.key]
            local btn = buttonMap[def.key]
            if fs then
                fs:SetShown(visible[def.key] and true or false)
                if visible[def.key] then
                    AnchorColumnText(fs, p.header, cols[def.key .. "X"], cols[def.key .. "W"], def.key == "character" and "LEFT" or "CENTER")
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
        row.currentHighlight:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -2)
        row.currentHighlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3, 2)
        row.currentHighlight:SetColorTexture(1.00, 0.78, 0.24, 0.00)
        row.currentHighlight:Hide()
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
        row.conc1:SetJustifyH("RIGHT")
        row.prof2Icon = row:CreateTexture(nil, "OVERLAY")
        row.prof2Icon:Hide()
        row.prof2 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.prof2:SetJustifyH("CENTER")
        row.conc2 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.conc2:SetJustifyH("RIGHT")
        row.mulch = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.mulch:SetJustifyH("RIGHT")
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
        row.hover:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -2)
        row.hover:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3, 2)
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

    if self.db and self.db.settings and self.db.settings.panel then self.db.settings.panel.charactersCollapsed = false end

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
    self:SortDashboardRows(rows)
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
        local profEntries = self:GetProfessionEntriesForCharacter(charKey)
        local concEntries = self:GetConcentrationEntriesForCharacter(charKey)
        local profData1, concData1 = self:GetDashboardProfessionData(charKey, 1)
        local profData2, concData2 = self:GetDashboardProfessionData(charKey, 2)
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
        local mulchValue = "N/A"
        if self:HasImbuedMulchAccess(mulchData) then
            local remain = math.max(0, (tonumber(mulchData.readyAt) or 0) - now)
            mulchValue = remain <= 0 and (READY_ICON .. " Ready") or self:FormatCountdown(remain)
        end

        row:SetWidth(width)
        row:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -((i - 1) * (rowH + gap)))
        AnchorColumnText(row.name, row, cols.nameX, cols.nameW, "LEFT")
        AnchorColumnText(row.conc1, row, cols.conc1X, cols.conc1W, "RIGHT")
        AnchorColumnText(row.conc2, row, cols.conc2X, cols.conc2W, "RIGHT")
        AnchorColumnText(row.mulch, row, cols.mulchX, math.max(1, cols.mulchW), "RIGHT")
        AnchorProfessionCell(row, row.prof1, row.prof1Icon, cols.prof1X, cols.prof1W, visible.prof1, profData1 and self:GetProfessionIconTexture(profData1))
        AnchorProfessionCell(row, row.prof2, row.prof2Icon, cols.prof2X, cols.prof2W, visible.prof2, profData2 and self:GetProfessionIconTexture(profData2))
        row.prof1:SetShown(visible.prof1 and not row.prof1._emberHasProfessionIcon)
        row.conc1:SetShown(visible.conc1 and true or false)
        row.prof2:SetShown(visible.prof2 and not row.prof2._emberHasProfessionIcon)
        row.conc2:SetShown(visible.conc2 and true or false)
        row.mulch:SetShown(visible.mulch and true or false)

        row.charKey = charKey
        row.concData = concData1
        row.concEntries = concEntries
        row.profEntries = profEntries
        row.mulchData = mulchData
        row.name:SetText(self:GetCharacterDisplayName(char, charKey))
        local r, g, b = self:GetClassColor(char.class)
        row.name:SetTextColor(r, g, b)
        local isPinned = self:IsCharacterPinned(charKey)
        local isCurrentCharacter = highlightCurrent and currentCharKey and charKey == currentCharKey
        row.isCurrentCharacter = isCurrentCharacter and true or false
        if row.currentHighlight then
            row.currentHighlight:SetShown(isCurrentCharacter and true or false)
            if isCurrentCharacter then row.currentHighlight:SetColorTexture(1.00, 0.78, 0.24, IsCompactModeEnabled() and 0.15 or 0.18) end
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
        row.mulch:SetText(mulchValue)
        if self:HasImbuedMulchAccess(mulchData) then
            local remain = math.max(0, (tonumber(mulchData.readyAt) or 0) - now)
            local mr, mg, mb = self:GetMulchCountdownColor(remain)
            row.mulch:SetTextColor(mr, mg, mb)
        else
            row.mulch:SetTextColor(0.7, 0.7, 0.7)
        end
        local stripe = (i % 2 == 0) and 0.030 or 0
        row.bg:SetColorTexture(0.15 + stripe, 0.15 + stripe, 0.165 + stripe, IsCompactModeEnabled() and ROW_STRIPE_ALPHA_COMPACT or ROW_STRIPE_ALPHA)
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
    if self.AutoSizeTrackingPanel then self:AutoSizeTrackingPanel("refresh") end
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

    if b.line1 then
        if display.showLauncherConc ~= false and concReady > 0 then
            b.line1:SetText("Conc Ready: " .. tostring(concReady))
            b.line1:SetTextColor(1.00, 0.82, 0.24)
            b.line1:Show()
        else
            b.line1:SetText("")
            b.line1:Hide()
        end
    end

    if b.line2 then
        if display.showLauncherMulch == false then
            b.line2:SetText("")
            b.line2:Hide()
        elseif nextMulch then
            if mulchReady > 0 then
                b.line2:SetText("Mulch Ready: " .. tostring(mulchReady))
                b.line2:SetTextColor(0.35, 1.00, 0.35)
            else
                b.line2:SetText("Mulch " .. self:FormatCountdown(nextMulch.remaining))
                b.line2:SetTextColor(self:GetMulchCountdownColor(nextMulch.remaining))
            end
            b.line2:Show()
        else
            b.line2:SetText("Mulch N/A")
            b.line2:SetTextColor(0.52, 0.60, 0.68)
            b.line2:Show()
        end
    end

    local sessionEnabled = not self.IsSessionTrackingEnabled or self:IsSessionTrackingEnabled()
    local showSessionGold = sessionEnabled and display.showLauncherSession ~= false
    local showSessionTotal = sessionEnabled and display.showLauncherSessionTotal ~= false
    local showSessionTime = sessionEnabled and display.showLauncherSessionTime ~= false
    local sdb = sessionEnabled and self.GetSessionDB and self:GetSessionDB() or {}
    if b.line3 then
        if showSessionGold then
            b.line3:SetText(self:FormatMoneyText(self:GetSessionGoldPerHour()) .. "/hr")
            b.line3:SetTextColor(0.86, 0.84, 0.76)
            b.line3:Show()
        else
            b.line3:SetText("")
            b.line3:Hide()
        end
    end
    if b.line4 then
        if showSessionTotal then
            b.line4:SetText("Total: " .. self:FormatMoneyText(sdb.totalSilver or 0))
            b.line4:SetTextColor(0.86, 0.84, 0.76)
            b.line4:Show()
        else
            b.line4:SetText("")
            b.line4:Hide()
        end
    end
    if b.line5 then
        if showSessionTime then
            b.line5:SetText("Time: " .. FormatSessionTime(self:GetSessionElapsedSeconds()))
            b.line5:SetTextColor(0.78, 0.78, 0.72)
            b.line5:Show()
        else
            b.line5:SetText("")
            b.line5:Hide()
        end
    end

    local orderedLines = { b.line1, b.line2, b.line3, b.line4, b.line5 }
    local previous = b.title
    local shownLineCount = 0
    for _, line in ipairs(orderedLines) do
        if line then
            line:ClearAllPoints()
            if line:IsShown() then
                local yGap = shownLineCount == 0 and -6 or -2
                line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, yGap)
                line:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, yGap)
                previous = line
                shownLineCount = shownLineCount + 1
            end
        end
    end

    local textW = math.max(GetTextWidth(b.title), GetTextWidth(b.line1), GetTextWidth(b.line2), b.line3 and GetTextWidth(b.line3) or 0, b.line4 and GetTextWidth(b.line4) or 0, b.line5 and GetTextWidth(b.line5) or 0)
    local targetW = math.ceil(math.max(142, textW + 28))
    local targetH = math.max(48, 31 + (shownLineCount * 13))
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
end

function EL:ToggleMainPanel()
    if not self.panel then return end
    if self.panel:IsShown() then
        self.panel:Hide()
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
        if self.panel then self.panel:Hide() end
        if self.sessionWindow then self.sessionWindow:Hide() end
    else
        if self.ShowPanelFromSavedState then self:ShowPanelFromSavedState() end
        if self.ShowSessionWindowFromSavedState then self:ShowSessionWindowFromSavedState() end
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

    local threshold = self.db and self.db.settings and self.db.settings.alerts and self.db.settings.alerts.concentrationThreshold or 360
    local attention, totalAttention = self:GetNeedsAttentionEntries(8)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Needs Attention", 1.00, 0.82, 0.24)
    if attention and #attention > 0 then
        for _, entry in ipairs(attention) do
            if entry.type == "mulch" then
                GameTooltip:AddDoubleLine(entry.displayName or "Unknown", "Imbued Mulch Ready", 0.35, 1.00, 0.35, 0.35, 1.00, 0.35)
            else
                local label = string.format("%s - %s", entry.displayName or "Unknown", entry.abbrev or "Prof")
                local value = string.format("%d/%d", tonumber(entry.quantity) or 0, tonumber(entry.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT)
                GameTooltip:AddDoubleLine(label, value, 1.00, 0.82, 0.24, 1, 1, 1)
            end
        end
        if totalAttention and totalAttention > #attention then
            GameTooltip:AddLine(string.format("...and %d more", totalAttention - #attention), 0.72, 0.72, 0.72)
        end
    else
        GameTooltip:AddLine("Nothing currently ready.", 0.72, 0.72, 0.72)
    end

    local concEntries, totalConc = self:GetConcentrationReadyEntries(threshold, 8)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Concentration Ready", 0.62, 0.78, 0.92)
    if concEntries and #concEntries > 0 then
        for _, entry in ipairs(concEntries) do
            local label = string.format("%s - %s", entry.displayName or "Unknown", entry.abbrev or "Prof")
            local value = string.format("%d/%d", tonumber(entry.quantity) or 0, tonumber(entry.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT)
            GameTooltip:AddDoubleLine(label, value, 0.62, 0.78, 0.92, 1, 1, 1)
        end
        if totalConc and totalConc > #concEntries then
            GameTooltip:AddLine(string.format("...and %d more", totalConc - #concEntries), 0.72, 0.72, 0.72)
        end
    else
        GameTooltip:AddLine("None above threshold.", 0.72, 0.72, 0.72)
    end

    local mulchEntries, totalMulch = self:GetMulchReadyEntries(8)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Imbued Mulch Ready", 0.35, 1.00, 0.35)
    if mulchEntries and #mulchEntries > 0 then
        for _, entry in ipairs(mulchEntries) do
            GameTooltip:AddLine(entry.displayName or "Unknown", 0.35, 1.00, 0.35)
        end
        if totalMulch and totalMulch > #mulchEntries then
            GameTooltip:AddLine(string.format("...and %d more", totalMulch - #mulchEntries), 0.72, 0.72, 0.72)
        end
    else
        GameTooltip:AddLine("None ready.", 0.72, 0.72, 0.72)
    end

    local nextMulch = self:GetNextMulchSummary()
    if nextMulch then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Next Imbued Mulch", nextMulch.displayName .. " - " .. self:FormatCountdown(nextMulch.remaining), 0.95, 0.62, 0.26, 1, 1, 1)
    end

    local total, hiddenCount = 0, 0
    for key in pairs(self.db.characters or {}) do
        total = total + 1
        if self:IsCharacterHidden(key) then hiddenCount = hiddenCount + 1 end
    end

    local s = self:GetSessionDB()
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Tracked characters", tostring(total), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Hidden characters", tostring(hiddenCount), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Session value", self:FormatMoneyText(s.totalSilver or 0), 0.95, 0.62, 0.26, 1, 1, 1)
    GameTooltip:AddDoubleLine("Gold/hour", self:FormatMoneyText(self:GetSessionGoldPerHour()) .. "/hr", 0.95, 0.62, 0.26, 1, 1, 1)
    GameTooltip:AddDoubleLine("Session status", s.isPaused and "Paused" or "Running", 0.95, 0.62, 0.26, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: open dashboard", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-click: lock/unlock launcher", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Shift-drag: move while locked", 0.7, 0.7, 0.7)
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
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(displayName, r, g, b)

    GameTooltip:AddDoubleLine("Realm", (char and char.realm) or "Unknown", 0.82, 0.80, 0.72, 1, 1, 1)
    GameTooltip:AddDoubleLine("Class", (char and char.class) or "Unknown", 0.82, 0.80, 0.72, 1, 1, 1)
    GameTooltip:AddDoubleLine("Last seen", FormatTooltipAgo(char and char.lastSeen), 0.82, 0.80, 0.72, 1, 1, 1)
    if char and char.lastSeen then
        GameTooltip:AddDoubleLine("Last seen at", FormatTooltipDate(char.lastSeen), 0.62, 0.62, 0.62, 0.85, 0.85, 0.85)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Known Professions", 0.62, 0.78, 0.92)
    if row.profEntries and #row.profEntries > 0 then
        for i, prof in ipairs(row.profEntries) do
            local profName = self:GetCleanProfessionName(prof.professionName)
            local abbrev = self:GetProfessionAbbreviation(prof)
            local conc = self:GetConcentrationEntryForProfession(row.charKey, prof)
            GameTooltip:AddDoubleLine(string.format("%d. %s", i, profName), abbrev, 0.62, 0.78, 0.92, 1, 1, 1)
            if conc then
                local quantity = tonumber(self:GetEstimatedConcentration(conc)) or 0
                local maxQuantity = tonumber(conc.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
                local pct = maxQuantity > 0 and math.floor((quantity / maxQuantity) * 100 + 0.5) or 0
                local fullIn = self:GetConcentrationFullIn(conc) or "Unknown"
                local lastUpdate = tonumber(conc.lastUpdate) or 0
                GameTooltip:AddDoubleLine("   Concentration", string.format("%d/%d (%d%%)", quantity, maxQuantity, pct), 0.72, 0.72, 0.72, 1, 1, 1)
                GameTooltip:AddDoubleLine("   Full in", fullIn, 0.72, 0.72, 0.72, 1, 1, 1)
                if lastUpdate > 0 then
                    GameTooltip:AddDoubleLine("   Concentration updated", FormatTooltipAgo(lastUpdate), 0.62, 0.62, 0.62, 0.85, 0.85, 0.85)
                end
            else
                GameTooltip:AddLine("   Concentration: not tracked for this profession", 0.70, 0.70, 0.70)
            end
        end
    elseif row.concEntries and #row.concEntries > 0 then
        for i, data in ipairs(row.concEntries) do
            local profName = self:GetCleanProfessionName(data.professionName)
            local abbrev = self:GetProfessionAbbreviation(data)
            local quantity = tonumber(self:GetEstimatedConcentration(data)) or 0
            local maxQuantity = tonumber(data.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
            local pct = maxQuantity > 0 and math.floor((quantity / maxQuantity) * 100 + 0.5) or 0
            GameTooltip:AddDoubleLine(string.format("%d. %s", i, profName), abbrev, 0.62, 0.78, 0.92, 1, 1, 1)
            GameTooltip:AddDoubleLine("   Concentration", string.format("%d/%d (%d%%)", quantity, maxQuantity, pct), 0.72, 0.72, 0.72, 1, 1, 1)
        end
    else
        GameTooltip:AddLine("No profession identity tracked yet.", 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Imbued Mulch", 0.95, 0.62, 0.26)
    if self:HasImbuedMulchAccess(row.mulchData) then
        local readyAt = tonumber(row.mulchData.readyAt) or 0
        local remain = math.max(0, readyAt - time())
        local readyText = remain <= 0 and "Ready" or self:FormatCountdown(remain)
        GameTooltip:AddDoubleLine("State", readyText, 0.95, 0.62, 0.26, 1, 1, 1)
        GameTooltip:AddDoubleLine("Ready at", remain <= 0 and "Now" or FormatTooltipDate(readyAt), 0.95, 0.62, 0.26, 1, 1, 1)
        GameTooltip:AddDoubleLine("Item", row.mulchData.itemName or "Imbued Mulch", 0.95, 0.62, 0.26, 1, 1, 1)
        GameTooltip:AddDoubleLine("In bags", tostring(row.mulchData.itemCount or 0), 0.95, 0.62, 0.26, 1, 1, 1)
        if row.mulchData.lastUpdate then
            GameTooltip:AddDoubleLine("Updated", FormatTooltipAgo(row.mulchData.lastUpdate), 0.62, 0.62, 0.62, 0.85, 0.85, 0.85)
        end
    else
        GameTooltip:AddLine("No Imbued Mulch data tracked for this character.", 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(" ")
    if row.isCurrentCharacter then
        GameTooltip:AddDoubleLine("Current", "Yes", 0.95, 0.82, 0.38, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine("Pinned", self:IsCharacterPinned(row.charKey) and "Yes" or "No", 0.95, 0.82, 0.38, 1, 1, 1)
    GameTooltip:AddLine((self:IsCharacterPinned(row.charKey) and "Alt-click: unpin this character" or "Alt-click: pin this character"), 0.95, 0.82, 0.38)
    GameTooltip:AddLine("Right-click: hide from the table", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Shift-right-click: reset this character's data", 0.95, 0.62, 0.26)
    GameTooltip:Show()
end
