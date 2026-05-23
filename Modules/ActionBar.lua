local addonName, EL = ...

local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsShiftKeyDown = _G.IsShiftKeyDown
local UIParent = _G.UIParent

local UIC = EL.UI_CONSTANTS or {}
local ACTION_BAR_H = UIC.ACTION_BAR_H or 36
local ACTION_BAR_FLOATING_W = UIC.ACTION_BAR_FLOATING_W or 244
local ACTION_BAR_FLOATING_H = UIC.ACTION_BAR_FLOATING_H or 40

local THEME = EL.THEME_COLORS or {}
local BORDER_R, BORDER_G, BORDER_B = THEME.BORDER_R or 0.82, THEME.BORDER_G or 0.66, THEME.BORDER_B or 0.34
local EL_BG_R, EL_BG_G, EL_BG_B = THEME.BG_R or 0.030, THEME.BG_G or 0.024, THEME.BG_B or 0.075

local function SafeNumber(value, fallback, context)
    return EL:SafeNumber(value, fallback ~= nil and fallback or 0, context or "ActionBar")
end

local function SetTextIfChanged(fontString, text)
    if not fontString or not fontString.SetText then return end
    text = tostring(text or "")
    if fontString._emberLastText == text then return end
    fontString._emberLastText = text
    fontString:SetText(text)
end

local function AddBackdrop(frame, alpha, borderAlpha)
    if EL.Style and EL.Style.AddFlatBackdrop then
        return EL.Style:AddFlatBackdrop(frame, alpha, borderAlpha)
    end
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

local function GetActionBarPanelSettings()
    EL.db = EL.db or {}
    EL.db.settings = EL.db.settings or {}
    EL.db.settings.panel = EL.db.settings.panel or {}
    local panel = EL.db.settings.panel
    panel.actionBarPosition = type(panel.actionBarPosition) == "table" and panel.actionBarPosition or { point = "CENTER", relativePoint = "CENTER", x = 0, y = -160 }
    panel.actionBarPosition.point = panel.actionBarPosition.point or "CENTER"
    panel.actionBarPosition.relativePoint = panel.actionBarPosition.relativePoint or "CENTER"
    panel.actionBarPosition.x = SafeNumber(panel.actionBarPosition.x, 0)
    panel.actionBarPosition.y = SafeNumber(panel.actionBarPosition.y, -160)
    return panel
end

local function SaveActionBarPoint(frame)
    local panelSettings = GetActionBarPanelSettings()
    local point, _, relativePoint, x, y = frame:GetPoint()
    panelSettings.actionBarPosition.point = point or "CENTER"
    panelSettings.actionBarPosition.relativePoint = relativePoint or "CENTER"
    panelSettings.actionBarPosition.x = x or 0
    panelSettings.actionBarPosition.y = y or -160
end

local VALID_ANCHOR_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function SanitizeAnchorPoint(point, fallback)
    point = tostring(point or "")
    return VALID_ANCHOR_POINTS[point] and point or fallback or "CENTER"
end

local function SetFloatingActionBarPoint(bar, pos)
    if not bar then return end
    if InCombatLockdown and InCombatLockdown() then
        if EL.QueueCombatDeferredWork then EL:QueueCombatDeferredWork("actionBar") end
        return false
    end
    local point = SanitizeAnchorPoint(pos and pos.point, "CENTER")
    local relativePoint = SanitizeAnchorPoint(pos and pos.relativePoint, "CENTER")
    local x = SafeNumber(pos and pos.x, 0)
    local y = SafeNumber(pos and pos.y, -160)
    local ok = pcall(bar.SetPoint, bar, point, UIParent, relativePoint, x, y)
    if ok then return true end

    -- If another addon or a stale saved anchor causes an anchor-family error,
    -- reset to a plain UIParent center anchor instead of throwing a Lua error.
    local panelSettings = GetActionBarPanelSettings()
    panelSettings.actionBarPosition = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -160 }
    bar:ClearAllPoints()
    pcall(bar.SetPoint, bar, "CENTER", UIParent, "CENTER", 0, -160)
    return false
end

