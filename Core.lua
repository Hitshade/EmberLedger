local addonName, EL = ...
_G.EmberLedger = EL

EL.name = addonName or "EmberLedger"
EL.version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.3.7"
EL.frame = CreateFrame("Frame")
EL.modules = {}
EL.DB_KEY_SEP = "\031"
EL.CONCENTRATION_MAX_DEFAULT = 1000
EL.CONCENTRATION_RATE_PER_HOUR = 10
EL.IMBUED_MULCH_ITEM_ID = 238388
EL.TRADEGOODS_CLASS = Enum.ItemClass and Enum.ItemClass.Tradegoods or 7
EL.CONSUMABLE_CLASS = Enum.ItemClass and Enum.ItemClass.Consumable or 0
EL.SESSION_DEDUPE_SECONDS = 5
EL.HERBALISM_ID = 182

EL.UI_CONSTANTS = {
    PANEL_MIN_W = 352,
    TRACKING_DYNAMIC_MIN_W = 230,
    TRACKING_COMPACT_MIN_W = 210,
    PANEL_MIN_H = 120,
    SESSION_MIN_W = 320,
    SESSION_EXPANDED_H = 166,
    SESSION_COLLAPSED_H = 36,
    ACTION_BAR_H = 36,
    SESSION_VISIBLE_ITEM_ROWS = 4,
    SESSION_ITEM_ROW_H = 18,
    PANEL_DEFAULT_VISIBLE_ROWS = 12,
    PANEL_EXPANDED_MIN_H = 300,
    PANEL_MAX_W = 900,
    PANEL_MAX_H = 720,
    PANEL_MIN_SCALE = 0.6,
    PANEL_MAX_SCALE = 1.4,
}

EL.DB_VERSION = 10307


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
    characters = {},
    resources = {
        concentration = {},
        mulch = {},
        professions = {},
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
            sessionCollapsed = false,
            charactersShown = true,
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
            collapsed = false,
            pricingSource = "Auctionator",
            topItems = 50,
            trackHerbs = true,
            trackOre = true,
            trackCloth = true,
            trackLeather = true,
            trackEnchanting = true,
            trackFish = true,
            trackOtherMaterials = true,
        },
        alerts = {
            concentrationThreshold = 360,
        },
        display = {
            panelOpacity = 0.55,
            launcherOpacity = 0.50,
            sessionOpacity = 0.55,
            showLauncherConc = true,
            showLauncherMulch = true,
            showLauncherSession = true,
            showLauncherSessionTotal = true,
            showLauncherSessionTime = true,
            showProfessionColumn = true,
            showConcentrationColumn = true,
            showProfession1Column = true,
            showConcentration1Column = true,
            showProfession2Column = true,
            showConcentration2Column = true,
            showMulchColumn = true,
            showCharacterRealm = true,
            attentionOnly = false,
            compactMode = false,
            showPinnedFirst = true,
            highlightCurrentCharacter = true,
            showFavoritesFirst = true, -- legacy saved key retained for compatibility
        },
        performance = {
            sessionTracking = true,
            actionBar = true,
        },
        hiddenCharacters = {},
        favoriteCharacters = {},
        options = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        },
        lockWindows = false,
        debug = false,
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
            if type(db.settings.session) == "table" and db.settings.session.collapsed == nil then
                db.settings.session.collapsed = db.settings.panel.sessionCollapsed and true or false
            end
            db.settings.panel.sessionCollapsed = nil
        end
    end

    -- totalItems is no longer displayed and was a frequent source of legacy noise.
    -- Keep item/value data, but allow the aggregate count to be rebuilt later if needed.
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

function EL:RunDatabaseCleanup(previousVersion)
    local current = tonumber(previousVersion) or tonumber(self.db and self.db.version) or 0
    if current < self.DB_VERSION then
        RemoveLegacySavedVariableFields(self.db)
        CleanupSavedCharacterFlags(self.db)
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

