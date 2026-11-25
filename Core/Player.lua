-- Who we are shopping for: class, spec (talent tree with the most points), weapon types, level.
-- Every game read is guarded: a nil from an API means "unknown" and falls back, it never stops the list.
local _, SR = ...

local function Try(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

function SR.PlayerClass()
    local _, token = UnitClass("player")
    return token
end

function SR.PlayerLevel()
    return UnitLevel("player") or 1
end

-- The slider's default: the player's level rounded UP to the next multiple of 5 (13 -> 15, 25 -> 25, 39 -> 40).
function SR.RoundUp5(level)
    return math.min(SR.MAX_LEVEL, math.max(5, math.ceil(level / 5) * 5))
end

--------------------------------------------------------------------------------
-- Spec: Forever has one spec ID per class and vanilla-style trees. Read the class tree's groups (one per talent
-- tree) and the points spent in each; the most-spent group is the spec. Ties and an empty tree go to nil.
--------------------------------------------------------------------------------
local function ConfigID()
    local id = C_ClassTalents and C_ClassTalents.GetActiveConfigID and Try(C_ClassTalents.GetActiveConfigID)
    if id then return id end
    local S = C_SpecializationInfo
    if S and S.GetActiveSpecGroup and S.GetCombatConfigIDForSpecGroup then
        local group = Try(S.GetActiveSpecGroup)
        return group and Try(S.GetCombatConfigIDForSpecGroup, group)
    end
end

local function TreeID(configID)
    local info = C_Traits and C_Traits.GetConfigInfo and Try(C_Traits.GetConfigInfo, configID)
    if info and info.treeIDs and info.treeIDs[1] then return info.treeIDs[1] end
    local S = C_SpecializationInfo
    local index = S and S.GetSpecialization and Try(S.GetSpecialization)
    local specID = index and S.GetSpecializationInfo and Try(S.GetSpecializationInfo, index)
    return specID and C_ClassTalents and C_ClassTalents.GetTraitTreeForSpec and Try(C_ClassTalents.GetTraitTreeForSpec, specID)
end

-- Returns the spec key (Data/Specs.lua) or nil, plus the trees as { name, spent } for the debug line.
function SR.DetectSpec(class)
    local cls = SR.CLASSES[class]
    if not cls or not C_Traits or not C_Traits.GetGroupDisplayInfoByTreeID then return nil end
    local configID = ConfigID()
    local treeID = configID and TreeID(configID)
    local groups = treeID and Try(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    if type(groups) ~= "table" or #groups == 0 then return nil end
    table.sort(groups, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    local ids = {}
    for i, g in ipairs(groups) do ids[i] = g.groupID end
    local spent = {}
    for _, info in ipairs(Try(C_Traits.GetGroupCurrencyInfo, configID, ids) or {}) do
        local c = info.currencyInfos and info.currencyInfos[1]
        spent[info.traitNodeGroupID] = c and c.spent or 0
    end
    local best, bestSpent, tie, trees = nil, 0, false, {}
    for i, g in ipairs(groups) do
        local s = spent[g.groupID] or 0
        trees[i] = { name = g.displayName, spent = s }
        if s > bestSpent then best, bestSpent, tie = i, s, false elseif s == bestSpent and s > 0 then tie = true end
    end
    if not best or tie then return nil, trees end
    -- Match the tree by name, else by position.
    local name = (groups[best].displayName or ""):lower()
    for _, spec in ipairs(cls.specs) do
        if spec.name:lower() == name then return spec.key, trees end
    end
    return cls.specs[best] and cls.specs[best].key, trees
end

--------------------------------------------------------------------------------
-- Weapons: main and off hand item subclasses. Blades take sharpening stones, blunt weapons take weightstones.
--------------------------------------------------------------------------------
local BLADE = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [15] = true } -- axes, polearm, swords, dagger
local BLUNT = { [4] = true, [5] = true, [10] = true, [13] = true }                       -- maces, staff, fist

function SR.DetectWeapons()
    local blade, blunt = false, false
    for _, slot in ipairs({ 16, 17 }) do
        local id = GetInventoryItemID("player", slot)
        if id then
            local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
            if classID == 2 then
                if BLADE[subID] then blade = true elseif BLUNT[subID] then blunt = true end
            end
        end
    end
    if blade and blunt then return "both" elseif blunt then return "blunt" end
    return "blade" -- blades, or nothing equipped: a rogue's default
end

--------------------------------------------------------------------------------
-- The shopping context the list is built for: player values with the rail's overrides on top.
--------------------------------------------------------------------------------
function SR.Context()
    local c = SR.char
    local class = SR.PlayerClass()
    local cls = SR.CLASSES[class]
    local real = SR.PlayerLevel()
    local autoSpec = cls and SR.DetectSpec(class)
    local specKey = c.spec or autoSpec or (cls and cls.specs[1].key)
    local spec
    for _, s in ipairs(cls and cls.specs or {}) do if s.key == specKey then spec = s end end
    local autoWeapons = SR.DetectWeapons()
    return {
        class = class, supported = cls ~= nil, cls = cls,
        spec = spec, specAuto = c.spec == nil, specDetected = autoSpec,
        weapons = c.weapons or autoWeapons, weaponsAuto = c.weapons == nil,
        realLevel = real,
        level = c.level or SR.RoundUp5(real), levelAuto = c.level == nil,
    }
end

-- Clear every override ("Reset to me").
function SR.ResetToMe()
    SR.char.spec, SR.char.weapons, SR.char.level = nil, nil, nil
    SR.Notify("list")
end

function SR.BagCount(id)
    return C_Item.GetItemCount and (C_Item.GetItemCount(id) or 0) or 0
end
