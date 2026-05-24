local _, EL = ...
local M = {}
EL:RegisterModule("session", M)

local EXCLUDED_ITEM_IDS = {
    [124124] = true, -- Blood of Sargeras style soulbound currency item from older content.
}

local EXCLUDED_NAME_PATTERNS = {
    -- Exclude vial-like trade goods that can look like materials but should not
    -- be counted as gathered profession-session items.
    "vial",
}

local TRUSTED_MAIL_KEYWORDS = {
    "patron",
    "crafting order",
    "work order",
}

local BLOCKED_MAIL_KEYWORDS = {
    "auction",
    "outbid",
    "sale pending",
    "expired",
}

local BAG_DIFF_DEBOUNCE_SECONDS = 0.75

local function TextContainsAny(value, patterns)
    local lower = tostring(value or ""):lower()
    if lower == "" then return false end
    for _, pattern in ipairs(patterns) do
        if lower:find(pattern, 1, true) then return true end
    end
    return false
end

local function N(value, fallback, context)
    return EL:SafeNumber(value, fallback, context)
end

local function GetInboxAttachmentQuantity(mailIndex, attachmentIndex)
    if type(GetInboxItem) ~= "function" then return 0 end
    local ok, _name, itemID, _texture, count = pcall(GetInboxItem, mailIndex, attachmentIndex)
    if not ok then return 0 end
    return itemID and (N(count, 0, "session.mailAttachmentCount") or 0) or 0
end

local function IsShownFrame(frame)
    return frame and frame.IsShown and frame:IsShown()
end

function EL:IsSessionInventoryTransferOpen()
    -- Bank, Warband bank, and mailbox item transfers should not be treated
    -- as newly gathered session loot. Keep this as a light UI-state guard so
    -- bag snapshots can still stay current while storage windows are open.
    return IsShownFrame(_G.BankFrame)
        or IsShownFrame(_G.BankPanel)
        or IsShownFrame(_G.AccountBankPanel)
        or IsShownFrame(_G.AccountBankFrame)
        or IsShownFrame(_G.WarbandBankFrame)
        or IsShownFrame(_G.GuildBankFrame)
        or IsShownFrame(_G.VoidStorageFrame)
        or IsShownFrame(_G.MailFrame)
end

function EL:IsSessionMoneyTransferOpen()
    -- Money changes from storage and transaction windows are usually transfers,
    -- auction/mail payouts, trades, or purchases rather than direct gameplay
    -- session income. Ignore them for raw-gold session tracking.
    return self:IsSessionInventoryTransferOpen()
        or IsShownFrame(_G.AuctionHouseFrame)
        or IsShownFrame(_G.AuctionFrame)
        or IsShownFrame(_G.TradeFrame)
end

local function GetItemInfoInstantSafe(itemLinkOrID)
    if not itemLinkOrID then return nil end
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local ok, itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = pcall(C_Item.GetItemInfoInstant, itemLinkOrID)
        if ok then return itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID end
    end
    if type(GetItemInfoInstant) == "function" then
        local ok, itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = pcall(GetItemInfoInstant, itemLinkOrID)
        if ok then return itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID end
    end
    return nil
end

local function GetItemName(itemID)
    if C_Item and type(C_Item.GetItemNameByID) == "function" then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok then return name end
    end
    if type(GetItemInfo) == "function" then
        local ok, name = pcall(GetItemInfo, itemID)
        if ok then return name end
    end
    return nil
end

local function GetItemIcon(itemID)
    if C_Item and type(C_Item.GetItemIconByID) == "function" then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok then return icon end
    end
    if type(GetItemInfoInstant) == "function" then
        local ok, _itemID, _itemType, _itemSubType, _itemEquipLoc, icon = pcall(GetItemInfoInstant, itemID)
        if ok then return icon end
    end
    return nil
end

local function GetContainerNumSlotsSafe(bag)
    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function" then return 0 end
    local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
    return ok and (N(slots, 0, "session.containerSlots") or 0) or 0
