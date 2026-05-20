local addonName, EL = ...
if not EL then return end

-- Curated profession cooldown readiness tracking.
-- Scope: compact alt-readiness signals for high-value profession cooldown crafts.
-- Not intended to become recipe accounting, reagent tracking, or auction analysis.
-- Stored data is lightweight per-character cooldown state and may be rebuilt from profession scans.
-- Store setup is centralized through EL:EnsureProfessionCooldownStore so Core and this module share the same path.
-- Spell IDs below are curated for the current Retail profession cooldown crafts.
-- If Blizzard changes recipe spells in a future patch, update this table rather than
-- broadening the feature into generic recipe/cooldown scanning.

local module = {}

local PROF_ALCHEMY = 171
local PROF_TAILORING = 197

EL.PROFESSION_COOLDOWN_DEFS = EL.PROFESSION_COOLDOWN_DEFS or {
    {
        key = "wondrous_synergist",
        professionID = PROF_ALCHEMY,
        professionName = "Alchemy",
        label = "Wondrous Synergist",
        shortLabel = "WS",
        spellID = 1230856,
        category = "Alchemy",
    },
    {
        key = "bouquet_of_herbs",
        professionID = PROF_ALCHEMY,
        professionName = "Alchemy",
        label = "Bouquet of Herbs",
        shortLabel = "Herbs",
        spellID = 1230892,
        category = "Alchemy",
    },
    {
        key = "box_of_rocks",
        professionID = PROF_ALCHEMY,
        professionName = "Alchemy",
        label = "Box of Rocks",
        shortLabel = "Rocks",
        spellID = 1230891,
        category = "Alchemy",
    },
    {
        key = "school_of_gems",
        professionID = PROF_ALCHEMY,
        professionName = "Alchemy",
        label = "School of Gems",
        shortLabel = "Gems",
        spellID = 1230893,
        category = "Alchemy",
    },
    {
        key = "dawnweave_bolt",
        professionID = PROF_TAILORING,
        professionName = "Tailoring",
        label = "Dawnweave Bolt",
        shortLabel = "Dawn",
        spellID = 446928,
        category = "Tailoring",
    },
    {
        key = "duskweave_bolt",
        professionID = PROF_TAILORING,
        professionName = "Tailoring",
        label = "Duskweave Bolt",
        shortLabel = "Dusk",
        spellID = 446927,
        category = "Tailoring",
    },
    {
        key = "arcanoweave_bolt",
        professionID = PROF_TAILORING,
        professionName = "Tailoring",
        label = "Arcanoweave Bolt",
        shortLabel = "Arcane",
        spellID = 1227926,
        category = "Tailoring",
    },
    {
        key = "sunfire_silk_bolt",
        professionID = PROF_TAILORING,
        professionName = "Tailoring",
        label = "Sunfire Silk Bolt",
        shortLabel = "Sunfire",
        spellID = 1228060,
        category = "Tailoring",
    },
}

local COOLDOWN_DEFS_BY_PROFESSION = {}
local COOLDOWN_DEFS_BY_KEY = {}
local VALID_COOLDOWN_DEF_KEYS = {}
for _, def in ipairs(EL.PROFESSION_COOLDOWN_DEFS) do
    if def and def.key then
        COOLDOWN_DEFS_BY_KEY[def.key] = def
            VALID_COOLDOWN_DEF_KEYS[def.key] = true
        if def.professionID then
            COOLDOWN_DEFS_BY_PROFESSION[def.professionID] = COOLDOWN_DEFS_BY_PROFESSION[def.professionID] or {}
            table.insert(COOLDOWN_DEFS_BY_PROFESSION[def.professionID], def)
        end
    end
end

local function Now()
    return time and time() or 0
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
    return nil
end


local function EnsureProfessionCooldownStore()
    -- Store creation lives in Core.lua so database normalization and this module use one path.
    if type(EL.EnsureProfessionCooldownStore) == "function" then
        return EL:EnsureProfessionCooldownStore()
    end
    return nil
end

local function SafeNumber(value, fallback)
    if EL and type(EL.SafeNumber) == "function" then
        return EL:SafeNumber(value, fallback, "ProfessionCooldowns")
    end
    if value == nil then return fallback end
    local okNumber, direct = pcall(tonumber, value)
    if okNumber and type(direct) == "number" then
        local okUsable, usable = pcall(function() return direct + 0 end)
        if okUsable and type(usable) == "number" then return usable end
    end
    local okText, text = pcall(tostring, value)
    if okText and text and text ~= "" then
        local okParsed, parsed = pcall(tonumber, text)
        if okParsed and type(parsed) == "number" then
            local okUsable, usable = pcall(function() return parsed + 0 end)
            if okUsable and type(usable) == "number" then return usable end
        end
    end
    return fallback
