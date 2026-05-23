local addonName, EL = ...
if not EL then return end

-- Curated profession cooldown readiness tracking.
-- Scope: compact alt-readiness signals for high-value profession cooldown crafts.
-- Not intended to become recipe accounting, reagent tracking, or auction analysis.
-- Stored data is lightweight per-character cooldown state and may be rebuilt from profession scans.
-- Store setup is centralized through EL:EnsureProfessionCooldownStore so Core and this module share the same path.
-- Spell IDs below are curated for Retail profession cooldown crafts.
-- If Blizzard changes recipe spells in a future patch, update this table rather than
-- broadening the feature into generic recipe/cooldown scanning.
-- Expansion metadata supports display-scope filtering while preserving all scanned data.
--
-- Expansion maintenance checklist:
-- 1. Update EL.CURRENT_EXPANSION_ID, EL.PREVIOUS_EXPANSION_ID, EL.EXPANSION_NAMES,
--    and EL.PROFESSION_EXPANSION_PREFIXES in Core.lua when a new expansion becomes current.
-- 2. Add or retire curated cooldown definitions below as Blizzard changes profession cooldowns.
-- 3. Assign expansionID to every definition so default Current Expansion filtering stays clean.
-- 4. Keep saved cooldown data expansion-neutral; filters should hide data, not delete it.

local module = {}

local PROF_ALCHEMY = 171
local PROF_TAILORING = 197
local EXPANSION_MIDNIGHT = EL.EXPANSION_IDS and EL.EXPANSION_IDS.MIDNIGHT or 11

EL.PROFESSION_COOLDOWN_DEFS = EL.PROFESSION_COOLDOWN_DEFS or {
    {
        key = "wondrous_synergist",
        professionID = PROF_ALCHEMY,
        professionName = "Alchemy",
        label = "Wondrous Synergist",
        shortLabel = "WS",
        spellID = 1230856,
        category = "Alchemy",
        expansionID = EXPANSION_MIDNIGHT,
    },
    {
        key = "bouquet_of_herbs",
        professionID = PROF_ALCHEMY,
        professionName = "Alchemy",
        label = "Bouquet of Herbs",
        shortLabel = "Herbs",
        aliases = { "Transmute: Bouquet of Herbs" },
        spellID = 1230892,
        craftedItemID = 245650,
        defaultRechargeSeconds = 18 * 60 * 60,
        defaultMaxCharges = 2,
        sharedCooldownKey = "alchemy_midnight_material_transmutes",
        sharedCooldownLabel = "Alchemy Material Transmutes",
        category = "Alchemy",
        expansionID = EXPANSION_MIDNIGHT,
    },
    {
        key = "box_of_rocks",
        professionID = PROF_ALCHEMY,
        professionName = "Alchemy",
        label = "Box of Rocks",
        shortLabel = "Rocks",
        aliases = { "Transmute: Box of Rocks" },
        spellID = 1230891,
        craftedItemID = 242650,
        defaultRechargeSeconds = 18 * 60 * 60,
        defaultMaxCharges = 2,
        sharedCooldownKey = "alchemy_midnight_material_transmutes",
        sharedCooldownLabel = "Alchemy Material Transmutes",
        category = "Alchemy",
        expansionID = EXPANSION_MIDNIGHT,
    },
    {
        key = "school_of_gems",
        professionID = PROF_ALCHEMY,
        professionName = "Alchemy",
        label = "School of Gems",
        shortLabel = "Gems",
        aliases = { "Transmute: School of Gems" },
        spellID = 1230893,
        craftedItemID = 245647,
        defaultRechargeSeconds = 18 * 60 * 60,
        defaultMaxCharges = 2,
        sharedCooldownKey = "alchemy_midnight_material_transmutes",
        sharedCooldownLabel = "Alchemy Material Transmutes",
        category = "Alchemy",
        expansionID = EXPANSION_MIDNIGHT,
    },
    {
        key = "dawnweave_bolt",
        professionID = PROF_TAILORING,
        professionName = "Tailoring",
        label = "Dawnweave Bolt",
        shortLabel = "Dawn",
        spellID = 446928,
        category = "Tailoring",
        expansionID = EXPANSION_MIDNIGHT,
    },
    {
        key = "duskweave_bolt",
        professionID = PROF_TAILORING,
        professionName = "Tailoring",
        label = "Duskweave Bolt",
        shortLabel = "Dusk",
        spellID = 446927,
        category = "Tailoring",
        expansionID = EXPANSION_MIDNIGHT,
    },
    {
        key = "arcanoweave_bolt",
        professionID = PROF_TAILORING,
        professionName = "Tailoring",
        label = "Arcanoweave Bolt",
        shortLabel = "Arcane",
        spellID = 1227926,
        category = "Tailoring",
        expansionID = EXPANSION_MIDNIGHT,
    },
    {
        key = "sunfire_silk_bolt",
        professionID = PROF_TAILORING,
        professionName = "Tailoring",
        label = "Sunfire Silk Bolt",
        shortLabel = "Sunfire",
        spellID = 1228060,
        category = "Tailoring",
        expansionID = EXPANSION_MIDNIGHT,
    },
}

local COOLDOWN_DEFS_BY_PROFESSION = {}
local COOLDOWN_DEFS_BY_KEY = {}
local COOLDOWN_DEFS_BY_ITEM = {}
local VALID_COOLDOWN_DEF_KEYS = {}
for _, def in ipairs(EL.PROFESSION_COOLDOWN_DEFS) do
    if def and def.key then
        COOLDOWN_DEFS_BY_KEY[def.key] = def
            VALID_COOLDOWN_DEF_KEYS[def.key] = true
        if def.professionID then
            COOLDOWN_DEFS_BY_PROFESSION[def.professionID] = COOLDOWN_DEFS_BY_PROFESSION[def.professionID] or {}
            table.insert(COOLDOWN_DEFS_BY_PROFESSION[def.professionID], def)
        end
        if def.craftedItemID then
            COOLDOWN_DEFS_BY_ITEM[def.craftedItemID] = def
        end
    end