end

local function GetContainerItemInfoSafe(bag, slot)
    if not C_Container or type(C_Container.GetContainerItemInfo) ~= "function" then return nil end
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" then return info end
    return nil
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

function EL:IsTrustedMailRewardTrackingEnabled()
    local settings = self.db and self.db.settings and self.db.settings.session or {}
    return settings.countTrustedMailRewards ~= false
end

function EL:IsCraftedSessionItemTrackingEnabled()
    local settings = self.db and self.db.settings and self.db.settings.session or {}
    return settings.countCraftedItems == true
end

local function ExtractCraftedItemFromEvent(...)
    local itemID, quantity

    -- Prefer item links/tables first. Numeric event args are less reliable because
    -- quantity and itemID are both numbers on some client builds.
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "string" then
            local link = value:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)") or value
            local parsed = GetItemInfoInstantSafe(link)
            if parsed then itemID = itemID or parsed end
            local stackText = value:match("x(%d+)")
            if stackText then quantity = quantity or tonumber(stackText) end
        elseif type(value) == "table" then
            local link = value.itemLink or value.hyperlink or value.link
            local parsed = link and GetItemInfoInstantSafe(link)
            itemID = itemID or parsed or value.itemID or value.id
            quantity = quantity or value.quantity or value.count or value.stackCount
        end
    end

    local numericItemCandidates = {}
    local numericQuantityCandidates = {}
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "number" and value > 0 then
            if not itemID then
                local parsed = GetItemInfoInstantSafe(value)
                if parsed then
                    table.insert(numericItemCandidates, parsed)
                end
            end
            if value < 10000 then
                table.insert(numericQuantityCandidates, value)
            end
        end
    end

    if not itemID and #numericItemCandidates > 0 then
        table.sort(numericItemCandidates, function(a, b) return (tonumber(a) or 0) > (tonumber(b) or 0) end)
        itemID = numericItemCandidates[1]
    end

    if not quantity then
        for _, value in ipairs(numericQuantityCandidates) do
            if not itemID or value ~= itemID then
                quantity = value
                break
            end
        end
    end

    return tonumber(itemID), math.max(tonumber(quantity) or 1, 1)
end

function EL:MarkPendingSessionCraftedItem(itemID, quantity)
    if not self:IsCraftedSessionItemTrackingEnabled() then return end
    if not itemID or not quantity or quantity <= 0 then return end
    local s = self:GetSessionDB()
    if s.isPaused then return end
    local now = GetTime()
    local pending = s.pendingCraftedItems[itemID]
    if pending and (pending.expiresAt or 0) > now then
        if (now - (tonumber(pending.lastMarkedAt) or 0)) < 0.30 then
            pending.quantity = math.max(tonumber(pending.quantity) or 0, quantity)
        else
            pending.quantity = (tonumber(pending.quantity) or 0) + quantity
        end
        pending.expiresAt = now + self.SESSION_DEDUPE_SECONDS
        pending.lastMarkedAt = now
    else
        s.pendingCraftedItems[itemID] = { quantity = quantity, expiresAt = now + self.SESSION_DEDUPE_SECONDS, lastMarkedAt = now }
    end
    if self.DebugThrottled then self:DebugThrottled("session.crafted.queue." .. tostring(itemID), 1, "Queued pending crafted item dedupe: item " .. tostring(itemID) .. " x" .. tostring(quantity) .. ".") elseif self.Debug then self:Debug("Queued pending crafted item dedupe: item " .. tostring(itemID) .. " x" .. tostring(quantity) .. ".") end
end

function EL:IsPendingSessionCraftedItem(itemID)
    if not self:IsCraftedSessionItemTrackingEnabled() then return false end
    if not itemID then return false end
    local s = self:GetSessionDB()
    local pending = s.pendingCraftedItems and s.pendingCraftedItems[itemID]
    if not pending then return false end
    if (pending.expiresAt or 0) <= GetTime() then
        s.pendingCraftedItems[itemID] = nil
        return false
    end
    return (tonumber(pending.quantity) or 0) > 0
