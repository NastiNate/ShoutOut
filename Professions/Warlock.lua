-- Shout Out: Warlock summons ad
-- Not a profession: a list of places to summon to, by continent. Check every
-- place you (or your other accounts) can summon to; each name is editable.
-- The faction capitals post short (ORG, UC, TB / SW, IF, Darn).

local _, ns = ...

local SECTIONS = {
    { key = "wlCities",   label = "Cities",           short = "" },
    { key = "wlKalimdor", label = "Kalimdor",         short = "" },
    { key = "wlEastern",  label = "Eastern Kingdoms", short = "" },
    { key = "wlExtras",   label = "Extras",           short = "" },
}

local entries = {
    { id = "wlZOrgrimmar", slot = "wlCities", skill = 0, recipe = "Orgrimmar", text = "ORG", faction = "Horde" },
    { id = "wlZUndercity", slot = "wlCities", skill = 0, recipe = "Undercity", text = "UC", faction = "Horde" },
    { id = "wlZThunderBluff", slot = "wlCities", skill = 0, recipe = "Thunder Bluff", text = "TB", faction = "Horde" },
    { id = "wlZStormwindCity", slot = "wlCities", skill = 0, recipe = "Stormwind City", text = "SW", faction = "Alliance" },
    { id = "wlZIronforge", slot = "wlCities", skill = 0, recipe = "Ironforge", text = "IF", faction = "Alliance" },
    { id = "wlZDarnassus", slot = "wlCities", skill = 0, recipe = "Darnassus", text = "Darn", faction = "Alliance" },
    { id = "wlZBootyBay", slot = "wlCities", skill = 0, recipe = "Booty Bay", text = "Booty Bay" },
    { id = "wlZGadgetzan", slot = "wlCities", skill = 0, recipe = "Gadgetzan", text = "Gadgetzan" },
    { id = "wlZEverlook", slot = "wlCities", skill = 0, recipe = "Everlook", text = "Everlook" },
    { id = "wlZRatchet", slot = "wlCities", skill = 0, recipe = "Ratchet", text = "Ratchet" },
    { id = "wlZPowderfusePort", slot = "wlCities", skill = 0, recipe = "Powderfuse Port", text = "Powderfuse Port" },
    { id = "wlZAshenvale", slot = "wlKalimdor", skill = 0, recipe = "Ashenvale", text = "Ashenvale" },
    { id = "wlZAzshara", slot = "wlKalimdor", skill = 0, recipe = "Azshara", text = "Azshara" },
    { id = "wlZDarkshore", slot = "wlKalimdor", skill = 0, recipe = "Darkshore", text = "Darkshore" },
    { id = "wlZDesolace", slot = "wlKalimdor", skill = 0, recipe = "Desolace", text = "Desolace" },
    { id = "wlZDurotar", slot = "wlKalimdor", skill = 0, recipe = "Durotar", text = "Durotar" },
    { id = "wlZDustwallowMarsh", slot = "wlKalimdor", skill = 0, recipe = "Dustwallow Marsh", text = "Dustwallow Marsh" },
    { id = "wlZFelwood", slot = "wlKalimdor", skill = 0, recipe = "Felwood", text = "Felwood" },
    { id = "wlZFeralas", slot = "wlKalimdor", skill = 0, recipe = "Feralas", text = "Feralas" },
    { id = "wlZMoonglade", slot = "wlKalimdor", skill = 0, recipe = "Moonglade", text = "Moonglade" },
    { id = "wlZMulgore", slot = "wlKalimdor", skill = 0, recipe = "Mulgore", text = "Mulgore" },
    { id = "wlZSilithus", slot = "wlKalimdor", skill = 0, recipe = "Silithus", text = "Silithus" },
    { id = "wlZStonetalonMountains", slot = "wlKalimdor", skill = 0, recipe = "Stonetalon Mountains", text = "Stonetalon Mountains" },
    { id = "wlZTanaris", slot = "wlKalimdor", skill = 0, recipe = "Tanaris", text = "Tanaris" },
    { id = "wlZTeldrassil", slot = "wlKalimdor", skill = 0, recipe = "Teldrassil", text = "Teldrassil" },
    { id = "wlZTheBarrens", slot = "wlKalimdor", skill = 0, recipe = "The Barrens", text = "The Barrens" },
    { id = "wlZThousandNeedles", slot = "wlKalimdor", skill = 0, recipe = "Thousand Needles", text = "Thousand Needles" },
    { id = "wlZUnGoroCrater", slot = "wlKalimdor", skill = 0, recipe = "Un'Goro Crater", text = "Un\'Goro Crater" },
    { id = "wlZWinterspring", slot = "wlKalimdor", skill = 0, recipe = "Winterspring", text = "Winterspring" },
    { id = "wlZAlteracMountains", slot = "wlEastern", skill = 0, recipe = "Alterac Mountains", text = "Alterac Mountains" },
    { id = "wlZArathiHighlands", slot = "wlEastern", skill = 0, recipe = "Arathi Highlands", text = "Arathi Highlands" },
    { id = "wlZBadlands", slot = "wlEastern", skill = 0, recipe = "Badlands", text = "Badlands" },
    { id = "wlZBlackrockMountain", slot = "wlEastern", skill = 0, recipe = "Blackrock Mountain", text = "Blackrock Mountain" },
    { id = "wlZBlastedLands", slot = "wlEastern", skill = 0, recipe = "Blasted Lands", text = "Blasted Lands" },
    { id = "wlZBurningSteppes", slot = "wlEastern", skill = 0, recipe = "Burning Steppes", text = "Burning Steppes" },
    { id = "wlZDeadwindPass", slot = "wlEastern", skill = 0, recipe = "Deadwind Pass", text = "Deadwind Pass" },
    { id = "wlZDunMorogh", slot = "wlEastern", skill = 0, recipe = "Dun Morogh", text = "Dun Morogh" },
    { id = "wlZDuskwood", slot = "wlEastern", skill = 0, recipe = "Duskwood", text = "Duskwood" },
    { id = "wlZEasternPlaguelands", slot = "wlEastern", skill = 0, recipe = "Eastern Plaguelands", text = "Eastern Plaguelands" },
    { id = "wlZElwynnForest", slot = "wlEastern", skill = 0, recipe = "Elwynn Forest", text = "Elwynn Forest" },
    { id = "wlZHillsbradFoothills", slot = "wlEastern", skill = 0, recipe = "Hillsbrad Foothills", text = "Hillsbrad Foothills" },
    { id = "wlZLochModan", slot = "wlEastern", skill = 0, recipe = "Loch Modan", text = "Loch Modan" },
    { id = "wlZRedridgeMountains", slot = "wlEastern", skill = 0, recipe = "Redridge Mountains", text = "Redridge Mountains" },
    { id = "wlZSearingGorge", slot = "wlEastern", skill = 0, recipe = "Searing Gorge", text = "Searing Gorge" },
    { id = "wlZSilverpineForest", slot = "wlEastern", skill = 0, recipe = "Silverpine Forest", text = "Silverpine Forest" },
    { id = "wlZStranglethornVale", slot = "wlEastern", skill = 0, recipe = "Stranglethorn Vale", text = "Stranglethorn Vale" },
    { id = "wlZSwampofSorrows", slot = "wlEastern", skill = 0, recipe = "Swamp of Sorrows", text = "Swamp of Sorrows" },
    { id = "wlZTheHinterlands", slot = "wlEastern", skill = 0, recipe = "The Hinterlands", text = "The Hinterlands" },
    { id = "wlZTirisfalGlades", slot = "wlEastern", skill = 0, recipe = "Tirisfal Glades", text = "Tirisfal Glades" },
    { id = "wlZWesternPlaguelands", slot = "wlEastern", skill = 0, recipe = "Western Plaguelands", text = "Western Plaguelands" },
    { id = "wlZWestfall", slot = "wlEastern", skill = 0, recipe = "Westfall", text = "Westfall" },
    { id = "wlZWetlands", slot = "wlEastern", skill = 0, recipe = "Wetlands", text = "Wetlands" },
}

ns.RegisterProfession({
    key = "warlock", name = "Warlock", fallback = "Warlock", icon = "Interface\\Icons\\Spell_Shadow_Twilight",
    kind = "service", listToken = "{places}", extras = "wlExtras",
    always = true, noPreview = true, class = "WARLOCK", repeatable = true, placeSep = true, pricedText = true, listJoin = ", ", listLabel = "+ Places",
    sections = SECTIONS, entries = entries,
    defaultTemplate = "SELLING SUMMS | {places} | /w \"INV\"",
    starterAds = { { name = "New ad", minSkill = 0, maxSkill = 999 } },
})
