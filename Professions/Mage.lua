-- Shout Out: Mage ad (portals, conjured food and water)
-- Not a profession, and open to any character (alts often advertise for a
-- mage). Every portal of your faction is listed. Portals post through {portals} as "UC & TB from ORG", where the
-- "from" part is whichever capital you're standing in when you post.
-- Conjured items: wowhead.com/forever (checked Nov 2026).

local _, ns = ...

local SECTIONS = {
    { key = "mgPortals", code = "P", label = "Portals", short = "", ownToken = "portals" },
    { key = "mgLvl55", code = "A", label = "Level 55", short = "" },
    { key = "mgLvl45", code = "B", label = "Level 45", short = "" },
    { key = "mgLvl35", code = "C", label = "Level 35", short = "" },
    { key = "mgLvl25", code = "D", label = "Level 25", short = "" },
    { key = "mgLvl15", code = "E", label = "Level 15", short = "" },
    { key = "mgLvl5",  code = "F", label = "Level 5",  short = "" },
    { key = "mgLvl1",  code = "G", label = "Level 1",  short = "" },
    { key = "mgExtras", label = "Extras", short = "" },
}
local byCode = {}
for _, s in ipairs(SECTIONS) do if s.code then byCode[s.code] = s.key end end

local entries = {}
-- portals: { spell, city as the game names the zone, short name, faction }
local PORTALS = {
    { 11417, "Orgrimmar", "ORG", "Horde" }, { 11418, "Undercity", "UC", "Horde" },
    { 11420, "Thunder Bluff", "TB", "Horde" },
    { 10059, "Stormwind City", "SW", "Alliance" }, { 11416, "Ironforge", "IF", "Alliance" },
    { 11419, "Darnassus", "Darn", "Alliance" },
}
for _, p in ipairs(PORTALS) do
    entries[#entries + 1] = {
        id = "mgPort" .. p[1], slot = "mgPortals", skill = 0, recipe = "Portal: " .. p[2],
        text = p[3], zone = p[2], faction = p[4], needSpell = p[1], starter = true,
    }
end
-- conjured water and food: { item, level section }
local CONJURED = {
    { 8079, "A" }, { 22895, "A" }, { 8078, "B" }, { 8076, "B" }, { 8077, "C" }, { 8075, "C" },
    { 3772, "D" }, { 1487, "D" }, { 2136, "E" }, { 1114, "E" }, { 2288, "F" }, { 1113, "F" },
    { 5350, "G" }, { 5349, "G" },
}
for i, c in ipairs(CONJURED) do
    entries[#entries + 1] = {
        id = "mgItem" .. c[1], item = c[1], slot = byCode[c[2]], skill = 0, quality = 1,
        starter = c[2] == "A", noAH = true, -- conjured items can't go on the AH
        fixedUnit = "stack", noCopper = true, -- always sold by the stack, in gold and silver
    }
end

ns.RegisterProfession({
    key = "mage", name = "Mage", fallback = "Mage", icon = "Interface\\Icons\\Spell_Arcane_PortalOrgrimmar",
    kind = "item", listToken = "{items}", extras = "mgExtras",
    always = true, noPreview = true, class = "MAGE", pricedText = true, starterPerSection = 3, listLabel = "+ Portals & Food",
    sections = SECTIONS, entries = entries,
    defaultTemplate = "WTS PORTS to {portals} | {items} | /w \"INV\"",
    starterAds = { { name = "New ad", minSkill = 0, maxSkill = 999 } },
})