end

function EL:ConsumePendingSessionCraftedItem(itemID, quantity)
    if not self:IsCraftedSessionItemTrackingEnabled() then return 0 end
    if not itemID or not quantity or quantity <= 0 then return 0 end
    local s = self:GetSessionDB()
    local pending = s.pendingCraftedItems and s.pendingCraftedItems[itemID]
    if not pending then return 0 end
    if (pending.expiresAt or 0) <= GetTime() then
        s.pendingCraftedItems[itemID] = nil
        if self.DebugThrottled then self:DebugThrottled("session.crafted.expired." .. tostring(itemID), 2, "Expired pending crafted item dedupe for item " .. tostring(itemID) .. ".") elseif self.Debug then self:Debug("Expired pending crafted item dedupe for item " .. tostring(itemID) .. ".") end
        return 0
    end
    local pendingQty = tonumber(pending.quantity) or 0
    local consumed = math.min(quantity, pendingQty)
    pending.quantity = pendingQty - consumed
    if pending.quantity <= 0 then s.pendingCraftedItems[itemID] = nil end
    if consumed > 0 then if self.DebugThrottled then self:DebugThrottled("session.crafted.consume." .. tostring(itemID), 1, "Consumed pending crafted item dedupe: item " .. tostring(itemID) .. " x" .. tostring(consumed) .. ".") elseif self.Debug then self:Debug("Consumed pending crafted item dedupe: item " .. tostring(itemID) .. " x" .. tostring(consumed) .. ".") end end
    return consumed
end

function EL:IsTrustedSessionRewardMail(sender, subject, codAmount, itemCount, isGM)
    if not self:IsTrustedMailRewardTrackingEnabled() then return false end
    if (tonumber(codAmount) or 0) > 0 then return false end
    if (tonumber(itemCount) or 0) <= 0 then return false end

    -- Avoid obvious auction/transaction mail. These can contain valuable items,
    -- but counting them would turn session tracking into mailbox accounting.
    if TextContainsAny(sender, BLOCKED_MAIL_KEYWORDS) or TextContainsAny(subject, BLOCKED_MAIL_KEYWORDS) then
        return false
    end

    -- Keep this intentionally narrow: patron/crafting order reward mail can
    -- contain reagent rewards that represent earned profession-session value.
    -- Player mail, alt transfers, bank shuffling, and auction mail remain ignored.
    return isGM == true
        or TextContainsAny(sender, TRUSTED_MAIL_KEYWORDS)
        or TextContainsAny(subject, TRUSTED_MAIL_KEYWORDS)
end

function EL:ClearTrustedSessionMailCache()
    local s = self:GetSessionDB()
    s.trustedMailItems = {}
end

function EL:RefreshTrustedSessionMailCache()
    local s = self:GetSessionDB()
    s.trustedMailItems = {}
    if not self:IsTrustedMailRewardTrackingEnabled() then return end
    if not IsShownFrame(_G.MailFrame) then return end
    if not GetInboxNumItems or not GetInboxHeaderInfo or not GetInboxItemLink then return end

    local okCount, numItems = pcall(GetInboxNumItems)
    numItems = okCount and (tonumber(numItems) or 0) or 0
    for mailIndex = 1, numItems do
        local okHeader, _, _, sender, subject, _, codAmount, _, itemCount, _, _, _, _, isGM = pcall(GetInboxHeaderInfo, mailIndex)
        if okHeader and self:IsTrustedSessionRewardMail(sender, subject, codAmount, itemCount, isGM) then
            for attachmentIndex = 1, tonumber(itemCount) or 0 do
                local itemLink = GetInboxItemLink(mailIndex, attachmentIndex)
                local itemID = itemLink and GetItemInfoInstantSafe(itemLink)
                if itemID and self:IsSessionTrackedItem(itemID) then
                    local qty = GetInboxAttachmentQuantity(mailIndex, attachmentIndex)
                    if qty > 0 then
                        s.trustedMailItems[itemID] = (tonumber(s.trustedMailItems[itemID]) or 0) + qty
                    end
                end
            end
        end
    end
