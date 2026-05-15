local addonName, EL = ...
local M = {}
EL:RegisterModule("session", M)

local EXCLUDED_ITEM_IDS = {
    [124124] = true, -- Blood of Sargeras style soulbound currency item from older content.
}

local EXCLUDED_NAME_PATTERNS = {
    "vial",
}

local function GetItemInfoInstantSafe(itemLinkOrID)
    if not itemLinkOrID or not C_Item or not C_Item.GetItemInfoInstant then return nil end
    local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = C_Item.GetItemInfoInstant(itemLinkOrID)
    return itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
end

local function GetItemName(itemID)
    if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(itemID) end
    local name = GetItemInfo and GetItemInfo(itemID)
    return name
end

local function GetItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(itemID) end
    local _, _, _, _, icon = GetItemInfoInstant and GetItemInfoInstant(itemID)
    return icon
end

local function GetTradeGoodsSubclassID(key, legacy)
    local tg = Enum and Enum.ItemTradeGoodsSubclass
    if tg then
        return tg[key] or tg[string.upper(key)]
    end
    return legacy
end

local TRACKED_TRADEGOODS_SUBCLASSES = {}
local TRADEGOODS_CATEGORY_BY_SUBCLASS = {}
local function AddTrackedSubclass(key, legacy, category)
    local id = GetTradeGoodsSubclassID(key, legacy)
    if id ~= nil then
        TRACKED_TRADEGOODS_SUBCLASSES[id] = true
        TRADEGOODS_CATEGORY_BY_SUBCLASS[id] = category or "other"
    end
end

AddTrackedSubclass("Herb", LE_ITEM_TRADEGOODS_SUBCLASS_HERB, "herbs")
AddTrackedSubclass("MetalAndStone", LE_ITEM_TRADEGOODS_SUBCLASS_METAL_AND_STONE, "ore")
AddTrackedSubclass("Cloth", LE_ITEM_TRADEGOODS_SUBCLASS_CLOTH, "cloth")
AddTrackedSubclass("Leather", LE_ITEM_TRADEGOODS_SUBCLASS_LEATHER, "leather")
AddTrackedSubclass("Enchanting", LE_ITEM_TRADEGOODS_SUBCLASS_ENCHANTING, "enchanting")
AddTrackedSubclass("Cooking", LE_ITEM_TRADEGOODS_SUBCLASS_COOKING, "fish")
AddTrackedSubclass("Elemental", LE_ITEM_TRADEGOODS_SUBCLASS_ELEMENTAL, "other")
AddTrackedSubclass("Jewelcrafting", LE_ITEM_TRADEGOODS_SUBCLASS_JEWELCRAFTING, "other")
AddTrackedSubclass("Inscription", LE_ITEM_TRADEGOODS_SUBCLASS_INSCRIPTION, "other")

local SUBTYPE_CATEGORY_WORDS = {
    herbs = { "herb" },
    ore = { "metal", "stone", "ore", "mining" },
    cloth = { "cloth" },
    leather = { "leather", "skin" },
    enchanting = { "enchant" },
    fish = { "fish", "fishing", "cooking", "meat" },
    other = { "elemental", "jewelcrafting", "inscription", "reagent", "optional" },
}

local function LooksLikeExcludedName(itemID)
    local name = GetItemName(itemID)
    if not name then return false end
    local lower = name:lower()
    for _, pattern in ipairs(EXCLUDED_NAME_PATTERNS) do
        if lower:find(pattern, 1, true) then return true end
    end
    return false
end

local function GetSessionMaterialCategory(subClassID, itemSubType)
    if subClassID and TRADEGOODS_CATEGORY_BY_SUBCLASS[subClassID] then
        return TRADEGOODS_CATEGORY_BY_SUBCLASS[subClassID]
    end
    local sub = tostring(itemSubType or ""):lower()
    for category, words in pairs(SUBTYPE_CATEGORY_WORDS) do
        for _, word in ipairs(words) do
            if sub:find(word, 1, true) then return category end
        end
    end
    return "other"
end

local function IsCategoryEnabled(settings, category)
    settings = settings or {}
    if category == "herbs" then return settings.trackHerbs ~= false end
    if category == "ore" then return settings.trackOre ~= false end
    if category == "cloth" then return settings.trackCloth ~= false end
    if category == "leather" then return settings.trackLeather ~= false end
    if category == "enchanting" then return settings.trackEnchanting ~= false end
    if category == "fish" then return settings.trackFish ~= false end
    return settings.trackOtherMaterials ~= false
end