local function ApplyActionBarBackdrop(bar, floating)
    if not bar then return end
    if floating then
        AddBackdrop(bar, 0.08, 0.24)
    else
        AddBackdrop(bar, 0.18, 0.18)
        if bar.SetBackdropColor then bar:SetBackdropColor(EL_BG_R, EL_BG_G, EL_BG_B, 0.30) end
    end
end

local function ClearButtonTexture(button, getterName)
    if EL.Style and EL.Style.ClearButtonTexture then return EL.Style:ClearButtonTexture(button, getterName) end
end

local function DisableButtonArt(button)
    if EL.Style and EL.Style.DisableButtonArt then return EL.Style:DisableButtonArt(button) end
    ClearButtonTexture(button, "GetNormalTexture")
    ClearButtonTexture(button, "GetPushedTexture")
    ClearButtonTexture(button, "GetHighlightTexture")
    ClearButtonTexture(button, "GetDisabledTexture")
end

local function StyleBlizzardButton(button)
    if EL.Style and EL.Style.StyleActionBarButton then return EL.Style:StyleActionBarButton(button) end
    if not button then return end
    DisableButtonArt(button)
    AddBackdrop(button, 0.86, 0.60)
    if button.SetBackdropColor then button:SetBackdropColor(THEME.ACTION_BUTTON_BG_R or 0.10, THEME.ACTION_BUTTON_BG_G or 0.08, THEME.ACTION_BUTTON_BG_B or 0.16, 0.86) end
    if button.SetBackdropBorderColor then button:SetBackdropBorderColor(0.72, 0.56, 0.28, 0.60) end
    if button.SetTextColor then button:SetTextColor(THEME.ACTION_BUTTON_TEXT_R or 1.00, THEME.ACTION_BUTTON_TEXT_G or 0.86, THEME.ACTION_BUTTON_TEXT_B or 0.36) end
end

local function FormatActionCooldownText(seconds)
    seconds = SafeNumber(seconds, 0)
    if seconds <= 0 then return "" end
    if seconds < 60 then return tostring(math.ceil(seconds)) .. "s" end
    local minutes = math.ceil(seconds / 60)
    if minutes < 60 then return tostring(minutes) .. "m" end
    return tostring(math.ceil(minutes / 60)) .. "h"
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


-- Zone-gated utility actions are intentionally grouped here so future expansion
-- action buttons can be maintained in one compact table without affecting tracking systems.
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

-- Forward-declared so icon resolution can use the same zone-variant spell resolver as button attributes.
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
        if ok and SafeNumber(count, nil) then return SafeNumber(count, 0) end
        ok, count = pcall(C_Item.GetItemCount, item)
        if ok and SafeNumber(count, nil) then return SafeNumber(count, 0) end
    end
    if GetItemCount then
        local ok, count = pcall(GetItemCount, item, false, false, true)
        if ok and SafeNumber(count, nil) then return SafeNumber(count, 0) end
        ok, count = pcall(GetItemCount, item)
        if ok and SafeNumber(count, nil) then return SafeNumber(count, 0) end
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

local function NormalizeCooldownValues(start, duration, enable)
    return SafeNumber(start, 0), SafeNumber(duration, 0), SafeNumber(enable, 0)
end

