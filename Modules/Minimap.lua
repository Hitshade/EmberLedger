local addonName, EL = ...

local M = {}
EL:RegisterModule("Minimap", M)

local MINIMAP_BUTTON_NAME = "EmberLedgerMinimapButton"
local DEFAULT_ICON = (EL and EL.LOGO_TEXTURE) or "Interface\\Icons\\INV_Misc_Coin_01"

local function ThemeRGB(kind, fallbackR, fallbackG, fallbackB)
    local colors = EL and EL.THEME_COLORS or {}
    local prefix = {
        accent = "ACCENT",
        border = "BORDER",
        text = "TEXT",
        muted = "MUTED_TEXT",
        value = "VALUE_TEXT",
    }
    local key = prefix[kind]
    if key then
        return colors[key .. "_R"] or fallbackR, colors[key .. "_G"] or fallbackG, colors[key .. "_B"] or fallbackB
    end
    return fallbackR, fallbackG, fallbackB
end

local function GetMinimapSettings()
    EL.db = EL.db or {}
    EL.db.settings = EL.db.settings or {}
    EL.db.settings.minimap = type(EL.db.settings.minimap) == "table" and EL.db.settings.minimap or {}
    local settings = EL.db.settings.minimap
    settings.hide = settings.hide == true
    settings.minimapPos = tonumber(settings.minimapPos) or 220
    return settings
end

local function GetDisplaySummary()
    local threshold = (EL.GetConcentrationThreshold and EL:GetConcentrationThreshold()) or (EL.db and EL.db.settings and EL.db.settings.alerts and EL.db.settings.alerts.concentrationThreshold) or EL.CONCENTRATION_THRESHOLD_DEFAULT or 900
    local ready = (EL.GetConcentrationReadyCount and EL:GetConcentrationReadyCount(threshold)) or 0
    local mulch = (EL.GetMulchReadyCount and EL:GetMulchReadyCount()) or 0
    local session = (EL.GetSessionDB and EL:GetSessionDB()) or {}
    local total = (EL.FormatMoneyText and EL:FormatMoneyText(session.totalSilver or 0)) or tostring(session.totalSilver or 0)
    local rate = (EL.GetSessionGoldPerHour and EL.FormatMoneyRateText and EL:FormatMoneyRateText(EL:GetSessionGoldPerHour())) or "0g"
    local elapsed = (EL.GetSessionElapsedSeconds and EL.FormatDuration and EL:FormatDuration(EL:GetSessionElapsedSeconds())) or "Ready"
    return ready, mulch, total, rate, elapsed
end

local function PopulateTooltipLines(tooltip)
    if not tooltip then return end

    local ready, mulch, total, rate, elapsed = GetDisplaySummary()
    local tr, tg, tb = ThemeRGB("text", 0.90, 0.91, 0.93)
    local mr, mg, mb = ThemeRGB("muted", 0.80, 0.82, 0.85)
    local vr, vg, vb = ThemeRGB("value", 0.93, 0.94, 0.96)
    tooltip:AddLine("Profession alt dashboard", tr, tg, tb, true)
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("Concentration ready", tostring(ready), mr, mg, mb, vr, vg, vb)
    tooltip:AddDoubleLine("Mulch ready", tostring(mulch), mr, mg, mb, vr, vg, vb)
    tooltip:AddDoubleLine("Session total", total, mr, mg, mb, vr, vg, vb)
    tooltip:AddDoubleLine("Session rate", rate .. "/hr", mr, mg, mb, vr, vg, vb)
    tooltip:AddDoubleLine("Session time", elapsed, mr, mg, mb, vr, vg, vb)
    tooltip:AddLine(" ")
    tooltip:AddLine("Left-click: Toggle tracker", mr, mg, mb)
    tooltip:AddLine("Right-click: Options", mr, mg, mb)
end

function EL:ShowMinimapTooltip(owner)
    if not GameTooltip then return end
    if owner then GameTooltip:SetOwner(owner, "ANCHOR_LEFT") end
    local ar, ag, ab = ThemeRGB("accent", 0.68, 0.68, 0.70)
    GameTooltip:SetText("EmberLedger", ar, ag, ab)
    PopulateTooltipLines(GameTooltip)
    GameTooltip:Show()
end

local function HandleMinimapClick(button)
    if button == "RightButton" then
        if EL.ShowSettingsPanel then EL:ShowSettingsPanel() end
    else
        if EL.ToggleAllWindows then
            EL:ToggleAllWindows()
        elseif EL.TogglePanel then
            EL:TogglePanel()
        end
    end
end