function EL:IsSessionTrackedItem(itemLinkOrID)
    if self.IsSessionTrackingEnabled and not self:IsSessionTrackingEnabled() then return false end
    if not itemLinkOrID then return false end
    local itemID, _, itemSubType, _, _, classID, subClassID = GetItemInfoInstantSafe(itemLinkOrID)
    if not itemID or EXCLUDED_ITEM_IDS[itemID] then return false end
    if LooksLikeExcludedName(itemID) then return false end

    local settings = self.db and self.db.settings and self.db.settings.session or {}
    local category = GetSessionMaterialCategory(subClassID, itemSubType)
    if classID == self.TRADEGOODS_CLASS then
        return IsCategoryEnabled(settings, category)
    end

    -- Some fish or profession-style materials can show outside Trade Goods depending on expansion/item setup.
    if category == "fish" then
        return settings.trackFish ~= false
    end

    return false
end

function EL:GetSessionItemCategory(itemLinkOrID)
    local _, _, itemSubType, _, _, classID = GetItemInfoInstantSafe(itemLinkOrID)
    if classID == self.TRADEGOODS_CLASS then
        return itemSubType or "Trade Goods"
    end
    local sub = tostring(itemSubType or "Other")
    if sub == "" then sub = "Other" end
    return sub
end

function EL:CountSessionItemsInBags()
    local counts = {}
    if self.IsSessionTrackingEnabled and not self:IsSessionTrackingEnabled() then return counts end
    if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then return counts end
    local maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, maxBag do
        local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and info.itemID
            if itemID and self:IsSessionTrackedItem(itemID) then
                counts[itemID] = (counts[itemID] or 0) + (info.stackCount or 0)
            end
        end
    end
    return counts
end

local function PushRecent(session, entry)
    -- Keep a chronological loot log for the session panel. Newest entries stay
    -- at the top, but the UI no longer sorts them by value or quantity.
    -- This makes the session list behave like a real scrolling loot feed.
    table.insert(session.recent, 1, entry)
    while #session.recent > 100 do table.remove(session.recent) end
end

function EL:RecordPendingSessionChatLoot(itemID, quantity)
    if self.IsSessionTrackingEnabled and not self:IsSessionTrackingEnabled() then return end
    if not itemID or not quantity or quantity <= 0 then return end
    local s = self:GetSessionDB()
    local now = GetTime()
    local pending = s.pendingChatLoot[itemID]
    if pending and (pending.expiresAt or 0) > now then
        pending.quantity = (pending.quantity or 0) + quantity
        pending.expiresAt = now + self.SESSION_DEDUPE_SECONDS
    else
        s.pendingChatLoot[itemID] = { quantity = quantity, expiresAt = now + self.SESSION_DEDUPE_SECONDS }
    end
end

function EL:ConsumePendingSessionChatLoot(itemID, quantity)
    if self.IsSessionTrackingEnabled and not self:IsSessionTrackingEnabled() then return quantity end
    if not itemID or not quantity or quantity <= 0 then return quantity end
    local s = self:GetSessionDB()
    local pending = s.pendingChatLoot[itemID]
    if not pending then return quantity end
    if (pending.expiresAt or 0) <= GetTime() then
        s.pendingChatLoot[itemID] = nil
        return quantity
    end
    local consumed = math.min(quantity, tonumber(pending.quantity) or 0)
    pending.quantity = (tonumber(pending.quantity) or 0) - consumed
    if pending.quantity <= 0 then s.pendingChatLoot[itemID] = nil end
    return quantity - consumed
end

function EL:AddSessionLootValue(itemID, quantity)
    if self.IsSessionTrackingEnabled and not self:IsSessionTrackingEnabled() then return end
    if not itemID or not quantity or quantity <= 0 then return end
    if not self:IsSessionTrackedItem(itemID) then
        if self.Debug then self:Debug("Ignored session item: " .. tostring(itemID)) end
        return
    end
    local s = self:GetSessionDB()
    if s.isPaused then return end

    local unitPriceSilver = self:GetUnitPriceSilver(itemID)
    local pickupSilver = 0
    if unitPriceSilver and unitPriceSilver > 0 then
        pickupSilver = unitPriceSilver * quantity
        s.totalSilver = (tonumber(s.totalSilver) or 0) + pickupSilver
    end

    local itemName = GetItemName(itemID) or ("item:" .. tostring(itemID))
    local itemIcon = GetItemIcon(itemID)
    local category = self:GetSessionItemCategory(itemID)
    local stat = s.items[itemID]
    if not stat then
        stat = { itemID = itemID, qty = 0, silver = 0, loots = 0, unitPrice = 0, name = itemName, icon = itemIcon, category = category }
        s.items[itemID] = stat
    end
    stat.qty = (tonumber(stat.qty) or 0) + quantity
    stat.silver = (tonumber(stat.silver) or 0) + pickupSilver
    stat.loots = (tonumber(stat.loots) or 0) + 1
    stat.unitPrice = unitPriceSilver or stat.unitPrice or 0
    stat.name = itemName
    stat.icon = itemIcon
    stat.category = category
    stat.lastSeen = time()

    local cat = s.categoryTotals[category] or { items = 0, silver = 0 }
    cat.items = (tonumber(cat.items) or 0) + quantity
    cat.silver = (tonumber(cat.silver) or 0) + pickupSilver
    s.categoryTotals[category] = cat

    if self.Debug then self:Debug("Tracked session item: " .. tostring(itemName) .. " x" .. tostring(quantity)) end

    PushRecent(s, {
        itemID = itemID,
        name = itemName,
        icon = itemIcon,
        count = quantity,
        category = category,
        moneyText = pickupSilver > 0 and self:FormatMoneyText(pickupSilver) or "no price",
    })