function EL:NormalizeDatabaseSettings()
    if type(self.db) ~= "table" or type(self.db.settings) ~= "table" then return end
    local settings = self.db.settings
    self.db.characters = type(self.db.characters) == "table" and self.db.characters or {}
    self.db.resources = type(self.db.resources) == "table" and self.db.resources or {}
    self.db.resources.concentration = type(self.db.resources.concentration) == "table" and self.db.resources.concentration or {}
    self.db.resources.mulch = type(self.db.resources.mulch) == "table" and self.db.resources.mulch or {}
    self.db.resources.professions = type(self.db.resources.professions) == "table" and self.db.resources.professions or {}

    settings.display = settings.display or {}
    settings.alerts = settings.alerts or {}
    settings.panel = settings.panel or {}
    settings.session = settings.session or {}
    settings.button = settings.button or {}
    settings.hiddenCharacters = settings.hiddenCharacters or {}
    settings.favoriteCharacters = settings.favoriteCharacters or {}
    settings.options = type(settings.options) == "table" and settings.options or {}

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

    settings.display.panelOpacity = ClampNumber(settings.display.panelOpacity, 0.20, 1.00, 0.55)
    settings.display.launcherOpacity = ClampNumber(settings.display.launcherOpacity, 0.20, 1.00, 0.50)
    settings.display.sessionOpacity = ClampNumber(settings.display.sessionOpacity, 0.20, 1.00, 0.55)
    if settings.display.showProfession1Column == nil then settings.display.showProfession1Column = settings.display.showProfessionColumn ~= false end
    if settings.display.showConcentration1Column == nil then settings.display.showConcentration1Column = settings.display.showConcentrationColumn ~= false end
    if settings.display.showProfession2Column == nil then settings.display.showProfession2Column = true end
    if settings.display.showConcentration2Column == nil then settings.display.showConcentration2Column = true end
    if settings.display.showMulchColumn == nil then settings.display.showMulchColumn = true end
    if settings.display.showCharacterRealm == nil then settings.display.showCharacterRealm = true end
    if settings.display.attentionOnly == nil then settings.display.attentionOnly = false end
    if settings.display.compactMode == nil then settings.display.compactMode = false end
    if settings.display.showPinnedFirst == nil then
        settings.display.showPinnedFirst = settings.display.showFavoritesFirst
        if settings.display.showPinnedFirst == nil then settings.display.showPinnedFirst = true end
    end
    -- Keep the old saved-variable key synchronized so v0.18-v0.20 users retain their setting.
    settings.display.showFavoritesFirst = settings.display.showPinnedFirst
    settings.display.showProfession1Column = settings.display.showProfession1Column ~= false
    settings.display.showConcentration1Column = settings.display.showConcentration1Column ~= false
    settings.display.showProfession2Column = settings.display.showProfession2Column ~= false
    settings.display.showConcentration2Column = settings.display.showConcentration2Column ~= false
    settings.display.showMulchColumn = settings.display.showMulchColumn ~= false
    settings.display.showCharacterRealm = settings.display.showCharacterRealm ~= false
    settings.display.attentionOnly = settings.display.attentionOnly == true
    settings.display.compactMode = settings.display.compactMode == true
    settings.display.showPinnedFirst = settings.display.showPinnedFirst ~= false
    settings.display.showFavoritesFirst = settings.display.showPinnedFirst
    settings.display.showProfessionColumn = settings.display.showProfession1Column
    settings.display.showConcentrationColumn = settings.display.showConcentration1Column
    if settings.display.showProfession1Column == false and settings.display.showConcentration1Column == false and settings.display.showProfession2Column == false and settings.display.showConcentration2Column == false and settings.display.showMulchColumn == false then
        settings.display.showProfession1Column = true
        settings.display.showProfessionColumn = true
    end
    CleanupSavedCharacterFlags(self.db)
    settings.alerts.concentrationThreshold = math.floor(ClampNumber(settings.alerts.concentrationThreshold, 0, self.CONCENTRATION_MAX_DEFAULT, 360))

    local ui = self.UI_CONSTANTS or {}
    local minScale = ui.PANEL_MIN_SCALE or 0.6
    local maxScale = ui.PANEL_MAX_SCALE or 1.4
    settings.panel.scale = ClampNumber(settings.panel.scale, minScale, maxScale, 1)
    settings.session.scale = ClampNumber(settings.session.scale, minScale, maxScale, 1)

    settings.panel.width = math.floor(ClampNumber(settings.panel.width, ui.TRACKING_DYNAMIC_MIN_W or ui.PANEL_MIN_W or 352, ui.PANEL_MAX_W or 900, 352))
    settings.panel.height = math.floor(ClampNumber(settings.panel.height, ui.PANEL_MIN_H or 120, ui.PANEL_MAX_H or 720, 360))
    settings.session.width = math.floor(ClampNumber(settings.session.width, ui.SESSION_MIN_W or 320, ui.PANEL_MAX_W or 900, ui.SESSION_MIN_W or 320))
    settings.session.height = math.floor(ClampNumber(settings.session.height, 120, ui.PANEL_MAX_H or 720, 180))

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

    settings.panel.charactersCollapsed = false
    settings.session.collapsed = false
    settings.panel.sessionCollapsed = nil
end

function EL:Debug(msg)
    if self.db and self.db.settings and self.db.settings.debug then
        print("|cff9ecbffEmberLedger Debug:|r " .. tostring(msg))
    end
end

function EL:ToggleDebug()
    self.db.settings.debug = not self.db.settings.debug
    self:Print("Debug " .. (self.db.settings.debug and "enabled." or "disabled."))
end

function EL:IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

function EL:RequestActionBarRefresh()
    if self:IsCombatLocked() then
        self.pendingActionBarRefresh = true
        return
    end
    if self.UpdateActionBar then self:UpdateActionBar() end
end

function EL:FlushCombatDeferredWork()
    if self.pendingActionBarRefresh then
        self.pendingActionBarRefresh = nil
        if self.UpdateActionBar then self:UpdateActionBar() end
    end
    if self.pendingSecureLayout then
        self.pendingSecureLayout = nil
        if self.LayoutPanel then self:LayoutPanel() end
        if self.AutoSizePanelHeight then self:AutoSizePanelHeight("combatDeferred") end
        if self.RequestUpdate then self:RequestUpdate() end
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

    -- v0.8.2: internal collapse controls were removed when the character and
    -- session modules became independently toggled/windows. Clear old collapse
    -- state so stale SavedVariables cannot create blank panels after reload.
    local uiRefactorVersion = tonumber(self.db.uiRefactorVersion) or 0
    if uiRefactorVersion < 820 then
        self.db.settings = self.db.settings or {}
        self.db.settings.panel = self.db.settings.panel or {}
        self.db.settings.session = self.db.settings.session or {}
        self.db.settings.panel.charactersCollapsed = false
        self.db.settings.session.collapsed = false
        self.db.uiRefactorVersion = 820
    end

    -- v0.4.20: clear older Imbued Mulch capability flags that were based on
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

    -- v0.4.25: normalize launcher opacity default to 50% for the redesigned launcher/settings panel.
    local uiOptionsVersion = tonumber(self.db.uiOptionsVersion) or 0
    if uiOptionsVersion < 425 then
        self.db.settings = self.db.settings or {}
        self.db.settings.display = self.db.settings.display or {}
        self.db.settings.display.launcherOpacity = 0.50
        self.db.uiOptionsVersion = 425
    end

    -- v0.9.1: align standalone Session window width with the minimum Profession Tracking window width.
    -- Preserve intentionally wider user values, but pull old default-width saves down to the cleaner compact width.
    -- v0.17.6/17.7: compact tracking layout; session width tightened further.
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

    -- v0.17.6: compact tracking layout hides the summary ticker and trims bottom padding.

    -- v0.17.7: compact tracking layout also hides the subtitle and tightens top padding.
    if rawSessionWidthVersion < 1750 then
        self.db.settings = self.db.settings or {}
        self.db.settings.session = self.db.settings.session or {}
        local session = self.db.settings.session
        if session.width == nil or tonumber(session.width) <= 360 then
            session.width = 320
        end
        self.db.sessionWidthVersion = 1750
    end

    -- v0.19.0+: polish pass. Remove stale hidden/pinned character flags and normalize table containers after the v0.18 pinning update.
    -- v0.20.0: UI-only refinement pass. Existing favoriteCharacters saved key remains as a backward-compatible storage key for pinned character data.
    local polishVersion = tonumber(self.db.polishVersion) or 0
    if polishVersion < 1900 then
        CleanupSavedCharacterFlags(self.db)
        self.db.polishVersion = 1900
    end

    self:NormalizeDatabaseSettings()
    return EmberLedgerDB