local function GetActionCooldownSafe(info)
    if not info then return 0, 0, 0 end
    if info.kind == "spell" then
        local spell = ResolveKnownSpellID(info)
        if not spell then return 0, 0, 0 end
        if C_Spell and C_Spell.GetSpellCooldown then
            local ok, cd = pcall(C_Spell.GetSpellCooldown, spell)
            if ok and cd then
                return NormalizeCooldownValues(cd.startTime, cd.duration, cd.isEnabled and 1 or 0)
            end
        end
        if GetSpellCooldown then
            local ok, start, duration, enable = pcall(GetSpellCooldown, spell)
            if ok and start then return NormalizeCooldownValues(start, duration, enable) end
        end
        return 0, 0, 0
    elseif info.kind == "toy" then
        if info.itemID and C_ToyBox and C_ToyBox.GetToyCooldown then
            local ok, start, duration, enable = pcall(C_ToyBox.GetToyCooldown, info.itemID)
            if ok and start then return NormalizeCooldownValues(start, duration, enable) end
        end
        if info.itemID and C_Item and C_Item.GetItemCooldown then
            local ok, start, duration, enable = pcall(C_Item.GetItemCooldown, info.itemID)
            if ok and start then return NormalizeCooldownValues(start, duration, enable) end
        end
        if info.itemID and GetItemCooldown then
            local ok, start, duration, enable = pcall(GetItemCooldown, info.itemID)
            if ok and start then return NormalizeCooldownValues(start, duration, enable) end
        end
        return 0, 0, 0
    else
        local item = info.itemID or info.name
        if not item then return 0, 0, 0 end
        if C_Container and C_Container.GetItemCooldown then
            local ok, start, duration, enable = pcall(C_Container.GetItemCooldown, item)
            if ok and start then return NormalizeCooldownValues(start, duration, enable) end
        end
        if C_Item and C_Item.GetItemCooldown then
            local ok, start, duration, enable = pcall(C_Item.GetItemCooldown, item)
            if ok and start then return NormalizeCooldownValues(start, duration, enable) end
        end
        if GetItemCooldown then
            local ok, start, duration, enable = pcall(GetItemCooldown, item)
            if ok and start then return NormalizeCooldownValues(start, duration, enable) end
        end
        return 0, 0, 0
    end
end


local function SetSpellButtonAttributes(button, info)
    if not button or not info or info.kind ~= "spell" then return end
    local resolved = ResolveActionSpell(info)
    local spellName = (resolved and resolved.name) or info.name or info.label or ""
    local macrotext = "/cast " .. tostring(spellName)
    if button._emberMacrotext ~= macrotext then
        button:SetAttribute("type", "macro")
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext", macrotext)
        button:SetAttribute("macrotext1", macrotext)
        button._emberMacrotext = macrotext
    end
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
    if b.cooldown.SetHideCountdownNumbers then
        b.cooldown:SetHideCountdownNumbers(true)
    end

    b.cooldownText = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.cooldownText:SetPoint("CENTER", b.icon, "CENTER", 0, 0)
    b.cooldownText:SetFontObject("GameFontHighlightSmall")
    b.cooldownText:SetTextColor(1, 0.92, 0.72)
    b.cooldownText:SetShadowOffset(1, -1)
    b.cooldownText:SetText("")

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

function EL:GetActionBarFrame()
    return self.actionBar or (self.panel and self.panel.actionBar)
end

function EL:CreateActionBar(parent)
    local bar = CreateFrame("Frame", "EmberLedgerActionBar", parent or UIParent, "BackdropTemplate")
    self.actionBar = bar
    if parent then parent.actionBar = bar end
    bar:SetHeight(ACTION_BAR_H)
    ApplyActionBarBackdrop(bar, false)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(frame)
        if not (EL.IsActionBarFloating and EL:IsActionBarFloating()) then return end
        local panelSettings = GetActionBarPanelSettings()
        if panelSettings.actionBarLocked == true and not IsShiftKeyDown() then return end
        if EL.IsCombatLocked and EL:IsCombatLocked() then return end
        frame._emberDragging = true
        frame:StartMoving()
    end)
    bar:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        frame._emberDragging = false
        if EL.IsActionBarFloating and EL:IsActionBarFloating() then
            SaveActionBarPoint(frame)
        end
    end)

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
    bar.logout:SetPoint("RIGHT", bar, "RIGHT", -34, 0)

    if self.LayoutActionBar then self:LayoutActionBar() end
    if self:IsActionBarEnabled() then self:RequestActionBarRefresh() end
end