end

function EL:ConsumeTrustedSessionMailItem(itemID, quantity)
    if not itemID or not quantity or quantity <= 0 then return 0 end
    if not self:IsTrustedMailRewardTrackingEnabled() then return 0 end
    local s = self:GetSessionDB()
    if type(s.trustedMailItems) ~= "table" then return 0 end
    local allowed = tonumber(s.trustedMailItems[itemID]) or 0
    if allowed <= 0 then return 0 end
    local consumed = math.min(quantity, allowed)
    s.trustedMailItems[itemID] = allowed - consumed
    if s.trustedMailItems[itemID] <= 0 then s.trustedMailItems[itemID] = nil end
    return consumed
end

function EL:CountSessionItemsInBags()
    local profile = self.ProfileStart and self:ProfileStart("CountSessionItemsInBags") or nil
    local counts = {}
    if self.IsSessionTrackingEnabled and not self:IsSessionTrackingEnabled() then if self.ProfileStop then self:ProfileStop("CountSessionItemsInBags", profile) end return counts end
    local maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, maxBag do
        local slots = GetContainerNumSlotsSafe(bag)
        for slot = 1, slots do
            local info = GetContainerItemInfoSafe(bag, slot)
            local itemID = info and info.itemID
            local stackCount = N(info and info.stackCount, 0, "session.containerStackCount") or 0
            if itemID and (self:IsSessionTrackedItem(itemID) or (self.IsPendingSessionCraftedItem and self:IsPendingSessionCraftedItem(itemID))) then
                counts[itemID] = (counts[itemID] or 0) + stackCount
            end
        end
    end
    if self.ProfileStop then self:ProfileStop("CountSessionItemsInBags", profile) end
    return counts
end

local function PushRecent(session, entry)
    -- Keep a chronological loot log for the session panel. Newest entries stay
    -- at the top, but the UI no longer sorts them by value or quantity.
    -- This makes the session list behave like a real scrolling loot feed.
    table.insert(session.recent, 1, entry)
    while #session.recent > 100 do table.remove(session.recent) end
end


local function SortBagSummaryLines(a, b)
    local av = tonumber(a and a.totalSilver) or 0
    local bv = tonumber(b and b.totalSilver) or 0
    if av ~= bv then return av > bv end
    return (a and a.name or "") < (b and b.name or "")
end

function EL:GetCurrentBagSummaryLines()
    local summary = { lines = {}, totalSilver = 0, totalQuantity = 0 }
    local counts = {}
    local maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, maxBag do
        local slots = GetContainerNumSlotsSafe(bag)
        for slot = 1, slots do
            local info = GetContainerItemInfoSafe(bag, slot)
            local itemID = info and info.itemID
            local count = N(info and info.stackCount, 0, "session.summaryStackCount") or 0
            if itemID and count and count > 0 and self:IsSessionTrackedItem(itemID) then
                counts[itemID] = (counts[itemID] or 0) + count
            end
        end
    end
    for itemID, quantity in pairs(counts) do
        local unitPrice = (self.GetUnitPriceSilver and self:GetUnitPriceSilver(itemID)) or 0
        local total = (tonumber(unitPrice) or 0) * (tonumber(quantity) or 0)
        summary.totalSilver = summary.totalSilver + total
        summary.totalQuantity = summary.totalQuantity + quantity
        table.insert(summary.lines, {
            itemID = itemID,
            name = GetItemName(itemID) or ("item:" .. tostring(itemID)),
            icon = GetItemIcon(itemID),
            quantity = quantity,
            unitPrice = unitPrice or 0,
            totalSilver = total,
            category = self.GetSessionItemCategory and self:GetSessionItemCategory(itemID) or "other",
        })
    end
    table.sort(summary.lines, SortBagSummaryLines)
    return summary
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
    if self.DebugThrottled then self:DebugThrottled("session.chat.queue." .. tostring(itemID), 1, "Queued pending chat-loot dedupe: item " .. tostring(itemID) .. " x" .. tostring(quantity) .. ".") elseif self.Debug then self:Debug("Queued pending chat-loot dedupe: item " .. tostring(itemID) .. " x" .. tostring(quantity) .. ".") end
