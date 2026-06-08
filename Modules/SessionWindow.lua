local addonName, EL = ...
if not EL then return end

-- SessionWindow owns the standalone Session window and refresh helpers
-- for the Stats, Sessions, and Bag Summary views. Main tracker UI and
-- options wiring remain in UI.lua so this module stays focused and low-risk.

local M = {}
if EL.RegisterModule then
    EL:RegisterModule("SessionWindow", M)
end

function M:OnLoad()
    local app = self.EL or EL
    if app and app.VerifyModuleInitialization then
        app:VerifyModuleInitialization("SessionWindow OnLoad")
    end
end

local UIC = EL.UI_CONSTANTS or {}
local SESSION_MIN_W = UIC.SESSION_MIN_W or 320
local SESSION_EXPANDED_H = UIC.SESSION_EXPANDED_H or 182
local SESSION_WINDOW_PAD = UIC.SESSION_WINDOW_PAD or 6
local PANEL_MIN_SCALE = UIC.PANEL_MIN_SCALE or 0.6
local PANEL_MAX_SCALE = UIC.PANEL_MAX_SCALE or 1.4
local SESSION_WINDOW_MIN_H = UIC.SESSION_WINDOW_MIN_H or 150
local SESSION_WINDOW_DEFAULT_H = UIC.SESSION_WINDOW_DEFAULT_H or 180
local SESSION_METRIC_CONTENT_PAD = UIC.SESSION_METRIC_CONTENT_PAD or 20
local SESSION_METRIC_GAP = UIC.SESSION_METRIC_GAP or 8
local SESSION_METRIC_MIN_W = UIC.SESSION_METRIC_MIN_W or 62
local SESSION_METRIC_H = UIC.SESSION_METRIC_H or 38
local SESSION_CLOSE_SIZE = UIC.SESSION_CLOSE_SIZE or 18
local SESSION_CLOSE_RIGHT_PAD = UIC.SESSION_CLOSE_RIGHT_PAD or -5
local SESSION_TITLE_LEFT_PAD = UIC.SESSION_TITLE_LEFT_PAD or 10
local SESSION_TITLE_RIGHT_PAD = UIC.SESSION_TITLE_RIGHT_PAD or -8
local function ThemeValue(key, fallback)
    local colors = EL and EL.THEME_COLORS or {}
    return tonumber(colors[key]) or fallback
end

local function ThemeBorderRGB()
    return ThemeValue("BORDER_R", 0.42), ThemeValue("BORDER_G", 0.42), ThemeValue("BORDER_B", 0.44)
end

local function ThemeTextRGB()
    return ThemeValue("TEXT_R", 0.90), ThemeValue("TEXT_G", 0.91), ThemeValue("TEXT_B", 0.93)
end

local function ThemeMutedTextRGB()
    return ThemeValue("MUTED_TEXT_R", 0.80), ThemeValue("MUTED_TEXT_G", 0.82), ThemeValue("MUTED_TEXT_B", 0.85)
end

local function ThemeValueTextRGB()
    return ThemeValue("VALUE_TEXT_R", 0.93), ThemeValue("VALUE_TEXT_G", 0.94), ThemeValue("VALUE_TEXT_B", 0.96)
end

local BORDER_ALPHA_STRONG = 0.78

local function AddBackdrop(frame, alpha, borderAlpha)
    return EL.Style:AddBackdrop(frame, alpha, borderAlpha)
end

local function AddInnerBorder(frame)
    return EL.Style:AddInnerBorder(frame)
end

local function ApplyFrameOpacity(frame, alpha)
    return EL.Style:ApplyFrameOpacity(frame, alpha)
end

local function GetSessionOpacity()
    local db = EL and EL.db
    local value = db and db.settings and db.settings.display and db.settings.display.sessionOpacity
    return math.max(0.20, math.min(1.00, tonumber(value) or 0.55))
end

local function IsCombatLocked()
    if EL and EL.IsCombatLocked then return EL:IsCombatLocked() end
    return InCombatLockdown and InCombatLockdown()
end

