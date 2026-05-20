local _, EL = ...
local M = {}
EL:RegisterModule("mulch", M)

local function GetItemCountSafe(itemID)
    if C_Item and C_Item.GetItemCount then
        local ok, count = pcall(C_Item.GetItemCount, itemID, false, false, false)
        if ok and count ~= nil then return (EL.SafeNumber and EL:SafeNumber(count, 0, "mulch.itemCount")) or tonumber(count) or 0 end
    end
    if GetItemCount then
        local ok, count = pcall(GetItemCount, itemID, false, false)
        if ok then return (EL.SafeNumber and EL:SafeNumber(count, 0, "mulch.legacyItemCount")) or tonumber(count) or 0 end
    end
    return 0
end

local function IsItemUsableSafe(itemID)
    if C_Item and C_Item.IsUsableItem then
        local ok, usable = pcall(C_Item.IsUsableItem, itemID)
        if ok then return usable and true or false end
    end
    if IsUsableItem then
        local ok, usable = pcall(IsUsableItem, itemID)
        if ok then return usable and true or false end
    end
    return false
end

local function GetCooldown(itemID)
    local startTime, duration
    if C_Item and C_Item.GetItemCooldown then
        local ok, startValue, durationValue = pcall(C_Item.GetItemCooldown, itemID)
        if ok then
            startTime, duration = startValue, durationValue
        end
    end
    if startTime == nil and GetItemCooldown then
        local ok, startValue, durationValue = pcall(GetItemCooldown, itemID)
        if ok then
            startTime, duration = startValue, durationValue
        end
    end
    startTime = (EL.SafeNumber and EL:SafeNumber(startTime, 0, "mulch.cooldownStart")) or tonumber(startTime) or 0
    duration = (EL.SafeNumber and EL:SafeNumber(duration, 0, "mulch.cooldownDuration")) or tonumber(duration) or 0
    return startTime, duration
end

function M:Refresh()
    local charKey, char = EL:GetCurrentCharacter()
    local hasHerbalism = EL:CharacterHasProfession(EL.HERBALISM_ID)
    local itemCount = GetItemCountSafe(EL.IMBUED_MULCH_ITEM_ID)
    local isUsable = IsItemUsableSafe(EL.IMBUED_MULCH_ITEM_ID)
    local startTime, duration = GetCooldown(EL.IMBUED_MULCH_ITEM_ID)

    EL.db.resources.mulch[charKey] = EL.db.resources.mulch[charKey] or {}
    local data = EL.db.resources.mulch[charKey]
    data.charKey = charKey
    data.charName = char.name
    data.realm = char.realm
    data.class = char.class
    data.itemID = EL.IMBUED_MULCH_ITEM_ID
    data.itemName = "Imbued Mulch"
    data.hasHerbalism = hasHerbalism
    data.isUsable = isUsable
    data.itemCount = itemCount

    local cooldownSeen = startTime and duration and startTime > 0 and duration > 0

    -- Confirm Imbued Mulch access from the current character only.
    -- Do not let old saved flags or merely owning the item mark a character as capable.
    local confirmedAccess = hasHerbalism and (isUsable or cooldownSeen)
    data.confirmedImbuedMulchAccess = confirmedAccess and true or nil
    data.hasImbuedMulchAccess = confirmedAccess and true or false
    data.itemKnown = confirmedAccess and true or nil
    data.confirmationSource = confirmedAccess and (cooldownSeen and "cooldown" or "usable") or nil
    data.confirmationVersion = confirmedAccess and 2 or nil
    data.lastUpdate = time()

    if confirmedAccess and cooldownSeen then
        local remaining = math.max(0, math.ceil((startTime + duration) - GetTime()))
        data.readyAt = time() + remaining
    elseif confirmedAccess then
        data.readyAt = 0
    else
        data.readyAt = nil
    end
end

function M:OnLoad()
    self:Refresh()
end

function M:OnEvent(event, ...)
    if event == "BAG_UPDATE_DELAYED" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        C_Timer.After(0.5, function()
            if not EL or not EL.db then return end
            self:Refresh()
            EL:RequestUpdate()
        end)
    end
end