end

function EL:ConsumePendingSessionChatLoot(itemID, quantity)
    if self.IsSessionTrackingEnabled and not self:IsSessionTrackingEnabled() then return quantity end
    if not itemID or not quantity or quantity <= 0 then return quantity end
    local s = self:GetSessionDB()
    local pending = s.pendingChatLoot[itemID]
    if not pending then return quantity end
    if (pending.expiresAt or 0) <= GetTime() then
        s.pendingChatLoot[itemID] = nil
        if self.DebugThrottled then self:DebugThrottled("session.chat.expired." .. tostring(itemID), 2, "Expired pending chat-loot dedupe for item " .. tostring(itemID) .. ".") elseif self.Debug then self:Debug("Expired pending chat-loot dedupe for item " .. tostring(itemID) .. ".") end
        return quantity
    end
    local pendingQty = tonumber(pending.quantity) or 0
    local consumed = math.min(quantity, pendingQty)
    pending.quantity = pendingQty - consumed
    if pending.quantity <= 0 then s.pendingChatLoot[itemID] = nil end
    if consumed > 0 then if self.DebugThrottled then self:DebugThrottled("session.chat.consume." .. tostring(itemID), 1, "Consumed pending chat-loot dedupe: item " .. tostring(itemID) .. " x" .. tostring(consumed) .. ".") elseif self.Debug then self:Debug("Consumed pending chat-loot dedupe: item " .. tostring(itemID) .. " x" .. tostring(consumed) .. ".") end end
    return quantity - consumed
end

