-- Shout Out: Alchemy pack
-- Source: wowhead.com/forever/skill=171/alchemy (pulled Nov 2026).
--
-- Each row: { recipe spellID, made itemID, skill, section, quality, recipe name }
-- Transmutes are a service: they list and post as the transmute itself
-- ([Transmute: Arcanite]), not the bar it makes.
-- Names otherwise come from the game itself. Bind on Pickup results (e.g.
-- Alchemist's Stone) are hidden automatically.

local _, ns = ...

local SECTIONS = {
    -- transmutes first: they're the main thing alchemists sell, so they get room first
    { key = "alTransmutes", code = "T", label = "Transmutes",   short = "Transmutes" },
    { key = "alFlasks",     code = "F", label = "Flasks",       short = "Flasks" },
    -- elixirs and potions are split by what they do; {items:Elixirs} or
    -- {items:Potions} still places a whole group at once
    { key = "alElixStr", code = "S", label = "Elixirs: Strength & Attack", short = "Strength", group = "Elixirs" },
    { key = "alElixAgi", code = "A", label = "Elixirs: Agility", short = "Agility", group = "Elixirs" },
    { key = "alElixSpell", code = "M", label = "Elixirs: Spell Damage", short = "Spell Dmg", group = "Elixirs" },
    { key = "alElixHeal", code = "H", label = "Elixirs: Healing Power", short = "Healing", group = "Elixirs" },
    { key = "alElixInt", code = "I", label = "Elixirs: Intellect & Mana", short = "Int/Mana", group = "Elixirs" },
    { key = "alElixSpi", code = "W", label = "Elixirs: Spirit", short = "Spirit", group = "Elixirs" },
    { key = "alElixDef", code = "D", label = "Elixirs: Health & Defense", short = "Defense", group = "Elixirs" },
    { key = "alElixUtil", code = "U", label = "Elixirs: Utility", short = "Utility", group = "Elixirs" },
    { key = "alPotRestore", code = "R", label = "Potions: Healing & Mana", short = "Heal/Mana", group = "Potions" },
    { key = "alPotCombat", code = "C", label = "Potions: Combat Boosts", short = "Combat", group = "Potions" },
    { key = "alPotProt", code = "X", label = "Potions: Protection", short = "Protection", group = "Potions" },
    { key = "alPotUtil", code = "Y", label = "Potions: Cures & Utility", short = "Cures", group = "Potions" },
    { key = "alOther",      code = "O", label = "Oils & Other", short = "" },
    { key = "alExtras",               label = "Extras",       short = "" },
}

local RAW = {
    -- F
    {17635,13510,300,"F",1, "Flask of the Titans"}, -- Flask of the Titans
    {17637,13512,300,"F",1, "Flask of Supreme Power"}, -- Flask of Supreme Power
    {17636,13511,300,"F",1, "Flask of Distilled Wisdom"}, -- Flask of Distilled Wisdom
    {17638,13513,300,"F",1, "Flask of Chromatic Resistance"}, -- Flask of Chromatic Resistance
    {17634,13506,300,"F",1, "Flask of Petrification"}, -- Flask of Petrification
    {1293559,274273,300,"F",2, "Flask of Natural Accuracy"}, -- Flask of Natural Accuracy
    {1293560,274274,300,"F",2, "Flask of Natural Aggression"}, -- Flask of Natural Aggression
    {1293561,274275,300,"F",2, "Flask of Natural Precision"}, -- Flask of Natural Precision
    {1293562,274276,300,"F",2, "Flask of Natural Swiftness"}, -- Flask of Natural Swiftness
    -- T
    {17187,12360,275,"T",2, "Transmute: Arcanite"}, -- Transmute: Arcanite
    {1317279,251290,275,"T",2, "Transmute: Legionite"}, -- Transmute: Legionite
    {25146,7068,300,"T",1, "Transmute: Elemental Fire"}, -- Transmute: Elemental Fire
    {17563,7080,275,"T",2, "Transmute: Undeath to Water"}, -- Transmute: Undeath to Water
    {17566,12803,275,"T",2, "Transmute: Earth to Life"}, -- Transmute: Earth to Life
    {17562,7082,275,"T",2, "Transmute: Water to Air"}, -- Transmute: Water to Air
    {17559,7078,275,"T",2, "Transmute: Air to Fire"}, -- Transmute: Air to Fire
    {17560,7076,275,"T",2, "Transmute: Fire to Earth"}, -- Transmute: Fire to Earth
    {17561,7080,275,"T",2, "Transmute: Earth to Water"}, -- Transmute: Earth to Water
    {17565,7076,275,"T",2, "Transmute: Life to Earth"}, -- Transmute: Life to Earth
    {17564,12808,275,"T",2, "Transmute: Water to Undeath"}, -- Transmute: Water to Undeath
    {11480,6037,225,"T",2, "Transmute: Mithril to Truesilver"}, -- Transmute: Mithril to Truesilver
    {11479,3577,225,"T",2, "Transmute: Iron to Gold"}, -- Transmute: Iron to Gold
    -- Elixirs: Strength & Attack
    {1250800,250351,300,"S",1, "Elixir of the Grizzly"}, -- Elixir of the Grizzly
    {1250799,250350,275,"S",1, "Elixir of Ferocity"}, -- Elixir of Ferocity
    {17557,13453,275,"S",1, "Elixir of Brute Force"}, -- Elixir of Brute Force
    {11472,9206,245,"S",1, "Elixir of Greater Strength"}, -- Elixir of Greater Strength
    {3188,3391,150,"S",1, "Elixir of Ogre Strength"}, -- Elixir of Ogre Strength
    {1250798,250349,150,"S",1, "Elixir of Strength"}, -- Elixir of Strength
    {8240,6662,90,"S",1, "Elixir of Giant Growth"}, -- Elixir of Giant Growth
    {2329,2454,15,"S",1, "Elixir of Minor Strength"}, -- Elixir of Minor Strength
    {1245250,247755,10,"S",1, "Elixir of Minor Force"}, -- Elixir of Minor Force
    {1244421,246948,250,"S",1, "Distilled Firewater"}, -- Distilled Firewater
    -- Elixirs: Agility
    {17571,13452,280,"A",1, "Elixir of the Mongoose"}, -- Elixir of the Mongoose
    {1250777,250328,275,"A",1, "Elixir of Cunning"}, -- Elixir of Cunning
    {11467,9187,240,"A",1, "Elixir of Greater Agility"}, -- Elixir of Greater Agility
    {11449,8949,185,"A",1, "Elixir of Agility"}, -- Elixir of Agility
    {2333,3390,140,"A",1, "Elixir of Lesser Agility"}, -- Elixir of Lesser Agility
    {3230,2457,50,"A",1, "Elixir of Minor Agility"}, -- Elixir of Minor Agility
    -- Elixirs: Spell Damage
    {17573,13454,285,"M",1, "Greater Arcane Elixir"}, -- Greater Arcane Elixir
    {1250792,250343,285,"M",1, "Elixir of Nature Power"}, -- Elixir of Nature Power
    {11476,9264,250,"M",1, "Elixir of Shadow Power"}, -- Elixir of Shadow Power
    {26277,21546,250,"M",1, "Elixir of Holy Power"}, -- Elixir of Holy Power
    {11461,9155,235,"M",1, "Arcane Elixir"}, -- Arcane Elixir
    {21923,17708,190,"M",1, "Elixir of Frost Power"}, -- Elixir of Frost Power
    {7845,6373,140,"M",1, "Elixir of Fire Power"}, -- Elixir of Fire Power
    {1250791,250342,120,"M",1, "Lesser Arcane Elixir"}, -- Lesser Arcane Elixir
    {1245246,247754,10,"M",1, "Minor Arcane Elixir"}, -- Minor Arcane Elixir
    -- Elixirs: Healing Power
    {1250782,250333,195,"H",1, "Greater Cleric's Elixir"}, -- Greater Cleric's Elixir
    {1250781,250332,145,"H",1, "Cleric's Elixir"}, -- Cleric's Elixir
    {1250780,250331,95,"H",1, "Lesser Cleric's Elixir"}, -- Lesser Cleric's Elixir
    {1250779,250330,45,"H",1, "Minor Cleric's Elixir"}, -- Minor Cleric's Elixir
    -- Elixirs: Intellect & Mana
    {1250786,250337,280,"I",1, "Elixir of the Owl"}, -- Elixir of the Owl
    {24365,20007,275,"I",1, "Mageblood Elixir"}, -- Mageblood Elixir
    {1250785,250336,285,"I",1, "Elixir of Wicked Regeneration"}, -- Elixir of Wicked Regeneration
    {17555,13447,270,"I",1, "Elixir of the Sages"}, -- Elixir of the Sages
    {11465,9179,235,"I",1, "Elixir of Greater Intellect"}, -- Elixir of Greater Intellect
    {1250790,250341,175,"I",1, "Greater Mageblood Elixir"}, -- Greater Mageblood Elixir
    {1250802,250354,135,"I",1, "Elixir of Intellect"}, -- Elixir of Intellect
    {3171,3383,90,"I",1, "Elixir of Wisdom"}, -- Elixir of Wisdom
    {1250789,250340,75,"I",1, "Lesser Mageblood Elixir"}, -- Lesser Mageblood Elixir
    {1250801,250353,95,"I",1, "Elixir of Lesser Intellect"}, -- Elixir of Lesser Intellect
    {1250788,250339,25,"I",1, "Minor Mageblood Elixir"}, -- Minor Mageblood Elixir
    -- Elixirs: Spirit
    {1250797,250348,275,"W",1, "Elixir of the Whale"}, -- Elixir of the Whale
    {1250787,250338,275,"W",1, "Elixir of Sages"}, -- Elixir of Sages
    {1250796,250347,165,"W",1, "Elixir of Greater Spirit"}, -- Elixir of Greater Spirit
    {1250795,250346,115,"W",1, "Elixir of Spirit"}, -- Elixir of Spirit
    {1250794,250345,65,"W",1, "Elixir of Lesser Spirit"}, -- Elixir of Lesser Spirit
    {1250793,250344,15,"W",1, "Elixir of Minor Spirit"}, -- Elixir of Minor Spirit
    -- Elixirs: Health & Defense
    {24368,20004,290,"D",1, "Major Troll's Blood Elixir"}, -- Major Troll's Blood Elixir
    {1250778,250329,250,"D",1, "Elixir of the Phalanx"}, -- Elixir of the Phalanx
    {17554,13445,265,"D",1, "Elixir of Greater Defense"}, -- Elixir of Greater Defense
    {11466,9088,240,"D",1, "Gift of Arthas"}, -- Gift of Arthas
    {1250784,250335,200,"D",1, "Elixir of Greater Fortitude"}, -- Elixir of Greater Fortitude
    {11450,8951,195,"D",1, "Elixir of Defense"}, -- Elixir of Defense
    {3451,3826,180,"D",1, "Troll's Blood Elixir"}, -- Troll's Blood Elixir
    {3450,3825,175,"D",1, "Elixir of Lesser Fortitude"}, -- Elixir of Lesser Fortitude
    {1250783,250334,150,"D",1, "Elixir of Fortitude"}, -- Elixir of Fortitude
    {3177,3389,130,"D",1, "Elixir of Lesser Defense"}, -- Elixir of Lesser Defense
    {3176,3388,125,"D",1, "Lesser Troll's Blood Elixir"}, -- Lesser Troll's Blood Elixir
    {7183,5997,55,"D",1, "Elixir of Minor Defense"}, -- Elixir of Minor Defense
    {2334,2458,50,"D",1, "Elixir of Minor Fortitude"}, -- Elixir of Minor Fortitude
    {3170,3382,15,"D",1, "Minor Troll's Blood Elixir"}, -- Minor Troll's Blood Elixir
    -- Elixirs: Utility
    {11478,9233,250,"U",1, "Draught of Detect Demon"}, -- Draught of Detect Demon
    {11468,9197,240,"U",1, "Draught of Dream Vision"}, -- Draught of Dream Vision
    {11460,9154,230,"U",1, "Draught of Detect Undead"}, -- Draught of Detect Undead
    {22808,18294,215,"U",1, "Draught of Greater Water Breathing"}, -- Draught of Greater Water Breathing
    {12609,10592,200,"U",1, "Catseye Draught"}, -- Catseye Draught
    {3453,3828,195,"U",1, "Draught of Detect Lesser Invisibility"}, -- Draught of Detect Lesser Invisibility
    {1250776,250327,195,"U",1, "Potion of Predatory Senses"}, -- Potion of Predatory Senses
    {7179,5996,90,"U",1, "Draught of Water Breathing"}, -- Draught of Water Breathing
    -- Potions: Healing & Mana
    {22732,18253,300,"R",1, "Major Rejuvenation Potion"}, -- Major Rejuvenation Potion
    {17580,13444,295,"R",1, "Major Mana Potion"}, -- Major Mana Potion
    {24366,20002,275,"R",1, "Greater Dreamless Sleep Potion"}, -- Greater Dreamless Sleep Potion
    {17553,13443,260,"R",1, "Superior Mana Potion"}, -- Superior Mana Potion
    {1231583,241650,250,"R",1, "Major Discolored Healing Potion"}, -- Major Discolored Healing Potion
    {1244648,247242,230,"R",1, "Superior Discolored Healing Potion"}, -- Superior Discolored Healing Potion
    {15833,12190,230,"R",1, "Dreamless Sleep Potion"}, -- Dreamless Sleep Potion
    {11458,9144,225,"R",1, "Wildvine Potion"}, -- Wildvine Potion
    {11448,6149,205,"R",1, "Greater Mana Potion"}, -- Greater Mana Potion
    {1244647,247241,175,"R",1, "Greater Discolored Healing Potion"}, -- Greater Discolored Healing Potion
    {3452,3827,160,"R",1, "Mana Potion"}, -- Mana Potion
    {1244646,247240,135,"R",1, "Discolored Healing Potion"}, -- Discolored Healing Potion
    {3173,3385,120,"R",1, "Lesser Mana Potion"}, -- Lesser Mana Potion
    {1244645,247239,85,"R",1, "Lesser Discolored Healing Potion"}, -- Lesser Discolored Healing Potion
    {4508,4596,50,"R",1, "Minor Discolored Healing Potion"}, -- Minor Discolored Healing Potion
    {2332,2456,40,"R",1, "Minor Rejuvenation Potion"}, -- Minor Rejuvenation Potion
    {2331,2455,25,"R",1, "Minor Mana Potion"}, -- Minor Mana Potion
    -- Potions: Combat Boosts
    {1251740,250943,290,"C",1, "Major Frenzy Potion"}, -- Major Frenzy Potion
    {1251734,250937,285,"C",1, "Major Spellblasting Potion"}, -- Major Spellblasting Potion
    {1251747,250949,280,"C",1, "Major Mender's Potion"}, -- Major Mender's Potion
    {1251753,250955,280,"C",1, "Potion of Beast Slaying"}, -- Potion of Beast Slaying
    {1251752,250954,280,"C",1, "Potion of Elemental Purging"}, -- Potion of Elemental Purging
    {11477,9224,250,"C",1, "Potion of Demon Slaying"}, -- Potion of Demon Slaying
    {1251748,250950,275,"C",1, "Potion of Venomous Blood"}, -- Potion of Venomous Blood
    {1251749,250951,265,"C",1, "Caustic Smog Potion"}, -- Caustic Smog Potion
    {17552,13442,255,"C",1, "Mighty Rage Potion"}, -- Mighty Rage Potion
    {1251751,250953,245,"C",1, "Dragonfire Potion"}, -- Dragonfire Potion
    {1251739,250942,240,"C",1, "Superior Frenzy Potion"}, -- Superior Frenzy Potion
    {1251733,250936,235,"C",1, "Superior Spellblasting Potion"}, -- Superior Spellblasting Potion
    {1251745,250948,230,"C",1, "Superior Mender's Potion"}, -- Superior Mender's Potion
    {1251738,250941,190,"C",1, "Greater Frenzy Potion"}, -- Greater Frenzy Potion
    {1251732,250935,185,"C",1, "Greater Spellblasting Potion"}, -- Greater Spellblasting Potion
    {1251744,250947,180,"C",1, "Greater Mender's Potion"}, -- Greater Mender's Potion
    {6618,5633,175,"C",1, "Great Rage Potion"}, -- Great Rage Potion
    {1251737,250940,140,"C",1, "Frenzy Potion"}, -- Frenzy Potion
    {1251731,250934,135,"C",1, "Spellblasting Potion"}, -- Spellblasting Potion
    {1251743,250946,130,"C",1, "Mender's Potion"}, -- Mender's Potion
    {1251736,250939,90,"C",1, "Lesser Frenzy Potion"}, -- Lesser Frenzy Potion
    {1251730,250933,85,"C",1, "Lesser Spellblasting Potion"}, -- Lesser Spellblasting Potion
    {1251742,250945,80,"C",1, "Lesser Mender's Potion"}, -- Lesser Mender's Potion
    {6617,5631,60,"C",1, "Rage Potion"}, -- Rage Potion
    {1251735,250938,40,"C",1, "Minor Frenzy Potion"}, -- Minor Frenzy Potion
    {1251729,250932,35,"C",1, "Minor Spellblasting Potion"}, -- Minor Spellblasting Potion
    {1251741,250944,30,"C",1, "Minor Mender's Potion"}, -- Minor Mender's Potion
    -- Potions: Protection
    {17577,13461,290,"X",1, "Greater Arcane Protection Potion"}, -- Greater Arcane Protection Potion
    {17574,13457,290,"X",1, "Greater Fire Protection Potion"}, -- Greater Fire Protection Potion
    {17575,13456,290,"X",1, "Greater Frost Protection Potion"}, -- Greater Frost Protection Potion
    {17576,13458,290,"X",1, "Greater Nature Protection Potion"}, -- Greater Nature Protection Potion
    {17578,13459,290,"X",1, "Greater Shadow Protection Potion"}, -- Greater Shadow Protection Potion
    {17570,13455,280,"X",1, "Greater Stoneshield Potion"}, -- Greater Stoneshield Potion
    {3175,3387,250,"X",1, "Limited Invulnerability Potion"}, -- Limited Invulnerability Potion
    {4942,4623,215,"X",1, "Lesser Stoneshield Potion"}, -- Lesser Stoneshield Potion
    {11453,9036,210,"X",1, "Magic Resistance Potion"}, -- Magic Resistance Potion
    {7259,6052,190,"X",1, "Nature Protection Potion"}, -- Nature Protection Potion
    {7258,6050,190,"X",1, "Frost Protection Potion"}, -- Frost Protection Potion
    {7257,6049,165,"X",1, "Fire Protection Potion"}, -- Fire Protection Potion
    {7256,6048,135,"X",1, "Shadow Protection Potion"}, -- Shadow Protection Potion
    {3172,3384,110,"X",1, "Minor Magic Resistance Potion"}, -- Minor Magic Resistance Potion
    {7255,6051,100,"X",1, "Holy Protection Potion"}, -- Holy Protection Potion
    -- Potions: Cures & Utility
    {24367,20008,285,"Y",1, "Living Action Potion"}, -- Living Action Potion
    {17572,13462,285,"Y",1, "Purification Potion"}, -- Purification Potion
    {11464,9172,235,"Y",1, "Invisibility Potion"}, -- Invisibility Potion
    {11452,9030,225,"Y",1, "Restorative Potion"}, -- Restorative Potion
    {3448,3823,165,"Y",1, "Lesser Invisibility Potion"}, -- Lesser Invisibility Potion
    {6624,5634,150,"Y",1, "Free Action Potion"}, -- Free Action Potion
    {3174,3386,120,"Y",1, "Potion of Poison Cleansing"}, -- Potion of Poison Cleansing
    {7841,6372,100,"Y",1, "Swim Speed Potion"}, -- Swim Speed Potion
    {2335,2459,60,"Y",1, "Swiftness Potion"}, -- Swiftness Potion
    -- O
    {24266,19931,315,"O",3, "Gurubashi Mojo Madness"}, -- Gurubashi Mojo Madness
    {17632,13503,300,"O",1, "Alchemist's Stone"}, -- Alchemist's Stone
    {1263078,279990,300,"O",1, "Alchemy Laboratory"}, -- Alchemy Laboratory
    {17551,13423,250,"O",1, "Stonescale Oil"}, -- Stonescale Oil
    {11473,9210,245,"O",1, "Ghost Dye"}, -- Ghost Dye
    {11459,9149,225,"O",1, "Philosopher's Stone"}, -- Philosopher's Stone
    {1249632,249431,215,"O",2, "Viridian Dye"}, -- Viridian Dye
    {11456,9061,210,"O",1, "Goblin Rocket Fuel"}, -- Goblin Rocket Fuel
    {11451,8956,205,"O",1, "Oil of Immolation"}, -- Oil of Immolation
    {3454,3829,200,"O",1, "Frost Oil"}, -- Frost Oil
    {3449,3824,165,"O",1, "Shadow Oil"}, -- Shadow Oil
    {1263005,279970,140,"O",1, "Fermenter"}, -- Fermenter
    {7837,6371,130,"O",1, "Fire Oil"}, -- Fire Oil
    {1249631,249430,120,"O",2, "Magenta Dye"}, -- Magenta Dye
    {7836,6370,80,"O",1, "Blackmouth Oil"}, -- Blackmouth Oil
    {1249630,249409,40,"O",2, "Cerulean Dye"}, -- Cerulean Dye
    {1249633,249410,40,"O",2, "Sulfuric Acid"}, -- Sulfuric Acid
    {1230564,279956,20,"O",1, "Mana Well"}, -- Mana Well
}

local byCode = {}
for _, s in ipairs(SECTIONS) do if s.code then byCode[s.code] = s.key end end

local entries = {}
for i, r in ipairs(RAW) do
    entries[i] = {
        id = "al" .. r[1], spell = r[1], item = r[2], skill = r[3],
        slot = byCode[r[4]], quality = r[5], recipe = r[6],
        label = r[4] == "T" and r[6] or nil, -- transmutes list as "Transmute: Arcanite"
        service = r[4] == "T" or nil,         -- ...and post as the transmute's recipe link
        nameNote = r[4] == "T" and "(Service)" or nil,
        -- starter ad: the best flasks and transmutes (rows are best-first)
        starter = r[4] == "F" or r[4] == "T",
    }
end

-- Transmute materials, for the "Mats" cost (Wowhead, Nov 2026)
ns.REAGENTS = ns.REAGENTS or {}
local MATS = {
    [17187] = { 12359, 1, 12363, 1 },   -- Arcanite: Thorium Bar, Arcane Crystal
    [1317279] = { 251291, 1, 248819, 1 }, -- Legionite
    [25146] = { 7077, 1 },              -- Elemental Fire: Heart of Fire
    [17559] = { 7082, 1 }, [17566] = { 7076, 1 }, [17561] = { 7076, 1 },
    [17560] = { 7078, 1 }, [17565] = { 12803, 1 }, [17563] = { 12808, 1 },
    [17562] = { 7080, 1 }, [17564] = { 7080, 1 },
    [11479] = { 3575, 1 },              -- Iron to Gold: Iron Bar
    [11480] = { 3860, 1 },              -- Mithril to Truesilver: Mithril Bar
}
for spell, list in pairs(MATS) do ns.REAGENTS[spell] = list end

ns.RegisterProfession({
    key = "alchemy", name = "Alchemy", fallback = "Alchemist", icon = "Interface\\Icons\\Trade_Alchemy",
    kind = "item", listToken = "{items}", extras = "alExtras",
    starterPerSection = 2, -- 2 flasks + 2 transmutes fit one post with links
    sections = SECTIONS, entries = entries,
    defaultTemplate = "{prof} | WTS {items:Flasks} | WTS {items:Transmutes} | Taking craft requests with your mats + tip | /w me",
    starterAds = {
        { name = "New ad", minSkill = 0, maxSkill = 999 }, -- best 2 flasks and 2 transmutes
    },
})
