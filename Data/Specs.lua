-- What each class and spec WANTS. A want is a `gives` key from Data/Items.lua with a weight:
--   1 = core (CORE tag; counts for one-at-a-time slots like Well Fed and flasks)
--   2 = optional (shown, no tag)
-- Roles are templates shared by specs; `extra` adds class-only wants on top (Thistle Tea's energy), and a spec's own
-- `extra` adds wants only that tree has (a school of magic: Fire Power for Demonology and Destruction).
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
    -- Spell caster (warlocks first; meant for mages too). Core is what the Wowhead Forever warlock guides put in their
    -- "Quick Picks by Level": spell power potions, elixirs, oils and food, Mageblood, healing potions. Their prose
    -- ranks Intellect (food and elixirs) and mana potions below that ("Life Tap covers most of your mana"), so those
    -- are optional and Intellect food never takes the Well Fed slot. Schools (shadow, fire...) come from class/spec extras.
    caster = {
        sp = 1, mp5 = 1, heal = 1,
        int = 2, mana = 2, hp = 2, spellCrit = 2, freedom = 2,
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
    WARLOCK = {
        id = 9,
        specs = {
            { key = "affliction", name = "Affliction", role = "caster" },
            { key = "demonology", name = "Demonology", role = "caster", extra = { fire = 2 } },
            { key = "destruction", name = "Destruction", role = "caster", extra = { fire = 2 } },
        },
        extra = { shadow = 1 },
        weapons = false, -- wizard oils go on any weapon: no Weapons picker
    },
}

-- Classes Snackrun covers so far (David adds them one at a time).
SR.CLASS_ORDER = { "ROGUE", "WARRIOR", "WARLOCK" }