function EL:AddSessionLootValue(itemID, quantity, allowUntracked)
    if self.IsSessionTrackingEnabled and not self:IsSessionTrackingEnabled() then return end
    if not itemID or not quantity or quantity <= 0 then return end
    if not allowUntracked and not self:IsSessionTrackedItem(itemID) then
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
    if EL.IsSessionInventoryTransferOpen and EL:IsSessionInventoryTransferOpen() then return end
    local itemLink = string.match(msg, "(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then return end
    -- Use the safe wrapper (consistent with the rest of this file) instead of
    -- a bare C_Item call, which would error on clients where C_Item is absent.
    local itemID = GetItemInfoInstantSafe(itemLink)
    if not itemID or not EL:IsSessionTrackedItem(itemID) then return end
    local quantity = tonumber(string.match(msg, "x(%d+)")) or 1
    -- Credit the chat loot immediately, then queue the same quantity so the
    -- following bag diff can consume it instead of adding it a second time.
    EL:RecordPendingSessionChatLoot(itemID, quantity)
    EL:AddSessionLootValue(itemID, quantity)
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
    local profile = EL.ProfileStart and EL:ProfileStart("ProcessBagDiff") or nil
    if EL.IsSessionTrackingEnabled and not EL:IsSessionTrackingEnabled() then if EL.ProfileStop then EL:ProfileStop("ProcessBagDiff", profile) end return end
    local s = EL:GetSessionDB()
    if s.isPaused then if EL.ProfileStop then EL:ProfileStop("ProcessBagDiff", profile) end return end
    local current = EL:CountSessionItemsInBags()

    -- Bank, Warband bank, and mailbox transfers can add tracked materials to
    -- bags without being gameplay loot. Refresh the baseline while these UIs
    -- are open so closing them does not create delayed false gains.
    if EL.IsSessionInventoryTransferOpen and EL:IsSessionInventoryTransferOpen() then
        if EL.DebugThrottled then EL:DebugThrottled("session.transfer.baseline", 2, "Session bag baseline refreshed during inventory transfer UI.") elseif EL.Debug then EL:Debug("Session bag baseline refreshed during inventory transfer UI.") end
        if IsShownFrame(_G.MailFrame) and EL.IsTrustedMailRewardTrackingEnabled and EL:IsTrustedMailRewardTrackingEnabled() then
            if EL.RefreshTrustedSessionMailCache and (not s.trustedMailItems or next(s.trustedMailItems) == nil) then
                EL:RefreshTrustedSessionMailCache()
            end
            for itemID, count in pairs(current) do
                local prev = tonumber(s.lastBagCounts[itemID]) or 0
                local diff = count - prev
                if diff > 0 and EL.ConsumeTrustedSessionMailItem then
                    local trusted = EL:ConsumeTrustedSessionMailItem(itemID, diff)
                    if trusted > 0 then
                        EL:AddSessionLootValue(itemID, trusted)
                    end
                end
            end
        end
        s.lastBagCounts = current
        s.bagBaselineReady = true
        s.baselinePrimingUntil = nil
        if EL.ProfileStop then EL:ProfileStop("ProcessBagDiff", profile) end
        return
    end

    -- On login/reload WoW often fires bag updates as bag data populates.
    -- During this short priming window, keep refreshing the baseline and never
    -- count existing bag contents as newly gathered session loot.
    if (tonumber(s.baselinePrimingUntil) or 0) > GetTime() then
        s.lastBagCounts = current
        s.bagBaselineReady = false
        if EL.DebugThrottled then EL:DebugThrottled("session.baseline.priming", 2, "Session bag baseline priming; ignored bag diff during startup/reset window.") elseif EL.Debug then EL:Debug("Session bag baseline priming; ignored bag diff during startup/reset window.") end
        if EL.ProfileStop then EL:ProfileStop("ProcessBagDiff", profile) end
        return
    end

    if not s.bagBaselineReady then
        s.lastBagCounts = current
        s.bagBaselineReady = true
        s.baselinePrimingUntil = nil
        if EL.ProfileStop then EL:ProfileStop("ProcessBagDiff", profile) end
        return
    end

    for itemID, count in pairs(current) do
        local prev = tonumber(s.lastBagCounts[itemID]) or 0
        local diff = count - prev
        if diff > 0 then
            if EL.DebugThrottled then EL:DebugThrottled("session.bagdiff." .. tostring(itemID), 1, "Session bag diff detected: item " .. tostring(itemID) .. " +" .. tostring(diff) .. ".") elseif EL.Debug then EL:Debug("Session bag diff detected: item " .. tostring(itemID) .. " +" .. tostring(diff) .. ".") end
            local crafted = (EL.ConsumePendingSessionCraftedItem and EL:ConsumePendingSessionCraftedItem(itemID, diff)) or 0
            if crafted > 0 then
                EL:AddSessionLootValue(itemID, crafted, true)
            end
            local remaining = diff - crafted
            if remaining > 0 then
                remaining = EL:ConsumePendingSessionChatLoot(itemID, remaining)
                if remaining > 0 then
                    if EL.DebugThrottled then EL:DebugThrottled("session.bagdiff.remaining." .. tostring(itemID), 1, "Session bag diff remaining after dedupe: item " .. tostring(itemID) .. " x" .. tostring(remaining) .. ".") elseif EL.Debug then EL:Debug("Session bag diff remaining after dedupe: item " .. tostring(itemID) .. " x" .. tostring(remaining) .. ".") end
                    EL:AddSessionLootValue(itemID, remaining)
                end
            end
        end
    end
    s.lastBagCounts = current
    EL:RequestUpdate()
    if EL.ProfileStop then EL:ProfileStop("ProcessBagDiff", profile) end
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

function M:ProcessCraftedItemResult(...)
    if EL.IsSessionTrackingEnabled and not EL:IsSessionTrackingEnabled() then return end
    if EL.IsCraftedSessionItemTrackingEnabled and not EL:IsCraftedSessionItemTrackingEnabled() then return end
    if EL.IsSessionInventoryTransferOpen and EL:IsSessionInventoryTransferOpen() then return end
    local itemID, quantity = ExtractCraftedItemFromEvent(...)
    if not itemID or quantity <= 0 then return end
    EL:MarkPendingSessionCraftedItem(itemID, quantity)
end

function M:ProcessCraftedItemMessage(msg)
    if EL.IsSessionTrackingEnabled and not EL:IsSessionTrackingEnabled() then return end
    if EL.IsCraftedSessionItemTrackingEnabled and not EL:IsCraftedSessionItemTrackingEnabled() then return end
    if EL.IsSessionInventoryTransferOpen and EL:IsSessionInventoryTransferOpen() then return end
    if not msg then return end
    local itemLink = tostring(msg):match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then return end
    local itemID = GetItemInfoInstantSafe(itemLink)
    if not itemID then return end
    local quantity = tonumber(tostring(msg):match("x(%d+)")) or 1
    EL:MarkPendingSessionCraftedItem(itemID, quantity)
end

function M:QueueBagDiff(delay)
    if self._bagDiffPending then return end
    self._bagDiffPending = true
    local function run()
        self._bagDiffPending = nil
        if not EL or not EL.db then return end
        self:ProcessBagDiff()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or BAG_DIFF_DEBOUNCE_SECONDS, run)
    else
        run()
    end
