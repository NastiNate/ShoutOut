-- Shout Out: "How it Works" page (scrollable), opened from the title bar.
-- A row of jump buttons under the title scrolls straight to each section.

local _, ns = ...
local W = ns.W
local col = W.col

-- WoW can't switch to a bold font partway through a line, so emphasis is
-- contrast instead: names in bright white against softer grey body text.
local B, R = "|cffffffff", "|r" -- bright white (button and option names), reset
local A                         -- accent (placeholders), from the theme

-- link-colored names inside the example ads, the way chat shows them
local function L(name, hex) return "|cff" .. hex .. "[" .. name .. "]|r" end
local PROF, WHITE, GREEN, BLUE, PURPLE = "ffd000", "ffffff", "1eff00", "0070dd", "a335ee"
local function T(s) return A .. s .. R end -- a placeholder like {items}
local function Icon(i) return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i .. ":13|t" end

-- Blocks:
--   { "h", "Title", "jumpKey" }  section heading (jumpKey: a jump button lands here)
--   { "h2", "Title" }            sub-heading (ad types)
--   { "p", text }                paragraph
--   { "n", "1.", text }          numbered step
--   { "b", text } / { "b2", text }  bullet / sub-bullet
--   { "ex", text }               example ad, in chat colors
--   { "cmd", "/shoutout x", "what it does" }
local function GetContent()
A = "|c" .. W.Hex(col.accent)
return {
    { "h", "Quick start", "start" },
    { "n", "1.", B .. "Open your profession window once." .. R .. " Shout Out reads which recipes you know and saves your clickable [Profession] link." },
    { "n", "2.", B .. "Check what you want to sell" .. R .. " on the left, and type a price if you want one shown." },
    { "n", "3.", B .. "Write your message, or keep the example." .. R .. " Placeholders in curly brackets fill themselves in when you post:" },
    { "b2", T("{prof}") .. " becomes your clickable profession link." },
    { "b2", T("{items}") .. " (or " .. T("{enchants}") .. ", " .. T("{portals}") .. ", " .. T("{places}") .. ") becomes everything you checked, packed to fit." },
    { "b2", "Use the " .. B .. "+ [Profession]" .. R .. " and " .. B .. "+ Items" .. R .. " buttons under the box to insert them. Placeholders are colored so you can spot them." },
    { "n", "4.", B .. "Links:" .. R .. " crafted items post as clickable links people can inspect, with your price after each one." },
    { "n", "5.", B .. "Pick your channel" .. R .. " in the dropdown next to Post. It lists Trade, Services or any other channel you're in, plus Say, Yell and Guild." },
    { "n", "6.", B .. "Check the preview," .. R .. " which shows the exact chat message. Then press " .. B .. "Post" .. R .. " (or use the quick-post bar or a key binding)." },
    { "p", "No profession on this character? " .. B .. "Settings > Preview a profession" .. R .. " lets you build and test any of them. Previewed ads can only be sent to yourself with Send test, never posted to a channel." },

    { "h", "1. The list (left)", "list" },
    { "b", "Only recipes you know are shown. Bind on Pickup items are hidden, since buyers can't receive them." },
    { "b", B .. "Check" .. R .. " an item to put it in this ad. " .. B .. "Search" .. R .. " finds anything by part of its name. " .. B .. "All / In ad" .. R .. " switches between everything and only what's checked." },
    { "b", B .. "Price boxes" .. R .. " (gold / silver / copper): leave them empty for no price." },
    { "b", B .. "Stack / each" .. R .. " appears on anything that stacks. Switching it converts your price." },
    { "b", B .. "AH estimate" .. R .. " (needs Auctionator or TSM): click it to use it as your price. " .. B .. "Use AH prices" .. R .. " fills every empty box and never changes prices you've typed." },
    { "b", B .. "Drag" .. R .. " an item or a section header to reorder. Higher up gets listed first and gets room first." },
    { "b", B .. "Clear prices" .. R .. " (per section) and " .. B .. "Clear all prices" .. R .. " do what they say. Your checkmarks stay." },
    { "b", B .. "Check All / Uncheck All" .. R .. " only affect what's currently shown." },

    { "h", "2. Your message", "message" },
    { "b", "Write the whole ad however you like." },
    { "b", T("{items}") .. " / " .. T("{enchants}") .. " / " .. T("{portals}") .. " / " .. T("{places}") .. " becomes everything you checked, packed to fit." },
    { "b", T("{items:Flasks}") .. " places just one section, so you can write around it, e.g. " .. B .. "WTS " .. R .. T("{items:Flasks}") .. B .. " | WTS " .. R .. T("{items:Transmutes}") .. "." },
    { "b", T("{prof}") .. " becomes your clickable profession link, and " .. T("{prof:Tailoring}") .. " links another profession you have." },
    { "b", "The raid icon buttons insert these codes, which only show as icons in Say, Yell and Guild:" },
    { "b2", Icon(1) .. " {rt1} Star     " .. Icon(2) .. " {rt2} Circle     " .. Icon(3) .. " {rt3} Diamond     " .. Icon(4) .. " {rt4} Triangle" },
    { "b2", Icon(5) .. " {rt5} Moon     " .. Icon(6) .. " {rt6} Square     " .. Icon(7) .. " {rt7} Cross     " .. Icon(8) .. " {rt8} Skull" },

    { "h", "3. Format options", "format" },
    { "b", B .. "Item links:" .. R .. " clickable items people can inspect." },
    { "b", B .. "Slot labels:" .. R .. " \"Cloak: [item]\" style groups. Edit each label in its section header." },
    { "b", B .. "Separator:" .. R .. " what goes between groups in your ad. A pipe gives \"1H: Crusader | Chest: +4 Stats\", and a comma gives \"1H: Crusader, Chest: +4 Stats\". In Warlock ads it goes between each place." },
    { "b", B .. "Per slot:" .. R .. " how many enchants each gear slot can show in one post (1-5). With 2 per slot: \"1H: Crusader, Fiery | Chest: +4 Stats, 100 HP\"." },
    { "b", B .. "Rotate overflow:" .. R .. " whatever didn't fit goes into one follow-up post, then it starts over. The button reads " .. B .. "Overflow post" .. R .. " and the Next post box shows what it will say." },
    { "b", B .. "ALL CAPS:" .. R .. " capitalizes your text. Links, prices and \"/w me\" stay as they are." },
    { "b", B .. "Repeat" .. R .. " (Warlock only): lets you repeat your summoning line multiple times in the same message." },

    { "h", "4. Preview & limits", "preview" },
    { "b", "The preview shows the exact chat message, in your channel's color." },
    { "b", "Every post must fit in " .. B .. "255 characters" .. R .. ", and a link counts as its [Name]." },
    { "b", B .. "Send test to me" .. R .. " posts it where only you can see it. " .. B .. "Copy" .. R .. " gives you plain text for Ctrl+C." },

    { "h", "5. Posting & reminders", "posting" },
    { "b", B .. "Channel Selection:" .. R .. " will only show you the channels you are currently in." },
    { "b", "Press " .. B .. "Post" .. R .. ", use the quick-post bar, a key binding (Options > Keybindings > AddOns), or type " .. A .. "/shoutout post" .. R .. "." },
    { "b", "Shout Out never posts on its own, because WoW only allows posting from a click or key press." },
    { "b", B .. "Reminder:" .. R .. " set the seconds between posts. When it's time, the Post button glows. You can add the auction house sound and a flashing outline on the quick-post bar." },
    { "b", B .. "Auto-invite" .. R .. " (Settings, or " .. B .. "inv" .. R .. " on the quick bar): whispers of just \"inv\" or \"invite\" get a group invite." },

    { "h", "6. Ad types", "types" },
    { "h2", "Enchanting" },
    { "b", "Each enchant has a text box that sets how it reads in the ad (\"Crusader\", \"15 Agi\")." },
    { "b", B .. "Mats" .. R .. " shows what its materials cost on the AH, as a pricing reference. It isn't part of the ad." },
    { "b", B .. "Slot labels" .. R .. " put enchants into groups by gear slot, with the label from each section header:" },
    { "ex", "1H: Crusader, Fiery | Chest: +4 Stats, 100 HP | Boots: 7 Agi, Spd" },
    { "p2", "Turn them off for one plain list:" },
    { "ex", "Crusader, Fiery, +4 Stats, 100 HP, 7 Agi, Spd" },
    { "b", B .. "Per slot" .. R .. " sets how many enchants each slot shows (1-5) before moving on to the next slot. Fewer per slot means more slots fit. With Rotate overflow on, the rest go in the next post." },

    { "h2", "Crafting (Leatherworking, Blacksmithing, Tailoring, Engineering, Cooking)" },
    { "b", "Everything you check posts as a clickable item link, followed by your price if you set one:" },
    { "ex", L("Leatherworking", PROF) .. " LFW | " .. L("Core Armor Kit", BLUE) .. " 3g | WTS " .. L("Hide of the Wild", PURPLE) .. " 220g, " .. L("Onyxia Scale Cloak", BLUE) .. " 15g | /w me" },
    { "b", "Stackable items show a " .. B .. "stack / each" .. R .. " switch: " .. L("Thorium Shells", WHITE) .. " 5g/stack or " .. L("Flask of the Titans", WHITE) .. " 38g ea. Ammo, explosives and food start on stack." },
    { "b", "Each profession's list is split into sections (Armor Kits, Cloak, Bags, Mooncloth...). Place one on its own with " .. T("{items:Cloak}") .. ", or everything with " .. T("{items}") .. "." },

    { "h2", "Alchemy" },
    { "b", B .. "Transmutes" .. R .. " are a service: you transmute the buyer's materials and charge a fee. The ad links the transmute itself, followed by your fee:" },
    { "ex", "WTS " .. L("Transmute: Arcanite", PROF) .. " 25g" },
    { "p2", "The row shows " .. B .. "Mats 11g 63s / AH 48g 96s" .. R .. ": what the materials cost, and what the finished Arcanite Bar sells for. That helps you set a fair fee." },
    { "b", B .. "Mooncloth CD" .. R .. " (Tailoring) works the same way." },
    { "b", "Elixirs and potions are sorted by what they do (Strength, Agility, Spell Damage, Healing & Mana, Protection...)." },

    { "h2", "Mage" },
    { "b", B .. "Portals:" .. R .. " check the portals you sell and set a price on each. " .. T("{portals}") .. " turns them into one short phrase:" },
    { "b2", "Same price on all: \"UC & TB 40s from ORG\"" },
    { "b2", "Different prices: \"UC 40s & TB 50s from ORG\"" },
    { "b2", "\"from ORG\" is added automatically from the capital you're standing in, and that city's own portal is left out. Outside a capital, there's no \"from\"." },
    { "b2", "The text box on each portal sets its short name (\"ORG\", \"UC\", \"TB\")." },
    { "b", B .. "Food & water:" .. R .. " " .. T("{items}") .. " lists the conjured food and water you checked, priced per stack:" },
    { "ex", "WTS PORTS to UC & TB 40s from ORG | " .. L("Conjured Crystal Water", WHITE) .. " 20s, " .. L("Conjured Cinnamon Roll", WHITE) .. " 10s | /w \"INV\"" },

    { "h2", "Warlock" },
    { "b", "Select the place(s) you are summoning to." },
    { "b", "Set a price for each place you are summoning to." },
    { "b", "Somewhere not listed? Use " .. B .. "+ Add line" .. R .. " (in Extras) to add your own, e.g. \"BRD Dungeon Entrance 2g\". Type the price into the line itself." },
    { "b", T("{places}") .. " lists the places you checked, with the " .. B .. "Separator" .. R .. " between each one:" },
    { "ex", "SELLING SUMMS | Tanaris 1g, Everlook 2g | /w \"INV\"" },
    { "p2", "With the pipe separator:" },
    { "ex", "Tanaris 1g | Everlook 2g" },
    { "b", B .. "Repeat" .. R .. " lets you repeat your summoning line multiple times in the same message. The last part (/w \"INV\") stays once at the end:" },
    { "ex", "SELLING SUMMS | EVERLOOK 1g | SELLING SUMMS | EVERLOOK 1g | /w \"INV\"" },

    { "p", "Mage and Warlock ads work on any character, so an alt (or a second account) can advertise for your mage or warlock." },

    { "h2", "Custom" },
    { "b", "Lists anything sellable in your bags (not soulbound), with stack counts and AH prices. It updates as your bags change." },
    { "b", B .. "+ Add line" .. R .. " (in Extras) is for anything else you want to advertise." },
    { "p", "In Mage, Warlock and Custom ads, " .. B .. "+ [Profession]" .. R .. " adds a link to one of your professions, e.g. \"Also offering " .. L("Tailoring", PROF) .. "\"." },

    { "h", "7. Ads, quick bar & minimap" },
    { "b", "Each tab is its own ad, with its own profession, message, checks and color. " .. B .. "+ New ad" .. R .. " starts from the example message." },
    { "b", "The color square colors the ad's tab, the Post button and the quick-post bar." },
    { "b", B .. "Quick bar:" .. R .. " " .. B .. "< >" .. R .. " switches ads, " .. B .. "inv" .. R .. " turns auto-invite on or off, and the gear opens Shout Out. Drag it to move it." },
    { "b", B .. "Minimap button:" .. R .. " left-click opens Shout Out, right-click opens Settings, middle-click hides it. Drag it to move it." },

    { "h", "8. Commands", "commands" },
    { "cmd", "/shoutout", "Open or close Shout Out" },
    { "cmd", "/so", "Short for /shoutout: works with everything below, e.g. /so post" },
    { "cmd", "/shoutout post [ad]", "Post the current ad (or a named one)" },
    { "cmd", "/shoutout next", "Switch to the next ad" },
    { "cmd", "/shoutout test", "Send a test to yourself" },
    { "cmd", "/shoutout settings", "Open Settings" },
    { "cmd", "/shoutout how", "Open this page" },
    { "cmd", "/shoutout mini", "Show or hide the quick-post bar" },
    { "cmd", "/shoutout minimap", "Show or hide the minimap button" },
    { "cmd", "/shoutout reset", "Move windows back to the center" },
    { "cmd", "/shoutout resetlimit", "Go back to the full message length" },
}
end

