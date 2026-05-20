local _, EL = ...
local M = {}
EL:RegisterModule("concentration", M)

local function N(value, fallback, context)
    if EL and type(EL.SafeNumber) == "function" then
        return EL:SafeNumber(value, fallback, context)
    end
    return fallback
end

local function GetChildProfessionInfo()
    if not C_TradeSkillUI or type(C_TradeSkillUI.GetChildProfessionInfo) ~= "function" then return nil end
    local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
    if ok then return info end
    return nil
end

function M:RecordFromTradeSkill()
    if not C_TradeSkillUI or type(C_TradeSkillUI.GetConcentrationCurrencyID) ~= "function" then return end
    local info = GetChildProfessionInfo()
    if not info or not info.professionID then return end
    local skillLineID = N(info.professionID, nil, "concentration.childProfessionID")
    if not skillLineID then return end
    local parentProfessionID = N(info.parentProfessionID, nil, "concentration.parentProfessionID")
    local okCurrencyID, currencyID = pcall(C_TradeSkillUI.GetConcentrationCurrencyID, skillLineID)
    if not okCurrencyID or not currencyID or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return end
    local okCurrency, currency = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
    if not okCurrency or type(currency) ~= "table" then return end
    local quantity = N(currency.quantity, nil, "concentration.currency.quantity")
    if quantity == nil then return end
    local maxQuantity = N(currency.maxQuantity, EL.CONCENTRATION_MAX_DEFAULT, "concentration.currency.maxQuantity")

    local charKey, char = EL:GetCurrentCharacter()
    if not charKey or type(char) ~= "table" then return end
    local key = EL:MakeResourceKey(charKey, skillLineID)
    EL.db.resources.concentration[key] = EL.db.resources.concentration[key] or {}
    local data = EL.db.resources.concentration[key]
    data.charKey = charKey
    data.charName = char.name
    data.realm = char.realm
    data.class = char.class
    data.professionID = skillLineID
    data.parentProfessionID = parentProfessionID
    data.professionName = info.professionName or "Profession"
    data.currencyID = currencyID
    data.quantity = quantity or 0
    data.maxQuantity = maxQuantity or EL.CONCENTRATION_MAX_DEFAULT
    data.lastUpdate = time()
    if EL.InvalidateConcentrationIndex then EL:InvalidateConcentrationIndex() end
end

function M:RefreshKnownCurrencies()
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return end
    if not EL or not EL.db or not EL.db.resources then return end
    local charKey = EL:GetCharacterKey()
    if not charKey then return end
    local changed = false
    for _, data in pairs(EL.db.resources.concentration or {}) do
        if data.charKey == charKey and data.currencyID then
            local okCurrency, currency = pcall(C_CurrencyInfo.GetCurrencyInfo, data.currencyID)
            local quantity = okCurrency and type(currency) == "table" and N(currency.quantity, nil, "concentration.refresh.quantity") or nil
            if quantity ~= nil then
                data.quantity = quantity
                data.maxQuantity = N(currency.maxQuantity, data.maxQuantity or EL.CONCENTRATION_MAX_DEFAULT, "concentration.refresh.maxQuantity") or data.maxQuantity or EL.CONCENTRATION_MAX_DEFAULT
                data.lastUpdate = time()
                changed = true
            end
        end
    end
    if changed and EL.InvalidateConcentrationIndex then EL:InvalidateConcentrationIndex() end
end

function M:RefreshMoxieCurrencies()
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return end
    if not EL or not EL.db or not EL.db.resources then return end
    local charKey, char = EL:GetCurrentCharacter()
    if not charKey then return end

    EL.db.resources.moxie = type(EL.db.resources.moxie) == "table" and EL.db.resources.moxie or {}
    EL.db.resources.moxie[charKey] = type(EL.db.resources.moxie[charKey]) == "table" and EL.db.resources.moxie[charKey] or {}

    for _, prof in ipairs(EL:GetProfessionEntriesForCharacter(charKey) or {}) do
        local currencyID, professionID = EL:GetMoxieCurrencyIDForProfession(prof)
        if currencyID and professionID then
            local okCurrency, currency = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
            local quantity = okCurrency and type(currency) == "table" and N(currency.quantity, nil, "moxie.quantity") or nil
            if quantity ~= nil then
                local entry = EL.db.resources.moxie[charKey][professionID] or {}
                entry.charKey = charKey
                entry.charName = char and char.name or prof.charName
                entry.realm = char and char.realm or prof.realm
                entry.class = char and char.class or prof.class
                entry.professionID = professionID
                entry.professionName = prof.professionName or "Profession"
                entry.currencyID = currencyID
                entry.currencyName = currency.name
                entry.quantity = quantity or 0
                entry.maxQuantity = N(currency.maxQuantity, nil, "moxie.maxQuantity")
                entry.lastUpdate = time()
                EL.db.resources.moxie[charKey][professionID] = entry
            end
        end
    end
end

function M:Refresh()
    self:RefreshKnownCurrencies()
    self:RecordFromTradeSkill()
    self:RefreshMoxieCurrencies()
end

function M:OnLoad()
    self:Refresh()
end

function M:OnEvent(event, ...)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        C_Timer.After(0.2, function()
            if not EL or not EL.db then return end
            self:RecordFromTradeSkill()
            self:RefreshMoxieCurrencies()
            EL:RequestUpdate()
        end)
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        C_Timer.After(0.1, function()
            if not EL or not EL.db or not self then return end
            if self.RefreshKnownCurrencies then self:RefreshKnownCurrencies() end
            if self.RefreshMoxieCurrencies then self:RefreshMoxieCurrencies() end
            EL:RequestUpdate()
        end)
    end
end
