local addonName, EL = ...
_G.EmberLedger = EL

local GetTime = _G.GetTime
local time = _G.time

EL.name = addonName or "EmberLedger"
EL.version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or "2.2.1"
EL.frame = CreateFrame("Frame")
EL.L = EL.L or {}

function EL:T(key, ...)
    local text = (self.L and self.L[key]) or key
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, tostring(text), ...)
        if ok then return formatted end
    end
    return tostring(text)
end

-- Load order note:
-- Core.lua defines shared state, database normalization, safe numeric conversion,
-- localization helpers, sorting, and slash-command wiring. Localization.lua
-- populates the English fallback table. Resource modules register next. UI.lua adds
-- frame/layout helpers after the shared Core helpers are available, and
-- ActionBar.lua loads last so secure button setup can use the completed UI layer.
EL.modules = {}
EL.moduleOrder = {}
-- Concentration threshold overrides only apply to crafting professions that use
-- concentration. Gathering professions such as Herbalism, Mining, and Skinning are
-- intentionally excluded because they do not have concentration values.
EL.PROFESSION_THRESHOLD_PROFESSIONS = {
    { id = 171, key = "alchemy", label = "Alchemy" },
    { id = 164, key = "blacksmithing", label = "Blacksmithing" },
    { id = 333, key = "enchanting", label = "Enchanting" },
    { id = 202, key = "engineering", label = "Engineering" },
    { id = 773, key = "inscription", label = "Inscription" },
    { id = 755, key = "jewelcrafting", label = "Jewelcrafting" },
    { id = 165, key = "leatherworking", label = "Leatherworking" },
    { id = 197, key = "tailoring", label = "Tailoring" },
}

EL.DB_KEY_SEP = "\031"
EL.CONCENTRATION_MAX_DEFAULT = 1000
EL.CONCENTRATION_RATE_PER_HOUR = 10
EL.CONCENTRATION_THRESHOLD_DEFAULT = 900
EL.MOXIE_THRESHOLD_DEFAULT = 600
EL.IMBUED_MULCH_ITEM_ID = 238388
EL.TRADEGOODS_CLASS = Enum.ItemClass and Enum.ItemClass.Tradegoods or 7
EL.CONSUMABLE_CLASS = Enum.ItemClass and Enum.ItemClass.Consumable or 0
EL.SESSION_DEDUPE_SECONDS = 5
EL.HERBALISM_ID = 182

EL.EXPANSION_IDS = EL.EXPANSION_IDS or {
    CLASSIC = 0,
    BURNING_CRUSADE = 1,
    WRATH = 2,
    CATACLYSM = 3,
    PANDARIA = 4,
    WARLORDS = 5,
    LEGION = 6,
    BATTLE_FOR_AZEROTH = 7,
    SHADOWLANDS = 8,
    DRAGONFLIGHT = 9,
    WAR_WITHIN = 10,
    MIDNIGHT = 11,
}
EL.CURRENT_EXPANSION_ID = EL.CURRENT_EXPANSION_ID or EL.EXPANSION_IDS.MIDNIGHT
EL.PREVIOUS_EXPANSION_ID = EL.PREVIOUS_EXPANSION_ID or EL.EXPANSION_IDS.WAR_WITHIN
EL.EXPANSION_NAMES = EL.EXPANSION_NAMES or {
    [EL.EXPANSION_IDS.CLASSIC] = "Classic",
    [EL.EXPANSION_IDS.BURNING_CRUSADE] = "Outland",
    [EL.EXPANSION_IDS.WRATH] = "Northrend",
    [EL.EXPANSION_IDS.CATACLYSM] = "Cataclysm",
    [EL.EXPANSION_IDS.PANDARIA] = "Pandaria",
    [EL.EXPANSION_IDS.WARLORDS] = "Warlords",
    [EL.EXPANSION_IDS.LEGION] = "Legion",
    [EL.EXPANSION_IDS.BATTLE_FOR_AZEROTH] = "Battle for Azeroth",
    [EL.EXPANSION_IDS.SHADOWLANDS] = "Shadowlands",
    [EL.EXPANSION_IDS.DRAGONFLIGHT] = "Dragonflight",
    [EL.EXPANSION_IDS.WAR_WITHIN] = "The War Within",
    [EL.EXPANSION_IDS.MIDNIGHT] = "Midnight",
}
EL.PROFESSION_EXPANSION_PREFIXES = EL.PROFESSION_EXPANSION_PREFIXES or {
    "Battle for Azeroth", "Warlords", "Dragon Isles", "Dragonflight",
    "Shadowlands", "The War Within", "Khaz Algar", "Midnight",
    "Cataclysm", "Northrend", "Pandaria", "Outland", "Classic", "Legion",
}

function EL:GetCurrentExpansionID()
    return self.CURRENT_EXPANSION_ID or (self.EXPANSION_IDS and self.EXPANSION_IDS.MIDNIGHT) or 11
end

-- Forward-looking helper for expansion-aware display systems. Prefer the explicit
-- PREVIOUS_EXPANSION_ID value so future non-sequential expansion IDs only need
-- one constant update.
function EL:GetPreviousExpansionID()
    local previous = self.PREVIOUS_EXPANSION_ID or (self.EXPANSION_IDS and self.EXPANSION_IDS.WAR_WITHIN) or 10
    return self:SafeNumber(previous, 10, "expansion.previous") or 10
end

-- Forward-looking helper for user-facing/debug expansion labels.
function EL:GetExpansionName(expansionID)
    local id = self:SafeNumber(expansionID, nil, "expansion.name")
    return (id and self.EXPANSION_NAMES and self.EXPANSION_NAMES[id]) or (id and ("Expansion " .. tostring(id))) or "Unknown Expansion"
end


EL.LOGO_TEXTURE = "Interface\\AddOns\\EmberLedger\\Media\\EmberLedgerLogo"

EL.THEME_COLORS = {
    -- EmberLedger v2.0 standard: near-black panels with neutral silver/grey accents.
    BORDER_R = 0.42, BORDER_G = 0.42, BORDER_B = 0.44,
    BG_R = 0.000, BG_G = 0.000, BG_B = 0.000,
    ACCENT_R = 0.68, ACCENT_G = 0.68, ACCENT_B = 0.70,
    GLOW_R = 0.26, GLOW_G = 0.26, GLOW_B = 0.28,
    ACTION_BUTTON_BG_R = 0.010, ACTION_BUTTON_BG_G = 0.010, ACTION_BUTTON_BG_B = 0.012,
    ACTION_BUTTON_TEXT_R = 0.88, ACTION_BUTTON_TEXT_G = 0.89, ACTION_BUTTON_TEXT_B = 0.91,
    TEXT_R = 0.90, TEXT_G = 0.91, TEXT_B = 0.93,
    MUTED_TEXT_R = 0.80, MUTED_TEXT_G = 0.82, MUTED_TEXT_B = 0.85,
    VALUE_TEXT_R = 0.93, VALUE_TEXT_G = 0.94, VALUE_TEXT_B = 0.96,
}

function EL:ApplyVisualTheme()
    self.THEME_COLORS = self.THEME_COLORS or {}
    return "dark"
end

EL.UPDATE_DEBOUNCE_SECONDS = 0.05
EL.UPDATE_COALESCE_SECONDS = 0.12
EL.ACTION_BAR_DEBOUNCE_SECONDS = 0.05

EL.MOXIE_CURRENCY_BY_PROFESSION_ID = {
    [171] = 3256, -- Alchemy
    [164] = 3257, -- Blacksmithing
    [333] = 3258, -- Enchanting
    [202] = 3259, -- Engineering
    [182] = 3260, -- Herbalism
    [773] = 3261, -- Inscription
    [755] = 3262, -- Jewelcrafting
    [165] = 3263, -- Leatherworking
    [186] = 3264, -- Mining
    [393] = 3265, -- Skinning
    [197] = 3266, -- Tailoring
}

EL.UI_CONSTANTS = {
    PANEL_MIN_W = 352,
    TRACKING_DYNAMIC_MIN_W = 230,
    TRACKING_COMPACT_MIN_W = 210,
    PANEL_MIN_H = 120,
    SESSION_MIN_W = 320,
    SESSION_EXPANDED_H = 182,
    SESSION_COLLAPSED_H = 36,
    SESSION_WINDOW_PAD = 6,
    ACTION_BAR_H = 36,
    ACTION_BAR_FLOATING_W = 244,
    ACTION_BAR_FLOATING_H = 40,
    SESSION_VISIBLE_ITEM_ROWS = 4,
    SESSION_ITEM_ROW_H = 18,
    SESSION_HISTORY_ROWS = 8,
    SESSION_STATS_CARD_W = 205,
    SESSION_STATS_CARD_H = 54,
    SESSION_STATS_CARD_LEFT = 16,
    SESSION_STATS_CARD_TOP = -70,
    SESSION_STATS_CARD_STEP_X = 219,
    SESSION_STATS_CARD_STEP_Y = 70,
    SESSION_BAG_CARD_W = 205,
    SESSION_BAG_CARD_H = 44,
    SESSION_BAG_CARD_LEFT = 16,
    SESSION_BAG_CARD_TOP = -58,
    SESSION_BAG_CARD_STEP_X = 219,
    SESSION_TOTAL_CARD_W = 205,
    SESSION_TOTAL_CARD_H = 36,
    SESSION_TOTAL_CARD_LEFT = 14,
    SESSION_TOTAL_CARD_TOP = -34,
    SESSION_TOTAL_CARD_STEP_X = 219,
    SESSION_TOTAL_CARD_STEP_Y = 46,
    SESSION_WINDOW_MIN_H = 150,
    SESSION_WINDOW_DEFAULT_H = 180,
    SESSION_METRIC_CONTENT_PAD = 20,
    SESSION_METRIC_GAP = 8,
    SESSION_METRIC_MIN_W = 62,
    SESSION_METRIC_H = 38,
    SESSION_CLOSE_SIZE = 18,
    SESSION_CLOSE_RIGHT_PAD = -5,
    SESSION_TITLE_LEFT_PAD = 10,
    SESSION_TITLE_RIGHT_PAD = -8,
    PANEL_DEFAULT_VISIBLE_ROWS = 12,
    TRACKING_ROW_H = 23,
    TRACKING_COMPACT_ROW_H = 18,
    TRACKING_ROW_GAP = 0,
    TRACKING_EMPTY_BODY_H = 42,
    PANEL_EXPANDED_MIN_H = 300,
    PANEL_MAX_W = 900,
    PANEL_MAX_H = 1600,
    PANEL_MIN_SCALE = 0.6,
    PANEL_MAX_SCALE = 1.4,
    OPTIONS_COLUMN_DESC_LEFT = 12,
    OPTIONS_COLUMN_DESC_TOP = -36,
    OPTIONS_COLUMN_DESC_RIGHT = -12,
    OPTIONS_NEXT_COLUMN_Y = -926,
    OPTIONS_NEXT_COLUMN_H = 116,
    OPTIONS_NEXT_COLUMN_CHECK_Y = -80,
    OPTIONS_COOLDOWN_COLUMN_Y = -1078,
    OPTIONS_COOLDOWN_COLUMN_H = 196,
    OPTIONS_COOLDOWN_COLUMN_CHECK_Y = -62,
}

EL.DB_VERSION = 11613


EL.PROFESSION_ICON_TEXTURES = {
    [164] = "Interface\\Icons\\Trade_BlackSmithing",
    [165] = "Interface\\Icons\\INV_Misc_ArmorKit_17",
    [171] = "Interface\\Icons\\Trade_Alchemy",
    [182] = "Interface\\Icons\\Trade_Herbalism",
    [186] = "Interface\\Icons\\Trade_Mining",
    [197] = "Interface\\Icons\\Trade_Tailoring",
    [202] = "Interface\\Icons\\Trade_Engineering",
    [333] = "Interface\\Icons\\Trade_Engraving",
    [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    [755] = "Interface\\Icons\\INV_Misc_Gem_01",
    [773] = "Interface\\Icons\\INV_Inscription_Tradeskill01",
    [794] = "Interface\\Icons\\INV_Misc_Rune_06",
    [356] = "Interface\\Icons\\Trade_Fishing",
    [185] = "Interface\\Icons\\INV_Misc_Food_15",
}

EL.PROFESSION_ABBREVIATIONS = {
    [164] = "BS",
    [165] = "LW",
    [171] = "ALCH",
    [182] = "HERB",
    [186] = "MIN",
    [197] = "TAIL",
    [202] = "ENG",
    [333] = "ENCH",
    [393] = "SKIN",
    [755] = "JC",
    [773] = "INS",
    [794] = "ARCH",
    [356] = "FISH",
    [185] = "COOK",
}

local defaults = {
    version = EL.DB_VERSION,
    actionBarPlacementVersion = 1202,
    characters = {},
    resources = {
        concentration = {},
        mulch = {},
        professions = {},
        moxie = {},
        professionCooldowns = {},
    },
    stats = {
        lifetime = {
            totalSilver = 0,
            itemValueSilver = 0,
            rawGoldGainedSilver = 0,
            goldSpentSilver = 0,
            duration = 0,
            sessions = 0,
            items = 0,
            backfilledFromHistory = false,
        },
        history = {
            daily = {},
            weekly = {},
            backfilledFromHistory = false,
        },
    },
    settings = {
        sort = {
            key = "character",
            ascending = true,
        },
        button = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 120,
            locked = false,
        },
        panel = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 540,
            height = 360,
            scale = 1,
            charactersCollapsed = false,
            charactersShown = true,
            actionBarFloating = false,
            actionBarLocked = false,
            actionBarPosition = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -160 },
            actionButtons = {
                mulch = true,
                seed = true,
                glowingSeed = true,
                wildSeed = true,
                primalSeed = true,
                greenThumb = true,
                overloadHerb = true,
                overloadOre = true,
                parcel = true,
                bank = true,
            },
            windowOpen = false,
        },
        session = {
            shown = true,
            windowOpen = false,
            point = "CENTER",
            relativePoint = "CENTER",
            x = 260,
            y = 0,
            width = 352,
            height = 180,
            scale = 1,
            pricingSource = "auto",
            topItems = 50,
            trackHerbs = true,
            trackOre = true,
            trackCloth = true,
            trackLeather = true,
            trackEnchanting = true,
            trackFish = true,
            trackOtherMaterials = true,
            countTrustedMailRewards = true,
            countCraftedItems = false,
            trackRawGoldGains = true,
            trackGoldSpent = false,
            sessionHistoryEnabled = true,
            historyRetentionDays = 30,
            historyDisplayDays = 30,
            historyDisplayMode = "30",
            historyMaxEntries = 500,
        },
        alerts = {
            concentrationThreshold = EL.CONCENTRATION_THRESHOLD_DEFAULT,
            moxieThreshold = EL.MOXIE_THRESHOLD_DEFAULT,
            professionThresholds = {},
        },
        display = {
            panelOpacity = 0.55,
            launcherOpacity = 0.50,
            sessionOpacity = 0.55,
            showLauncherConc = true,
            showLauncherMulch = true,
            showLauncherCooldown = false,
            showLauncherSession = true,
            showLauncherSessionTotal = true,
            showLauncherSessionTime = true,
            showProfessionColumn = true,
            showConcentrationColumn = true,
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
            attentionOnly = false,
            compactMode = false,
            showCurrentCharacterFirst = false,
            showPinnedFirst = true,
            highlightCurrentCharacter = true,
        },
        performance = {
            sessionTracking = true,
            actionBar = true,
            profile = false,
            profileSlowMs = 1.0,
        },
        minimap = {
            hide = false,
            minimapPos = 220,
        },
        hiddenCharacters = {},
        favoriteCharacters = {},
        sessionHistory = {},
        options = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        },
        lockWindows = false,
        debug = false,
        onboardingSeen = false,
    },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = DeepCopy(v)
    end
    return dst
end

function EL:GetDefaultSettingsSnapshot()
    return DeepCopy(defaults.settings)
end

local function RemoveLegacySavedVariableFields(db)
    if type(db) ~= "table" then return end
    if type(db.settings) == "table" then
        db.settings.sortMode = nil
        if type(db.settings.button) == "table" then
            db.settings.button.width = nil
            db.settings.button.height = nil
        end
        if type(db.settings.panel) == "table" then
            db.settings.panel.detached = nil
            db.settings.panel.sessionCollapsed = nil
        end
        if type(db.settings.session) == "table" then
            db.settings.session.collapsed = nil
        end
        if type(db.settings.display) == "table" then
            db.settings.display.visualTheme = nil
            db.settings.display.themePreset = nil
        end
    end

    -- totalItems is no longer displayed and was a frequent source of legacy noise.
    -- Keep item/value data, but allow the aggregate count to be rebuilt later if needed.
    db.sessionHistory = type(db.sessionHistory) == "table" and db.sessionHistory or {}

    if type(db.session) == "table" then
        db.session.totalItems = nil
        db.session.legacyProjected = nil
        db.session.projected = nil
        db.session.wallet = nil
        db.session.goal = nil
    end
end

local function CleanupSavedCharacterFlags(db)
    if type(db) ~= "table" or type(db.settings) ~= "table" then return end
    local characters = type(db.characters) == "table" and db.characters or {}
    local hidden = db.settings.hiddenCharacters
    if type(hidden) == "table" then
        for charKey in pairs(hidden) do
            if characters[charKey] == nil then
                hidden[charKey] = nil
            end
        end
    end

    local favorites = db.settings.favoriteCharacters
    if type(favorites) == "table" then
        for charKey in pairs(favorites) do
            if characters[charKey] == nil then
                favorites[charKey] = nil
            end
        end
    end
end

local function IsEmptyTableValue(value)
    return value == nil or value == "" or (type(value) == "table" and next(value) == nil)
end

