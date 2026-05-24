local addonName, EL = ...

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local UISpecialFrames = _G.UISpecialFrames
local InCombatLockdown = _G.InCombatLockdown
local C_Timer = _G.C_Timer
local table_insert = table.insert or _G.tinsert

local function T(key, ...)
    if EL and EL.T then return EL:T(key, ...) end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, tostring(key), ...)
        if ok then return formatted end
    end
    return tostring(key)
end

local function AddBackdrop(frame, alpha, borderAlpha)
    if EL and EL.Style and EL.Style.AddBackdrop then return EL.Style:AddBackdrop(frame, alpha, borderAlpha) end
end

local function AddInnerBorder(frame)
    if EL and EL.Style and EL.Style.AddInnerBorder then return EL.Style:AddInnerBorder(frame) end
end

local function StyleBlizzardButton(button)
    if EL and EL.Style and EL.Style.StyleBlizzardButton then return EL.Style:StyleBlizzardButton(button) end
end

local function ThemeValue(key, fallback)
    local colors = (EL and EL.THEME_COLORS) or {}
    return tonumber(colors[key]) or fallback
end

local function ThemeAccentRGB()
    return ThemeValue("ACCENT_R", 0.68), ThemeValue("ACCENT_G", 0.68), ThemeValue("ACCENT_B", 0.70)
end

local function ThemeTextRGB()
    return ThemeValue("TEXT_R", 0.90), ThemeValue("TEXT_G", 0.91), ThemeValue("TEXT_B", 0.93)
end

local function RegisterEscClose(frameName)
    if type(UISpecialFrames) ~= "table" or not frameName or frameName == "" then return end
    for _, existing in ipairs(UISpecialFrames) do
        if existing == frameName then return end
    end
    table_insert(UISpecialFrames, frameName)
end


local ONBOARDING_BODY_TEXT = "EmberLedger learns your profession characters as you visit them.\n\nGetting Started:\n1. Log into each profession character you want to track.\n2. Open the Trade Skill window (press K, then choose a profession) once.\n3. Repeat this for each profession alt.\n\nConcentration, Artisan Moxie, and profession cooldowns are only available after opening the profession window. Your dashboard updates automatically as more characters are scanned.\n\nTip: /el help lists all commands and row interactions."

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

local topLevelFrameCounter = 100
local function BringEmberWindowToFront(frame)
    if not frame or not frame.SetFrameLevel then return end
    topLevelFrameCounter = math.min((tonumber(topLevelFrameCounter) or 100) + 1, 65535)
    frame:SetFrameLevel(topLevelFrameCounter)
end

-- Onboarding panel runtime. Slash command routing and onboarding state helpers
-- remain in Core.lua; the Options panel continues to call EL:ShowOnboardingPanel(true).

function EL:CreateOnboardingPanel()
    if self.onboardingPanel then return self.onboardingPanel end
    local f = CreateFrame("Frame", "EmberLedgerOnboardingPanel", UIParent, "BackdropTemplate")
    self.onboardingPanel = f
    f:SetSize(430, 304)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 70)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    AddBackdrop(f, 0.82, 0.85)
    AddInnerBorder(f)
    f:Hide()
    f:SetScript("OnHide", function()
        if EL and EL.MarkOnboardingSeen then EL:MarkOnboardingSeen() end
    end)
    RegisterEscClose("EmberLedgerOnboardingPanel")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 18, -18)
    f.title:SetPoint("TOPRIGHT", -18, -18)
    f.title:SetJustifyH("LEFT")
    f.title:SetText(T("Welcome to EmberLedger"))
    f.title:SetTextColor(ThemeAccentRGB())

    f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.body:SetPoint("TOPLEFT", 18, -52)
    f.body:SetPoint("TOPRIGHT", -18, -52)
    f.body:SetJustifyH("LEFT")
    f.body:SetJustifyV("TOP")
    if f.body.SetWordWrap then f.body:SetWordWrap(true) end
    f.body:SetTextColor(ThemeTextRGB())
    f.body:SetText(T(ONBOARDING_BODY_TEXT))

    f.optionsButton = MakeSettingsButton(f, T("Open Options"), 120, function()
        if EL.MarkOnboardingSeen then EL:MarkOnboardingSeen() end
        f:Hide()
        if EL.ShowSettingsPanel then EL:ShowSettingsPanel() end
    end)
    f.optionsButton:SetPoint("BOTTOMLEFT", 18, 16)

    f.okButton = MakeSettingsButton(f, T("Got It"), 100, function()
        if EL.MarkOnboardingSeen then EL:MarkOnboardingSeen() end
        f:Hide()
    end)
    f.okButton:SetPoint("BOTTOMRIGHT", -18, 16)

    f.close = MakeSettingsButton(f, "X", 24, function()
        if EL.MarkOnboardingSeen then EL:MarkOnboardingSeen() end
        f:Hide()
    end)
    f.close:SetPoint("TOPRIGHT", -10, -10)

    return f
end

function EL:RefreshOnboardingPanel()
    local f = self.onboardingPanel
    if not f then return end
    if f.title then
        f.title:SetText(T("Welcome to EmberLedger"))
        f.title:SetTextColor(ThemeAccentRGB())
    end
    if f.body then
        f.body:SetTextColor(ThemeTextRGB())
        f.body:SetText(T(ONBOARDING_BODY_TEXT))
    end
    if f.optionsButton then f.optionsButton:SetText(T("Open Options")) end
    if f.okButton then f.okButton:SetText(T("Got It")) end
end

function EL:ShowOnboardingPanel(manual)
    if not manual and self.ShouldShowFirstRunOnboarding and not self:ShouldShowFirstRunOnboarding() then return end
    if InCombatLockdown and InCombatLockdown() then
        if not manual then self._pendingOnboarding = true end
        return
    end
    local f = self:CreateOnboardingPanel()
    if self.RefreshOnboardingPanel then self:RefreshOnboardingPanel() end
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 70)
    f:Show()
    BringEmberWindowToFront(f)
end

function EL:ScheduleFirstRunOnboarding()
    if self._onboardingScheduled then return end
    if self.ShouldShowFirstRunOnboarding and not self:ShouldShowFirstRunOnboarding() then return end
    self._onboardingScheduled = true
    local function showLater()
        if not EL or not EL.ShowOnboardingPanel then return end
        EL:ShowOnboardingPanel(false)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(3, showLater)
    else
        showLater()
    end
end
