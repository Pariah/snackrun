-- Snackrun's consumable catalog. Items say what they GIVE; classes and specs (Data/Specs.lua) say what they WANT;
-- the list is the overlap. Nothing here is rated per spec, so a new class is new spec lines plus any new items.
--
-- Fields
--   sec    section key (SR.SECTIONS)
--   lvl    required level
--   gives  what the item gives; the FIRST entry is its main effect
--   line   items in one line replace each other; higher `tier` wins once its level is reached
--   tier   rank inside the line (equal tiers are alternatives, both stay)
--   slot   one-at-a-time buff (Well Fed, flask, ...): such items only show for a CORE want
--   class  only these classes can use it        weapon "blade" | "blunt": what the item can be applied to
--   want   default Want (else the section's)    fx     the short effect line under the name
-- IDs at 200000 and up are new in Forever (the NEW tag). Sources: _dev/research/*.json, Forever tooltips.
-- Only items you can buy on the AH belong here: nothing that binds when picked up (checked against every Forever
-- tooltip 2026-11-24; Jujus, Blasted Lands buffs, Zanzas and Tessa's Tonic are out for that reason). No reagents or
-- bandages either (David: "not stuff to get off the AH").
local _, SR = ...

SR.SECTIONS = {
    { key = "elixir", name = "Elixirs & Flasks", want = 5 },
    { key = "potion", name = "Potions", want = 10 },
    { key = "food", name = "Food", want = 20 },
    { key = "weapon", name = "Weapon", want = 10 },
    { key = "buff", name = "Scrolls & Buffs", want = 4 },
    { key = "boom", name = "Explosives", want = 5 },
}

local ROGUE_DRUID = { ROGUE = true, DRUID = true }
local ROGUE = { ROGUE = true }

SR.ITEMS = {
    ----------------------------------------------------------------------------------------------- Elixirs & flasks
    [2457] = { sec = "elixir", lvl = 2, gives = { "agi" }, line = "agiElixir", tier = 1, fx = "+4 Agi · 1 hr" },
    [3390] = { sec = "elixir", lvl = 18, gives = { "agi" }, line = "agiElixir", tier = 2, fx = "+8 Agi · 1 hr" },
    [8949] = { sec = "elixir", lvl = 27, gives = { "agi" }, line = "agiElixir", tier = 3, fx = "+15 Agi · 1 hr" },
    [9187] = { sec = "elixir", lvl = 38, gives = { "agi" }, line = "agiElixir", tier = 4, fx = "+25 Agi · 1 hr" },
    [250328] = { sec = "elixir", lvl = 55, gives = { "agi", "int" }, line = "agiElixir", tier = 4, fx = "+25 Agi, +25 Int · 30 min" },
    [13452] = { sec = "elixir", lvl = 46, gives = { "agi", "crit" }, line = "agiElixir", tier = 5, want = 5, fx = "+25 Agi, +2% crit · 30 min" },
    [250350] = { sec = "elixir", lvl = 55, gives = { "agi", "str" }, line = "ferocity", tier = 1, fx = "+18 Str & Agi · 30 min" },
    [2454] = { sec = "elixir", lvl = 1, gives = { "str" }, line = "strElixir", tier = 1, fx = "+4 Str · 1 hr" },
    [3391] = { sec = "elixir", lvl = 20, gives = { "str" }, line = "strElixir", tier = 2, fx = "+8 Str · 1 hr" },
    [250349] = { sec = "elixir", lvl = 45, gives = { "str" }, line = "strElixir", tier = 2, fx = "+10 Str · 30 min" },
    [9206] = { sec = "elixir", lvl = 48, gives = { "str" }, line = "strElixir", tier = 3, fx = "+25 Str · 1 hr" },
    [13453] = { sec = "elixir", lvl = 45, gives = { "str", "sta" }, line = "bruteForce", tier = 1, fx = "+18 Str & Sta · 1 hr" },
    [2458] = { sec = "elixir", lvl = 2, gives = { "hp" }, line = "hpElixir", tier = 1, fx = "+27 health · 1 hr" },
    [3825] = { sec = "elixir", lvl = 25, gives = { "hp" }, line = "hpElixir", tier = 2, fx = "+120 health · 1 hr" },
    [250334] = { sec = "elixir", lvl = 45, gives = { "hp" }, line = "hpElixir", tier = 3, fx = "+200 health · 30 min" },
    [250335] = { sec = "elixir", lvl = 55, gives = { "hp" }, line = "hpElixir", tier = 4, fx = "+400 health · 30 min" },
    [250329] = { sec = "elixir", lvl = 55, gives = { "hp", "armor" }, line = "phalanx", tier = 1, fx = "+400 health, +500 armor · 30 min" },
    [5997] = { sec = "elixir", lvl = 1, gives = { "armor" }, line = "armorElixir", tier = 1, fx = "+50 armor · 1 hr" },
    [3389] = { sec = "elixir", lvl = 16, gives = { "armor" }, line = "armorElixir", tier = 2, fx = "+150 armor · 1 hr" },
    [8951] = { sec = "elixir", lvl = 29, gives = { "armor" }, line = "armorElixir", tier = 3, fx = "+250 armor · 1 hr" },
    [13445] = { sec = "elixir", lvl = 43, gives = { "armor" }, line = "armorElixir", tier = 4, fx = "+450 armor · 1 hr" },
    [3382] = { sec = "elixir", lvl = 1, gives = { "regen" }, line = "trollsBlood", tier = 1, fx = "2 health / 5 sec · 1 hr" },
    [3388] = { sec = "elixir", lvl = 15, gives = { "regen" }, line = "trollsBlood", tier = 2, fx = "6 health / 5 sec · 1 hr" },
    [3826] = { sec = "elixir", lvl = 26, gives = { "regen" }, line = "trollsBlood", tier = 3, fx = "12 health / 5 sec · 1 hr" },
    [20004] = { sec = "elixir", lvl = 53, gives = { "regen" }, line = "trollsBlood", tier = 4, fx = "20 health / 5 sec · 1 hr" },
    [13510] = { sec = "elixir", lvl = 50, gives = { "hp" }, slot = "flask", want = 1, fx = "+1200 health · 2 hr, through death" },
    -- Zone flasks (Hyjal, Barrow Deeps...), in Forever from 2026-12-09.
    [274274] = { sec = "elixir", lvl = 55, gives = { "crit", "sta" }, slot = "flask", want = 1, fx = "+30 Sta; +2% crit in Hyjal zones" },
    [274273] = { sec = "elixir", lvl = 55, gives = { "hit", "sta" }, slot = "flask", want = 1, fx = "+30 Sta; +2% hit in Hyjal zones" },
    [274275] = { sec = "elixir", lvl = 55, gives = { "expertise", "sta" }, slot = "flask", want = 1, fx = "+30 Sta; -2% dodged/parried in Hyjal zones" },
    [274276] = { sec = "elixir", lvl = 55, gives = { "haste", "sta" }, slot = "flask", want = 1, fx = "+30 Sta; +2% haste in Hyjal zones" },

    ------------------------------------------------------------------------------------------------------- Potions
    [118] = { sec = "potion", lvl = 1, gives = { "heal" }, line = "healPot", tier = 1, fx = "70–90 health" },
    [858] = { sec = "potion", lvl = 3, gives = { "heal" }, line = "healPot", tier = 2, fx = "140–180 health" },
    [929] = { sec = "potion", lvl = 12, gives = { "heal" }, line = "healPot", tier = 3, fx = "280–360 health" },
    [1710] = { sec = "potion", lvl = 21, gives = { "heal" }, line = "healPot", tier = 4, fx = "455–585 health" },
    [3928] = { sec = "potion", lvl = 35, gives = { "heal" }, line = "healPot", tier = 5, fx = "700–900 health" },
    [13446] = { sec = "potion", lvl = 45, gives = { "heal" }, line = "healPot", tier = 6, fx = "1050–1750 health" },
    [250938] = { sec = "potion", lvl = 5, gives = { "ap" }, line = "frenzy", tier = 1, fx = "+12 AP · 30 sec" },
    [250939] = { sec = "potion", lvl = 15, gives = { "ap" }, line = "frenzy", tier = 2, fx = "+18 AP · 30 sec" },
    [250940] = { sec = "potion", lvl = 25, gives = { "ap" }, line = "frenzy", tier = 3, fx = "+28 AP · 30 sec" },
    [250941] = { sec = "potion", lvl = 35, gives = { "ap" }, line = "frenzy", tier = 4, fx = "+40 AP · 30 sec" },
    [250942] = { sec = "potion", lvl = 45, gives = { "ap" }, line = "frenzy", tier = 5, fx = "+56 AP · 30 sec" },
    [250943] = { sec = "potion", lvl = 55, gives = { "ap" }, line = "frenzy", tier = 6, fx = "+80 AP · 30 sec" },
    [5634] = { sec = "potion", lvl = 20, gives = { "freedom" }, line = "freeAction", tier = 1, want = 2, fx = "Stun and snare immune · 30 sec" },
    [20008] = { sec = "potion", lvl = 47, gives = { "freedom" }, line = "livingAction", tier = 1, want = 2, fx = "Breaks stuns and snares · 5 sec" },
    [3387] = { sec = "potion", lvl = 45, gives = { "immune" }, want = 2, fx = "Immune to physical · 6 sec" },
    [2459] = { sec = "potion", lvl = 5, gives = { "speed" }, want = 2, fx = "+50% run speed · 15 sec" },
    [3823] = { sec = "potion", lvl = 23, gives = { "invis" }, line = "invis", tier = 1, want = 2, fx = "Lesser invisibility · 15 sec" },
    [9172] = { sec = "potion", lvl = 37, gives = { "invis" }, line = "invis", tier = 2, want = 2, fx = "Invisibility · 18 sec" },
    [9030] = { sec = "potion", lvl = 32, gives = { "cleanse" }, want = 2, fx = "Removes a magic, curse, poison or disease effect / 5 sec" },
    [3386] = { sec = "potion", lvl = 14, gives = { "cleanse" }, want = 2, fx = "Cures up to four poisons" },
    [4623] = { sec = "potion", lvl = 33, gives = { "armor" }, line = "stoneshield", tier = 1, want = 2, fx = "+1000 armor · 90 sec" },
    [13455] = { sec = "potion", lvl = 46, gives = { "armor" }, line = "stoneshield", tier = 2, want = 2, fx = "+2000 armor · 2 min" },
    [3384] = { sec = "potion", lvl = 12, gives = { "resist" }, line = "magicRes", tier = 1, want = 2, fx = "+25 all resistances · 3 min" },
    [9036] = { sec = "potion", lvl = 32, gives = { "resist" }, line = "magicRes", tier = 2, want = 2, fx = "+50 all resistances · 3 min" },
    [6048] = { sec = "potion", lvl = 17, gives = { "absorb" }, line = "shadowProt", tier = 1, want = 2, fx = "Absorbs 675–1125 shadow" },
    [13459] = { sec = "potion", lvl = 48, gives = { "absorb" }, line = "shadowProt", tier = 2, want = 2, fx = "Absorbs 1950–3250 shadow" },
    [6049] = { sec = "potion", lvl = 23, gives = { "absorb" }, line = "fireProt", tier = 1, want = 2, fx = "Absorbs 975–1625 fire" },
    [13457] = { sec = "potion", lvl = 48, gives = { "absorb" }, line = "fireProt", tier = 2, want = 2, fx = "Absorbs 1950–3250 fire" },
    [6050] = { sec = "potion", lvl = 28, gives = { "absorb" }, line = "frostProt", tier = 1, want = 2, fx = "Absorbs 1350–2250 frost" },
    [13456] = { sec = "potion", lvl = 48, gives = { "absorb" }, line = "frostProt", tier = 2, want = 2, fx = "Absorbs 1950–3250 frost" },
    [6052] = { sec = "potion", lvl = 28, gives = { "absorb" }, line = "natureProt", tier = 1, want = 2, fx = "Absorbs 1350–2250 nature" },
    [13458] = { sec = "potion", lvl = 48, gives = { "absorb" }, line = "natureProt", tier = 2, want = 2, fx = "Absorbs 1950–3250 nature" },
    [13461] = { sec = "potion", lvl = 48, gives = { "absorb" }, want = 2, fx = "Absorbs 1950–3250 arcane" },
    [9224] = { sec = "potion", lvl = 40, gives = { "slaying" }, want = 2, fx = "+180 AP vs demons · 5 min" },
    [250955] = { sec = "potion", lvl = 40, gives = { "slaying" }, want = 2, fx = "+180 AP vs beasts · 5 min" },
    [250327] = { sec = "potion", lvl = 45, gives = { "detect" }, want = 2, fx = "Better stealth detection" },

    ---------------------------------------------------------------------------------------------------------- Food
    [2680] = { sec = "food", lvl = 1, gives = { "agi" }, line = "agiFood", tier = 1, slot = "fed", fx = "+1 Agi · Well Fed" },
    [2684] = { sec = "food", lvl = 5, gives = { "agi" }, line = "agiFood", tier = 2, slot = "fed", fx = "+3 Agi · Well Fed" },
    [12209] = { sec = "food", lvl = 15, gives = { "agi" }, line = "agiFood", tier = 3, slot = "fed", fx = "+5 Agi · Well Fed" },
    [13851] = { sec = "food", lvl = 25, gives = { "agi" }, line = "agiFood", tier = 4, slot = "fed", fx = "+10 Agi · Well Fed" },
    [18045] = { sec = "food", lvl = 35, gives = { "agi" }, line = "agiFood", tier = 5, slot = "fed", fx = "+15 Agi · Well Fed" },
    [250072] = { sec = "food", lvl = 45, gives = { "agi" }, line = "agiFood", tier = 6, slot = "fed", fx = "+20 Agi · Well Fed" },
    [250069] = { sec = "food", lvl = 45, gives = { "agi" }, line = "agiFood", tier = 6, slot = "fed", fx = "+20 Agi · Well Fed" },
    [4592] = { sec = "food", lvl = 5, gives = { "ap" }, line = "apFood", tier = 1, slot = "fed", fx = "+10 AP · Well Fed" },
    [8364] = { sec = "food", lvl = 25, gives = { "ap" }, line = "apFood", tier = 2, slot = "fed", fx = "+20 AP · Well Fed" },
    [13927] = { sec = "food", lvl = 35, gives = { "ap" }, line = "apFood", tier = 3, slot = "fed", fx = "+30 AP · Well Fed" },
    [13932] = { sec = "food", lvl = 35, gives = { "ap" }, line = "apFood", tier = 4, slot = "fed", fx = "+40 AP · Well Fed" },
    [13934] = { sec = "food", lvl = 45, gives = { "ap" }, line = "apFood", tier = 4, slot = "fed", fx = "+40 AP · Well Fed" },
    [13928] = { sec = "food", lvl = 35, gives = { "crit" }, line = "critFood", tier = 1, slot = "fed", fx = "+1% crit · Well Fed" },
    [13929] = { sec = "food", lvl = 35, gives = { "crit" }, line = "critFood", tier = 1, slot = "fed", fx = "+1% crit · Well Fed" },
    [2681] = { sec = "food", lvl = 1, gives = { "str" }, line = "strFood", tier = 1, slot = "fed", fx = "+1 Str · Well Fed" },
    [5480] = { sec = "food", lvl = 15, gives = { "str" }, line = "strFood", tier = 2, slot = "fed", fx = "+5 Str · Well Fed" },
    [250065] = { sec = "food", lvl = 35, gives = { "str" }, line = "strFood", tier = 3, slot = "fed", fx = "+15 Str · Well Fed" },
    [20452] = { sec = "food", lvl = 45, gives = { "str" }, line = "strFood", tier = 4, slot = "fed", fx = "+20 Str · Well Fed" },
    [250071] = { sec = "food", lvl = 45, gives = { "str" }, line = "strFood", tier = 4, slot = "fed", fx = "+20 Str · Well Fed" },
    [250070] = { sec = "food", lvl = 45, gives = { "str" }, line = "strFood", tier = 4, slot = "fed", fx = "+20 Str · Well Fed" },
    [6888] = { sec = "food", lvl = 1, gives = { "sta" }, line = "staFood", tier = 1, slot = "fed", fx = "+1 Sta · Well Fed" },
    [3665] = { sec = "food", lvl = 15, gives = { "sta" }, line = "staFood", tier = 2, slot = "fed", fx = "+5 Sta · Well Fed" },
    [12215] = { sec = "food", lvl = 25, gives = { "sta" }, line = "staFood", tier = 3, slot = "fed", fx = "+10 Sta · Well Fed" },
    [17222] = { sec = "food", lvl = 35, gives = { "sta" }, line = "staFood", tier = 4, slot = "fed", fx = "+15 Sta · Well Fed" },
    [250068] = { sec = "food", lvl = 45, gives = { "sta" }, line = "staFood", tier = 5, slot = "fed", fx = "+20 Sta · Well Fed" },
    [21023] = { sec = "food", lvl = 45, gives = { "sta" }, line = "staFood", tier = 6, slot = "fed", fx = "+25 Sta · Well Fed" },
    [12210] = { sec = "food", lvl = 15, gives = { "int" }, line = "intFood", tier = 1, slot = "fed", fx = "+5 Int · Well Fed" },
    [12216] = { sec = "food", lvl = 25, gives = { "int" }, line = "intFood", tier = 2, slot = "fed", fx = "+10 Int · Well Fed" },
    [7676] = { sec = "food", lvl = 5, gives = { "energy" }, class = ROGUE_DRUID, want = 6, fx = "100 energy · 5 min cooldown" },
    [4540] = { sec = "food", lvl = 1, gives = { "eat" }, line = "bread", tier = 1, fx = "59 health over 18 sec" },
    [4541] = { sec = "food", lvl = 5, gives = { "eat" }, line = "bread", tier = 2, fx = "234 health over 21 sec" },
    [4542] = { sec = "food", lvl = 15, gives = { "eat" }, line = "bread", tier = 3, fx = "531 health over 24 sec" },
    [4544] = { sec = "food", lvl = 25, gives = { "eat" }, line = "bread", tier = 4, fx = "841 health over 27 sec" },
    [4601] = { sec = "food", lvl = 35, gives = { "eat" }, line = "bread", tier = 5, fx = "1338 health over 30 sec" },
    [8950] = { sec = "food", lvl = 45, gives = { "eat" }, line = "bread", tier = 6, fx = "2065 health over 30 sec" },

    -------------------------------------------------------------------------------------------------------- Weapon
    [2862] = { sec = "weapon", lvl = 1, gives = { "dmg" }, line = "sharpen", tier = 1, weapon = "blade", fx = "+2 damage · 30 min · blades" },
    [2863] = { sec = "weapon", lvl = 5, gives = { "dmg" }, line = "sharpen", tier = 2, weapon = "blade", fx = "+3 damage · 30 min · blades" },
    [2871] = { sec = "weapon", lvl = 15, gives = { "dmg" }, line = "sharpen", tier = 3, weapon = "blade", fx = "+4 damage · 30 min · blades" },
    [7964] = { sec = "weapon", lvl = 25, gives = { "dmg" }, line = "sharpen", tier = 4, weapon = "blade", fx = "+6 damage · 30 min · blades" },
    [12404] = { sec = "weapon", lvl = 35, gives = { "dmg" }, line = "sharpen", tier = 5, weapon = "blade", fx = "+8 damage · 30 min · blades" },
    [18262] = { sec = "weapon", lvl = 50, gives = { "crit" }, line = "sharpen", tier = 6, weapon = "blade", fx = "+2% crit · 30 min · blades" },
    [3239] = { sec = "weapon", lvl = 1, gives = { "dmg" }, line = "weight", tier = 1, weapon = "blunt", fx = "+2 damage · 30 min · blunt" },
    [3240] = { sec = "weapon", lvl = 5, gives = { "dmg" }, line = "weight", tier = 2, weapon = "blunt", fx = "+3 damage · 30 min · blunt" },
    [3241] = { sec = "weapon", lvl = 15, gives = { "dmg" }, line = "weight", tier = 3, weapon = "blunt", fx = "+4 damage · 30 min · blunt" },
    [7965] = { sec = "weapon", lvl = 25, gives = { "dmg" }, line = "weight", tier = 4, weapon = "blunt", fx = "+6 damage · 30 min · blunt" },
    [12643] = { sec = "weapon", lvl = 35, gives = { "dmg" }, line = "weight", tier = 5, weapon = "blunt", fx = "+8 damage · 30 min · blunt" },

    ----------------------------------------------------------------------------------------------- Scrolls & buffs
    [3012] = { sec = "buff", lvl = 10, gives = { "agi" }, line = "scrollAgi", tier = 1, fx = "+5 Agi · 30 min" },
    [1477] = { sec = "buff", lvl = 25, gives = { "agi" }, line = "scrollAgi", tier = 2, fx = "+9 Agi · 30 min" },
    [4425] = { sec = "buff", lvl = 40, gives = { "agi" }, line = "scrollAgi", tier = 3, fx = "+13 Agi · 30 min" },
    [10309] = { sec = "buff", lvl = 55, gives = { "agi" }, line = "scrollAgi", tier = 4, fx = "+17 Agi · 30 min" },
    [954] = { sec = "buff", lvl = 10, gives = { "str" }, line = "scrollStr", tier = 1, fx = "+5 Str · 30 min" },
    [2289] = { sec = "buff", lvl = 25, gives = { "str" }, line = "scrollStr", tier = 2, fx = "+9 Str · 30 min" },
    [4426] = { sec = "buff", lvl = 40, gives = { "str" }, line = "scrollStr", tier = 3, fx = "+13 Str · 30 min" },
    [10310] = { sec = "buff", lvl = 55, gives = { "str" }, line = "scrollStr", tier = 4, fx = "+17 Str · 30 min" },
    [3013] = { sec = "buff", lvl = 1, gives = { "armor" }, line = "scrollArmor", tier = 1, fx = "+60 armor · 30 min" },
    [1478] = { sec = "buff", lvl = 15, gives = { "armor" }, line = "scrollArmor", tier = 2, fx = "+120 armor · 30 min" },
    [4421] = { sec = "buff", lvl = 30, gives = { "armor" }, line = "scrollArmor", tier = 3, fx = "+180 armor · 30 min" },
    [10305] = { sec = "buff", lvl = 45, gives = { "armor" }, line = "scrollArmor", tier = 4, fx = "+240 armor · 30 min" },
    [1180] = { sec = "buff", lvl = 5, gives = { "sta" }, line = "scrollSta", tier = 1, fx = "+4 Sta · 30 min" },
    [1711] = { sec = "buff", lvl = 20, gives = { "sta" }, line = "scrollSta", tier = 2, fx = "+8 Sta · 30 min" },
    [4422] = { sec = "buff", lvl = 35, gives = { "sta" }, line = "scrollSta", tier = 3, fx = "+12 Sta · 30 min" },
    [10307] = { sec = "buff", lvl = 50, gives = { "sta" }, line = "scrollSta", tier = 4, fx = "+16 Sta · 30 min" },
    [12820] = { sec = "buff", lvl = 45, gives = { "ap" }, line = "firewater", tier = 1, fx = "+35 AP · 20 min · same buff as Juju Might" },
    [246948] = { sec = "buff", lvl = 45, gives = { "ap" }, line = "firewater", tier = 1, fx = "+35 AP · 20 min · same buff as Winterfall" },
    [21151] = { sec = "buff", lvl = 1, gives = { "sta" }, line = "rum", tier = 2, slot = "drunk", fx = "+15 Sta · 15 min · drunk" },
    [21114] = { sec = "buff", lvl = 1, gives = { "sta" }, line = "rum", tier = 1, slot = "drunk", fx = "+10 Sta · 15 min · drunk" },

    ---------------------------------------------------------------------------------------------------- Explosives
    -- Engineers only, except Ez-Thro. Catalog items: nothing in Auto wants "boom".
    [6714] = { sec = "boom", lvl = 10, gives = { "boom" }, line = "ezThro", tier = 1, fx = "51–69 fire · anyone can throw it" },
    [18588] = { sec = "boom", lvl = 30, gives = { "boom" }, line = "ezThro", tier = 2, fx = "213–287 fire · anyone can throw it" },
    [4358] = { sec = "boom", lvl = 10, gives = { "boom" }, line = "dynamite", tier = 1, fx = "26–34 fire · engineers" },
    [4365] = { sec = "boom", lvl = 20, gives = { "boom" }, line = "dynamite", tier = 2, fx = "51–69 fire · engineers" },
    [4378] = { sec = "boom", lvl = 30, gives = { "boom" }, line = "dynamite", tier = 3, fx = "128–172 fire · engineers" },
    [10507] = { sec = "boom", lvl = 35, gives = { "boom" }, line = "dynamite", tier = 4, fx = "213–287 fire · engineers" },
    [18641] = { sec = "boom", lvl = 45, gives = { "boom" }, line = "dynamite", tier = 5, fx = "340–460 fire · engineers" },
    [4390] = { sec = "boom", lvl = 35, gives = { "boom" }, line = "grenade", tier = 1, fx = "132–218 fire, 3 sec stun · engineers" },
    [15993] = { sec = "boom", lvl = 52, gives = { "boom" }, line = "grenade", tier = 2, fx = "300–500 fire, 3 sec stun · engineers" },
    [10562] = { sec = "boom", lvl = 47, gives = { "boom" }, fx = "255–345 fire, 3 sec stun · engineers" },
    [10646] = { sec = "boom", lvl = 41, gives = { "boom" }, fx = "450–750 fire AoE, hurts you too · engineers" },
}
