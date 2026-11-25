-- Builds the shopping list: Auto (from class, spec, weapons and the slider level) or a hand-picked profile.
-- Auto rules, in order:
--   1. an item shows when its main effect is wanted, or any effect is CORE (weight 1, Data/Specs.lua)
--   2. one-at-a-time slots (Well Fed, flasks, drunk) only show for a CORE want
--   3. class and weapon restrictions apply; items above the slider level are left out
--   4. in a `line`, the best tier usable at the slider level wins; lower tiers are "outclassed": dimmed with Want 0,
--      and only listed while you still carry some (an empty outclassed tier is noise)
-- Custom profiles show exactly their items: no rules, no dimming. Items above your real level get "AT nn" either way.
local _, SR = ...

local SECTION = {}
for i, s in ipairs(SR.SECTIONS) do s.index = i; SECTION[s.key] = s end
SR.SECTION = SECTION

--------------------------------------------------------------------------------
-- Item names and icons. Names need the item cache: ask for missing ones and redraw when they arrive.
--------------------------------------------------------------------------------
local waiting = {}
function SR.ItemInfo(id)
    local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
    if not name then
        if not waiting[id] then
            waiting[id] = true
            C_Item.RequestLoadItemDataByID(id)
        end
        icon = icon or select(5, C_Item.GetItemInfoInstant(id))
    end
    return name, quality or 1, icon
end

local namesDue
SR.On("GET_ITEM_INFO_RECEIVED", function(_, id)
    if not waiting[id] then return end
    waiting[id] = nil
    if namesDue then return end
    namesDue = true
    C_Timer.After(0.2, function() namesDue = nil; SR.Notify("names") end)
end)

--------------------------------------------------------------------------------
-- Want: the item's default unless this character changed it (then saved per item, shared by every profile).
--------------------------------------------------------------------------------
function SR.DefaultWant(id)
    local item = SR.ITEMS[id]
    return item.want or SECTION[item.sec].want
end

function SR.Want(id)
    local set = SR.char.wants[id]
    if set then return set, true end
    return SR.DefaultWant(id), false
end

function SR.SetWant(id, n)
    n = tonumber(n)
    if not n then return end
    n = math.max(0, math.min(9999, math.floor(n)))
    SR.char.wants[id] = n ~= SR.DefaultWant(id) and n or nil
    SR.Notify("want", id)
end

function SR.ResetWant(id)
    SR.char.wants[id] = nil
    SR.Notify("want", id)
end

--------------------------------------------------------------------------------
-- Matching
--------------------------------------------------------------------------------
-- What this spec wants: its role, then the class extras, then the spec's own extras. Returns { give = weight }.
function SR.Wants(ctx)
    local w = {}
    local role = ctx.spec and SR.ROLES[ctx.spec.role]
    for k, v in pairs(role or {}) do w[k] = v end
    for k, v in pairs(ctx.cls and ctx.cls.extra or {}) do w[k] = v end
    for k, v in pairs(ctx.spec and ctx.spec.extra or {}) do w[k] = v end
    return w
end

-- nil: not for this spec. Otherwise true (CORE) or false (optional).
function SR.Match(item, wants)
    local core = false
    for _, g in ipairs(item.gives) do
        if wants[g] == 1 then core = true end
    end
    if not wants[item.gives[1]] and not core then return nil end
    if item.slot and not core then return nil end
    return core
end

local function ClassOK(item, ctx)
    return not item.class or item.class[ctx.class] == true
end

local function WeaponOK(item, ctx)
    -- ctx.weapons is nil for classes and specs without weapon buffs by type (warlocks, Holy): nothing to filter on
    return not item.weapon or not ctx.weapons or ctx.weapons == "both" or ctx.weapons == item.weapon
end

local function Usable(item, _, level)
    return (item.lvl or 1) <= level
end
SR.Usable = Usable

local function Row(id, ctx, wants)
    local item = SR.ITEMS[id]
    local want, set = SR.Want(id)
    local lvl = item.lvl or 1
    return {
        id = id, item = item, sec = item.sec,
        core = wants and SR.Match(item, wants) == true or false,
        new = id >= 200000,
        at = lvl > ctx.realLevel and lvl or nil,
        bags = SR.BagCount(id), want = want, wantSet = set,
    }