-- jump buttons, in page order
local JUMPS = {
    { "start", "Start" }, { "list", "List" }, { "message", "Message" }, { "format", "Format" },
    { "preview", "Preview" }, { "posting", "Posting" }, { "types", "Ad types" }, { "commands", "Commands" },
}

local BODY = { 0.66, 0.67, 0.73, 1 } -- softer grey, so the white names stand out
local CHAT = { 1, 0.75, 0.75, 1 } -- the pink of a Trade / Services line

local function Height(fs) return math.max(fs:GetStringHeight() or 0, 12) end

-- the chat font swallows the space in "| /w" (see ns.DisplayText)
local function ChatSafe(s) return (s:gsub("| /", "|  /")) end

-- Builds the page inside the main window. Returns the overlay frame.
function ns.CreateHowItWorks(parentFrame)
    local ov = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    W.Backdrop(ov, col.bg, { 0, 0, 0, 0 }, "lg")
    ov:SetPoint("TOPLEFT", 1, -40)
    ov:SetPoint("BOTTOMRIGHT", -1, 1)
    ov:SetFrameLevel(parentFrame:GetFrameLevel() + 20)
    ov:EnableMouse(true)
    ov:Hide()

    local inner = W.Panel(ov)
    inner:SetPoint("TOPLEFT", 40, -12)
    inner:SetPoint("BOTTOMRIGHT", -40, 12)

    local title = W.Text(inner, 14, col.text)
    title:SetText("How it Works")
    title:SetPoint("TOPLEFT", 16, -16)
    local done = W.Button(inner, "Done", 80, 22, "accent")
    done:SetPoint("TOPRIGHT", -14, -12)
    done:SetScript("OnClick", function() ns.ShowHow(false) end)

    -- jump buttons: one row, equal widths, spanning the text column
    local jumpRow = CreateFrame("Frame", nil, inner)
    jumpRow:SetPoint("TOPLEFT", 16, -44)
    jumpRow:SetPoint("TOPRIGHT", -22, -44)
    jumpRow:SetHeight(22)
    local jumpBtns, anchors = {}, {}

    local sc = W.Scroll(inner)
    sc:SetPoint("TOPLEFT", 16, -76)
    sc:SetPoint("BOTTOMRIGHT", -22, 14)
    local child = sc.child

    for i, j in ipairs(JUMPS) do
        local b = W.Button(jumpRow, j[2], 80, 22)
        b.text:SetFont(W.FONT, 10, "")
        b:SetScript("OnClick", function()
            if anchors[j[1]] then sc:ScrollTo(anchors[j[1]]) end
        end)
        jumpBtns[i] = b
    end
    local function LayoutJumps(w)
        if not w or w < 50 then return end
        local GAP = 4
        local bw = math.floor((w - GAP * (#jumpBtns - 1)) / #jumpBtns)
        for i, b in ipairs(jumpBtns) do
            b:SetWidth(bw)
            b:ClearAllPoints()
            b:SetPoint("LEFT", jumpRow, "LEFT", (i - 1) * (bw + GAP), 0)
        end
    end
    jumpRow:SetScript("OnSizeChanged", function(_, w) LayoutJumps(w) end)

    -- lay the content out once we know the width
    local built = false
    local function Build(width)
        if built or not width or width < 50 then return end
        built = true
        local y = 0
        local IN1, IN2, NUM = 14, 30, 22 -- bullet, sub-bullet and numbered-step indents
        local function Para(x, text, color, size)
            local p = W.Text(child, size or 12, color or BODY)
            p:SetWordWrap(true)
            if p.SetNonSpaceWrap then p:SetNonSpaceWrap(true) end
            p:SetSpacing(2)
            p:SetWidth(width - x - 6)
            p:SetText(text)
            p:SetPoint("TOPLEFT", x, -y)
            return p
        end
        local function Dot(x, size, alpha)
            local d = child:CreateTexture(nil, "ARTWORK")
            d:SetColorTexture(col.accent[1], col.accent[2], col.accent[3], alpha)
            d:SetSize(size, size)
            d:SetPoint("TOPLEFT", x, -y - 5)
        end
        for i, blk in ipairs(GetContent()) do
            local kind = blk[1]
            if kind == "h" then
                if i > 1 then y = y + 16 end
                if blk[3] then anchors[blk[3]] = math.max(0, y - 4) end
                local h = W.Text(child, 13, col.accent)
                h:SetText(blk[2]:upper())
                h:SetPoint("TOPLEFT", 0, -y)
                y = y + Height(h) + 4
                local line = child:CreateTexture(nil, "ARTWORK")
                line:SetColorTexture(col.accent[1], col.accent[2], col.accent[3], 0.25)
                line:SetHeight(1)
                line:SetPoint("TOPLEFT", 0, -y)
                line:SetPoint("TOPRIGHT", 0, -y)
                y = y + 8
            elseif kind == "h2" then
                y = y + 6
                local h = W.Text(child, 13, { 1, 1, 1, 1 })
                h:SetText(blk[2])
                h:SetPoint("TOPLEFT", 0, -y)
                y = y + Height(h) + 5
            elseif kind == "p" then
                y = y + Height(Para(0, blk[2])) + 7
            elseif kind == "p2" then -- a note under a bullet, lined up with its text
                y = y + Height(Para(IN1, blk[2])) + 5
            elseif kind == "n" then
                local n = W.Text(child, 12, col.accent)
                n:SetText(blk[2])
                n:SetPoint("TOPLEFT", 2, -y)
                y = y + Height(Para(NUM, blk[3])) + 6
            elseif kind == "b" then
                Dot(3, 4, 0.9)
                y = y + Height(Para(IN1, blk[2])) + 6
            elseif kind == "b2" then
                Dot(IN1 + 5, 3, 0.6)
                y = y + Height(Para(IN2, blk[2])) + 5
            elseif kind == "ex" then
                -- an example ad: chat colors on a dark strip with an accent edge
                local p = Para(IN1 + 10, ChatSafe(blk[2]), CHAT, 12)
                local h = Height(p)
                local bg = child:CreateTexture(nil, "BACKGROUND")
                bg:SetColorTexture(col.chat and col.chat[1] or 0.06, col.chat and col.chat[2] or 0.07,
                    col.chat and col.chat[3] or 0.09, 1)
                bg:SetPoint("TOPLEFT", IN1, -y + 4)
                bg:SetPoint("TOPRIGHT", -2, -y + 4)
                bg:SetHeight(h + 8)
                local edge = child:CreateTexture(nil, "ARTWORK")
                edge:SetColorTexture(col.accent[1], col.accent[2], col.accent[3], 0.7)
                edge:SetPoint("TOPLEFT", bg, "TOPLEFT")
                edge:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT")
                edge:SetWidth(2)
                y = y + h + 12
            elseif kind == "cmd" then
                local c = W.Text(child, 12, col.accent)
                c:SetText(blk[2])
                c:SetWidth(150)
                c:SetPoint("TOPLEFT", 4, -y)
                local d = W.Text(child, 12, BODY)
                d:SetText(blk[3])
                d:SetPoint("TOPLEFT", 164, -y)
                y = y + 20
            end
        end
        child:SetHeight(y + 12)
        sc:ScrollTo(0)
    end
    sc:HookScript("OnSizeChanged", function(_, w) Build(w) end)
    ov:SetScript("OnShow", function()
        LayoutJumps(jumpRow:GetWidth())
        Build(sc:GetWidth())
        sc:ScrollTo(0)
    end)
    ov.scroll = sc
    ov.jumps, ov.anchors = jumpBtns, anchors
    return ov
end