local function GetMinimapAngle(button)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local dx, dy = px - mx, py - my
    local angle
    if math.atan2 then
        angle = math.deg(math.atan2(dy, dx))
    else
        angle = math.deg(math.atan(dy / (dx ~= 0 and dx or 0.0001)))
        if dx < 0 then
            angle = angle + 180
        elseif dy < 0 then
            angle = angle + 360
        end
    end
    if angle < 0 then angle = angle + 360 end
    return angle
end

local function PositionFallbackButton(button)
    local settings = GetMinimapSettings()
    local angle = math.rad(tonumber(settings.minimapPos) or 220)
    local radius = 80
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function CreateFallbackButton()
    if EL.minimapButton then return EL.minimapButton end
    if not Minimap then return nil end

    local button = CreateFrame("Button", MINIMAP_BUTTON_NAME, Minimap, "BackdropTemplate")
    EL.minimapButton = button
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER", 0, 0)
    button.icon:SetSize(20, 20)
    button.icon:SetTexture(DEFAULT_ICON)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetAllPoints()
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints(button.icon)
    local ar, ag, ab = ThemeRGB("accent", 0.68, 0.68, 0.70)
    button.highlight:SetColorTexture(ar, ag, ab, 0.18)

    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function(btn)
            local settings = GetMinimapSettings()
            settings.minimapPos = GetMinimapAngle(btn)
            PositionFallbackButton(btn)
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        local settings = GetMinimapSettings()
        settings.minimapPos = GetMinimapAngle(self)
        PositionFallbackButton(self)
    end)
    button:SetScript("OnClick", function(_, mouseButton)
        HandleMinimapClick(mouseButton)
    end)
    button:SetScript("OnEnter", function(self)
        if EL.ShowMinimapTooltip then EL:ShowMinimapTooltip(self) end
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    PositionFallbackButton(button)
    return button
end

function EL:SetMinimapButtonShown(shown)
    local settings = GetMinimapSettings()
    settings.hide = shown == false

    if self.LibDBIcon and self.minimapDataObject then
        if settings.hide then
            self.LibDBIcon:Hide("EmberLedger")
        else
            self.LibDBIcon:Show("EmberLedger")
        end
    end

    if self.minimapButton then
        if self.minimapRegisteredWithDBIcon then
            self.minimapButton:Hide()
        elseif settings.hide then
            self.minimapButton:Hide()
        else
            self.minimapButton:Show()
        end
    end

    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
end

function EL:ToggleMinimapButton()
    local settings = GetMinimapSettings()
    self:SetMinimapButtonShown(settings.hide == true)
end

function EL:RefreshMinimapButton()
    local settings = GetMinimapSettings()
    if self.minimapDataObject then
        self.minimapDataObject.text = "EmberLedger"
    end
    if self.minimapButton then
        PositionFallbackButton(self.minimapButton)
        if self.minimapRegisteredWithDBIcon then
            self.minimapButton:Hide()
        elseif settings.hide then
            self.minimapButton:Hide()
        else
            self.minimapButton:Show()
        end
    end
end

local function TryRegisterLibDataBroker()
    if not LibStub then return false end
    local ldb = LibStub("LibDataBroker-1.1", true)
    if not ldb then return false end

    EL.minimapDataObject = EL.minimapDataObject or ldb:NewDataObject("EmberLedger", {
        type = "data source",
        text = "EmberLedger",
        icon = DEFAULT_ICON,
        OnClick = function(_, button) HandleMinimapClick(button) end,
        OnTooltipShow = function(tooltip)
            if not tooltip then return end
            local ar, ag, ab = ThemeRGB("accent", 0.68, 0.68, 0.70)
            tooltip:SetText("EmberLedger", ar, ag, ab)
            PopulateTooltipLines(tooltip)
        end,
    })

    local dbIcon = LibStub("LibDBIcon-1.0", true)
    if dbIcon and EL.minimapDataObject then
        EL.LibDBIcon = dbIcon
        if not EL.minimapRegisteredWithDBIcon then
            dbIcon:Register("EmberLedger", EL.minimapDataObject, GetMinimapSettings())
            EL.minimapRegisteredWithDBIcon = true
        end
        if EL.minimapButton then EL.minimapButton:Hide() end
        return true
    end
    return false
end

function M:OnLoad()
    local usedDBIcon = TryRegisterLibDataBroker()
    if not usedDBIcon then
        CreateFallbackButton()
    end
    if EL.RefreshMinimapButton then EL:RefreshMinimapButton() end
end

function M:Refresh()
    if EL.RefreshMinimapButton then EL:RefreshMinimapButton() end
end


function M:OnEvent(event)
    if event == "PLAYER_ENTERING_WORLD" and not EL.minimapRegisteredWithDBIcon then
        local usedDBIcon = TryRegisterLibDataBroker()
        if not usedDBIcon and not EL.minimapButton then
            CreateFallbackButton()
        end
        if EL.RefreshMinimapButton then EL:RefreshMinimapButton() end
    end
end