local function MergeTableMissingValues(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then return end
    for key, value in pairs(source) do
        if IsEmptyTableValue(target[key]) and value ~= nil then
            target[key] = value
        end
    end
end

local function CanonicalizeLegacySpacedKey(key)
    local name, realm = tostring(key or ""):match("^([^%-]+)%-(.+)$")
    if not name or not realm or not realm:find("%s") then return nil end
    local canonicalRealm = realm:gsub("%s+", "")
    if canonicalRealm == "" then canonicalRealm = "UnknownRealm" end
    local canonicalKey = name .. "-" .. canonicalRealm
    if canonicalKey == key then return nil end
    return canonicalKey
end

local function MoveOrMergeKeyedTable(tbl, oldKey, newKey)
    if type(tbl) ~= "table" or not oldKey or not newKey or oldKey == newKey then return false end
    local oldValue = tbl[oldKey]
    if oldValue == nil then return false end
    if tbl[newKey] == nil then
        tbl[newKey] = oldValue
    elseif type(tbl[newKey]) == "table" and type(oldValue) == "table" then
        MergeTableMissingValues(tbl[newKey], oldValue)
    end
    tbl[oldKey] = nil
    return true
end

local function MoveLegacyConcentrationEntries(resources, oldKey, newKey)
    if type(resources) ~= "table" or type(resources.concentration) ~= "table" then return false end
    local moved = false
    local sep = EL and EL.DB_KEY_SEP or "\031"
    local concentration = resources.concentration
    local pending = {}
    for resourceKey, data in pairs(concentration) do
        if type(data) == "table" and data.charKey == oldKey then
            local resourceKeyText = tostring(resourceKey or "")
            local prefix = oldKey .. sep
            local suffix
            if resourceKeyText:sub(1, #prefix) == prefix then
                suffix = resourceKeyText:sub(#prefix + 1)
            end
            suffix = suffix or tostring(data.professionID or data.skillLineID or data.skillLine or "default")
            pending[#pending + 1] = { oldResourceKey = resourceKey, newResourceKey = newKey .. sep .. suffix, data = data }
        end
    end
    for _, item in ipairs(pending) do
        item.data.charKey = newKey
        if concentration[item.newResourceKey] == nil then
            concentration[item.newResourceKey] = item.data
        elseif type(concentration[item.newResourceKey]) == "table" then
            MergeTableMissingValues(concentration[item.newResourceKey], item.data)
            concentration[item.newResourceKey].charKey = newKey
        end
        concentration[item.oldResourceKey] = nil
        moved = true
    end
    return moved
end

local function MigrateSpacedCharacterKeys(db)
    if type(db) ~= "table" or type(db.characters) ~= "table" then return false end
    local migrations = {}
    for key in pairs(db.characters) do
        local canonicalKey = CanonicalizeLegacySpacedKey(key)
        if canonicalKey then
            migrations[#migrations + 1] = { old = key, new = canonicalKey }
        end
    end
    if #migrations == 0 then return false end

    local changed = false
    db.resources = type(db.resources) == "table" and db.resources or {}
    db.settings = type(db.settings) == "table" and db.settings or {}

    for _, migration in ipairs(migrations) do
        local oldKey, newKey = migration.old, migration.new
        local oldChar = db.characters[oldKey]
        if oldChar ~= nil then
            if db.characters[newKey] == nil then
                db.characters[newKey] = oldChar
            elseif type(db.characters[newKey]) == "table" and type(oldChar) == "table" then
                MergeTableMissingValues(db.characters[newKey], oldChar)
                local oldSeen = tonumber(oldChar.lastSeen) or 0
                local newSeen = tonumber(db.characters[newKey].lastSeen) or 0
                if oldSeen > newSeen then db.characters[newKey].lastSeen = oldChar.lastSeen end
            end
            if type(db.characters[newKey]) == "table" then
                db.characters[newKey].key = newKey
            end
            db.characters[oldKey] = nil
            changed = true
        end

        for _, tblName in ipairs({ "mulch", "moxie", "professions", "professionCooldowns" }) do
            if MoveOrMergeKeyedTable(db.resources[tblName], oldKey, newKey) then changed = true end
        end
        if MoveLegacyConcentrationEntries(db.resources, oldKey, newKey) then changed = true end

        for _, flagsName in ipairs({ "hiddenCharacters", "favoriteCharacters" }) do
            if MoveOrMergeKeyedTable(db.settings[flagsName], oldKey, newKey) then changed = true end
        end
    end
    return changed
end

function EL:RunDatabaseCleanup(previousVersion)
    local current = tonumber(previousVersion) or tonumber(self.db and self.db.version) or 0
    if current < self.DB_VERSION then
        RemoveLegacySavedVariableFields(self.db)
        MigrateSpacedCharacterKeys(self.db)
        CleanupSavedCharacterFlags(self.db)
        if self.InvalidateCharacterRows then self:InvalidateCharacterRows() end
        self._concentrationByCharKey = nil
        self._professionLookupCache = nil
        self._hasCooldownColumnData = nil
        self.db.version = self.DB_VERSION
    end
end

local function ClampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if value == nil then value = fallback end
    if minValue ~= nil and value < minValue then value = minValue end
    if maxValue ~= nil and value > maxValue then value = maxValue end
    return value
end

local CORE_SORT_CONTEXT = {}

local function SortProfessionEntriesBySlot(a, b)
    local as = tonumber(a and a.slot) or 99
    local bs = tonumber(b and b.slot) or 99
    if as ~= bs then return as < bs end
    return ((a and a.professionName) or "") < ((b and b.professionName) or "")
end

local function SortWrappedCharacterRows(a, b)
    if a == b then return false end
    if not a then return false end
    if not b then return true end

    if CORE_SORT_CONTEXT.showCurrentCharacterFirst and a.current ~= b.current then
        return a.current == true
    end

    if CORE_SORT_CONTEXT.showPinnedFirst and a.pinned ~= b.pinned then
        return a.pinned == true
    end

    local aNA = a.value == nil
    local bNA = b.value == nil
    if aNA ~= bNA then return not aNA end

    if not aNA and not bNA then
        if a.valueType == b.valueType then
            if a.value ~= b.value then
                if CORE_SORT_CONTEXT.ascending then
                    return a.value < b.value
                else
                    return b.value < a.value
                end
            end
        elseif a.valueType ~= b.valueType then
            return (a.valueType or "") < (b.valueType or "")
        end
    end

    if a.name ~= b.name then return a.name < b.name end
    if a.key ~= b.key then return a.key < b.key end
    return (a.originalIndex or 0) < (b.originalIndex or 0)
end

local function SortConcentrationEntriesForCharacter(a, b)
    local aa = EL:GetProfessionAbbreviation(a)
    local bb = EL:GetProfessionAbbreviation(b)
    if aa == bb then return ((a and a.professionName) or "") < ((b and b.professionName) or "") end
    return aa < bb
end

local function SortConcentrationReadyEntries(a, b)
    local aq, bq = tonumber(a and a.quantity) or 0, tonumber(b and b.quantity) or 0
    if aq ~= bq then return aq > bq end
    local an, bn = ((a and a.displayName) or ""):lower(), ((b and b.displayName) or ""):lower()
    if an ~= bn then return an < bn end
    return ((a and a.abbrev) or "") < ((b and b.abbrev) or "")
end

local function SortMulchReadyEntries(a, b)
    return ((a and a.displayName) or ""):lower() < ((b and b.displayName) or ""):lower()
end

local function SortAttentionEntries(a, b)
    local ap = a and a.type == "mulch" and 1 or 2
    local bp = b and b.type == "mulch" and 1 or 2
    if ap ~= bp then return ap < bp end
    local an, bn = ((a and a.displayName) or ""):lower(), ((b and b.displayName) or ""):lower()
    if an ~= bn then return an < bn end
    return ((a and (a.abbrev or a.itemName)) or "") < ((b and (b.abbrev or b.itemName)) or "")
end

local function SortSessionItems(a, b)
    local av, bv = tonumber(a and a.silver) or 0, tonumber(b and b.silver) or 0
    if av ~= bv then return av > bv end
    local aq, bq = tonumber(a and a.qty) or 0, tonumber(b and b.qty) or 0
    if aq ~= bq then return aq > bq end
    return ((a and (a.name or a.itemID)) or "") < ((b and (b.name or b.itemID)) or "")
end

local function SortSessionHistoryNewestFirst(a, b)
    return (tonumber(a and a.timestamp) or 0) > (tonumber(b and b.timestamp) or 0)
end

local function SortCharacterRowsByName(a, b)
    local an = a and a.displayNameLower
    local bn = b and b.displayNameLower
    if not an then
        an = EL:GetCharacterDisplayName(a and a.char, a and a.key)
        an = tostring(an or ""):lower()
    end
    if not bn then
        bn = EL:GetCharacterDisplayName(b and b.char, b and b.key)
        bn = tostring(bn or ""):lower()
    end
    if an ~= bn then return an < bn end
    return tostring(a and a.key or "") < tostring(b and b.key or "")
end

local function FormatCompactDuration(seconds, showSecondsUnderHour)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds <= 0 then return "Ready" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %02dm", hours, mins)
    elseif mins > 0 then
        if showSecondsUnderHour then return string.format("%dm %02ds", mins, secs) end
        return string.format("%dm", mins)
    elseif showSecondsUnderHour then
        return string.format("%ds", secs)
    end
    return "<1m"
end

function EL:EnsureProfessionCooldownStore()
    if type(self.db) ~= "table" then return nil end
    self.db.resources = type(self.db.resources) == "table" and self.db.resources or {}
    self.db.resources.professionCooldowns = type(self.db.resources.professionCooldowns) == "table" and self.db.resources.professionCooldowns or {}
    return self.db.resources.professionCooldowns
end

local function NormalizeResourceTables(self)
    self.db.characters = type(self.db.characters) == "table" and self.db.characters or {}
    self.db.resources = type(self.db.resources) == "table" and self.db.resources or {}
    self.db.resources.concentration = type(self.db.resources.concentration) == "table" and self.db.resources.concentration or {}
    self.db.resources.mulch = type(self.db.resources.mulch) == "table" and self.db.resources.mulch or {}
    self.db.resources.professions = type(self.db.resources.professions) == "table" and self.db.resources.professions or {}
    if self.EnsureProfessionCooldownStore then self:EnsureProfessionCooldownStore() end
    self._hasCooldownColumnData = nil
    self._concentrationByCharKey = nil
    self.db.resources.moxie = type(self.db.resources.moxie) == "table" and self.db.resources.moxie or {}
end

local function NormalizeStatsTables(self)
    self.db.stats = type(self.db.stats) == "table" and self.db.stats or {}
    self.db.stats.lifetime = type(self.db.stats.lifetime) == "table" and self.db.stats.lifetime or {}
    local lifetime = self.db.stats.lifetime
    lifetime.totalSilver = tonumber(lifetime.totalSilver) or 0
    lifetime.itemValueSilver = tonumber(lifetime.itemValueSilver) or 0
    lifetime.rawGoldGainedSilver = tonumber(lifetime.rawGoldGainedSilver) or 0
    lifetime.goldSpentSilver = tonumber(lifetime.goldSpentSilver) or 0
    lifetime.duration = tonumber(lifetime.duration) or 0
    lifetime.sessions = tonumber(lifetime.sessions) or 0
    lifetime.items = tonumber(lifetime.items) or 0
    lifetime.backfilledFromHistory = lifetime.backfilledFromHistory == true
    lifetime._normalized = true

    self.db.stats.history = type(self.db.stats.history) == "table" and self.db.stats.history or {}
    self.db.stats.history.daily = type(self.db.stats.history.daily) == "table" and self.db.stats.history.daily or {}
    self.db.stats.history.weekly = type(self.db.stats.history.weekly) == "table" and self.db.stats.history.weekly or {}
    self.db.stats.history.backfilledFromHistory = self.db.stats.history.backfilledFromHistory == true
end

local function NormalizeSettingsTables(settings)
    settings.display = settings.display or {}
    settings.alerts = settings.alerts or {}
    settings.panel = settings.panel or {}
    settings.session = settings.session or {}
    settings.button = settings.button or {}
    settings.minimap = type(settings.minimap) == "table" and settings.minimap or {}
    settings.hiddenCharacters = settings.hiddenCharacters or {}
    settings.favoriteCharacters = settings.favoriteCharacters or {}
    settings.options = type(settings.options) == "table" and settings.options or {}
end

local function NormalizeActionBarSettings(settings)
    settings.panel.actionBarFloating = settings.panel.actionBarFloating == true
    settings.panel.actionBarLocked = settings.panel.actionBarLocked == true
    settings.panel.actionBarPosition = type(settings.panel.actionBarPosition) == "table" and settings.panel.actionBarPosition or { point = "CENTER", relativePoint = "CENTER", x = 0, y = -160 }
    settings.panel.actionBarPosition.point = settings.panel.actionBarPosition.point or "CENTER"
    settings.panel.actionBarPosition.relativePoint = settings.panel.actionBarPosition.relativePoint or "CENTER"
    settings.panel.actionBarPosition.x = tonumber(settings.panel.actionBarPosition.x) or 0
    settings.panel.actionBarPosition.y = tonumber(settings.panel.actionBarPosition.y) or -160

    settings.panel.actionButtons = type(settings.panel.actionButtons) == "table" and settings.panel.actionButtons or {}
    local validActionButtons = {
        mulch = true,
        seed = true,
        glowingSeed = true,
        wildSeed = true,
        primalSeed = true,
        greenThumb = true,
        overloadHerb = true,
        overloadOre = true,
        parcel = true,
        bank = true,
    }
    for key in pairs(validActionButtons) do
        if settings.panel.actionButtons[key] == nil then
            settings.panel.actionButtons[key] = true
        else
            settings.panel.actionButtons[key] = settings.panel.actionButtons[key] ~= false
        end
    end
    for key in pairs(settings.panel.actionButtons) do
        if not validActionButtons[key] then
            settings.panel.actionButtons[key] = nil
        end
    end
end

local function NormalizeDisplaySettings(self, settings)
    settings.display.panelOpacity = ClampNumber(settings.display.panelOpacity, 0.20, 1.00, 0.55)
    settings.display.launcherOpacity = ClampNumber(settings.display.launcherOpacity, 0.20, 1.00, 0.50)
    settings.display.sessionOpacity = ClampNumber(settings.display.sessionOpacity, 0.20, 1.00, 0.55)
    if settings.display.showProfession1Column == nil then settings.display.showProfession1Column = settings.display.showProfessionColumn ~= false end
    if settings.display.showConcentration1Column == nil then settings.display.showConcentration1Column = settings.display.showConcentrationColumn ~= false end
    if settings.display.showProfession2Column == nil then settings.display.showProfession2Column = true end
    if settings.display.showConcentration2Column == nil then settings.display.showConcentration2Column = true end
    if settings.display.showMoxieColumn == nil then settings.display.showMoxieColumn = false end
    if settings.display.showMulchColumn == nil then settings.display.showMulchColumn = true end
    if settings.display.showCooldownColumn == nil then settings.display.showCooldownColumn = true end
    if settings.display.showLauncherCooldown == nil then settings.display.showLauncherCooldown = false end
    if settings.display.cooldownDisplayScope == nil then settings.display.cooldownDisplayScope = "current" end
    settings.display.hiddenCooldowns = type(settings.display.hiddenCooldowns) == "table" and settings.display.hiddenCooldowns or {}
    if settings.display.showForecastColumn == nil then settings.display.showForecastColumn = false end
    if settings.display.showCharacterRealm == nil then settings.display.showCharacterRealm = true end
    if settings.display.attentionOnly == nil then settings.display.attentionOnly = false end
    if settings.display.compactMode == nil then settings.display.compactMode = false end
    if settings.display.showCurrentCharacterFirst == nil then settings.display.showCurrentCharacterFirst = false end
    if settings.display.showPinnedFirst == nil then
        settings.display.showPinnedFirst = settings.display.showFavoritesFirst
        if settings.display.showPinnedFirst == nil then settings.display.showPinnedFirst = true end
    end
    settings.display.showFavoritesFirst = nil
    settings.display.showProfession1Column = settings.display.showProfession1Column ~= false
    settings.display.showConcentration1Column = settings.display.showConcentration1Column ~= false
    settings.display.showProfession2Column = settings.display.showProfession2Column ~= false
    settings.display.showConcentration2Column = settings.display.showConcentration2Column ~= false
    settings.display.showMoxieColumn = settings.display.showMoxieColumn == true
    settings.display.showMulchColumn = settings.display.showMulchColumn ~= false
    settings.display.showCooldownColumn = settings.display.showCooldownColumn ~= false
    settings.display.showLauncherCooldown = settings.display.showLauncherCooldown == true
    if settings.display.cooldownDisplayScope ~= "current_previous" and settings.display.cooldownDisplayScope ~= "all" then
        settings.display.cooldownDisplayScope = "current"
    end
    for key, value in pairs(settings.display.hiddenCooldowns) do
        if type(key) ~= "string" or value ~= true then
            settings.display.hiddenCooldowns[key] = nil
        end
    end
    settings.display.showForecastColumn = settings.display.showForecastColumn == true
    settings.display.showCharacterRealm = settings.display.showCharacterRealm ~= false
    settings.display.attentionOnly = settings.display.attentionOnly == true
    settings.display.compactMode = settings.display.compactMode == true
    settings.display.showCurrentCharacterFirst = settings.display.showCurrentCharacterFirst == true
    settings.display.showPinnedFirst = settings.display.showPinnedFirst ~= false
    settings.display.showProfessionColumn = settings.display.showProfession1Column
    settings.display.showConcentrationColumn = settings.display.showConcentration1Column
    if settings.display.showProfession1Column == false and settings.display.showConcentration1Column == false and settings.display.showProfession2Column == false and settings.display.showConcentration2Column == false and settings.display.showMoxieColumn == false and settings.display.showMulchColumn == false and settings.display.showCooldownColumn == false and settings.display.showForecastColumn == false then
        settings.display.showProfession1Column = true
        settings.display.showProfessionColumn = true
    end
    CleanupSavedCharacterFlags(self.db)
end

local function NormalizeAlertAndScaleSettings(self, settings)
    settings.alerts.concentrationThreshold = math.floor(ClampNumber(settings.alerts.concentrationThreshold, 0, self.CONCENTRATION_MAX_DEFAULT, self.CONCENTRATION_THRESHOLD_DEFAULT or 900))
    settings.alerts.moxieThreshold = math.floor(ClampNumber(settings.alerts.moxieThreshold, 0, 1000, self.MOXIE_THRESHOLD_DEFAULT or 600))
    if type(settings.alerts.professionThresholds) ~= "table" then settings.alerts.professionThresholds = {} end
    local normalizedThresholds = {}
    for k, v in pairs(settings.alerts.professionThresholds) do
        local id = tonumber(k)
        local threshold = tonumber(v)
        if id and threshold and threshold > 0 then
            normalizedThresholds[id] = math.floor(ClampNumber(threshold, 0, self.CONCENTRATION_MAX_DEFAULT, settings.alerts.concentrationThreshold))
        end
    end
    settings.alerts.professionThresholds = normalizedThresholds

    local ui = self.UI_CONSTANTS or {}
    local minScale = ui.PANEL_MIN_SCALE or 0.6
    local maxScale = ui.PANEL_MAX_SCALE or 1.4
    settings.panel.scale = ClampNumber(settings.panel.scale, minScale, maxScale, 1)
    settings.session.scale = ClampNumber(settings.session.scale, minScale, maxScale, 1)

    settings.minimap.hide = settings.minimap.hide == true
    settings.onboardingSeen = settings.onboardingSeen == true
    settings.minimap.minimapPos = ClampNumber(settings.minimap.minimapPos, 0, 360, 220)

    settings.panel.width = math.floor(ClampNumber(settings.panel.width, ui.TRACKING_DYNAMIC_MIN_W or ui.PANEL_MIN_W or 352, ui.PANEL_MAX_W or 900, 352))
    settings.panel.height = math.floor(ClampNumber(settings.panel.height, ui.PANEL_MIN_H or 120, ui.PANEL_MAX_H or 720, 360))
    if settings.panel.customHeight ~= nil then
        settings.panel.customHeight = math.floor(ClampNumber(settings.panel.customHeight, ui.PANEL_MIN_H or 120, ui.PANEL_MAX_H or 720, settings.panel.height))
    end
    settings.session.width = math.floor(ClampNumber(settings.session.width, ui.SESSION_MIN_W or 320, ui.PANEL_MAX_W or 900, ui.SESSION_MIN_W or 320))
    settings.session.height = math.floor(ClampNumber(settings.session.height, 120, ui.PANEL_MAX_H or 720, 180))
end

local function NormalizeSessionSettings(settings)
    local function normalizeBool(tbl, key, default)
        if tbl[key] == nil then tbl[key] = default and true or false end
        tbl[key] = tbl[key] ~= false
    end
    normalizeBool(settings.session, "trackHerbs", true)
    normalizeBool(settings.session, "trackOre", true)
    normalizeBool(settings.session, "trackCloth", true)
    normalizeBool(settings.session, "trackLeather", true)
    normalizeBool(settings.session, "trackEnchanting", true)
    normalizeBool(settings.session, "trackFish", true)
    normalizeBool(settings.session, "trackOtherMaterials", true)
    normalizeBool(settings.session, "countTrustedMailRewards", true)
    normalizeBool(settings.session, "countCraftedItems", false)
    normalizeBool(settings.session, "sessionHistoryEnabled", true)
    settings.session.historyMaxEntries = math.floor(ClampNumber(settings.session.historyMaxEntries, 50, 3000, 500))
    settings.session.historyRetentionDays = 30
    if settings.session.historyDisplayMode ~= "today" and settings.session.historyDisplayMode ~= "week" and settings.session.historyDisplayMode ~= "30" then
        local oldDays = tonumber(settings.session.historyDisplayDays) or 30
        settings.session.historyDisplayMode = oldDays == 1 and "today" or (oldDays == 7 and "week" or "30")
    end
    settings.session.historyDisplayDays = settings.session.historyDisplayMode == "today" and 1 or (settings.session.historyDisplayMode == "week" and 7 or 30)

    settings.session.collapsed = nil
    settings.panel.sessionCollapsed = nil
end

function EL:NormalizeDatabaseSettings()
    if type(self.db) ~= "table" or type(self.db.settings) ~= "table" then return end
    local settings = self.db.settings
    NormalizeResourceTables(self)
    NormalizeStatsTables(self)
    NormalizeSettingsTables(settings)
    NormalizeActionBarSettings(settings)
    NormalizeDisplaySettings(self, settings)
    NormalizeAlertAndScaleSettings(self, settings)
    NormalizeSessionSettings(settings)
end

function EL:Debug(msg)
    if self.db and self.db.settings and self.db.settings.debug then
        print("|cff9ecbffEmberLedger Debug:|r " .. tostring(msg))
    end
end

function EL:DebugThrottled(key, seconds, msg)
    if not (self.db and self.db.settings and self.db.settings.debug) then return end
    self._debugThrottle = self._debugThrottle or {}
    local now = (GetTime and GetTime()) or time()
    key = tostring(key or msg or "debug")
    seconds = self:SafeNumber(seconds, 1, "debug.throttleSeconds") or 1
    if self._debugThrottle[key] and now - self._debugThrottle[key] < seconds then return end
    self._debugThrottle[key] = now
    self:Debug(msg)
end

function EL:IsProfilingEnabled()
    local perf = self.db and self.db.settings and self.db.settings.performance or {}
    return perf.profile == true
end

function EL:GetProfileSlowThresholdMs()
    local perf = self.db and self.db.settings and self.db.settings.performance or {}
    return self:SafeNumber(perf.profileSlowMs, 1.0, "profile.slowMs") or 1.0
end

function EL:SetProfilingEnabled(enabled)
    self.db = self.db or {}
    self.db.settings = self.db.settings or {}
    self.db.settings.performance = self.db.settings.performance or {}
    self.db.settings.performance.profile = enabled and true or false
    if self.db.settings.performance.profile then
        self._profileStats = self._profileStats or {}
        self:Print("Performance profiling enabled. Slow sections will be reported in chat.")
    else
        self:Print("Performance profiling disabled.")
    end
end

function EL:ResetProfileStats()
    self._profileStats = {}
    self._profileThrottle = {}
    self:Print("Performance profile counters reset.")
end

local function ProfileNowMs()
    if debugprofilestop then
        local ok, value = pcall(debugprofilestop)
        if ok and value then return value end
    end
    if GetTime then return GetTime() * 1000 end
    return time() * 1000
end

function EL:ProfileStart(label)
    if not self:IsProfilingEnabled() then return nil end
    return ProfileNowMs()
end

function EL:ProfileStop(label, started)
    if not started or not self:IsProfilingEnabled() then return end
    local nowMs = ProfileNowMs()
    local elapsedMs = math.max(0, nowMs - started)
    label = tostring(label or "unknown")
    self._profileStats = self._profileStats or {}
    local stat = self._profileStats[label] or { count = 0, total = 0, peak = 0, overSlow = 0 }
    stat.count = stat.count + 1
    stat.total = stat.total + elapsedMs
    if elapsedMs > stat.peak then stat.peak = elapsedMs end
    local threshold = self:GetProfileSlowThresholdMs()
    if elapsedMs >= threshold then
        stat.overSlow = stat.overSlow + 1
        self._profileThrottle = self._profileThrottle or {}
        local last = self._profileThrottle[label] or 0
        if nowMs - last >= 5000 then
            self._profileThrottle[label] = nowMs
            self:Print(string.format("Profile: %s took %.3fms", label, elapsedMs))
        end
    end
    self._profileStats[label] = stat
end

function EL:PrintProfileReport()
    if type(self._profileStats) ~= "table" or next(self._profileStats) == nil then
        self:Print("No profile data recorded yet. Use /el profile on, then play normally for a few minutes.")
        return
    end
    self:Print("Performance profile summary:")
    local rows = {}
    for label, stat in pairs(self._profileStats) do
        table.insert(rows, { label = label, count = stat.count or 0, total = stat.total or 0, peak = stat.peak or 0, overSlow = stat.overSlow or 0 })
    end
    table.sort(rows, function(a, b) return (a.total or 0) > (b.total or 0) end)
    for i = 1, math.min(#rows, 18) do
        local row = rows[i]
        local avg = row.count > 0 and (row.total / row.count) or 0
        self:Print(string.format("%s: avg %.3fms, peak %.3fms, total %.1fms, slow %dx/%dx", row.label, avg, row.peak, row.total, row.overSlow, row.count))
    end
end

function EL:SafeNumber(value, fallback, context)
    -- Shared guard for WoW values that may behave like protected/secret numbers.
    -- Some protected values can survive tonumber() but still fail later arithmetic,
    -- so validate the converted value with a protected no-op numeric operation before returning it.
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

    if self.db and self.db.settings and self.db.settings.debug then
        self._safeNumberWarnings = self._safeNumberWarnings or {}
        local key = tostring(context or "unknown")
        if not self._safeNumberWarnings[key] then
            self._safeNumberWarnings[key] = true
            self:Debug("Sanitized non-numeric or protected value in " .. key .. ".")
        end
    end

    return fallback
end

function EL:ToggleDebug()
    self.db.settings.debug = not self.db.settings.debug
    self:Print("Debug " .. (self.db.settings.debug and "enabled." or "disabled."))
end

function EL:IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

function EL:QueueCombatDeferredWork(kind)
    if kind == "actionBar" then
        self.pendingActionBarRefresh = true
    elseif kind == "layout" then
        self.pendingSecureLayout = true
        self.pendingUIRefresh = true
    elseif kind == "visibility" then
        self.pendingWindowVisibility = true
        self.pendingUIRefresh = true
    else
        self.pendingUIRefresh = true
    end
end

function EL:PerformActionBarRefresh()
    if self:IsCombatLocked() then
        self:QueueCombatDeferredWork("actionBar")
        return
    end
    if self.UpdateActionBar then self:UpdateActionBar() end
end

function EL:RequestActionBarRefresh(immediate)
    if self:IsCombatLocked() then
        self:QueueCombatDeferredWork("actionBar")
        return
    end

    if immediate or not (C_Timer and C_Timer.After) then
        self:PerformActionBarRefresh()
        return
    end

    if self.actionBarRefreshQueued then return end
    self.actionBarRefreshQueued = true

    C_Timer.After(self.ACTION_BAR_DEBOUNCE_SECONDS or 0.05, function()
        if not EL then return end
        EL.actionBarRefreshQueued = nil
        if EL.IsCombatLocked and EL:IsCombatLocked() then
            if EL.QueueCombatDeferredWork then EL:QueueCombatDeferredWork("actionBar") end
            return
        end
        if EL.ShouldRefreshActionBar and not EL:ShouldRefreshActionBar() then return end
        if EL.PerformActionBarRefresh then EL:PerformActionBarRefresh() end
    end)
end

function EL:FlushCombatDeferredWork()
    local needsActionBar = self.pendingActionBarRefresh
    local needsLayout = self.pendingSecureLayout
    local needsRefresh = self.pendingUIRefresh
    local needsPositionRestore = self.pendingWindowPositionRestore
    local needsVisibility = self.pendingWindowVisibility

    self.pendingActionBarRefresh = nil
    self.pendingSecureLayout = nil
    self.pendingUIRefresh = nil
    self.pendingWindowPositionRestore = nil
    self.pendingWindowVisibility = nil

    if needsPositionRestore and self.RestoreDeferredWindowPositions then
        self:RestoreDeferredWindowPositions()
    end
    if needsVisibility and self.ApplyDeferredWindowVisibility then
        self:ApplyDeferredWindowVisibility()
    end
    if needsLayout then
        if self.LayoutPanel then self:LayoutPanel() end
        if self.AutoSizePanelHeight then self:AutoSizePanelHeight("combatDeferred") end
        if self.LayoutSessionWindow then self:LayoutSessionWindow() end
    end
    if needsActionBar and self.RequestActionBarRefresh then
        self:RequestActionBarRefresh(true)
    end
    if needsRefresh and self.RequestUpdate then
        self:RequestUpdate(true)
    end
end

function EL:EnsureDB()
    if type(EmberLedgerDB) ~= "table" then
        EmberLedgerDB = {}
    end
    local previousVersion = tonumber(EmberLedgerDB.version) or 0
    CopyDefaults(defaults, EmberLedgerDB)
    self.db = EmberLedgerDB
    self:RunDatabaseCleanup(previousVersion)
    -- NormalizeDatabaseSettings is called once after ALL migrations complete
    -- (see bottom of EnsureDB). Calling it here before migrations run was
    -- redundant and could produce inconsistent state when migrations alter
    -- settings keys that normalization also reads.

    -- Legacy migration: internal collapse controls were removed when the character and
    -- session modules became independently toggled/windows. Clear old collapse
    -- state so stale SavedVariables cannot create blank panels after reload.
    local uiRefactorVersion = tonumber(self.db.uiRefactorVersion) or 0
    if uiRefactorVersion < 820 then
        self.db.settings = self.db.settings or {}
        self.db.settings.panel = self.db.settings.panel or {}
        self.db.settings.session = self.db.settings.session or {}
        self.db.settings.panel.charactersCollapsed = false
        self.db.settings.session.collapsed = nil
        self.db.uiRefactorVersion = 820
    end

    -- Legacy migration: clear older Imbued Mulch capability flags that were based on
    -- generic Herbalism or stale saved data. Capability is now only trusted
    -- when it was confirmed by the stricter v2 check in Modules/Mulch.lua.
    local mulchVersion = tonumber(self.db.mulchCapabilityVersion) or 0
    if mulchVersion < 2 and self.db.resources and type(self.db.resources.mulch) == "table" then
        for _, data in pairs(self.db.resources.mulch) do
            if type(data) == "table" then
                data.confirmedImbuedMulchAccess = nil
                data.hasImbuedMulchAccess = false
                data.itemKnown = nil
                data.readyAt = nil
                data.confirmationSource = nil
                data.confirmationVersion = nil
            end
        end
        self.db.mulchCapabilityVersion = 2
    end

    -- Legacy migration: normalize launcher opacity default to 50% for the redesigned launcher/settings panel.
    local uiOptionsVersion = tonumber(self.db.uiOptionsVersion) or 0
    if uiOptionsVersion < 425 then
        self.db.settings = self.db.settings or {}
        self.db.settings.display = self.db.settings.display or {}
        self.db.settings.display.launcherOpacity = 0.50
        self.db.uiOptionsVersion = 425
    end

    -- Legacy migration: align standalone Session window width with the minimum Profession Tracking window width.
    -- Preserve intentionally wider user values, but pull old default-width saves down to the cleaner compact width.
    -- Legacy migration: compact tracking layout; session width tightened further.
    -- Capture the raw version ONCE so both blocks compare against the pre-migration value,
    -- not the mutated key written by the first block.
    local rawSessionWidthVersion = tonumber(self.db.sessionWidthVersion) or 0
    if rawSessionWidthVersion < 910 then
        self.db.settings = self.db.settings or {}
        self.db.settings.session = self.db.settings.session or {}
        local session = self.db.settings.session
        if session.width == nil or tonumber(session.width) <= 360 then
            session.width = 352
        end
        self.db.sessionWidthVersion = 910
    end

    -- Legacy compact tracking layout migration.
    if rawSessionWidthVersion < 1750 then
        self.db.settings = self.db.settings or {}
        self.db.settings.session = self.db.settings.session or {}
        local session = self.db.settings.session
        if session.width == nil or tonumber(session.width) <= 360 then
            session.width = 320
        end
        self.db.sessionWidthVersion = 1750
    end

    -- Legacy pinning cleanup and saved-table normalization.
    local polishVersion = tonumber(self.db.polishVersion) or 0
    if polishVersion < 1900 then
        CleanupSavedCharacterFlags(self.db)
        self.db.polishVersion = 1900
    end

    -- Keep the action bar anchored by default after the first floating-bar release.
    -- Users can still enable floating mode again from Options.
    local actionBarPlacementVersion = tonumber(self.db.actionBarPlacementVersion) or 0
    if actionBarPlacementVersion < 1202 then
        self.db.settings = self.db.settings or {}
        self.db.settings.panel = self.db.settings.panel or {}
        self.db.settings.panel.actionBarFloating = false
        self.db.actionBarPlacementVersion = 1202
    end

    -- Migration: align the untouched historical concentration threshold default
    -- with the documented 900-value default. Explicit user/custom values other than
    -- the old default are preserved.
    local thresholdDefaultVersion = tonumber(self.db.thresholdDefaultVersion) or 0
    if thresholdDefaultVersion < 13005 then
        self.db.settings = self.db.settings or {}
        self.db.settings.alerts = self.db.settings.alerts or {}
        local currentThreshold = tonumber(self.db.settings.alerts.concentrationThreshold)
        if currentThreshold == nil or currentThreshold == 360 then
            self.db.settings.alerts.concentrationThreshold = self.CONCENTRATION_THRESHOLD_DEFAULT or 900
        end
        self.db.thresholdDefaultVersion = 13005
    end

    self:NormalizeDatabaseSettings()
    if self.BackfillLifetimeSessionStatsFromHistory then self:BackfillLifetimeSessionStatsFromHistory() end
    if self.BackfillSessionAggregateStatsFromHistory then self:BackfillSessionAggregateStatsFromHistory() end
    return EmberLedgerDB
end

local function TrimCharacterKeyPart(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function CanonicalRealmKeyPart(value)
    value = TrimCharacterKeyPart(value)
    -- Realm values can appear with or without spaces depending on API timing or legacy data.
    -- Keep display realm text separate, but use a stable no-space realm token for saved keys.
    value = value:gsub("%s+", "")
    if value == "" then value = "UnknownRealm" end
    return value
end

function EL:GetRealm()
    return GetNormalizedRealmName() or GetRealmName() or "UnknownRealm"
end

function EL:GetCanonicalCharacterKey(name, realm)
    name = TrimCharacterKeyPart(name or UnitName("player") or "Unknown")
    if name == "" then name = "Unknown" end
    realm = CanonicalRealmKeyPart(realm or self:GetRealm())
    return name .. "-" .. realm
end

function EL:GetCharacterKey(name, realm)
    return self:GetCanonicalCharacterKey(name, realm)
end

function EL:GetCurrentCharacter()
    self.db = self.db or {}
    self.db.characters = type(self.db.characters) == "table" and self.db.characters or {}
    local key = self:GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = self:GetRealm()
    local _, classFile = UnitClass("player")
    self.db.characters[key] = self.db.characters[key] or {}
    local c = self.db.characters[key]
    local displayName = name .. "-" .. realm
    local characterRowsChanged = c.key ~= key or c.name ~= name or c.realm ~= realm or c.displayName ~= displayName or c.class ~= (classFile or c.class)
    c.key = key
    c.name = name
    c.realm = realm
    c.displayName = displayName
    c.class = classFile or c.class
    c.lastSeen = time()
    if characterRowsChanged and self.InvalidateCharacterRows then self:InvalidateCharacterRows() end
    self.currentCharKey = key
    return key, c
end


function EL:GetCharacterDisplayName(char, charKey)
    char = char or {}
    local display = self.db and self.db.settings and self.db.settings.display or {}
    if display.showCharacterRealm == false then
        return tostring(char.name or charKey or "Unknown")
    end
    return tostring(char.displayName or charKey or char.name or "Unknown")
end

function EL:RegisterModule(name, module)
    self.modules[name] = module
    self.moduleOrder = type(self.moduleOrder) == "table" and self.moduleOrder or {}
    local known = false
    for _, registeredName in ipairs(self.moduleOrder) do
        if registeredName == name then
            known = true
            break
        end
    end
    if not known then
        self.moduleOrder[#self.moduleOrder + 1] = name
    end
    module.name = name
    module.EL = self
end

function EL:GetModule(name)
    return self.modules and self.modules[name]
end

function EL:ForEachModule(fn)
    local orderedNames = type(self.moduleOrder) == "table" and self.moduleOrder or {}
    local seen = {}
    for _, name in ipairs(orderedNames) do
        local module = self.modules and self.modules[name]
        seen[name] = true
        if module and module[fn] then
            local ok, err = pcall(module[fn], module)
            if not ok and self.Debug then
                self:Debug("Module error [" .. tostring(module.name or "?") .. "." .. tostring(fn) .. "]: " .. tostring(err))
            end
        end
    end
    for name, module in pairs(self.modules or {}) do
        if not seen[name] and module and module[fn] then
            local ok, err = pcall(module[fn], module)
            if not ok and self.Debug then
                self:Debug("Module error [" .. tostring(module.name or "?") .. "." .. tostring(fn) .. "]: " .. tostring(err))
            end
        end
    end
end

EL.REQUIRED_MODULES = {
    Core = {
        functions = {
            "SafeNumber",
            "InvalidateConcentrationIndex",
            "GetConcentrationIndex",
            "GetEstimatedConcentration",
            "HasImbuedMulchAccess",
            "InvalidateProfessionLookup",
            "GetProfessionLookup",
            "GetMulchStatus",
            "RequestUpdate",
            "SetSortKey",
            "SortDashboardRows",
            "IsSortColumnAvailable",
            "T",
            "GetLocalizationTable",
        },
    },
    UI = {
        functions = {
            "IsTrackingColumnVisible",
            "GetVisibleTrackingRowCount",
            "AutoSizeTrackingPanel",
            "LayoutPanel",
            "RefreshPanel",
            "RestoreSavedTrackingHeightIfNeeded",
        },
    },
    TrackingRows = {
        functions = {
            "GetRow",
            "RefreshTrackingRows",
            "GetTrackingRowHeight",
        },
    },
    OptionsPanel = {
        functions = {
            "CreateSettingsPanel",
            "RefreshSettingsPanel",
            "ShowSettingsPanel",
        },
    },
    Onboarding = {
        functions = {
            "CreateOnboardingPanel",
            "ShowOnboardingPanel",
            "RefreshOnboardingPanel",
        },
    },
    concentration = { registered = true },
    mulch = { registered = true },
    session = { registered = true },
    Minimap = { registered = true },
    tooltips = {
        registered = true,
        functions = {
            "ShowRowTooltip",
            "AddProfessionCooldownTooltipLines",
            "FormatTooltipDate",
            "FormatTooltipAgo",
        },
    },
    ProfessionCooldowns = {
        registered = true,
        functions = {
            "EnsureProfessionCooldownStore",
            "RefreshCurrentProfessionCooldowns",
            "GetProfessionCooldownDisplayText",
            "AddProfessionCooldownTooltipLines",
            "GetProfessionCooldownSortValue",
            "HasProfessionCooldownColumnData",
            "PruneProfessionCooldownStore",
            "GetCooldownDisplayScope",
            "SetCooldownDisplayScope",
            "IsProfessionCooldownHidden",
            "SetProfessionCooldownHidden",
            "GetProfessionCooldownVisibilityDefinitions",
        },
    },
    SessionWindow = {
        registered = true,
        functions = {
            "RefreshSessionView",
            "RefreshSessionStatsView",
            "RefreshBagSummaryView",
            "CreateSessionWindow",
            "LayoutSessionWindow",
            "ShowSessionWindow",
            "HideSessionWindow",
            "ShowSessionWindowFromSavedState",
            "ToggleSessionWindow",
        },
    },
    Styling = {
        functions = {
            "StyleBlizzardButton",
        },
        styleFunctions = {
            "AddBackdrop",
            "AddInnerBorder",
            "ApplyFrameOpacity",
        },
    },
    ActionBar = {
        functions = {
            "CreateActionBar",
            "UpdateActionBar",
            "LayoutActionBar",
            "ToggleActionBarFloating",
        },
    },
}

function EL:VerifyModuleInitialization(context, releaseWarning)
    local debug = self.db and self.db.settings and self.db.settings.debug
    local ok = true
    local messages = {}
    local required = self.REQUIRED_MODULES or {}
    local label = "Module check" .. (context and (" [" .. tostring(context) .. "]") or "")

    for name, spec in pairs(required) do
        if spec.registered and not (self.modules and self.modules[name]) then
            ok = false
            table.insert(messages, "missing registered module " .. tostring(name))
        end
        for _, fnName in ipairs(spec.functions or {}) do
            if type(self[fnName]) ~= "function" then
                ok = false
                table.insert(messages, "missing function " .. tostring(fnName))
            end
        end
        for _, fnName in ipairs(spec.styleFunctions or {}) do
            if not (self.Style and type(self.Style[fnName]) == "function") then
                ok = false
                table.insert(messages, "missing style helper " .. tostring(fnName))
            end
        end
    end

    if not ok and self.Print then
        if debug then
            for _, msg in ipairs(messages) do
                self:Print(label .. ": " .. tostring(msg))
            end
        elseif releaseWarning and not self._moduleInitWarningShown then
            self._moduleInitWarningShown = true
            local first = messages[1] and (" First issue: " .. tostring(messages[1]) .. ".") or ""
            self:Print("One or more EmberLedger modules or core helpers did not initialize cleanly." .. first .. " Use /el debug for details, then /reload.")
        end
    end

    return ok
end

function EL:MakeResourceKey(charKey, resourceKey)
    return charKey .. self.DB_KEY_SEP .. tostring(resourceKey or "default")
end

function EL:FormatDuration(seconds)
    return FormatCompactDuration(seconds, false)
end

function EL:GetClassColor(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then
        -- Slightly soften class colors so they fit the darker EmberLedger palette.
        local blend = 0.24
        local floor = 0.12
        local r = math.max(floor, (c.r or 1) * (1 - blend) + 0.68 * blend)
        local g = math.max(floor, (c.g or 1) * (1 - blend) + 0.70 * blend)
        local b = math.max(floor, (c.b or 1) * (1 - blend) + 0.76 * blend)
        return r, g, b
    end
    return 0.92, 0.92, 0.92
end

function EL:ResolveSessionHistoryClass(entry)
    if type(entry) ~= "table" then return nil end
    if entry.class and entry.class ~= "" then return entry.class end
    local characters = self.db and self.db.characters
    if type(characters) ~= "table" then return nil end
    local entryName = tostring(entry.character or "")
    local entryRealm = tostring(entry.realm or "")
    for key, char in pairs(characters) do
        if type(char) == "table" then
            local name = tostring(char.name or "")
            local realm = tostring(char.realm or "")
            if name == entryName and (entryRealm == "" or realm == entryRealm) then
                return char.class
            end
            if tostring(key or "") == entryName .. "-" .. entryRealm then
                return char.class
            end
        end
    end
    return nil
end

function EL:GetProfessionsSafe()
    if type(GetProfessions) ~= "function" then return nil, nil end
    local ok, prof1, prof2 = pcall(GetProfessions)
    if ok then return prof1, prof2 end
    if self.DebugThrottled then self:DebugThrottled("professions.get.failed", 10, "GetProfessions failed during profession identity scan.") end
    return nil, nil
end

function EL:GetProfessionInfoSafe(profIndex)
    if type(GetProfessionInfo) ~= "function" or not profIndex then return nil end
    local ok, name, icon, skillLevel, maxSkillLevel, numAbilities, spellOffset, skillLine = pcall(GetProfessionInfo, profIndex)
    if ok then return name, icon, skillLevel, maxSkillLevel, numAbilities, spellOffset, skillLine end
    if self.DebugThrottled then self:DebugThrottled("profession.info.failed", 10, "GetProfessionInfo failed during profession identity scan.") end
    return nil
end

function EL:CharacterHasProfession(skillLineID)
    local target = self:SafeNumber(skillLineID, nil, "profession.targetSkillLine")
    if not target then return false end
    local prof1, prof2 = self:GetProfessionsSafe()
    local professions = { prof1, prof2 }
    for _, profIndex in ipairs(professions) do
        if profIndex then
            local _, _, _, _, _, _, skillLine = self:GetProfessionInfoSafe(profIndex)
            if self:SafeNumber(skillLine, nil, "profession.skillLine") == target then
                return true
            end
        end
    end
    return false
end

function EL:RefreshCurrentProfessionIdentity()
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return false end
    self.db = self.db or {}
    self.db.resources = type(self.db.resources) == "table" and self.db.resources or {}
    self.db.resources.professions = type(self.db.resources.professions) == "table" and self.db.resources.professions or {}

    local charKey, char = self:GetCurrentCharacter()
    if not charKey then return false end

    local prof1, prof2 = self:GetProfessionsSafe()
    local slots = { prof1, prof2 }
    local list = {}

    for slotIndex, profIndex in ipairs(slots) do
        if profIndex then
            local name, icon, skillLevel, maxSkillLevel, _, _, skillLine = self:GetProfessionInfoSafe(profIndex)
            if name and name ~= "" then
                skillLine = self:SafeNumber(skillLine, nil, "profession.identity.skillLine")
                skillLevel = self:SafeNumber(skillLevel, 0, "profession.identity.skillLevel") or 0
                maxSkillLevel = self:SafeNumber(maxSkillLevel, 0, "profession.identity.maxSkillLevel") or 0
                list[#list + 1] = {
                    charKey = charKey,
                    charName = char and char.name or UnitName("player") or "Unknown",
                    realm = char and char.realm or self:GetRealm(),
                    class = char and char.class,
                    slot = slotIndex,
                    professionID = skillLine,
                    skillLineID = skillLine,
                    professionName = name,
                    icon = icon,
                    skillLevel = skillLevel,
                    maxSkillLevel = maxSkillLevel,
                    lastUpdate = time(),
                    source = "GetProfessions",
                }
            end
        end
    end

    if #list == 0 then
        local existing = self.db.resources.professions[charKey]
        if type(existing) == "table" and #existing > 0 then
            -- Avoid wiping known profession identity if the profession API is not ready yet.
            return false
        end
    end

    self.db.resources.professions[charKey] = list
    if self.InvalidateProfessionLookup then self:InvalidateProfessionLookup() end
    if char then
        char.professions = list
    end
    return true
end

function EL:InvalidateProfessionLookup()
    self._professionLookupCache = nil
end

function EL:GetProfessionLookup()
    if self._professionLookupCache then return self._professionLookupCache end

    local lookup = {}
    for charKey, stored in pairs(self.db and self.db.resources and self.db.resources.professions or {}) do
        if type(stored) == "table" then
            local list = {}
            for _, data in ipairs(stored) do
                if type(data) == "table" and (data.professionName or data.professionID or data.skillLineID) then
                    list[#list + 1] = data
                end
            end
            if #list > 0 then
                table.sort(list, SortProfessionEntriesBySlot)
                lookup[charKey] = list
            end
        end
    end

    self._professionLookupCache = lookup
    return lookup
end

function EL:GetProfessionEntriesForCharacter(charKey)
    if not charKey then return {} end
    local lookup = self.GetProfessionLookup and self:GetProfessionLookup() or nil
    local out = lookup and lookup[charKey]
    if out and #out > 0 then
        return out
    end

    -- Compatibility fallback for older characters that have concentration data but have not logged in since profession identity tracking was added.
    return self:GetConcentrationEntriesForCharacter(charKey)
end

function EL:GetConcentrationEntryForProfession(charKey, professionData, concentrationEntries)
    if not charKey or type(professionData) ~= "table" then return nil end
    local targetID = self.SafeNumber and self:SafeNumber(professionData.professionID or professionData.skillLineID or professionData.skillLine, nil, "concentration.match.targetID") or nil
    local targetParentID = self.SafeNumber and self:SafeNumber(professionData.parentProfessionID, nil, "concentration.match.targetParentID") or nil
    local targetName = self:GetCleanProfessionName(professionData.professionName):lower()
    local fallback
    local source = concentrationEntries or (self.db and self.db.resources and self.db.resources.concentration) or {}

    for _, data in pairs(source) do
        if data and data.charKey == charKey then
            local dataID = self.SafeNumber and self:SafeNumber(data.professionID or data.skillLineID or data.skillLine, nil, "concentration.match.dataID") or nil
            local dataParentID = self.SafeNumber and self:SafeNumber(data.parentProfessionID, nil, "concentration.match.dataParentID") or nil
            if targetID and dataID and targetID == dataID then
                return data
            end
            if targetID and dataParentID and targetID == dataParentID then
                return data
            end
            if targetParentID and dataID and targetParentID == dataID then
                return data
            end
            if targetParentID and dataParentID and targetParentID == dataParentID then
                return data
            end
            local dataName = self:GetCleanProfessionName(data.professionName):lower()
            if targetName ~= "profession" and targetName ~= "" and dataName == targetName then
                fallback = data
            end
        end
    end

    return fallback
end

function EL:GetDashboardProfessionSlots(charKey, professionEntries, concentrationEntries)
    local slots = {}
    local professions = professionEntries or self:GetProfessionEntriesForCharacter(charKey)
    local matchedConc = {}
    local concSource = concentrationEntries or self:GetConcentrationEntriesForCharacter(charKey) or {}

    for _, profData in ipairs(professions or {}) do
        local concData = self:GetConcentrationEntryForProfession(charKey, profData, concSource)
        if concData then matchedConc[concData] = true end
        table.insert(slots, { prof = profData, conc = concData })
    end

    -- Locale-safe fallback: if Blizzard reports profession identity and
    -- concentration under different localized labels or skill-line IDs, do not
    -- drop the concentration data. Add any unmatched concentration records as
    -- display-only profession slots, then promote concentration slots to the
    -- visible P1/P2 positions below. This protects non-English clients such as
    -- ptBR where expansion profession names may not match the English ordering.
    for _, concData in ipairs(concSource) do
        if concData and not matchedConc[concData] then
            table.insert(slots, { prof = concData, conc = concData, concentrationFallback = true })
            matchedConc[concData] = true
        end
    end

    -- Prefer concentration-bearing slots first so the two visible profession
    -- columns do not hide concentration just because a locale-specific name or
    -- child-profession ID failed to match the base profession identity.
    local withConcentration, withoutConcentration = {}, {}
    for _, slotData in ipairs(slots) do
        if slotData and slotData.conc then
            table.insert(withConcentration, slotData)
        else
            table.insert(withoutConcentration, slotData)
        end
    end

    if #withConcentration > 0 then
        slots = {}
        for _, slotData in ipairs(withConcentration) do table.insert(slots, slotData) end
        for _, slotData in ipairs(withoutConcentration) do table.insert(slots, slotData) end
    end

    return slots
end

function EL:GetDashboardProfessionData(charKey, slot)
    local slots = self:GetDashboardProfessionSlots(charKey)
    local slotData = slots and slots[slot]
    if slotData then
        return slotData.prof, slotData.conc
    end
    return nil, nil
end

function EL:GetMoxieCurrencyIDForProfession(professionData)
    if not professionData then return nil end
    local professionID = self.SafeNumber and self:SafeNumber(professionData.professionID or professionData.skillLineID or professionData.skillLine, nil, "moxie.professionID") or nil
    local parentID = self.SafeNumber and self:SafeNumber(professionData.parentProfessionID, nil, "moxie.parentProfessionID") or nil
    local lookupID = parentID and self.MOXIE_CURRENCY_BY_PROFESSION_ID and self.MOXIE_CURRENCY_BY_PROFESSION_ID[parentID] and parentID or professionID
    if lookupID and self.MOXIE_CURRENCY_BY_PROFESSION_ID then
        return self.MOXIE_CURRENCY_BY_PROFESSION_ID[lookupID], lookupID
    end
    return nil, lookupID
end

function EL:GetMoxieEntryForProfession(charKey, professionData)
    if not charKey or type(professionData) ~= "table" then return nil end
    local _, professionID = self:GetMoxieCurrencyIDForProfession(professionData)
    if not professionID then return nil end
    local characterMoxie = self.db and self.db.resources and self.db.resources.moxie and self.db.resources.moxie[charKey]
    if type(characterMoxie) ~= "table" then return nil end
    return characterMoxie[professionID] or characterMoxie[tostring(professionID)]
end

function EL:GetMoxieEntriesForCharacter(charKey, professionEntries)
    local list = {}
    if not charKey then return list end
    for _, prof in ipairs(professionEntries or self:GetProfessionEntriesForCharacter(charKey) or {}) do
        local entry = self:GetMoxieEntryForProfession(charKey, prof)
        if entry and type(entry.quantity) == "number" then
            list[#list + 1] = entry
        end
    end
    return list
end

function EL:GetMoxieDisplayText(charKey, professionEntries)
    local values = {}
    for _, prof in ipairs(professionEntries or self:GetProfessionEntriesForCharacter(charKey) or {}) do
        local currencyID = self:GetMoxieCurrencyIDForProfession(prof)
        if currencyID then
            local entry = self:GetMoxieEntryForProfession(charKey, prof)
            if entry and type(entry.quantity) == "number" then
                values[#values + 1] = tostring(entry.quantity)
            end
        end
    end
    if #values == 0 then return "N/A" end
    return table.concat(values, " • ")
end


function EL:GetMoxieThreshold()
    local threshold = self.db and self.db.settings and self.db.settings.alerts and tonumber(self.db.settings.alerts.moxieThreshold)
    return math.max(0, math.min(1000, math.floor((threshold or self.MOXIE_THRESHOLD_DEFAULT or 600) + 0.5)))
end

function EL:HasMoxieAtThreshold(charKey, moxieEntries)
    local threshold = self:GetMoxieThreshold()
    for _, entry in ipairs(moxieEntries or self:GetMoxieEntriesForCharacter(charKey) or {}) do
        if type(entry.quantity) == "number" and entry.quantity >= threshold then
            return true
        end
    end
    return false
end

function EL:GetMoxieSortValue(charKey, moxieEntries)
    local total, found = 0, false
    for _, entry in ipairs(moxieEntries or self:GetMoxieEntriesForCharacter(charKey) or {}) do
        if type(entry.quantity) == "number" then
            total = total + entry.quantity
            found = true
        end
    end
    return found and total or nil
end

-- Expansion prefixes to strip from profession names so the UI stays
-- expansion-neutral. Update EL.PROFESSION_EXPANSION_PREFIXES with new expansion
-- profession prefixes rather than maintaining local copies in display code.
-- Do not add a prefix that is the leading substring of another entry unless the
-- longer entry is checked first.
local EXPANSION_PREFIXES = EL.PROFESSION_EXPANSION_PREFIXES or {}
local EXPANSION_PREFIX_DATA = {}
for i, prefix in ipairs(EXPANSION_PREFIXES) do
    EXPANSION_PREFIX_DATA[i] = { text = prefix, lower = prefix:lower(), len = #prefix }
end
table.sort(EXPANSION_PREFIX_DATA, function(a, b) return (a.len or 0) > (b.len or 0) end)
local cleanProfessionNameCache = {}

local function StripProfessionExpansionPrefix(name)
    local trimmed = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then return "" end
    local lower = trimmed:lower()
    for _, prefix in ipairs(EXPANSION_PREFIX_DATA) do
        if lower:sub(1, prefix.len) == prefix.lower and trimmed:sub(prefix.len + 1, prefix.len + 1) == " " then
            return trimmed:sub(prefix.len + 2):gsub("^%s+", ""):gsub("%s+$", "")
        end

        -- Some locales place the expansion name after the profession name
        -- instead of before it, for example "Alchemy of Khaz Algar" style
        -- strings. Strip known expansion names anywhere in the label so
        -- profession/concentration matching does not depend on English word
        -- order. This is intentionally conservative and only removes the
        -- expansion token plus common connector words left around it.
        local startPos, endPos = lower:find(prefix.lower, 1, true)
        if startPos and startPos > 1 then
            local before = trimmed:sub(1, startPos - 1):gsub("%s+$", "")
            before = before:gsub("%s+[Oo][Ff]$", "")
            before = before:gsub("%s+[Dd][Ee]$", "")
            before = before:gsub("%s+[Dd][Aa]$", "")
            before = before:gsub("%s+[Dd][Oo]$", "")
            before = before:gsub("%s+[Dd][Oo][Ss]$", "")
            before = before:gsub("%s+[Dd][Aa][Ss]$", "")
            local after = trimmed:sub(endPos + 1):gsub("^%s+", ""):gsub("%s+$", "")
            if before ~= "" then return before end
            if after ~= "" then return after end
        end
    end
    return trimmed
end

function EL:GetCleanProfessionName(name)
    name = tostring(name or "")
    if name == "" then return "Profession" end
    local cached = cleanProfessionNameCache[name]
    if cached then return cached end
    local clean = StripProfessionExpansionPrefix(name)
    if clean == "" then clean = name end
    cleanProfessionNameCache[name] = clean
    return clean
end

function EL:ClearProfessionNameCache()
    if wipe then
        wipe(cleanProfessionNameCache)
    else
        for key in pairs(cleanProfessionNameCache) do cleanProfessionNameCache[key] = nil end
    end
end

function EL:GetProfessionAbbreviation(data)
    if not data then return "N/A" end
    -- Prefer the base/parent profession ID when available. Concentration uses
    -- expansion child profession IDs, while the abbreviation table is keyed by
    -- base profession IDs. This keeps P1/P2 labels locale-independent on CJK,
    -- Russian, German hyphenated, and other localized clients.
    local professionID = self.SafeNumber and self:SafeNumber(data.professionID or data.skillLineID or data.skillLine, nil, "profession.abbreviation.id") or nil
    local parentID = self.SafeNumber and self:SafeNumber(data.parentProfessionID, nil, "profession.abbreviation.parentID") or nil
    local lookupID = parentID and self.PROFESSION_ABBREVIATIONS and self.PROFESSION_ABBREVIATIONS[parentID] and parentID or professionID
    if lookupID and self.PROFESSION_ABBREVIATIONS and self.PROFESSION_ABBREVIATIONS[lookupID] then
        local abbr = self.PROFESSION_ABBREVIATIONS[lookupID]
        return abbr:sub(1, 1):upper() .. abbr:sub(2):lower()
    end
    -- Fallback: derive from the first word of the cleaned profession name.
    local clean = self:GetCleanProfessionName(data.professionName)
    local firstWord = clean:match("%a+") or clean
    local abbr = firstWord:sub(1, 4)
    if abbr == "" then abbr = "Prof" end
    return abbr:sub(1, 1):upper() .. abbr:sub(2):lower()
end


function EL:GetProfessionIconTexture(data)
    if not data then return nil end
    local professionID = self.SafeNumber and self:SafeNumber(data.professionID or data.skillLineID or data.skillLine, nil, "profession.icon.id") or nil
    local parentID = self.SafeNumber and self:SafeNumber(data.parentProfessionID, nil, "profession.icon.parentID") or nil
    local lookupID = parentID and self.PROFESSION_ICON_TEXTURES and self.PROFESSION_ICON_TEXTURES[parentID] and parentID or professionID
    if lookupID and self.PROFESSION_ICON_TEXTURES and self.PROFESSION_ICON_TEXTURES[lookupID] then
        return self.PROFESSION_ICON_TEXTURES[lookupID]
    end
    local clean = self:GetCleanProfessionName(data.professionName):lower()
    local nameMap = {
        alchemy = "Interface\\Icons\\Trade_Alchemy",
        blacksmithing = "Interface\\Icons\\Trade_BlackSmithing",
        enchanting = "Interface\\Icons\\Trade_Engraving",
        engineering = "Interface\\Icons\\Trade_Engineering",
        herbalism = "Interface\\Icons\\Trade_Herbalism",
        inscription = "Interface\\Icons\\INV_Inscription_Tradeskill01",
        jewelcrafting = "Interface\\Icons\\INV_Misc_Gem_01",
        leatherworking = "Interface\\Icons\\INV_Misc_ArmorKit_17",
        mining = "Interface\\Icons\\Trade_Mining",
        skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
        tailoring = "Interface\\Icons\\Trade_Tailoring",
        cooking = "Interface\\Icons\\INV_Misc_Food_15",
        fishing = "Interface\\Icons\\Trade_Fishing",
        archaeology = "Interface\\Icons\\INV_Misc_Rune_06",
    }
    if nameMap[clean] then return nameMap[clean] end
    for key, texture in pairs(nameMap) do
        if clean:find(key, 1, true) then return texture end
    end
    return nil
end

function EL:GetProfessionIconTag(data, size)
    local texture = self:GetProfessionIconTexture(data)
    if not texture then return "" end
    size = tonumber(size) or 14
    return string.format("|T%s:%d:%d:0:0|t", texture, size, size)
end

function EL:GetProfessionDisplayText(data)
    if not data then return "N/A" end
    local abbr = self:GetProfessionAbbreviation(data)
    local iconSize = (self.db and self.db.settings and self.db.settings.display and self.db.settings.display.compactMode == true) and 12 or 14
    local icon = self:GetProfessionIconTag(data, iconSize)
    if icon ~= "" then
        return icon .. " " .. abbr
    end
    return abbr
end

function EL:IsCharacterHidden(charKey)
    return self.db and self.db.settings and self.db.settings.hiddenCharacters and self.db.settings.hiddenCharacters[charKey] and true or false
end

function EL:CountHiddenCharacters()
    local hidden = self.db and self.db.settings and self.db.settings.hiddenCharacters
    local count = 0
    if type(hidden) == "table" then
        for _, value in pairs(hidden) do
            if value then count = count + 1 end
        end
    end
    return count
end

function EL:SetCharacterHidden(charKey, hidden)
    if not (self.db and self.db.settings and charKey) then return end
    self.db.settings.hiddenCharacters = self.db.settings.hiddenCharacters or {}
    self.db.settings.hiddenCharacters[charKey] = hidden and true or nil
end

function EL:RestoreHiddenCharacters()
    if not (self.db and self.db.settings) then return 0 end
    local count = self:CountHiddenCharacters()
    self.db.settings.hiddenCharacters = {}
    self:RequestUpdate()
    self:Print(count > 0 and ("Hidden characters restored: " .. tostring(count)) or "No hidden characters to restore.")
    return count
end

function EL:IsCharacterPinned(charKey)
    return self.db and self.db.settings and self.db.settings.favoriteCharacters and self.db.settings.favoriteCharacters[charKey] and true or false
end

function EL:SetCharacterPinned(charKey, pinned)
    if not (self.db and self.db.settings and charKey) then return end
    -- Storage key remains favoriteCharacters for upgrade compatibility with older saved variables.
    self.db.settings.favoriteCharacters = self.db.settings.favoriteCharacters or {}
    self.db.settings.favoriteCharacters[charKey] = pinned and true or nil
end

function EL:ToggleCharacterPinned(charKey)
    if not charKey then return false end
    local pinned = not self:IsCharacterPinned(charKey)
    self:SetCharacterPinned(charKey, pinned)
    self:RequestUpdate()
    local char = self.db and self.db.characters and self.db.characters[charKey]
    local displayName = (char and (char.displayName or char.name)) or charKey
    self:Print((pinned and "Pinned: " or "Unpinned: ") .. tostring(displayName))
    return pinned
end

function EL:ResetPinnedCharacters()
    if not (self.db and self.db.settings) then return 0 end
    local pinned = self.db.settings.favoriteCharacters
    local count = 0
    if type(pinned) == "table" then
        for _ in pairs(pinned) do
            count = count + 1
        end
    end
    self.db.settings.favoriteCharacters = {}
    self:RequestUpdate()
    self:Print(count > 0 and ("Pinned characters reset: " .. tostring(count)) or "No pinned characters to reset.")
    return count
end

-- Backward-compatible aliases for older code paths and saved-variable wording.
function EL:IsCharacterFavorite(charKey) return self:IsCharacterPinned(charKey) end
function EL:SetCharacterFavorite(charKey, favorite) return self:SetCharacterPinned(charKey, favorite) end
function EL:ToggleCharacterFavorite(charKey) return self:ToggleCharacterPinned(charKey) end

function EL:ResetCharacterData(charKey, silent)
    if not (self.db and charKey) then return false end
    local char = self.db and self.db.characters and self.db.characters[charKey]
    local displayName = (char and (char.displayName or char.name)) or charKey

    if self.db.characters then
        self.db.characters[charKey] = nil
        if self.InvalidateCharacterRows then self:InvalidateCharacterRows() end
    end
    if self.db.settings and self.db.settings.favoriteCharacters then
        self.db.settings.favoriteCharacters[charKey] = nil
    end

    if self.db.resources then
        if self.db.resources.mulch then
            self.db.resources.mulch[charKey] = nil
        end
        if self.db.resources.concentration then
            for resourceKey, data in pairs(self.db.resources.concentration) do
                if data and data.charKey == charKey then
                    self.db.resources.concentration[resourceKey] = nil
                end
            end
            if self.InvalidateConcentrationIndex then self:InvalidateConcentrationIndex() end
        end
        if self.db.resources.professions then
            self.db.resources.professions[charKey] = nil
            if self.InvalidateProfessionLookup then self:InvalidateProfessionLookup() end
        end
        if self.db.resources.moxie then
            self.db.resources.moxie[charKey] = nil
        end
        if self.db.resources.professionCooldowns then
            self.db.resources.professionCooldowns[charKey] = nil
            self._hasCooldownColumnData = nil
        end
    end

    if self.db.settings and self.db.settings.hiddenCharacters then
        self.db.settings.hiddenCharacters[charKey] = nil
    end

    if not silent then
        self:RequestUpdate()
        self:Print("Removed EmberLedger data for: " .. tostring(displayName))
    end
    return true
end

function EL:RemoveHiddenCharacterData()
    if not (self.db and self.db.settings and type(self.db.settings.hiddenCharacters) == "table") then
        if self.Print then self:Print("No hidden character data to remove.") end
        return 0
    end

    local keys = {}
    for charKey, hidden in pairs(self.db.settings.hiddenCharacters) do
        if hidden then keys[#keys + 1] = charKey end
    end

    local removed = 0
    for _, charKey in ipairs(keys) do
        if self:ResetCharacterData(charKey, true) then
            removed = removed + 1
        end
    end

    if self.RequestUpdate then self:RequestUpdate() end
    if self.Print then
        self:Print(removed > 0 and ("Removed hidden character data: " .. tostring(removed)) or "No hidden character data to remove.")
    end
    return removed
end

function EL:GetEffectiveMaxQuantity(maxQuantity, thresholdOverride)
    local maxQ = tonumber(maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
    if maxQ <= 0 then maxQ = self.CONCENTRATION_MAX_DEFAULT end

    local threshold = tonumber(thresholdOverride) or (self.GetConcentrationThreshold and self:GetConcentrationThreshold())
    if threshold and threshold > 0 then
        return math.max(1, math.min(maxQ, threshold))
    end

    return math.max(1, maxQ)
end

function EL:GetConcentrationColor(quantity, maxQuantity, thresholdOverride)
    local maxQ = self:GetEffectiveMaxQuantity(maxQuantity, thresholdOverride)
    local q = tonumber(quantity) or 0
    local percentage = math.max(0, math.min(100, (q / maxQ) * 100))
    local r, g, b

    -- Keep the climb darker and reserve bright green for the ready state.
    if percentage >= 100 then
        -- Full/ready: bright pop
        r, g, b = 0.18, 1.00, 0.28
    elseif percentage >= 80 then
        -- Almost ready: restrained dark green
        r, g, b = 0.18, 0.62, 0.20
    elseif percentage >= 50 then
        -- Mid range: muted olive/yellow
        r, g, b = 0.55, 0.50, 0.16
    elseif percentage >= 30 then
        -- Low-mid range: darker amber
        r, g, b = 0.62, 0.34, 0.12
    else
        -- Low range: darker red
        r, g, b = 0.58, 0.16, 0.14
    end

    return r, g, b, percentage
end


function EL:GetMulchCountdownColor(remaining)
    if remaining == nil then return 0.7, 0.7, 0.7 end
    local duration = 3600
    local pct = 1 - math.max(0, math.min(1, (tonumber(remaining) or 0) / duration))
    -- Red when just used, amber during cooldown, green when ready.
    if pct < 0.5 then
        local t = pct * 2
        return 0.95, 0.18 + (0.52 * t), 0.08
    end
    local t = (pct - 0.5) * 2
    return 0.95 * (1 - t) + 0.22 * t, 0.70 * (1 - t) + 1.00 * t, 0.08 * (1 - t) + 0.22 * t
end

function EL:FormatCountdown(seconds)
    return FormatCompactDuration(seconds, true)
end


function EL:IsTrackingColumnVisible(key)
    -- UI.lua replaces this fallback with the full column-visibility rules.
    -- Keep a safe Core implementation so sort requests made before UI setup
    -- never error or leave a disabled-column sort key behind.
    if key == "prof" then key = "prof1" end
    if key == "conc" then key = "conc1" end
    if key == "character" then return true end
    return true
end

function EL:IsSortColumnAvailable(key)
    if key == "prof" then key = "prof1" end
    if key == "conc" then key = "conc1" end
    if key == "character" then return true end
    if type(self.IsTrackingColumnVisible) ~= "function" then return true end
    local ok, visible = pcall(self.IsTrackingColumnVisible, self, key)
    if not ok then
        if self.Debug then self:Debug("Column visibility check failed for sort key " .. tostring(key) .. ": " .. tostring(visible)) end
        return true
    end
    return visible ~= false
end

function EL:GetSortSettings()
    self.db.settings.sort = self.db.settings.sort or { key = "character", ascending = true }
    self.db.settings.sort.key = self.db.settings.sort.key or "character"
    if self.db.settings.sort.key == "full" then self.db.settings.sort.key = "character" end
    if self.db.settings.sort.key == "prof" then self.db.settings.sort.key = "prof1" end
    if self.db.settings.sort.key == "conc" then self.db.settings.sort.key = "conc1" end
    if self.db.settings.sort.ascending == nil then self.db.settings.sort.ascending = true end
    return self.db.settings.sort
end

function EL:SetSortKey(key)
    if not key then return end
    if key == "prof" then key = "prof1" end
    if key == "conc" then key = "conc1" end
    if self.IsSortColumnAvailable and not self:IsSortColumnAvailable(key) then key = "character" end
    local sort = self:GetSortSettings()
    if sort.key == key then
        sort.ascending = not sort.ascending
    else
        sort.key = key
        sort.ascending = true
        if key == "conc" or key == "conc1" or key == "conc2" then sort.ascending = false end
    end
    self:RequestUpdate()
end

function EL:GetMulchSortValue(charKey, now)
    local data = self.db and self.db.resources and self.db.resources.mulch and self.db.resources.mulch[charKey]
    if not self:HasImbuedMulchAccess(data) then return nil end
    local readyAt = self.SafeNumber and self:SafeNumber(data.readyAt, 0, "mulch.sort.readyAt") or (tonumber(data.readyAt) or 0)
    return math.max(0, readyAt - (now or time()))
end

function EL:GetDashboardSortValue(entry, key, now, cache)
    if not entry then return nil end
    now = now or time()
    local charKey, char = entry.key, entry.char
    if not charKey then return nil end
    if key == "character" then
        return cache and cache.displayNameLower or tostring(self:GetCharacterDisplayName(char, charKey)):lower()
    elseif key == "prof" or key == "prof1" then
        local slot = cache and cache.slots and cache.slots[1]
        local prof = slot and slot.prof or self:GetDashboardProfessionData(charKey, 1)
        return prof and self:GetProfessionAbbreviation(prof):lower() or nil
    elseif key == "conc" or key == "conc1" then
        local slot = cache and cache.slots and cache.slots[1]
        local conc = slot and slot.conc or select(2, self:GetDashboardProfessionData(charKey, 1))
        return conc and (self:GetEstimatedConcentration(conc, now) or 0) or nil
    elseif key == "prof2" then
        local slot = cache and cache.slots and cache.slots[2]
        local prof = slot and slot.prof or self:GetDashboardProfessionData(charKey, 2)
        return prof and self:GetProfessionAbbreviation(prof):lower() or nil
    elseif key == "conc2" then
        local slot = cache and cache.slots and cache.slots[2]
        local conc = slot and slot.conc or select(2, self:GetDashboardProfessionData(charKey, 2))
        return conc and (self:GetEstimatedConcentration(conc, now) or 0) or nil
    elseif key == "full" then
        local conc = cache and cache.bestConc or self:GetBestConcentrationForCharacter(charKey, now)
        if not conc then return nil end
        local maxQ = tonumber(conc.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
        local q = self:GetEstimatedConcentration(conc, now) or 0
        if q >= maxQ then return 0 end
        return math.ceil((maxQ - q) / self.CONCENTRATION_RATE_PER_HOUR * 3600)
    elseif key == "forecast" then
        local conc = cache and cache.bestConc or self:GetBestConcentrationForCharacter(charKey, now)
        if not conc then return nil end
        local maxQ = tonumber(conc.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
        local q = self:GetEstimatedConcentration(conc, now) or 0
        local threshold = self:GetProfessionConcentrationThreshold(conc)
        if q >= threshold then return 0 end
        return math.ceil((threshold - q) / self.CONCENTRATION_RATE_PER_HOUR * 3600)
    elseif key == "moxie" then
        return self:GetMoxieSortValue(charKey, cache and cache.moxieEntries)
    elseif key == "mulch" then
        return self:GetMulchSortValue(charKey, now)
    elseif key == "cooldown" then
        if type(self.GetProfessionCooldownSortValue) ~= "function" then return nil end
        local ok, value = pcall(self.GetProfessionCooldownSortValue, self, charKey, cache and cache.profEntries)
        if ok then return value end
        if self.db and self.db.settings and self.db.settings.debug and self.Print then
            self:Print("Cooldown sort unavailable: " .. tostring(value))
        end
        return nil
    end
    return cache and cache.displayNameLower or tostring(self:GetCharacterDisplayName(char, charKey)):lower()
end

function EL:SortDashboardRows(rows, dashboardLookups, now)
    if type(rows) ~= "table" then return end

    local profileStage = self.ProfileStart and self.ProfileStop and self:IsProfilingEnabled()
    local function StartSortStage(label)
        if not profileStage then return nil end
        return self:ProfileStart(label)
    end
    local function StopSortStage(label, started)
        if started then self:ProfileStop(label, started) end
    end

    local sort = self:GetSortSettings()
    local key = sort.key or "character"
    if key == "prof" then key = "prof1" end
    if key == "conc" then key = "conc1" end
    if self.IsSortColumnAvailable and not self:IsSortColumnAvailable(key) then
        key = "character"
        sort.key = "character"
        sort.ascending = true
    end
    local ascending = sort.ascending ~= false
    now = now or time()
    local clean = {}
    local sortCache = dashboardLookups and dashboardLookups.rowCache or {}
    if dashboardLookups then dashboardLookups.rowCache = sortCache end
    local concentrationLookup = dashboardLookups and dashboardLookups.concentrationLookup
    local professionLookup = dashboardLookups and dashboardLookups.professionLookup

    local function getSortCache(charKey, displayNameLower)
        if not charKey then return nil end
        local cached = sortCache[charKey]
        if cached then
            if displayNameLower and not cached.displayNameLower then cached.displayNameLower = displayNameLower end
            return cached
        end
        local concLookup = concentrationLookup and concentrationLookup[charKey]
        local concEntries = concLookup and concLookup.entries or self:GetConcentrationEntriesForCharacter(charKey)
        local profEntries = professionLookup and professionLookup[charKey] or self:GetProfessionEntriesForCharacter(charKey)
        if (not profEntries or #profEntries == 0) and concEntries then
            profEntries = concEntries
        end
        local slots = self:GetDashboardProfessionSlots(charKey, profEntries, concEntries)
        local moxieEntries = self:GetMoxieEntriesForCharacter(charKey, profEntries)
        local bestConc = concLookup and concLookup.best or nil
        if not bestConc then
            local bestQty
            for _, conc in ipairs(concEntries or {}) do
                local qty = self:GetEstimatedConcentration(conc, now) or 0
                if not bestConc or qty > (bestQty or -1) then
                    bestConc = conc
                    bestQty = qty
                end
            end
        end
        cached = { concEntries = concEntries, profEntries = profEntries, slots = slots, moxieEntries = moxieEntries, bestConc = bestConc, displayNameLower = displayNameLower }
        sortCache[charKey] = cached
        return cached
    end

    local function isBadNumber(v)
        return type(v) == "number" and v ~= v
    end

    local function normalizeSortValue(v)
        if v == nil or isBadNumber(v) then
            return nil, nil
        end
        if type(v) == "number" then
            return "number", v
        end
        return "string", tostring(v):lower()
    end

    local sortStageProfile = StartSortStage("SortDashboardRows:WrapRows")
    for i, entry in ipairs(rows) do
        if type(entry) == "table" and entry.key then
            local displayNameLower = entry.displayNameLower or tostring(self:GetCharacterDisplayName(entry.char, entry.key)):lower()
            local cache = getSortCache(entry.key, displayNameLower)
            local valueType, value
            if key == "character" then
                valueType, value = "string", displayNameLower
            else
                local rawValue = self:GetDashboardSortValue(entry, key, now, cache)
                valueType, value = normalizeSortValue(rawValue)
            end
            table.insert(clean, {
                row = entry,
                originalIndex = i,
                valueType = valueType,
                value = value,
                name = displayNameLower,
                key = tostring(entry.key or ""),
                pinned = self:IsCharacterPinned(entry.key),
                current = false,
            })
        end
    end
    StopSortStage("SortDashboardRows:WrapRows", sortStageProfile)

    local display = self.db and self.db.settings and self.db.settings.display or {}
    local showCurrentCharacterFirst = display.showCurrentCharacterFirst == true
    local currentCharKey = nil
    if showCurrentCharacterFirst then
        currentCharKey = self.currentCharKey or (self.GetCharacterKey and self:GetCharacterKey())
    end
    if showCurrentCharacterFirst and currentCharKey then
        for _, wrapped in ipairs(clean) do
            wrapped.current = wrapped.key == tostring(currentCharKey)
        end
    end

    CORE_SORT_CONTEXT.showCurrentCharacterFirst = showCurrentCharacterFirst
    CORE_SORT_CONTEXT.showPinnedFirst = display.showPinnedFirst ~= false
    CORE_SORT_CONTEXT.ascending = ascending
    sortStageProfile = StartSortStage("SortDashboardRows:Sort")
    table.sort(clean, SortWrappedCharacterRows)
    StopSortStage("SortDashboardRows:Sort", sortStageProfile)

    sortStageProfile = StartSortStage("SortDashboardRows:UnwrapRows")
    wipe(rows)
    for i, wrapped in ipairs(clean) do
        rows[i] = wrapped.row
    end
    StopSortStage("SortDashboardRows:UnwrapRows", sortStageProfile)
end

function EL:InvalidateConcentrationIndex()
    self._concentrationByCharKey = nil
end

function EL:GetConcentrationIndex()
    if self._concentrationByCharKey then return self._concentrationByCharKey end
    local byChar = {}
    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        local charKey = data and data.charKey
        if charKey then
            local list = byChar[charKey]
            if not list then
                list = {}
                byChar[charKey] = list
            end
            list[#list + 1] = data
        end
    end
    for _, list in pairs(byChar) do
        table.sort(list, SortConcentrationEntriesForCharacter)
    end
    self._concentrationByCharKey = byChar
    return byChar
end

function EL:GetConcentrationEntriesForCharacter(charKey)
    if not charKey then return {} end
    local index = self:GetConcentrationIndex()
    return (index and index[charKey]) or {}
end

function EL:GetBestConcentrationForCharacter(charKey, now)
    local best
    now = now or time()
    for _, data in ipairs(self:GetConcentrationEntriesForCharacter(charKey) or {}) do
        local qty = self:GetEstimatedConcentration(data, now)
        if not best or qty > (self:GetEstimatedConcentration(best, now) or 0) then
            best = data
        end
    end
    return best
end

function EL:GetReadyConcentrationCountForCharacter(charKey, threshold, now)
    if not charKey then return 0 end
    threshold = tonumber(threshold)
    now = now or time()

    local count = 0
    for _, data in ipairs(self:GetConcentrationEntriesForCharacter(charKey) or {}) do
        local qty = self:GetEstimatedConcentration(data, now) or 0
        local required = self:GetProfessionConcentrationThreshold(data) or threshold or self.CONCENTRATION_THRESHOLD_DEFAULT or 900
        if qty >= required then
            count = count + 1
        end
    end

    return count
end

function EL:GetHighestConcentrationSummary()
    local best
    local now = time()
    for charKey, entries in pairs(self:GetConcentrationIndex() or {}) do
        if charKey and not self:IsCharacterHidden(charKey) then
            local char = self.db and self.db.characters and self.db.characters[charKey]
            for _, data in ipairs(entries or {}) do
                if data then
                    local qty = self:GetEstimatedConcentration(data, now) or 0
                    if not best or qty > best.quantity then
                        best = {
                            charKey = charKey,
                            displayName = (char and char.name) or data.charName or "Unknown",
                            quantity = qty,
                            maxQuantity = data.maxQuantity or self.CONCENTRATION_MAX_DEFAULT,
                            professionName = data.professionName,
                            professionID = data.professionID,
                            abbrev = self:GetProfessionAbbreviation(data),
                        }
                    end
                end
            end
        end
    end
    return best
end


function EL:GetConcentrationThreshold()
    local alerts = self.db and self.db.settings and self.db.settings.alerts
    return tonumber(alerts and alerts.concentrationThreshold) or self.CONCENTRATION_THRESHOLD_DEFAULT or 900
end

function EL:GetConcentrationThresholdProfessionID(profOrData)
    if type(profOrData) ~= "table" then return tonumber(profOrData) end
    return tonumber(profOrData.parentProfessionID)
        or tonumber(profOrData.professionID)
        or tonumber(profOrData.skillLineID)
        or tonumber(profOrData.skillLine)
end

function EL:GetProfessionConcentrationThreshold(profOrID)
    local id = self:GetConcentrationThresholdProfessionID(profOrID)
    local alerts = self.db and self.db.settings and self.db.settings.alerts
    local overrides = alerts and alerts.professionThresholds
    local value = id and type(overrides) == "table" and tonumber(overrides[id]) or nil
    if value and value > 0 then
        return math.max(1, math.min(self.CONCENTRATION_MAX_DEFAULT or 1000, math.floor(value + 0.5))), true
    end
    return self:GetConcentrationThreshold(), false
end

function EL:SetProfessionConcentrationThreshold(profOrID, value)
    local id = self:GetConcentrationThresholdProfessionID(profOrID)
    if not id then return false end
    self.db.settings.alerts.professionThresholds = self.db.settings.alerts.professionThresholds or {}
    local numeric = tonumber(value)
    if not numeric or numeric <= 0 then
        self.db.settings.alerts.professionThresholds[id] = nil
    else
        self.db.settings.alerts.professionThresholds[id] = math.max(1, math.min(self.CONCENTRATION_MAX_DEFAULT or 1000, math.floor(numeric + 0.5)))
    end
    self:RequestUpdate()
    return true
end

function EL:GetConcentrationReadyCount(threshold, now)
    threshold = tonumber(threshold)
    now = now or time()
    local count = 0
    for charKey, entries in pairs(self:GetConcentrationIndex() or {}) do
        if charKey and not self:IsCharacterHidden(charKey) then
            for _, data in ipairs(entries or {}) do
                local qty = self:GetEstimatedConcentration(data, now) or 0
                local required = self:GetProfessionConcentrationThreshold(data) or threshold or self.CONCENTRATION_THRESHOLD_DEFAULT or 900
                if qty >= required then
                    count = count + 1
                    break
                end
            end
        end
    end
    return count
end


function EL:GetConcentrationReadyEntries(threshold, limit)
    threshold = tonumber(threshold)
    local now = time()
    local entries = {}

    for charKey, concEntries in pairs(self:GetConcentrationIndex() or {}) do
        if charKey and not self:IsCharacterHidden(charKey) then
            local char = self.db and self.db.characters and self.db.characters[charKey]
            for _, data in ipairs(concEntries or {}) do
                local qty = self:GetEstimatedConcentration(data, now) or 0
                local required = self:GetProfessionConcentrationThreshold(data) or threshold or self.CONCENTRATION_THRESHOLD_DEFAULT or 900
                if qty >= required then
                    entries[#entries + 1] = {
                        type = "concentration",
                        charKey = charKey,
                        displayName = (char and (char.displayName or char.name)) or data.charName or "Unknown",
                        professionName = data.professionName or "Profession",
                        abbrev = self:GetProfessionAbbreviation(data),
                        quantity = qty,
                        maxQuantity = data.maxQuantity or self.CONCENTRATION_MAX_DEFAULT,
                        threshold = required,
                    }
                end
            end
        end
    end

    table.sort(entries, SortConcentrationReadyEntries)

    if limit and #entries > limit then
        local trimmed = {}
        for i = 1, tonumber(limit) or #entries do trimmed[i] = entries[i] end
        return trimmed, #entries
    end

    return entries, #entries
end

function EL:GetMulchStatus(now)
    now = now or time()
    local seen = {}
    local readyByChar = {}
    local readyCount = 0
    local nextSummary = nil

    for _, data in pairs(self.db and self.db.resources and self.db.resources.mulch or {}) do
        local charKey = data and data.charKey
        if charKey and not self:IsCharacterHidden(charKey) and self:HasImbuedMulchAccess(data) then
            local readyAt = self.SafeNumber and self:SafeNumber(data.readyAt, 0, "mulch.status.readyAt") or (tonumber(data.readyAt) or 0)
            local remain = math.max(0, readyAt - now)
            if readyAt <= now and not seen[charKey] then
                seen[charKey] = true
                readyByChar[charKey] = true
                readyCount = readyCount + 1
            end
            if not nextSummary or remain < nextSummary.remaining then
                local char = self.db and self.db.characters and self.db.characters[charKey]
                nextSummary = {
                    charKey = charKey,
                    displayName = (char and char.name) or data.charName or "Unknown",
                    remaining = remain,
                    readyAt = readyAt,
                }
            end
        end
    end

    return { readyCount = readyCount, next = nextSummary, readyByChar = readyByChar }
end

function EL:GetMulchReadyCount(now)
    local status = self:GetMulchStatus(now)
    return status and status.readyCount or 0
end

function EL:GetMulchReadyEntries(limit)
    local now = time()
    local seen = {}
    local entries = {}

    for _, data in pairs(self.db and self.db.resources and self.db.resources.mulch or {}) do
        local charKey = data and data.charKey
        if charKey and not seen[charKey] and not self:IsCharacterHidden(charKey) and self:HasImbuedMulchAccess(data) then
            local readyAt = self.SafeNumber and self:SafeNumber(data.readyAt, 0, "mulch.ready.readyAt") or (tonumber(data.readyAt) or 0)
            if readyAt <= now then
                seen[charKey] = true
                local char = self.db and self.db.characters and self.db.characters[charKey]
                entries[#entries + 1] = {
                    type = "mulch",
                    charKey = charKey,
                    displayName = (char and (char.displayName or char.name)) or data.charName or "Unknown",
                    itemName = data.itemName or "Imbued Mulch",
                }
            end
        end
    end

    table.sort(entries, SortMulchReadyEntries)

    if limit and #entries > limit then
        local trimmed = {}
        for i = 1, tonumber(limit) or #entries do trimmed[i] = entries[i] end
        return trimmed, #entries
    end

    return entries, #entries
end

function EL:GetNeedsAttentionEntries(limit)
    local combined = {}
    local concEntries = self:GetConcentrationReadyEntries(nil)
    local mulchEntries = self:GetMulchReadyEntries()

    for _, entry in ipairs(concEntries or {}) do
        combined[#combined + 1] = entry
    end
    for _, entry in ipairs(mulchEntries or {}) do
        combined[#combined + 1] = entry
    end

    table.sort(combined, SortAttentionEntries)

    if limit and #combined > limit then
        local trimmed = {}
        for i = 1, tonumber(limit) or #combined do trimmed[i] = combined[i] end
        return trimmed, #combined
    end

    return combined, #combined
end


function EL:DoesCharacterNeedAttention(charKey, threshold, now)
    if not charKey or self:IsCharacterHidden(charKey) then return false end
    local fallbackThreshold = tonumber(threshold) or (self.db and self.db.settings and self.db.settings.alerts and self.db.settings.alerts.concentrationThreshold) or self.CONCENTRATION_THRESHOLD_DEFAULT or 900
    now = now or time()

    for _, data in ipairs(self:GetConcentrationEntriesForCharacter(charKey) or {}) do
        local entryThreshold = fallbackThreshold
        if self.GetProfessionConcentrationThreshold then
            local rawEntryThreshold = self:GetProfessionConcentrationThreshold(data)
            entryThreshold = tonumber(rawEntryThreshold) or fallbackThreshold
        end
        local qty = self:GetEstimatedConcentration(data, now) or 0
        if qty >= entryThreshold then
            return true
        end
    end

    local mulchData = self.db and self.db.resources and self.db.resources.mulch and self.db.resources.mulch[charKey]
    if self:HasImbuedMulchAccess(mulchData) then
        local readyAt = self.SafeNumber and self:SafeNumber(mulchData.readyAt, 0, "mulch.readyAt") or (tonumber(mulchData.readyAt) or 0)
        if readyAt <= now then
            return true
        end
    end

    return false
end

function EL:GetEstimatedConcentration(data, now)
    if type(data) ~= "table" then return nil end
    local fallbackNow = time()
    local rawNow = now ~= nil and now or fallbackNow
    now = self.SafeNumber and self:SafeNumber(rawNow, fallbackNow, "GetEstimatedConcentration.now") or (tonumber(rawNow) or fallbackNow)
    local maxQ = self.SafeNumber and self:SafeNumber(data.maxQuantity, self.CONCENTRATION_MAX_DEFAULT, "concentration.maxQuantity") or (tonumber(data.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT)
    local q = self.SafeNumber and self:SafeNumber(data.quantity, 0, "concentration.quantity") or (tonumber(data.quantity) or 0)
    local last = self.SafeNumber and self:SafeNumber(data.lastUpdate, now, "concentration.lastUpdate") or (tonumber(data.lastUpdate) or now)
    local rate = self.SafeNumber and self:SafeNumber(self.CONCENTRATION_RATE_PER_HOUR, 10, "concentration.rate") or (tonumber(self.CONCENTRATION_RATE_PER_HOUR) or 10)

    maxQ = math.max(0, maxQ)
    q = math.max(0, math.min(maxQ, q))
    if q >= maxQ then return maxQ end

    local gained = math.floor(math.max(0, now - last) * (rate / 3600))
    return math.min(maxQ, q + gained)
end


function EL:GetConcentrationForecastText(data, threshold, now)
    if not data then return "N/A" end
    now = now or time()
    threshold = self:GetProfessionConcentrationThreshold(data) or tonumber(threshold) or self:GetConcentrationThreshold()
    local maxQ = self.SafeNumber and self:SafeNumber(data.maxQuantity, self.CONCENTRATION_MAX_DEFAULT, "forecast.maxQuantity") or (tonumber(data.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT)
    local q = self:GetEstimatedConcentration(data, now) or 0
    local rate = self.SafeNumber and self:SafeNumber(self.CONCENTRATION_RATE_PER_HOUR, 10, "forecast.rate") or (tonumber(self.CONCENTRATION_RATE_PER_HOUR) or 10)

    if q >= maxQ then
        return "Full"
    end

    if q >= threshold then
        return "Ready"
    end

    local readySeconds = math.ceil((threshold - q) / math.max(1, rate) * 3600)
    return self:FormatDuration(readySeconds)
end

function EL:GetConcentrationFullIn(data, now)
    if not data then return "N/A" end
    now = now or time()
    local maxQ = self.SafeNumber and self:SafeNumber(data.maxQuantity, self.CONCENTRATION_MAX_DEFAULT, "fullIn.maxQuantity") or (tonumber(data.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT)
    local q = self:GetEstimatedConcentration(data, now) or 0
    if q >= maxQ then return "Full" end
    local missing = maxQ - q
    local rate = self.SafeNumber and self:SafeNumber(self.CONCENTRATION_RATE_PER_HOUR, 10, "fullIn.rate") or (tonumber(self.CONCENTRATION_RATE_PER_HOUR) or 10)
    local seconds = math.ceil(missing / math.max(1, rate) * 3600)
    return self:FormatDuration(seconds)
end

function EL:HasImbuedMulchAccess(data)
    if type(data) ~= "table" then return false end
    -- Legacy compatibility: only trust the stricter confirmation written by Modules/Mulch.lua.
    -- Older saved values could mark generic Herbalism characters as mulch-ready.
    local version = self.SafeNumber and self:SafeNumber(data.confirmationVersion, 0, "mulch.confirmationVersion") or (tonumber(data.confirmationVersion) or 0)
    return data.confirmedImbuedMulchAccess == true and version == 2
end


function EL:CopperToSilver(copper)
    copper = tonumber(copper) or 0
    if copper <= 0 then return 0 end
    return math.floor((copper + 50) / 100)
end

local MONEY_GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:10:10:1:0|t"
local MONEY_SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:10:10:1:0|t"

local function FormatNumberWithCommas(value)
    local formatted = tostring(math.floor(tonumber(value) or 0))
    while true do
        local nextValue, changed = formatted:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
        formatted = nextValue
        if changed == 0 then break end
    end
    return formatted
end

function EL:FormatMoneyText(silver)
    silver = math.floor(tonumber(silver) or 0)
    local negative = silver < 0
    silver = math.abs(silver)
    local gold = math.floor(silver / 100)
    local sil = silver % 100
    local prefix = negative and "-" or ""
    if sil == 0 then
        return string.format("%s%s %s", prefix, FormatNumberWithCommas(gold), MONEY_GOLD_ICON)
    end
    if gold == 0 then
        -- Avoid showing "0 [gold]" for sub-1g amounts.
        return string.format("%s%02d %s", prefix, sil, MONEY_SILVER_ICON)
    end
    return string.format("%s%s %s %02d %s", prefix, FormatNumberWithCommas(gold), MONEY_GOLD_ICON, sil, MONEY_SILVER_ICON)
end

function EL:FormatMoneyRateText(silver)
    silver = math.floor(tonumber(silver) or 0)
    local negative = silver < 0
    silver = math.abs(silver)
    local gold = silver / 100
    local prefix = negative and "-" or ""

    if gold >= 1000000 then
        return string.format("%s%.1fm", prefix, gold / 1000000):gsub("%.0m$", "m")
    elseif gold >= 1000 then
        return string.format("%s%.1fk", prefix, gold / 1000):gsub("%.0k$", "k")
    elseif gold >= 100 then
        return string.format("%s%d", prefix, math.floor(gold + 0.5))
    elseif gold >= 10 then
        return string.format("%s%.1f", prefix, gold):gsub("%.0$", "")
    else
        return string.format("%s%.2f", prefix, gold):gsub("0$", ""):gsub("%.$", "")
    end
end

function EL:IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    elseif IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end
    return false
end

function EL:GetAuctionatorUnitPriceSilver(itemID)
    if not itemID or not Auctionator then return 0 end
    if Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID then
        local ok, copperPrice = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, self.name or "EmberLedger", itemID)
        if ok and type(copperPrice) == "number" and copperPrice > 0 then
            return self:CopperToSilver(copperPrice)
        end
    end
    if Auctionator.Database and Auctionator.Database.GetPrice then
        local ok, dbCopperPrice = pcall(Auctionator.Database.GetPrice, Auctionator.Database, tostring(itemID))
        if ok and type(dbCopperPrice) == "number" and dbCopperPrice > 0 then
            return self:CopperToSilver(dbCopperPrice)
        end
    end
    return 0
end

function EL:GetTSMUnitPriceSilver(itemID)
    if not itemID or not TSM_API or type(TSM_API.GetCustomPriceValue) ~= "function" then return 0 end
    local copperPrice = TSM_API.GetCustomPriceValue("dbmarket", "i:" .. tostring(itemID))
    if type(copperPrice) == "number" and copperPrice > 0 then
        return self:CopperToSilver(copperPrice)
    end
    return 0
end

local VALID_PRICING_SOURCES = {
    auto = true,
    tsm = true,
    auctionator = true,
    fallback = true,
    -- Legacy saved values from earlier EmberLedger builds.
    TSM = "tsm",
    Auctionator = "auctionator",
}

function EL:GetSessionPricingSource()
    local settings = self.db and self.db.settings and self.db.settings.session
    local source = settings and settings.pricingSource or "auto"
    local mapped = VALID_PRICING_SOURCES[source]
    if mapped == true then return source end
    if type(mapped) == "string" then
        if settings then settings.pricingSource = mapped end
        return mapped
    end
    if settings then settings.pricingSource = "auto" end
    return "auto"
end

function EL:SetSessionPricingSource(source)
    if not VALID_PRICING_SOURCES[source] or VALID_PRICING_SOURCES[source] ~= true then
        source = "auto"
    end
    self.db.settings.session = self.db.settings.session or {}
    self.db.settings.session.pricingSource = source
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
    if self.RefreshSessionWindow then self:RefreshSessionWindow() end
    if self.RequestUpdate then self:RequestUpdate() end
    if self.Print then
        self:Print("Item value source set to " .. (self:GetSessionPricingSourceLabel(source) or "Auto"))
    end
end

function EL:GetSessionPricingSourceLabel(source)
    source = source or (self.GetSessionPricingSource and self:GetSessionPricingSource()) or "auto"
    if source == "auto" then return "Auto" end
    if source == "tsm" then return "TSM" end
    if source == "auctionator" then return "Auctionator" end
    if source == "fallback" then return "Fallback only" end
    return "Auto"
end

function EL:GetUnitPriceSilver(itemID)
    local source = self:GetSessionPricingSource()
    if source == "fallback" then return 0 end
    if source == "tsm" then
        return self:GetTSMUnitPriceSilver(itemID)
    end
    if source == "auctionator" then
        return self:GetAuctionatorUnitPriceSilver(itemID)
    end

    -- Auto prefers TSM when available because profession-focused users often
    -- treat TSM as their authoritative market source, then falls back to Auctionator.
    local tsm = self:GetTSMUnitPriceSilver(itemID)
    if tsm and tsm > 0 then return tsm end
    return self:GetAuctionatorUnitPriceSilver(itemID)
end

function EL:GetActivePricingSourceLabel()
    local source = self:GetSessionPricingSource()
    if source == "fallback" then return "Fallback only" end
    if source == "tsm" then
        if self:IsAddOnLoaded("TradeSkillMaster") and TSM_API then return "TSM" end
        return "TSM selected, not ready"
    end
    if source == "auctionator" then
        if self:IsAddOnLoaded("Auctionator") and Auctionator and ((Auctionator.API and Auctionator.API.v1) or Auctionator.Database) then return "Auctionator" end
        return "Auctionator selected, not ready"
    end
    if self:IsAddOnLoaded("TradeSkillMaster") and TSM_API then return "Auto: TSM" end
    if self:IsAddOnLoaded("Auctionator") and Auctionator and ((Auctionator.API and Auctionator.API.v1) or Auctionator.Database) then return "Auto: Auctionator" end
    return "Auto: fallback"
end

function EL:GetPricingWarning()
    local source = self:GetSessionPricingSource()
    if source == "fallback" then return nil end
    if source == "tsm" then
        if not self:IsAddOnLoaded("TradeSkillMaster") then return "TSM missing" end
        if not TSM_API then return "TSM not ready" end
        return nil
    end
    if source == "auctionator" then
        if not self:IsAddOnLoaded("Auctionator") then return "Auctionator missing" end
        if not Auctionator or not ((Auctionator.API and Auctionator.API.v1) or Auctionator.Database) then return "Auctionator not ready" end
        return nil
    end
    if self:IsAddOnLoaded("TradeSkillMaster") and TSM_API then return nil end
    if self:IsAddOnLoaded("Auctionator") and Auctionator and ((Auctionator.API and Auctionator.API.v1) or Auctionator.Database) then return nil end
    return "No pricing addon detected"
end

function EL:GetSessionDB()
    self.db.session = self.db.session or {}
    local s = self.db.session
    s.totalSilver = tonumber(s.totalSilver) or 0
    s.rawGoldGainedSilver = tonumber(s.rawGoldGainedSilver) or 0
    s.goldSpentSilver = tonumber(s.goldSpentSilver) or 0
    s.lastMoneyCopper = tonumber(s.lastMoneyCopper) or (GetMoney and GetMoney()) or 0
    s.items = type(s.items) == "table" and s.items or {}
    s.recent = type(s.recent) == "table" and s.recent or {}
    s.pendingChatLoot = type(s.pendingChatLoot) == "table" and s.pendingChatLoot or {}
    s.trustedMailItems = type(s.trustedMailItems) == "table" and s.trustedMailItems or {}
    s.pendingCraftedItems = type(s.pendingCraftedItems) == "table" and s.pendingCraftedItems or {}
    s.lastBagCounts = type(s.lastBagCounts) == "table" and s.lastBagCounts or {}
    s.categoryTotals = type(s.categoryTotals) == "table" and s.categoryTotals or {}
    if s.isPaused == nil then s.isPaused = false end
    s.priorDuration = tonumber(s.priorDuration) or 0
    s.sessionStartUptime = tonumber(s.sessionStartUptime) or GetTime()
    s.sessionStartTime = tonumber(s.sessionStartTime) or time()
    s.sessionID = s.sessionID
    return s
end

function EL:StartFreshSessionOnLogin()
    -- Runtime-only guard: reset once per login/reload, not every PLAYER_ENTERING_WORLD fire.
    if self.sessionResetThisLogin then return end
    self.sessionResetThisLogin = true

    self.db.session = {
        totalSilver = 0,
        rawGoldGainedSilver = 0,
        goldSpentSilver = 0,
        lastMoneyCopper = (GetMoney and GetMoney()) or 0,
        items = {},
        recent = {},
        pendingChatLoot = {},
        trustedMailItems = {},
        pendingCraftedItems = {},
        lastBagCounts = {},
        categoryTotals = {},
        isPaused = false,
        priorDuration = 0,
        sessionStartUptime = GetTime(),
        sessionStartTime = time(),
        sessionID = nil,
        historySaved = false,
        bagBaselineReady = false,
        baselinePrimingUntil = GetTime() + 6,
    }
end

function EL:AutoStartSessionOnLogin()
    self:StartFreshSessionOnLogin()
end

function EL:GetSessionElapsedSeconds()
    local s = self:GetSessionDB()
    local prior = math.max(0, tonumber(s.priorDuration) or 0)
    if s.isPaused then return prior end
    return prior + math.max(0, math.floor(GetTime() - (tonumber(s.sessionStartUptime) or GetTime())))
end

function EL:IsRawGoldGainTrackingEnabled()
    local session = self.db and self.db.settings and self.db.settings.session or {}
    return session.trackRawGoldGains ~= false
end

function EL:IsGoldSpentTrackingEnabled()
    local session = self.db and self.db.settings and self.db.settings.session or {}
    return session.trackGoldSpent == true
end

function EL:SyncSessionMoneyBaseline()
    local s = self:GetSessionDB()
    s.lastMoneyCopper = (GetMoney and GetMoney()) or tonumber(s.lastMoneyCopper) or 0
end

function EL:AddSessionMoneyDelta(copperDelta)
    if self.IsSessionTrackingEnabled and not self:IsSessionTrackingEnabled() then return end
    local s = self:GetSessionDB()
    if s.isPaused then return end
    copperDelta = tonumber(copperDelta) or 0
    if copperDelta == 0 then return end

    local silverDelta = self.CopperToSilver and self:CopperToSilver(math.abs(copperDelta)) or math.floor((math.abs(copperDelta) + 50) / 100)
    if silverDelta <= 0 then return end

    if copperDelta > 0 then
        if not self:IsRawGoldGainTrackingEnabled() then return end
        s.rawGoldGainedSilver = (tonumber(s.rawGoldGainedSilver) or 0) + silverDelta
        s.totalSilver = (tonumber(s.totalSilver) or 0) + silverDelta
        table.insert(s.recent, 1, {
            type = "money",
            name = "Raw gold gained",
            count = 1,
            silver = silverDelta,
            moneyText = self:FormatMoneyText(silverDelta),
        })
    else
        if not self:IsGoldSpentTrackingEnabled() then return end
        s.goldSpentSilver = (tonumber(s.goldSpentSilver) or 0) + silverDelta
        s.totalSilver = (tonumber(s.totalSilver) or 0) - silverDelta
        table.insert(s.recent, 1, {
            type = "money",
            name = "Gold spent",
            count = 1,
            silver = -silverDelta,
            moneyText = self:FormatMoneyText(-silverDelta),
        })
    end
    while #s.recent > 100 do table.remove(s.recent) end
    self:RequestUpdate()
end

function EL:GetSessionGoldPerHour()
    local s = self:GetSessionDB()
    local elapsed = self:GetSessionElapsedSeconds()
    if elapsed <= 0 then return 0 end
    return math.floor(((tonumber(s.totalSilver) or 0) * 3600) / elapsed)
end

function EL:SetSessionPaused(paused)
    local s = self:GetSessionDB()
    if paused and not s.isPaused then
        s.priorDuration = self:GetSessionElapsedSeconds()
        s.isPaused = true
    elseif not paused and s.isPaused then
        s.isPaused = false
        s.sessionStartUptime = GetTime()
        if self.CountSessionItemsInBags then
            s.lastBagCounts = self:CountSessionItemsInBags()
            s.bagBaselineReady = true
        end
    end
    self:RequestUpdate()
end

function EL:ToggleSessionPause()
    local s = self:GetSessionDB()
    self:SetSessionPaused(not s.isPaused)
end

function EL:ResetSession()
    if self.SaveCurrentSessionHistory then self:SaveCurrentSessionHistory("reset") end
    self.db.session = {
        totalSilver = 0,
        rawGoldGainedSilver = 0,
        goldSpentSilver = 0,
        lastMoneyCopper = (GetMoney and GetMoney()) or 0,
        items = {},
        recent = {},
        pendingChatLoot = {},
        trustedMailItems = {},
        pendingCraftedItems = {},
        lastBagCounts = {},
        categoryTotals = {},
        isPaused = false,
        priorDuration = 0,
        sessionStartUptime = GetTime(),
        sessionStartTime = time(),
        sessionID = nil,
        historySaved = false,
        bagBaselineReady = false,
        baselinePrimingUntil = GetTime() + 3,
    }
    self:RequestUpdate()
    self:Print("Session reset.")
end

function EL:GetTopSessionItems(limit)
    local s = self:GetSessionDB()
    local list = {}
    for itemID, entry in pairs(s.items or {}) do
        local numericID = tonumber((type(entry) == "table" and entry.itemID) or itemID) or itemID
        if self.IsSessionTrackedItem and self:IsSessionTrackedItem(numericID) then
            entry.itemID = entry.itemID or numericID
            table.insert(list, entry)
        end
    end
    table.sort(list, SortSessionItems)
    local out = {}
    for i = 1, math.min(tonumber(limit) or 4, #list) do out[i] = list[i] end
    return out
end



function EL:GetSessionLootLog(limit)
    local s = self:GetSessionDB()
    local out = {}
    local max = tonumber(limit) or 50
    for _, entry in ipairs(s.recent or {}) do
        if type(entry) == "table" then
            local itemID = tonumber(entry.itemID)
            if not itemID or (self.IsSessionTrackedItem and self:IsSessionTrackedItem(itemID)) then
                out[#out + 1] = entry
                if #out >= max then break end
            end
        end
    end
    return out
end


function EL:IsSessionHistoryEnabled()
    local session = self.db and self.db.settings and self.db.settings.session or {}
    return session.sessionHistoryEnabled ~= false
end

function EL:SetSessionHistoryEnabled(enabled)
    self.db.settings.session = self.db.settings.session or {}
    self.db.settings.session.sessionHistoryEnabled = enabled == true
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
    if self.RefreshSessionHistoryWindow then self:RefreshSessionHistoryWindow() end
    self:Print("Session history: " .. (enabled and "Enabled" or "Disabled") .. ".")
end

function EL:ToggleSessionHistoryEnabled()
    self:SetSessionHistoryEnabled(not self:IsSessionHistoryEnabled())
end

function EL:GetSessionHistoryRetentionDays()
    -- Retention is intentionally fixed at 30 days to keep SavedVariables small.
    -- Longer-term summaries may be added later through compact aggregates.
    return 30
end


function EL:GetSessionHistoryMaxEntries()
    local session = self.db and self.db.settings and self.db.settings.session or {}
    return math.floor(ClampNumber(session.historyMaxEntries, 50, 3000, 500))
end

function EL:SetSessionHistoryMaxEntries(entries)
    self.db = self.db or {}
    self.db.settings = self.db.settings or {}
    self.db.settings.session = self.db.settings.session or {}
    self.db.settings.session.historyMaxEntries = math.floor(ClampNumber(entries, 50, 3000, 500))
    if self.PruneSessionHistory then self:PruneSessionHistory() end
    if self.RefreshSettingsPanel then self:RefreshSettingsPanel() end
    if self.RefreshSessionHistoryWindow then self:RefreshSessionHistoryWindow() end
end

function EL:SetSessionHistoryRetentionDays(days)
    -- Deprecated compatibility shim. Older builds exposed retention choices,
    -- but current EmberLedger keeps retention fixed at 30 days.
    self.db.settings.session = self.db.settings.session or {}
    self.db.settings.session.historyRetentionDays = 30
    if self.PruneSessionHistory then self:PruneSessionHistory() end
end

function EL:CycleSessionHistoryRetentionDays()
    -- Deprecated compatibility shim for old bindings or slash usage.
    self:SetSessionHistoryRetentionDays(30)
end

function EL:GetSessionHistoryDisplayMode()
    local session = self.db and self.db.settings and self.db.settings.session or {}
    local mode = tostring(session.historyDisplayMode or "")
    if mode == "today" or mode == "week" or mode == "30" then return mode end

    -- Compatibility: older builds stored a numeric display window. Treat the old
    -- 7-day view as the new WoW-native current-week view.
    local days = tonumber(session.historyDisplayDays) or 30
    if days == 1 then return "today" end
    if days == 7 then return "week" end
    return "30"
end

function EL:GetSessionHistoryDisplayDays()
    -- Compatibility accessor for older UI/call sites. The current-week mode is
    -- not a rolling 7-day window, but 7 remains its nearest legacy equivalent.
    local mode = self:GetSessionHistoryDisplayMode()
    if mode == "today" then return 1 end
    if mode == "week" then return 7 end
    return 30
end

function EL:GetWeeklyResetStartTime(now)
    now = tonumber(now) or time()

    -- Prefer Blizzard's region-aware weekly reset timer when available.
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local ok, secondsUntilReset = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        secondsUntilReset = tonumber(secondsUntilReset)
        if ok and secondsUntilReset and secondsUntilReset > 0 and secondsUntilReset <= ((7 * 86400) + 7200) then
            return (now + secondsUntilReset) - (7 * 86400)
        end
    end

    -- Safe fallback: local Tuesday 8:00 AM. This is only used if Blizzard's
    -- reset timer API is unavailable, and keeps the view predictable.
    local t = date("*t", now)
    local daysSinceTuesday = (tonumber(t.wday) or 3) - 3
    if daysSinceTuesday < 0 then daysSinceTuesday = daysSinceTuesday + 7 end
    local todayMidnight = time({ year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0, isdst = t.isdst })
    local resetTime = todayMidnight - (daysSinceTuesday * 86400) + (8 * 3600)
    if now < resetTime then resetTime = resetTime - (7 * 86400) end
    return resetTime
end

function EL:GetTodayStartTime(now)
    now = tonumber(now) or time()
    local t = date("*t", now)
    return time({ year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0, isdst = t.isdst })
end

function EL:SetSessionHistoryDisplayMode(mode)
    self.db.settings.session = self.db.settings.session or {}
    mode = tostring(mode or "30")
    if mode ~= "today" and mode ~= "week" and mode ~= "30" then mode = "30" end
    self.db.settings.session.historyDisplayMode = mode
    self.db.settings.session.historyDisplayDays = (mode == "today") and 1 or ((mode == "week") and 7 or 30)
    if self.RefreshSessionHistoryWindow then self:RefreshSessionHistoryWindow() end
    local label = mode == "today" and "Today" or (mode == "week" and "This Week" or "30 days")
    self:Print("Session history display: " .. label .. ".")
end

function EL:SetSessionHistoryDisplayDays(days)
    days = tonumber(days) or 30
    self:SetSessionHistoryDisplayMode(days == 1 and "today" or (days == 7 and "week" or "30"))
end

function EL:CycleSessionHistoryDisplayDays()
    local current = self:GetSessionHistoryDisplayMode()
    if current == "today" then
        self:SetSessionHistoryDisplayMode("week")
    elseif current == "week" then
        self:SetSessionHistoryDisplayMode("30")
    else
        self:SetSessionHistoryDisplayMode("today")
    end
end

function EL:PruneSessionHistory()
    if not self.db then return end
    self.db.sessionHistory = type(self.db.sessionHistory) == "table" and self.db.sessionHistory or {}
    local retention = self:GetSessionHistoryRetentionDays()
    local cutoff = time() - (retention * 86400)
    local kept = {}
    for _, entry in ipairs(self.db.sessionHistory) do
        if type(entry) == "table" and (tonumber(entry.timestamp) or 0) >= cutoff then
            kept[#kept + 1] = entry
        end
    end
    table.sort(kept, SortSessionHistoryNewestFirst)
    local maxEntries = self.GetSessionHistoryMaxEntries and self:GetSessionHistoryMaxEntries() or 500
    if #kept > maxEntries then
        local capped = {}
        for i = 1, maxEntries do
            capped[i] = kept[i]
        end
        kept = capped
    end
    self.db.sessionHistory = kept
    if self.PruneSessionAggregateStats then self:PruneSessionAggregateStats() end
end

function EL:GetSessionHistoryList()
    if not self.db then return {} end
    self:PruneSessionHistory()
    local mode = self.GetSessionHistoryDisplayMode and self:GetSessionHistoryDisplayMode() or "30"
    local now = time()
    local cutoff
    if mode == "today" then
        cutoff = (self.GetTodayStartTime and self:GetTodayStartTime(now)) or (now - 86400)
    elseif mode == "week" then
        cutoff = (self.GetWeeklyResetStartTime and self:GetWeeklyResetStartTime(now)) or (now - (7 * 86400))
    else
        cutoff = now - (30 * 86400)
    end
    local visible = {}
    for _, entry in ipairs(self.db.sessionHistory or {}) do
        if type(entry) == "table" and (tonumber(entry.timestamp) or 0) >= cutoff then
            visible[#visible + 1] = entry
        end
    end
    return visible
end

function EL:GetSessionHistoryID(s)
    s = s or self:GetSessionDB()
    local char = self.current and self.current.key or (UnitName and UnitName("player")) or "Unknown"
    local start = tonumber(s.sessionStartTime) or time()
    return tostring(char) .. ":" .. tostring(start)
end

function EL:SaveCurrentSessionHistory(reason)
    if not self.db then return false end
    if not self:IsSessionHistoryEnabled() then return false end
    local s = self:GetSessionDB()
    local elapsed = self:GetSessionElapsedSeconds()
    local total = tonumber(s.totalSilver) or 0
    local itemValue = total - (tonumber(s.rawGoldGainedSilver) or 0) + (tonumber(s.goldSpentSilver) or 0)
    local trackedItemQty = 0
    for _, item in pairs(s.items or {}) do
        if type(item) == "table" then
            trackedItemQty = trackedItemQty + (tonumber(item.qty) or 0)
        end
    end
    -- Do not save empty login/logout sessions. History is for useful session summaries,
    -- not passive character hops with no tracked gold or profession materials.
    local meaningful = total ~= 0 or (tonumber(s.rawGoldGainedSilver) or 0) ~= 0 or (tonumber(s.goldSpentSilver) or 0) ~= 0 or itemValue ~= 0 or trackedItemQty > 0
    if not meaningful then return false end

    local _, current = self:GetCurrentCharacter()
    current = current or {}
    local id = s.sessionID or self:GetSessionHistoryID(s)
    s.sessionID = id
    local entry = {
        id = id,
        timestamp = time(),
        startedAt = tonumber(s.sessionStartTime) or time(),
        character = current and current.name or (UnitName and UnitName("player")) or "Unknown",
        realm = current and current.realm or (GetRealmName and GetRealmName()) or "Unknown",
        class = (current and current.class) or (select(2, UnitClass("player"))),
        duration = elapsed,
        itemValueSilver = itemValue,
        rawGoldGainedSilver = tonumber(s.rawGoldGainedSilver) or 0,
        goldSpentSilver = tonumber(s.goldSpentSilver) or 0,
        totalSilver = total,
        trackedItemQty = trackedItemQty,
        goldPerHourSilver = self:GetSessionGoldPerHour(),
        reason = tostring(reason or "save"),
    }
    self.db.sessionHistory = type(self.db.sessionHistory) == "table" and self.db.sessionHistory or {}
    local replaced = false
    for i, old in ipairs(self.db.sessionHistory) do
        if type(old) == "table" and old.id == id then
            if self.RemoveSessionHistoryEntryFromAggregateStats then
                self:RemoveSessionHistoryEntryFromAggregateStats(old)
            end
            if old.countedInLifetime == true then
                entry.countedInLifetime = true
            end
            self.db.sessionHistory[i] = entry
            replaced = true
            break
        end
    end
    if not replaced then table.insert(self.db.sessionHistory, 1, entry) end
    if self.AddSessionHistoryEntryToLifetimeStats then
        self:AddSessionHistoryEntryToLifetimeStats(entry)
    end
    if self.AddSessionHistoryEntryToAggregateStats then
        self:AddSessionHistoryEntryToAggregateStats(entry)
    end
    s.historySaved = true
    self:PruneSessionHistory()
    if self.RefreshSessionHistoryWindow then self:RefreshSessionHistoryWindow() end
    return true
end


function EL:ResetSessionHistory()
    if not self.db then return end
    self.db.sessionHistory = {}
    self.db.stats = type(self.db.stats) == "table" and self.db.stats or {}
    self.db.stats.history = {
        daily = {},
        weekly = {},
        backfilledFromHistory = true,
    }
    if self.RefreshSessionHistoryWindow then self:RefreshSessionHistoryWindow() end
    self:Print("Session history cleared.")
end


function EL:GetLifetimeSessionStats()
    self.db = self.db or {}
    self.db.stats = type(self.db.stats) == "table" and self.db.stats or {}
    self.db.stats.lifetime = type(self.db.stats.lifetime) == "table" and self.db.stats.lifetime or {}
    local lifetime = self.db.stats.lifetime
    if lifetime._normalized ~= true then
        lifetime.totalSilver = tonumber(lifetime.totalSilver) or 0
        lifetime.itemValueSilver = tonumber(lifetime.itemValueSilver) or 0
        lifetime.rawGoldGainedSilver = tonumber(lifetime.rawGoldGainedSilver) or 0
        lifetime.goldSpentSilver = tonumber(lifetime.goldSpentSilver) or 0
        lifetime.duration = tonumber(lifetime.duration) or 0
        lifetime.sessions = tonumber(lifetime.sessions) or 0
        lifetime.items = tonumber(lifetime.items) or 0
        lifetime.backfilledFromHistory = lifetime.backfilledFromHistory == true
        lifetime._normalized = true
    end
    return lifetime
end

function EL:AddSessionHistoryEntryToLifetimeStats(entry)
    if type(entry) ~= "table" or entry.countedInLifetime == true then return false end
    local total = tonumber(entry.totalSilver) or 0
    local itemValue = tonumber(entry.itemValueSilver) or 0
    local raw = tonumber(entry.rawGoldGainedSilver) or 0
    local spent = tonumber(entry.goldSpentSilver) or 0
    local duration = math.max(0, tonumber(entry.duration) or 0)
    local itemQty = math.max(0, tonumber(entry.trackedItemQty) or tonumber(entry.items) or 0)
    local meaningful = total ~= 0 or itemValue ~= 0 or raw ~= 0 or spent ~= 0 or itemQty > 0
    if not meaningful then return false end

    local lifetime = self:GetLifetimeSessionStats()
    lifetime.totalSilver = lifetime.totalSilver + total
    lifetime.itemValueSilver = lifetime.itemValueSilver + itemValue
    lifetime.rawGoldGainedSilver = lifetime.rawGoldGainedSilver + raw
    lifetime.goldSpentSilver = lifetime.goldSpentSilver + spent
    lifetime.duration = lifetime.duration + duration
    lifetime.sessions = lifetime.sessions + 1
    lifetime.items = lifetime.items + itemQty
    entry.countedInLifetime = true
    return true
end

function EL:BackfillLifetimeSessionStatsFromHistory()
    local lifetime = self:GetLifetimeSessionStats()
    if lifetime.backfilledFromHistory == true then return false end
    self.db.sessionHistory = type(self.db.sessionHistory) == "table" and self.db.sessionHistory or {}
    for _, entry in ipairs(self.db.sessionHistory) do
        if type(entry) == "table" then
            self:AddSessionHistoryEntryToLifetimeStats(entry)
        end
    end
    lifetime.backfilledFromHistory = true
    return true
end

function EL:ResetLifetimeSessionStats()
    self.db = self.db or {}
    self.db.stats = type(self.db.stats) == "table" and self.db.stats or {}
    self.db.stats.lifetime = {
        totalSilver = 0,
        itemValueSilver = 0,
        rawGoldGainedSilver = 0,
        goldSpentSilver = 0,
        duration = 0,
        sessions = 0,
        items = 0,
        backfilledFromHistory = true,
        _normalized = true,
    }
    for _, entry in ipairs(self.db.sessionHistory or {}) do
        if type(entry) == "table" then entry.countedInLifetime = nil end
    end
    if self.RefreshSessionHistoryWindow then self:RefreshSessionHistoryWindow() end
    self:Print("Lifetime session stats reset.")
end


local function AddEntryValuesToAggregateBucket(bucket, entry, sign)
    if type(bucket) ~= "table" or type(entry) ~= "table" then return end
    sign = sign or 1
    -- Aggregate buckets clamp non-money counts to zero when subtracting replaced entries.
    -- totalSilver intentionally remains signed so refunds/spend adjustments can be represented.
    bucket.duration = math.max(0, (tonumber(bucket.duration) or 0) + (math.max(0, tonumber(entry.duration) or 0) * sign))
    bucket.itemValueSilver = math.max(0, (tonumber(bucket.itemValueSilver) or 0) + ((tonumber(entry.itemValueSilver) or 0) * sign))
    bucket.rawGoldGainedSilver = math.max(0, (tonumber(bucket.rawGoldGainedSilver) or 0) + ((tonumber(entry.rawGoldGainedSilver) or 0) * sign))
    bucket.goldSpentSilver = math.max(0, (tonumber(bucket.goldSpentSilver) or 0) + ((tonumber(entry.goldSpentSilver) or 0) * sign))
    bucket.totalSilver = (tonumber(bucket.totalSilver) or 0) + ((tonumber(entry.totalSilver) or 0) * sign)
    bucket.sessions = math.max(0, (tonumber(bucket.sessions) or 0) + sign)
    bucket.items = math.max(0, (tonumber(bucket.items) or 0) + ((math.max(0, tonumber(entry.trackedItemQty) or tonumber(entry.items) or 0)) * sign))
end

function EL:GetSessionAggregateDateKey(timestamp)
    local t = date("*t", tonumber(timestamp) or time())
    return string.format("%04d-%02d-%02d", tonumber(t.year) or 1970, tonumber(t.month) or 1, tonumber(t.day) or 1)
end

function EL:GetSessionAggregateWeekKey(timestamp)
    timestamp = tonumber(timestamp) or time()
    local start = (self.GetWeeklyResetStartTime and self:GetWeeklyResetStartTime(timestamp)) or (timestamp - (7 * 86400))
    local t = date("*t", start)
    return string.format("%04d-%02d-%02d", tonumber(t.year) or 1970, tonumber(t.month) or 1, tonumber(t.day) or 1)
end

function EL:GetSessionHistoryAggregateStats()
    self.db = self.db or {}
    self.db.stats = type(self.db.stats) == "table" and self.db.stats or {}
    self.db.stats.history = type(self.db.stats.history) == "table" and self.db.stats.history or {}
    local stats = self.db.stats.history
    stats.daily = type(stats.daily) == "table" and stats.daily or {}
    stats.weekly = type(stats.weekly) == "table" and stats.weekly or {}
    stats.backfilledFromHistory = stats.backfilledFromHistory == true
    return stats
end

function EL:AddSessionHistoryEntryToAggregateStats(entry)
    if type(entry) ~= "table" or entry.countedInAggregates == true then return false end
    local total = tonumber(entry.totalSilver) or 0
    local itemValue = tonumber(entry.itemValueSilver) or 0
    local raw = tonumber(entry.rawGoldGainedSilver) or 0
    local spent = tonumber(entry.goldSpentSilver) or 0
    local itemQty = math.max(0, tonumber(entry.trackedItemQty) or tonumber(entry.items) or 0)
    local meaningful = total ~= 0 or itemValue ~= 0 or raw ~= 0 or spent ~= 0 or itemQty > 0
    if not meaningful then return false end

    local stats = self:GetSessionHistoryAggregateStats()
    local timestamp = tonumber(entry.timestamp) or time()
    local dayKey = self:GetSessionAggregateDateKey(timestamp)
    local weekKey = self:GetSessionAggregateWeekKey(timestamp)
    stats.daily[dayKey] = type(stats.daily[dayKey]) == "table" and stats.daily[dayKey] or {}
    stats.weekly[weekKey] = type(stats.weekly[weekKey]) == "table" and stats.weekly[weekKey] or {}
    AddEntryValuesToAggregateBucket(stats.daily[dayKey], entry, 1)
    AddEntryValuesToAggregateBucket(stats.weekly[weekKey], entry, 1)
    entry.countedInAggregates = true
    return true
end

function EL:RemoveSessionHistoryEntryFromAggregateStats(entry)
    if type(entry) ~= "table" or entry.countedInAggregates ~= true then return false end
    local stats = self:GetSessionHistoryAggregateStats()
    local timestamp = tonumber(entry.timestamp) or time()
    local dayKey = self:GetSessionAggregateDateKey(timestamp)
    local weekKey = self:GetSessionAggregateWeekKey(timestamp)
    if type(stats.daily[dayKey]) == "table" then AddEntryValuesToAggregateBucket(stats.daily[dayKey], entry, -1) end
    if type(stats.weekly[weekKey]) == "table" then AddEntryValuesToAggregateBucket(stats.weekly[weekKey], entry, -1) end
    entry.countedInAggregates = nil
    return true
end

function EL:PruneSessionAggregateStats()
    local stats = self:GetSessionHistoryAggregateStats()
    local now = time()
    local dailyCutoff = (self.GetSessionAggregateDateKey and self:GetSessionAggregateDateKey(now - (31 * 86400))) or ""
    for key in pairs(stats.daily or {}) do
        if tostring(key) < dailyCutoff then stats.daily[key] = nil end
    end
    local weeklyCutoff = (self.GetSessionAggregateWeekKey and self:GetSessionAggregateWeekKey(now - (42 * 86400))) or ""
    for key in pairs(stats.weekly or {}) do
        if tostring(key) < weeklyCutoff then stats.weekly[key] = nil end
    end
end

function EL:BackfillSessionAggregateStatsFromHistory()
    local stats = self:GetSessionHistoryAggregateStats()
    if stats.backfilledFromHistory == true then return false end
    stats.daily = {}
    stats.weekly = {}
    self.db.sessionHistory = type(self.db.sessionHistory) == "table" and self.db.sessionHistory or {}
    for _, entry in ipairs(self.db.sessionHistory) do
        if type(entry) == "table" then
            entry.countedInAggregates = nil
            self:AddSessionHistoryEntryToAggregateStats(entry)
        end
    end
    stats.backfilledFromHistory = true
    if self.PruneSessionAggregateStats then self:PruneSessionAggregateStats() end
    return true
end

local function AddAggregateBucketToTotal(total, bucket)
    if type(total) ~= "table" or type(bucket) ~= "table" then return end
    total.duration = total.duration + (tonumber(bucket.duration) or 0)
    total.itemValueSilver = total.itemValueSilver + (tonumber(bucket.itemValueSilver) or 0)
    total.rawGoldGainedSilver = total.rawGoldGainedSilver + (tonumber(bucket.rawGoldGainedSilver) or 0)
    total.goldSpentSilver = total.goldSpentSilver + (tonumber(bucket.goldSpentSilver) or 0)
    total.totalSilver = total.totalSilver + (tonumber(bucket.totalSilver) or 0)
    total.sessions = total.sessions + (tonumber(bucket.sessions) or 0)
    total.items = total.items + (tonumber(bucket.items) or 0)
end

function EL:GetSessionAggregateStats(range)
    range = tostring(range or "30")
    if range == "lifetime" then
        local lifetime = self:GetLifetimeSessionStats()
        local total = {
            duration = tonumber(lifetime.duration) or 0,
            itemValueSilver = tonumber(lifetime.itemValueSilver) or 0,
            rawGoldGainedSilver = tonumber(lifetime.rawGoldGainedSilver) or 0,
            goldSpentSilver = tonumber(lifetime.goldSpentSilver) or 0,
            totalSilver = tonumber(lifetime.totalSilver) or 0,
            sessions = tonumber(lifetime.sessions) or 0,
            items = tonumber(lifetime.items) or 0,
        }
        total.goldPerHourSilver = total.duration > 0 and math.floor((total.totalSilver * 3600) / total.duration) or 0
        return total
    end

    if self.PruneSessionAggregateStats then self:PruneSessionAggregateStats() end
    local now = time()
    local stats = self:GetSessionHistoryAggregateStats()
    local total = { duration = 0, itemValueSilver = 0, rawGoldGainedSilver = 0, goldSpentSilver = 0, totalSilver = 0, sessions = 0, items = 0 }

    if range == "today" then
        local key = self:GetSessionAggregateDateKey(now)
        AddAggregateBucketToTotal(total, stats.daily and stats.daily[key])
    elseif range == "week" then
        local key = self:GetSessionAggregateWeekKey(now)
        AddAggregateBucketToTotal(total, stats.weekly and stats.weekly[key])
    else
        range = "30"
        local cutoffKey = self:GetSessionAggregateDateKey(now - (30 * 86400))
        for key, bucket in pairs(stats.daily or {}) do
            if tostring(key) >= cutoffKey then
                AddAggregateBucketToTotal(total, bucket)
            end
        end
    end

    total.sessions = math.max(0, math.floor(tonumber(total.sessions) or 0))
    total.items = math.max(0, math.floor(tonumber(total.items) or 0))
    total.duration = math.max(0, math.floor(tonumber(total.duration) or 0))
    total.goldPerHourSilver = total.duration > 0 and math.floor((total.totalSilver * 3600) / total.duration) or 0
    return total
end

function EL:BuildSessionSummaryText()
    local s = self:GetSessionDB()
    local lines = {}
    table.insert(lines, "EmberLedger Session")
    table.insert(lines, "Time: " .. self:FormatDuration(self:GetSessionElapsedSeconds()))
    table.insert(lines, "Total: " .. self:FormatMoneyText(s.totalSilver or 0))
    table.insert(lines, "Rate: " .. self:FormatMoneyRateText(self:GetSessionGoldPerHour()) .. "/hr")
    table.insert(lines, "Pricing: " .. (self.GetActivePricingSourceLabel and self:GetActivePricingSourceLabel() or "Unknown"))
    table.insert(lines, "")
    table.insert(lines, "Recent Loot:")
    local loot = self:GetSessionLootLog(12)
    if #loot == 0 then
        table.insert(lines, "No tracked loot yet.")
    else
        for _, item in ipairs(loot) do
            local count = tonumber(item.count or item.qty) or 0
            local money = item.moneyText or self:FormatMoneyText(item.silver or 0)
            table.insert(lines, string.format("%s x%d - %s", tostring(item.name or ("item:" .. tostring(item.itemID))), count, money))
        end
    end
    return table.concat(lines, "\n")
end

function EL:PrintSessionSummaryToChat(text)
    text = text or self:BuildSessionSummaryText()
    for line in tostring(text):gmatch("[^\n]+") do
        self:Print(line)
    end
end

local COPY_SESSION_POPUP_NAME = "EMBERLEDGER_COPY_SESSION"

local function EnsureCopySessionPopupDefinition()
    if not StaticPopupDialogs or StaticPopupDialogs[COPY_SESSION_POPUP_NAME] then return end
    StaticPopupDialogs[COPY_SESSION_POPUP_NAME] = {
        text = "Press Ctrl+C to copy the highlighted session summary. The OK button only closes this window.",
        button1 = CLOSE,
        button2 = "Print Chat",
        hasEditBox = true,
        editBoxWidth = 360,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(dialog, data)
            local editBox = dialog and (dialog.editBox or dialog.EditBox)
            if editBox then
                editBox:SetText(data or "")
                editBox:HighlightText()
                editBox:SetFocus()
            end
        end,
        EditBoxOnEscapePressed = function(editBox)
            local dialog = editBox and editBox:GetParent()
            if dialog then dialog:Hide() end
        end,
        EditBoxOnEnterPressed = function(editBox)
            editBox:HighlightText()
        end,
        -- Blizzard StaticPopup button2 dispatches through OnCancel with reason == "clicked".
        -- Use that path for the optional Print Chat action while button1 simply closes.
        OnCancel = function(_, data, reason)
            if reason == "clicked" and EL and type(EL.PrintSessionSummaryToChat) == "function" then
                EL:PrintSessionSummaryToChat(data)
            end
        end,
    }
end

function EL:ShowCopySessionSummaryDialog()
    local text = self:BuildSessionSummaryText()
    if StaticPopupDialogs then
        EnsureCopySessionPopupDefinition()
        StaticPopup_Show(COPY_SESSION_POPUP_NAME, nil, nil, text)
    else
        self:PrintSessionSummaryToChat(text)
    end
end

function EL:GetNextMulchSummary(now)
    local status = self:GetMulchStatus(now)
    return status and status.next or nil
end

function EL:InvalidateCharacterRows()
    self._characterRowsCache = nil
    self._characterRowsVersion = (self._characterRowsVersion or 0) + 1
end

local function NormalizeCharacterIdentityPart(value)
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    -- Realm names may appear with or without spaces depending on client/API path.
    -- Removing internal spaces lets legacy keys such as Area 52 and Area52 collapse.
    return value:gsub("%s+", "")
end

local function ParseCharacterKeyParts(key)
    local text = tostring(key or "")
    local name, realm = text:match("^([^%-]+)%-(.+)$")
    return name, realm
end

function EL:GetCanonicalCharacterIdentity(char, key)
    char = type(char) == "table" and char or {}
    local keyName, keyRealm = ParseCharacterKeyParts(key)
    local name = char.name or keyName or key
    local realm = char.realm or keyRealm or ""
    return NormalizeCharacterIdentityPart(name) .. "-" .. NormalizeCharacterIdentityPart(realm)
end

function EL:IsPreferredCharacterRowCandidate(candidate, existing, currentCharKey)
    if not existing then return true end

    local candidateLastSeen = tonumber(candidate.char and candidate.char.lastSeen) or 0
    local existingLastSeen = tonumber(existing.char and existing.char.lastSeen) or 0

    if currentCharKey then
        if candidate.key == currentCharKey and existing.key ~= currentCharKey then
            return candidateLastSeen > 0 or existingLastSeen == 0
        end
        if existing.key == currentCharKey and candidate.key ~= currentCharKey then
            return candidateLastSeen > 0 and existingLastSeen == 0
        end
    end

    local candidateCanonicalKey = candidate.char and candidate.char.name and candidate.char.realm and self.GetCharacterKey and self:GetCharacterKey(candidate.char.name, candidate.char.realm) or nil
    local existingCanonicalKey = existing.char and existing.char.name and existing.char.realm and self.GetCharacterKey and self:GetCharacterKey(existing.char.name, existing.char.realm) or nil
    if candidateCanonicalKey and candidate.key == candidateCanonicalKey and existing.key ~= existingCanonicalKey then
        return candidateLastSeen > 0 or existingLastSeen == 0
    end
    if existingCanonicalKey and existing.key == existingCanonicalKey and candidate.key ~= candidateCanonicalKey then
        return not (candidateLastSeen > 0 and existingLastSeen == 0)
    end

    return candidateLastSeen > existingLastSeen
end

function EL:GetCharacterRows()
    local chars = self.db and self.db.characters or {}
    local display = self.db and self.db.settings and self.db.settings.display or {}
    local showRealm = display.showCharacterRealm ~= false
    local cache = self._characterRowsCache
    if cache and cache.source == chars and cache.showRealm == showRealm and cache.version == (self._characterRowsVersion or 0) then
        return cache.rows
    end

    local rows = {}
    local candidatesByIdentity = {}
    local currentCharKey = self.currentCharKey or (self.GetCharacterKey and self:GetCharacterKey() or nil)

    for key, char in pairs(chars) do
        local identity = self.GetCanonicalCharacterIdentity and self:GetCanonicalCharacterIdentity(char, key) or tostring(key or ""):lower()
        local displayName = self:GetCharacterDisplayName(char, key)
        local candidate = {
            key = key,
            char = char,
            displayName = displayName,
            displayNameLower = tostring(displayName or key or ""):lower(),
            duplicateIdentity = identity,
        }
        local existing = candidatesByIdentity[identity]
        if self:IsPreferredCharacterRowCandidate(candidate, existing, currentCharKey) then
            if existing and self.Debug then
                self:Debug("Suppressing duplicate character row candidate: " .. tostring(existing.key) .. " -> " .. tostring(key) .. " [identity=" .. tostring(identity) .. "]")
            end
            candidatesByIdentity[identity] = candidate
        else
            if self.Debug then
                self:Debug("Suppressing duplicate character row candidate: " .. tostring(key) .. " -> " .. tostring(existing and existing.key or identity) .. " [identity=" .. tostring(identity) .. "]")
            end
        end
    end

    for _, row in pairs(candidatesByIdentity) do
        rows[#rows + 1] = row
    end

    table.sort(rows, SortCharacterRowsByName)
    self._characterRowsCache = {
        rows = rows,
        source = chars,
        showRealm = showRealm,
        version = self._characterRowsVersion or 0,
    }
    return rows
end

function EL:IsSessionTrackingEnabled()
    local perf = self.db and self.db.settings and self.db.settings.performance or {}
    return perf.sessionTracking ~= false
end

function EL:IsActionBarEnabled()
    local perf = self.db and self.db.settings and self.db.settings.performance or {}
    return perf.actionBar ~= false
end

function EL:IsActionBarFloating()
    local panel = self.db and self.db.settings and self.db.settings.panel or {}
    return panel.actionBarFloating == true
end

function EL:ShouldRefreshActionBar()
    if self.IsActionBarEnabled and not self:IsActionBarEnabled() then return false end
    local bar = self.GetActionBarFrame and self:GetActionBarFrame() or (self.panel and self.panel.actionBar)
    local floating = self.IsActionBarFloating and self:IsActionBarFloating()
    if floating then
        return bar and bar:IsShown()
    end
    -- Anchored mode belongs to the main tracker. During login/show restore the
    -- action bar may still be hidden until its first layout pass, so refresh
    -- whenever the panel is visible rather than requiring bar:IsShown() first.
    return (self.panel and self.panel:IsShown()) or (bar and bar:IsShown())
end

function EL:HasVisibleUpdateConsumers()
    local buttonShown = self.button and self.button:IsShown()
    local panelShown = self.panel and self.panel:IsShown()
    local sessionShown = self:IsSessionTrackingEnabled() and self.sessionWindow and self.sessionWindow:IsShown()
    return buttonShown or panelShown or sessionShown or self:ShouldRefreshActionBar()
end

function EL:PerformUpdate()
    local profileAll = self:ProfileStart("PerformUpdate")
    if self.HasVisibleUpdateConsumers and not self:HasVisibleUpdateConsumers() then
        if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
        self:ProfileStop("PerformUpdate", profileAll)
        return
    end

    if self:IsCombatLocked() then
        self:QueueCombatDeferredWork("ui")
        self:ProfileStop("PerformUpdate", profileAll)
        return
    end

    if self.UpdateButton then
        local profile = self:ProfileStart("UpdateButton")
        self:UpdateButton()
        self:ProfileStop("UpdateButton", profile)
    end

    local panelShown = self.panel and self.panel:IsShown()
    if panelShown and self.RefreshPanel then
        local profile = self:ProfileStart("RefreshPanel")
        self:RefreshPanel()
        self:ProfileStop("RefreshPanel", profile)
    end

    local sessionShown = self:IsSessionTrackingEnabled() and self.sessionWindow and self.sessionWindow:IsShown()
    if sessionShown and self.RefreshSessionPanel then
        local profile = self:ProfileStart("RefreshSessionPanel")
        self:RefreshSessionPanel()
        self:ProfileStop("RefreshSessionPanel", profile)
    end

    if self:ShouldRefreshActionBar() and self.RequestActionBarRefresh then self:RequestActionBarRefresh() end
    self:ProfileStop("PerformUpdate", profileAll)
end

function EL:RequestUpdate(immediate)
    if self.HasVisibleUpdateConsumers and not self:HasVisibleUpdateConsumers() then
        self.updateRefreshQueued = nil
        self.updateRefreshPending = nil
        if self.RefreshUpdateTicker then self:RefreshUpdateTicker() end
        return
    end

    if self:IsCombatLocked() then
        self:QueueCombatDeferredWork("ui")
        return
    end

    if immediate or not (C_Timer and C_Timer.After) then
        self.updateRefreshQueued = nil
        self.updateRefreshPending = nil
        self._lastUpdateRefreshTime = GetTime and GetTime() or self._lastUpdateRefreshTime
        self:PerformUpdate()
        return
    end

    self.updateRefreshPending = true
    if self.updateRefreshQueued then return end
    self.updateRefreshQueued = true

    local now = GetTime and GetTime() or 0
    local debounce = self.UPDATE_DEBOUNCE_SECONDS or 0.05
    local coalesce = self.UPDATE_COALESCE_SECONDS or debounce
    local last = tonumber(self._lastUpdateRefreshTime) or 0
    local delay = debounce
    if now > 0 and last > 0 then
        local remaining = coalesce - (now - last)
        if remaining > delay then delay = remaining end
    end

    C_Timer.After(delay, function()
        if not EL then return end
        EL.updateRefreshQueued = nil
        if not EL.updateRefreshPending then return end
        EL.updateRefreshPending = nil
        EL._lastUpdateRefreshTime = GetTime and GetTime() or EL._lastUpdateRefreshTime
        if EL.PerformUpdate then EL:PerformUpdate() end
    end)
end

function EL:Print(msg)
    print("|cffff7a1aEmberLedger:|r " .. tostring(msg))
end

function EL:GetProfessionThresholdDefinition(token)
    if not token then return nil end
    local needle = tostring(token):lower():gsub("%s+", "")
    for _, def in ipairs(self.PROFESSION_THRESHOLD_PROFESSIONS or {}) do
        local key = tostring(def.key or ""):lower()
        local label = tostring(def.label or ""):lower():gsub("%s+", "")
        if needle == key or needle == label or needle == tostring(def.id) then
            return def
        end
    end
    return nil
end


function EL:HasScannedProfessionData()
    local resources = self.db and self.db.resources or nil
    if type(resources) ~= "table" then return false end
    local professions = resources.professions
    if type(professions) == "table" then
        for _, list in pairs(professions) do
            if type(list) == "table" and #list > 0 then return true end
        end
    end
    local concentration = resources.concentration
    if type(concentration) == "table" then
        for _, list in pairs(concentration) do
            if type(list) == "table" and #list > 0 then return true end
        end
    end
    return false
end

function EL:CaptureOnboardingLoadState()
    self._hadTrackedDataOnLoad = self:HasScannedProfessionData() == true
end

function EL:ShouldShowFirstRunOnboarding()
    local settings = self.db and self.db.settings or nil
    if type(settings) ~= "table" then return false end
    if settings.onboardingSeen == true then return false end
    return self._hadTrackedDataOnLoad ~= true
end

function EL:MarkOnboardingSeen()
    if self.db and self.db.settings then
        self.db.settings.onboardingSeen = true
    end
end

function EL:PrintSlashHelp()
    self:Print(self:T("Commands:"))
    self:Print(self:T("General: /el, /el main, /el recover, /el settings, /el help, /el welcome"))
    self:Print(self:T("Sessions: /el session, /el history, /el session start, /el session pause, /el reset session"))
    self:Print(self:T("Characters: /el restore, /el restore hidden, /el reset pinned"))
    self:Print(self:T("Display: /el scale, /el scale 0.85, /el lock, /el unlock, /el threshold 900, /el threshold alchemy 900"))
    self:Print(self:T("Maintenance: /el refresh, /el refresh professions, /el debug"))
    self:Print(self:T("Profiling: /el profile on, /el profile off, /el profile report, /el profile dump, /el profile reset"))
end


local function PreserveMainWindowForProfileCommand(callback)
    local wasShown = EL and EL.panel and EL.panel.IsShown and EL.panel:IsShown()

    if callback then callback() end

    if not wasShown then return end

    -- Profile commands must not hide or disable an already-visible tracker.
    -- Force only the main tracker visibility flags back on after profiling actions.
    local function restore()
        local panelSettings = EL and EL.db and EL.db.settings and EL.db.settings.panel or nil
        if panelSettings then
            panelSettings.charactersShown = true
            panelSettings.windowOpen = true
        end
        if EL and EL.panel and EL.panel.Show and not EL.panel:IsShown() then
            EL.panel:Show()
        elseif EL and EL.ShowPanelFromSavedState then
            EL:ShowPanelFromSavedState()
        end
        if EL and EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
    end

    restore()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, restore)
        C_Timer.After(0.10, restore)
    end
end

SLASH_EMBERLEDGER1 = "/ember"
SLASH_EMBERLEDGER2 = "/emberledger"
SLASH_EMBERLEDGER3 = "/el"
SlashCmdList.EMBERLEDGER = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local scaleValue = msg:match("^scale%s+([%d%.]+)$")
    if scaleValue then
        local scale = tonumber(scaleValue)
        if scale and scale >= 0.6 and scale <= 1.4 then
            EL.db.settings.panel.scale = scale
            if EL.ApplyPanelScale then EL:ApplyPanelScale() end
            EL:Print(EL:T("Window scale set to %.2f.", scale))
        else
            EL:Print(EL:T("Use /el scale 0.6 through /el scale 1.4"))
        end
    elseif msg == "help" or msg == "?" then
        if EL.PrintSlashHelp then EL:PrintSlashHelp() end
    elseif msg == "welcome" or msg == "onboarding" or msg == "getting started" then
        if EL.ShowOnboardingPanel then EL:ShowOnboardingPanel(true) end
    elseif msg == "scale" then
        local current = EL.db and EL.db.settings and EL.db.settings.panel and EL.db.settings.panel.scale or 1
        EL:Print(EL:T("Current window scale: %.2f. Use /el scale 0.85, /el scale 1, etc.", current))
    elseif msg == "reset" or msg == "reset windows" or msg == "reset layout" then
        if EL.ResetWindowPositions then EL:ResetWindowPositions() end
    elseif msg == "recover" or msg == "restore window" or msg == "reset main" then
        if EL.db and EL.db.settings and EL.db.settings.panel then
            EL.db.settings.panel.point = "CENTER"
            EL.db.settings.panel.relativePoint = "CENTER"
            EL.db.settings.panel.x = 0
            EL.db.settings.panel.y = 0
            EL.db.settings.panel.charactersShown = true
            EL.db.settings.panel.windowOpen = true
        end
        if EL.ShowPanelFromSavedState then EL:ShowPanelFromSavedState() end
        EL:Print(EL:T("Main window restored."))
    elseif msg == "lock" or msg == "unlock" then
        EL.db.settings.lockWindows = (msg == "lock")
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
        EL:Print(EL.db.settings.lockWindows and EL:T("Windows locked. Hold Shift and drag to move them.") or EL:T("Windows unlocked."))
    elseif msg == "debug" then
        if EL.ToggleDebug then EL:ToggleDebug() end
    elseif msg == "profile" or msg == "profile status" then
        local enabled = EL.IsProfilingEnabled and EL:IsProfilingEnabled()
        EL:Print(enabled and EL:T("Performance profiling is enabled.") or EL:T("Performance profiling is disabled. Use /el profile on to enable it."))
        if EL.PrintProfileReport then EL:PrintProfileReport() end
    elseif msg == "profile on" or msg == "profile start" then
        PreserveMainWindowForProfileCommand(function()
            if EL.SetProfilingEnabled then EL:SetProfilingEnabled(true) end
        end)
    elseif msg == "profile off" or msg == "profile stop" then
        PreserveMainWindowForProfileCommand(function()
            if EL.SetProfilingEnabled then EL:SetProfilingEnabled(false) end
        end)
    elseif msg == "profile reset" then
        PreserveMainWindowForProfileCommand(function()
            if EL.ResetProfileStats then EL:ResetProfileStats() end
        end)
    elseif msg == "profile report" or msg == "profile summary" or msg == "profile dump" then
        PreserveMainWindowForProfileCommand(function()
            if EL.PrintProfileReport then EL:PrintProfileReport() end
        end)
    elseif msg == "refresh" then
        if EL.RefreshCurrentProfessionIdentity then EL:RefreshCurrentProfessionIdentity() end
        EL:ForEachModule("Refresh")
        EL:RequestUpdate()
        EL:Print(EL:T("Refreshed."))
    elseif msg == "refresh professions" or msg == "professions" then
        if EL.RefreshCurrentProfessionIdentity and EL:RefreshCurrentProfessionIdentity() then
            EL:RequestUpdate()
            EL:Print(EL:T("Profession identity refreshed."))
        else
            EL:Print(EL:T("Profession identity could not be refreshed yet."))
        end
    elseif msg == "session start" or msg == "session resume" then
        EL:SetSessionPaused(false)
        EL:Print(EL:T("Session tracking resumed."))
    elseif msg == "session pause" then
        EL:SetSessionPaused(true)
        EL:Print(EL:T("Session tracking paused."))
    elseif msg == "session reset" or msg == "reset session" then
        EL:ResetSession()
    elseif msg == "reset hidden" or msg == "restore hidden" then
        EL:RestoreHiddenCharacters()
    elseif msg == "reset pinned" or msg == "unpinall" then
        if EL.ResetPinnedCharacters then EL:ResetPinnedCharacters() end
    elseif msg == "main" then
        if EL.ToggleMainPanel then EL:ToggleMainPanel() end
    elseif msg == "session" then
        if EL.ToggleSessionWindow then EL:ToggleSessionWindow() end
    elseif msg == "history" or msg == "session history" then
        if EL.ToggleSessionHistoryWindow then EL:ToggleSessionHistoryWindow() end
    elseif msg == "settings" or msg == "options" then
        if EL.ToggleSettingsPanel then EL:ToggleSettingsPanel() end
    elseif msg:match("^threshold%s+[%a%d_%-]+%s+%d+$") then
        local token, value = msg:match("^threshold%s+([%a%d_%-]+)%s+(%d+)$")
        local def = EL.GetProfessionThresholdDefinition and EL:GetProfessionThresholdDefinition(token) or nil
        if def and EL.SetProfessionConcentrationThreshold then
            EL:SetProfessionConcentrationThreshold(def.id, tonumber(value))
            EL:Print((def.label or token) .. " concentration threshold set to " .. tostring(EL:GetProfessionConcentrationThreshold(def.id)) .. ".")
        else
            EL:Print("Unknown profession. Example: /el threshold alchemy 900")
        end
    elseif msg:match("^threshold%s+[%a%d_%-]+%s+default$") or msg:match("^threshold%s+[%a%d_%-]+%s+reset$") then
        local token = msg:match("^threshold%s+([%a%d_%-]+)%s+")
        local def = EL.GetProfessionThresholdDefinition and EL:GetProfessionThresholdDefinition(token) or nil
        if def and EL.SetProfessionConcentrationThreshold then
            EL:SetProfessionConcentrationThreshold(def.id, nil)
            EL:Print((def.label or token) .. " concentration threshold reset to global default.")
        else
            EL:Print("Unknown profession. Example: /el threshold alchemy default")
        end
    elseif msg:match("^threshold%s+%d+$") then
        local value = tonumber(msg:match("^threshold%s+(%d+)$"))
        if value then
            EL.db.settings.alerts = EL.db.settings.alerts or {}
            EL.db.settings.alerts.concentrationThreshold = math.max(0, math.min(1000, value))
            EL:RequestUpdate()
            EL:Print(EL:T("Concentration alert threshold set to %d.", EL.db.settings.alerts.concentrationThreshold))
        end
    elseif msg == "restore" or msg == "unhideall" then
        EL:RestoreHiddenCharacters()
    else
        if EL.TogglePanel then EL:TogglePanel() end
    end
end

EL.frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then return end
        EL:EnsureDB()
        if EL.ApplyVisualTheme then EL:ApplyVisualTheme() end
        if EL.CaptureOnboardingLoadState then EL:CaptureOnboardingLoadState() end
        EL:GetCurrentCharacter()
        if EL.RefreshCurrentProfessionIdentity then EL:RefreshCurrentProfessionIdentity() end
        EL:ForEachModule("OnLoad")
        if EL.VerifyModuleInitialization then EL:VerifyModuleInitialization("PostLoad", true) end
        if EL.CreateUI then EL:CreateUI() end
        if EL.VerifyModuleInitialization then EL:VerifyModuleInitialization("PostCreateUI", true) end
        EL:ForEachModule("Refresh")
        EL:RequestUpdate()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if EL.FlushCombatDeferredWork then EL:FlushCombatDeferredWork() end
        if EL._pendingOnboarding and EL.ShowOnboardingPanel then
            EL._pendingOnboarding = nil
            EL:ShowOnboardingPanel(false)
        end
    elseif event == "PLAYER_LOGOUT" then
        if EL.SaveCurrentSessionHistory then EL:SaveCurrentSessionHistory("logout") end
        if EL.ClearProfessionNameCache then EL:ClearProfessionNameCache() end
    else
        if event == "PLAYER_ENTERING_WORLD" then
            if C_Timer and C_Timer.After then
                C_Timer.After(1, function()
                    if not EL or not EL.db then return end
                    if EL.RefreshCurrentProfessionIdentity then EL:RefreshCurrentProfessionIdentity() end
                    if EL.ForEachModule then EL:ForEachModule("Refresh") end
                    if EL.RequestUpdate then EL:RequestUpdate() end
                end)
            else
                if EL.RefreshCurrentProfessionIdentity then EL:RefreshCurrentProfessionIdentity() end
                if EL.ForEachModule then EL:ForEachModule("Refresh") end
            end
        elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "SKILL_LINES_CHANGED" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function()
                    if not EL or not EL.db then return end
                    if EL.RefreshCurrentProfessionIdentity then EL:RefreshCurrentProfessionIdentity() end
                    if EL.RequestUpdate then EL:RequestUpdate() end
                end)
            else
                if EL.RefreshCurrentProfessionIdentity then EL:RefreshCurrentProfessionIdentity() end
            end
        elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" or event == "SPELLS_CHANGED" or event == "BAG_UPDATE_DELAYED" then
            if EL.ShouldRefreshActionBar and EL:ShouldRefreshActionBar() and EL.RequestActionBarRefresh then EL:RequestActionBarRefresh() end
        end
        -- Module handlers intentionally run after the core event branch. Some
        -- events update shared identity/UI state here and then allow modules to
        -- refresh their own cached resources.
        for _, module in pairs(EL.modules) do
            if module and module.OnEvent then
                pcall(module.OnEvent, module, event, ...)
            end
        end
    end
end)

local function RegisterCoreEvent(eventName)
    if not EL.frame or not eventName then return end
    local ok, err = pcall(EL.frame.RegisterEvent, EL.frame, eventName)
    if not ok and EL.Debug then
        EL:Debug("Skipping unsupported event: " .. tostring(eventName) .. " - " .. tostring(err))
    end
end

RegisterCoreEvent("ADDON_LOADED")
RegisterCoreEvent("PLAYER_ENTERING_WORLD")
RegisterCoreEvent("SKILL_LINES_CHANGED")
RegisterCoreEvent("TRADE_SKILL_SHOW")
RegisterCoreEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
RegisterCoreEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
RegisterCoreEvent("CURRENCY_DISPLAY_UPDATE")
RegisterCoreEvent("BAG_UPDATE_DELAYED")
RegisterCoreEvent("CHAT_MSG_LOOT")
RegisterCoreEvent("CHAT_MSG_TRADESKILLS")
RegisterCoreEvent("PLAYER_MONEY")
RegisterCoreEvent("MAIL_SHOW")
RegisterCoreEvent("MAIL_INBOX_UPDATE")
RegisterCoreEvent("MAIL_CLOSED")
RegisterCoreEvent("PLAYER_REGEN_ENABLED")
RegisterCoreEvent("PLAYER_LOGOUT")
RegisterCoreEvent("SPELLS_CHANGED")
RegisterCoreEvent("ZONE_CHANGED")
RegisterCoreEvent("ZONE_CHANGED_INDOORS")
RegisterCoreEvent("ZONE_CHANGED_NEW_AREA")
