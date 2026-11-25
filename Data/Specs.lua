-- What each class and spec WANTS. A want is a `gives` key from Data/Items.lua with a weight:
--   1 = core (CORE tag; counts for one-at-a-time slots like Well Fed and flasks)
--   2 = optional (shown, no tag)
-- Roles are templates shared by specs; `extra` adds class-only wants on top (Thistle Tea's energy).
-- Adding a class: one CLASSES entry, a role if none fits, and any items it needs.
local _, SR = ...

SR.ROLES = {
    meleeAgi = {
        agi = 1, ap = 1, crit = 1, hit = 1, expertise = 1, dmg = 1, heal = 1,
        hp = 2, sta = 2, haste = 2, freedom = 2,
    },
    -- Strength melee (Arms, Fury). Agility is optional: elixirs show, Agi food does not take the Well Fed slot.
    meleeStr = {
        str = 1, ap = 1, crit = 1, hit = 1, expertise = 1, dmg = 1, heal = 1,
        agi = 2, hp = 2, sta = 2, haste = 2, freedom = 2,
    },
    -- Physical tank (Protection): survival first, Strength/AP/weapon damage for threat (Wowhead Forever prot guide).
    tank = {
        sta = 1, hp = 1, armor = 1, heal = 1, str = 1, ap = 1, dmg = 1,
        agi = 2, hit = 2, crit = 2, regen = 2, freedom = 2,
    },
}

-- specs: talent trees in the game's order (Forever has one spec ID per class; the "spec" is the tree with the most
-- points). `name` must match the tree's displayName; position is the fallback when it does not.
SR.CLASSES = {
    ROGUE = {
        id = 4,
        specs = {
            { key = "assassination", name = "Assassination", role = "meleeAgi" },
            { key = "combat", name = "Combat", role = "meleeAgi" },
            { key = "subtlety", name = "Subtlety", role = "meleeAgi" },
        },
        extra = { energy = 1 },
        weapons = true, -- blade/blunt matters (sharpening stones vs weightstones)
    },
    WARRIOR = {
        id = 1,
        specs = {
            { key = "arms", name = "Arms", role = "meleeStr" },
            { key = "fury", name = "Fury", role = "meleeStr" },
            { key = "protection", name = "Protection", role = "tank" },
        },
        extra = { rage = 1 },
        weapons = true,
    },
}

-- Classes Snackrun covers so far (David adds them one at a time).
SR.CLASS_ORDER = { "ROGUE", "WARRIOR" }