local function SetFramePointFromDB(frame, pos)
    if not frame or not pos then return false end
    if IsCombatLocked() then
        if EL then
            EL.pendingWindowPositionRestore = true
            if EL.QueueCombatDeferredWork then EL:QueueCombatDeferredWork("layout") end
        end
        return false
    end
    local cleared = pcall(frame.ClearAllPoints, frame)
    if not cleared then return false end
    return pcall(frame.SetPoint, frame, pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
end

local function SaveFramePoint(frame, pos)
    if not frame or not pos then return end
    local point, _, relativePoint, x, y = frame:GetPoint()
    pos.point = point or "CENTER"
    pos.relativePoint = relativePoint or "CENTER"
    pos.x = x or 0
    pos.y = y or 0
end

local function QueueDeferredWindowVisibility()
    if EL then
        EL.pendingWindowVisibility = true
        if EL.QueueCombatDeferredWork then EL:QueueCombatDeferredWork("visibility") end
    end
end

local function BringEmberWindowToFront(frame)
    if EL.BringWindowToFront then
        EL:BringWindowToFront(frame)
    end
end


local SESSION_HISTORY_ICON_SIZE = 18

function EL:SessionHistoryIcon(path)
    return "|T" .. tostring(path or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":" .. SESSION_HISTORY_ICON_SIZE .. ":" .. SESSION_HISTORY_ICON_SIZE .. ":0:0|t"
end

function EL:FormatSessionHistoryMoneyText(silver)
    if self.FormatMoneyText then
        return self:FormatMoneyText(silver)
    end
    return tostring(silver or 0)
end

function EL:GetSessionHistoryCapText()
    local maxEntries = (self.GetSessionHistoryMaxEntries and self:GetSessionHistoryMaxEntries()) or 500
    return "max " .. tostring(maxEntries)
end

function EL:FormatSessionHistoryRange(displayMode)
    local now = time()
    if displayMode == "today" then
        local startTime = (self.GetTodayStartTime and self:GetTodayStartTime(now)) or (now - 86400)
        return string.format("Today: since %s", date("%I:%M %p", startTime))
    elseif displayMode == "week" then
        local startTime = (self.GetWeeklyResetStartTime and self:GetWeeklyResetStartTime(now)) or (now - (7 * 86400))
        return string.format("This Week: since %s", date("%b %d, %Y %I:%M %p", startTime))
    end
    local startTime = now - (30 * 86400)
    return string.format("Last 30 Days (%s): %s  |  %s", self:GetSessionHistoryCapText(), date("%b %d, %Y", startTime), date("%b %d, %Y", now))
end

function EL:GetSessionStatsRangeLabel(range)
    if range == "today" then return "Today" end
    if range == "week" then return "This Week" end
    if range == "lifetime" then return "Lifetime" end
    return "30 Days"
end

function EL:GetSessionStatsRangeTitle(range)
    return self:GetSessionStatsRangeLabel(range)
end

function EL:FormatSessionStatsRange(range)
    local now = time()
    if range == "today" then
        return "Today: since local midnight"
    elseif range == "week" then
        local startTime = (self.GetWeeklyResetStartTime and self:GetWeeklyResetStartTime(now)) or (now - (7 * 86400))
        return string.format("This Week: since %s", date("%b %d, %Y %I:%M %p", startTime))
    elseif range == "lifetime" then
        return "Lifetime: retained history backfill plus all future saved sessions"
    end
    local startTime = now - (30 * 86400)
    return string.format("Last 30 Days: %s  |  %s", date("%b %d, %Y", startTime), date("%b %d, %Y", now))
end


function EL:RefreshSessionStatsView(frame)
    if not frame then return end
    local range = frame.statsRange or "30"
    local stats = (self.GetSessionAggregateStats and self:GetSessionAggregateStats(range)) or {}
    if frame.info then
        frame.info:SetText("Quick aggregated totals across saved EmberLedger sessions. Lifetime uses compact aggregate counters so raw history can remain lightweight.")
    end
    if frame.statsTitle then frame.statsTitle:SetText("Session Stats (" .. self:GetSessionStatsRangeTitle(range) .. ")") end
    if frame.statsNote then frame.statsNote:SetText(self:FormatSessionStatsRange(range)) end
    if frame.statGold then
        frame.statGold:SetText(self:FormatSessionHistoryMoneyText(tonumber(stats.totalSilver) or 0))
        local total = tonumber(stats.totalSilver) or 0
        frame.statGold:SetTextColor(total < 0 and 1.00 or 0.55, total < 0 and 0.34 or 1.00, total < 0 and 0.28 or 0.36)
    end
    if frame.statTime then frame.statTime:SetText(self:FormatDuration(tonumber(stats.duration) or 0)) end
    if frame.statRate then frame.statRate:SetText(self:FormatMoneyRateText(tonumber(stats.goldPerHourSilver) or 0) .. "/hr") end
    if frame.statSessions then frame.statSessions:SetText(tostring(tonumber(stats.sessions) or 0)) end
    if frame.statItems then frame.statItems:SetText(tostring(tonumber(stats.items) or 0)) end
    if frame.statRaw then frame.statRaw:SetText(self:FormatSessionHistoryMoneyText(tonumber(stats.rawGoldGainedSilver) or 0)) end
    if frame.statsFootnote then
        if range == "lifetime" then
            frame.statsFootnote:SetText("Lifetime totals begin with retained session history that existed when v1.11.0 first loaded, then continue from future saved sessions. Reset Lifetime in Options clears only these aggregate counters.")
        else
            frame.statsFootnote:SetText("Today, This Week, and 30 Days are calculated from compact daily/weekly aggregates. The Sessions list still keeps up to 30 days, capped at " .. tostring((self.GetSessionHistoryMaxEntries and self:GetSessionHistoryMaxEntries()) or 500) .. " entries. Current active sessions appear after they are saved by reset, logout, or reload.")
        end
    end
end

function EL:RefreshBagSummaryView(frame)
    if not frame then return end
    local summary = (self.GetCurrentBagSummaryLines and self:GetCurrentBagSummaryLines()) or { lines = {}, totalSilver = 0, totalQuantity = 0 }
    local session = (self.GetSessionDB and self:GetSessionDB()) or {}
    local sessionTotal = tonumber(session.totalSilver) or 0
    local bagTotal = tonumber(summary.totalSilver) or 0
    local projected = sessionTotal + bagTotal
    if frame.info then
        frame.info:SetText("Read-only current inventory value for tracked materials. This does not add to session history, lifetime stats, or realized gold/hour.")
    end
    if frame.bagValue then frame.bagValue:SetText(self:FormatSessionHistoryMoneyText(bagTotal)) end
    if frame.bagProjected then frame.bagProjected:SetText(self:FormatSessionHistoryMoneyText(projected)) end
    if frame.bagQuantity then frame.bagQuantity:SetText(tostring(tonumber(summary.totalQuantity) or 0)) end
    if frame.bagFootnote then
        frame.bagFootnote:SetText("Projected Total = current active session total plus currently held tracked bag value. It is an estimate for decision-making, not accounting or profit/loss tracking.")
    end
    local lines = summary.lines or {}
    for i, row in ipairs(frame.bagRows or {}) do
        local entry = lines[i]
        if entry then
            row:Show()
            local icon = entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
            row.texts[1]:SetText(self:SessionHistoryIcon(icon) .. " " .. tostring(entry.name or ("item:" .. tostring(entry.itemID))))
            row.texts[2]:SetText(tostring(tonumber(entry.quantity) or 0))
            row.texts[3]:SetText(self:FormatSessionHistoryMoneyText(tonumber(entry.unitPrice) or 0))
            row.texts[4]:SetText(self:FormatSessionHistoryMoneyText(tonumber(entry.totalSilver) or 0))
            row.texts[4]:SetTextColor(0.55, 1.00, 0.36)
            row.texts[1]:SetTextColor(ThemeTextRGB())
            row.texts[2]:SetTextColor(ThemeTextRGB())
            row.texts[3]:SetTextColor(ThemeTextRGB())
        else
            row:Show()
            if i == 1 then
                row.texts[1]:SetText("No currently held tracked materials found.")
                row.texts[1]:SetTextColor(ThemeMutedTextRGB())
                row.texts[2]:SetText("")
                row.texts[3]:SetText("")
                row.texts[4]:SetText("")
            else
                for _, fs in ipairs(row.texts or {}) do fs:SetText(""); fs:SetTextColor(ThemeTextRGB()) end
            end
        end
    end
end


-- Dispatcher for the Session History window tabs. Frame creation remains in UI.lua,
-- while each view owns its own refresh logic here. Keeping the routing
-- in one place makes future Stats / Sessions / Bag Summary changes easier to trace.
function EL:RefreshSessionView(frame, viewMode)
    if not frame then return false end
    viewMode = viewMode or frame.viewMode or "stats"

    if viewMode == "bag" then
        if self.RefreshBagSummaryView then
            self:RefreshBagSummaryView(frame)
            return true
        end
        if self.WarnMissingSessionWindowHelper then
            self:WarnMissingSessionWindowHelper("RefreshBagSummaryView")
        end
        return false
    end

    if viewMode == "stats" then
        if self.RefreshSessionStatsView then
            self:RefreshSessionStatsView(frame)
            return true
        end
        if self.WarnMissingSessionWindowHelper then
            self:WarnMissingSessionWindowHelper("RefreshSessionStatsView")
        end
        return false
    end

    return false
end

function EL:LayoutSessionWindow()
    local w = self.sessionWindow
    if not w or not w.sessionPanel then return end
    local settings = self.db and self.db.settings and self.db.settings.session or {}
    local height = math.max(SESSION_WINDOW_MIN_H, SESSION_EXPANDED_H + 16)
    local trackingWidth = (self.GetTrackingPanelMaxWidth and self:GetTrackingPanelMaxWidth()) or SESSION_MIN_W
    local savedWidth = tonumber(settings.width) or trackingWidth
    -- The Session window is not manually resizable, so keep it visually aligned
    -- with the current adaptive tracking window instead of preserving the older
    -- wide default width forever.
    local width = math.max(SESSION_MIN_W, math.min(savedWidth, trackingWidth))
    settings.width = width
    w:SetSize(width, height)
    ApplyFrameOpacity(w, GetSessionOpacity())
    if w.SetBackdropBorderColor then
        local borderR, borderG, borderB = ThemeBorderRGB()
        w:SetBackdropBorderColor(borderR, borderG, borderB, BORDER_ALPHA_STRONG)
    end
    w.sessionPanel:ClearAllPoints()
    w.sessionPanel:SetPoint("TOPLEFT", w, "TOPLEFT", SESSION_WINDOW_PAD, -SESSION_WINDOW_PAD)
    w.sessionPanel:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -SESSION_WINDOW_PAD, SESSION_WINDOW_PAD)
    w.sessionPanel:SetHeight(height - (SESSION_WINDOW_PAD * 2))
    ApplyFrameOpacity(w.sessionPanel, math.max(0.20, GetSessionOpacity() - 0.09))
    if w.sessionPanel.metrics then
        local contentW = math.max(1, width - SESSION_METRIC_CONTENT_PAD)
        local gap = SESSION_METRIC_GAP
        local blockW = math.max(SESSION_METRIC_MIN_W, math.floor((contentW - (gap * 2)) / 3))
        local totalW = (blockW * 3) + (gap * 2)
        local startX = math.floor((contentW - totalW) / 2)
        w.sessionPanel.metricTime:ClearAllPoints()
        w.sessionPanel.metricTime:SetPoint("TOPLEFT", w.sessionPanel.metrics, "TOPLEFT", startX, 0)
        w.sessionPanel.metricTime:SetSize(blockW, SESSION_METRIC_H)
        w.sessionPanel.metricValue:ClearAllPoints()
        w.sessionPanel.metricValue:SetPoint("LEFT", w.sessionPanel.metricTime, "RIGHT", gap, 0)
        w.sessionPanel.metricValue:SetSize(blockW, SESSION_METRIC_H)
        w.sessionPanel.metricRate:ClearAllPoints()
        w.sessionPanel.metricRate:SetPoint("LEFT", w.sessionPanel.metricValue, "RIGHT", gap, 0)
        w.sessionPanel.metricRate:SetSize(blockW, SESSION_METRIC_H)
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
    frame:SetSize(math.max(SESSION_MIN_W, tonumber(s.width) or SESSION_MIN_W), math.max(SESSION_WINDOW_MIN_H, tonumber(s.height) or SESSION_WINDOW_DEFAULT_H))
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    AddBackdrop(frame, GetSessionOpacity(), 0.58)
    AddInnerBorder(frame)
    frame:Hide()
    frame:SetScript("OnShow", function(self)
        BringEmberWindowToFront(self)
        if EL.db and EL.db.settings and EL.db.settings.session then
            EL.db.settings.session.windowOpen = true
            EL.db.settings.session.shown = true
        end
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
        if EL.RefreshUpdateTicker then EL:RefreshUpdateTicker() end
    end)
    frame:SetScript("OnHide", function()
        if EL.db and EL.db.settings and EL.db.settings.session then
            -- Hiding/closing the Session window should only close the current window instance.
            -- It should not disable the user's Session window preference, otherwise launcher
            -- and minimap toggles will refuse to restore the window until /el session forces it.
            EL.db.settings.session.windowOpen = false
        end
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
        if EL.RefreshUpdateTicker then EL:RefreshUpdateTicker() end
    end)
    frame:SetScript("OnMouseDown", function(self)
        BringEmberWindowToFront(self)
    end)
    frame:SetScript("OnDragStart", function(self)
        if EL.IsCombatLocked and EL:IsCombatLocked() then return end
        if not (EL.db.settings.lockWindows == true) or IsShiftKeyDown() then BringEmberWindowToFront(self); self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if EL.IsCombatLocked and EL:IsCombatLocked() then return end
        SaveFramePoint(self, EL.db.settings.session)
    end)

    self:CreateSessionPanel(frame)
    frame.close = CreateFrame("Button", nil, frame.sessionPanel.header, "UIPanelCloseButton")
    frame.close:SetSize(SESSION_CLOSE_SIZE, SESSION_CLOSE_SIZE)
    frame.close:SetPoint("RIGHT", frame.sessionPanel.header, "RIGHT", SESSION_CLOSE_RIGHT_PAD, 0)
    frame.close:SetFrameLevel((frame.sessionPanel.header:GetFrameLevel() or 1) + 10)
    frame.close:SetScript("OnClick", function() EL:HideSessionWindow(true) end)

    if frame.sessionPanel and frame.sessionPanel.title then
        frame.sessionPanel.title:ClearAllPoints()
        frame.sessionPanel.title:SetPoint("LEFT", frame.sessionPanel.header, "LEFT", SESSION_TITLE_LEFT_PAD, 0)
        frame.sessionPanel.title:SetPoint("RIGHT", frame.close, "LEFT", SESSION_TITLE_RIGHT_PAD, 0)
    end

    SetFramePointFromDB(frame, s)
    frame:SetScale(math.max(PANEL_MIN_SCALE, math.min(PANEL_MAX_SCALE, tonumber(s.scale) or 1)))
    self:LayoutSessionWindow()
end

function EL:SetSessionWindowPointFromDB()
    if not self.sessionWindow then return false end
    local settings = self.db and self.db.settings and self.db.settings.session
    return SetFramePointFromDB(self.sessionWindow, settings or {})
end

function EL:ShowSessionWindow(forcePreference)
    if not self.sessionWindow and self.CreateSessionWindow then
        self:CreateSessionWindow()
    end
    if not self.sessionWindow then
        if self.Print then self:Print("Session window could not be created.") end
        return false
    end

    local settings = self.db and self.db.settings and self.db.settings.session
    if settings then
        if forcePreference then
            settings.shown = true
            settings.windowOpen = true
        elseif settings.shown == false then
            return false
        end
    end

    SetFramePointFromDB(self.sessionWindow, settings or {})
    self:LayoutSessionWindow()
    if self.RefreshSessionPanel then self:RefreshSessionPanel() end
    self.sessionWindow:Show()
    BringEmberWindowToFront(self.sessionWindow)
    if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
    return true
end

function EL:HideSessionWindow(preservePreference)
    local settings = self.db and self.db.settings and self.db.settings.session
    if settings then
        settings.windowOpen = false
        if preservePreference == true then
            settings.shown = true
        elseif preservePreference == false then
            settings.shown = false
        end
    end
    if self.sessionWindow and self.sessionWindow:IsShown() then
        if self.IsCombatLocked and self:IsCombatLocked() then
            self.pendingSessionWindowHide = true
            QueueDeferredWindowVisibility()
            if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
            if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
            return false
        end
        self.sessionWindow:Hide()
    else
        if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
        if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
    end
    return true
end

function EL:ShowSessionWindowFromSavedState(forceShow)
    return self:ShowSessionWindow(forceShow == true)
end

function EL:ToggleSessionWindow()
    if self.sessionWindow and self.sessionWindow:IsShown() then
        self:HideSessionWindow(true)
    else
        local shown = self:ShowSessionWindow(true)
        if not shown and self.Print then self:Print("Session window could not be shown.") end
    end
end