end

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = SafeCall(C_Spell.GetSpellInfo, spellID)
        if type(info) == "table" and info.name then return info.name end
    end
    local name = SafeCall(GetSpellInfo, spellID)
    return name
end

local function GetRecipeInfo(spellID)
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local info = SafeCall(C_TradeSkillUI.GetRecipeInfo, spellID)
        if type(info) == "table" then return info end
    end
    return nil
end

local function CheckKnownAPI(fn, spellID)
    if type(fn) ~= "function" or not spellID then return nil end
    local ok, known = pcall(fn, spellID)
    if not ok then return nil end
    return known and true or false
end

local function GetSpellOrRecipeKnownState(spellID)
    if not spellID then return nil end

    local checked = false
    local known = CheckKnownAPI(IsPlayerSpell, spellID)
    if known ~= nil then
        checked = true
        if known == true then return true end
    end

    known = CheckKnownAPI(IsSpellKnown, spellID)
    if known ~= nil then
        checked = true
        if known == true then return true end
    end

    known = C_Spell and CheckKnownAPI(C_Spell.IsSpellKnown, spellID) or nil
    if known ~= nil then
        checked = true
        if known == true then return true end
    end

    local recipeInfo = GetRecipeInfo(spellID)
    if type(recipeInfo) == "table" then
        checked = true
        if recipeInfo.learned == true or recipeInfo.unlocked == true then
            -- Do not treat a browsable recipe name alone as learned.
            -- Some profession UI states expose unlearned recipe records while the trade skill frame is open.
            return true
        end
        if recipeInfo.learned == false or recipeInfo.unlocked == false then
            return false
        end
    end

    if checked then return false end
    return nil
end

local function GetSpellCooldownData(spellID)
    local startTime, duration, isEnabled, modRate = 0, 0, 1, 1
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = SafeCall(C_Spell.GetSpellCooldown, spellID)
        if type(info) == "table" then
            startTime = SafeNumber(info.start or info.startTime, 0)
            duration = SafeNumber(info.duration, 0)
            isEnabled = info.isEnabled == false and 0 or 1
            modRate = SafeNumber(info.modRate, 1)
            return startTime, duration, isEnabled, modRate
        end
    end
    local a, b, c, d = SafeCall(GetSpellCooldown, spellID)
    startTime = SafeNumber(a, 0)
    duration = SafeNumber(b, 0)
    isEnabled = SafeNumber(c, 1)
    modRate = SafeNumber(d, 1)
    return startTime, duration, isEnabled, modRate
end

local function GetSpellChargeData(spellID)
    if C_Spell and C_Spell.GetSpellCharges then
        local info = SafeCall(C_Spell.GetSpellCharges, spellID)
        if type(info) == "table" then
            return SafeNumber(info.currentCharges), SafeNumber(info.maxCharges), SafeNumber(info.cooldownStartTime or info.startTime), SafeNumber(info.cooldownDuration or info.duration), SafeNumber(info.chargeModRate or info.modRate, 1)
        end
    end
    local a, b, c, d, e = SafeCall(GetSpellCharges, spellID)
    return SafeNumber(a), SafeNumber(b), SafeNumber(c), SafeNumber(d), SafeNumber(e, 1)
end

local function CharacterHasProfession(professions, professionID)
    professionID = SafeNumber(professionID)
    if not professionID then return false end
    for _, prof in ipairs(professions or {}) do
        local id = SafeNumber(prof and (prof.professionID or prof.skillLineID or prof.skillLine))
        if id == professionID then return true end
    end
    return false
end

local function SortCooldownEntries(a, b)
    local ac = tostring(a and a.category or "")
    local bc = tostring(b and b.category or "")
    if ac == bc then
        return tostring(a and a.label or "") < tostring(b and b.label or "")
    end
    return ac < bc
end

