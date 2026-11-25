-- Snackrun: namespace, saved data, events, slash command.
--   SnackrunDB      account-wide: AH prices per realm and faction
--   SnackrunCharDB  this character: profiles, Want numbers, the rail's overrides (spec, weapons, level)
local ADDON, SR = ...
SR.name = ADDON
SR.MAX_LEVEL = 60

local frame = CreateFrame("Frame")
local handlers = {}

-- SR.On(event, fn): fn(event, ...) runs on every fire. Several handlers per event are fine.
function SR.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    local list = handlers[event]
    list[#list + 1] = fn
end

frame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do
        local ok, err = pcall(fn, event, ...)
        if not ok then geterrorhandler()(err) end
    end
end)

-- Change listeners: the UI redraws on "list" (anything that changes which rows show) and "prices".
local listeners = {}
function SR.Listen(what, fn)
    listeners[what] = listeners[what] or {}
    local l = listeners[what]
    l[#l + 1] = fn
end
function SR.Notify(what, ...)
    for _, fn in ipairs(listeners[what] or {}) do fn(...) end
end

local function Defaults(t, d)
    for k, v in pairs(d) do
        if t[k] == nil then
            t[k] = type(v) == "table" and Defaults({}, v) or v
        elseif type(v) == "table" and type(t[k]) == "table" then
            Defaults(t[k], v)
        end
    end
    return t
end

SR.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    SnackrunDB = Defaults(type(SnackrunDB) == "table" and SnackrunDB or {}, { prices = {} })
    SnackrunCharDB = Defaults(type(SnackrunCharDB) == "table" and SnackrunCharDB or {}, {
        profile = "auto",  -- "auto" or a profile name
        profiles = {},     -- [name] = { items = { [itemID] = true } }
        order = {},        -- profile names in creation order
        wants = {},        -- [itemID] = n, only where the player changed the default
        spec = nil,        -- spec key override; nil follows the talent trees
        weapons = nil,     -- "blade" | "blunt" | "both" override; nil follows the gear
        level = nil,       -- level override; nil = player level rounded up to 5
    })
    SR.db, SR.char = SnackrunDB, SnackrunCharDB
    -- A profile deleted elsewhere (or a hand-edited save) falls back to Auto.
    if SR.char.profile ~= "auto" and not SR.char.profiles[SR.char.profile] then SR.char.profile = "auto" end
end)

-- The realm + faction whose AH the prices came from.
function SR.MarketKey()
    return (GetRealmName() or "?") .. "-" .. (UnitFactionGroup("player") or "?")
end

function SR.Prices()
    local key = SR.MarketKey()
    SR.db.prices[key] = SR.db.prices[key] or {}
    return SR.db.prices[key]
end

function SR.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9edb52Snackrun|r " .. msg)
end

SLASH_SNACKRUN1, SLASH_SNACKRUN2 = "/snack", "/snackrun"
SlashCmdList.SNACKRUN = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "profiles" then SR.OpenOptions("profiles") else SR.OpenOptions(msg ~= "" and msg or nil) end
end
