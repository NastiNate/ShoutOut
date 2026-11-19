-- Shout Out: Custom ad
-- Not a profession: the list on the left is what's in your bags that you
-- could sell (anything not soulbound), found by scanning your bags. Items
-- come and go as your bags change; prices, AH estimates and stack/each work
-- like any crafted item.

local _, ns = ...

local SECTIONS = {
    { key = "cuGear",       label = "Gear",         short = "" },
    { key = "cuTrade",      label = "Trade Goods",  short = "", stack = true },
    { key = "cuConsumable", label = "Consumables",  short = "", stack = true },
    { key = "cuRecipes",    label = "Recipes",      short = "" },
    { key = "cuOther",      label = "Other",        short = "" },
    { key = "cuExtras",     label = "Extras",       short = "" },
}

ns.RegisterProfession({
    key = "custom", name = "Custom", fallback = "", icon = "Interface\\Icons\\INV_Misc_Bag_10",
    kind = "item", listToken = "{items}", extras = "cuExtras",
    always = true, bags = true, noPreview = true,
    sections = SECTIONS, entries = {},
    defaultTemplate = "WTS {items} | /w me",
})