local function BuildCooldownRecord(def)
    if not def or not def.spellID then return nil, nil end
    local knownState = GetSpellOrRecipeKnownState(def.spellID)
    if knownState ~= true then return nil, knownState end

    local now = Now()
    local name = GetSpellName(def.spellID) or def.label or ("Spell " .. tostring(def.spellID))
    local currentCharges, maxCharges, chargeStart, chargeDuration, chargeModRate = GetSpellChargeData(def.spellID)
    local startTime, duration, isEnabled, modRate = GetSpellCooldownData(def.spellID)
    currentCharges = SafeNumber(currentCharges, 0)
    maxCharges = SafeNumber(maxCharges, 0)
    chargeStart = SafeNumber(chargeStart, 0)
    chargeDuration = SafeNumber(chargeDuration, 0)
    chargeModRate = SafeNumber(chargeModRate, 1)
    startTime = SafeNumber(startTime, 0)
    duration = SafeNumber(duration, 0)
    isEnabled = SafeNumber(isEnabled, 1)
    modRate = SafeNumber(modRate, 1)
    -- Profession cooldown crafts currently report normal modRate values.
    -- Keep the raw API remaining time for display unless Blizzard adds profession-specific modifiers.

    local ready = false
    local remaining = 0
    if maxCharges > 0 then
        currentCharges = math.max(0, math.min(maxCharges, currentCharges))
        if currentCharges > 0 then ready = true end
        if currentCharges < maxCharges and chargeStart > 0 and chargeDuration > 0 then
            remaining = math.max(0, (chargeStart + chargeDuration) - now)
        end
    else
        if isEnabled == 0 then
            ready = false
        elseif duration <= 1 or startTime <= 0 then
            ready = true
        else
            remaining = math.max(0, (startTime + duration) - now)
            ready = remaining <= 0
        end
    end

    return {
        key = def.key,
        label = def.label or name,
        shortLabel = def.shortLabel or def.label or name,
        category = def.category or def.professionName or "Profession",
        professionID = def.professionID,
        professionName = def.professionName,
        spellID = def.spellID,
        spellName = name,
        currentCharges = currentCharges,
        maxCharges = maxCharges,
        startTime = startTime,
        duration = duration,
        chargeStartTime = chargeStart,
        chargeDuration = chargeDuration,
        remaining = remaining,
        ready = ready and true or false,
        lastUpdated = now,
    }
end

function EL:PruneProfessionCooldownStore()
    local store = EnsureProfessionCooldownStore()
    if type(store) ~= "table" then return false end
    local chars = self.db and self.db.characters or {}
    for charKey, records in pairs(store) do
        if type(charKey) == "string" and type(records) == "table" then
            if type(chars) == "table" and not chars[charKey] then
                store[charKey] = nil
            else
                for key in pairs(records) do
                    if key ~= "_lastUpdated" and not VALID_COOLDOWN_DEF_KEYS[key] then
                        records[key] = nil
                    end
                end
            end
        end
    end
    return true
end

function EL:GetProfessionCooldownDefinitionsForProfession(professionID)
    return COOLDOWN_DEFS_BY_PROFESSION[SafeNumber(professionID)] or {}
end

local function CopyCooldownRecord(record)
    if type(record) ~= "table" then return nil end
    local copy = {}
    for k, v in pairs(record) do copy[k] = v end
    return copy
end

function EL:RefreshCurrentProfessionCooldowns()
    local profile = self.ProfileStart and self:ProfileStart("RefreshCurrentProfessionCooldowns") or nil
    self._hasCooldownColumnData = nil
    local cooldownStore = EnsureProfessionCooldownStore()
    if not cooldownStore then if self.ProfileStop then self:ProfileStop("RefreshCurrentProfessionCooldowns", profile) end return false end
    if self.PruneProfessionCooldownStore then self:PruneProfessionCooldownStore() end

    local charKey, char = self:GetCurrentCharacter()
    charKey = charKey or (char and char.key) or (self.GetCharacterKey and self:GetCharacterKey())
    if not charKey then if self.ProfileStop then self:ProfileStop("RefreshCurrentProfessionCooldowns", profile) end return false end

    local professions = self:GetProfessionEntriesForCharacter(charKey) or {}
    if #professions == 0 and self.RefreshCurrentProfessionIdentity then
        self:RefreshCurrentProfessionIdentity()
        professions = self:GetProfessionEntriesForCharacter(charKey) or {}
    end

    local previousRecords = type(cooldownStore[charKey]) == "table" and cooldownStore[charKey] or nil
    local records = {}
    for _, def in ipairs(self.PROFESSION_COOLDOWN_DEFS or {}) do
        if CharacterHasProfession(professions, def.professionID) then
            local record, knownState = BuildCooldownRecord(def)
            if record then
                records[record.key] = record
            elseif knownState == false then
                records[def.key] = {
                    key = def.key,
                    label = def.label,
                    shortLabel = def.shortLabel or def.label,
                    category = def.category or def.professionName,
                    professionID = def.professionID,
                    professionName = def.professionName,
                    spellID = def.spellID,
                    unlearned = true,
                    ready = false,
                    remaining = 0,
                    lastUpdated = Now(),
                }
            else
                local previous = previousRecords and CopyCooldownRecord(previousRecords[def.key])
                if previous then
                    previous.unknownScan = true
                    previous.lastScanAttempt = Now()
                    records[def.key] = previous
                else
                    records[def.key] = {
                        key = def.key,
                        label = def.label,
                        shortLabel = def.shortLabel or def.label,
                        category = def.category or def.professionName,
                        professionID = def.professionID,
                        professionName = def.professionName,
                        spellID = def.spellID,
                        unknown = true,
                        ready = false,
                        remaining = 0,
                        lastUpdated = Now(),
                    }
                end
            end
        end
    end

    records._lastUpdated = Now()
    cooldownStore[charKey] = records
    if self.ProfileStop then self:ProfileStop("RefreshCurrentProfessionCooldowns", profile) end
    return true
