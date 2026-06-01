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
local EXPANSION_WAR_WITHIN = EL.EXPANSION_IDS and EL.EXPANSION_IDS.WAR_WITHIN or 10

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
        expansionID = EXPANSION_WAR_WITHIN,
    },
    {
        key = "duskweave_bolt",
        professionID = PROF_TAILORING,
        professionName = "Tailoring",
        label = "Duskweave Bolt",
        shortLabel = "Dusk",
        spellID = 446927,
        category = "Tailoring",
        expansionID = EXPANSION_WAR_WITHIN,
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
    return EL:SafeNumber(value, fallback, "ProfessionCooldowns")
end

local function ProfileStart(label)
    return (EL and EL.ProfileStart) and EL:ProfileStart(label) or nil
end

local function ProfileStop(label, started)
    if EL and EL.ProfileStop then EL:ProfileStop(label, started) end
end

local LOGIN_READY_OVERWRITE_GUARD_SECONDS = 0.5

local function GetFineTime()
    if type(GetTime) == "function" then return GetTime() end
    return Now()
end

local function ArmLoginCooldownGuard()
    EL._professionCooldownLoginGuardUntil = math.max(SafeNumber(EL._professionCooldownLoginGuardUntil, 0) or 0, GetFineTime() + LOGIN_READY_OVERWRITE_GUARD_SECONDS)
end

local function IsLoginCooldownGuardActive()
    local guardUntil = SafeNumber(EL._professionCooldownLoginGuardUntil, 0) or 0
    return guardUntil > 0 and GetFineTime() < guardUntil
end

-- Arm early so the first profession scan after login is protected,
-- even before PLAYER_ENTERING_WORLD fires. Later login events extend this window.
ArmLoginCooldownGuard()

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
    ClearCooldownDisplayCache()
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
    ClearCooldownDisplayCache()
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


local SPELL_NAME_CACHE = {}
local RECIPE_MATCH_CACHE = { byKey = nil }

-- Short-lived display caches reduce repeated cooldown entry/summary rebuilding during
-- row sorting, row painting, launcher summaries, and tooltip prep. They are invalidated
-- whenever cooldown data or visibility settings change, and also expire quickly so
-- countdown text remains fresh.
local COOLDOWN_DISPLAY_CACHE_TTL_SECONDS = 0.35
local COOLDOWN_DISPLAY_CACHE_VERSION = 0
local COOLDOWN_ENTRIES_CACHE = {}
local COOLDOWN_SUMMARY_CACHE = {}

-- Short-lived display caches avoid rebuilding the same cooldown lists repeatedly
-- during bursty UI refreshes. Bumping the cache version invalidates all entries.
local function ClearCooldownDisplayCache()
    COOLDOWN_DISPLAY_CACHE_VERSION = COOLDOWN_DISPLAY_CACHE_VERSION + 1
    COOLDOWN_ENTRIES_CACHE = {}
    COOLDOWN_SUMMARY_CACHE = {}
    if EL then EL._hasCooldownColumnData = nil end
end

function EL:InvalidateProfessionCooldownDisplayCache()
    ClearCooldownDisplayCache()
end

-- Recipe/name lookup cache is rebuilt from current profession data after Blizzard
-- signals that the trade skill source may have changed.
local function ClearRecipeMatchCache()
    RECIPE_MATCH_CACHE.byKey = nil
    SPELL_NAME_CACHE = {}
    ClearCooldownDisplayCache()
end

local function GetSpellName(spellID)
    spellID = SafeNumber(spellID)
    if not spellID then return nil end
    if SPELL_NAME_CACHE[spellID] ~= nil then
        local cached = SPELL_NAME_CACHE[spellID]
        return cached ~= false and cached or nil
    end
    local name
    if C_Spell and C_Spell.GetSpellInfo then
        local info = SafeCall(C_Spell.GetSpellInfo, spellID)
        if type(info) == "table" and info.name then name = info.name end
    end
    if not name then name = SafeCall(GetSpellInfo, spellID) end
    SPELL_NAME_CACHE[spellID] = name or false
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

local function BuildRecipeMatchCache()
    local byKey = {}
    local seenByKey = {}
    local defs = EL.PROFESSION_COOLDOWN_DEFS or {}

    local function Add(def, id)
        if not (def and def.key) then return end
        id = SafeNumber(id)
        if not id or id <= 0 then return end
        byKey[def.key] = byKey[def.key] or {}
        seenByKey[def.key] = seenByKey[def.key] or {}
        if not seenByKey[def.key][id] then
            seenByKey[def.key][id] = true
            byKey[def.key][#byKey[def.key] + 1] = id
        end
    end

    for _, def in ipairs(defs) do
        Add(def, def and def.spellID)
    end

    -- C_TradeSkillUI.GetAllRecipeIDs can be expensive. Build the recipe-name
    -- match cache once per profession data change rather than scanning the full
    -- recipe list for every cooldown definition on every craft refresh.
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local allRecipeIDs = SafeCall(C_TradeSkillUI.GetAllRecipeIDs)
        if type(allRecipeIDs) == "table" then
            for _, recipeID in ipairs(allRecipeIDs) do
                local info = GetRecipeInfo(recipeID)
                if type(info) == "table" then
                    for _, def in ipairs(defs) do
                        if RecipeInfoMatchesDefinition(info, def) then
                            Add(def, recipeID)
                        end
                    end
                end
            end
        end
    end

    RECIPE_MATCH_CACHE.byKey = byKey
    return byKey
end

local function GetMatchingRecipeIDsForDefinition(def)
    if not (def and def.key) then return {} end
    local byKey = RECIPE_MATCH_CACHE.byKey or BuildRecipeMatchCache()
    return byKey[def.key] or { def.spellID }
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
    local recipeReadyTime

    -- Recipe cooldowns are the most reliable source while the Blizzard trade skill UI is open.
    -- Spell charge/cooldown APIs can temporarily return stale positive charges for shared
    -- profession cooldown buckets, which caused tooltip rows to fall back to Unknown.
    if recipeRemaining and recipeRemaining > 0 then
        ready = false
        remaining = recipeRemaining
        recipeReadyTime = now + recipeRemaining
        readyTime = recipeReadyTime
        if maxCharges <= 0 then maxCharges = SafeNumber(def.defaultMaxCharges, 0) or 0 end
        if maxCharges <= 0 then maxCharges = 1 end
        -- A positive recipe cooldown means this recipe is temporarily locked, but
        -- for shared charged cooldown pools it must not erase the shared bucket count.
        -- The CD column should reflect available shared charges; recipe locks remain
        -- tooltip/detail data and only block when the bucket has no usable charges.
        if def.sharedCooldownKey and maxCharges > 0 then
            currentCharges = math.max(0, math.min(maxCharges, currentCharges))
        else
            currentCharges = 0
        end
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
        recipeReadyTime = recipeReadyTime,
        nextChargeReadyTime = (maxCharges > 0 and recipeReadyTime) or ((maxCharges > 0 and remaining and remaining > 0) and (now + remaining) or nil),
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
    local recipeReadyTime = SafeNumber(record.recipeReadyTime)
    if recipeReadyTime and recipeReadyTime > 0 then return recipeReadyTime end

    local sharedRecipeReadyTime = SafeNumber(record.sharedRecipeReadyTime)
    if sharedRecipeReadyTime and sharedRecipeReadyTime > 0 then return sharedRecipeReadyTime end

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

local GetRecipeFallbackReadyTime

local function GetNextChargeReadyTime(record)
    if type(record) ~= "table" then return nil end
    local recipeFallbackReadyTime = GetRecipeFallbackReadyTime(record)
    if recipeFallbackReadyTime and recipeFallbackReadyTime > 0 then return recipeFallbackReadyTime end
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

GetRecipeFallbackReadyTime = function(record)
    if type(record) ~= "table" then return nil end
    local now = Now()
    local recipeReadyTime = SafeNumber(record.recipeReadyTime)
    if recipeReadyTime and recipeReadyTime > now then return recipeReadyTime end
    local sharedRecipeReadyTime = SafeNumber(record.sharedRecipeReadyTime)
    if sharedRecipeReadyTime and sharedRecipeReadyTime > now then return sharedRecipeReadyTime end
    return nil
end


-- Shared charged cooldown philosophy:
-- Some profession cooldown crafts spend charges from one bucket across multiple recipes.
-- EmberLedger treats any available charge as Ready while still preserving the next
-- recharge and full recharge timers for tooltip clarity. Saved future timing is
-- protected during login because profession APIs can briefly report Ready before
-- the profession window has repopulated.
local SharedCooldownBucket = {}

function SharedCooldownBucket.GetRecipeLockTime(record, now, extraReadyTime)
    if type(record) ~= "table" then return nil end
    local lockTime
    local recipeReadyTime = SafeNumber(record.recipeReadyTime)
    local sharedRecipeReadyTime = SafeNumber(record.sharedRecipeReadyTime)
    if recipeReadyTime and recipeReadyTime > now then lockTime = recipeReadyTime end
    if sharedRecipeReadyTime and sharedRecipeReadyTime > now then
        lockTime = lockTime and math.min(lockTime, sharedRecipeReadyTime) or sharedRecipeReadyTime
    end
    if extraReadyTime and extraReadyTime > now then
        lockTime = lockTime and math.min(lockTime, extraReadyTime) or extraReadyTime
    end
    return lockTime
end

function SharedCooldownBucket.GetBlockingReadyTime(record, currentCharges, nextChargeReadyTime, now, extraReadyTime)
    -- For shared charged profession cooldowns, a future recipe/charge timer usually
    -- means a charge is recovering, not that every recipe in the bucket is blocked.
    -- Only block the display when no usable charges remain. This keeps 1/2 charges
    -- actionable in the CD column while still showing the recharge timer in tooltips.
    if SafeNumber(currentCharges, 0) > 0 then return nil end

    local blockingReadyTime = SharedCooldownBucket.GetRecipeLockTime(record, now, extraReadyTime)
    if nextChargeReadyTime and nextChargeReadyTime > now then
        blockingReadyTime = blockingReadyTime and math.max(blockingReadyTime, nextChargeReadyTime) or nextChargeReadyTime
    end
    return blockingReadyTime
end

local function CountDistinctFutureTimes(times, now)
    local count = 0
    local seen = {}
    for _, value in ipairs(times or {}) do
        local timestamp = SafeNumber(value)
        if timestamp and timestamp > now then
            local bucket = math.floor(timestamp + 0.5)
            if not seen[bucket] then
                seen[bucket] = true
                count = count + 1
            end
        end
    end
    return count
end

function SharedCooldownBucket.GetRecoveringChargeCount(recordOrTiming, now, maxCharges)
    if type(recordOrTiming) ~= "table" then return 0 end
    now = SafeNumber(now, Now()) or Now()
    maxCharges = SafeNumber(maxCharges, recordOrTiming.maxCharges or 0) or 0
    if maxCharges <= 0 then return 0 end

    local count = CountDistinctFutureTimes({
        recordOrTiming.nextChargeReadyTime,
        recordOrTiming.fullRechargeReadyTime,
    }, now)
    return math.max(0, math.min(maxCharges, count))
end

function SharedCooldownBucket.ClampChargesByRecoveringTimers(currentCharges, maxCharges, recordOrTiming, now)
    maxCharges = SafeNumber(maxCharges, 0) or 0
    currentCharges = SafeNumber(currentCharges, maxCharges) or maxCharges
    if maxCharges <= 0 then return currentCharges end
    local recovering = SharedCooldownBucket.GetRecoveringChargeCount(recordOrTiming, now, maxCharges)
    if recovering > 0 then
        currentCharges = math.min(currentCharges, math.max(0, maxCharges - recovering))
    end
    return math.max(0, math.min(maxCharges, currentCharges))
end

function SharedCooldownBucket.GetFutureTiming(record, now)
    if type(record) ~= "table" then return nil end
    local recipeReadyTime = SafeNumber(record.recipeReadyTime)
    local sharedRecipeReadyTime = SafeNumber(record.sharedRecipeReadyTime)
    local nextChargeReadyTime = GetNextChargeReadyTime(record)
    local fullRechargeReadyTime = GetFullRechargeReadyTime(record)
    local hasFuture = (recipeReadyTime and recipeReadyTime > now)
        or (sharedRecipeReadyTime and sharedRecipeReadyTime > now)
        or (nextChargeReadyTime and nextChargeReadyTime > now)
        or (fullRechargeReadyTime and fullRechargeReadyTime > now)
    if not hasFuture then return nil end
    return {
        recipeReadyTime = recipeReadyTime,
        sharedRecipeReadyTime = sharedRecipeReadyTime,
        nextChargeReadyTime = nextChargeReadyTime,
        fullRechargeReadyTime = fullRechargeReadyTime,
        maxCharges = SafeNumber(record.maxCharges, 0) or 0,
        currentCharges = SafeNumber(record.currentCharges, 0) or 0,
        chargeStartTime = SafeNumber(record.chargeStartTime, 0) or 0,
        chargeDuration = SafeNumber(record.chargeDuration, 0) or 0,
        fullRechargeMode = record.fullRechargeMode,
    }
end

function SharedCooldownBucket.AccumulateFutureState(state, timing, now)
    if type(timing) ~= "table" then return state end
    state = state or {
        maxCharges = timing.maxCharges or 0,
        currentCharges = timing.currentCharges or 0,
        chargeDuration = timing.chargeDuration or 0,
    }
    if (timing.maxCharges or 0) > (state.maxCharges or 0) then state.maxCharges = timing.maxCharges end
    -- Shared charged cooldown records describe the same bucket. Use the highest
    -- reported bucket charge count and let real charge recovery timers clamp it down.
    -- A single recipe-specific lock must not force the whole pool to 0/max.
    state.currentCharges = math.max(state.currentCharges or 0, timing.currentCharges or 0)
    if (timing.chargeDuration or 0) > (state.chargeDuration or 0) then state.chargeDuration = timing.chargeDuration end
    if timing.nextChargeReadyTime and timing.nextChargeReadyTime > now then
        state.nextChargeReadyTime = state.nextChargeReadyTime and math.min(state.nextChargeReadyTime, timing.nextChargeReadyTime) or timing.nextChargeReadyTime
        state.fullRechargeReadyTime = state.fullRechargeReadyTime and math.max(state.fullRechargeReadyTime, timing.nextChargeReadyTime) or timing.nextChargeReadyTime
    end
    if timing.fullRechargeReadyTime and timing.fullRechargeReadyTime > now then
        state.fullRechargeReadyTime = state.fullRechargeReadyTime and math.max(state.fullRechargeReadyTime, timing.fullRechargeReadyTime) or timing.fullRechargeReadyTime
    end
    local lockTime = nil
    if timing.recipeReadyTime and timing.recipeReadyTime > now then lockTime = timing.recipeReadyTime end
    if timing.sharedRecipeReadyTime and timing.sharedRecipeReadyTime > now then
        lockTime = lockTime and math.min(lockTime, timing.sharedRecipeReadyTime) or timing.sharedRecipeReadyTime
    end
    if lockTime and lockTime > now then
        state.sharedRecipeReadyTime = state.sharedRecipeReadyTime and math.min(state.sharedRecipeReadyTime, lockTime) or lockTime
    end
    state.chargeStartTime = timing.chargeStartTime or state.chargeStartTime
    state.fullRechargeMode = timing.fullRechargeMode or state.fullRechargeMode
    return state
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
        local recipeReadyTime = SafeNumber(record.recipeReadyTime)
        local sharedRecipeReadyTime = SafeNumber(record.sharedRecipeReadyTime)
        if recipeReadyTime and recipeReadyTime <= now then
            record.recipeReadyTime = nil
            record.recipeRemaining = nil
            recipeReadyTime = nil
        end
        if sharedRecipeReadyTime and sharedRecipeReadyTime <= now then
            record.sharedRecipeReadyTime = nil
            record.sharedRecipeRemaining = nil
            sharedRecipeReadyTime = nil
        end

        -- Recipe cooldown data can mean one recipe in a shared pool is locked.
        -- It should not erase the shared charge bucket. Only non-shared cooldowns
        -- treat a recipe lock as fully unavailable.
        local recipeLockTime = SharedCooldownBucket.GetRecipeLockTime(record, now)
        if recipeLockTime and recipeLockTime > now and not record.sharedCooldownKey then
            currentCharges = 0
        end

        if currentCharges < maxCharges and nextChargeTime and chargeDuration > 0 then
            while currentCharges < maxCharges and nextChargeTime <= now do
                currentCharges = currentCharges + 1
                if currentCharges < maxCharges then
                    nextChargeTime = nextChargeTime + chargeDuration
                end
            end
        end

        currentCharges = SharedCooldownBucket.ClampChargesByRecoveringTimers(currentCharges, maxCharges, record, now)
        record.currentCharges = currentCharges
        record.maxCharges = maxCharges

        local blockingReadyTime = SharedCooldownBucket.GetBlockingReadyTime(record, currentCharges, nextChargeTime, now)

        if blockingReadyTime and blockingReadyTime > now then
            record.ready = false
            record.unknown = false
            record.readyTime = blockingReadyTime
            record.remaining = math.max(0, blockingReadyTime - now)
            record.nextChargeReadyTime = nextChargeTime
            record.fullRechargeReadyTime = GetFullRechargeReadyTime(record)
        elseif currentCharges >= maxCharges then
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
    local profile = ProfileStart("Cooldowns:MarkCooldownCrafted")
    if not (EL and def and def.key) then ProfileStop("Cooldowns:MarkCooldownCrafted", profile); return false end
    local store = EnsureProfessionCooldownStore()
    if type(store) ~= "table" then ProfileStop("Cooldowns:MarkCooldownCrafted", profile); return false end
    local charKey = (EL.GetCurrentCharacter and select(1, EL:GetCurrentCharacter())) or (EL.GetCharacterKey and EL:GetCharacterKey())
    if not charKey then ProfileStop("Cooldowns:MarkCooldownCrafted", profile); return false end
    store[charKey] = type(store[charKey]) == "table" and store[charKey] or {}
    local records = store[charKey]
    local now = Now()
    local recharge = SafeNumber(def.defaultRechargeSeconds, 0) or 0
    if recharge <= 0 then ProfileStop("Cooldowns:MarkCooldownCrafted", profile); return false end
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
    local previousRecoveringCharges = 0
    for _, candidate in ipairs(affected) do
        local previous = type(records[candidate.key]) == "table" and records[candidate.key] or nil
        local candidateCharges = previous and SafeNumber(previous.currentCharges) or nil
        if candidateCharges then
            previousCharges = previousCharges and math.min(previousCharges, candidateCharges) or candidateCharges
        end
        local recovering = previous and SharedCooldownBucket.GetRecoveringChargeCount(previous, now, maxCharges) or 0
        if recovering > previousRecoveringCharges then previousRecoveringCharges = recovering end
    end
    if not previousCharges then previousCharges = maxCharges end
    if previousRecoveringCharges > 0 then
        previousCharges = math.min(previousCharges, math.max(0, maxCharges - previousRecoveringCharges))
    end
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
        if groupKey then
            -- Shared profession cooldown buckets can report individual recipes as ready
            -- after a fresh login until the profession window is opened again. Persist a
            -- group-level recipe lock so the dashboard does not forget an active member
            -- cooldown between sessions.
            record.sharedRecipeReadyTime = newChargeReadyTime
            record.sharedRecipeRemaining = recharge
        end
        if candidate.key == def.key then
            record.recipeReadyTime = newChargeReadyTime
            record.recipeRemaining = recharge
        elseif SafeNumber(record.recipeReadyTime, 0) <= now then
            record.recipeReadyTime = nil
            record.recipeRemaining = nil
        end
        local recipeReadyTime = SafeNumber(record.recipeReadyTime)
        local blockingReadyTime = nil
        if recipeReadyTime and recipeReadyTime > now then
            blockingReadyTime = recipeReadyTime
        end
        if currentCharges <= 0 and nextReadyTime and nextReadyTime > now then
            blockingReadyTime = blockingReadyTime and math.max(blockingReadyTime, nextReadyTime) or nextReadyTime
        end
        record.remaining = blockingReadyTime and math.max(0, blockingReadyTime - now) or math.max(0, nextReadyTime - now)
        record.readyTime = blockingReadyTime or (currentCharges > 0 and now or nextReadyTime)
        record.ready = not blockingReadyTime and currentCharges > 0
        record.unknown = false
        record.unlearned = false
        record.lastUpdated = now
        records[candidate.key] = record
    end
    records._lastUpdated = now
    local sharedProfile = ProfileStart("Cooldowns:MarkCrafted:ApplySharedGroups")
    ApplySharedCooldownGroups(records)
    ProfileStop("Cooldowns:MarkCrafted:ApplySharedGroups", sharedProfile)
    ClearCooldownDisplayCache()
    ProfileStop("Cooldowns:MarkCooldownCrafted", profile)
    return true
end

local COOLDOWN_REFRESH_MIN_INTERVAL_SECONDS = 0.75

local function QueueCooldownRefresh(delay, flagName)
    delay = SafeNumber(delay, 0.5) or 0.5
    flagName = flagName or "_cooldownRefreshPending"
    if C_Timer and C_Timer.After then
        if EL[flagName] then return end
        EL[flagName] = true
        C_Timer.After(delay, function()
            local queuedProfile = ProfileStart("Cooldowns:QueuedRefresh:" .. tostring(flagName))
            if EL then EL[flagName] = nil end
            if not EL or not EL.db then
                ProfileStop("Cooldowns:QueuedRefresh:" .. tostring(flagName), queuedProfile)
                return
            end
            if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
            if EL.RequestUpdate then EL:RequestUpdate() end
            ProfileStop("Cooldowns:QueuedRefresh:" .. tostring(flagName), queuedProfile)
        end)
    else
        if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
        if EL.RequestUpdate then EL:RequestUpdate() end
    end
end

function ApplySharedCooldownGroups(records)
    if type(records) ~= "table" then return end
    local profile = ProfileStart("Cooldowns:ApplySharedCooldownGroups")
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
            local groupRecipeReadyTime
            local groupRemaining = 0
            local groupLabel

            for _, record in ipairs(entries) do
                groupLabel = groupLabel or record.sharedCooldownLabel
                local maxCharges = SafeNumber(record.maxCharges, 0)
                local currentCharges = SafeNumber(record.currentCharges, 0)
                local nextChargeTime = GetNextChargeReadyTime(record)
                local fullRechargeTime = GetFullRechargeReadyTime(record)
                local recipeReadyTime = SafeNumber(record.recipeReadyTime)
                local sharedRecipeReadyTime = SafeNumber(record.sharedRecipeReadyTime)
                local remaining = SafeNumber(record.remaining, 0)

                if recipeReadyTime and recipeReadyTime > now then
                    groupRecipeReadyTime = groupRecipeReadyTime and math.min(groupRecipeReadyTime, recipeReadyTime) or recipeReadyTime
                end
                if sharedRecipeReadyTime and sharedRecipeReadyTime > now then
                    groupRecipeReadyTime = groupRecipeReadyTime and math.min(groupRecipeReadyTime, sharedRecipeReadyTime) or sharedRecipeReadyTime
                end

                if maxCharges > groupMaxCharges then groupMaxCharges = maxCharges end
                if maxCharges > 0 then
                    -- All entries in a shared group consume the same charge bucket.
                    -- Prefer the highest reported bucket count, then clamp with real
                    -- recharge timers below. This avoids one recipe-specific lock
                    -- making the entire group appear as 0/max.
                    if not groupCurrentCharges or currentCharges > groupCurrentCharges then
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
                groupCurrentCharges = SharedCooldownBucket.ClampChargesByRecoveringTimers(groupCurrentCharges, groupMaxCharges, {
                    nextChargeReadyTime = groupNextChargeTime,
                    fullRechargeReadyTime = groupFullRechargeTime,
                    sharedRecipeReadyTime = groupRecipeReadyTime,
                }, now)
                for _, record in ipairs(entries) do
                    record.sharedCooldownLabel = record.sharedCooldownLabel or groupLabel
                    record.currentCharges = groupCurrentCharges
                    record.maxCharges = groupMaxCharges
                    record.nextChargeReadyTime = groupNextChargeTime
                    local recipeReadyTime = SafeNumber(record.recipeReadyTime)
                    local sharedRecipeReadyTime = SafeNumber(record.sharedRecipeReadyTime)
                    if recipeReadyTime and recipeReadyTime <= now then
                        record.recipeReadyTime = nil
                        record.recipeRemaining = nil
                        recipeReadyTime = nil
                    end
                    if sharedRecipeReadyTime and sharedRecipeReadyTime <= now then
                        record.sharedRecipeReadyTime = nil
                        record.sharedRecipeRemaining = nil
                        sharedRecipeReadyTime = nil
                    end
                    if groupRecipeReadyTime and groupRecipeReadyTime <= now then
                        groupRecipeReadyTime = nil
                    end
                    local blockingReadyTime = SharedCooldownBucket.GetBlockingReadyTime(record, groupCurrentCharges, groupNextChargeTime, now, groupRecipeReadyTime)

                    if blockingReadyTime and blockingReadyTime > now then
                        record.ready = false
                        record.unknown = false
                        record.readyTime = blockingReadyTime
                        record.fullRechargeReadyTime = groupFullRechargeTime or GetFullRechargeReadyTime(record)
                        record.fullRechargeMode = groupFullRechargeTime and "longest_timer" or record.fullRechargeMode
                        record.remaining = math.max(0, blockingReadyTime - now)
                    elseif groupCurrentCharges >= groupMaxCharges then
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
    ProfileStop("Cooldowns:ApplySharedCooldownGroups", profile)
end


local function BuildPreviousSharedCooldownState(previousRecords, sharedCooldownKey)
    if type(previousRecords) ~= "table" or type(sharedCooldownKey) ~= "string" or sharedCooldownKey == "" then return nil end

    local now = Now()
    local state
    for _, previous in pairs(previousRecords) do
        if type(previous) == "table" and previous.sharedCooldownKey == sharedCooldownKey then
            local copy = CopyCooldownRecord(previous)
            NormalizeCooldownRecordTiming(copy)
            state = SharedCooldownBucket.AccumulateFutureState(state, SharedCooldownBucket.GetFutureTiming(copy, now), now)
        end
    end
    return state
end

local function PreserveInferredChargedState(record, previous, def, previousSharedState)
    if type(record) ~= "table" or type(def) ~= "table" then return record end
    local maxCharges = SafeNumber(def.defaultMaxCharges, 0) or 0
    if maxCharges <= 0 then return record end

    local previousCopy = type(previous) == "table" and CopyCooldownRecord(previous) or nil
    if previousCopy then NormalizeCooldownRecordTiming(previousCopy) end

    local now = Now()
    local timing = previousSharedState or (previousCopy and SharedCooldownBucket.GetFutureTiming(previousCopy, now))

    -- Blizzard's spell charge APIs can briefly report a shared profession cooldown as
    -- ready after login/reload. Preserve confirmed saved future timing until it expires
    -- or a later profession scan provides a real replacement state.
    if timing then
        local previousMaxCharges = SafeNumber(timing.maxCharges, maxCharges) or maxCharges
        local previousCharges = SafeNumber(timing.currentCharges)
        local nextChargeReadyTime = timing.nextChargeReadyTime
        local fullRechargeReadyTime = timing.fullRechargeReadyTime
        local previousRecipeReadyTime = previousCopy and SafeNumber(previousCopy.recipeReadyTime) or nil
        local previousSharedRecipeReadyTime = SafeNumber(timing.sharedRecipeReadyTime)
        record.currentCharges = SharedCooldownBucket.ClampChargesByRecoveringTimers(previousCharges or 0, previousMaxCharges, timing, now)
        record.maxCharges = previousMaxCharges
        record.chargeStartTime = (previousSharedState and SafeNumber(previousSharedState.chargeStartTime, 0)) or (previousCopy and SafeNumber(previousCopy.chargeStartTime, 0)) or 0
        record.chargeDuration = (previousSharedState and SafeNumber(previousSharedState.chargeDuration, def.defaultRechargeSeconds or 0)) or (previousCopy and SafeNumber(previousCopy.chargeDuration, def.defaultRechargeSeconds or 0)) or def.defaultRechargeSeconds or 0
        record.nextChargeReadyTime = nextChargeReadyTime
        record.fullRechargeReadyTime = fullRechargeReadyTime
        record.fullRechargeMode = timing.fullRechargeMode or (previousCopy and previousCopy.fullRechargeMode)
        if previousSharedRecipeReadyTime and previousSharedRecipeReadyTime > now then
            record.sharedRecipeReadyTime = previousSharedRecipeReadyTime
            record.sharedRecipeRemaining = math.max(0, previousSharedRecipeReadyTime - now)
        end
        if previousRecipeReadyTime and previousRecipeReadyTime > now then
            record.recipeReadyTime = previousRecipeReadyTime
            record.recipeRemaining = math.max(0, previousRecipeReadyTime - now)
        end
        local blockingReadyTime = SharedCooldownBucket.GetBlockingReadyTime(record, record.currentCharges, nextChargeReadyTime, now)
        record.remaining = blockingReadyTime and math.max(0, blockingReadyTime - now) or (nextChargeReadyTime and math.max(0, nextChargeReadyTime - now) or (previousCopy and SafeNumber(previousCopy.remaining, 0)) or 0)
        if blockingReadyTime then
            record.readyTime = blockingReadyTime
            record.ready = false
        elseif record.currentCharges > 0 then
            record.readyTime = now
            record.ready = true
        else
            record.readyTime = nextChargeReadyTime or fullRechargeReadyTime
            record.ready = false
        end
        record.unknown = false
    end
    return record
end

local function ReapplyPreviousFutureCooldownState(records, previousRecords)
    if type(records) ~= "table" or type(previousRecords) ~= "table" then return false end
    local now = Now()
    local changed = false

    local function ApplyFutureState(record, previous, sharedState)
        if type(record) ~= "table" then return end
        local previousCopy = type(previous) == "table" and CopyCooldownRecord(previous) or nil
        if previousCopy then NormalizeCooldownRecordTiming(previousCopy) end

        local timing = sharedState or (previousCopy and SharedCooldownBucket.GetFutureTiming(previousCopy, now))
        if not timing then return end

        local recipeReadyTime = previousCopy and SafeNumber(previousCopy.recipeReadyTime) or nil
        local sharedRecipeReadyTime = SafeNumber(timing.sharedRecipeReadyTime)
        local nextChargeReadyTime = timing.nextChargeReadyTime
        local fullRechargeReadyTime = timing.fullRechargeReadyTime
        local previousMaxCharges = SafeNumber(timing.maxCharges) or SafeNumber(record.maxCharges, 0) or 0
        local previousCharges = SafeNumber(timing.currentCharges) or SafeNumber(record.currentCharges, previousMaxCharges) or previousMaxCharges
        local previousChargeDuration = SafeNumber(timing.chargeDuration) or SafeNumber(record.chargeDuration, 0) or 0

        if previousMaxCharges and previousMaxCharges > 0 then
            record.maxCharges = previousMaxCharges
            record.currentCharges = SharedCooldownBucket.ClampChargesByRecoveringTimers(previousCharges or 0, previousMaxCharges, timing, now)
        end
        if previousChargeDuration and previousChargeDuration > 0 then
            record.chargeDuration = previousChargeDuration
        end
        if recipeReadyTime and recipeReadyTime > now then
            record.recipeReadyTime = recipeReadyTime
            record.recipeRemaining = math.max(0, recipeReadyTime - now)
        end
        if sharedRecipeReadyTime and sharedRecipeReadyTime > now then
            record.sharedRecipeReadyTime = sharedRecipeReadyTime
            record.sharedRecipeRemaining = math.max(0, sharedRecipeReadyTime - now)
        end
        if nextChargeReadyTime and nextChargeReadyTime > now then
            record.nextChargeReadyTime = nextChargeReadyTime
        end
        if fullRechargeReadyTime and fullRechargeReadyTime > now then
            record.fullRechargeReadyTime = fullRechargeReadyTime
            record.fullRechargeMode = "longest_timer"
        end

        local blockingReadyTime = SharedCooldownBucket.GetBlockingReadyTime(record, record.currentCharges, record.nextChargeReadyTime, now)
        if blockingReadyTime and blockingReadyTime > now then
            record.ready = false
            record.unknown = false
            record.readyTime = blockingReadyTime
            record.remaining = math.max(0, blockingReadyTime - now)
        end
        changed = true
    end

    local sharedStates = {}
    for _, def in ipairs(EL.PROFESSION_COOLDOWN_DEFS or {}) do
        if def and def.sharedCooldownKey and not sharedStates[def.sharedCooldownKey] then
            sharedStates[def.sharedCooldownKey] = BuildPreviousSharedCooldownState(previousRecords, def.sharedCooldownKey)
        end
    end

    for _, def in ipairs(EL.PROFESSION_COOLDOWN_DEFS or {}) do
        if def and def.key and type(records[def.key]) == "table" then
            ApplyFutureState(records[def.key], previousRecords[def.key], def.sharedCooldownKey and sharedStates[def.sharedCooldownKey])
        end
    end
    return changed
end

-- Detect saved future cooldown timing before trusting fresh API-ready states.
local function HasFutureCooldownState(records)
    if type(records) ~= "table" then return false end
    local now = Now()
    for key, record in pairs(records) do
        if key ~= "_lastUpdated" and type(record) == "table" and not record.unlearned then
            local copy = CopyCooldownRecord(record)
            NormalizeCooldownRecordTiming(copy)
            local readyTime = DeriveReadyTime(copy)
            local nextChargeReadyTime = GetNextChargeReadyTime(copy)
            local fullRechargeReadyTime = GetFullRechargeReadyTime(copy)
            local recipeReadyTime = SafeNumber(copy.recipeReadyTime)
            local sharedRecipeReadyTime = SafeNumber(copy.sharedRecipeReadyTime)
            if (readyTime and readyTime > now)
                or (nextChargeReadyTime and nextChargeReadyTime > now)
                or (fullRechargeReadyTime and fullRechargeReadyTime > now)
                or (recipeReadyTime and recipeReadyTime > now)
                or (sharedRecipeReadyTime and sharedRecipeReadyTime > now) then
                return true
            end
        end
    end
    return false
end

function module:ApplyLoginCooldownGuard(previousRecords)
    if not IsLoginCooldownGuardActive() or not HasFutureCooldownState(previousRecords) then return false end
    QueueCooldownRefresh(LOGIN_READY_OVERWRITE_GUARD_SECONDS + 0.05, "_cooldownLoginSettledRefreshPending")
    return true
end

function EL:RefreshCurrentProfessionCooldowns()
    local profile = self.ProfileStart and self:ProfileStart("RefreshCurrentProfessionCooldowns") or nil
    local now = Now()
    local lastRefresh = SafeNumber(self._lastProfessionCooldownRefreshAt, 0) or 0
    if lastRefresh > 0 and (now - lastRefresh) < COOLDOWN_REFRESH_MIN_INTERVAL_SECONDS then
        if self.ProfileStop then self:ProfileStop("RefreshCurrentProfessionCooldowns", profile) end
        return false
    end
    self._lastProfessionCooldownRefreshAt = now
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
    if module:ApplyLoginCooldownGuard(previousRecords) then
        if self.ProfileStop then self:ProfileStop("RefreshCurrentProfessionCooldowns", profile) end
        return false
    end
    if #professions == 0 and type(previousRecords) == "table" then
        -- Full logout/login can fire cooldown refreshes before profession identity has
        -- repopulated. Do not replace confirmed saved cooldowns with an empty table.
        if self.ProfileStop then self:ProfileStop("RefreshCurrentProfessionCooldowns", profile) end
        return false
    end
    local previousSharedProfile = ProfileStart("Cooldowns:PreviousSharedState")
    local previousSharedStates = {}
    if type(previousRecords) == "table" then
        for _, def in ipairs(self.PROFESSION_COOLDOWN_DEFS or {}) do
            if def and def.sharedCooldownKey and not previousSharedStates[def.sharedCooldownKey] then
                previousSharedStates[def.sharedCooldownKey] = BuildPreviousSharedCooldownState(previousRecords, def.sharedCooldownKey)
            end
        end
    end
    ProfileStop("Cooldowns:PreviousSharedState", previousSharedProfile)
    local records = {}
    local buildRecordsProfile = ProfileStart("Cooldowns:BuildRecords")
    for _, def in ipairs(self.PROFESSION_COOLDOWN_DEFS or {}) do
        if CharacterHasProfession(professions, def.professionID) then
            local buildOneProfile = ProfileStart("Cooldowns:BuildCooldownRecord")
            local record, knownState = BuildCooldownRecord(def)
            ProfileStop("Cooldowns:BuildCooldownRecord", buildOneProfile)
            if record then
                record = PreserveInferredChargedState(record, previousRecords and previousRecords[def.key], def, def.sharedCooldownKey and previousSharedStates[def.sharedCooldownKey])
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
    ProfileStop("Cooldowns:BuildRecords", buildRecordsProfile)

    if HasFutureCooldownState(previousRecords) then
        local reapplyProfile = ProfileStart("Cooldowns:ReapplyPreviousFutureState")
        ReapplyPreviousFutureCooldownState(records, previousRecords)
        ProfileStop("Cooldowns:ReapplyPreviousFutureState", reapplyProfile)
    end
    local applySharedProfile = ProfileStart("Cooldowns:Refresh:ApplySharedGroups")
    ApplySharedCooldownGroups(records)
    ProfileStop("Cooldowns:Refresh:ApplySharedGroups", applySharedProfile)

    records._lastUpdated = Now()
    cooldownStore[charKey] = records
    ClearCooldownDisplayCache()
    if self.ProfileStop then self:ProfileStop("RefreshCurrentProfessionCooldowns", profile) end
    return true
end


local function GetProfessionSignature(professions)
    if type(professions) ~= "table" then return "" end
    local parts = {}
    for index, prof in ipairs(professions) do
        local profID = SafeNumber(prof and (prof.professionID or prof.skillLineID or prof.skillLine), 0) or 0
        local name = prof and (prof.name or prof.professionName or prof.skillLineName) or ""
        parts[#parts + 1] = tostring(index) .. ":" .. tostring(profID) .. ":" .. tostring(name)
    end
    return table.concat(parts, "|")
end

local function GetCooldownVisibilitySignature()
    local hidden = GetHiddenCooldownSettings()
    if type(hidden) ~= "table" then return "" end
    local parts = {}
    for key, value in pairs(hidden) do
        if value == true then parts[#parts + 1] = tostring(key) end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

local function GetCooldownCacheKey(charKey, professions, stored)
    return table.concat({
        tostring(charKey or ""),
        tostring(GetCooldownDisplayScope()),
        tostring(SafeNumber(stored and stored._lastUpdated, 0) or 0),
        GetProfessionSignature(professions),
        GetCooldownVisibilitySignature(),
    }, "\031")
end

local function IsCooldownDisplayCacheFresh(entry, key, now)
    return entry
        and entry.version == COOLDOWN_DISPLAY_CACHE_VERSION
        and entry.key == key
        and entry.expiresAt
        and entry.expiresAt > now
end

function EL:GetProfessionCooldownEntriesForCharacter(charKey, professions)
    local profile = ProfileStart("Cooldowns:GetEntriesForCharacter")
    local results = {}
    if not charKey then
        ProfileStop("Cooldowns:GetEntriesForCharacter", profile)
        return results
    end
    local store = EnsureProfessionCooldownStore()
    local stored = store and store[charKey]
    local cacheNow = GetFineTime()
    local cacheKey = GetCooldownCacheKey(charKey, professions, stored)
    local cached = COOLDOWN_ENTRIES_CACHE[charKey]
    if IsCooldownDisplayCacheFresh(cached, cacheKey, cacheNow) then
        ProfileStop("Cooldowns:GetEntriesForCharacter", profile)
        return cached.results
    end
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
    local displaySharedProfile = ProfileStart("Cooldowns:GetEntries:ApplySharedGroups")
    ApplySharedCooldownGroups(results)
    ProfileStop("Cooldowns:GetEntries:ApplySharedGroups", displaySharedProfile)

    local sortProfile = ProfileStart("Cooldowns:GetEntries:Sort")
    table.sort(results, SortCooldownEntries)
    ProfileStop("Cooldowns:GetEntries:Sort", sortProfile)
    COOLDOWN_ENTRIES_CACHE[charKey] = {
        version = COOLDOWN_DISPLAY_CACHE_VERSION,
        key = cacheKey,
        expiresAt = cacheNow + COOLDOWN_DISPLAY_CACHE_TTL_SECONDS,
        results = results,
    }
    ProfileStop("Cooldowns:GetEntriesForCharacter", profile)
    return results
end

local FormatCooldownDuration
local ComputeCanonicalCooldownState
local FormatCooldownTooltipState

function EL:GetProfessionCooldownSummary(charKey, professions)
    if not charKey then
        return { entries = {}, tracked = 0, ready = 0, recovering = 0, unknown = 0, unlearned = 0, nextRemaining = nil }
    end
    local store = EnsureProfessionCooldownStore()
    local stored = store and store[charKey]
    local cacheNow = GetFineTime()
    local cacheKey = GetCooldownCacheKey(charKey, professions, stored)
    local cached = COOLDOWN_SUMMARY_CACHE[charKey]
    if IsCooldownDisplayCacheFresh(cached, cacheKey, cacheNow) then
        return cached.summary
    end

    local entries = self:GetProfessionCooldownEntriesForCharacter(charKey, professions)
    local tracked, ready, recovering, unknown, unlearned = 0, 0, 0, 0, 0
    local nextRemaining
    for _, entry in ipairs(entries) do
        tracked = tracked + 1
        local state = ComputeCanonicalCooldownState(entry)
        if state.unknown then
            unknown = unknown + 1
        elseif state.unlearned then
            unlearned = unlearned + 1
        elseif state.ready then
            ready = ready + 1
        else
            recovering = recovering + 1
            local remaining = state.nextRemaining or state.remaining or 0
            if remaining > 0 and (not nextRemaining or remaining < nextRemaining) then
                nextRemaining = remaining
            end
        end
    end
    local summary = {
        entries = entries,
        tracked = tracked,
        ready = ready,
        recovering = recovering,
        unknown = unknown,
        unlearned = unlearned,
        nextRemaining = nextRemaining,
    }
    COOLDOWN_SUMMARY_CACHE[charKey] = {
        version = COOLDOWN_DISPLAY_CACHE_VERSION,
        key = cacheKey,
        expiresAt = cacheNow + COOLDOWN_DISPLAY_CACHE_TTL_SECONDS,
        summary = summary,
    }
    return summary
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

FormatCooldownDuration = function(seconds)
    local secs = SafeNumber(seconds, 0) or 0
    if EL and EL.FormatCountdown then return EL:FormatCountdown(secs) end
    return FormatCooldownColumnTimer(secs)
end

-- Canonical display state used by summaries, sorting, and tooltip formatting.
ComputeCanonicalCooldownState = function(entry)
    local state = {
        ready = false,
        unknown = true,
        unlearned = false,
        remaining = 0,
        nextRemaining = nil,
        fullRemaining = nil,
        currentCharges = 0,
        maxCharges = 0,
    }
    if type(entry) ~= "table" then return state end

    state.unlearned = entry.unlearned and true or false
    if state.unlearned then
        state.unknown = false
        return state
    end

    local now = Now()
    state.maxCharges = SafeNumber(entry.maxCharges, 0) or 0
    state.currentCharges = math.max(0, math.min(state.maxCharges, SafeNumber(entry.currentCharges, 0) or 0))
    state.readyTime = SafeNumber(entry.readyTime)
    state.remaining = SafeNumber(entry.remaining, 0) or 0

    if state.remaining <= 0 and state.readyTime and state.readyTime > now then
        state.remaining = math.max(0, state.readyTime - now)
    end

    if entry.unknown then
        local recoveredReadyTime = DeriveReadyTime(entry)
        if recoveredReadyTime and recoveredReadyTime > now then
            state.unknown = false
            state.ready = false
            state.readyTime = recoveredReadyTime
            state.remaining = math.max(0, recoveredReadyTime - now)
            state.nextRemaining = state.remaining
        elseif state.remaining > 0 then
            state.unknown = false
            state.ready = false
            state.nextRemaining = state.remaining
        end
        return state
    end

    state.unknown = false
    state.ready = entry.ready == true

    if state.maxCharges > 0 then
        local recipeReadyTime = SafeNumber(entry.recipeReadyTime)
        if recipeReadyTime and recipeReadyTime > now and not entry.sharedCooldownKey then
            state.currentCharges = 0
        end
        state.currentCharges = SharedCooldownBucket.ClampChargesByRecoveringTimers(state.currentCharges, state.maxCharges, entry, now)
        -- Charged cooldowns are actionable when at least one charge is available.
        -- Future recharge timers reduce the trusted available-charge count first,
        -- so 1/2 remains Ready while 0/2 cannot be shown as Ready from stale API data.
        state.ready = (entry.ready == true) and state.currentCharges > 0
        local nextChargeReadyTime = GetNextChargeReadyTime(entry)
        if (not nextChargeReadyTime or nextChargeReadyTime <= now) then
            nextChargeReadyTime = GetRecipeFallbackReadyTime(entry)
        end
        if nextChargeReadyTime and nextChargeReadyTime > now then
            state.nextRemaining = math.max(0, nextChargeReadyTime - now)
            if state.remaining <= 0 then state.remaining = state.nextRemaining end
        elseif state.remaining > 0 then
            state.nextRemaining = state.remaining
        elseif state.readyTime and state.readyTime > now then
            state.nextRemaining = math.max(0, state.readyTime - now)
            state.remaining = state.nextRemaining
        end

        local fullRechargeReadyTime = GetFullRechargeReadyTime(entry)
        if fullRechargeReadyTime and fullRechargeReadyTime > now then
            local fullRemaining = math.max(0, fullRechargeReadyTime - now)
            -- Always expose full recharge in tooltips, even when it is identical
            -- or nearly identical to the next recharge. Shared charged cooldowns can
            -- legitimately have next and full resolve at the same time, and hiding
            -- full makes the charged state look incomplete.
            state.fullRemaining = fullRemaining
        end
    elseif state.remaining > 0 then
        state.nextRemaining = state.remaining
    end

    return state
end

FormatCooldownTooltipState = function(entry, state)
    state = state or ComputeCanonicalCooldownState(entry)
    if state.unknown then return EL:T("Unknown") end
    if state.unlearned then return EL:T("Unlearned") end

    if state.maxCharges and state.maxCharges > 0 then
        local chargesText = tostring(state.currentCharges or 0) .. "/" .. tostring(state.maxCharges) .. " " .. EL:T("charges")
        if state.ready and (state.currentCharges or 0) > 0 then
            local text = chargesText .. " " .. EL:T("ready")
            if state.nextRemaining and state.nextRemaining > 0 then text = text .. " | " .. EL:T("next") .. " " .. FormatCooldownDuration(state.nextRemaining) end
            if state.fullRemaining and state.fullRemaining > 0 then text = text .. " | " .. EL:T("full") .. " " .. FormatCooldownDuration(state.fullRemaining) end
            return text
        end
        local displayRemaining = (state.nextRemaining and state.nextRemaining > 0 and state.nextRemaining)
            or (state.remaining and state.remaining > 0 and state.remaining)
        if displayRemaining and displayRemaining > 0 then
            local text = chargesText .. " | " .. EL:T("next") .. " " .. FormatCooldownDuration(displayRemaining)
            if state.fullRemaining and state.fullRemaining > 0 then text = text .. " | " .. EL:T("full") .. " " .. FormatCooldownDuration(state.fullRemaining) end
            return text
        end
        if state.fullRemaining and state.fullRemaining > 0 then
            return chargesText .. " | " .. EL:T("full") .. " " .. FormatCooldownDuration(state.fullRemaining)
        end
        if state.ready then return EL:T("READY") end
        return EL:T("Unknown")
    end

    if state.ready then return EL:T("READY") end
    if state.nextRemaining and state.nextRemaining > 0 then return FormatCooldownDuration(state.nextRemaining) end
    return EL:T("Unknown")
end

function EL:GetProfessionCooldownDisplayText(charKey, professions)
    -- Priority: actionable > active timer > unknown > not tracked.
    -- The compact CD column uses an inline gold checkmark texture for actionable cooldowns
    -- instead of raw ready counts. This avoids missing-glyph font boxes and keeps the column stable while avoiding
    -- implying that shared charged cooldown buckets are separate independent crafts.
    local summary = self:GetProfessionCooldownSummary(charKey, professions)
    if summary.tracked <= 0 then return "-", summary end
    if summary.ready > 0 then return "", summary end
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

function EL:GetNextProfessionCooldownSummary(now)
    now = SafeNumber(now, Now()) or Now()
    local bestReady, bestRecovering
    local rows = self.GetCharacterRows and self:GetCharacterRows() or nil
    if type(rows) ~= "table" then
        rows = {}
        for charKey, char in pairs(self.db and self.db.characters or {}) do
            rows[#rows + 1] = { key = charKey, char = char, displayName = self.GetCharacterDisplayName and self:GetCharacterDisplayName(char, charKey) or charKey }
        end
    end
    for _, row in ipairs(rows) do
        local charKey = row and row.key
        if charKey and not self:IsCharacterHidden(charKey) then
            local profs = self:GetProfessionEntriesForCharacter(charKey)
            local summary = self:GetProfessionCooldownSummary(charKey, profs)
            if summary and summary.tracked and summary.tracked > 0 then
                local displayName = row.displayName or (self.GetCharacterDisplayName and self:GetCharacterDisplayName(row.char, charKey)) or charKey
                if summary.ready and summary.ready > 0 then
                    if not bestReady or summary.ready > bestReady.readyCount then
                        bestReady = {
                            ready = true,
                            readyCount = summary.ready,
                            characterKey = charKey,
                            characterName = displayName,
                            remaining = 0,
                        }
                    end
                elseif summary.nextRemaining and summary.nextRemaining > 0 then
                    if not bestRecovering or summary.nextRemaining < bestRecovering.remaining then
                        bestRecovering = {
                            ready = false,
                            characterKey = charKey,
                            characterName = displayName,
                            remaining = summary.nextRemaining,
                        }
                    end
                end
            end
        end
    end
    return bestReady or bestRecovering
end

function EL:GetTrackedCooldownProfessionList()
    local seen, names = {}, {}
    for _, def in ipairs(self.PROFESSION_COOLDOWN_DEFS or {}) do
        if def and ShouldDisplayCooldownDefinition(def) then
            local name = def.professionName or def.category or def.professionID
            if name and not seen[name] then
                seen[name] = true
                names[#names + 1] = tostring(name)
            end
        end
    end
    table.sort(names)
    if #names == 0 then return nil end
    return table.concat(names, ", ")
end

function EL:ShowAllProfessionCooldowns()
    local display = self.db and self.db.settings and self.db.settings.display
    if not display then return false end
    display.hiddenCooldowns = {}
    self._hasCooldownColumnData = nil
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
    if self.RequestUpdate then
        self:RequestUpdate(true)
    else
        if self.RefreshPanel then self:RefreshPanel() end
        if self.UpdateButton then self:UpdateButton() end
    end
    if self.RefreshMinimapButton then self:RefreshMinimapButton() end
    if self.Print then self:Print(self:T("All supported cooldown crafts are now shown.")) end
    return true
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


local function ThemeTooltipRGB(kind, fallbackR, fallbackG, fallbackB)
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

function EL:AddProfessionCooldownTooltipLines(tooltip, charKey, professions)
    if not tooltip or not charKey then return end
    local accentR, accentG, accentB = 0.46, 0.68, 0.96
    local mutedR, mutedG, mutedB = ThemeTooltipRGB("muted", 0.72, 0.72, 0.72)
    local valueR, valueG, valueB = ThemeTooltipRGB("value", 0.90, 0.91, 0.93)
    local categoryR, categoryG, categoryB = accentR, accentG, accentB
    local entries = self:GetProfessionCooldownEntriesForCharacter(charKey, professions)
    tooltip:AddLine(" ")
    tooltip:AddLine(self:T("Profession Cooldowns"), accentR, accentG, accentB)
    if #entries == 0 then
        tooltip:AddLine(self:T("No supported profession cooldowns tracked."), mutedR, mutedG, mutedB)
        return
    end

    local currentCategory
    local sharedPools = {}
    local sharedOrder = {}
    local normalEntries = {}
    for _, entry in ipairs(entries) do
        if entry.sharedCooldownKey then
            local key = tostring(entry.category or self:T("Profession")) .. ":" .. tostring(entry.sharedCooldownKey)
            local pool = sharedPools[key]
            if not pool then
                pool = {
                    category = entry.category or self:T("Profession"),
                    key = entry.sharedCooldownKey,
                    label = entry.sharedCooldownLabel or entry.label or entry.shortLabel or self:T("Shared cooldown"),
                    entries = {},
                    names = {},
                }
                sharedPools[key] = pool
                sharedOrder[#sharedOrder + 1] = key
            end
            pool.entries[#pool.entries + 1] = entry
            pool.names[#pool.names + 1] = tostring(entry.shortLabel or entry.label or self:T("Cooldown"))
        else
            normalEntries[#normalEntries + 1] = entry
        end
    end

    local function addCategory(category)
        category = category or self:T("Profession")
        if category ~= currentCategory then
            tooltip:AddLine(category, categoryR, categoryG, categoryB)
            currentCategory = category
        end
    end

    local function addCooldownLine(entry, labelOverride, stateOverride)
        local state = stateOverride or ComputeCanonicalCooldownState(entry)
        local label = "   " .. tostring(labelOverride or entry.label or entry.shortLabel or self:T("Cooldown"))
        local right = FormatCooldownTooltipState(entry, state)
        if state.unknown then
            tooltip:AddDoubleLine(label, right, mutedR, mutedG, mutedB, valueR, valueG, valueB)
            tooltip:AddLine("      " .. EL:T("Open profession to refresh."), mutedR, mutedG, mutedB)
        elseif state.unlearned then
            tooltip:AddDoubleLine(label, right, mutedR, mutedG, mutedB, valueR, valueG, valueB)
        else
            tooltip:AddDoubleLine(label, right, mutedR, mutedG, mutedB, state.ready and 0.35 or 1.00, state.ready and 1.00 or 0.82, state.ready and 0.45 or 0.32)
        end
    end

    local function addSharedPool(pool)
        if not pool or #pool.entries == 0 then return end
        addCategory(pool.category)
        local representative = pool.entries[1]
        local state = ComputeCanonicalCooldownState(representative)
        local right = FormatCooldownTooltipState(representative, state)
        tooltip:AddDoubleLine("   " .. tostring(pool.label or self:T("Shared cooldown")), right, mutedR, mutedG, mutedB, state.ready and 0.35 or 1.00, state.ready and 1.00 or 0.82, state.ready and 0.45 or 0.32)
        if #pool.names > 0 then
            tooltip:AddLine("      " .. self:T("Shared pool") .. ": " .. table.concat(pool.names, ", "), mutedR, mutedG, mutedB)
        end
    end

    local sharedIndex = 1
    for _, entry in ipairs(normalEntries) do
        local category = entry.category or self:T("Profession")
        while sharedIndex <= #sharedOrder and sharedPools[sharedOrder[sharedIndex]].category == category do
            addSharedPool(sharedPools[sharedOrder[sharedIndex]])
            sharedIndex = sharedIndex + 1
        end
        addCategory(category)
        addCooldownLine(entry)
    end
    while sharedIndex <= #sharedOrder do
        addSharedPool(sharedPools[sharedOrder[sharedIndex]])
        sharedIndex = sharedIndex + 1
    end

    local store = EnsureProfessionCooldownStore()
    local stored = store and store[charKey]
    local age = type(stored) == "table" and FormatCooldownScanAge(stored._lastUpdated) or nil
    if age then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine(self:T("Last scanned"), age, accentR, accentG, accentB, mutedR, mutedG, mutedB)
    end
end

function module:OnLoad()
    ClearRecipeMatchCache()
    ArmLoginCooldownGuard()
    if EL.ValidateProfessionCooldownDefinitions then EL:ValidateProfessionCooldownDefinitions() end
    if EL.EnsureProfessionCooldownStore then EL:EnsureProfessionCooldownStore() end
    if EL.PruneProfessionCooldownStore then EL:PruneProfessionCooldownStore() end
    if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
    QueueCooldownRefresh(LOGIN_READY_OVERWRITE_GUARD_SECONDS + 0.05, "_cooldownLoginInitialRefreshPending")
end

function module:Refresh()
    if EL.RefreshCurrentProfessionCooldowns then EL:RefreshCurrentProfessionCooldowns() end
end

function module:OnEvent(event, ...)
    local eventProfile = ProfileStart("Cooldowns:OnEvent:" .. tostring(event or "unknown"))
    if event == "PLAYER_ENTERING_WORLD" then
        ArmLoginCooldownGuard()
        QueueCooldownRefresh(LOGIN_READY_OVERWRITE_GUARD_SECONDS + 0.05, "_cooldownLoginSettledRefreshPending")
    elseif event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        local craftedItemID = ExtractCraftedItemIDFromEvent(...)
        local craftedDef = craftedItemID and COOLDOWN_DEFS_BY_ITEM[craftedItemID]
        if craftedDef then
            MarkCooldownCrafted(craftedDef)
            if EL.RequestUpdate then EL:RequestUpdate() end
        end
        -- Recipe cooldown availability can lag behind the craft-result event while
        -- the Blizzard profession UI remains open, especially for shared charged cooldowns.
        -- Use one settled refresh to avoid stacking cooldown scans during batch crafting.
        QueueCooldownRefresh(1.2, "_cooldownCraftSettledRefreshPending")
    elseif event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        -- This event can fire repeatedly while crafting. Keep one settled refresh pending.
        ClearRecipeMatchCache()
        QueueCooldownRefresh(1.0, "_cooldownTradeSkillSettledRefreshPending")
    elseif event == "TRADE_SKILL_SHOW" or event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" then
        ClearRecipeMatchCache()
        QueueCooldownRefresh(0.75)
    end
    ProfileStop("Cooldowns:OnEvent:" .. tostring(event or "unknown"), eventProfile)
end

EL:RegisterModule("ProfessionCooldowns", module)