end

local function ValidateCooldownDefinition(def, index)
    if not (EL and EL.db and EL.db.settings and EL.db.settings.debug) then return end
    local missing = {}
    if not def then
        missing[#missing + 1] = "definition"
    else
        if not def.key or def.key == "" then missing[#missing + 1] = "key" end
        if not def.professionID then missing[#missing + 1] = "professionID" end
        if not def.spellID then missing[#missing + 1] = "spellID" end
        if not def.label or def.label == "" then missing[#missing + 1] = "label" end
        if not def.expansionID then missing[#missing + 1] = "expansionID" end
    end
    if #missing > 0 and EL.Debug then
        EL:Debug("Profession cooldown definition " .. tostring(index or "?") .. " missing: " .. table.concat(missing, ", "))
    end
end

function EL:ValidateProfessionCooldownDefinitions()
    for index, def in ipairs(self.PROFESSION_COOLDOWN_DEFS or {}) do
        ValidateCooldownDefinition(def, index)
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
    if okText and type(text) == "string" then
        local okParsed, parsed = pcall(tonumber, text)
        if okParsed and type(parsed) == "number" then
            local okUsable, usable = pcall(function() return parsed + 0 end)
            if okUsable and type(usable) == "number" then return usable end
        end
    end
    return fallback
end

local function GetLatestExpansionID()
    if EL and type(EL.GetCurrentExpansionID) == "function" then
        return EL:GetCurrentExpansionID()
    end
    local level
    if type(GetExpansionLevel) == "function" then
        level = SafeNumber(GetExpansionLevel())
    end
    if not level and type(LE_EXPANSION_WAR_WITHIN) == "number" then
        level = SafeNumber(LE_EXPANSION_WAR_WITHIN)
    end
    return level or EXPANSION_MIDNIGHT
end

local function GetPreviousExpansionID()
    if EL and type(EL.GetPreviousExpansionID) == "function" then
        return EL:GetPreviousExpansionID()
    end
    local latest = GetLatestExpansionID()
    return math.max(0, (SafeNumber(latest) or EXPANSION_MIDNIGHT) - 1)
end

local function GetCooldownDisplayScope()
    local display = EL and EL.db and EL.db.settings and EL.db.settings.display or nil
    local scope = display and display.cooldownDisplayScope or "current"
    if scope ~= "current_previous" and scope ~= "all" then scope = "current" end
    return scope
end

local function IsCooldownDefinitionInDisplayScope(def)
    if not def then return false end
    local scope = GetCooldownDisplayScope()
    if scope == "all" then return true end
    local expansionID = SafeNumber(def.expansionID)
    if not expansionID then return true end
    local currentExpansionID = GetLatestExpansionID()
    if scope == "current_previous" then
        return expansionID >= GetPreviousExpansionID()
    end
    return expansionID >= currentExpansionID
end

local function GetHiddenCooldownSettings()
    local display = EL and EL.db and EL.db.settings and EL.db.settings.display or nil
    if not display then return nil end
    display.hiddenCooldowns = type(display.hiddenCooldowns) == "table" and display.hiddenCooldowns or {}
    return display.hiddenCooldowns
end

local function IsCooldownDefinitionUserVisible(def)
    if not def or not def.key then return false end
    local hidden = GetHiddenCooldownSettings()
    return not (hidden and hidden[def.key] == true)
end

local function ShouldDisplayCooldownDefinition(def)
    return IsCooldownDefinitionInDisplayScope(def) and IsCooldownDefinitionUserVisible(def)
end

function EL:GetCooldownDisplayScope()
    return GetCooldownDisplayScope()
end

function EL:SetCooldownDisplayScope(scope)
    if scope ~= "current_previous" and scope ~= "all" then scope = "current" end
    if not (self.db and self.db.settings and self.db.settings.display) then return false end
    self.db.settings.display.cooldownDisplayScope = scope
    self._hasCooldownColumnData = nil
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
    if self.RequestUpdate then self:RequestUpdate() end
    return true
end

function EL:IsProfessionCooldownHidden(key)
    if type(key) ~= "string" or key == "" then return false end
    local hidden = GetHiddenCooldownSettings()
    return hidden and hidden[key] == true or false
end

function EL:SetProfessionCooldownHidden(key, hidden)
    if type(key) ~= "string" or key == "" then return false end
    if not (self.db and self.db.settings and self.db.settings.display) then return false end
    local hiddenCooldowns = GetHiddenCooldownSettings()
    if not hiddenCooldowns then return false end
    if hidden then
        hiddenCooldowns[key] = true
    else
        hiddenCooldowns[key] = nil
    end
    self._hasCooldownColumnData = nil
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
    if self.RequestUpdate then self:RequestUpdate() end
    return true
end

function EL:GetProfessionCooldownVisibilityDefinitions()
    local defs = {}
    for _, def in ipairs(self.PROFESSION_COOLDOWN_DEFS or {}) do
        if IsCooldownDefinitionInDisplayScope(def) then
            table.insert(defs, def)
        end
    end
    return defs
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

local function LowerText(value)
    if value == nil then return nil end
    local ok, text = pcall(tostring, value)
    if not ok or type(text) ~= "string" or text == "" then return nil end
    local okLower, lowered = pcall(string.lower, text)
    return okLower and lowered or text
end

local function RecipeInfoMatchesDefinition(info, def)
    if type(info) ~= "table" or type(def) ~= "table" then return false end
    local name = LowerText(info.name)
    if not name then return false end

    local function Matches(candidate)
        candidate = LowerText(candidate)
        if not candidate or candidate == "" then return false end
        if name == candidate then return true end

        -- Some profession recipe names include a prefix such as "Transmute:" while
        -- EmberLedger's curated label intentionally stays short for compact UI display.
        -- Allow suffix/contained label matches so recipe discovery still finds the
        -- active recipe ID needed for learned-state and cooldown-timer APIs.
        local okFind, startIndex = pcall(string.find, name, candidate, 1, true)
        if okFind and startIndex then
            if startIndex == 1 then return true end
            local before = string.sub(name, startIndex - 1, startIndex - 1)
            if before == ":" or before == " " or before == "-" or before == "(" then return true end
        end
        local suffix = ": " .. candidate
        if string.sub(name, -#suffix) == suffix then return true end
        return false
    end

    if Matches(def.label) or Matches(def.shortLabel) or Matches(GetSpellName(def.spellID)) then return true end

    if type(def.aliases) == "table" then
        for _, alias in ipairs(def.aliases) do
            if Matches(alias) then return true end
        end
    end

    return false
end

local function IsRecipeLearned(recipeID, info)
    if type(info) == "table" then
        if info.learned == true or info.unlocked == true then return true end
        if info.learned == false or info.unlocked == false then return false end
    end
    if C_TradeSkillUI and C_TradeSkillUI.IsRecipeProfessionLearned then
        local learned = SafeCall(C_TradeSkillUI.IsRecipeProfessionLearned, recipeID)
        if learned ~= nil then return learned and true or false end
    end
    if C_TradeSkillUI and C_TradeSkillUI.IsOriginalCraftRecipeLearned then
        local learned = SafeCall(C_TradeSkillUI.IsOriginalCraftRecipeLearned, recipeID)
        if learned ~= nil then return learned and true or false end
    end
    return nil
end

local function GetMatchingRecipeIDsForDefinition(def)
    local ids = {}
    local seen = {}
    local function Add(id)
        id = SafeNumber(id)
        if id and id > 0 and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    Add(def and def.spellID)

    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local allRecipeIDs = SafeCall(C_TradeSkillUI.GetAllRecipeIDs)
        if type(allRecipeIDs) == "table" then
            for _, recipeID in ipairs(allRecipeIDs) do
                local info = GetRecipeInfo(recipeID)
                if RecipeInfoMatchesDefinition(info, def) then
                    Add(recipeID)
                end
            end
        end
    end

    return ids
end

local function GetKnownRecipeInfoForDefinition(def)
    for _, recipeID in ipairs(GetMatchingRecipeIDsForDefinition(def)) do
        local info = GetRecipeInfo(recipeID)
        if RecipeInfoMatchesDefinition(info, def) then
            local learned = IsRecipeLearned(recipeID, info)
            if learned == true then return info, recipeID, true end
            if learned == false then return info, recipeID, false end
        end
    end
    return nil, nil, nil
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

local function GetRecipeCooldownRemaining(def, knownRecipeInfo, knownRecipeID)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeCooldown and def and def.spellID) then return nil end

    -- Retail profession cooldowns may expose timing on a recipe ID that differs from
    -- the curated spell ID. Search the currently open profession recipe list by
    -- display name before falling back to the curated ID.
    local checked = {}
    local function TryCooldownID(id)
        id = SafeNumber(id)
        if not id or id <= 0 or checked[id] then return nil end
        checked[id] = true
        local remaining = SafeCall(C_TradeSkillUI.GetRecipeCooldown, id)
        remaining = SafeNumber(remaining)
        if remaining and remaining > 0 then return remaining end
        return nil
    end

    local function TryInfo(info)
        if type(info) ~= "table" then return nil end
        local remaining = SafeNumber(info.cooldownRemaining)
            or SafeNumber(info.cooldownTimeRemaining)
            or SafeNumber(info.timeRemaining)
            or SafeNumber(info.remainingCooldown)
            or SafeNumber(info.cooldown)
        if remaining and remaining > 0 then return remaining end

        return TryCooldownID(info.recipeID)
            or TryCooldownID(info.recipeSchematicID)
            or TryCooldownID(info.spellID)
            or TryCooldownID(info.craftSpellID)
            or TryCooldownID(info.itemID)
    end

    local remaining = TryCooldownID(knownRecipeID)
        or TryInfo(knownRecipeInfo)

    if remaining then return remaining end

    for _, recipeID in ipairs(GetMatchingRecipeIDsForDefinition(def)) do
        remaining = TryCooldownID(recipeID) or TryInfo(GetRecipeInfo(recipeID))
        if remaining then return remaining end
    end

    return nil
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
    local knownRecipeInfo, knownRecipeID, recipeLearned = GetKnownRecipeInfoForDefinition(def)
    local knownState = GetSpellOrRecipeKnownState(def.spellID)
    if knownState ~= true and recipeLearned ~= nil then knownState = recipeLearned end
    if knownState ~= true then return nil, knownState end

    local now = Now()
    local name = GetSpellName(def.spellID) or def.label or ("Spell " .. tostring(def.spellID))
    local currentCharges, maxCharges, chargeStart, chargeDuration, chargeModRate = GetSpellChargeData(def.spellID)
    local startTime, duration, isEnabled, modRate = GetSpellCooldownData(def.spellID)
    local recipeRemaining = GetRecipeCooldownRemaining(def, knownRecipeInfo, knownRecipeID)
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
    local readyTime

    -- Recipe cooldowns are the most reliable source while the Blizzard trade skill UI is open.
    -- Spell charge/cooldown APIs can temporarily return stale positive charges for shared
    -- profession cooldown buckets, which caused tooltip rows to fall back to Unknown.
    if recipeRemaining and recipeRemaining > 0 then
        ready = false
        remaining = recipeRemaining
        readyTime = now + recipeRemaining
        currentCharges = 0
        if maxCharges <= 0 then maxCharges = 1 end
    elseif maxCharges > 0 then
        currentCharges = math.max(0, math.min(maxCharges, currentCharges))
        if currentCharges > 0 then ready = true end
        if currentCharges < maxCharges and chargeStart > 0 and chargeDuration > 0 then
            remaining = math.max(0, (chargeStart + chargeDuration) - now)
        end
        if currentCharges > 0 then
            -- A charged profession cooldown is actionable when at least one charge is available.
            -- Track the next recharge separately in remaining, but keep readyTime as now so
            -- normalization does not incorrectly mark 1/max charges as unavailable.
            readyTime = now
        elseif chargeStart > 0 and chargeDuration > 0 then
            readyTime = chargeStart + chargeDuration
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
        if ready then
            readyTime = now
        elseif startTime > 0 and duration > 1 then
            readyTime = startTime + duration
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
        craftedItemID = def.craftedItemID,
        expansionID = def.expansionID,
        sharedCooldownKey = def.sharedCooldownKey,
        sharedCooldownLabel = def.sharedCooldownLabel,
        spellName = name,
        currentCharges = currentCharges,
        maxCharges = maxCharges,
        startTime = startTime,
        duration = duration,
        chargeStartTime = chargeStart,
        chargeDuration = chargeDuration,
        recipeID = knownRecipeID,
        recipeRemaining = recipeRemaining,
        nextChargeReadyTime = (maxCharges > 0 and remaining and remaining > 0) and (now + remaining) or nil,
        -- For shared charged profession cooldowns, each recovering charge can have its own timer.
        -- Store the known timer here and let group normalization choose the longest known timer
        -- as full recharge instead of adding recharge durations together.
        fullRechargeReadyTime = (not def.sharedCooldownKey and maxCharges > 0 and currentCharges < maxCharges and remaining and remaining > 0 and chargeDuration and chargeDuration > 0) and ((now + remaining) + (math.max(0, maxCharges - currentCharges - 1) * chargeDuration)) or nil,
        readyTime = readyTime,
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
    local defs = COOLDOWN_DEFS_BY_PROFESSION[SafeNumber(professionID)] or {}
    local filtered = {}
    for _, def in ipairs(defs) do
        if ShouldDisplayCooldownDefinition(def) then
            table.insert(filtered, def)
        end
    end
    return filtered
end

local function CopyCooldownRecord(record)
    if type(record) ~= "table" then return nil end
    local copy = {}
    for k, v in pairs(record) do copy[k] = v end
    return copy
end

local function DeriveReadyTime(record)
    if type(record) ~= "table" then return nil end
    local readyTime = SafeNumber(record.readyTime)
    if readyTime and readyTime > 0 then return readyTime end

    local maxCharges = SafeNumber(record.maxCharges, 0)
    if maxCharges > 0 then
        local chargeStart = SafeNumber(record.chargeStartTime, 0)
        local chargeDuration = SafeNumber(record.chargeDuration, 0)
        if chargeStart > 0 and chargeDuration > 0 then return chargeStart + chargeDuration end
    else
        local startTime = SafeNumber(record.startTime, 0)
        local duration = SafeNumber(record.duration, 0)
        if startTime > 0 and duration > 1 then return startTime + duration end
    end

    -- Older saved cooldown records stored remaining time but not the absolute ready time.
    -- Use the scan timestamp plus remaining time as a one-time compatibility fallback.
    local remaining = SafeNumber(record.remaining, 0)
    local lastUpdated = SafeNumber(record.lastUpdated, 0)
    if remaining > 0 and lastUpdated > 0 then return lastUpdated + remaining end
    return nil
end

local function GetNextChargeReadyTime(record)
    if type(record) ~= "table" then return nil end
    local nextChargeReadyTime = SafeNumber(record.nextChargeReadyTime)
    if nextChargeReadyTime and nextChargeReadyTime > 0 then return nextChargeReadyTime end

    local chargeStart = SafeNumber(record.chargeStartTime, 0)
    local chargeDuration = SafeNumber(record.chargeDuration, 0)
    if chargeStart > 0 and chargeDuration > 0 then return chargeStart + chargeDuration end

    local maxCharges = SafeNumber(record.maxCharges, 0)
    local currentCharges = SafeNumber(record.currentCharges, 0)
    if maxCharges > 0 and currentCharges <= 0 then
        local readyTime = SafeNumber(record.readyTime)
        if readyTime and readyTime > 0 then return readyTime end
    end

    local remaining = SafeNumber(record.remaining, 0)
    local lastUpdated = SafeNumber(record.lastUpdated, 0)
    if remaining > 0 and lastUpdated > 0 then return lastUpdated + remaining end
    return nil
end

local function GetFullRechargeReadyTime(record)
    if type(record) ~= "table" then return nil end
    local fullRechargeReadyTime = SafeNumber(record.fullRechargeReadyTime)
    if fullRechargeReadyTime and fullRechargeReadyTime > 0 then
        if not record.sharedCooldownKey or record.fullRechargeMode == "longest_timer" then
            return fullRechargeReadyTime
        end
    end

    local maxCharges = SafeNumber(record.maxCharges, 0)
    local currentCharges = SafeNumber(record.currentCharges, 0)
    local chargeDuration = SafeNumber(record.chargeDuration, 0)
    if maxCharges <= 0 or currentCharges >= maxCharges or chargeDuration <= 0 then return nil end

    local nextChargeReadyTime = GetNextChargeReadyTime(record)
    if nextChargeReadyTime and nextChargeReadyTime > 0 then
        if record.sharedCooldownKey then
            return nextChargeReadyTime
        end
        local chargesMissingAfterNext = math.max(0, maxCharges - currentCharges - 1)
        return nextChargeReadyTime + (chargesMissingAfterNext * chargeDuration)
    end
    return nil
end

local function NormalizeCooldownRecordTiming(record)
    if type(record) ~= "table" then return record end
    if record.unlearned then return record end

    -- Unknown should only mean EmberLedger has no reliable timing data.
    -- Older or transient shared-cooldown records may still carry a valid readyTime/remaining
    -- while flagged unknown from a failed scan, so recover those before display/summary use.
    if record.unknown then
        local recoveredReadyTime = DeriveReadyTime(record)
        if recoveredReadyTime and recoveredReadyTime > 0 then
            record.readyTime = recoveredReadyTime
            record.unknown = false
        else
            return record
        end
    end

    local now = Now()
    local maxCharges = SafeNumber(record.maxCharges, 0)
    if maxCharges > 0 then
        local currentCharges = math.max(0, math.min(maxCharges, SafeNumber(record.currentCharges, 0)))
        local chargeDuration = SafeNumber(record.chargeDuration, 0)
        local nextChargeTime = GetNextChargeReadyTime(record)

        if currentCharges < maxCharges and nextChargeTime and chargeDuration > 0 then
            while currentCharges < maxCharges and nextChargeTime <= now do
                currentCharges = currentCharges + 1
                if currentCharges < maxCharges then
                    nextChargeTime = nextChargeTime + chargeDuration
                end
            end
        end

        record.currentCharges = currentCharges
        record.maxCharges = maxCharges
        if currentCharges >= maxCharges then
            record.ready = true
            record.unknown = false
            record.readyTime = now
            record.remaining = 0
            record.nextChargeReadyTime = nil
            record.fullRechargeReadyTime = nil
        elseif currentCharges > 0 then
            record.ready = true
            record.unknown = false
            record.readyTime = now
            record.nextChargeReadyTime = nextChargeTime
            record.fullRechargeReadyTime = GetFullRechargeReadyTime(record)
            record.remaining = nextChargeTime and math.max(0, nextChargeTime - now) or SafeNumber(record.remaining, 0) or 0
        elseif nextChargeTime and nextChargeTime > 0 then
            record.ready = false
            record.unknown = false
            record.readyTime = nextChargeTime
            record.nextChargeReadyTime = nextChargeTime
            record.fullRechargeReadyTime = GetFullRechargeReadyTime(record)
            record.remaining = math.max(0, nextChargeTime - now)
        else
            record.ready = false
            record.unknown = true
            record.remaining = 0
            record.fullRechargeReadyTime = nil
        end
        return record
    end

    local readyTime = DeriveReadyTime(record)
    if readyTime and readyTime > 0 then
        record.readyTime = readyTime
        local remaining = math.max(0, readyTime - now)
        record.remaining = remaining
        record.ready = remaining <= 0
    elseif record.ready == true then
        record.remaining = 0
    else
        record.unknown = true
        record.remaining = 0
    end
    return record
end

local function FormatCooldownScanAge(timestamp)
    local scanned = SafeNumber(timestamp)
    if not scanned or scanned <= 0 then return nil end
    local elapsed = math.max(0, Now() - scanned)
    if EL and EL.FormatCountdown then
        return EL:FormatCountdown(elapsed) .. " ago"
    end
    if elapsed >= 86400 then return tostring(math.floor(elapsed / 86400)) .. "d ago" end
    if elapsed >= 3600 then return tostring(math.floor(elapsed / 3600)) .. "h ago" end
    if elapsed >= 60 then return tostring(math.floor(elapsed / 60)) .. "m ago" end
    return "just now"
end


local function ExtractCraftedItemIDFromEvent(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "string" then
            local link = value:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)") or value
            if type(GetItemInfoInstant) == "function" then
                local itemID = SafeCall(GetItemInfoInstant, link)
                itemID = SafeNumber(itemID)
                if itemID and COOLDOWN_DEFS_BY_ITEM[itemID] then return itemID end
            end
        elseif type(value) == "table" then
            local itemID = SafeNumber(value.itemID or value.id)
            if itemID and COOLDOWN_DEFS_BY_ITEM[itemID] then return itemID end
            local link = value.itemLink or value.hyperlink or value.link
            if link and type(GetItemInfoInstant) == "function" then
                itemID = SafeNumber(SafeCall(GetItemInfoInstant, link))
                if itemID and COOLDOWN_DEFS_BY_ITEM[itemID] then return itemID end
            end
        elseif type(value) == "number" then
            local numeric = SafeNumber(value)
            if numeric and COOLDOWN_DEFS_BY_ITEM[numeric] then return numeric end
            if type(GetItemInfoInstant) == "function" then
                local itemID = SafeNumber(SafeCall(GetItemInfoInstant, value))
                if itemID and COOLDOWN_DEFS_BY_ITEM[itemID] then return itemID end
            end
        end
    end
    return nil
end

local ApplySharedCooldownGroups

local function MarkCooldownCrafted(def)
    if not (EL and def and def.key) then return false end
    local store = EnsureProfessionCooldownStore()
    if type(store) ~= "table" then return false end
    local charKey = (EL.GetCurrentCharacter and select(1, EL:GetCurrentCharacter())) or (EL.GetCharacterKey and EL:GetCharacterKey())
    if not charKey then return false end
    store[charKey] = type(store[charKey]) == "table" and store[charKey] or {}
    local records = store[charKey]
    local now = Now()
    local recharge = SafeNumber(def.defaultRechargeSeconds, 0) or 0
    if recharge <= 0 then return false end
    local groupKey = def.sharedCooldownKey
    local affected = {}
    for _, candidate in ipairs(EL.PROFESSION_COOLDOWN_DEFS or {}) do
        if candidate and (candidate.key == def.key or (groupKey and candidate.sharedCooldownKey == groupKey)) then
            affected[#affected + 1] = candidate
        end
    end
    if #affected == 0 then affected[1] = def end

    local maxCharges = SafeNumber(def.defaultMaxCharges, 1) or 1
    local previousCharges
    for _, candidate in ipairs(affected) do
        local previous = type(records[candidate.key]) == "table" and records[candidate.key] or nil
        local candidateCharges = previous and SafeNumber(previous.currentCharges) or nil
        if candidateCharges then
            previousCharges = previousCharges and math.min(previousCharges, candidateCharges) or candidateCharges
        end
    end
    if not previousCharges then previousCharges = maxCharges end
    local currentCharges = math.max(0, math.min(maxCharges, previousCharges - 1))
    local previousNextReadyTime
    local previousFullRechargeReadyTime
    if previousCharges <= 1 then
        for _, candidate in ipairs(affected) do
            local previous = type(records[candidate.key]) == "table" and records[candidate.key] or nil
            local candidateNext = previous and GetNextChargeReadyTime(previous) or nil
            if candidateNext and candidateNext > now then
                previousNextReadyTime = previousNextReadyTime and math.min(previousNextReadyTime, candidateNext) or candidateNext
                previousFullRechargeReadyTime = previousFullRechargeReadyTime and math.max(previousFullRechargeReadyTime, candidateNext) or candidateNext
            end
            if not groupKey then
                local candidateFull = previous and GetFullRechargeReadyTime(previous) or nil
                if candidateFull and candidateFull > now then
                    previousFullRechargeReadyTime = previousFullRechargeReadyTime and math.max(previousFullRechargeReadyTime, candidateFull) or candidateFull
                end
            end
        end
    end
    local newChargeReadyTime = now + recharge
    local nextReadyTime = previousNextReadyTime and math.min(previousNextReadyTime, newChargeReadyTime) or newChargeReadyTime
    local fullRechargeReadyTime = nil
    if currentCharges < maxCharges then
        fullRechargeReadyTime = math.max(newChargeReadyTime, previousFullRechargeReadyTime or 0)
        if not groupKey then
            fullRechargeReadyTime = nextReadyTime + (math.max(0, maxCharges - currentCharges - 1) * recharge)
        end
    end

    for _, candidate in ipairs(affected) do
        local previous = type(records[candidate.key]) == "table" and records[candidate.key] or {}
        local record = CopyCooldownRecord(previous) or {}
        record.key = candidate.key
        record.label = candidate.label
        record.shortLabel = candidate.shortLabel or candidate.label
        record.category = candidate.category or candidate.professionName
        record.professionID = candidate.professionID
        record.professionName = candidate.professionName
        record.spellID = candidate.spellID
        record.craftedItemID = candidate.craftedItemID
        record.expansionID = candidate.expansionID
        record.sharedCooldownKey = candidate.sharedCooldownKey
        record.sharedCooldownLabel = candidate.sharedCooldownLabel
        record.currentCharges = currentCharges
        record.maxCharges = maxCharges
        record.chargeStartTime = now
        record.chargeDuration = recharge
        record.nextChargeReadyTime = nextReadyTime
        record.fullRechargeReadyTime = fullRechargeReadyTime
        record.fullRechargeMode = groupKey and "longest_timer" or nil
        record.remaining = math.max(0, nextReadyTime - now)
        record.readyTime = currentCharges > 0 and now or nextReadyTime
        record.ready = currentCharges > 0
        record.unknown = false
        record.unlearned = false
        record.lastUpdated = now
        records[candidate.key] = record
    end
    records._lastUpdated = now
    ApplySharedCooldownGroups(records)
    EL._hasCooldownColumnData = nil
    return true
end

local function QueueCooldownRefresh(delay, flagName)
    delay = SafeNumber(delay, 0.5) or 0.5
    flagName = flagName or "_cooldownRefreshPending"
    if C_Timer and C_Timer.After then
        if EL[flagName] then return end
        EL[flagName] = true
        C_Timer.After(delay, function()
            if EL then EL[flagName] = nil end
            if not EL or not EL.db then return end
            if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
            if EL.RequestUpdate then EL:RequestUpdate() end
        end)
    else
        if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
        if EL.RequestUpdate then EL:RequestUpdate() end
    end
end

function ApplySharedCooldownGroups(records)
    if type(records) ~= "table" then return end
    local groups = {}
    for key, record in pairs(records) do
        if type(record) == "table" and not record.unlearned then
            NormalizeCooldownRecordTiming(record)
            local groupKey = record.sharedCooldownKey
            if type(groupKey) == "string" and groupKey ~= "" then
                groups[groupKey] = groups[groupKey] or {}
                table.insert(groups[groupKey], record)
            end
        end
    end

    local now = Now()
    for _, entries in pairs(groups) do
        if #entries > 1 then
            local groupMaxCharges = 0
            local groupCurrentCharges
            local groupNextChargeTime
            local groupFullRechargeTime
            local groupRemaining = 0
            local groupLabel

            for _, record in ipairs(entries) do
                groupLabel = groupLabel or record.sharedCooldownLabel
                local maxCharges = SafeNumber(record.maxCharges, 0)
                local currentCharges = SafeNumber(record.currentCharges, 0)
                local nextChargeTime = GetNextChargeReadyTime(record)
                local fullRechargeTime = GetFullRechargeReadyTime(record)
                local remaining = SafeNumber(record.remaining, 0)

                if maxCharges > groupMaxCharges then groupMaxCharges = maxCharges end
                if maxCharges > 0 then
                    if not groupCurrentCharges or currentCharges < groupCurrentCharges then
                        groupCurrentCharges = currentCharges
                    end
                end
                if nextChargeTime and nextChargeTime > now then
                    if not groupNextChargeTime or nextChargeTime < groupNextChargeTime then
                        groupNextChargeTime = nextChargeTime
                    end
                    if not groupFullRechargeTime or nextChargeTime > groupFullRechargeTime then
                        groupFullRechargeTime = nextChargeTime
                    end
                end
                if fullRechargeTime and fullRechargeTime > now then
                    if not groupFullRechargeTime or fullRechargeTime > groupFullRechargeTime then
                        groupFullRechargeTime = fullRechargeTime
                    end
                end
                if remaining > groupRemaining then groupRemaining = remaining end
            end

            if groupMaxCharges > 0 and groupCurrentCharges ~= nil then
                groupCurrentCharges = math.max(0, math.min(groupMaxCharges, groupCurrentCharges))
                for _, record in ipairs(entries) do
                    record.sharedCooldownLabel = record.sharedCooldownLabel or groupLabel
                    record.currentCharges = groupCurrentCharges
                    record.maxCharges = groupMaxCharges
                    record.nextChargeReadyTime = groupNextChargeTime
                    if groupCurrentCharges >= groupMaxCharges then
                        record.ready = true
                        record.unknown = false
                        record.readyTime = now
                        record.remaining = 0
                        record.nextChargeReadyTime = nil
                        record.fullRechargeReadyTime = nil
                        record.fullRechargeMode = nil
                    elseif groupCurrentCharges > 0 then
                        record.ready = true
                        record.unknown = false
                        record.readyTime = now
                        record.fullRechargeReadyTime = groupFullRechargeTime or GetFullRechargeReadyTime(record)
                        record.fullRechargeMode = groupFullRechargeTime and "longest_timer" or record.fullRechargeMode
                        record.remaining = groupNextChargeTime and math.max(0, groupNextChargeTime - now) or groupRemaining
                    elseif groupNextChargeTime and groupNextChargeTime > now then
                        record.ready = false
                        record.unknown = false
                        record.readyTime = groupNextChargeTime
                        record.nextChargeReadyTime = groupNextChargeTime
                        record.fullRechargeReadyTime = groupFullRechargeTime or GetFullRechargeReadyTime(record)
                        record.fullRechargeMode = groupFullRechargeTime and "longest_timer" or record.fullRechargeMode
                        record.remaining = math.max(0, groupNextChargeTime - now)
                    else
                        record.ready = false
                        record.unknown = true
                        record.remaining = 0
                    end
                end
            elseif groupNextChargeTime and groupNextChargeTime > now then
                for _, record in ipairs(entries) do
                    record.sharedCooldownLabel = record.sharedCooldownLabel or groupLabel
                    record.ready = false
                    record.unknown = false
                    record.readyTime = groupNextChargeTime
                    record.nextChargeReadyTime = groupNextChargeTime
                    record.fullRechargeReadyTime = groupFullRechargeTime or GetFullRechargeReadyTime(record)
                    record.fullRechargeMode = groupFullRechargeTime and "longest_timer" or record.fullRechargeMode
                    record.remaining = math.max(0, groupNextChargeTime - now)
                end
            end
        end
    end
end


local function PreserveInferredChargedState(record, previous, def)
    if type(record) ~= "table" or type(previous) ~= "table" or type(def) ~= "table" then return record end
    local maxCharges = SafeNumber(def.defaultMaxCharges, 0) or 0
    if maxCharges <= 0 then return record end
    local previousCopy = CopyCooldownRecord(previous)
    NormalizeCooldownRecordTiming(previousCopy)
    local previousCharges = SafeNumber(previousCopy.currentCharges)
    local nextChargeReadyTime = GetNextChargeReadyTime(previousCopy)
    if previousCharges and previousCharges > 0 and nextChargeReadyTime and nextChargeReadyTime > Now() then
        record.currentCharges = previousCharges
        record.maxCharges = SafeNumber(previousCopy.maxCharges, maxCharges) or maxCharges
        record.chargeStartTime = SafeNumber(previousCopy.chargeStartTime, 0)
        record.chargeDuration = SafeNumber(previousCopy.chargeDuration, def.defaultRechargeSeconds or 0)
        record.nextChargeReadyTime = nextChargeReadyTime
        record.fullRechargeReadyTime = GetFullRechargeReadyTime(previousCopy)
        record.remaining = math.max(0, nextChargeReadyTime - Now())
        record.readyTime = Now()
        record.ready = true
        record.unknown = false
    end
    return record
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
                record = PreserveInferredChargedState(record, previousRecords and previousRecords[def.key], def)
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
                    craftedItemID = def.craftedItemID,
                    expansionID = def.expansionID,
                    sharedCooldownKey = def.sharedCooldownKey,
                    sharedCooldownLabel = def.sharedCooldownLabel,
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
                    previous.expansionID = previous.expansionID or def.expansionID
                    previous.sharedCooldownKey = previous.sharedCooldownKey or def.sharedCooldownKey
                    previous.sharedCooldownLabel = previous.sharedCooldownLabel or def.sharedCooldownLabel
                    NormalizeCooldownRecordTiming(previous)
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
                        craftedItemID = def.craftedItemID,
                        expansionID = def.expansionID,
                        sharedCooldownKey = def.sharedCooldownKey,
                        sharedCooldownLabel = def.sharedCooldownLabel,
                        unknown = true,
                        ready = false,
                        remaining = 0,
                        lastUpdated = Now(),
                    }
                end
            end
        end
    end

    ApplySharedCooldownGroups(records)

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
            if type(record) == "table" and ShouldDisplayCooldownDefinition(def) then
                local copy = {}
                for k, v in pairs(record) do copy[k] = v end
                copy.definition = def
                copy.label = copy.label or def.label
                copy.shortLabel = copy.shortLabel or def.shortLabel or def.label
                copy.category = copy.category or def.category or def.professionName
                copy.professionID = copy.professionID or def.professionID
                copy.spellID = copy.spellID or def.spellID
                copy.craftedItemID = copy.craftedItemID or def.craftedItemID
                copy.expansionID = copy.expansionID or def.expansionID
                copy.sharedCooldownKey = copy.sharedCooldownKey or def.sharedCooldownKey
                copy.sharedCooldownLabel = copy.sharedCooldownLabel or def.sharedCooldownLabel
                copy.unlearned = copy.unlearned and true or false
                copy.lastScan = SafeNumber(stored._lastUpdated) or SafeNumber(copy.lastUpdated)
                NormalizeCooldownRecordTiming(copy)
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
            if not included[def.key] and ShouldDisplayCooldownDefinition(def) then
                table.insert(results, {
                    key = def.key,
                    label = def.label,
                    shortLabel = def.shortLabel or def.label,
                    category = def.category or def.professionName,
                    professionID = def.professionID,
                    spellID = def.spellID,
                    craftedItemID = def.craftedItemID,
                    expansionID = def.expansionID,
                    sharedCooldownKey = def.sharedCooldownKey,
                    sharedCooldownLabel = def.sharedCooldownLabel,
                    unknown = true,
                    ready = false,
                    lastScan = type(stored) == "table" and SafeNumber(stored._lastUpdated) or nil,
                })
                included[def.key] = true
            end
        end
    end

    -- Re-apply shared cooldown grouping to display copies/placeholders so tooltip and
    -- summary rows recover shared-bucket countdowns even after an individual member
    -- was copied as Unknown from a transient scan result.
    ApplySharedCooldownGroups(results)

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
            local readyTime = DeriveReadyTime(entry)
            local remaining = 0
            if readyTime and readyTime > Now() then
                remaining = math.max(0, readyTime - Now())
            else
                remaining = SafeNumber(entry.remaining, 0)
            end
            if remaining and remaining > 0 then
                local right = (self.FormatCountdown and self:FormatCountdown(remaining) or tostring(math.ceil(remaining)))
                tooltip:AddDoubleLine(label, right, 0.72, 0.72, 0.72, 1.00, 0.82, 0.32)
            else
                tooltip:AddDoubleLine(label, "Unknown", 0.72, 0.72, 0.72, 0.58, 0.68, 0.78)
                tooltip:AddLine("      Open profession to refresh.", 0.58, 0.68, 0.78)
            end
        elseif entry.unlearned then
            tooltip:AddDoubleLine(label, "Unlearned", 0.72, 0.72, 0.72, 0.78, 0.62, 0.42)
        elseif entry.maxCharges and entry.maxCharges > 0 then
            local charges = tostring(entry.currentCharges or 0) .. "/" .. tostring(entry.maxCharges)
            local remaining = SafeNumber(entry.remaining, 0)
            local readyTime = SafeNumber(entry.readyTime)
            if remaining <= 0 and readyTime and readyTime > Now() then
                remaining = math.max(0, readyTime - Now())
            end
            local right = charges
            local nextChargeReadyTime = GetNextChargeReadyTime(entry)
            if remaining <= 0 and nextChargeReadyTime and nextChargeReadyTime > Now() then
                remaining = math.max(0, nextChargeReadyTime - Now())
            end
            local countdown = remaining > 0 and (self.FormatCountdown and self:FormatCountdown(remaining) or tostring(math.ceil(remaining))) or nil
            local fullRechargeReadyTime = GetFullRechargeReadyTime(entry)
            local fullCountdown
            if fullRechargeReadyTime and fullRechargeReadyTime > Now() then
                local fullRemaining = math.max(0, fullRechargeReadyTime - Now())
                if not remaining or fullRemaining > remaining + 1 then
                    fullCountdown = self.FormatCountdown and self:FormatCountdown(fullRemaining) or tostring(math.ceil(fullRemaining))
                end
            end
            if entry.ready == false and countdown then
                right = "next " .. countdown
                if fullCountdown then right = right .. ", full " .. fullCountdown end
            elseif (SafeNumber(entry.currentCharges, 0)) > 0 and entry.ready == true then
                right = charges .. " ready"
                if countdown then right = right .. ", next " .. countdown end
                if fullCountdown then right = right .. ", full " .. fullCountdown end
            elseif (SafeNumber(entry.currentCharges, 0)) <= 0 and countdown then
                right = "next " .. countdown
                if fullCountdown then right = right .. ", full " .. fullCountdown end
            elseif entry.ready == true then
                right = "READY"
            elseif readyTime and readyTime > Now() then
                right = (self.FormatCountdown and self:FormatCountdown(math.max(0, readyTime - Now())) or tostring(math.ceil(math.max(0, readyTime - Now()))))
            else
                right = "Unknown"
            end
            tooltip:AddDoubleLine(label, right, 0.72, 0.72, 0.72, entry.ready and 0.35 or 1.00, entry.ready and 1.00 or 0.82, entry.ready and 0.45 or 0.32)
        else
            local right = entry.ready and "READY" or ((SafeNumber(entry.remaining, 0)) > 0 and (self.FormatCountdown and self:FormatCountdown(entry.remaining) or tostring(entry.remaining)) or "Unknown")
            tooltip:AddDoubleLine(label, right, 0.72, 0.72, 0.72, entry.ready and 0.35 or 1.00, entry.ready and 1.00 or 0.82, entry.ready and 0.45 or 0.32)
        end
    end

    local store = EnsureProfessionCooldownStore()
    local stored = store and store[charKey]
    local age = type(stored) == "table" and FormatCooldownScanAge(stored._lastUpdated) or nil
    if age then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Last scanned", age, 0.62, 0.78, 0.92, 0.72, 0.72, 0.72)
    end
end

function module:OnLoad()
    if EL.ValidateProfessionCooldownDefinitions then EL:ValidateProfessionCooldownDefinitions() end
    if EL.EnsureProfessionCooldownStore then EL:EnsureProfessionCooldownStore() end
    if EL.PruneProfessionCooldownStore then EL:PruneProfessionCooldownStore() end
    if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
end

function module:Refresh()
    if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
end

function module:OnEvent(event, ...)
    -- PLAYER_ENTERING_WORLD is already covered by Core.lua via ForEachModule("Refresh").
    -- Handle only profession/cooldown-specific changes here to avoid duplicate login scans.
    if event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        local craftedItemID = ExtractCraftedItemIDFromEvent(...)
        local craftedDef = craftedItemID and COOLDOWN_DEFS_BY_ITEM[craftedItemID]
        if craftedDef then
            MarkCooldownCrafted(craftedDef)
            if EL.RequestUpdate then EL:RequestUpdate() end
        end
        -- Recipe cooldown availability can lag behind the craft-result event while
        -- the Blizzard profession UI remains open, especially for shared charged cooldowns.
        -- Queue an early refresh for responsiveness and a second settling refresh so shared
        -- cooldown buckets do not stay in a transient ready state until the window closes.
        QueueCooldownRefresh(0.8, "_cooldownCraftRefreshPending")
        QueueCooldownRefresh(2.5, "_cooldownCraftSettledRefreshPending")
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" then
        QueueCooldownRefresh(0.5)
    end
end

EL:RegisterModule("ProfessionCooldowns", module)