function EL:LayoutActionBar()
    if self:IsCombatLocked() then
        if self.QueueCombatDeferredWork then self:QueueCombatDeferredWork("layout") end
        return
    end
    local bar = self:GetActionBarFrame()
    local panel = self.panel
    if not bar then return end

    local enabled = not self.IsActionBarEnabled or self:IsActionBarEnabled()
    local floating = self.IsActionBarFloating and self:IsActionBarFloating()

    if floating and bar._emberDragging then
        bar:SetHeight(ACTION_BAR_FLOATING_H)
        bar:EnableMouse(true)
        ApplyActionBarBackdrop(bar, true)
        bar:SetShown(enabled)
        return
    end

    bar:ClearAllPoints()
    bar:SetHeight(floating and ACTION_BAR_FLOATING_H or ACTION_BAR_H)
    bar:SetWidth(floating and ACTION_BAR_FLOATING_W or 1)
    bar:EnableMouse(floating)
    ApplyActionBarBackdrop(bar, floating)

    if floating then
        bar:SetParent(UIParent)
        bar:SetClampedToScreen(true)
        local pos = GetActionBarPanelSettings().actionBarPosition
        SetFloatingActionBarPoint(bar, pos)
        bar:SetShown(enabled)
    elseif panel then
        bar:SetParent(panel)
        local actionBottom = ((EL.db and EL.db.settings and EL.db.settings.display and EL.db.settings.display.compactMode == true) and 8 or 10)
        bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, actionBottom)
        bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, actionBottom)
        bar:SetShown(enabled and panel:IsShown())
    else
        bar:SetShown(false)
    end
end

function EL:UpdateActionBar()
    local profile = self.ProfileStart and self:ProfileStart("UpdateActionBar") or nil
    if self:IsCombatLocked() then
        if self.QueueCombatDeferredWork then self:QueueCombatDeferredWork("actionBar") end
        if self.ProfileStop then self:ProfileStop("UpdateActionBar", profile) end
        return
    end
    if self.IsActionBarEnabled and not self:IsActionBarEnabled() then
        local bar = self.GetActionBarFrame and self:GetActionBarFrame() or (self.panel and self.panel.actionBar)
        if bar then bar:Hide() end
        if self.ProfileStop then self:ProfileStop("UpdateActionBar", profile) end
        return
    end
    local bar = self.GetActionBarFrame and self:GetActionBarFrame() or (self.panel and self.panel.actionBar)
    if not bar or not bar.itemButtons then if self.ProfileStop then self:ProfileStop("UpdateActionBar", profile) end return end
    if self.LayoutActionBar then self:LayoutActionBar() end

    local lastVisible
    local visibleCount = 0
    for _, info in ipairs(ACTION_ITEM_BUTTONS) do
        local b = bar.itemButtons[info.key]
        if b then
            local actionButtons = self.db and self.db.settings and self.db.settings.panel and self.db.settings.panel.actionButtons
            local enabled = (not actionButtons) or actionButtons[info.key] ~= false
            local available = enabled and GetActionAvailable(info) or false
            local show = enabled and ((not b.hideWhenMissing) or available)
            if info.kind == "spell" and enabled then SetSpellButtonAttributes(b, info) end
            b:SetShown(show)
            if show then
                b:ClearAllPoints()
                if lastVisible then
                    b:SetPoint("LEFT", lastVisible, "RIGHT", 3, 0)
                else
                    b:SetPoint("LEFT", bar, "LEFT", 6, 0)
                end
                lastVisible = b
                visibleCount = visibleCount + 1

                if b.icon then
                    if info.kind == "spell" then b.icon:SetTexture(GetActionIcon(info)) end
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
                if b.cooldownText then
                    local remaining = 0
                    if start and duration and duration > 1 then
                        remaining = math.max(0, (start + duration) - GetTime())
                    end
                    SetTextIfChanged(b.cooldownText, FormatActionCooldownText(remaining))
                end
            end
        end
    end

    if bar.logout then
        bar.logout:ClearAllPoints()
        bar.logout:SetPoint("RIGHT", bar, "RIGHT", -34, 0)
    end
    if self.IsActionBarFloating and self:IsActionBarFloating() then
        local dynamicW = 6 + (visibleCount * 29) + 3 + 72 + 34
        bar:SetWidth(math.max(ACTION_BAR_FLOATING_W, dynamicW))
    end
    if self.ProfileStop then self:ProfileStop("UpdateActionBar", profile) end
end