end

function SR.BuildAuto(ctx)
    local wants = SR.Wants(ctx)
    local picked, best = {}, {}
    for id, item in pairs(SR.ITEMS) do
        if SR.Match(item, wants) ~= nil and ClassOK(item, ctx) and WeaponOK(item, ctx) and Usable(item, ctx, ctx.level) then
            picked[#picked + 1] = id
            if item.line and (item.tier or 0) > (best[item.line] or -1) then best[item.line] = item.tier or 0 end
        end
    end
    local rows = {}
    for _, id in ipairs(picked) do
        local item = SR.ITEMS[id]
        local dim = item.line ~= nil and (item.tier or 0) < best[item.line]
        local row = Row(id, ctx, wants)
        if not dim or row.bags > 0 then
            row.dim = dim
            if dim then row.want = 0 end
            rows[#rows + 1] = row
        end
    end
    return rows
end

function SR.BuildProfile(ctx, name)
    local p = SR.char.profiles[name]
    local wants = SR.Wants(ctx)
    local rows = {}
    for id in pairs(p and p.items or {}) do
        if SR.ITEMS[id] then rows[#rows + 1] = Row(id, ctx, wants) end
    end
    return rows
end

-- Rows in one line stay together: the line's best (non-dimmed) row decides where the group sorts.
-- Group order: CORE first, then higher level, then the line name; inside a group, live rows before dimmed ones.
local function Sort(rows)
    local group = {}
    for _, r in ipairs(rows) do
        local key = r.item.line or ("#" .. r.id)
        r.group = key
        local g = group[key] or { core = false, lvl = 0 }
        group[key] = g
        if not r.dim then
            g.core = g.core or r.core
            g.lvl = math.max(g.lvl, r.item.lvl or 1)
        end
    end
    local name = {}
    for _, r in ipairs(rows) do name[r] = SR.ItemInfo(r.id) or tostring(r.id) end
    table.sort(rows, function(a, b)
        local ga, gb = group[a.group], group[b.group]
        if ga ~= gb then
            if ga.core ~= gb.core then return ga.core end
            if ga.lvl ~= gb.lvl then return ga.lvl > gb.lvl end
            return a.group < b.group
        end
        if (a.dim or false) ~= (b.dim or false) then return not a.dim end
        if (a.item.lvl or 1) ~= (b.item.lvl or 1) then return (a.item.lvl or 1) > (b.item.lvl or 1) end
        return name[a] < name[b]
    end)
end

-- Auto only: items that give the same buff (one slot like Well Fed or flasks, or equal tiers of one line like the
-- two +20 Agi steaks) are alternatives. The default Want goes to the cheapest one with a known price (else the
-- first in list order); the others default to 0 and are marked `alt`. A Want the player set always stands.
local function MarkAlternatives(list)
    local prices, groups = SR.Prices(), {}
    for _, s in ipairs(list.sections) do
        for _, r in ipairs(s.rows) do
            local it = r.item
            local key = not r.dim and (it.slot or (it.line and (it.line .. ":" .. (it.tier or 0))))
            if key then
                groups[key] = groups[key] or {}
                table.insert(groups[key], r)
            end
        end
    end
    for _, g in pairs(groups) do
        if #g > 1 then
            local pick = g[1]
            for _, r in ipairs(g) do
                local p, best = prices[r.id], prices[pick.id]
                if p and p.p and (not (best and best.p) or p.p < best.p) then pick = r end
            end
            for _, r in ipairs(g) do
                if r ~= pick then
                    r.alt = true
                    if not r.wantSet then r.want = 0 end
                end
            end
        end
    end
end

-- The whole list as sections, plus the header numbers.
function SR.BuildList()
    local ctx = SR.Context()
    local profile = SR.char.profile
    local rows = profile == "auto" and (ctx.supported and SR.BuildAuto(ctx) or {}) or SR.BuildProfile(ctx, profile)
    local bySec = {}
    for _, r in ipairs(rows) do
        bySec[r.sec] = bySec[r.sec] or {}
        table.insert(bySec[r.sec], r)
    end
    local list = { ctx = ctx, profile = profile, sections = {}, count = 0, unlock = 0, dimmed = 0 }
    for _, s in ipairs(SR.SECTIONS) do
        local secRows = bySec[s.key]
        if secRows then
            Sort(secRows)
            list.sections[#list.sections + 1] = { sec = s, rows = secRows }
            for _, r in ipairs(secRows) do
                if r.dim then list.dimmed = list.dimmed + 1 else list.count = list.count + 1 end
                if r.at and not r.dim then list.unlock = list.unlock + 1 end
            end
        end
    end
    if profile == "auto" then MarkAlternatives(list) end
    return list
end

-- Cost to fill: (Want - Bags) x lowest unit price, over live rows. Also counts rows with no known price.
function SR.CostToFill(list)
    local prices, total, unknown = SR.Prices(), 0, 0
    for _, s in ipairs(list.sections) do
        for _, r in ipairs(s.rows) do
            local need = r.want - r.bags
            if not r.dim and need > 0 then
                local p = prices[r.id]
                if p and p.p then total = total + need * p.p else unknown = unknown + 1 end
            end
        end
    end
    return total, unknown
end

-- Every item ID the scan should price (live rows).
function SR.ScanIDs(list)
    local ids = {}
    for _, s in ipairs(list.sections) do
        for _, r in ipairs(s.rows) do
            if not r.dim then ids[#ids + 1] = r.id end
        end
    end
    return ids
end

--------------------------------------------------------------------------------
-- Profiles (per character)
--------------------------------------------------------------------------------
function SR.ProfileNames()
    local out = {}
    for _, n in ipairs(SR.char.order) do
        if SR.char.profiles[n] then out[#out + 1] = n end
    end
    return out
end

function SR.CreateProfile(base)
    local n, name = 1, nil
    repeat
        name = (base or "Profile") .. (n > 1 and (" " .. n) or "")
        n = n + 1
    until not SR.char.profiles[name]
    SR.char.profiles[name] = { items = {} }
    table.insert(SR.char.order, name)
    SR.Notify("profiles")
    return name
end

function SR.RenameProfile(old, new)
    new = strtrim(new or "")
    if new == "" or new == "auto" or new == old or SR.char.profiles[new] or not SR.char.profiles[old] then return false end
    SR.char.profiles[new], SR.char.profiles[old] = SR.char.profiles[old], nil
    for i, n in ipairs(SR.char.order) do if n == old then SR.char.order[i] = new end end
    if SR.char.profile == old then SR.char.profile = new end
    SR.Notify("profiles")
    SR.Notify("list")
    return true
end

function SR.DeleteProfile(name)
    if not SR.char.profiles[name] then return end
    SR.char.profiles[name] = nil
    for i = #SR.char.order, 1, -1 do
        if SR.char.order[i] == name then table.remove(SR.char.order, i) end
    end
    if SR.char.profile == name then SR.char.profile = "auto" end
    SR.Notify("profiles")
    SR.Notify("list")
end

function SR.SetProfile(name)
    if name ~= "auto" and not SR.char.profiles[name] then return end
    SR.char.profile = name
    SR.Notify("list")
end

function SR.ProfileHas(name, id)
    local p = SR.char.profiles[name]
    return p and p.items[id] == true
end

function SR.SetInProfile(name, id, on)
    local p = SR.char.profiles[name]
    if not p then return end
    p.items[id] = on and true or nil
    SR.Notify("profiles")
    if SR.char.profile == name then SR.Notify("list") end
end

function SR.ProfileSize(name)
    local n = 0
    for _ in pairs(SR.char.profiles[name] and SR.char.profiles[name].items or {}) do n = n + 1 end
    return n
end

-- Adds everything Auto lists right now (its live rows) to the profile. Adds only, never removes.
function SR.FillFromAuto(name)
    local p = SR.char.profiles[name]
    if not p then return 0 end
    local ctx, added = SR.Context(), 0
    for _, r in ipairs(SR.BuildAuto(ctx)) do
        if not r.dim and not p.items[r.id] then
            p.items[r.id] = true
            added = added + 1
        end
    end
    SR.Notify("profiles")
    if SR.char.profile == name then SR.Notify("list") end
    return added
end
