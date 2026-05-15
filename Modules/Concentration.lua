local _, EL = ...
local M = {}
EL:RegisterModule("concentration", M)

local function GetChildProfessionInfo()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetChildProfessionInfo then return nil end
    return C_TradeSkillUI.GetChildProfessionInfo()
end

function M:RecordFromTradeSkill()
    if not C_TradeSkillUI or type(C_TradeSkillUI.GetConcentrationCurrencyID) ~= "function" then return end
    local info = GetChildProfessionInfo()
    if not info or not info.professionID then return end
    local skillLineID = info.professionID
    local currencyID = C_TradeSkillUI.GetConcentrationCurrencyID(skillLineID)
    if not currencyID or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return end
    local currency = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not currency or type(currency.quantity) ~= "number" then return end

    local charKey, char = EL:GetCurrentCharacter()
    local key = EL:MakeResourceKey(charKey, skillLineID)
    EL.db.resources.concentration[key] = EL.db.resources.concentration[key] or {}
    local data = EL.db.resources.concentration[key]
    data.charKey = charKey
    data.charName = char.name
    data.realm = char.realm
    data.class = char.class
    data.professionID = skillLineID
    data.professionName = info.professionName or "Profession"
    data.currencyID = currencyID
    data.quantity = currency.quantity or 0
    data.maxQuantity = currency.maxQuantity or EL.CONCENTRATION_MAX_DEFAULT
    data.lastUpdate = time()
end

function M:RefreshKnownCurrencies()
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return end
    local charKey = EL:GetCharacterKey()
    for _, data in pairs(EL.db.resources.concentration or {}) do
        if data.charKey == charKey and data.currencyID then
            local currency = C_CurrencyInfo.GetCurrencyInfo(data.currencyID)
            if currency and type(currency.quantity) == "number" then
                data.quantity = currency.quantity
                data.maxQuantity = currency.maxQuantity or data.maxQuantity or EL.CONCENTRATION_MAX_DEFAULT
                data.lastUpdate = time()
            end
        end
    end
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
            local currency = C_CurrencyInfo.GetCurrencyInfo(currencyID)
            if currency and type(currency.quantity) == "number" then
                local entry = EL.db.resources.moxie[charKey][professionID] or {}
                entry.charKey = charKey
                entry.charName = char and char.name or prof.charName
                entry.realm = char and char.realm or prof.realm
                entry.class = char and char.class or prof.class
                entry.professionID = professionID
                entry.professionName = prof.professionName or "Profession"
                entry.currencyID = currencyID
                entry.currencyName = currency.name
                entry.quantity = currency.quantity or 0
                entry.maxQuantity = currency.maxQuantity
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
            if not EL or not EL.db then return end
            self:RefreshKnownCurrencies()
            self:RefreshMoxieCurrencies()
            EL:RequestUpdate()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            if not EL or not EL.db then return end
            self:Refresh()
            EL:RequestUpdate()
        end)
    end
end
