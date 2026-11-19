-- Shout Out: profession registry + the Enchanting pack
-- Source: wowhead.com/forever/skill=333/enchanting (pulled Nov 2026)
--
-- Each row: { spellID, slot, skill, recipe name, default ad text }
--   spellID  the recipe's spell ID; Shout Out matches your known recipes on this
--   skill    skill required to learn it (used for sorting and starter ads)
--   text     the short text that goes in the ad (editable in-game)
--
-- Shout Out only shows the enchants your character knows, so it is fine for
-- this list to include every rank.

local _, ns = ...

-------------------------------------------------------------------------------
-- Profession packs. Each pack brings its own sections, recipes and starter
-- ads; everything else in Shout Out is shared. ns.SLOTS / ns.CATALOG hold every
-- pack's sections and recipes (keys and ids are unique across packs), each
-- tagged with .prof.
--   key        internal name ("enchanting")
--   name       shown in the UI ("Enchanting")
--   fallback   what {prof} posts before the profession link is captured
--   kind       "service" (list effects) or "item" (list crafted items, as links)
--   listToken  the placeholder the insert button adds ("{enchants}", "{items}")
--   extras     key of the section that holds custom lines
-------------------------------------------------------------------------------
ns.PROFESSIONS, ns.PROF_BY_KEY = {}, {}
ns.SLOTS, ns.CATALOG = {}, {}

function ns.RegisterProfession(p)
    table.insert(ns.PROFESSIONS, p)
    ns.PROF_BY_KEY[p.key] = p
    for _, sec in ipairs(p.sections) do
        sec.prof = p.key
        if sec.key == p.extras then sec.extras = true end
        table.insert(ns.SLOTS, sec)
    end
    for _, e in ipairs(p.entries) do
        e.prof = p.key
        table.insert(ns.CATALOG, e)
    end
end

-------------------------------------------------------------------------------
-- Enchanting
-------------------------------------------------------------------------------
local SECTIONS = {
    { key = "Weapon",   label = "Weapon",    short = "Wep" },
    { key = "2H",       label = "2H Weapon", short = "2H" },
    { key = "OffHand",  label = "Off-Hand",  short = "OH" },
    { key = "Chest",    label = "Chest",     short = "Chest" },
    { key = "Cloak",    label = "Cloak",     short = "Cloak" },
    { key = "Bracer",   label = "Bracer",    short = "Bracer" },
    { key = "Gloves",   label = "Gloves",    short = "Gloves" },
    { key = "Boots",    label = "Boots",     short = "Boots" },
    { key = "Shield",   label = "Shield",    short = "Shield" },
    { key = "Necklace", label = "Necklace",  short = "Neck" },
    { key = "Extras",   label = "Extras",    short = "" },
}

