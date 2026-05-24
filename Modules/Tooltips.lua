local addonName, EL = ...
if not EL then return end

-- Dashboard row tooltip module.
-- Keeps row hover, profession detail, cooldown detail, and interaction hint text
-- outside UI.lua so the main dashboard file can stay focused on frame construction,
-- layout, and refresh work.
local M = {}


local function ThemeRGB(kind, fallbackR, fallbackG, fallbackB)
    local colors = EL and EL.THEME_COLORS or {}
    if kind == "text" then
        return tonumber(colors.TEXT_R) or fallbackR, tonumber(colors.TEXT_G) or fallbackG, tonumber(colors.TEXT_B) or fallbackB
    elseif kind == "muted" then
        return tonumber(colors.MUTED_TEXT_R) or fallbackR, tonumber(colors.MUTED_TEXT_G) or fallbackG, tonumber(colors.MUTED_TEXT_B) or fallbackB
    elseif kind == "value" then
        return tonumber(colors.VALUE_TEXT_R) or fallbackR, tonumber(colors.VALUE_TEXT_G) or fallbackG, tonumber(colors.VALUE_TEXT_B) or fallbackB
    elseif kind == "accent" then
        return tonumber(colors.ACCENT_R) or fallbackR, tonumber(colors.ACCENT_G) or fallbackG, tonumber(colors.ACCENT_B) or fallbackB
    end
    return fallbackR, fallbackG, fallbackB
end

local function T(key, ...)
    if EL and EL.T then return EL:T(key, ...) end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, tostring(key), ...)
        if ok then return formatted end
    end
    return tostring(key)
end

local TOOLTIP_SECTION_R, TOOLTIP_SECTION_G, TOOLTIP_SECTION_B = 0.46, 0.68, 0.96

local function AddTooltipSection(tooltip, title, r, g, b)
    if not tooltip then return end
    tooltip:AddLine(" ")
    if not r then r, g, b = TOOLTIP_SECTION_R, TOOLTIP_SECTION_G, TOOLTIP_SECTION_B end
    tooltip:AddLine(tostring(title or ""), r, g, b)
end

function M:FormatTooltipDate(timestamp)
    timestamp = EL:SafeNumber(timestamp, 0, "tooltip.date") or 0
    if timestamp <= 0 then return T("Unknown") end
    return date("%b %d, %I:%M %p", timestamp)
end

function M:FormatTooltipAgo(timestamp)
    timestamp = EL:SafeNumber(timestamp, 0, "tooltip.ago") or 0
    if timestamp <= 0 then return T("Unknown") end
    local elapsed = math.max(0, time() - timestamp)
    if elapsed < 60 then return T("just now") end
    if elapsed < 3600 then return T("%dm ago", math.floor(elapsed / 60)) end
    if elapsed < 86400 then return T("%dh %02dm ago", math.floor(elapsed / 3600), math.floor((elapsed % 3600) / 60)) end
    return T("%dd ago", math.floor(elapsed / 86400))
end

function M:AddProfessionCooldownTooltipLines(tooltip, charKey, profEntries)
    if type(EL.AddProfessionCooldownTooltipLines) ~= "function" then return end
    local ok, err = pcall(EL.AddProfessionCooldownTooltipLines, EL, tooltip, charKey, profEntries)
    if not ok and EL.db and EL.db.settings and EL.db.settings.debug and EL.Print then
        EL:Print(T("Cooldown tooltip unavailable: %s", tostring(err)))
    end
end