end

function M:ProcessChatLoot(msg)
    if EL.IsSessionTrackingEnabled and not EL:IsSessionTrackingEnabled() then return end
    if not msg then return end
    local itemLink = string.match(msg, "(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then return end
    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if not itemID or not EL:IsSessionTrackedItem(itemID) then return end
    local quantity = tonumber(string.match(msg, "x(%d+)")) or 1
    EL:RecordPendingSessionChatLoot(itemID, quantity)
    EL:AddSessionLootValue(itemID, quantity)
    EL:RequestUpdate()
end

function M:PrimeBagBaseline(forceReady)
    if EL.IsSessionTrackingEnabled and not EL:IsSessionTrackingEnabled() then return end
    local s = EL:GetSessionDB()
    if s.isPaused then return end
    s.lastBagCounts = EL:CountSessionItemsInBags()
    if forceReady or ((tonumber(s.baselinePrimingUntil) or 0) <= GetTime()) then
        s.bagBaselineReady = true
        s.baselinePrimingUntil = nil
    end
end

function M:ProcessBagDiff()
    if EL.IsSessionTrackingEnabled and not EL:IsSessionTrackingEnabled() then return end
    local s = EL:GetSessionDB()
    if s.isPaused then return end
    local current = EL:CountSessionItemsInBags()

    -- On login/reload WoW often fires bag updates as bag data populates.
    -- During this short priming window, keep refreshing the baseline and never
    -- count existing bag contents as newly gathered session loot.
    if (tonumber(s.baselinePrimingUntil) or 0) > GetTime() then
        s.lastBagCounts = current
        s.bagBaselineReady = false
        return
    end

    if not s.bagBaselineReady then
        s.lastBagCounts = current
        s.bagBaselineReady = true
        s.baselinePrimingUntil = nil
        return
    end

    for itemID, count in pairs(current) do
        local prev = tonumber(s.lastBagCounts[itemID]) or 0
        local diff = count - prev
        if diff > 0 then
            local remaining = EL:ConsumePendingSessionChatLoot(itemID, diff)
            if remaining > 0 then
                EL:AddSessionLootValue(itemID, remaining)
            end
        end
    end
    s.lastBagCounts = current
    EL:RequestUpdate()
end

function M:Refresh()
    if EL.IsSessionTrackingEnabled and not EL:IsSessionTrackingEnabled() then return end
    local s = EL:GetSessionDB()
    if s.isPaused then return end
    if (tonumber(s.baselinePrimingUntil) or 0) > GetTime() then
        s.lastBagCounts = EL:CountSessionItemsInBags()
        s.bagBaselineReady = false
        return
    end
    if not s.bagBaselineReady then
        s.lastBagCounts = EL:CountSessionItemsInBags()
        s.bagBaselineReady = true
        s.baselinePrimingUntil = nil
    end
end

function M:OnLoad()
    EL:GetSessionDB()
    if EL.IsSessionTrackingEnabled and EL:IsSessionTrackingEnabled() then
        EL:AutoStartSessionOnLogin()
    end
end

function M:OnEvent(event, ...)
    if EL.IsSessionTrackingEnabled and not EL:IsSessionTrackingEnabled() then return end
    if event == "CHAT_MSG_LOOT" then
        self:ProcessChatLoot(...)
    elseif event == "BAG_UPDATE_DELAYED" then
        C_Timer.After(0.2, function()
            if not EL or not EL.db then return end
            self:ProcessBagDiff()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            if not EL or not EL.db then return end
            EL:AutoStartSessionOnLogin()
            self:Refresh()
            EL:RequestUpdate()
            if EL.Debug then EL:Debug("Session reset and bag baseline priming started.") end
        end)
        C_Timer.After(5.5, function()
            if not EL or not EL.db then return end
            self:PrimeBagBaseline(true)
            EL:RequestUpdate()
        end)
    end
end
