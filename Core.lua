-- Shout Out: saved data, recipe scan, message building, posting, reminders

local ADDON, ns = ...
ns.ICON = "Interface\\AddOns\\ShoutOut\\Media\\Icon"
-- hand-sized copies (Nate's): 30x30 for the title bar, 18x18 for the minimap,
-- each in the top-left of a 32x32 file (textures need power-of-two sizes)
ns.ICON_TITLE = "Interface\\AddOns\\ShoutOut\\Media\\IconTitle"
ns.ICON_MINIMAP = "Interface\\AddOns\\ShoutOut\\Media\\IconMinimap" -- the LFW megaphone (Nate's artwork, 256x256)
ShoutOut = ns -- global handle for macros: /run ShoutOut.Post()

ns.VERSION = "1.1.0"
ns.MAX_LEN = 255   -- characters players see (links count as their [Name])
ns.MAX_RAW = 1000  -- full length incl. hidden link code. WoW Forever takes far more than
                   -- the 448 once measured (10 recipe links in one line post fine), so
                   -- this is only a ceiling: if WoW refuses a post, Shout Out trims it,
                   -- sends the shorter one in the same click, and remembers the limit.
-- A lower limit learned when WoW refused a post (settings.maxRaw) wins if set.
function ns.MaxRaw() return (ns.db and ns.db.settings.maxRaw) or ns.MAX_RAW end
-- The visible limit. WoW's own count can come out a little higher than
-- Shout Out's (escaped pipes and profession links seem to count extra), so when
-- WoW refuses a post Shout Out lowers this until it goes through, and remembers.
-- Enchants per slot, 1-5 ("Spread evenly" was removed; it reads as 3)
function ns.PerSlot()
    local n = tonumber(ns.db and ns.db.settings.perSlot) or 3
    if n < 1 then n = 3 end
    return math.min(5, math.floor(n))
end
function ns.MaxLen() return (ns.db and ns.db.settings.maxVis) or ns.MAX_LEN end
-- Separator choices. Raid icons use the {rtN} codes, which work in every
-- game language (the {star}/{skull} names are localized).
ns.SEPARATORS = {
    { value = ", ",   label = ",  (comma)" },
    { value = " | ",  label = "|  (pipe)" },
    { value = " / ",  label = "/  (slash)" },
    { value = " // ", label = "//  (double slash)" },
    { value = " - ",  label = "-  (dash)" },
    { value = " ~ ",  label = "~  (tilde)" },
    { value = " :: ", label = "::  (double colon)" },
    { value = " >> ", label = ">>  (arrows)" },
    { value = " * ",  label = "*  (star)" },
    { value = " + ",  label = "+  (plus)" },
    { value = " = ",  label = "=  (equals)" },
    { value = "; ",   label = ";  (semicolon)" },
    { value = " ",    label = "(just a space)" },
    { value = " {rt1} ", icon = 1, label = "Star  {rt1}" },
    { value = " {rt2} ", icon = 2, label = "Circle  {rt2}" },
    { value = " {rt3} ", icon = 3, label = "Diamond  {rt3}" },
    { value = " {rt4} ", icon = 4, label = "Triangle  {rt4}" },
    { value = " {rt5} ", icon = 5, label = "Moon  {rt5}" },
    { value = " {rt6} ", icon = 6, label = "Square  {rt6}" },
    { value = " {rt7} ", icon = 7, label = "Cross  {rt7}" },
    { value = " {rt8} ", icon = 8, label = "Skull  {rt8}" },
}
-- Colors you can give each ad (tab, Post button, quick-post bar)
ns.AD_COLORS = {
    { key = "purple", name = "Purple", c = { 0.71, 0.55, 1.00 } },
    { key = "blue",   name = "Blue",   c = { 0.36, 0.62, 1.00 } },
    { key = "teal",   name = "Teal",   c = { 0.25, 0.80, 0.78 } },
    { key = "green",  name = "Green",  c = { 0.45, 0.82, 0.40 } },
    { key = "gold",   name = "Gold",   c = { 1.00, 0.80, 0.30 } },
    { key = "orange", name = "Orange", c = { 1.00, 0.55, 0.22 } },
    { key = "red",    name = "Red",    c = { 0.95, 0.33, 0.33 } },
    { key = "pink",   name = "Pink",   c = { 1.00, 0.45, 0.75 } },
    { key = "gray",   name = "Gray",   c = { 0.62, 0.62, 0.68 } },
}

function ns.AdColor(ad)
    ad = ad or ns.ActiveAd()
    for _, p in ipairs(ns.AD_COLORS) do
        if ad and p.key == ad.color then return p.c end
    end
    return ns.AD_COLORS[1].c
end

-- First color no other ad is using yet
function ns.NextFreeColor()
    local used = {}
    for _, ad in ipairs((ns.db and ns.db.ads) or {}) do if ad.color then used[ad.color] = true end end
    for _, p in ipairs(ns.AD_COLORS) do if not used[p.key] then return p.key end end
    return ns.AD_COLORS[1].key
end

ns.PROF_TOKEN = "{prof}"
ns.LIST_TOKEN = "{enchants}" -- {items} and {list} work the same way

local C = {
    accent = "ffb48cff",
    good   = "ff7ddc8a",
    warn   = "ffffc857",
    bad    = "ffff6b6b",
    dim    = "ff8a8a96",
}
ns.C = C

function ns.Print(msg)
    print("|c" .. C.accent .. "Shout Out|r " .. tostring(msg))
end

-------------------------------------------------------------------------------
-- Lookups
-------------------------------------------------------------------------------
ns.byId, ns.slotIndex = {}, {}
for i, s in ipairs(ns.SLOTS) do ns.slotIndex[s.key] = i end
ns.bySpell, ns.byRecipe = {}, {}
for i, e in ipairs(ns.CATALOG) do
    e.order = i
    ns.byId[e.id] = e
    if e.spell then ns.bySpell[e.spell] = e end
    if e.recipe then ns.byRecipe[e.recipe:lower()] = e end
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------
local DEFAULT_SETTINGS = {
    radar      = true,    -- Customer radar: pop up when someone asks for what you sell
    radarAuto  = false,   -- ...and invite on its own when the message is exactly "LF enchanter" etc.
    radarSound = true,
    autoRaid   = true,    -- turn a full party into a raid so invites keep going
    radarWhisper = "Hey! I can help with that. Want an invite?",
    sep        = " | ",
    slotLabels = true,
    rotate     = true,
    channel    = "",      -- "" = auto (Services, then Trade)
    interval   = 90,
    remind     = false,
    sound      = true,
    flash      = true,
    ahPrices   = true,    -- show Auctionator estimates next to crafted items    -- flashing outline on the quick-post bar when it's time
    showMini   = true,
    filter     = "all",   -- all | selected
    theme      = "glass", -- glass (Arcane Glass) | violet (Midnight Violet)
    perSlot    = 3,       -- 1-5: up to N enchants per slot
    scale      = 1,       -- main window scale
    miniScale  = 1,       -- quick-post bar scale
    showMinimap = true,
    minimapAngle = 200,
}

function ns.Pack(key) return ns.PROF_BY_KEY[key] or ns.PROFESSIONS[1] end
function ns.ProfOf(ad) ad = ad or ns.ActiveAd(); return (ad and ns.PROF_BY_KEY[ad.prof] and ad.prof) or "enchanting" end

-- The example message for a profession. An ad whose message box is empty
-- posts this (the box shows it in grey until you type your own).
function ns.DefaultTemplate(prof)
    local pack = ns.Pack(prof)
    return pack.defaultTemplate or ("{prof} LFW! " .. pack.listToken .. " | /w me")
end
function ns.UsingExample(ad)
    return not (ad and ad.template and ad.template:match("%S"))
end
function ns.Template(ad)
    if ns.UsingExample(ad) then return ns.DefaultTemplate(ns.ProfOf(ad)) end
    return ad.template
end

local function NewAd(name, template, prof)
    prof = prof or "enchanting"
    local pack = ns.Pack(prof)
    return { name = name or "New ad", rotate = false, prof = prof, links = pack.kind == "item",
             slotLabels = pack.kind ~= "item" and not pack.always, -- "Chest: [link]" wastes room in item ads
             template = template or "", items = {},
             caps = prof == "warlock" or nil, -- summon ads read best shouted: SELLING SUMMS | EVERLOOK
             color = ns.db and ns.NextFreeColor() or nil }
end
ns.NewAd = NewAd

function ns.InitDB()
    ShoutOutDB = ShoutOutDB or {}
    local db = ShoutOutDB
    db.settings  = db.settings or {}
    for k, v in pairs(DEFAULT_SETTINGS) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    db.text      = db.text or {}       -- per-item ad text overrides
    db.slotShort = db.slotShort or {}  -- per-slot label overrides
    db.custom    = db.custom or {}     -- { {id=, text=} }
    db.settings.links, db.settings.linkCount = nil, nil
    if db.settings.filter ~= "selected" then db.settings.filter = "all" end
    -- 1.1: new Forever catalog with new ids, so start the ads over once
    if (db.schema or 1) < 2 then
        db.ads, db.text, db.known, db.scanned = nil, {}, nil, nil
        db.schema = 2
    end
    -- 1.8: reminder is off by default
    if db.schema < 3 then
        db.settings.remind = false
        db.schema = 3
    end
    db.known     = db.known or {}      -- id -> true for recipes you know
    db.pos       = db.pos or {}
    if not db.ads or #db.ads == 0 then
        db.ads = {}
        for _, def in ipairs(ns.Pack("enchanting").starterAds) do
            local ad = NewAd(def.name, def.template, "enchanting")
            ad.fill = { def.minSkill, def.maxSkill } -- filled on first scan
            table.insert(db.ads, ad)
        end
    end
    -- 1.2: opening/closing lines became one editable message
    for _, ad in ipairs(db.ads) do
        if not ad.template then
            local t = ad.header or ""
            t = (t ~= "" and (t .. " ") or "") .. "{enchants}"
            if ad.footer and ad.footer ~= "" then t = t .. db.settings.sep .. ad.footer end
            ad.template = t
        end
        ad.header, ad.footer, ad.rot = nil, nil, nil
    end
    -- 1.11: Rotate overflow is per ad (each ad starts with the old global value)
    for _, ad in ipairs(db.ads) do
        if ad.rotate == nil then ad.rotate = db.settings.rotate ~= false end
    end
    -- give every ad a color
    for i, ad in ipairs(db.ads) do
        if not ad.color then ad.color = ns.AD_COLORS[((i - 1) % #ns.AD_COLORS) + 1].key end
    end
    if db.ads[2] and db.ads[2].color == "blue" and db.ads[2].name == "Leveling" then db.ads[2].color = "teal" end
    -- 2.0: several professions. Everything so far was Enchanting.
    db.scannedProfs = db.scannedProfs or {}
    if db.scanned then db.scannedProfs.enchanting = true; db.scanned = nil end
    db.profLinks = db.profLinks or {}
    if db.profLink then db.profLinks.enchanting = db.profLink; db.profLink = nil end
    db.slotOrders = db.slotOrders or {}
    if db.slotOrder then db.slotOrders.enchanting = db.slotOrder; db.slotOrder = nil end
    -- 1.0.2: the old 448 (and any limit learned against it) held ads back; start
    -- clean, the post itself finds the real limit if there is one
    if not db.limitsV2 then
        db.settings.maxRaw, db.settings.maxVis = nil, nil
        db.limitsV2 = true
    end
    db.preview = db.preview or {}      -- prof -> true: pretend you know every recipe
    db.preview.mage, db.preview.warlock = nil, nil -- class ads are open to everyone now
    db.names = db.names or {}          -- id -> name, remembered from your profession window
    db.prices = db.prices or {}        -- id -> your price for a crafted item, in copper
    -- before 2.7 prices were typed text ("100g", "2.5g", "1g 50s"): convert
    for id, v in pairs(db.prices) do
        if type(v) ~= "number" then db.prices[id] = ns.ParseMoney(v) end
    end
    if db.settings.autoInvite == nil then db.settings.autoInvite = false end
    db.priceUnit = db.priceUnit or {}
    db.settings.priceSource = db.settings.priceSource or "auto" -- auto / auctionator / tsm
    db.settings.tsmValue = db.settings.tsmValue or "DBMarket"
    db.classSetup = db.classSetup or {}    -- class ads already created for this character     -- id -> "stack" / "each" (ammo, explosives)
    db.recipeLinks = db.recipeLinks or {} -- spellID -> recipe link (transmutes)
    db.reagents = db.reagents or {}    -- spellID -> { item, count, ... } read from the game
    db.ahSeen = db.ahSeen or {}        -- itemID -> { p = price, t = time Shout Out saw it in a scan }
    db.bind = db.bind or {}            -- itemID -> bind type from the game (1 = Bind on Pickup)
    db.settings.limitLo, db.settings.limitHi = nil, nil -- from the old chat-limit test
    if db.settings.priceSource then    -- 2.2's source picker is gone (Auctionator only)
        db.settings.ahPrices = db.settings.priceSource ~= "off"
        db.settings.priceSource = nil
    end
    for _, ad in ipairs(db.ads) do
        if ad.prof == "guild" then ad.prof = "custom" end -- Guild Recruiting was removed in 4.1.1; keep its message
        if not ns.PROF_BY_KEY[ad.prof or ""] then ad.prof = "enchanting" end
        if ad.links == nil then ad.links = ns.Pack(ad.prof).kind == "item" end
        if ad.slotLabels == nil then ad.slotLabels = db.settings.slotLabels ~= false and ns.Pack(ad.prof).kind ~= "item" end
    end
    for _, c in ipairs(db.custom) do c.prof = c.prof or "enchanting" end
    -- 4.10: an untouched default message becomes the example (empty box,
    -- example shown in grey), so it follows the profession and later updates
    for _, ad in ipairs(db.ads) do
        for _, p in ipairs(ns.PROFESSIONS) do
            if ad.template and p.defaultTemplate and ad.template == p.defaultTemplate then ad.template = "" end
        end
        -- Warlock ads start in ALL CAPS (one you've switched off stays off)
        if ad.prof == "warlock" and ad.caps == nil then ad.caps = true end
        -- earlier example messages, changed since
        if ad.template == "{prof} | WTS Flasks: {items:Flasks} | WTS {items:Transmutes} | Your mats | Tips Appreciated | /w me"
            or ad.template == "WTS PORT | {portals} | WTS {items} | /w me"
            or ad.template == "{prof} | WTS {items:Flasks} | WTS {items:Transmutes} | Your mats | Tips Appreciated | /w me"
            or ad.template == "{prof} | WTS {items:One-Hand, Two-Hand} | Your mats | Tips Appreciated | /w me"
            or ad.template == "{prof} | WTS Bags: {items:Bags} | WTS {items:Cloak} | Your mats | Tips Appreciated | /w me"
            or ad.template == "{prof} | WTS {items:Scopes} | WTS {items:Ammo} | WTS {items:Explosives} | /w me"
            or ad.template == "WTS Summons to {items} | /w me" then
            ad.template = ""
        end
    end
    db.active = math.min(math.max(db.active or 1, 1), #db.ads)
    db.nextCustom = db.nextCustom or 1
    ns.db = db
    if ns.W then ns.W.ApplyTheme(db.settings.theme) end
end

-------------------------------------------------------------------------------
-- Item helpers (catalog + custom lines behave the same)
-------------------------------------------------------------------------------
local function CustomEntry(c, i)
    local prof = c.prof or "enchanting"
    return { id = c.id, prof = prof, slot = ns.Pack(prof).extras, text = c.text, order = 100000 + i, custom = true }
end

function ns.GetEntry(id)
    if ns.byId[id] then return ns.byId[id] end
    if ns.bagById and ns.bagById[id] then return ns.bagById[id] end
    for i, c in ipairs(ns.db.custom) do
        if c.id == id then return CustomEntry(c, i) end
    end
end

-- Known = learned (from your profession window), or Preview is on for it.
-- Crafted items also have to be sellable (not Bind on Pickup).
-- Class ads (Mage, Warlock) and the Custom ad aren't professions: they're
-- "always" known: any character can make them, limited only by faction.
local function PlayerClass() local _, c = UnitClass("player"); return c end
local function PlayerFaction() return UnitFactionGroup and UnitFactionGroup("player") end
-- Mage and Warlock ads are open to every character: an alt (or a second
-- account) often does the advertising for the mage or warlock.
function ns.ClassPackAvailable(pack)
    return true
end
local function Knows(e)
    local pack = ns.PROF_BY_KEY[e.prof]
    if pack and pack.always then
        if e.custom then return true end
        if not ns.ClassPackAvailable(pack) then return false end
        local fac = PlayerFaction()
        if e.faction and fac and fac ~= "Neutral" and e.faction ~= fac then return false end
        -- every portal of your faction is listed, learned or not
        return true
    end
    if not (e.custom or ns.db.known[e.id] or (e.knownVia and ns.db.known[e.knownVia]) or ns.db.preview[e.prof]) then return false end
    if e.item and not e.fromBags and not ns.Tradeable(e) then return false end
    return true
end

function ns.IsKnown(id)
    local e = ns.GetEntry(id)
    return e and Knows(e) and true or false
end

function ns.HasScanned(prof)
    prof = prof or ns.ProfOf()
    if ns.Pack(prof).always then return true end
    return (ns.db.scannedProfs[prof] or ns.db.preview[prof]) and true or false
end

-- One profession's recipes you know, plus its custom lines
function ns.AllEntries(prof)
    prof = prof or ns.ProfOf()
    local list = {}
    for _, e in ipairs(ns.CATALOG) do
        if e.prof == prof and Knows(e) then list[#list + 1] = e end
    end
    if ns.Pack(prof).bags and ns.BagEntries then
        for _, e in ipairs(ns.BagEntries()) do list[#list + 1] = e end
    end
    for i, c in ipairs(ns.db.custom) do
        if (c.prof or "enchanting") == prof then list[#list + 1] = CustomEntry(c, i) end
    end
    -- your drag order within each section (catalog order otherwise)
    table.sort(list, function(a, b)
        if a.slot ~= b.slot then return (ns.slotIndex[a.slot] or 99) < (ns.slotIndex[b.slot] or 99) end
        return ns.ItemRank(a) < ns.ItemRank(b)
    end)
    return list
end

-------------------------------------------------------------------------------
-- Enchant order inside a section (drag rows to change it). First in the
-- section = listed first in the message and gets room first.
-------------------------------------------------------------------------------
-- Cached: id -> position from your drag order (rebuilt after a drag)
local rankCache
function ns.InvalidateRanks() rankCache = nil end

function ns.ItemRank(e)
    if not rankCache then
        rankCache = {}
        for _, ids in pairs(ns.db.itemOrder or {}) do
            for i, id in ipairs(ids) do rankCache[id] = i end
        end
    end
    return rankCache[e.id] or (10000 + e.order) -- not placed yet: catalog order
end

-- Move an enchant before (or after) another one in the same section
function ns.MoveItem(id, targetId, after)
    local e, t = ns.GetEntry(id), ns.GetEntry(targetId)
    if not e or not t or e.slot ~= t.slot or id == targetId then return end
    local ids = {}
    for _, x in ipairs(ns.AllEntries(e.prof)) do
        if x.slot == e.slot and x.id ~= id then ids[#ids + 1] = x.id end
    end
    local pos = #ids + 1
    for i, x in ipairs(ids) do
        if x == targetId then pos = after and (i + 1) or i break end
    end
    table.insert(ids, pos, id)
    ns.db.itemOrder = ns.db.itemOrder or {}
    ns.db.itemOrder[e.slot] = ids
    ns.InvalidateRanks()
    for _, ad in ipairs(ns.db.ads) do ad.pending = nil end
end

-- Crafted items: name and link come from the game (cached; the first look
-- may still be loading, then GET_ITEM_INFO_RECEIVED refreshes the window).
local function ItemInfo(itemID)
    if not itemID then return end
    local info
    if C_Item and C_Item.GetItemInfo then info = { C_Item.GetItemInfo(itemID) }
    elseif GetItemInfo then info = { GetItemInfo(itemID) } end
    local name, link, bindType = info and info[1], info and info[2], info and info[14]
    if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
    return name, link, bindType
end

-- Can this crafted item be sold? Bind on Pickup (1) and quest items (4) bind
-- to whoever crafts them, so they're never listed. Remembered once known.
-- Returns true (sellable), false (soulbound), or nil (game hasn't said yet).
function ns.Tradeable(e)
    if not e.item then return true end
    local known = ns.db.bind[e.item]
    if known == nil then
        local name, _, bindType = ItemInfo(e.item)
        if name and type(bindType) == "number" then
            ns.db.bind[e.item] = bindType
            known = bindType
        end
    end
    if known == nil then return nil end
    return known ~= 1 and known ~= 4
end

function ns.ItemName(e)
    local name = ItemInfo(e.item)
    if name then return name end
    if ns.db.names[e.id] then return ns.db.names[e.id] end
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(e.spell)
    return spellName or ("Item " .. tostring(e.item))
end

-- WoW item quality colors (uncommon and up), slightly brightened for dark panels
local QUALITY = { [2] = { 0.12, 1, 0, 1 }, [3] = { 0.25, 0.6, 1, 1 }, [4] = { 0.70, 0.35, 1, 1 }, [5] = { 1, 0.5, 0, 1 } }
function ns.QualityColor(q) return q and QUALITY[q] end

-- A recipe's clickable link, e.g. [Transmute: Arcanite]. Saved when you open
-- the profession window; otherwise asked from the game; nil if it can't.
local function ValidLink(l) return type(l) == "string" and l:find("|H", 1, true) and l or nil end
function ns.RecipeLink(e)
    if not (e and e.spell) then return end
    if e.linkType == "spell" then -- e.g. [Mooncloth]: the spell itself, not the recipe
        local l
        if C_Spell and type(C_Spell.GetSpellLink) == "function" then
            local ok, v = pcall(C_Spell.GetSpellLink, e.spell); if ok then l = ValidLink(v) end
        end
        if not l and type(GetSpellLink) == "function" then
            local ok, v = pcall(GetSpellLink, e.spell); if ok then l = ValidLink(v) end
        end
        return l
    end
    local saved = ns.db.recipeLinks[e.spell]
    if ValidLink(saved) then return saved end
    local l
    local T = C_TradeSkillUI
    if T and type(T.GetRecipeLink) == "function" then
        local ok, v = pcall(T.GetRecipeLink, e.spell); if ok then l = ValidLink(v) end
    end
    if not l and C_Spell and type(C_Spell.GetSpellLink) == "function" then
        local ok, v = pcall(C_Spell.GetSpellLink, e.spell); if ok then l = ValidLink(v) end
    end
    if not l and type(GetSpellLink) == "function" then
        local ok, v = pcall(GetSpellLink, e.spell); if ok then l = ValidLink(v) end
    end
    if l then ns.db.recipeLinks[e.spell] = l end
    return l
end

function ns.ItemLink(e)
    -- bag items keep their exact link (random "of the Eagle" suffixes etc.)
    if type(e.link) == "string" and e.link:find("|H", 1, true) then return e.link end
    local _, link = ItemInfo(e.item)
    if type(link) == "string" and link:find("|H", 1, true) then return link end
end

-- The default ad text: an enchant's short text, or a crafted item's name
local function DefaultText(e)
    if e.text then return e.text end
    if e.service and e.recipe then return e.recipe end
    if e.item then return ns.ItemName(e) end
    return ""
end

function ns.ItemText(id)
    local e = ns.GetEntry(id)
    if not e then return "" end
    if e.custom then return e.text or "" end
    local t = ns.db.text[id]
    if t and t ~= "" then return t end
    return DefaultText(e)
end

function ns.SetItemText(id, text)
    local e = ns.GetEntry(id)
    if not e then return end
    if e.custom then
        for _, c in ipairs(ns.db.custom) do if c.id == id then c.text = text end end
    elseif text == DefaultText(e) or text == "" then
        ns.db.text[id] = nil
    else
        ns.db.text[id] = text
    end
end

function ns.DisplayName(e)
    if e.custom then return "Custom line" end
    -- transmutes sit under "Transmutes", so the list just says "Arcanite"
    if e.item and e.label then return (e.label:gsub("^Transmute:%s*", "")) end
    if e.item and e.fromBags then
        local name = (type(e.link) == "string" and e.link:match("|h%[(.-)%]|h")) or ns.ItemName(e)
        return (e.count or 1) > 1 and (name .. "  x" .. e.count) or name
    end
    if e.item then return ns.ItemName(e) end
    return e.recipe:match("%-%s*(.+)$") or e.recipe
end

function ns.SlotShort(key)
    local v = ns.db.slotShort[key]
    if v ~= nil then return v end
    return ns.SLOTS[ns.slotIndex[key]].short
end

function ns.ActiveAd() return ns.db.ads[ns.db.active] end

-------------------------------------------------------------------------------
-- Section order (drag the section headers to change it). This is the order
-- of the list, the order in the message, and which slots get room first.
-------------------------------------------------------------------------------
function ns.OrderedSlots(prof)
    prof = prof or ns.ProfOf()
    local list, seen = {}, {}
    for _, key in ipairs(ns.db.slotOrders[prof] or {}) do
        local def = ns.SLOTS[ns.slotIndex[key] or 0]
        if def and def.prof == prof and not seen[key] then list[#list + 1] = def; seen[key] = true end
    end
    for _, def in ipairs(ns.SLOTS) do
        if def.prof == prof and not seen[def.key] then list[#list + 1] = def end
    end
    return list
end

function ns.SlotRank(key)
    local def = ns.SLOTS[ns.slotIndex[key] or 0]
    for i, d in ipairs(ns.OrderedSlots(def and def.prof)) do
        if d.key == key then return i end
    end
    return 99
end

-- Move a section to sit before (or after) another one
function ns.MoveSlot(key, targetKey, after)
    if key == targetKey then return end
    local prof = (ns.SLOTS[ns.slotIndex[key] or 0] or {}).prof or ns.ProfOf()
    local order = {}
    for _, def in ipairs(ns.OrderedSlots(prof)) do
        if def.key ~= key then order[#order + 1] = def.key end
    end
    local pos = #order + 1
    for i, k in ipairs(order) do
        if k == targetKey then pos = after and (i + 1) or i break end
    end
    table.insert(order, pos, key)
    ns.db.slotOrders[prof] = order
    for _, ad in ipairs(ns.db.ads) do ad.pending = nil end
end

function ns.ItemState(ad, id)
    local st = ad.items[id]
    return st and st.on or false
end


function ns.SetItemState(ad, id, on)
    ad.items[id] = ad.items[id] or {}
    if on ~= nil then ad.items[id].on = on end
    ad.pending = nil -- selection changed: start the rotation over
end


function ns.AddCustom(text)
    local id = "custom_" .. ns.db.nextCustom
    ns.db.nextCustom = ns.db.nextCustom + 1
    table.insert(ns.db.custom, { id = id, text = text or "New line", prof = ns.ProfOf() })
    ns.SetItemState(ns.ActiveAd(), id, true)
    return id
end

function ns.RemoveCustom(id)
    for i, c in ipairs(ns.db.custom) do
        if c.id == id then table.remove(ns.db.custom, i) break end
    end
    for _, ad in ipairs(ns.db.ads) do ad.items[id] = nil end
end

-------------------------------------------------------------------------------
-- Message building
-------------------------------------------------------------------------------
-- A raw "|" starts an escape code in WoW chat, so plain text pipes are doubled.
local function Safe(s) return (((s or ""):gsub("|", "||"))) end

-------------------------------------------------------------------------------
-- Auction house price estimates (reference only), from Auctionator's price
-- database (fills in as you scan the AH with Auctionator). Prices are copper.
-------------------------------------------------------------------------------
local function AuctionatorAPI()
    return Auctionator and Auctionator.API and Auctionator.API.v1
end

function ns.HasAuctionator()
    local api = AuctionatorAPI()
    return api and api.GetAuctionPriceByItemID and true or false
end
function ns.HasTSM()
    return type(TSM_API) == "table" and type(TSM_API.GetCustomPriceValue) == "function"
        and type(TSM_API.ToItemString) == "function"
end

-- Which addon the AH prices come from. "auto" picks whichever is installed
-- (Auctionator first if both are, since it also knows when you scanned).
ns.PRICE_SOURCES = {
    { value = "auto",        label = "Automatic" },
    { value = "auctionator", label = "Auctionator" },
    { value = "tsm",         label = "TradeSkillMaster" },
}
-- TSM's price values to pick from (its own price source keys)
ns.TSM_VALUES = {
    { value = "DBMarket",     label = "Market Value" },
    { value = "DBMinBuyout",  label = "Minimum Buyout" },
    { value = "DBRecent",     label = "Recent Value" },
    { value = "DBRegionMarketAvg", label = "Region Market Avg" },
}
function ns.PriceSource()
    local want = ns.db.settings.priceSource or "auto"
    if want == "auctionator" then return ns.HasAuctionator() and "auctionator" or nil end
    if want == "tsm" then return ns.HasTSM() and "tsm" or nil end
    if ns.HasAuctionator() then return "auctionator" end
    if ns.HasTSM() then return "tsm" end
end
function ns.PriceSourceName(src)
    src = src or ns.PriceSource()
    return (src == "tsm" and "TradeSkillMaster") or (src == "auctionator" and "Auctionator") or nil
end
function ns.HasPriceSource() return ns.PriceSource() ~= nil end

-- TSM: price of an item (link or item ID) by the chosen TSM value
local function TSMPrice(item, key)
    if not ns.HasTSM() then return end
    local str = type(item) == "string" and item or ("i:" .. tostring(item))
    local okS, itemString = pcall(TSM_API.ToItemString, str)
    if not okS or type(itemString) ~= "string" then return end
    local ok, v = pcall(TSM_API.GetCustomPriceValue, key or ns.db.settings.tsmValue or "DBMarket", itemString)
    if ok and type(v) == "number" and v > 0 then return v end
end

-- price, source name, daysSinceSeen, exact time seen
function ns.AHPrice(e)
    if not e or not e.item or e.noAH or not ns.db.settings.ahPrices then return end
    if ns.PriceSource() == "tsm" then
        local key = ns.db.settings.tsmValue or "DBMarket"
        local p = TSMPrice(ns.ItemLink(e) or e.item, key) or TSMPrice(e.item, key)
        if not p then return end
        local label = "TSM"
        for _, t in ipairs(ns.TSM_VALUES) do if t.value == key then label = "TSM " .. t.label end end
        return p, label
    end
    if ns.PriceSource() ~= "auctionator" then return end
    local api = AuctionatorAPI()
    if not (api and api.GetAuctionPriceByItemID) then return end
    local link = ns.ItemLink(e)
    local ok, price
    if link and api.GetAuctionPriceByItemLink then ok, price = pcall(api.GetAuctionPriceByItemLink, "ShoutOut", link) end
    if not (ok and type(price) == "number" and price > 0) then
        ok, price = pcall(api.GetAuctionPriceByItemID, "ShoutOut", e.item)
    end
    if not ok or type(price) ~= "number" or price <= 0 then return end
    local age
    if api.GetAuctionAgeByItemID then
        local ok2, a = pcall(api.GetAuctionAgeByItemID, "ShoutOut", e.item)
        if ok2 and type(a) == "number" then age = a end
    end
    return price, "Auctionator", age, ns.AHSeenAt(e.item, price, age)
end

-- Auctionator only keeps prices per day, so Shout Out notes the moment it sees
-- each price arrive from a scan. Returns that time when it's trustworthy.
function ns.AHSeenAt(item, price, age)
    local s = ns.db.ahSeen[item]
    if not (s and s.t) then return end
    if age and age > 0 then
        -- Auctionator says it hasn't been seen for `age` days; our time must agree
        local days = math.floor((time() - s.t) / 86400)
        if days < age - 1 then return end
    end
    return s.t
end

-- After each Auctionator scan: any price that changed (or showed up today for
-- the first time since we last looked) was just scanned.
function ns.NoteAHScan()
    local now = time()
    local today = date("%Y-%m-%d", now)
    for _, e in ipairs(ns.CATALOG) do
        if e.item then
            local p, _, age = ns.AHPrice(e)
            if p then
                local s = ns.db.ahSeen[e.item]
                if not s or s.p ~= p or (age == 0 and date("%Y-%m-%d", s.t) ~= today) then
                    ns.db.ahSeen[e.item] = { p = p, t = now }
                end
            end
        end
    end
end

-- "just now", "12 minutes ago", "3 hours 20 minutes ago", "2 days 5 hours ago"
function ns.FormatAgo(t)
    local d = math.max(0, time() - t)
    local function n(v, w) return v .. " " .. w .. (v == 1 and "" or "s") end
    if d < 60 then return "just now" end
    if d < 3600 then return n(math.floor(d / 60), "minute") .. " ago" end
    if d < 86400 then
        local h, m = math.floor(d / 3600), math.floor((d % 3600) / 60)
        return n(h, "hour") .. (m > 0 and (" " .. n(m, "minute")) or "") .. " ago"
    end
    local days, h = math.floor(d / 86400), math.floor((d % 86400) / 3600)
    return n(days, "day") .. (h > 0 and (" " .. n(h, "hour")) or "") .. " ago"
end

-------------------------------------------------------------------------------
-- Material cost (Enchanting): what a recipe's reagents cost on the AH right
-- now. Reference only, so you know what to charge when people bring nothing.
-------------------------------------------------------------------------------
local noSchematic = {}
-- { itemID, count, itemID, count, ... } from the game when it can tell us,
-- otherwise from Shout Out's list (Wowhead, Nov 2026)
function ns.Reagents(e)
    if not (e and e.spell) then return end
    local spell = e.spell
    if ns.db.reagents[spell] then return ns.db.reagents[spell] end
    local T = C_TradeSkillUI
    if not noSchematic[spell] and T and type(T.GetRecipeSchematic) == "function" then
        local ok, sch = pcall(T.GetRecipeSchematic, spell, false)
        local list = {}
        if ok and type(sch) == "table" and type(sch.reagentSlotSchematics) == "table" then
            for _, slot in ipairs(sch.reagentSlotSchematics) do
                local r = type(slot.reagents) == "table" and slot.reagents[1]
                local basic = slot.reagentType == nil or slot.reagentType == 1
                if basic and r and r.itemID and (slot.quantityRequired or 0) > 0 then
                    list[#list + 1] = r.itemID
                    list[#list + 1] = slot.quantityRequired
                end
            end
        end
        if #list > 0 then ns.db.reagents[spell] = list; return list end
        noSchematic[spell] = true
    end
    return ns.REAGENTS and ns.REAGENTS[spell]
end

function ns.ReagentName(item)
    local name = ItemInfo(item)
    return name or (ns.REAGENT_NAMES and ns.REAGENT_NAMES[item]) or ("Item " .. item)
end

-- One material's price: the AH (Auctionator), or the vendor price for things
-- only vendors sell (vials, rods' wood...). Returns copper, "AH"/"vendor"
local function MatPrice(item)
    if ns.PriceSource() == "tsm" then
        local p = TSMPrice(item)
        if p then return p, "AH" end
        p = TSMPrice(item, "VendorBuy")
        if p then return p, "vendor" end
        return
    end
    local api = AuctionatorAPI()
    if not api then return end
    if api.GetAuctionPriceByItemID then
        local ok, p = pcall(api.GetAuctionPriceByItemID, "ShoutOut", item)
        if ok and type(p) == "number" and p > 0 then return p, "AH" end
    end
    if api.GetVendorPriceByItemID then
        local ok, p = pcall(api.GetVendorPriceByItemID, "ShoutOut", item)
        if ok and type(p) == "number" and p > 0 then return p, "vendor" end
    end
end

-- total copper, parts = { { item, n, each, src }, ... }, missing = how many
-- materials have no price yet. nil when off or nothing is known.
function ns.MatsCost(e)
    if not ns.db.settings.ahPrices or not ns.HasPriceSource() then return end
    local list = ns.Reagents(e)
    if not list or #list == 0 then return end
    local total, parts, missing = 0, {}, 0
    for i = 1, #list, 2 do
        local item, n = list[i], list[i + 1]
        local each, src = MatPrice(item)
        if each then total = total + each * n else missing = missing + 1 end
        parts[#parts + 1] = { item = item, n = n, each = each, src = src }
    end
    return total, parts, missing
end

-- Refresh the estimates when Auctionator finishes a scan
function ns.HookAuctionator()
    local api = AuctionatorAPI()
    if ns.auctionatorHooked or not (api and api.RegisterForDBUpdate) then return end
    ns.auctionatorHooked = pcall(api.RegisterForDBUpdate, "ShoutOut", function()
        ns.NoteAHScan()
        if ns.Refresh then ns.Refresh(true) end
    end)
end

-- Reference prices: gold and silver, no copper. 1234567 -> "123g 45s",
-- 45000 -> "4g 50s", 3500 -> "35s"; under a silver -> "12c"
function ns.FormatMoney(c)
    if not c then return "" end
    c = math.floor(c)
    if c < 100 then return string.format("%dc", c) end
    local g, sv = math.floor(c / 10000), math.floor((c % 10000) / 100)
    if g == 0 then return sv .. "s" end
    if sv == 0 then return g .. "g" end
    return g .. "g " .. sv .. "s"
end

-- "1g 50s" / "2.5g" / "75s" / "100" (gold) -> copper; nil if there's no amount
function ns.ParseMoney(text)
    text = tostring(text or ""):lower()
    local total, found = 0, false
    for num, unit in text:gmatch("(%d+%.?%d*)%s*([gsc]?)") do
        local v = tonumber(num) or 0
        local mult = (unit == "s" and 100) or (unit == "c" and 1) or 10000
        total, found = total + v * mult, true
    end
    total = math.floor(total + 0.5)
    if not found or total <= 0 then return nil end
    return total
end

-- copper -> gold, silver, copper
function ns.SplitMoney(c)
    c = math.max(0, math.floor(c or 0))
    return math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
end

-- copper -> how the price reads in chat: "120g", "2g 50s", "75s", "1g 5c"
function ns.FormatCoins(c)
    if not c or c <= 0 then return "" end
    local g, s, cp = ns.SplitMoney(c)
    local out = {}
    if g > 0 then out[#out + 1] = g .. "g" end
    if s > 0 then out[#out + 1] = s .. "s" end
    if cp > 0 then out[#out + 1] = cp .. "c" end
    return table.concat(out, " ")
end

-- Fill empty prices with the exact AH estimates (never overwrites yours).
-- Returns how many were filled.
function ns.FillPricesFromAH(entries)
    local n = 0
    for _, e in ipairs(entries) do
        if e.item and not ns.db.prices[e.id] then
            local p = ns.AHPrice(e)
            if p then ns.db.prices[e.id] = p; n = n + 1 end
        end
    end
    return n
end

-- Ammo and explosives sell by the stack: their sections are marked stack = true,
-- and each item can be switched between a stack price and a price each.
function ns.StackSection(e)
    local def = e and ns.SLOTS[ns.slotIndex[e.slot] or 0]
    return def and def.stack and true or false
end
-- Anything that stacks in the game (not gear, not transmutes) can be priced
-- per stack. Sections where stacks are the norm (ammo, explosives, food)
-- start on "stack"; everything else starts on "each".
function ns.CanStack(e)
    if not (e and e.item) or e.service then return false end
    return ns.StackSection(e) or ns.StackSize(e) ~= nil
end
function ns.PriceUnit(e)
    if e and e.fixedUnit then return e.fixedUnit end -- e.g. conjured food: always per stack
    if not ns.CanStack(e) then return nil end
    return ns.db.priceUnit[e.id] or (ns.StackSection(e) and "stack" or "each")
end
function ns.SetPriceUnit(id, unit) ns.db.priceUnit[id] = unit end
-- how many make a stack (from the game; nil until it knows)
function ns.StackSize(e)
    if not (e and e.item) then return end
    local n
    if C_Item and C_Item.GetItemInfo then n = select(8, C_Item.GetItemInfo(e.item))
    elseif GetItemInfo then n = select(8, GetItemInfo(e.item)) end
    return type(n) == "number" and n > 1 and n or nil
end

-- prices are kept in copper
function ns.GetPriceC(id) return ns.db.prices[id] end
function ns.SetPriceC(id, c)
    c = tonumber(c)
    ns.db.prices[id] = (c and c > 0) and math.floor(c) or nil
end
function ns.GetPrice(id) return ns.FormatCoins(ns.db.prices[id]) end
-- Empties the prices of the given entries; returns how many were cleared
function ns.ClearPrices(entries)
    local n = 0
    for _, e in ipairs(entries) do
        if ns.db.prices[e.id] then ns.db.prices[e.id] = nil; n = n + 1 end
    end
    return n
end
function ns.SetPrice(id, text) ns.SetPriceC(id, ns.ParseMoney(text)) end

-- Crafted items go in as their clickable link (while "Item links" is on),
-- followed by your price if you set one: [Dreamscale Breastplate] 100g
-- While one ad is being packed, each item's text is worked out once and
-- reused for every trial render (the packer renders the ad many times).
local outMemo
local ItemOutTextRaw
local function ItemOutText(id, ad, mode)
    if not outMemo then return ItemOutTextRaw(id, ad, mode) end
    local k = id .. "\001" .. tostring(mode)
    local v = outMemo[k]
    if v == nil then v = ItemOutTextRaw(id, ad, mode); outMemo[k] = v end
    return v
end
function ItemOutTextRaw(id, ad, mode)
    local e = ns.GetEntry(id)
    if e and e.item then
        local out
        if mode ~= "text" and ad and ad.links then
            -- services (transmutes) post the recipe link, not what it makes
            if e.service then out = ns.RecipeLink(e) else out = ns.ItemLink(e) end
        end
        out = out or Safe(ns.ItemText(id))
        if e.pricePrefix then out = out .. " " .. e.pricePrefix end -- "[Mooncloth] CD 30g"
        local price = ns.GetPrice(id)
        if price ~= "" then
            local unit = ns.PriceUnit(e)
            -- "/stack" for stacks; " ea" only where stacks are the norm, so it's clear
            out = out .. " " .. price .. (unit == "stack" and "/stack" or (unit == "each" and ns.StackSection(e)) and " ea" or "")
        end
        return out
    end
    -- priced lines (mage portals, summon places): "TB 5g"
    local text = Safe(ns.ItemText(id))
    if e and ns.Pack(e.prof).pricedText then
        local price = ns.GetPrice(id)
        if price ~= "" and text ~= "" then text = text .. " " .. price end
    end
    return text
end

-- {prof} becomes your clickable profession link, e.g. [Enchanting] (captured
-- when you open that profession's window). Until then it posts plain text.
function ns.ProfLink(prof)
    local l = ns.db.profLinks[prof or ns.ProfOf()]
    if type(l) == "string" and l:find("|H", 1, true) then return l end
end

-- {prof} = this ad's profession link; {prof:Tailoring} = a named profession's
-- link (for class and custom ads: "Also offering [Tailoring]")
function ns.ProfByName(name)
    name = (name or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    for _, p in ipairs(ns.PROFESSIONS) do
        if p.key == name or p.name:lower() == name then return p end
    end
end
function ns.ExpandTokens(text, ad)
    local prof = ns.ProfOf(ad)
    text = text:gsub("{[Pp][Rr][Oo][Ff]:([^}]*)}", function(name)
        local p = ns.ProfByName(name)
        if not p then return name end
        return ns.ProfLink(p.key) or p.name
    end)
    return (text:gsub("{[Pp][Rr][Oo][Ff]}", function()
        if ns.Pack(prof).always then return "" end -- not a profession: nothing to link
        return ns.ProfLink(prof) or ns.Pack(prof).fallback
    end))
end

-- List tokens: {items} / {enchants} / {list} is everything you checked, and
-- {items:Armor Kits} (or {items:Cloak, Chest}) is just those sections, so you
-- can write text between groups. A section placed by its own token is never
-- repeated in the plain {items}.
local LIST_WORDS = { enchants = true, items = true, list = true, places = true } -- {places}: Warlock

-- "{items:Armor Kits}" -> { sections = { "armor kits" } }, "{items}" -> { all = true }
local function ParseListToken(inner)
    local word, rest = inner:match("^(%a+)%s*:%s*(.-)%s*$")
    word = word or inner:match("^%s*(%a+)%s*$")
    if word and word:lower() == "portals" and not rest then return { portals = true } end
    if not (word and LIST_WORDS[word:lower()]) then return end
    if not rest or rest == "" then return { all = true } end
    local secs = {}
    for name in rest:gmatch("[^,]+") do
        name = name:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if name ~= "" then secs[#secs + 1] = name end
    end
    return { sections = secs }
end

-- Which sections a name in a token means: a section's label, short label or
-- key (any case), or a group of sections ("Food" = every Food level)
local function SlotsByName(prof, name)
    local keys = {}
    for _, def in ipairs(ns.OrderedSlots(prof)) do
        if def.label:lower() == name or def.key:lower() == name
            or ((ns.SlotShort(def.key) or ""):lower() == name and name ~= "") or ((def.short or ""):lower() == name and name ~= "") then
            return { def.key }, false
        end
        if def.group and def.group:lower() == name then keys[#keys + 1] = def.key end
    end
    return keys, true
end

-- The list tokens in a template, in order: { { text = "{items:Kits}", spec = ... }, ... }
function ns.ListTokens(template)
    local out = {}
    for inner in (template or ""):gmatch("{([^{}]*)}") do
        local spec = ParseListToken(inner)
        if spec then out[#out + 1] = { text = "{" .. inner .. "}", spec = spec } end
    end
    return out
end

function ns.HasListToken(ad)
    return #ns.ListTokens(ns.Template(ad)) > 0
end

-- Message as shown in a chat window preview: escaped pipes shown as one "|"
-- (links and colors stay so they look like chat)
-- The chat font draws "| /w" with the space swallowed ("|/w"); the posted
-- message is fine, so the preview gets one extra space there to match it.
function ns.DisplayText(msg)
    return (msg:gsub("||", "\001"):gsub("\001 /", "\001  /"):gsub("\001", "|"))
end

-- Plain text for copying: links become [Name], colors removed
function ns.PlainText(msg)
    return (msg:gsub("||", "\001"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1"):gsub("\001", "|"))
end

-- What other players actually see: links collapse to their [Name] text.
function ns.VisibleLength(msg)
    return #ns.PlainText(msg)
end

-- Mage portals: the checked cities, except the one you're standing in, plus
-- "from <here>" when you're in one of the portal cities: "UC or TB from ORG"
function ns.CurrentZone()
    return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
end
function ns.PortalsText(ad, chosen)
    local here = ns.CurrentZone()
    local dests, from = {}, nil
    for _, e in ipairs(ns.AllEntries(ns.ProfOf(ad))) do
        local def = ns.SLOTS[ns.slotIndex[e.slot] or 0]
        if def and def.ownToken == "portals" then
            local name = Safe(ns.ItemText(e.id))
            if e.zone == here then from = name
            elseif chosen[e.id] and name ~= "" then
                dests[#dests + 1] = { name = name, price = ns.GetPrice(e.id) }
            end
        end
    end
    if #dests == 0 then return "" end
    -- one shared price: "UC & TB 40s from ORG"; different prices: "UC 40s & TB 50s"
    local same = dests[1].price
    for _, d in ipairs(dests) do if d.price ~= same then same = nil break end end
    local parts = {}
    for _, d in ipairs(dests) do
        parts[#parts + 1] = (same or d.price == "") and d.name or (d.name .. " " .. d.price)
    end
    local text = table.concat(parts, " & ")
    if same and same ~= "" then text = text .. " " .. same end
    return text .. (from and (" from " .. from) or "")
end

-- Each ad has its own separator; until you pick one, item ads without slot
-- labels use a comma and everything else uses the global default
-- The Separator only applies where one list token covers labelled groups:
-- Enchanting, or a crafting ad with Slot labels on. Everywhere else groups
-- are joined with commas and you type your own dividers.
function ns.SepApplies(ad)
    local pack = ns.Pack(ns.ProfOf(ad))
    if pack.placeSep then return true end -- Warlock: between every summon spot
    if pack.always then return false end
    return pack.kind ~= "item" or (ad and ad.slotLabels) and true or false
end
function ns.AdSep(ad)
    if not ns.SepApplies(ad) then return ", " end
    if ad and ad.sep then return ad.sep end
    if ns.Pack(ns.ProfOf(ad)).placeSep then return ", " end -- Warlock starts on a comma
    return ns.db.settings.sep
end

-- Renders a message from a set of chosen ids. Items are grouped by slot in
-- slot order, so the ad reads cleanly no matter what order they were chosen in.
-- Each list token gets its own sections; text around a token that ends up
-- empty (e.g. "Crafting:" when no gear is in this post) is left out.
function ns.Render(ad, chosen)
    local s = ns.db.settings
    local prof = ns.ProfOf(ad)
    local entries = {}
    for id in pairs(chosen) do
        local e = ns.GetEntry(id)
        if e then entries[#entries + 1] = e end
    end
    local rank = {}
    for i, def in ipairs(ns.OrderedSlots(prof)) do rank[def.key] = i end
    table.sort(entries, function(a, b)
        local sa, sb = rank[a.slot] or 999, rank[b.slot] or 999
        if sa ~= sb then return sa < sb end
        return ns.ItemRank(a) < ns.ItemRank(b)
    end)
    local groups, cur = {}, nil
    for _, e in ipairs(entries) do
        if not cur or cur.slot ~= e.slot then
            cur = { slot = e.slot, texts = {} }
            groups[#groups + 1] = cur
        end
        cur.texts[#cur.texts + 1] = ItemOutText(e.id, ad, chosen[e.id])
    end

    -- which token each section belongs to (first token naming it wins)
    local tmpl = ns.Template(ad):gsub("[\r\n]+", " ")
    local tokens = ns.ListTokens(tmpl)
    local owner = {}
    -- a token naming one section beats a group token ("Food") for that section
    for pass = 1, 2 do
        for ti, tok in ipairs(tokens) do
            for _, name in ipairs(tok.spec.sections or {}) do
                local keys, isGroup = SlotsByName(prof, name)
                if (pass == 1) ~= isGroup then
                    for _, key in ipairs(keys) do
                        if not owner[key] then owner[key] = ti end
                    end
                end
            end
        end
    end
    -- what goes between groups (sections, and item tokens side by side): the
    -- ad's own separator; item ads without slot labels default to a comma
    local joiner = Safe(ns.AdSep(ad))
    local function SectionOwnToken(slot)
        local def = ns.SLOTS[ns.slotIndex[slot] or 0]
        return def and def.ownToken
    end
    local function BodyFor(ti, tok)
        if tok.spec.portals then return ns.PortalsText(ad, chosen) end
        local parts = {}
        for _, g in ipairs(groups) do
            local mine
            if tok.spec.all then mine = owner[g.slot] == nil and not SectionOwnToken(g.slot) else mine = owner[g.slot] == ti end
            if mine then
                local label = (ad.slotLabels and not ns.Pack(prof).class) and Safe(ns.SlotShort(g.slot)) or ""
                -- Warlock: the separator goes between every place, not just sections
                local within = ns.Pack(prof).placeSep and joiner or ", "
                parts[#parts + 1] = (label ~= "" and (label .. ": ") or "") .. table.concat(g.texts, within)
            end
        end
        return table.concat(parts, joiner)
    end
    local bodies = {}
    for ti, tok in ipairs(tokens) do bodies[ti] = BodyFor(ti, tok) end

    -- swap tokens for markers, so the user's text can be escaped safely
    local ti = 0
    local marked = tmpl:gsub("{([^{}]*)}", function(inner)
        if not ParseListToken(inner) then return nil end
        ti = ti + 1
        return "\002" .. ti .. "\003"
    end)
    -- tokens side by side ("{items:Ammo} {items:Explosives}") read as one list,
    -- with a comma between whichever of them have items
    while true do
        local changed
        marked, changed = marked:gsub("\002(%d+)\003%s*,?%s*\002(%d+)\003", function(x, y)
            local parts = {}
            for _, n in ipairs({ tonumber(x), tonumber(y) }) do
                if bodies[n] and bodies[n] ~= "" then parts[#parts + 1] = bodies[n] end
            end
            bodies[#bodies + 1] = table.concat(parts, joiner)
            return "\002" .. #bodies .. "\003"
        end, 1)
        if changed == 0 then break end
    end
    -- split at the pipes you type between parts of the ad
    local segs, delims = {}, {}
    local pos = 1
    while true do
        local a, b = marked:find("%s*|+%s*", pos)
        if not a then segs[#segs + 1] = marked:sub(pos); break end
        segs[#segs + 1] = marked:sub(pos, a - 1)
        delims[#segs] = marked:sub(a, b)
        pos = b + 1
    end
    local keep = {}
    for i, seg in ipairs(segs) do
        local hadToken = seg:find("\002") ~= nil
        local anyBody = false
        for n in seg:gmatch("\002(%d+)\003") do if bodies[tonumber(n)] ~= "" then anyBody = true end end
        -- an empty group takes its label with it: "Crafting: " before it, back
        -- to the last ! . ? ; , in that part
        seg = seg:gsub("([^!%.%?;,\002\003]-:%s*)(\002(%d+)\003)", function(label, m, n)
            if bodies[tonumber(n)] == "" then return "" end
            return label .. m
        end)
        -- an empty group goes, with the one space in front of it (your own
        -- spacing everywhere else is kept exactly as typed)
        seg = seg:gsub(" ?\002(%d+)\003", function(n) if bodies[tonumber(n)] == "" then return "" end end)
        -- tidy commas left behind by an empty group
        seg = seg:gsub("([!%.%?;,])%s*,", "%1"):gsub("^%s*,%s*", ""):gsub("%s*,%s*$", "")
        local text = Safe(seg):gsub("\002(%d+)\003", function(n) return bodies[tonumber(n)] or "" end)
        -- a part whose groups are all empty goes away entirely ("WTS {items:X}"),
        -- unless it holds your {prof} opener
        local orphan = hadToken and not anyBody and not seg:find("{[Pp][Rr][Oo][Ff]}")
        if not orphan and not (hadToken and text:match("^%s*$")) then
            -- a part whose group was empty runs straight into the next one:
            -- "LFW! | Crafting: ..." reads as "LFW! Crafting: ..."
            keep[#keep + 1] = { text = text, delim = delims[i], emptied = hadToken and not anyBody }
        end
    end
    local function Join(from, to)
        local out = {}
        for i = from, to do
            local k = keep[i]
            out[#out + 1] = k.text
            if i < to then out[#out + 1] = k.emptied and " " or Safe(k.delim or " | ") end
        end
        return table.concat(out)
    end
    local function Finish(text)
        text = ns.ExpandTokens(text, ad)
        if ad.caps then text = ns.Caps(text) end
        return (text:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    -- Repeat: everything before the last | part, n times; the last part
    -- (e.g. "/w me") once at the end
    local rep = ns.Pack(prof).repeatable and ad.repeatN or 1 -- Warlock ads only
    if not rep or rep == 1 or #keep == 0 then return Finish(Join(1, #keep)) end
    local head, tail
    if #keep > 1 then head, tail = Join(1, #keep - 1), keep[#keep].text else head = Join(1, 1) end
    local between = Safe((#keep > 1 and keep[#keep - 1].delim) or " | ")
    local function Make(n)
        local parts = {}
        for i = 1, n do parts[i] = head end
        local text = table.concat(parts, between)
        if tail then text = text .. between .. tail end
        return Finish(text)
    end
    if rep == "fill" then
        local n = 1
        while n < 10 and ns.Fits(Make(n + 1)) do n = n + 1 end
        return Make(n)
    end
    return Make(tonumber(rep) or 1)
end

-- ALL CAPS: capitals for your text, but links, colors, icons and {codes}
-- stay exactly as they are (the game checks link names). Everything that
-- must not change is set aside first, then put back after capitalizing.
-- Handles both color styles: |cffRRGGBB and the newer |cnIQ1: kind.
function ns.Caps(msg)
    local keep = {}
    local function hold(x) keep[#keep + 1] = x; return "\001" .. #keep .. "\002" end
    msg = msg:gsub("||", hold)                                   -- a typed pipe
    msg = msg:gsub("|c[^|]*|H.-|h.-|h|r", hold)                  -- colored link
    msg = msg:gsub("|H.-|h.-|h", hold)                           -- bare link
    msg = msg:gsub("|T.-|t", hold)                               -- icon texture
    msg = msg:gsub("|cn[^:|]*:", hold):gsub("|c%x%x%x%x%x%x%x%x", hold):gsub("|r", hold)
    msg = msg:gsub("{[^{}]*}", hold)                             -- {rt1} etc.
    msg = msg:upper()
    -- prices stay "1g 50s", and whisper hints stay "/w me"
    msg = msg:gsub("(%d)([GSC])%f[^%a]", function(d, u) return d .. u:lower() end)
    msg = msg:gsub("/W ME%f[^%a]", "/w me"):gsub("/W%f[^%a]", "/w"):gsub("/STACK", "/stack")
    return (msg:gsub("\001(%d+)\002", function(n) return keep[tonumber(n)] end))
end

-- How long the message looks to players: links count as their [Name] text.
function ns.MeasureLen(msg)
    return ns.VisibleLength(msg)
end

-- A message must pass both limits: <= 255 visible characters, and <= 280
-- counting the hidden link code (tested in WoW Forever).
function ns.Fits(msg)
    return ns.VisibleLength(msg) <= ns.MaxLen() and #msg <= ns.MaxRaw()
end

-- 0..1+ : how full the message is against whichever limit is tighter
function ns.Fullness(msg)
    return math.max(ns.VisibleLength(msg) / ns.MaxLen(), #msg / ns.MaxRaw())
end

-- Packs as many ticked enchants as fit into 255 characters.
-- Slots take turns (each slot's 1st enchant, then each slot's 2nd, ...), so
-- every slot gets a mention before any slot gets a second one.
-- Rotation: enchants that didn't fit become the "pending" list, and the next
-- post contains only those. Once everything has been shown, it starts over.
-- pending (optional set of ids) overrides ad.pending, used to preview the next post.
-- Returns message, includedIds, droppedIds, nextPending (set or nil)
local BuildInner
function ns.Build(ad, pending)
    local outer = outMemo == nil
    if outer then outMemo = {} end
    local ok, a, b, c, d = pcall(BuildInner, ad, pending)
    if outer then outMemo = nil end
    if not ok then error(a, 0) end
    return a, b, c, d
end
function BuildInner(ad, pending)
    ad = ad or ns.ActiveAd()
    local s = ns.db.settings
    if pending == nil and ns.Rotating(ad) then pending = ad.pending end
    if pending == false then pending = nil end -- explicit "first post of the cycle"

    local function Collect(filter)
        local bySlot, any = {}, false
        for _, e in ipairs(ns.AllEntries(ns.ProfOf(ad))) do -- known-only, your order
            if ns.ItemState(ad, e.id) and ns.ItemText(e.id) ~= "" and (not filter or filter[e.id]) then
                bySlot[e.slot] = bySlot[e.slot] or {}
                table.insert(bySlot[e.slot], e.id)
                any = true
            end
        end
        return bySlot, any
    end
    local bySlot, any = Collect(pending)
    if pending and not any then bySlot = Collect(nil) end -- pending ones were unticked

    local queues = {}
    for _, def in ipairs(ns.OrderedSlots(ns.ProfOf(ad))) do
        if bySlot[def.key] then queues[#queues + 1] = bySlot[def.key] end
    end

    local chosen, included, dropped = {}, {}, {}
    -- Item ads with links on pack the links themselves (crafters sell with
    -- links; each carries ~60-70 hidden characters, so fewer fit per post and
    -- rotation carries the rest). Everything else packs as text.
    local mode = ad.links and true or "text"
    -- Speed: adding an item makes the message at least as long as that item's
    -- own text, so one that can't fit is dropped without rendering the whole
    -- ad again (big lists went from ~0.5 s to a few ms). Not used where an
    -- item can add less than its text: shared portal prices, and Repeat.
    local quick = not ns.noQuickPack and not (ns.Pack(ns.ProfOf(ad)).repeatable and ad.repeatN and ad.repeatN ~= 1)
    -- sections the message actually shows (an item in a section no token
    -- names never appears, so it always "fits"; it mustn't count as dropped)
    local shownAll, shown = false, {}
    for _, tok in ipairs(ns.ListTokens(ns.Template(ad))) do
        if tok.spec.all then shownAll = true end
        for _, name in ipairs(tok.spec.sections or {}) do
            for _, key in ipairs((SlotsByName(ns.ProfOf(ad), name))) do shown[key] = true end
        end
    end
    local cur = ns.Render(ad, chosen)
    local curVis, curRaw = ns.VisibleLength(cur), #cur
    local MAXV, MAXR = ns.MaxLen(), ns.MaxRaw()
    local function Try(id)
        local e = ns.GetEntry(id)
        local def = e and ns.SLOTS[ns.slotIndex[e.slot] or 0]
        if quick and e and not (def and def.ownToken) and not (shownAll or shown[e.slot]) then
            -- no token shows this section: the message can't change
            chosen[id] = mode
            included[#included + 1] = id
            return
        end
        if quick and e and not (def and def.ownToken) then
            local t = ItemOutText(id, ad, mode)
            if curVis + ns.VisibleLength(t) > MAXV or curRaw + #t > MAXR then
                dropped[#dropped + 1] = id
                return
            end
        end
        chosen[id] = mode
        local msg = ns.Render(ad, chosen)
        if ns.Fits(msg) then
            cur, curVis, curRaw = msg, ns.VisibleLength(msg), #msg
            included[#included + 1] = id
        else
            chosen[id] = nil
            dropped[#dropped + 1] = id
        end
    end
    local per = ns.PerSlot()
    if ns.Pack(ns.ProfOf(ad)).kind == "item" or not ad.slotLabels or ns.Pack(ns.ProfOf(ad)).always then
        -- Crafted items, or no slot labels: your checked items, in the order you set
        for _, q in ipairs(queues) do
            for _, id in ipairs(q) do Try(id) end
        end
    elseif per > 0 then
        -- Up to N per slot: fill each slot in order before moving on.
        -- Anything past N waits for the next post.
        for _, q in ipairs(queues) do
            for i, id in ipairs(q) do
                if i <= per then Try(id) else dropped[#dropped + 1] = id end
            end
        end
    else
        -- Spread evenly: every slot's 1st enchant, then every slot's 2nd, ...
        local depth, more = 0, true
        while more do
            more, depth = false, depth + 1
            for _, q in ipairs(queues) do
                if q[depth] then more = true; Try(q[depth]) end
            end
        end
    end

    local nextPending
    if #dropped > 0 and #included > 0 then
        nextPending = {}
        for _, id in ipairs(dropped) do nextPending[id] = true end
    end
    return ns.Render(ad, chosen), included, dropped, nextPending
end

-- Rotate overflow is set per ad
function ns.Rotating(ad)
    ad = ad or ns.ActiveAd()
    if ad and ns.Pack(ns.ProfOf(ad)).class then return false end -- Mage and Warlock ads don't rotate
    return ad and ad.rotate and true or false
end

-- True when the next post is an overflow post (the enchants that didn't fit)
function ns.IsOverflowNext(ad)
    ad = ad or ns.ActiveAd()
    return ns.Rotating(ad) and ad.pending ~= nil and next(ad.pending) ~= nil
end

-- The message the next post would send: only the enchants this post missed.
-- nil when rotation is off or everything already fits.
-- Rotation is at most two posts: the first post, then one overflow post with
-- only what the first missed. After the overflow it starts over.
function ns.BuildNext(ad)
    ad = ad or ns.ActiveAd()
    if not ns.Rotating(ad) then return end
    if ns.IsOverflowNext(ad) then
        return ns.Build(ad, false) -- after the overflow: back to the first post
    end
    local _, _, _, nextPending = ns.Build(ad)
    if not nextPending then return end
    return ns.Build(ad, nextPending)
end

-- Enchants that fit in neither the first post nor the overflow post
function ns.LeftOutOfCycle(ad)
    ad = ad or ns.ActiveAd()
    if not ns.Rotating(ad) then return {} end
    local _, _, drop1, nextPending = ns.Build(ad, false)
    if not nextPending then return drop1 end
    local _, _, drop2 = ns.Build(ad, nextPending)
    return drop2
end

local function AdvanceRotation(ad)
    if not ns.Rotating(ad) then ad.pending = nil return end
    if ns.IsOverflowNext(ad) then
        ad.pending = nil -- that was the overflow post: start over next time
        return
    end
    local _, _, _, nextPending = ns.Build(ad)
    ad.pending = nextPending -- nil when everything fit
end

-------------------------------------------------------------------------------
-- Channels
-------------------------------------------------------------------------------
function ns.GetJoinedChannels()
    local list = {}
    local raw = { GetChannelList() }
    local count = select("#", GetChannelList())
    local i = 1
    while i <= count do
        local id, name = raw[i], raw[i + 1]
        if type(id) == "number" and type(name) == "string" then
            if not name:find("^ShoutOutTest") then -- our private test channel isn't a place to post
                list[#list + 1] = { id = id, name = name }
            end
            i = i + ((type(raw[i + 2]) == "boolean") and 3 or 2)
        else
            i = i + 1
        end
    end
    return list
end

-- How a channel reads in Shout Out: community channels come through as
-- "Community:123456:1", so show the community's name (or just "Community")
function ns.ChannelLabel(name)
    if type(name) ~= "string" then return "" end
    local club = name:match("^Community:(%d+)")
    if club then
        if C_Club and C_Club.GetClubInfo then
            local ok, info = pcall(C_Club.GetClubInfo, club)
            if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
        end
        return "Community"
    end
    return (name:gsub("(:%d+)+$", ""))
end

-- Non-channel places to post. Stored in settings.channel as "@SAY" etc.
ns.CHAT_TARGETS = {
    { key = "@SAY",   chatType = "SAY",   name = "Say" },
    { key = "@YELL",  chatType = "YELL",  name = "Yell" },
    { key = "@GUILD", chatType = "GUILD", name = "Guild", needsGuild = true },
}

function ns.FindChannel()
    local raw = ns.db.settings.channel or ""
    for _, t in ipairs(ns.CHAT_TARGETS) do
        if raw == t.key and (not t.needsGuild or (IsInGuild and IsInGuild())) then
            return { chatType = t.chatType, name = t.name, key = t.key }
        end
    end
    local want = raw:lower()
    local chans = ns.GetJoinedChannels()
    local function find(sub)
        for _, c in ipairs(chans) do
            if c.name:lower():find(sub, 1, true) then return c end
        end
    end
    if want ~= "" then
        local c = find(want)
        if c then return c end
    end
    return find("services") or find("trade")
end

-------------------------------------------------------------------------------
-- Posting and reminders
-------------------------------------------------------------------------------
ns.lastPost = 0

local function SendChat(msg, chatType, target)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        return C_ChatInfo.SendChatMessage(msg, chatType, nil, target)
    end
    return SendChatMessage(msg, chatType, nil, target)
end

-- Must be called from a click, key binding or macro (the game requires a
-- real key press or click to post in public channels).
function ns.Post(adIndex)
    local ad = ns.db.ads[adIndex or ns.db.active]
    if not ad then return end
    local blocked = ns.PostBlocked(ad)
    if blocked then ns.Print("|c" .. C.bad .. "Not posted.|r " .. blocked); return end
    local msg, included = ns.Build(ad)
    if not msg or msg == "" or (ns.HasListToken(ad) and #included == 0) then
        ns.Print("This ad is empty. Check a few items in the list first.")
        return
    end
    local chan = ns.FindChannel()
    if not chan then
        local want = ns.db.settings.channel ~= "" and ns.db.settings.channel or "Services/Trade"
        ns.Print("You're not in a channel matching |cffffffff" .. want .. "|r. Go to a city or pick a channel in settings.")
        return
    end
    local function Send(m)
        if chan.chatType then return pcall(SendChat, m, chan.chatType) end
        return pcall(SendChat, m, "CHANNEL", chan.id)
    end
    local ok, err = Send(msg)
    -- Too long for WoW: lower the limit Shout Out packs to a few characters at a
    -- time and send the shorter ad, all in this same click. The new limit is
    -- kept, so later posts fit the first time.
    local st, tries, lowered = ns.db.settings, 0, false
    while not ok and tostring(err):find("limits exceeded") and tries < 40 do
        tries = tries + 1
        local vis, raw = ns.VisibleLength(msg), #msg
        -- The visible limit is known to sit right around 255, so a refused post
        -- well under it was too long in link code: lower that. A post right at
        -- the visible limit lowers the visible limit instead (WoW counts a few
        -- things, like pipes, a little differently). Each limit only learns
        -- from its own kind of refusal, so a text-heavy ad can't shrink the
        -- room link-heavy ads get, or the other way round.
        if vis < ns.MaxLen() - 15 or (st.maxVis or ns.MAX_LEN) <= 225 then
            st.maxRaw = math.max(200, math.min(ns.MaxRaw(), raw) - 24)
        else
            st.maxVis = math.max(225, math.min(ns.MaxLen(), vis) - 3)
        end
        lowered = true
        msg = ns.Build(ad)
        if not msg or msg == "" then break end
        ok, err = Send(msg)
    end
    if not ok then
        if tostring(err):find("limits exceeded") then
            ns.Print("|c" .. C.bad .. "WoW refused the post as too long|r (" .. ns.VisibleLength(msg) .. " characters, " .. #msg ..
                " counting link code). Uncheck something or shorten your message.")
        else
            ns.Print("|c" .. C.bad .. "Couldn't post:|r " .. tostring(err))
        end
        if lowered and ns.Refresh then ns.Refresh(true) end
        return
    end
    if lowered then
        ns.Print("WoW counts a little more strictly than Shout Out did, so the first try was too long. Shout Out now packs to |cffffffff" ..
            ns.MaxLen() .. "|r characters (|cffffffff" .. ns.MaxRaw() .. "|r with link code) and posted the shorter ad. Type /shoutout resetlimit to go back to the full length.")
        if ns.Refresh then ns.Refresh(true) end
    end
    ns.lastPost = GetTime()
    ns.notified = false
    AdvanceRotation(ad)
    if ns.OnPosted then ns.OnPosted() end
end

function ns.SecondsUntilReady()
    if ns.lastPost == 0 then return 0 end
    return math.max(0, ns.db.settings.interval - (GetTime() - ns.lastPost))
end

local function Tick()
    if not ns.db then return end
    local left = ns.SecondsUntilReady()
    if left <= 0 and ns.lastPost > 0 and not ns.notified then
        ns.notified = true
        if ns.db.settings.remind and ns.db.settings.sound and PlaySound and SOUNDKIT then
            -- same sound as closing the auction house
            PlaySound(SOUNDKIT.AUCTION_WINDOW_CLOSE or 5275, "Master")
        end
    end
    if ns.OnTick then ns.OnTick(left) end
end

function ns.FormatTime(sec)
    sec = math.ceil(sec)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-------------------------------------------------------------------------------
-- Test message: sends the real message to a private, password-protected
-- channel only you are in, then shows what came back, styled as your ad
-- channel, in your chat window. Nobody else sees it.
-------------------------------------------------------------------------------
local testChan -- { name, password }

local function TestChannelInfo()
    ns.db.testChan = ns.db.testChan or {
        name = "ShoutOutTest",
        password = tostring(math.random(100000, 999999)),
    }
    -- only ever Shout Out's own private channel (a hand-edited name can't turn
    -- "Send test" into a way to post somewhere public)
    local t = ns.db.testChan
    if type(t.name) ~= "string" or not t.name:match("^ShoutOutTest%d*$") or type(t.password) ~= "string" or t.password == "" then
        t.name, t.password = "ShoutOutTest", tostring(math.random(100000, 999999))
    end
    return t
end

-- Leave every Shout Out test channel (cleans up the numbered ones older
-- versions left behind)
function ns.CleanupTestChannels(keep)
    local raw = { GetChannelList() }
    for i = 1, select("#", GetChannelList()) do
        local v = raw[i]
        if type(v) == "string" and v:find("^ShoutOutTest") and v ~= keep and LeaveChannelByName then
            pcall(LeaveChannelByName, v)
        end
    end
end

local function TestChannelId()
    if not testChan then return end
    local id = GetChannelName(testChan.name)
    if type(id) == "number" and id > 0 then return id end
end

-- Join quietly ahead of time (when the window opens) so one click can send
function ns.PrepareTestChannel()
    testChan = TestChannelInfo()
    ns.CleanupTestChannels(testChan.name)
    if TestChannelId() then return end
    pcall(JoinTemporaryChannel or JoinChannelByName, testChan.name, testChan.password)
    -- If someone else already owns "ShoutOutTest", the join fails; use a
    -- numbered name instead (kept for next time).
    C_Timer.After(2, function()
        if testChan and not TestChannelId() and testChan.name == "ShoutOutTest" then
            testChan.name = "ShoutOutTest" .. math.random(10, 99)
            pcall(JoinTemporaryChannel or JoinChannelByName, testChan.name, testChan.password)
        end
    end)
end

function ns.LeaveTestChannel()
    if TestChannelId() and LeaveChannelByName then pcall(LeaveChannelByName, testChan.name) end
end

function ns.SendTest()
    local msg, included = ns.Build(ns.ActiveAd())
    if not msg or msg == "" then ns.Print("Nothing to send yet.") return end
    local id = TestChannelId()
    if not id then
        ns.PrepareTestChannel()
        ns.Print("Getting your private test channel ready. Click |cffffffffSend test|r again in a second.")
        return
    end
    ns.pendingTest = GetTime()
    local ok, err = pcall(SendChat, msg, "CHANNEL", id)
    if not ok then
        ns.pendingTest = nil
        if tostring(err):find("limits exceeded") then
            ns.Print("|c" .. C.bad .. "WoW refused the test as too long|r (" .. #msg ..
                " characters counting link code). Uncheck an enchant or shorten your message.")
        else
            ns.Print("Couldn't send the test: " .. tostring(err))
        end
    end
end

-- CHAT_MSG_CHANNEL echo of our own test line: show it as it would look
function ns.OnChannelMessage(text, channelBaseName)
    if not testChan then return end
    if type(channelBaseName) ~= "string" or not channelBaseName:find(testChan.name, 1, true) then return end
    if not ns.pendingTest then return end
    ns.pendingTest = nil
    local line = ns.ChatLine and ns.ChatLine(text, ns.FindChannel()) or text
    DEFAULT_CHAT_FRAME:AddMessage(line)
    ns.Print("|cff8a8a96^ test message, sent only to you (" .. #text .. " characters, " ..
        ns.VisibleLength(text) .. " visible).|r")
end

-------------------------------------------------------------------------------
-- Recipe scan: open your Enchanting window once and Shout Out learns which
-- enchants you know and grabs your [Enchanting] profession link.
-------------------------------------------------------------------------------
local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function ViewingSomeoneElse()
    local T = C_TradeSkillUI
    if T and (Call(T.IsTradeSkillLinked) or Call(T.IsTradeSkillGuild) or Call(T.IsNPCCrafting)) then return true end
    if Call(IsTradeSkillLinked) then return true end
    return false
end

local function Match(found, spellID, name)
    local e = (spellID and ns.bySpell[spellID]) or (name and ns.byRecipe[name:lower()])
    if e then
        found[e.prof] = found[e.prof] or {}
        found[e.prof][e.id] = true
        if name and name ~= "" then ns.db.names[e.id] = name end
    end
end

-- Fill an ad that's waiting for its first scan (or Preview) with the
-- recipes you know in its skill range.
local function FillStarter(ad, knownSet)
    if not ad.fill then return end
    local cap = ns.Pack(ad.prof).starterPerSection -- nil = no limit
    local perSection = {}
    -- only check sections the message can actually show
    local shows, all = {}, false
    for _, tok in ipairs(ns.ListTokens(ns.Template(ad))) do
        if tok.spec.all then all = true end
        for _, name in ipairs(tok.spec.sections or {}) do
            for _, key in ipairs(SlotsByName(ad.prof, name)) do shows[key] = true end
        end
    end
    for _, e in ipairs(ns.CATALOG) do -- catalog order is best-first within a section
        if e.prof == ad.prof and knownSet(e) and e.starter and e.skill >= ad.fill[1] and e.skill <= ad.fill[2]
            and ns.Tradeable(e) ~= false and (all or shows[e.slot]) then
            local n = perSection[e.slot] or 0
            if not cap or n < cap then
                ad.items[e.id] = ad.items[e.id] or { on = true }
                perSection[e.slot] = n + 1
            end
        end
    end
    ad.fill = nil
end

-- First time we see a profession (scan or Preview): give it starter ads,
-- and drop untouched starter ads of professions this character doesn't have.
function ns.SetupProfession(prof, knownSet)
    local has = false
    for _, ad in ipairs(ns.db.ads) do if ad.prof == prof then has = true end end
    local firstNew
    if not has then
        for _, def in ipairs(ns.Pack(prof).starterAds or {}) do
            local ad = NewAd(def.name, def.template, prof)
            ad.fill = { def.minSkill, def.maxSkill }
            table.insert(ns.db.ads, ad)
            firstNew = firstNew or #ns.db.ads
        end
    end
    for _, ad in ipairs(ns.db.ads) do
        if ad.prof == prof then FillStarter(ad, knownSet) end
    end
    for i = #ns.db.ads, 1, -1 do
        local ad = ns.db.ads[i]
        if ad.fill and ad.prof ~= prof and not ns.HasScanned(ad.prof) and #ns.db.ads > 1 then
            table.remove(ns.db.ads, i)
            if firstNew and i < firstNew then firstNew = firstNew - 1 end
        end
    end
    if firstNew then ns.db.active = firstNew end
    ns.db.active = math.min(math.max(ns.db.active, 1), #ns.db.ads)
end

function ns.ScanRecipes()
    if ViewingSomeoneElse() then return end
    local found = {}
    local T = C_TradeSkillUI
    -- Modern profession API: recipe IDs are the spell IDs
    if T and T.GetAllRecipeIDs then
        for _, rid in ipairs(Call(T.GetAllRecipeIDs) or {}) do
            local info = Call(T.GetRecipeInfo, rid)
            if info and info.learned then
                Match(found, info.recipeID or rid, info.name)
                local e = ns.bySpell[info.recipeID or rid]
                if e and e.service and e.linkType ~= "spell" and T.GetRecipeLink then
                    local l = Call(T.GetRecipeLink, info.recipeID or rid)
                    if type(l) == "string" and l:find("|H", 1, true) then ns.db.recipeLinks[e.spell] = l end
                end
            end
        end
    end
    -- Older trade skill API
    for i = 1, Call(GetNumTradeSkills) or 0 do
        local name, kind = Call(GetTradeSkillInfo, i)
        if name and kind ~= "header" then
            local link = Call(GetTradeSkillRecipeLink, i)
            Match(found, link and tonumber(link:match("enchant:(%d+)")), name)
        end
    end
    -- Vanilla-style craft API
    for i = 1, Call(GetNumCrafts) or 0 do
        local name, _, kind = Call(GetCraftInfo, i)
        if name and kind ~= "header" then
            local link = Call(GetCraftRecipeLink, i)
            Match(found, link and tonumber(link:match("enchant:(%d+)")), name)
        end
    end
    -- The open window is the profession with the most matches
    local prof, best = nil, 0
    for p, set in pairs(found) do
        local n = 0
        for _ in pairs(set) do n = n + 1 end
        if n > best then prof, best = p, n end
    end
    if not prof then return end -- not a profession Shout Out has a pack for

    local link = Call(T and T.GetTradeSkillListLink) or Call(GetTradeSkillListLink)
    if link then ns.db.profLinks[prof] = link end

    -- replace what we know for this profession only
    local before = 0
    for id in pairs(ns.db.known) do
        local e = ns.byId[id]
        if e and e.prof == prof then before = before + 1; ns.db.known[id] = nil end
    end
    for id in pairs(found[prof]) do ns.db.known[id] = true end
    local firstScan = not ns.db.scannedProfs[prof]
    ns.db.scannedProfs[prof] = true
    ns.SetupProfession(prof, function(e) return found[prof][e.id] end)

    if best ~= before or firstScan then
        ns.Print("Found |cffffffff" .. best .. "|r " .. ns.Pack(prof).name .. " recipes you know.")
    end
    if ns.Refresh then ns.Refresh(true) end
end

-- Preview: pretend you know every recipe of a profession you don't have,
-- to build and test its ads.
-------------------------------------------------------------------------------
-- Custom ad: what's in your bags that you could sell (anything not soulbound,
-- not junk, not a quest item), grouped like the AH does
-------------------------------------------------------------------------------
ns.bagById = {}
local bagList, bagDirty = {}, true
local BAG_SECTION = { [2] = "cuGear", [4] = "cuGear", [7] = "cuTrade", [0] = "cuConsumable", [9] = "cuRecipes" }
function ns.ScanBags()
    wipe(bagList); wipe(ns.bagById)
    bagDirty = false
    local C = C_Container
    local getN = (C and C.GetContainerNumSlots) or GetContainerNumSlots
    local getInfo = C and C.GetContainerItemInfo
    if not (getN and getInfo) then return end
    local last = (NUM_BAG_SLOTS or 4) + 1 -- the reagent bag too, if there is one
    for bag = 0, last do
        local ok, n = pcall(getN, bag)
        for slot = 1, (ok and n or 0) do
            local okI, info = pcall(getInfo, bag, slot)
            if okI and type(info) == "table" and info.itemID and not info.isBound and (info.quality or 1) >= 1 then
                local classID
                if C_Item and C_Item.GetItemInfoInstant then classID = select(6, C_Item.GetItemInfoInstant(info.itemID))
                elseif GetItemInfoInstant then classID = select(6, GetItemInfoInstant(info.itemID)) end
                if classID ~= 12 then -- not quest items
                    local gear = classID == 2 or classID == 4
                    -- gear keeps its exact version (suffix), everything else stacks up by item
                    local key = gear and type(info.hyperlink) == "string" and info.hyperlink:match("|Hitem:([^|]+)|h") or tostring(info.itemID)
                    local id = "bag" .. key
                    local e = ns.bagById[id]
                    if e then
                        e.count = e.count + (info.stackCount or 1)
                    else
                        e = { id = id, item = info.itemID, link = info.hyperlink, prof = "custom",
                              slot = BAG_SECTION[classID] or "cuOther", quality = info.quality, skill = 0,
                              count = info.stackCount or 1, fromBags = true, order = 100000 + #bagList }
                        ns.bagById[id] = e
                        bagList[#bagList + 1] = e
                    end
                end
            end
        end
    end
end
function ns.BagEntries()
    if bagDirty then ns.ScanBags() end
    return bagList
end
function ns.BagsChanged() bagDirty = true end

-- Preview is for building and testing ads only. While a profession (or a
-- class ad) is previewed, its ads can't go to a real channel: only "Send test
-- to me" works. That way nobody can advertise crafts they can't make.
function ns.PostBlocked(ad)
    ad = ad or ns.ActiveAd()
    local prof = ns.ProfOf(ad)
    if ns.db.preview[prof] and not ns.Pack(prof).class then
        return "Preview is on for " .. ns.Pack(prof).name .. ", so this ad can only be sent to yourself as a test. Turn it off in Settings > Preview a profession to post it."
    end
end

function ns.SetPreview(prof, on)
    ns.db.preview[prof] = on and true or nil
    if on then ns.SetupProfession(prof, function() return true end) end
    if ns.Refresh then ns.Refresh(true) end
end

-------------------------------------------------------------------------------
-- Events, slash commands, bindings
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "GET_ITEM_INFO_RECEIVED")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
                     "NEW_RECIPE_LEARNED", "CRAFT_SHOW", "CRAFT_UPDATE", "CHAT_MSG_CHANNEL", "CHAT_MSG_WHISPER", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
                     "BAG_UPDATE_DELAYED", "ZONE_CHANGED_NEW_AREA", "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
local scanPending = false

-- Auto-invite: a whisper that's just "inv" or "invite" (any case, a "!" or
-- "?" after is fine) gets a group invite. Off unless turned on in Settings.
function ns.IsInviteWord(msg)
    local m = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("[%s%.!%?]+$", "")
    return m == "inv" or m == "invite"
end
-- Another addon already inviting people who whisper "inv"? Then Shout Out stays
-- out of it, so nobody gets two invites (or an "already invited" error).
-- LayerSwap invites whispers while you're hosting swaps (LayerSwapDB.hosting).
function ns.OtherInviter()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if loaded and loaded("LayerSwap") and type(LayerSwapDB) == "table" and LayerSwapDB.hosting == true then
        return "LayerSwap"
    end
end
-- Can you invite someone right now? WoW refuses an invite into a full group,
-- or from someone who isn't the leader (or a raid assistant), without telling
-- the addon, so check first. Returns true, or false and a short reason.
-- Returns true (plus "raid" when the party has to become a raid first),
-- or false plus "Group full" / "Not leader".
function ns.CanInvite()
    local inGroup = type(IsInGroup) == "function" and IsInGroup() == true
    if not inGroup then return true end
    local raid = type(IsInRaid) == "function" and IsInRaid() == true
    local n = type(GetNumGroupMembers) == "function" and tonumber(GetNumGroupMembers()) or 0
    local lead = type(UnitIsGroupLeader) == "function" and UnitIsGroupLeader("player") == true
    local assist = raid and type(UnitIsGroupAssistant) == "function" and UnitIsGroupAssistant("player") == true
    if raid then
        if n >= 40 then return false, "Group full" end
        if not (lead or assist) then return false, "Not leader" end
        return true
    end
    if not lead then return false, "Not leader" end
    if n >= 5 then
        if ns.db and ns.db.settings.autoRaid == true then return true, "raid" end
        return false, "Group full"
    end
    return true
end

local function ConvertToRaidNow()
    local f = (C_PartyInfo and C_PartyInfo.ConvertToRaid) or ConvertToRaid
    if type(f) ~= "function" then return false end
    return (pcall(f))
end

-- Invites name, turning a full party into a raid first when that's turned on.
-- The raid change takes a moment to reach the server, so that invite waits
-- a second. Returns true when an invite went out (or is on its way).
function ns.InviteName(name)
    local can, how = ns.CanInvite()
    if not can then return false end
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if type(invite) ~= "function" then return false end
    if how == "raid" then
        if not ConvertToRaidNow() then return false end
        ns.Print("Your party was full, so it's a raid now.")
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function() pcall(invite, name) end)
            return true
        end
    end
    return (pcall(invite, name))
end

function ns.OnWhisper(msg, sender)
    if not ns.db.settings.autoInvite or type(sender) ~= "string" or not ns.IsInviteWord(msg) then return end
    local other = ns.OtherInviter()
    if other then
        if not ns.toldOther then
            ns.toldOther = true
            ns.Print("Auto-invite: " .. other .. " is already inviting people who whisper \"inv\", so Shout Out leaves those to it.")
        end
        return
    end
    local who = (Ambiguate and Ambiguate(sender, "short") or sender)
    local can, why = ns.CanInvite()
    if not can then
        ns.Print("Couldn't invite |cffffffff" .. who .. "|r (they whispered \"" .. msg .. "\"): " ..
            (why == "Group full" and (ns.db.settings.autoRaid and "your raid is full." or "your party is full (turn on \"Turn a full party into a raid\" in Settings to keep inviting).") or "you're not the group leader."))
        return
    end
    if ns.InviteName(sender) then ns.Print("Invited |cffffffff" .. who .. "|r (they whispered \"" .. msg .. "\").") end
end
ev:SetScript("OnEvent", function(_, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then ns.InitDB() end
    elseif event == "PLAYER_LOGIN" then
        if ns.CreateUI then ns.CreateUI() end
        if ns.CreateMini then ns.CreateMini() end
        if ns.CreateMinimapButton then ns.CreateMinimapButton() end
        ns.HookAuctionator()
        -- your class's ad (Mage portals & food, Warlock summons), once per character
        for _, p in ipairs(ns.PROFESSIONS) do
            if p.class and PlayerClass() == p.class and not ns.db.classSetup[p.key] then
                ns.db.classSetup[p.key] = true
                ns.SetupProfession(p.key, function(e) return ns.IsKnown(e.id) end)
                if ns.Refresh then ns.Refresh(true) end
            end
        end
        -- channel list isn't ready right at login
        C_Timer.After(6, function() if not (ns.frame and ns.frame:IsShown()) then ns.CleanupTestChannels() end end)
        C_Timer.NewTicker(1, Tick)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- item names/links finished loading: redraw once, shortly after the burst
        if not ns.itemRefreshPending then
            ns.itemRefreshPending = true
            C_Timer.After(0.3, function() ns.itemRefreshPending = false; if ns.Refresh then ns.Refresh(true) end end)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.BagsChanged()
        if ns.Pack(ns.ProfOf()).bags and ns.Refresh then ns.Refresh(true) end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if ns.RefreshPreview then ns.RefreshPreview() end -- "from ORG" follows you
    elseif event == "LEARNED_SPELL_IN_TAB" or event == "SPELLS_CHANGED" then
        if ns.Pack(ns.ProfOf()).always and ns.Refresh then ns.Refresh(true) end
    elseif event == "CHAT_MSG_WHISPER" then
        ns.OnWhisper(arg1, ...)
    elseif event == "CHAT_MSG_CHANNEL" then
        if ns.pendingTest then ns.OnChannelMessage(arg1, select(8, ...)) end
        if ns.OnRadarMessage then ns.OnRadarMessage(arg1, (...), select(8, ...)) end
    elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" then
        if ns.OnRadarMessage then ns.OnRadarMessage(arg1, (...)) end
    elseif not scanPending then
        scanPending = true
        C_Timer.After(0.5, function() scanPending = false; ns.ScanRecipes() end)
    end
end)

function ns.Toggle()
    if not ns.frame then return end
    ns.frame:SetShown(not ns.frame:IsShown())
end

-- Key bindings (Bindings.xml) and addon compartment
BINDING_HEADER_SHOUTOUT = "Shout Out"
BINDING_NAME_SHOUTOUT_POST = "Post current ad"
BINDING_NAME_SHOUTOUT_TOGGLE = "Open / close Shout Out"
function ShoutOut_Post() ns.Post() end
function ShoutOut_Toggle() ns.Toggle() end
function ShoutOut_OnCompartmentClick() ns.Toggle() end

-- /shout is taken by WoW itself (it means /yell), so the command is
-- /shoutout, with /so for short.
SLASH_SHOUTOUT1 = "/shoutout"
SLASH_SHOUTOUT2 = "/so"
SlashCmdList.SHOUTOUT = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "post" or cmd == "send" then
        local idx = tonumber(rest)
        if not idx and rest ~= "" then
            for i, ad in ipairs(ns.db.ads) do
                if ad.name:lower() == rest:lower() then idx = i end
            end
        end
        ns.Post(idx)
    elseif cmd == "next" then
        ns.db.active = (ns.db.active % #ns.db.ads) + 1
        if ns.Refresh then ns.Refresh(true) end
        ns.Print("Active ad: |cffffffff" .. ns.ActiveAd().name)
    elseif cmd == "mini" then
        ns.db.settings.showMini = not ns.db.settings.showMini
        if ns.mini then ns.mini:SetShown(ns.db.settings.showMini) end
    elseif cmd == "test" then
        ns.SendTest()
    elseif cmd == "minimap" then
        ns.db.settings.showMinimap = not ns.db.settings.showMinimap
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    elseif cmd == "how" then
        if ns.ShowHow then ns.ShowHow(true) end
    elseif cmd == "settings" or cmd == "options" then
        if ns.OpenSettings then ns.OpenSettings() end
    elseif cmd == "reset" then
        if ns.frame then ns.frame:ClearAllPoints(); ns.frame:SetPoint("CENTER") end
        if ns.mini then ns.mini:ClearAllPoints(); ns.mini:SetPoint("CENTER", 0, -200) end
        ns.db.pos = {}
        ns.Print("Window positions reset.")
    elseif cmd == "resetlimit" then
        ns.db.settings.maxVis, ns.db.settings.maxRaw = nil, nil
        ns.Print("Message limit back to |cffffffff" .. ns.MaxLen() .. "|r characters (" .. ns.MaxRaw() .. " with link code).")
        if ns.Refresh then ns.Refresh(true) end
    elseif cmd == "help" then
        ns.Print("/shoutout  open or close the window")
        ns.Print("/shoutout post [name or number]  post the active ad (or a named one)")
        ns.Print("/shoutout next  switch to the next ad")
        ns.Print("/shoutout mini  show or hide the quick-post bar")
        ns.Print("/shoutout reset  move windows back to the center")
        ns.Print("/shoutout test  send the ad to yourself to see how it looks")
        ns.Print("/shoutout settings  open settings;  /shoutout minimap  show or hide the minimap button")
        ns.Print("/shoutout how  open the How it Works page")
    else
        ns.Toggle()
    end
end