end

function EL:GetProfessionCooldownEntriesForCharacter(charKey, professions)
    local results = {}
    if not charKey then return results end
    local store = EnsureProfessionCooldownStore()
    local stored = store and store[charKey]
    local included = {}

    if type(stored) == "table" then
        for _, def in ipairs(self.PROFESSION_COOLDOWN_DEFS or {}) do
            local record = stored[def.key]
            if type(record) == "table" then
                local copy = {}
                for k, v in pairs(record) do copy[k] = v end
                copy.definition = def
                copy.label = copy.label or def.label
                copy.shortLabel = copy.shortLabel or def.shortLabel or def.label
                copy.category = copy.category or def.category or def.professionName
                copy.professionID = copy.professionID or def.professionID
                copy.spellID = copy.spellID or def.spellID
                copy.unlearned = copy.unlearned and true or false
                table.insert(results, copy)
                included[def.key] = true
            end
        end
    end

    -- If a character has a supported profession but no scanned recipe data yet,
    -- include an Unknown placeholder so the tooltip explains why the CD column exists.
    for _, prof in ipairs(professions or self:GetProfessionEntriesForCharacter(charKey) or {}) do
        local profID = SafeNumber(prof and (prof.professionID or prof.skillLineID or prof.skillLine))
        for _, def in ipairs(COOLDOWN_DEFS_BY_PROFESSION[profID] or {}) do
            if not included[def.key] then
                table.insert(results, {
                    key = def.key,
                    label = def.label,
                    shortLabel = def.shortLabel or def.label,
                    category = def.category or def.professionName,
                    professionID = def.professionID,
                    spellID = def.spellID,
                    unknown = true,
                    ready = false,
                })
                included[def.key] = true
            end
        end
    end

    table.sort(results, SortCooldownEntries)
    return results
end

function EL:GetProfessionCooldownSummary(charKey, professions)
    local entries = self:GetProfessionCooldownEntriesForCharacter(charKey, professions)
    local tracked, ready, recovering, unknown, unlearned = 0, 0, 0, 0, 0
    local nextRemaining
    for _, entry in ipairs(entries) do
        tracked = tracked + 1
        if entry.unknown then
            unknown = unknown + 1
        elseif entry.unlearned then
            unlearned = unlearned + 1
        elseif entry.ready then
            ready = ready + 1
        else
            recovering = recovering + 1
            local remaining = SafeNumber(entry.remaining, 0)
            if remaining > 0 and (not nextRemaining or remaining < nextRemaining) then
                nextRemaining = remaining
            end
        end
    end
    return {
        entries = entries,
        tracked = tracked,
        ready = ready,
        recovering = recovering,
        unknown = unknown,
        unlearned = unlearned,
        nextRemaining = nextRemaining,
    }
end

local function FormatCooldownColumnTimer(seconds)
    local secs = SafeNumber(seconds, 0)
    if secs >= 3600 then
        return tostring(math.ceil(secs / 3600)) .. "h"
    end
    if secs >= 60 then
        return tostring(math.ceil(secs / 60)) .. "m"
    end
    return "<1m"
end

function EL:GetProfessionCooldownDisplayText(charKey, professions)
    local summary = self:GetProfessionCooldownSummary(charKey, professions)
    if summary.tracked <= 0 then return "-", summary end
    if summary.ready > 0 then return tostring(summary.ready), summary end
    if summary.nextRemaining and summary.nextRemaining > 0 then
        return FormatCooldownColumnTimer(summary.nextRemaining), summary
    end
    if summary.unknown > 0 then return "?", summary end
    return "-", summary