end

function EL:GetRealm()
    return GetNormalizedRealmName() or GetRealmName() or "UnknownRealm"
end

function EL:GetCharacterKey(name, realm)
    name = name or UnitName("player") or "Unknown"
    realm = realm or self:GetRealm()
    return name .. "-" .. realm
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
    c.key = key
    c.name = name
    c.realm = realm
    c.displayName = name .. "-" .. realm
    c.class = classFile or c.class
    c.lastSeen = time()
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
    module.name = name
    module.EL = self
end

function EL:ForEachModule(fn)
    for _, module in pairs(self.modules) do
        if module and module[fn] then
            local ok, err = pcall(module[fn], module)
            if not ok and self.db and self.db.settings and self.db.settings.debug then
                self:Print("Module error [" .. tostring(module.name or "?") .. "." .. tostring(fn) .. "]: " .. tostring(err))
            end
        end
    end
end

function EL:MakeResourceKey(charKey, resourceKey)
    return charKey .. self.DB_KEY_SEP .. tostring(resourceKey or "default")
end

function EL:FormatDuration(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return "Ready" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %02dm", hours, mins)
    elseif mins > 0 then
        return string.format("%dm", mins)
    else
        return "<1m"
    end
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

function EL:CharacterHasProfession(skillLineID)
    local professions = { GetProfessions() }
    for _, profIndex in ipairs(professions) do
        if profIndex then
            local _, _, _, _, _, _, skillLine = GetProfessionInfo(profIndex)
            if tonumber(skillLine) == tonumber(skillLineID) then
                return true
            end
        end
    end
    return false
end

function EL:RefreshCurrentProfessionIdentity()
    if not GetProfessions or not GetProfessionInfo then return false end
    self.db = self.db or {}
    self.db.resources = type(self.db.resources) == "table" and self.db.resources or {}
    self.db.resources.professions = type(self.db.resources.professions) == "table" and self.db.resources.professions or {}

    local charKey, char = self:GetCurrentCharacter()
    if not charKey then return false end

    local prof1, prof2 = GetProfessions()
    local slots = { prof1, prof2 }
    local list = {}

    for slotIndex, profIndex in ipairs(slots) do
        if profIndex then
            local name, icon, skillLevel, maxSkillLevel, _, _, skillLine = GetProfessionInfo(profIndex)
            if name and name ~= "" then
                list[#list + 1] = {
                    charKey = charKey,
                    charName = char and char.name or UnitName("player") or "Unknown",
                    realm = char and char.realm or self:GetRealm(),
                    class = char and char.class,
                    slot = slotIndex,
                    professionID = tonumber(skillLine) or skillLine,
                    skillLineID = tonumber(skillLine) or skillLine,
                    professionName = name,
                    icon = icon,
                    skillLevel = tonumber(skillLevel) or 0,
                    maxSkillLevel = tonumber(maxSkillLevel) or 0,
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
    if char then
        char.professions = list
    end
    return true
end

function EL:GetProfessionEntriesForCharacter(charKey)
    local out = {}
    local stored = self.db and self.db.resources and self.db.resources.professions and self.db.resources.professions[charKey]
    if type(stored) == "table" then
        for _, data in ipairs(stored) do
            if type(data) == "table" and (data.professionName or data.professionID or data.skillLineID) then
                table.insert(out, data)
            end
        end
    end

    if #out > 0 then
        table.sort(out, function(a, b)
            local as = tonumber(a.slot) or 99
            local bs = tonumber(b.slot) or 99
            if as ~= bs then return as < bs end
            return tostring(a.professionName or "") < tostring(b.professionName or "")
        end)
        return out
    end

    -- Compatibility fallback for older characters that have concentration data but have not logged in since v0.24.0.
    return self:GetConcentrationEntriesForCharacter(charKey)
end

function EL:GetConcentrationEntryForProfession(charKey, professionData)
    if not charKey or type(professionData) ~= "table" then return nil end
    local targetID = tonumber(professionData.professionID or professionData.skillLineID or professionData.skillLine)
    local targetName = self:GetCleanProfessionName(professionData.professionName):lower()
    local fallback

    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        if data and data.charKey == charKey then
            local dataID = tonumber(data.professionID or data.skillLineID or data.skillLine)
            if targetID and dataID and targetID == dataID then
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

function EL:GetDashboardProfessionSlots(charKey)
    local slots = {}
    local professions = self:GetProfessionEntriesForCharacter(charKey)
    local matchedConc = {}

    for _, profData in ipairs(professions or {}) do
        local concData = self:GetConcentrationEntryForProfession(charKey, profData)
        if concData then matchedConc[concData] = true end
        table.insert(slots, { prof = profData, conc = concData })
    end

    -- If profession identity is incomplete but concentration exists, keep the old
    -- concentration-only fallback so older character records still display.
    if #slots == 0 then
        for _, concData in ipairs(self:GetConcentrationEntriesForCharacter(charKey) or {}) do
            table.insert(slots, { prof = concData, conc = concData })
        end
    end

    -- If one of two known professions has concentration and the other does not,
    -- present the concentration profession in P1/Conc 1. This is display-only:
    -- stored profession slots are not changed.
    local concSlotIndex
    local concCount = 0
    for i, slotData in ipairs(slots) do
        if slotData and slotData.conc then
            concCount = concCount + 1
            concSlotIndex = i
        end
    end

    if concCount == 1 and concSlotIndex and concSlotIndex > 1 then
        local promoted = table.remove(slots, concSlotIndex)
        table.insert(slots, 1, promoted)
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

-- Expansion prefixes to strip from profession names so the UI stays
-- expansion-neutral. Add new expansion names here as they release.
local EXPANSION_PREFIXES = {
    "Midnight", "Khaz Algar", "Dragon Isles", "Shadowlands",
    "Battle for Azeroth", "Legion", "Warlords", "Pandaria",
    "Cataclysm", "Northrend", "Outland", "Classic",
}

function EL:GetCleanProfessionName(name)
    name = tostring(name or "")
    if name == "" then return "Profession" end
    local clean = name
    -- Store the full profession name internally, but keep the UI expansion-neutral.
    for _, prefix in ipairs(EXPANSION_PREFIXES) do
        clean = clean:gsub("^" .. prefix .. "%s+", "")
    end
    clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
    if clean == "" then clean = name end
    return clean
end

function EL:GetProfessionAbbreviation(data)
    if not data then return "N/A" end
    -- Prefer the explicit abbreviation table keyed by profession ID so known
    -- professions always get a consistent short name regardless of locale or
    -- how the name string is structured.
    local professionID = tonumber(data.professionID or data.skillLineID or data.skillLine)
    if professionID and self.PROFESSION_ABBREVIATIONS and self.PROFESSION_ABBREVIATIONS[professionID] then
        local abbr = self.PROFESSION_ABBREVIATIONS[professionID]
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
    local professionID = tonumber(data.professionID or data.skillLineID or data.skillLine)
    if professionID and self.PROFESSION_ICON_TEXTURES and self.PROFESSION_ICON_TEXTURES[professionID] then
        return self.PROFESSION_ICON_TEXTURES[professionID]
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
    -- Storage key remains favoriteCharacters for upgrade compatibility with v0.18-v0.20 saved variables.
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

-- Backward-compatible aliases for v0.18-v0.20 code paths and saved-variable wording.
function EL:IsCharacterFavorite(charKey) return self:IsCharacterPinned(charKey) end
function EL:SetCharacterFavorite(charKey, favorite) return self:SetCharacterPinned(charKey, favorite) end
function EL:ToggleCharacterFavorite(charKey) return self:ToggleCharacterPinned(charKey) end

function EL:ResetCharacterData(charKey)
    if not (self.db and charKey) then return false end
    local char = self.db and self.db.characters and self.db.characters[charKey]
    local displayName = (char and (char.displayName or char.name)) or charKey

    if self.db.characters then
        self.db.characters[charKey] = nil
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
        end
        if self.db.resources.professions then
            self.db.resources.professions[charKey] = nil
        end
    end

    if self.db.settings and self.db.settings.hiddenCharacters then
        self.db.settings.hiddenCharacters[charKey] = nil
    end

    self:RequestUpdate()
    self:Print("Reset data for: " .. tostring(displayName))
    return true
end

function EL:GetEffectiveMaxQuantity(maxQuantity)
    local maxQ = tonumber(maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
    if maxQ <= 0 then maxQ = self.CONCENTRATION_MAX_DEFAULT end

    local threshold = self.db and self.db.settings and self.db.settings.alerts and tonumber(self.db.settings.alerts.concentrationThreshold)
    if threshold and threshold > 0 then
        return math.max(1, math.min(maxQ, threshold))
    end

    return math.max(1, maxQ)
end

function EL:GetConcentrationColor(quantity, maxQuantity)
    local maxQ = self:GetEffectiveMaxQuantity(maxQuantity)
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
        return string.format("%dm %02ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
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
    if self.IsTrackingColumnVisible and not self:IsTrackingColumnVisible(key) then key = "character" end
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
    return math.max(0, (tonumber(data.readyAt) or 0) - (now or time()))
end

function EL:GetDashboardSortValue(entry, key, now)
    if not entry then return nil end
    now = now or time()
    local charKey, char = entry.key, entry.char
    if not charKey then return nil end
    if key == "character" then
        return tostring(self:GetCharacterDisplayName(char, charKey)):lower()
    elseif key == "prof" or key == "prof1" then
        local prof = self:GetDashboardProfessionData(charKey, 1)
        return prof and self:GetProfessionAbbreviation(prof):lower() or nil
    elseif key == "conc" or key == "conc1" then
        local _, conc = self:GetDashboardProfessionData(charKey, 1)
        return conc and (self:GetEstimatedConcentration(conc, now) or 0) or nil
    elseif key == "prof2" then
        local prof = self:GetDashboardProfessionData(charKey, 2)
        return prof and self:GetProfessionAbbreviation(prof):lower() or nil
    elseif key == "conc2" then
        local _, conc = self:GetDashboardProfessionData(charKey, 2)
        return conc and (self:GetEstimatedConcentration(conc, now) or 0) or nil
    elseif key == "full" then
        local conc = self:GetBestConcentrationForCharacter(charKey, now)
        if not conc then return nil end
        local maxQ = tonumber(conc.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
        local q = self:GetEstimatedConcentration(conc, now) or 0
        if q >= maxQ then return 0 end
        return math.ceil((maxQ - q) / self.CONCENTRATION_RATE_PER_HOUR * 3600)
    elseif key == "mulch" then
        return self:GetMulchSortValue(charKey, now)
    end
    return tostring(self:GetCharacterDisplayName(char, charKey)):lower()
end

function EL:SortDashboardRows(rows)
    if type(rows) ~= "table" then return end

    local sort = self:GetSortSettings()
    local key = sort.key or "character"
    if key == "prof" then key = "prof1" end
    if key == "conc" then key = "conc1" end
    if self.IsTrackingColumnVisible and not self:IsTrackingColumnVisible(key) then
        key = "character"
        sort.key = "character"
        sort.ascending = true
    end
    local ascending = sort.ascending ~= false
    local now = time()
    local clean = {}

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

    for i, entry in ipairs(rows) do
        if type(entry) == "table" and entry.key then
            local rawValue = self:GetDashboardSortValue(entry, key, now)
            local valueType, value = normalizeSortValue(rawValue)
            table.insert(clean, {
                row = entry,
                originalIndex = i,
                valueType = valueType,
                value = value,
                name = tostring(self:GetCharacterDisplayName(entry.char, entry.key)):lower(),
                key = tostring(entry.key or ""),
                pinned = self:IsCharacterPinned(entry.key),
            })
        end
    end

    table.sort(clean, function(a, b)
        -- Absolute safety. table.sort requires a strict weak ordering.
        if a == b then return false end
        if not a then return false end
        if not b then return true end

        local showPinnedFirst = self.db and self.db.settings and self.db.settings.display and self.db.settings.display.showPinnedFirst ~= false
        if showPinnedFirst and a.pinned ~= b.pinned then
            return a.pinned == true
        end

        local aNA = a.value == nil
        local bNA = b.value == nil

        -- Keep N/A values at the bottom in both directions.
        if aNA ~= bNA then
            return not aNA
        end

        -- Only compare the active sort value when both entries have one.
        if not aNA and not bNA then
            if a.valueType == b.valueType then
                if a.value ~= b.value then
                    if ascending then
                        return a.value < b.value
                    else
                        return b.value < a.value
                    end
                end
            else
                -- Deterministic fallback for mixed types. This should rarely happen,
                -- but avoids inconsistent comparisons if a column ever changes shape.
                if a.valueType ~= b.valueType then
                    return tostring(a.valueType or "") < tostring(b.valueType or "")
                end
            end
        end

        -- Tie breakers are always ascending and stable, regardless of selected direction.
        if a.name ~= b.name then return a.name < b.name end
        if a.key ~= b.key then return a.key < b.key end
        return (a.originalIndex or 0) < (b.originalIndex or 0)
    end)

    wipe(rows)
    for i, wrapped in ipairs(clean) do
        rows[i] = wrapped.row
    end
end

function EL:GetConcentrationEntriesForCharacter(charKey)
    local list = {}
    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        if data.charKey == charKey then
            table.insert(list, data)
        end
    end
    table.sort(list, function(a, b)
        local aa = self:GetProfessionAbbreviation(a)
        local bb = self:GetProfessionAbbreviation(b)
        if aa == bb then return tostring(a.professionName or "") < tostring(b.professionName or "") end
        return aa < bb
    end)
    return list
end

function EL:GetBestConcentrationForCharacter(charKey, now)
    local best
    now = now or time()
    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        if data.charKey == charKey then
            local qty = self:GetEstimatedConcentration(data, now)
            if not best or qty > (self:GetEstimatedConcentration(best, now) or 0) then
                best = data
            end
        end
    end
    return best
end

function EL:GetHighestConcentrationSummary()
    local best
    local now = time()
    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        if data and not self:IsCharacterHidden(data.charKey) then
            local char = self.db and self.db.characters and self.db.characters[data.charKey or ""]
            local qty = self:GetEstimatedConcentration(data, now)
            if not best or qty > best.quantity then
                best = {
                    charKey = data.charKey,
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
    return best
end


function EL:GetConcentrationReadyCount(threshold)
    threshold = tonumber(threshold) or 800
    local now = time()
    local seen = {}
    local count = 0
    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        local charKey = data and data.charKey
        if charKey and not seen[charKey] and not self:IsCharacterHidden(charKey) then
            local qty = self:GetEstimatedConcentration(data, now) or 0
            if qty >= threshold then
                seen[charKey] = true
                count = count + 1
            end
        end
    end
    return count
end

function EL:GetConcentrationReadyEntries(threshold, limit)
    threshold = tonumber(threshold) or 360
    local now = time()
    local entries = {}

    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        local charKey = data and data.charKey
        if charKey and not self:IsCharacterHidden(charKey) then
            local qty = self:GetEstimatedConcentration(data, now) or 0
            if qty >= threshold then
                local char = self.db and self.db.characters and self.db.characters[charKey]
                entries[#entries + 1] = {
                    type = "concentration",
                    charKey = charKey,
                    displayName = (char and (char.displayName or char.name)) or data.charName or "Unknown",
                    professionName = data.professionName or "Profession",
                    abbrev = self:GetProfessionAbbreviation(data),
                    quantity = qty,
                    maxQuantity = data.maxQuantity or self.CONCENTRATION_MAX_DEFAULT,
                    threshold = threshold,
                }
            end
        end
    end

    table.sort(entries, function(a, b)
        local aq, bq = tonumber(a.quantity) or 0, tonumber(b.quantity) or 0
        if aq ~= bq then return aq > bq end
        local an, bn = tostring(a.displayName or ""):lower(), tostring(b.displayName or ""):lower()
        if an ~= bn then return an < bn end
        return tostring(a.abbrev or "") < tostring(b.abbrev or "")
    end)

    if limit and #entries > limit then
        local trimmed = {}
        for i = 1, tonumber(limit) or #entries do trimmed[i] = entries[i] end
        return trimmed, #entries
    end

    return entries, #entries
end

function EL:GetMulchReadyCount()
    local now = time()
    local seen = {}
    local count = 0
    for _, data in pairs(self.db and self.db.resources and self.db.resources.mulch or {}) do
        local charKey = data and data.charKey
        if charKey and not seen[charKey] and not self:IsCharacterHidden(charKey) and self:HasImbuedMulchAccess(data) then
            local readyAt = tonumber(data.readyAt) or 0
            if readyAt <= now then
                seen[charKey] = true
                count = count + 1
            end
        end
    end
    return count
end

function EL:GetMulchReadyEntries(limit)
    local now = time()
    local seen = {}
    local entries = {}

    for _, data in pairs(self.db and self.db.resources and self.db.resources.mulch or {}) do
        local charKey = data and data.charKey
        if charKey and not seen[charKey] and not self:IsCharacterHidden(charKey) and self:HasImbuedMulchAccess(data) then
            local readyAt = tonumber(data.readyAt) or 0
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

    table.sort(entries, function(a, b)
        return tostring(a.displayName or ""):lower() < tostring(b.displayName or ""):lower()
    end)

    if limit and #entries > limit then
        local trimmed = {}
        for i = 1, tonumber(limit) or #entries do trimmed[i] = entries[i] end
        return trimmed, #entries
    end

    return entries, #entries
end

function EL:GetNeedsAttentionEntries(limit)
    local threshold = self.db and self.db.settings and self.db.settings.alerts and self.db.settings.alerts.concentrationThreshold or 360
    local combined = {}
    local concEntries = self:GetConcentrationReadyEntries(threshold)
    local mulchEntries = self:GetMulchReadyEntries()

    for _, entry in ipairs(concEntries or {}) do
        combined[#combined + 1] = entry
    end
    for _, entry in ipairs(mulchEntries or {}) do
        combined[#combined + 1] = entry
    end

    table.sort(combined, function(a, b)
        local ap = a.type == "mulch" and 1 or 2
        local bp = b.type == "mulch" and 1 or 2
        if ap ~= bp then return ap < bp end
        local an, bn = tostring(a.displayName or ""):lower(), tostring(b.displayName or ""):lower()
        if an ~= bn then return an < bn end
        return tostring(a.abbrev or a.itemName or "") < tostring(b.abbrev or b.itemName or "")
    end)

    if limit and #combined > limit then
        local trimmed = {}
        for i = 1, tonumber(limit) or #combined do trimmed[i] = combined[i] end
        return trimmed, #combined
    end

    return combined, #combined
end


function EL:DoesCharacterNeedAttention(charKey, threshold, now)
    if not charKey or self:IsCharacterHidden(charKey) then return false end
    threshold = tonumber(threshold) or (self.db and self.db.settings and self.db.settings.alerts and self.db.settings.alerts.concentrationThreshold) or 360
    now = now or time()

    for _, data in pairs(self.db and self.db.resources and self.db.resources.concentration or {}) do
        if data and data.charKey == charKey then
            local qty = self:GetEstimatedConcentration(data, now) or 0
            if qty >= threshold then
                return true
            end
        end
    end

    local mulchData = self.db and self.db.resources and self.db.resources.mulch and self.db.resources.mulch[charKey]
    if self:HasImbuedMulchAccess(mulchData) then
        local readyAt = tonumber(mulchData.readyAt) or 0
        if readyAt <= now then
            return true
        end
    end

    return false
end

function EL:GetEstimatedConcentration(data, now)
    if not data then return nil end
    now = now or time()
    local maxQ = tonumber(data.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
    local q = tonumber(data.quantity) or 0
    local last = tonumber(data.lastUpdate) or now
    if q >= maxQ then return maxQ end
    local gained = math.floor(math.max(0, now - last) * (self.CONCENTRATION_RATE_PER_HOUR / 3600))
    return math.min(maxQ, q + gained)
end

function EL:GetConcentrationFullIn(data, now)
    if not data then return "N/A" end
    now = now or time()
    local maxQ = tonumber(data.maxQuantity) or self.CONCENTRATION_MAX_DEFAULT
    local q = self:GetEstimatedConcentration(data, now) or 0
    if q >= maxQ then return "Full" end
    local missing = maxQ - q
    local seconds = math.ceil(missing / self.CONCENTRATION_RATE_PER_HOUR * 3600)
    return self:FormatDuration(seconds)
end

function EL:HasImbuedMulchAccess(data)
    if type(data) ~= "table" then return false end
    -- v0.4.20: only trust the stricter confirmation written by Modules/Mulch.lua.
    -- Older saved values could mark generic Herbalism characters as mulch-ready.
    return data.confirmedImbuedMulchAccess == true and tonumber(data.confirmationVersion) == 2
end


function EL:CopperToSilver(copper)
    copper = tonumber(copper) or 0
    if copper <= 0 then return 0 end
    return math.floor((copper + 50) / 100)
end

function EL:FormatMoneyText(silver)
    silver = math.max(0, math.floor(tonumber(silver) or 0))
    local gold = math.floor(silver / 100)
    local sil = silver % 100
    if gold >= 1000 then
        return string.format("%.1fk", gold / 1000)
    end
    return string.format("%dg %02ds", gold, sil)
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

function EL:GetUnitPriceSilver(itemID)
    local source = self.db and self.db.settings and self.db.settings.session and self.db.settings.session.pricingSource or "Auctionator"
    if source == "TSM" then
        return self:GetTSMUnitPriceSilver(itemID)
    end
    local auctionator = self:GetAuctionatorUnitPriceSilver(itemID)
    if auctionator and auctionator > 0 then return auctionator end
    return self:GetTSMUnitPriceSilver(itemID)
end

function EL:GetActivePricingSourceLabel()
    local source = self.db and self.db.settings and self.db.settings.session and self.db.settings.session.pricingSource or "Auctionator"
    if source == "TSM" then
        if self:IsAddOnLoaded("TradeSkillMaster") and TSM_API then return "TSM" end
        return "None detected"
    end
    if self:IsAddOnLoaded("Auctionator") and Auctionator and Auctionator.API and Auctionator.API.v1 then return "Auctionator" end
    if self:IsAddOnLoaded("TradeSkillMaster") and TSM_API then return "TSM fallback" end
    return "None detected"
end

function EL:GetPricingWarning()
    local source = self.db and self.db.settings and self.db.settings.session and self.db.settings.session.pricingSource or "Auctionator"
    if source == "TSM" then
        if not self:IsAddOnLoaded("TradeSkillMaster") then return "TSM missing" end
        if not TSM_API then return "TSM not ready" end
        return nil
    end
    if not self:IsAddOnLoaded("Auctionator") then return "Auctionator missing" end
    if not Auctionator or not Auctionator.API or not Auctionator.API.v1 then return "Auctionator not ready" end
    return nil
end

function EL:GetSessionDB()
    self.db.session = self.db.session or {}
    local s = self.db.session
    s.totalSilver = tonumber(s.totalSilver) or 0
    s.items = type(s.items) == "table" and s.items or {}
    s.recent = type(s.recent) == "table" and s.recent or {}
    s.pendingChatLoot = type(s.pendingChatLoot) == "table" and s.pendingChatLoot or {}
    s.lastBagCounts = type(s.lastBagCounts) == "table" and s.lastBagCounts or {}
    s.categoryTotals = type(s.categoryTotals) == "table" and s.categoryTotals or {}
    if s.isPaused == nil then s.isPaused = false end
    s.priorDuration = tonumber(s.priorDuration) or 0
    s.sessionStartUptime = tonumber(s.sessionStartUptime) or GetTime()
    return s
end

function EL:StartFreshSessionOnLogin()
    -- Runtime-only guard: reset once per login/reload, not every PLAYER_ENTERING_WORLD fire.
    if self.sessionResetThisLogin then return end
    self.sessionResetThisLogin = true

    self.db.session = {
        totalSilver = 0,
        items = {},
        recent = {},
        pendingChatLoot = {},
        lastBagCounts = {},
        categoryTotals = {},
        isPaused = false,
        priorDuration = 0,
        sessionStartUptime = GetTime(),
        bagBaselineReady = false,
        baselinePrimingUntil = GetTime() + 5,
    }
end

function EL:AutoStartSessionOnLogin()
    self:StartFreshSessionOnLogin()
end

function EL:GetSessionElapsedSeconds()
    local s = self:GetSessionDB()
    local prior = tonumber(s.priorDuration) or 0
    if s.isPaused then return math.max(1, prior) end
    return math.max(1, prior + math.max(0, math.floor(GetTime() - (tonumber(s.sessionStartUptime) or GetTime()))))
end

function EL:GetSessionGoldPerHour()
    local s = self:GetSessionDB()
    return math.floor(((tonumber(s.totalSilver) or 0) * 3600) / self:GetSessionElapsedSeconds())
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
    self.db.session = {
        totalSilver = 0,
        items = {},
        recent = {},
        pendingChatLoot = {},
        lastBagCounts = {},
        categoryTotals = {},
        isPaused = false,
        priorDuration = 0,
        sessionStartUptime = GetTime(),
        bagBaselineReady = false,
        baselinePrimingUntil = GetTime() + 2,
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
    table.sort(list, function(a, b)
        local av, bv = tonumber(a.silver) or 0, tonumber(b.silver) or 0
        if av ~= bv then return av > bv end
        local aq, bq = tonumber(a.qty) or 0, tonumber(b.qty) or 0
        if aq ~= bq then return aq > bq end
        return tostring(a.name or a.itemID or "") < tostring(b.name or b.itemID or "")
    end)
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

function EL:BuildSessionSummaryText()
    local s = self:GetSessionDB()
    local lines = {}
    table.insert(lines, "EmberLedger Session")
    table.insert(lines, "Time: " .. self:FormatDuration(self:GetSessionElapsedSeconds()))
    table.insert(lines, "Total: " .. self:FormatMoneyText(s.totalSilver or 0))
    table.insert(lines, "Rate: " .. self:FormatMoneyText(self:GetSessionGoldPerHour()) .. "/hr")
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

function EL:ShowCopySessionSummaryDialog()
    local text = self:BuildSessionSummaryText()
    if StaticPopupDialogs then
        StaticPopupDialogs["EMBERLEDGER_COPY_SESSION"] = StaticPopupDialogs["EMBERLEDGER_COPY_SESSION"] or {
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
            OnCancel = function(_, data, reason)
                if reason == "clicked" and EmberLedger and EmberLedger.PrintSessionSummaryToChat then
                    EmberLedger:PrintSessionSummaryToChat(data)
                end
            end,
        }
        StaticPopup_Show("EMBERLEDGER_COPY_SESSION", nil, nil, text)
    else
        self:PrintSessionSummaryToChat(text)
    end
end

function EL:GetNextMulchSummary()
    local best
    local now = time()
    for _, data in pairs(self.db and self.db.resources and self.db.resources.mulch or {}) do
        if self:HasImbuedMulchAccess(data) and not self:IsCharacterHidden(data.charKey) then
            local readyAt = tonumber(data.readyAt) or 0
            local remain = math.max(0, readyAt - now)
            if not best or remain < best.remaining then
                local char = self.db and self.db.characters and self.db.characters[data.charKey or ""]
                best = {
                    charKey = data.charKey,
                    displayName = (char and char.name) or data.charName or "Unknown",
                    remaining = remain,
                    readyAt = readyAt,
                }
            end
        end
    end
    return best
end

function EL:GetCharacterRows()
    local rows = {}
    for key, char in pairs(self.db and self.db.characters or {}) do
        table.insert(rows, { key = key, char = char })
    end
    table.sort(rows, function(a, b)
        local an = self:GetCharacterDisplayName(a.char, a.key)
        local bn = self:GetCharacterDisplayName(b.char, b.key)
        return tostring(an):lower() < tostring(bn):lower()
    end)
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

function EL:ShouldRefreshActionBar()
    if self.IsActionBarEnabled and not self:IsActionBarEnabled() then return false end
    local panel = self.panel
    if not (panel and panel:IsShown()) then return false end
    local bar = panel.actionBar
    return bar and bar:IsShown()
end

function EL:RequestUpdate()
    if self.UpdateButton then self:UpdateButton() end

    local panelShown = self.panel and self.panel:IsShown()
    if panelShown and self.RefreshPanel then self:RefreshPanel() end

    local sessionShown = self:IsSessionTrackingEnabled() and self.sessionWindow and self.sessionWindow:IsShown()
    if sessionShown and self.RefreshSessionPanel then self:RefreshSessionPanel() end

    if self:ShouldRefreshActionBar() and self.RequestActionBarRefresh then self:RequestActionBarRefresh() end
end

function EL:Print(msg)
    print("|cffff7a1aEmberLedger:|r " .. tostring(msg))
end

function EL:PrintSlashHelp()
    self:Print("Commands:")
    self:Print("/el or /ember - Toggle EmberLedger.")
    self:Print("/el settings - Open Options.")
    self:Print("/el session - Toggle the standalone Session window.")
    self:Print("/el refresh - Refresh tracked profession data.")
    self:Print("/el scale - Show the current main window scale.")
    self:Print("/el scale 0.85 - Set main window scale from 0.60 to 1.40.")
    self:Print("/el threshold 900 - Set concentration alert threshold.")
    self:Print("/el lock or /el unlock - Lock or unlock EmberLedger windows.")
    self:Print("/el reset layout - Reset window positions.")
    self:Print("/el reset session - Reset current session totals.")
    self:Print("/el restore - Restore hidden characters.")
    self:Print("/el reset pinned - Remove all pinned markers.")
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
            EL:Print("Window scale set to " .. string.format("%.2f", scale) .. ".")
        else
            EL:Print("Use /el scale 0.6 through /el scale 1.4")
        end
    elseif msg == "help" or msg == "?" then
        if EL.PrintSlashHelp then EL:PrintSlashHelp() end
    elseif msg == "scale" then
        local current = EL.db and EL.db.settings and EL.db.settings.panel and EL.db.settings.panel.scale or 1
        EL:Print("Current window scale: " .. string.format("%.2f", current) .. ". Use /el scale 0.85, /el scale 1, etc.")
    elseif msg == "reset" or msg == "reset windows" or msg == "reset layout" then
        if EL.ResetWindowPositions then EL:ResetWindowPositions() end
    elseif msg == "lock" or msg == "unlock" then
        EL.db.settings.lockWindows = (msg == "lock")
        if EL.RefreshSettingsPanel then EL:RefreshSettingsPanel() end
        EL:Print("Windows " .. (EL.db.settings.lockWindows and "locked. Hold Shift and drag to move them." or "unlocked."))
    elseif msg == "debug" then
        if EL.ToggleDebug then EL:ToggleDebug() end
    elseif msg == "refresh" then
        if EL.RefreshCurrentProfessionIdentity then EL:RefreshCurrentProfessionIdentity() end
        EL:ForEachModule("Refresh")
        EL:RequestUpdate()
        EL:Print("Refreshed.")
    elseif msg == "refresh professions" or msg == "professions" then
        if EL.RefreshCurrentProfessionIdentity and EL:RefreshCurrentProfessionIdentity() then
            EL:RequestUpdate()
            EL:Print("Profession identity refreshed.")
        else
            EL:Print("Profession identity could not be refreshed yet.")
        end
    elseif msg == "session start" or msg == "session resume" then
        EL:SetSessionPaused(false)
        EL:Print("Session tracking resumed.")
    elseif msg == "session pause" then
        EL:SetSessionPaused(true)
        EL:Print("Session tracking paused.")
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
    elseif msg == "settings" or msg == "options" then
        if EL.ToggleSettingsPanel then EL:ToggleSettingsPanel() end
    elseif msg:match("^threshold%s+%d+$") then
        local value = tonumber(msg:match("^threshold%s+(%d+)$"))
        if value then
            EL.db.settings.alerts = EL.db.settings.alerts or {}
            EL.db.settings.alerts.concentrationThreshold = math.max(0, math.min(1000, value))
            EL:RequestUpdate()
            EL:Print("Concentration alert threshold set to " .. tostring(EL.db.settings.alerts.concentrationThreshold) .. ".")
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
        EL:GetCurrentCharacter()
        if EL.RefreshCurrentProfessionIdentity then EL:RefreshCurrentProfessionIdentity() end
        EL:ForEachModule("OnLoad")
        if EL.CreateUI then EL:CreateUI() end
        EL:ForEachModule("Refresh")
        EL:RequestUpdate()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if EL.FlushCombatDeferredWork then EL:FlushCombatDeferredWork() end
    else
        if event == "PLAYER_ENTERING_WORLD" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "SKILL_LINES_CHANGED" then
            local delay = (event == "PLAYER_ENTERING_WORLD") and 1 or 0.2
            if C_Timer and C_Timer.After then
                C_Timer.After(delay, function()
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
        for _, module in pairs(EL.modules) do
            if module and module.OnEvent then
                pcall(module.OnEvent, module, event, ...)
            end
        end
    end
end)

EL.frame:RegisterEvent("ADDON_LOADED")
EL.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
EL.frame:RegisterEvent("SKILL_LINES_CHANGED")
EL.frame:RegisterEvent("TRADE_SKILL_SHOW")
EL.frame:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
EL.frame:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
EL.frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
EL.frame:RegisterEvent("BAG_UPDATE_DELAYED")
EL.frame:RegisterEvent("CHAT_MSG_LOOT")
EL.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
EL.frame:RegisterEvent("SPELLS_CHANGED")
EL.frame:RegisterEvent("ZONE_CHANGED")
EL.frame:RegisterEvent("ZONE_CHANGED_INDOORS")
EL.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