function M:ShowRowTooltip(row)
    if not row or not row.charKey then return end
    local char = EL.db and EL.db.characters and EL.db.characters[row.charKey or ""]
    local displayName = EL:GetCharacterDisplayName(char, row.charKey or "Character")
    local r, g, b = EL:GetClassColor(char and char.class)
    local now = time()

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(displayName, r, g, b)

    local textR, textG, textB = ThemeRGB("text", 0.88, 0.89, 0.91)
    local mutedR, mutedG, mutedB = ThemeRGB("muted", 0.76, 0.77, 0.80)
    local valueR, valueG, valueB = ThemeRGB("value", 0.90, 0.91, 0.93)
    local accentR, accentG, accentB = TOOLTIP_SECTION_R, TOOLTIP_SECTION_G, TOOLTIP_SECTION_B

    GameTooltip:AddDoubleLine(T("Realm"), (char and char.realm) or T("Unknown"), mutedR, mutedG, mutedB, valueR, valueG, valueB)
    GameTooltip:AddDoubleLine(T("Last seen"), self:FormatTooltipAgo(char and char.lastSeen), mutedR, mutedG, mutedB, valueR, valueG, valueB)

    AddTooltipSection(GameTooltip, T("Professions"), accentR, accentG, accentB)
    if row.profEntries and #row.profEntries > 0 then
        for i, prof in ipairs(row.profEntries) do
            local profName = EL:GetCleanProfessionName(prof.professionName)
            local abbrev = EL:GetProfessionAbbreviation(prof)
            local conc = EL:GetConcentrationEntryForProfession(row.charKey, prof)
            GameTooltip:AddDoubleLine(string.format("%d. %s", i, profName), abbrev, accentR, accentG, accentB, 1, 1, 1)
            if conc then
                local quantity = EL:SafeNumber(EL:GetEstimatedConcentration(conc, now), 0, "tooltip.concentration.quantity") or 0
                local maxQuantity = EL:SafeNumber(conc.maxQuantity, EL.CONCENTRATION_MAX_DEFAULT, "tooltip.concentration.maxQuantity") or EL.CONCENTRATION_MAX_DEFAULT
                local thresholdValue, hasOverride = EL:GetProfessionConcentrationThreshold(conc)
                GameTooltip:AddDoubleLine("   " .. T("Concentration"), string.format("%d/%d", quantity, maxQuantity), mutedR, mutedG, mutedB, valueR, valueG, valueB)
                GameTooltip:AddDoubleLine("   " .. T("Alert threshold"), tostring(thresholdValue) .. (hasOverride and " (" .. T("override") .. ")" or " (" .. T("global") .. ")"), mutedR, mutedG, mutedB, valueR, valueG, valueB)
                if quantity >= maxQuantity then
                    GameTooltip:AddDoubleLine("   " .. T("Full"), T("Now"), mutedR, mutedG, mutedB, valueR, valueG, valueB)
                elseif quantity >= thresholdValue then
                    GameTooltip:AddDoubleLine("   " .. T("Ready"), T("Now"), 0.35, 1.00, 0.45, 0.35, 1.00, 0.45)
                    GameTooltip:AddDoubleLine("   " .. T("Full in"), (EL.GetConcentrationFullIn and EL:GetConcentrationFullIn(conc, now)) or T("Unknown"), mutedR, mutedG, mutedB, valueR, valueG, valueB)
                else
                    local rate = EL:SafeNumber(EL.CONCENTRATION_RATE_PER_HOUR, 10, "tooltip.concentration.rate") or 10
                    local readySeconds = math.ceil(math.max(0, thresholdValue - quantity) / rate * 3600)
                    GameTooltip:AddDoubleLine("   " .. T("Ready at"), self:FormatTooltipDate(now + readySeconds), mutedR, mutedG, mutedB, valueR, valueG, valueB)
                    GameTooltip:AddDoubleLine("   " .. T("Full in"), (EL.GetConcentrationFullIn and EL:GetConcentrationFullIn(conc, now)) or T("Unknown"), mutedR, mutedG, mutedB, valueR, valueG, valueB)
                end
            else
                GameTooltip:AddLine("   " .. T("Concentration: not tracked"), mutedR, mutedG, mutedB)
            end
            local moxie = EL:GetMoxieEntryForProfession(row.charKey, prof)
            if moxie and type(moxie.quantity) == "number" then
                local moxieThreshold = EL.GetMoxieThreshold and EL:GetMoxieThreshold() or (EL.MOXIE_THRESHOLD_DEFAULT or 600)
                local ready = EL:SafeNumber(moxie.quantity, 0, "tooltip.moxie.quantity") >= moxieThreshold
                GameTooltip:AddDoubleLine("   " .. T("Moxie"), tostring(moxie.quantity), mutedR, mutedG, mutedB, ready and 0.35 or valueR, ready and 1 or valueG, ready and 0.45 or valueB)
            end
        end
    elseif row.concEntries and #row.concEntries > 0 then
        for i, data in ipairs(row.concEntries) do
            local profName = EL:GetCleanProfessionName(data.professionName)
            local abbrev = EL:GetProfessionAbbreviation(data)
            local quantity = EL:SafeNumber(EL:GetEstimatedConcentration(data, now), 0, "tooltip.fallbackConcentration.quantity") or 0
            local maxQuantity = EL:SafeNumber(data.maxQuantity, EL.CONCENTRATION_MAX_DEFAULT, "tooltip.fallbackConcentration.maxQuantity") or EL.CONCENTRATION_MAX_DEFAULT
            GameTooltip:AddDoubleLine(string.format("%d. %s", i, profName), abbrev, accentR, accentG, accentB, 1, 1, 1)
            GameTooltip:AddDoubleLine("   " .. T("Concentration"), string.format("%d/%d", quantity, maxQuantity), mutedR, mutedG, mutedB, valueR, valueG, valueB)
        end
    else
        GameTooltip:AddLine(T("No professions tracked yet."), mutedR, mutedG, mutedB)
    end

    self:AddProfessionCooldownTooltipLines(GameTooltip, row.charKey, row.profEntries)

    AddTooltipSection(GameTooltip, T("Imbued Mulch"), accentR, accentG, accentB)
    if EL:HasImbuedMulchAccess(row.mulchData) then
        local readyAt = EL:SafeNumber(row.mulchData.readyAt, 0, "tooltip.mulch.readyAt") or 0
        local remain = math.max(0, readyAt - now)
        GameTooltip:AddDoubleLine(T("Ready at"), remain <= 0 and T("Now") or self:FormatTooltipDate(readyAt), mutedR, mutedG, mutedB, valueR, valueG, valueB)
        GameTooltip:AddDoubleLine(T("In bags"), tostring(row.mulchData.itemCount or 0), mutedR, mutedG, mutedB, valueR, valueG, valueB)
    else
        GameTooltip:AddLine(T("No Imbued Mulch data tracked."), mutedR, mutedG, mutedB)
    end

    AddTooltipSection(GameTooltip, T("Row interactions"), accentR, accentG, accentB)
    if row.isCurrentCharacter then
        GameTooltip:AddLine(T("Viewing this character"), accentR, accentG, accentB)
    end
    if EL:IsCharacterPinned(row.charKey) then
        GameTooltip:AddLine(T("Pinned"), accentR, accentG, accentB)
    end
    GameTooltip:AddLine((EL:IsCharacterPinned(row.charKey) and T("Alt-click: unpin character") or T("Alt-click: pin character")), mutedR, mutedG, mutedB)
    GameTooltip:AddLine(T("Right-click: hide character"), mutedR, mutedG, mutedB)
    GameTooltip:AddLine(T("Shift-right-click: remove EmberLedger data"), accentR, accentG, accentB)
    GameTooltip:Show()
end

-- Compatibility wrapper for older internal callers while UI.lua migrates to the module.
function EL:ShowRowTooltip(row)
    return M:ShowRowTooltip(row)
end

function EL:FormatTooltipDate(timestamp)
    return M:FormatTooltipDate(timestamp)
end

function EL:FormatTooltipAgo(timestamp)
    return M:FormatTooltipAgo(timestamp)
end

EL:RegisterModule("tooltips", M)