end

function M:OnEvent(event, ...)
    if EL.IsSessionTrackingEnabled and not EL:IsSessionTrackingEnabled() then return end
    if event == "CHAT_MSG_LOOT" then
        self:ProcessChatLoot(...)
    elseif event == "CHAT_MSG_TRADESKILLS" then
        self:ProcessCraftedItemMessage(...)
    elseif event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        self:ProcessCraftedItemResult(...)
    elseif event == "BAG_UPDATE_DELAYED" then
        self:QueueBagDiff(BAG_DIFF_DEBOUNCE_SECONDS)
    elseif event == "PLAYER_MONEY" then
        local s = EL:GetSessionDB()
        local currentMoney = N(s.lastMoneyCopper, 0, "session.lastMoneyCopper") or 0
        if type(GetMoney) == "function" then
            local okMoney, money = pcall(GetMoney)
            if okMoney then currentMoney = N(money, currentMoney, "session.currentMoneyCopper") or currentMoney end
        end
        local previousMoney = N(s.lastMoneyCopper, currentMoney, "session.previousMoneyCopper") or currentMoney
        s.lastMoneyCopper = currentMoney
        if EL.IsSessionMoneyTransferOpen and EL:IsSessionMoneyTransferOpen() then
            if EL.DebugThrottled then EL:DebugThrottled("session.money.transfer", 2, "Ignored session money delta during transfer UI.") elseif EL.Debug then EL:Debug("Ignored session money delta during transfer UI.") end
            return
        end
        local delta = currentMoney - previousMoney
        if delta ~= 0 and EL.AddSessionMoneyDelta then
            EL:AddSessionMoneyDelta(delta)
        end
    elseif event == "MAIL_SHOW" or event == "MAIL_INBOX_UPDATE" then
        if EL.RefreshTrustedSessionMailCache then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.15, function()
                    if not EL or not EL.db then return end
                    EL:RefreshTrustedSessionMailCache()
                end)
            else
                EL:RefreshTrustedSessionMailCache()
            end
        end
    elseif event == "MAIL_CLOSED" then
        if EL.ClearTrustedSessionMailCache then EL:ClearTrustedSessionMailCache() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Core also calls module:Refresh() after login; this branch only handles
        -- session-specific money sync and the delayed bag baseline priming window.
        C_Timer.After(1, function()
            if not EL or not EL.db then return end
            if EL.SyncSessionMoneyBaseline then EL:SyncSessionMoneyBaseline() end
            if EL.Debug then EL:Debug("Session money baseline synced and bag baseline priming started.") end
        end)
        C_Timer.After(6.5, function()
            if not EL or not EL.db then return end
            self:PrimeBagBaseline(true)
            EL:RequestUpdate()
        end)
    end
end
