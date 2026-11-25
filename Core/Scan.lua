-- AH price scan: one SendSearchQuery per item, one in flight at a time, gated on the throttle system.
-- Pattern from _dev/research/ah-api.md (the one proven on Forever): wait for the item key info to be cached first
-- (searches for uncached keys are silently ignored), read the cheapest tier, retry on silence, give up after 2.
-- It only runs while the Snackrun tab is showing; leaving the tab pauses it, closing the AH stops it.
local _, SR = ...

local AH = C_AuctionHouse
local ANSWER_TIMEOUT, INFO_TIMEOUT, MAX_RETRY = 3, 5, 2

local S = { queue = {}, i = 0, running = false, paused = false }
SR.scan = S

local function Sorts()
    local order = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
    return { { sortOrder = order, reverseSort = false } }
end

local function Progress()
    SR.Notify("scan", S.i - 1, #S.queue, S.running)
end

local Send

local function Finish()
    S.running, S.cur, S.state = false, nil, nil
    Progress()
end

local function Next()
    S.i = S.i + 1
    S.cur, S.retries, S.state = S.queue[S.i], 0, nil
    Progress()
    if not S.cur then return Finish() end
    Send()
end

local function Record(price, qty)
    local p = SR.Prices()
    p[S.cur] = { p = price, q = qty or 0, t = time() }
    SR.Notify("prices", S.cur)
end

local function Retry()
    S.retries = S.retries + 1
    if S.retries > MAX_RETRY then
        Record(nil, 0) -- nothing came back: treat as not listed
        return Next()
    end
    Send()
end

Send = function()
    if not S.running or S.paused or not S.cur then return end
    if not AH.IsThrottledMessageSystemReady() then
        S.state = "throttle" -- resumes on AUCTION_HOUSE_THROTTLED_SYSTEM_READY
        return
    end
    local key = AH.MakeItemKey(S.cur)
    local info = AH.GetItemKeyInfo(key)
    if not info then
        S.state, S.sentAt = "info", GetTime() -- resumes on ITEM_KEY_ITEM_INFO_RECEIVED
        C_Item.RequestLoadItemDataByID(S.cur)
        return
    end
    S.key, S.commodity = key, info.isCommodity
    S.state, S.sentAt = "sent", GetTime()
    AH.SendSearchQuery(key, Sorts(), false)
end

function SR.StartScan(ids)
    if not ids or #ids == 0 then return end
    S.queue, S.i, S.running, S.paused = ids, 0, true, false
    Next()
end

function SR.StopScan()
    if S.running then Finish() end
end

function SR.PauseScan(on)
    S.paused = on
    if not on and S.running and S.state ~= "sent" then Send() end
end

-- Watchdog: no answer in time means retry.
C_Timer.NewTicker(0.25, function()
    if not S.running or S.paused then return end
    local wait = S.state == "sent" and ANSWER_TIMEOUT or S.state == "info" and INFO_TIMEOUT
    if wait and GetTime() - S.sentAt > wait then Retry() end
end)

SR.On("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function()
    if S.running and S.state == "throttle" then Send() end
end)

SR.On("ITEM_KEY_ITEM_INFO_RECEIVED", function(_, id)
    if S.running and S.state == "info" and id == S.cur then Send() end
end)

SR.On("AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED", function()
    if S.running and S.state == "sent" then
        S.state = "throttle"
        C_Timer.After(2, function() if S.running and S.state == "throttle" then Send() end end)
    end
end)

SR.On("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, id)
    if not S.running or S.state ~= "sent" or id ~= S.cur then return end
    local has = AH.HasSearchResults(S.key)
    local full = AH.HasFullCommoditySearchResults(id)
    local qty = AH.GetCommoditySearchResultsQuantity(id) or 0
    if not has or (not full and qty == 0) then return Retry() end -- Auctionator's validity check
    local first = AH.GetCommoditySearchResultInfo(id, 1)
    Record(first and first.unitPrice, qty)
    Next()
end)

SR.On("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey)
    if not S.running or S.state ~= "sent" or not itemKey or itemKey.itemID ~= S.cur then return end
    local best
    for i = 1, AH.GetNumItemSearchResults(itemKey) or 0 do
        local r = AH.GetItemSearchResultInfo(itemKey, i)
        if r and r.buyoutAmount and r.buyoutAmount > 0 then
            local unit = math.floor(r.buyoutAmount / math.max(1, r.quantity or 1))
            if not best or unit < best then best = unit end
        end
    end
    Record(best, AH.GetItemSearchResultsQuantity(itemKey) or 0)
    Next()
end)

SR.On("AUCTION_HOUSE_CLOSED", function() SR.StopScan() end)
