local addonName, EL = ...
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

function M:Refresh()
    self:RefreshKnownCurrencies()
    self:RecordFromTradeSkill()
end

function M:OnLoad()
    self:Refresh()
end

function M:OnEvent(event, ...)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        C_Timer.After(0.2, function()
            self:RecordFromTradeSkill()
            EL:RequestUpdate()
        end)
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        C_Timer.After(0.1, function()
            self:RefreshKnownCurrencies()
            EL:RequestUpdate()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            self:Refresh()
            EL:RequestUpdate()
        end)
    end
end