local RAW = {
    -- Weapon
    { 20034,   "Weapon", 300, "Enchant Weapon - Crusader", "Crusader" },
    { 22750,   "Weapon", 300, "Enchant Weapon - Healing Power", "55 Heal" },
    { 20032,   "Weapon", 300, "Enchant Weapon - Lifestealing", "Lifesteal" },
    { 23804,   "Weapon", 300, "Enchant Weapon - Mighty Intellect", "22 Int" },
    { 23803,   "Weapon", 300, "Enchant Weapon - Mighty Spirit", "22 Spi" },
    { 22749,   "Weapon", 300, "Enchant Weapon - Spell Power", "30 SP" },
    { 20031,   "Weapon", 300, "Enchant Weapon - Superior Striking", "+5 Dmg" },
    { 20033,   "Weapon", 295, "Enchant Weapon - Unholy Weapon", "Unholy" },
    { 23800,   "Weapon", 290, "Enchant Weapon - Agility", "15 Agi" },
    { 23799,   "Weapon", 290, "Enchant Weapon - Strength", "15 Str" },
    { 20029,   "Weapon", 285, "Enchant Weapon - Icy Chill", "Icy Chill" },
    { 1231164, "Weapon", 280, "Enchant Weapon - Grand Sorcerer", "Grand Sorcerer" },
    { 13898,   "Weapon", 265, "Enchant Weapon - Fiery Weapon", "Fiery" },
    { 13943,   "Weapon", 245, "Enchant Weapon - Greater Striking", "+4 Dmg" },
    { 13693,   "Weapon", 195, "Enchant Weapon - Striking", "+3 Dmg" },
    { 21931,   "Weapon", 190, "Enchant Weapon - Winter's Might", "Winter's Might" },
    { 1248757, "Weapon", 140, "Enchant Weapon - Insight", "Insight" },
    { 13503,   "Weapon", 140, "Enchant Weapon - Lesser Striking", "+2 Dmg" },
    { 1248760, "Weapon", 140, "Enchant Weapon - Recovery", "Recov" },
    { 1248805, "Weapon", 140, "Enchant Weapon - Revelation", "Rev" },
    { 7788,    "Weapon", 90,  "Enchant Weapon - Minor Striking", "+1 Dmg" },
    { 13915,   "Weapon", 230, "Enchant Weapon - Demonslaying", "Demonslaying" },
    { 13653,   "Weapon", 175, "Enchant Weapon - Lesser Beastslayer", "Beastslayer" },
    { 13655,   "Weapon", 175, "Enchant Weapon - Lesser Elemental Slayer", "Elemental Slayer" },
    { 7786,    "Weapon", 90,  "Enchant Weapon - Minor Beastslayer", "Minor Beastslayer" },

    -- Two-hand
    { 1219580, "2H", 300, "Enchant 2H Weapon - Spellblasting", "65 SP" },
    { 1248607, "2H", 300, "Enchant 2H Weapon - Mighty Spell Power", "55 SP" },
    { 1248636, "2H", 300, "Enchant 2H Weapon - Mighty Healing Power", "100 Heal" },
    { 20036,   "2H", 300, "Enchant 2H Weapon - Major Intellect", "9 Int" },
    { 20035,   "2H", 300, "Enchant 2H Weapon - Major Spirit", "9 Spi" },
    { 20030,   "2H", 295, "Enchant 2H Weapon - Superior Impact", "+9 Dmg" },
    { 27837,   "2H", 290, "Enchant 2H Weapon - Agility", "25 Agi" },
    { 1248668, "2H", 290, "Enchant 2H Weapon - Strength", "25 Str" },
    { 13937,   "2H", 240, "Enchant 2H Weapon - Greater Impact", "+7 Dmg" },
    { 1248511, "2H", 220, "Enchant 2H Weapon - Lesser Strength", "15 Str" },
    { 1248510, "2H", 210, "Enchant 2H Weapon - Lesser Agility", "15 Agi" },
    { 13695,   "2H", 200, "Enchant 2H Weapon - Impact", "+6 Dmg" },
    { 13529,   "2H", 145, "Enchant 2H Weapon - Lesser Impact", "+5 Dmg" },
    { 13380,   "2H", 110, "Enchant 2H Weapon - Lesser Spirit", "5 Spi" },
    { 7793,    "2H", 100, "Enchant 2H Weapon - Lesser Intellect", "5 Int" },
    { 7745,    "2H", 100, "Enchant 2H Weapon - Minor Impact", "+4 Dmg" },

    -- Off-hand
    { 1219578, "OffHand", 300, "Enchant Off-Hand - Excellent Spirit", "12 Spi" },
    { 1219577, "OffHand", 300, "Enchant Off-Hand - Superior Intellect", "9 Int" },
    { 1219579, "OffHand", 300, "Enchant Off-Hand - Wisdom", "6 Int 5 Spi" },

    -- Chest
    { 20025,   "Chest", 300, "Enchant Chest - Greater Stats", "+4 Stats" },
    { 20028,   "Chest", 290, "Enchant Chest - Major Intellect", "10 Int" },
    { 20026,   "Chest", 275, "Enchant Chest - Major Stamina", "10 Stam" },
    { 13941,   "Chest", 245, "Enchant Chest - Stats", "+3 Stats" },
    { 13917,   "Chest", 230, "Enchant Chest - Superior Intellect", "8 Int" },
    { 1249071, "Chest", 220, "Enchant Chest - Absorption", "Absorb" },
    { 13858,   "Chest", 220, "Enchant Chest - Superior Stamina", "8 Stam" },
    { 13700,   "Chest", 200, "Enchant Chest - Lesser Stats", "+2 Stats" },
    { 13663,   "Chest", 185, "Enchant Chest - Greater Intellect", "6 Int" },
    { 13640,   "Chest", 160, "Enchant Chest - Greater Stamina", "6 Stam" },
    { 13626,   "Chest", 150, "Enchant Chest - Minor Stats", "+1 Stats" },
    { 13607,   "Chest", 145, "Enchant Chest - Intellect", "4 Int" },
    { 13538,   "Chest", 140, "Enchant Chest - Lesser Absorption", "Lesser Absorb" },
    { 7857,    "Chest", 120, "Enchant Chest - Stamina", "4 Stam" },
    { 7776,    "Chest", 80,  "Enchant Chest - Lesser Intellect", "3 Int" },
    { 7748,    "Chest", 60,  "Enchant Chest - Lesser Stamina", "3 Stam" },
    { 7426,    "Chest", 40,  "Enchant Chest - Minor Absorption", "Minor Absorb" },
    { 7443,    "Chest", 20,  "Enchant Chest - Minor Intellect", "2 Int" },
    { 7420,    "Chest", 15,  "Enchant Chest - Inferior Stamina", "2 Stam" },

    -- Cloak
    { 1219587, "Cloak", 300, "Enchant Cloak - Agility", "5 Agi" },
    { 25086,   "Cloak", 300, "Enchant Cloak - Dodge", "1% Dodge" },
    { 25081,   "Cloak", 300, "Enchant Cloak - Greater Fire Resistance", "15 Fire Res" },
    { 25082,   "Cloak", 300, "Enchant Cloak - Greater Nature Resistance", "15 Nature Res" },
    { 25083,   "Cloak", 300, "Enchant Cloak - Stealth", "Stealth" },
    { 25084,   "Cloak", 300, "Enchant Cloak - Subtlety", "-2% Threat" },
    { 20015,   "Cloak", 285, "Enchant Cloak - Superior Defense", "70 Arm" },
    { 20014,   "Cloak", 265, "Enchant Cloak - Greater Resistance", "5 All Res" },
    { 13882,   "Cloak", 225, "Enchant Cloak - Lesser Agility", "3 Agi" },
    { 13746,   "Cloak", 205, "Enchant Cloak - Greater Defense", "60 Arm" },
    { 13794,   "Cloak", 205, "Enchant Cloak - Resistance", "3 All Res" },
    { 13657,   "Cloak", 175, "Enchant Cloak - Fire Resistance", "12 Fire Res" },
    { 13635,   "Cloak", 155, "Enchant Cloak - Defense", "30 Arm" },
    { 13522,   "Cloak", 135, "Enchant Cloak - Lesser Shadow Resistance", "10 Shadow Res" },
    { 7861,    "Cloak", 125, "Enchant Cloak - Lesser Fire Resistance", "10 Fire Res" },
    { 13421,   "Cloak", 115, "Enchant Cloak - Lesser Protection", "20 Arm" },
    { 13419,   "Cloak", 110, "Enchant Cloak - Minor Agility", "3 Agi" },
    { 7771,    "Cloak", 70,  "Enchant Cloak - Minor Protection", "10 Arm" },
    { 7454,    "Cloak", 45,  "Enchant Cloak - Minor Resistance", "2 All Res" },

    -- Bracer
    { 1217189, "Bracer", 320, "Enchant Bracer - Spell Power", "12 SP" },
    { 1220624, "Bracer", 300, "Enchant Bracer - Greater Spellpower", "16 SP" },
    { 23802,   "Bracer", 300, "Enchant Bracer - Healing Power", "24 Heal" },
    { 1248665, "Bracer", 300, "Enchant Bracer - Superior Deflection", "Sup Deflection" },
    { 1248661, "Bracer", 300, "Enchant Bracer - Superior Intellect", "9 Int" },
    { 20011,   "Bracer", 300, "Enchant Bracer - Superior Stamina", "9 Stam" },
    { 1248599, "Bracer", 295, "Enchant Bracer - Superior Agility", "9 Agi" },
    { 20010,   "Bracer", 295, "Enchant Bracer - Superior Strength", "9 Str" },
    { 23801,   "Bracer", 290, "Enchant Bracer - Mana Regeneration", "4 MP5" },
    { 20009,   "Bracer", 270, "Enchant Bracer - Superior Spirit", "9 Spi" },
    { 20008,   "Bracer", 255, "Enchant Bracer - Greater Intellect", "7 Int" },
    { 13945,   "Bracer", 245, "Enchant Bracer - Greater Stamina", "7 Stam" },
    { 1248500, "Bracer", 240, "Enchant Bracer - Greater Agility", "7 Agi" },
    { 13939,   "Bracer", 240, "Enchant Bracer - Greater Strength", "7 Str" },
    { 13931,   "Bracer", 235, "Enchant Bracer - Deflection", "7 Def" },
    { 13846,   "Bracer", 220, "Enchant Bracer - Greater Spirit", "7 Spi" },
    { 13822,   "Bracer", 210, "Enchant Bracer - Intellect", "5 Int" },
    { 1248498, "Bracer", 205, "Enchant Bracer - Lesser Healing Power", "16 Heal" },
    { 1248497, "Bracer", 190, "Enchant Bracer - Agility", "5 Agi" },
    { 13661,   "Bracer", 180, "Enchant Bracer - Strength", "5 Str" },
    { 13646,   "Bracer", 170, "Enchant Bracer - Lesser Deflection", "5 Def" },
    { 13648,   "Bracer", 170, "Enchant Bracer - Stamina", "5 Stam" },
    { 13642,   "Bracer", 165, "Enchant Bracer - Spirit", "5 Spi" },
    { 13622,   "Bracer", 150, "Enchant Bracer - Lesser Intellect", "3 Int" },
    { 1248460, "Bracer", 140, "Enchant Bracer - Lesser Agility", "4 Agi" },
    { 13536,   "Bracer", 140, "Enchant Bracer - Lesser Strength", "4 Str" },
    { 13501,   "Bracer", 130, "Enchant Bracer - Lesser Stamina", "4 Stam" },
    { 7859,    "Bracer", 120, "Enchant Bracer - Lesser Spirit", "4 Spi" },
    { 1248459, "Bracer", 90,  "Enchant Bracer - Minor Healing Power", "8 Heal" },
    { 7779,    "Bracer", 80,  "Enchant Bracer - Minor Agility", "3 Agi" },
    { 7428,    "Bracer", 80,  "Enchant Bracer - Minor Deflect", "3 Def" },
    { 7782,    "Bracer", 80,  "Enchant Bracer - Minor Strength", "3 Str" },
    { 1248458, "Bracer", 70,  "Enchant Bracer - Minor Intellect", "3 Int" },
    { 7766,    "Bracer", 60,  "Enchant Bracer - Minor Spirit", "3 Spi" },
    { 7457,    "Bracer", 50,  "Enchant Bracer - Minor Stamina", "3 Stam" },
    { 7418,    "Bracer", 20,  "Enchant Bracer - Inferior Stamina", "2 Stam" },

    -- Gloves
    { 25080,   "Gloves", 300, "Enchant Gloves - Superior Agility", "15 Agi" },
    { 1248640, "Gloves", 300, "Enchant Gloves - Superior Strength", "15 Str" },
    { 25079,   "Gloves", 300, "Enchant Gloves - Healing Power", "35 Heal" },
    { 1213626, "Gloves", 300, "Enchant Gloves - Arcane Power", "20 Arcane" },
    { 25078,   "Gloves", 300, "Enchant Gloves - Fire Power", "20 Fire" },
    { 25074,   "Gloves", 300, "Enchant Gloves - Frost Power", "20 Frost" },
    { 1213622, "Gloves", 300, "Enchant Gloves - Holy Power", "20 Holy" },
    { 1248645, "Gloves", 300, "Enchant Gloves - Natural Power", "20 Nature" },
    { 25073,   "Gloves", 300, "Enchant Gloves - Shadow Power", "20 Shadow" },
    { 25072,   "Gloves", 300, "Enchant Gloves - Threat", "+2% Threat" },
    { 20013,   "Gloves", 295, "Enchant Gloves - Greater Strength", "10 Str" },
    { 1294054, "Gloves", 295, "Enchant Gloves - Lotus Claw", "Lotus Claw" },
    { 20012,   "Gloves", 270, "Enchant Gloves - Greater Agility", "10 Agi" },
    { 1248528, "Gloves", 250, "Enchant Gloves - Advanced Skinning", "+10 Skinning" },
    { 13948,   "Gloves", 250, "Enchant Gloves - Minor Haste", "1% Haste" },
    { 13947,   "Gloves", 250, "Enchant Gloves - Riding Skill", "Riding" },
    { 13868,   "Gloves", 225, "Enchant Gloves - Advanced Herbalism", "+5 Herbalism" },
    { 13887,   "Gloves", 225, "Enchant Gloves - Strength", "7 Str" },
    { 13841,   "Gloves", 215, "Enchant Gloves - Advanced Mining", "+5 Mining" },
    { 13815,   "Gloves", 210, "Enchant Gloves - Agility", "7 Agi" },
    { 13698,   "Gloves", 200, "Enchant Gloves - Skinning", "+5 Skinning" },
    { 13620,   "Gloves", 145, "Enchant Gloves - Fishing", "+2 Fishing" },
    { 13617,   "Gloves", 145, "Enchant Gloves - Herbalism", "+2 Herbalism" },
    { 13612,   "Gloves", 145, "Enchant Gloves - Mining", "+2 Mining" },

    -- Boots
    { 20023,   "Boots", 295, "Enchant Boots - Greater Agility", "7 Agi" },
    { 1328948, "Boots", 280, "Enchant Boots - Speed", "8% Spd" },
    { 20024,   "Boots", 275, "Enchant Boots - Spirit", "5 Spi" },
    { 20020,   "Boots", 260, "Enchant Boots - Greater Stamina", "7 Stam" },
    { 13935,   "Boots", 235, "Enchant Boots - Agility", "5 Agi" },
    { 13890,   "Boots", 225, "Enchant Boots - Minor Speed", "4% Spd" },
    { 13836,   "Boots", 215, "Enchant Boots - Stamina", "5 Stam" },
    { 13687,   "Boots", 190, "Enchant Boots - Lesser Spirit", "4 Spi" },
    { 13644,   "Boots", 170, "Enchant Boots - Lesser Stamina", "4 Stam" },
    { 13637,   "Boots", 160, "Enchant Boots - Lesser Agility", "4 Agi" },
    { 7867,    "Boots", 125, "Enchant Boots - Minor Agility", "3 Agi" },
    { 7863,    "Boots", 125, "Enchant Boots - Minor Stamina", "3 Stam" },

    -- Shield
    { 1220623, "Shield", 300, "Enchant Shield - Critical Strike", "1% Crit" },
    { 1219581, "Shield", 300, "Enchant Shield - Excellent Stamina", "12 Stam" },
    { 20016,   "Shield", 280, "Enchant Shield - Superior Spirit", "9 Spi" },
    { 20017,   "Shield", 265, "Enchant Shield - Greater Stamina", "9 Stam" },
    { 13933,   "Shield", 235, "Enchant Shield - Frost Resistance", "8 Frost Res" },
    { 13905,   "Shield", 230, "Enchant Shield - Greater Spirit", "7 Spi" },
    { 13817,   "Shield", 210, "Enchant Shield - Stamina", "7 Stam" },
    { 13689,   "Shield", 195, "Enchant Shield - Lesser Block", "2% Block" },
    { 13659,   "Shield", 180, "Enchant Shield - Spirit", "5 Spi" },
    { 13631,   "Shield", 155, "Enchant Shield - Lesser Stamina", "5 Stam" },
    { 13485,   "Shield", 130, "Enchant Shield - Lesser Spirit", "3 Spi" },
    { 13464,   "Shield", 115, "Enchant Shield - Lesser Protection", "30 Arm" },
    { 13378,   "Shield", 105, "Enchant Shield - Minor Stamina", "3 Stam" },

    -- Necklace (new in Forever)
    { 1249059, "Necklace", 210, "Enchant Necklace - Agility", "5 Agi" },
    { 1249060, "Necklace", 210, "Enchant Necklace - Deflection", "5 Def" },
    { 1249058, "Necklace", 210, "Enchant Necklace - Healing Power", "11 Heal" },
    { 1249057, "Necklace", 210, "Enchant Necklace - Spell Power", "6 SP" },
    { 1249019, "Necklace", 210, "Enchant Necklace - Strength", "5 Str" },
}

-- Gathering and novelty enchants left out of the starter ads
local NOT_IN_STARTER = {
    [1294054] = true, [13620] = true, [13617] = true, [13612] = true,
    [13868] = true, [13841] = true, [13698] = true, [1248528] = true,
}

local entries = {}
for i, r in ipairs(RAW) do
    entries[i] = {
        id = "s" .. r[1], spell = r[1], slot = r[2], skill = r[3],
        recipe = r[4], text = r[5],
        starter = not NOT_IN_STARTER[r[1]],
    }
end

ns.RegisterProfession({
    key = "enchanting", name = "Enchanting", fallback = "Enchanter",
    defaultTemplate = "{prof} | Your Mats | Tips Appreciated | *your location* | {enchants} | +more", icon = "Interface\\Icons\\Trade_Engraving",
    kind = "service", listToken = "{enchants}", extras = "Extras",
    sections = SECTIONS, entries = entries,
    -- Starter ads fill themselves with the enchants you know in a skill range
    -- the first time Shout Out sees your Enchanting window. After that they're yours.
    starterAds = {
        { name = "New ad", minSkill = 0, maxSkill = 999 }, -- one starter ad: every enchant you know, best first
    },
})