end

function EL:GetProfessionCooldownSortValue(charKey, professions)
    local summary = self:GetProfessionCooldownSummary(charKey, professions)
    if summary.tracked <= 0 then return nil end
    if summary.ready > 0 then return 0 - summary.ready end
    if summary.nextRemaining and summary.nextRemaining > 0 then return summary.nextRemaining end
    if summary.unknown > 0 then return 999999998 end
    return 999999999
end

function EL:HasProfessionCooldownColumnData(rows)
    if not (self.db and self.db.characters) then return false end
    if rows then
        for _, entry in ipairs(rows) do
            local charKey = entry and entry.key
            if charKey and not self:IsCharacterHidden(charKey) then
                local profs = self:GetProfessionEntriesForCharacter(charKey)
                if #(self:GetProfessionCooldownEntriesForCharacter(charKey, profs) or {}) > 0 then return true end
            end
        end
        return false
    end
    if self._hasCooldownColumnData ~= nil then return self._hasCooldownColumnData end
    local hasData = false
    for charKey in pairs(self.db.characters or {}) do
        if charKey and not self:IsCharacterHidden(charKey) then
            local profs = self:GetProfessionEntriesForCharacter(charKey)
            if #(self:GetProfessionCooldownEntriesForCharacter(charKey, profs) or {}) > 0 then
                hasData = true
                break
            end
        end
    end
    self._hasCooldownColumnData = hasData
    return hasData
end

function EL:AddProfessionCooldownTooltipLines(tooltip, charKey, professions)
    if not tooltip or not charKey then return end
    local entries = self:GetProfessionCooldownEntriesForCharacter(charKey, professions)
    tooltip:AddLine(" ")
    tooltip:AddLine("Profession Cooldowns", 0.62, 0.78, 0.92)
    if #entries == 0 then
        tooltip:AddLine("No supported profession cooldowns tracked.", 0.70, 0.70, 0.70)
        return
    end

    local currentCategory
    for _, entry in ipairs(entries) do
        local category = entry.category or "Profession"
        if category ~= currentCategory then
            tooltip:AddLine(category, 0.95, 0.82, 0.38)
            currentCategory = category
        end
        local label = "   " .. tostring(entry.label or entry.shortLabel or "Cooldown")
        if entry.unknown then
            tooltip:AddDoubleLine(label, "Open profession to scan", 0.72, 0.72, 0.72, 0.58, 0.68, 0.78)
        elseif entry.unlearned then
            tooltip:AddDoubleLine(label, "Unlearned", 0.72, 0.72, 0.72, 0.78, 0.62, 0.42)
        elseif entry.maxCharges and entry.maxCharges > 0 then
            local charges = tostring(entry.currentCharges or 0) .. "/" .. tostring(entry.maxCharges)
            local right = charges
            if (SafeNumber(entry.currentCharges, 0)) <= 0 and (SafeNumber(entry.remaining, 0)) > 0 then
                right = (self.FormatCountdown and self:FormatCountdown(entry.remaining) or charges)
            elseif (SafeNumber(entry.currentCharges, 0)) > 0 then
                right = charges .. " ready"
            end
            tooltip:AddDoubleLine(label, right, 0.72, 0.72, 0.72, entry.ready and 0.35 or 1.00, entry.ready and 1.00 or 0.82, entry.ready and 0.45 or 0.32)
        else
            local right = entry.ready and "READY" or ((SafeNumber(entry.remaining, 0)) > 0 and (self.FormatCountdown and self:FormatCountdown(entry.remaining) or tostring(entry.remaining)) or "Unknown")
            tooltip:AddDoubleLine(label, right, 0.72, 0.72, 0.72, entry.ready and 0.35 or 1.00, entry.ready and 1.00 or 0.82, entry.ready and 0.45 or 0.32)
        end
    end
end

function module:OnLoad()
    if EL.EnsureProfessionCooldownStore then EL:EnsureProfessionCooldownStore() end
    if EL.PruneProfessionCooldownStore then EL:PruneProfessionCooldownStore() end
    if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
end

function module:Refresh()
    if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
end

function module:OnEvent(event)
    -- PLAYER_ENTERING_WORLD is already covered by Core.lua via ForEachModule("Refresh").
    -- Handle only profession/cooldown-specific changes here to avoid duplicate login scans.
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.2, function()
                if not EL or not EL.db then return end
                if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
                if EL.RequestUpdate then EL:RequestUpdate() end
            end)
        else
            if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
        end
    end
end

EL:RegisterModule("ProfessionCooldowns", module)
