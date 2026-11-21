-- Shout Out: main window

local _, ns = ...
local W = ns.W
local col = W.col

local WIDTH, HEIGHT = 916, 800
local LEFT_W = 526
local ROW_H, HEAD_H = 24, 26

local f, list, rows, heads, tabs
local ui = {}
ns.ui = ui -- handy for debugging: /dump ShoutOut.ui

-------------------------------------------------------------------------------
-- Enchant list (left)
-------------------------------------------------------------------------------

-- Drag grip: three thin bars. Rows sit at fractional screen positions (UI
-- scale, scrolling), and the game normally snaps each bar to the nearest
-- pixel row, so some grips came out as "≡", others "=" or "-". Snapping is
-- turned off for these bars: every grip is drawn the same way, wherever it is.
local function Grip(parent, w, alpha)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w, 9)
    holder:SetPoint("LEFT", 4, 0)
    for i = 0, 2 do
        local g = holder:CreateTexture(nil, "ARTWORK")
        g:SetColorTexture(col.dim[1], col.dim[2], col.dim[3], alpha)
        if g.SetSnapToPixelGrid then g:SetSnapToPixelGrid(false) end
        if g.SetTexelSnappingBias then g:SetTexelSnappingBias(0) end
        g:SetSize(w, 1.5)
        g:SetPoint("TOPLEFT", 0, -i * 3.5)
    end
    if holder.EnableMouse then holder:EnableMouse(false) end
    return holder
end

local function AcquireHead(i)
    local h = heads[i]
    if h then return h end
    h = CreateFrame("Frame", nil, list.child)
    h:SetHeight(HEAD_H)
    h.line = h:CreateTexture(nil, "BACKGROUND")
    h.line:SetColorTexture(col.accent[1], col.accent[2], col.accent[3], 0.25)
    h.line:SetHeight(1)
    h.line:SetPoint("BOTTOMLEFT", 0, 2)
    h.line:SetPoint("BOTTOMRIGHT", 0, 2)
    -- highlight shown when another section is dragged over this one
    h.hl = h:CreateTexture(nil, "BACKGROUND")
    h.hl:SetAllPoints()
    h.hl:SetColorTexture(col.accent[1], col.accent[2], col.accent[3], 0.18)
    h.hl:Hide()
    -- grip: three short bars
    Grip(h, 8, 0.8)
    h.title = W.Text(h, 11, col.accent, "")
    h.title:SetPoint("LEFT", 18, 0)

    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function(self) ns.StartSectionDrag(self) end)
    h:SetScript("OnDragStop", function() ns.StopSectionDrag() end)
    h:SetScript("OnEnter", function(self)
        if ns.sectionDrag then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Drag to reorder", 1, 1, 1)
        GameTooltip:AddLine("Sections are listed in the message in this order, and the ones on top get room first.", 0.8, 0.8, 0.85, true)
        GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- crafted-item sections: clear this section's prices (click twice)
    h.clear = W.Button(h, "Clear prices", 72, 18, "ghost")
    h.clear.text:SetFont(W.FONT, 9, "")
    h.clear.text:SetTextColor(unpack(col.dim))
    W.ConfirmClick(h.clear, "Clear prices", function()
        local entries = {}
        for _, e in ipairs(ns.AllEntries(ns.ProfOf())) do if e.slot == h.slotKey then entries[#entries + 1] = e end end
        local n = ns.ClearPrices(entries)
        ns.Print(n > 0 and ("Cleared |cffffffff" .. n .. "|r prices in this section.") or "No prices to clear in this section.")
        ns.Refresh(true)
    end)
    W.Tooltip(h.clear, "Clear prices", "Empties the price boxes of every item in this section.")
    h.count = W.Text(h, 10, col.dim)
    h.count:SetPoint("LEFT", h.title, "RIGHT", 6, 0)
    h.shortLbl = W.Text(h, 10, col.dim)
    h.shortLbl:SetText("label")
    h.short = W.Edit(h, 80, 18, function(t)
        ns.db.slotShort[h.slotKey] = t
        ns.RefreshPreview()
    end, 12)
    h.short:SetPoint("RIGHT", -4, 0)
    h.shortLbl:SetPoint("RIGHT", h.short, "LEFT", -5, 0)
    h.clear:SetPoint("RIGHT", h.shortLbl, "LEFT", -8, 0)
    W.Tooltip(h.short, "Slot label", "The text shown before this group in the ad, e.g. \"Wep:\". Leave empty for no label.")
    h.add = W.Button(h, "+ Add line", 74, 18)
    h.add:SetPoint("RIGHT", -4, 0)
    h.add:SetScript("OnClick", function()
        ns.AddCustom("New line")
        ns.Refresh(true)
    end)
    W.Tooltip(h.add, "Add a custom line", "Anything you want to advertise that isn't in the list: a new recipe, \"Disenchanting\", \"Can do it on your mats\".")
    heads[i] = h
    return h
end

local function AcquireRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, list.child)
    r:SetHeight(ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, 0)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 1, 1, 0.035) end)
    r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 1, 1, 0) end)

    r.check = W.Check(r, nil, function(on)
        ns.SetItemState(ns.ActiveAd(), r.id, on)
        ns.Refresh(true)
    end)
    r.check:SetPoint("LEFT", 16, 0)
    -- grip: drag the row up or down within its section
    Grip(r, 7, 0.6)
    r.hl = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(col.accent[1], col.accent[2], col.accent[3], 0.18)
    r.hl:Hide()
    r:RegisterForDrag("LeftButton")
    r:SetScript("OnDragStart", function(self) ns.StartRowDrag(self) end)
    r:SetScript("OnDragStop", function() ns.StopRowDrag() end)

    r.name = W.Text(r, 11, col.text)
    r.name:SetPoint("LEFT", r.check, "RIGHT", 10, 0)
    r.name:SetWidth(266)

    -- Typing here only updates the preview and this row's count; rebuilding
    -- the list would hide the box and drop the cursor after every key.
    r.edit = W.Edit(r, 150, 18, function(t)
        ns.SetItemText(r.id, t)
        ns.RefreshPreview()
    end, 60)
    r.edit:SetPoint("RIGHT", -28, 0)

    -- Crafted items: price in three boxes, gold / silver / copper (numbers only)
    r.money = CreateFrame("Frame", nil, r)
    r.money:SetSize(122, 18)
    r.money:SetPoint("RIGHT", -28, 0)
    local COINS = {
        { key = "g", w = 50, max = 4, icon = "Interface\\MoneyFrame\\UI-GoldIcon", name = "Gold" },
        { key = "s", w = 34, max = 2, icon = "Interface\\MoneyFrame\\UI-SilverIcon", name = "Silver" },
        { key = "c", w = 34, max = 2, icon = "Interface\\MoneyFrame\\UI-CopperIcon", name = "Copper" },
    }
    r.coin = {}
    local function ReadCoins()
        local g = tonumber(r.coin.g:GetText()) or 0
        local sv = math.min(99, tonumber(r.coin.s:GetText()) or 0)
        local c = math.min(99, tonumber(r.coin.c:GetText()) or 0)
        ns.SetPriceC(r.id, g * 10000 + sv * 100 + c)
        ns.RefreshPreview()
        if ns.UpdateSectionPrices then ns.UpdateSectionPrices(r.slot) end
    end
    local prevBox
    for i, cdef in ipairs(COINS) do
        local b = W.Edit(r.money, cdef.w, 18, nil, cdef.max)
        b:HookScript("OnTextChanged", function() if r.settingPrice ~= true and r.id then ReadCoins() end end)
        b:SetNumeric(true)
        b:SetFont(W.FONT, 10, "")
        b:SetJustifyH("RIGHT")
        b:SetTextInsets(3, 13, 0, 0)
        if prevBox then b:SetPoint("LEFT", prevBox, "RIGHT", 2, 0) else b:SetPoint("LEFT", 0, 0) end
        local ic = b:CreateTexture(nil, "OVERLAY")
        ic:SetTexture(cdef.icon)
        ic:SetSize(10, 10)
        ic:SetPoint("RIGHT", -3, 0)
        W.Tooltip(b, cdef.name, function()
            local e = r.id and ns.GetEntry(r.id)
            local what = "this item"
            if e and e.zone and ns.ProfOf() == "mage" then what = "this portal"
            elseif e and ns.ProfOf() == "warlock" then what = "a summon here"
            elseif e and e.service then what = "this service (your fee)" end
            local unit = e and ns.PriceUnit(e) == "stack" and " per stack" or ""
            return "Your price for " .. what .. unit .. ". Leave the boxes empty for no price. Tab moves to the next box."
        end)
        r.coin[cdef.key] = b
        prevBox = b
    end
    r.coin.g:SetScript("OnTabPressed", function() r.coin.s:SetFocus() end)
    r.coin.s:SetScript("OnTabPressed", function() if r.coin.c:IsShown() then r.coin.c:SetFocus() else r.coin.g:SetFocus() end end)
    r.coin.c:SetScript("OnTabPressed", function() r.coin.g:SetFocus() end)
    -- first click into a box selects what's in it, so typing replaces it
    for _, b in pairs(r.coin) do
        b:HookScript("OnEditFocusGained", function(self)
            self:HighlightText()
            -- the click that gave focus can move the cursor afterwards; select again next frame
            C_Timer.After(0, function() if self:HasFocus() then self:HighlightText() end end)
        end)
        b:HookScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    end
    -- tidy the boxes when you leave them (e.g. 0 -> empty)
    for _, b in pairs(r.coin) do
        b:HookScript("OnEditFocusLost", function()
            ReadCoins()
            if not r:Focused() then r:ShowPrice() end
        end)
    end
    function r:ShowPrice()
        local c = ns.GetPriceC(self.id)
        local g, sv, cp = ns.SplitMoney(c or 0)
        local function put(box, v) if not box:HasFocus() then box:SetText((c and v > 0) and tostring(v) or "") end end
        self.settingPrice = true
        put(self.coin.g, g); put(self.coin.s, sv); put(self.coin.c, cp)
        self.settingPrice = false
    end
    function r:Focused()
        return self.edit:HasFocus() or self.coin.g:HasFocus() or self.coin.s:HasFocus() or self.coin.c:HasFocus()
    end
    -- AH estimate (crafted items): click to copy it into the price box
    r.ah = W.Button(r, "", 78, 18)
    r.ah.text:SetFont(W.FONT, 10, "")
    r.ah:SetPoint("RIGHT", r.money, "LEFT", -4, 0)
    -- stack / each switch for ammo and explosives
    r.unit = W.Button(r, "", 40, 18)
    r.unit.text:SetFont(W.FONT, 9, "")
    r.unit:SetPoint("RIGHT", r.money, "LEFT", -4, 0)
    r.unit:SetScript("OnClick", function()
        local e = ns.GetEntry(r.id)
        local toStack = ns.PriceUnit(e) ~= "stack"
        ns.SetPriceUnit(r.id, toStack and "stack" or "each")
        -- convert your price so it means the same thing: 10s each <-> 20g per stack of 200
        local n, c = ns.StackSize(e), ns.GetPriceC(r.id)
        if n and c then
            ns.SetPriceC(r.id, toStack and c * n or math.floor(c / n + 0.5))
        end
        ns.Refresh(true)
    end)
    r.unit:HookScript("OnEnter", function(self)
        local e = ns.GetEntry(r.id)
        local n = ns.StackSize(e)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.PriceUnit(e) == "stack" and "Price per stack" or "Price each", 1, 1, 1)
        GameTooltip:AddLine("Click to switch between a stack price and a price each; your price converts to match. Your ad shows it as \"5g/stack\" or \"50s ea\"." .. (n and ("\nA stack is " .. n .. ".") or ""), 0.8, 0.8, 0.85, true)
        GameTooltip:Show()
    end)
    r.unit:HookScript("OnLeave", function() GameTooltip:Hide() end)
    r.ah:SetScript("OnClick", function()
        local e = ns.GetEntry(r.id)
        if e and e.service then return end -- reference only: your fee isn't the item's price
        local p = ns.AHPrice(e)
        if not p then return end
        for _, b in pairs(r.coin) do b:ClearFocus() end
        if ns.PriceUnit(e) == "stack" and ns.StackSize(e) then p = p * ns.StackSize(e) end
        ns.SetPriceC(r.id, p) -- the exact AH price, gold/silver/copper
        r:ShowPrice()
        ns.RefreshPreview()
    end)
    r.ah:HookScript("OnEnter", function(self)
        local e = ns.GetEntry(r.id)
        local p, src, age, seenAt = ns.AHPrice(e)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if p then
            local stackN = ns.PriceUnit(e) == "stack" and ns.StackSize(e)
            GameTooltip:SetText("AH estimate: " .. ns.FormatMoney(stackN and p * stackN or p) .. (stackN and (" per stack of " .. stackN) or ""), 1, 1, 1)
            if stackN then GameTooltip:AddLine(ns.FormatMoney(p) .. " each", 0.8, 0.8, 0.85) end
            local when
            if seenAt then
                when = "Scanned " .. ns.FormatAgo(seenAt) .. " (" .. date("%b %d, %I:%M %p", seenAt):gsub(" 0", " ") .. ")"
            elseif age and age > 0 then
                when = "Scanned " .. age .. " day" .. (age == 1 and "" or "s") .. " ago (exact time unknown)"
            elseif age == 0 then
                when = "Scanned earlier today (exact time unknown; your next scan will record it)"
            end
            GameTooltip:AddLine("From " .. src, 0.8, 0.8, 0.85)
            if when then GameTooltip:AddLine(when, 0.8, 0.8, 0.85, true) end
            if e.service then
                GameTooltip:AddLine("What the transmuted item sells for. Compare it with the Mats cost to decide your fee.", 0.55, 0.55, 0.62, true)
            else
                GameTooltip:AddLine("Exact: " .. ns.FormatCoins(stackN and p * stackN or p) .. ". Click to put it in your price boxes.", 0.55, 0.55, 0.62, true)
            end
        else
            GameTooltip:SetText("No AH price yet", 1, 1, 1)
            local src = ns.PriceSourceName()
            GameTooltip:AddLine(src and ("No price for this item in " .. src .. " yet. Scan the auction house (or update TSM's data) to get one.") or "Install Auctionator or TradeSkillMaster to see estimates here.", 0.8, 0.8, 0.85, true)
        end
        GameTooltip:Show()
    end)
    r.ah:HookScript("OnLeave", function() GameTooltip:Hide() end)


    -- Enchanting: what the materials cost on the AH (reference only)
    r.mats = CreateFrame("Frame", nil, r)
    r.mats:SetSize(64, 18)
    r.mats:SetPoint("RIGHT", r.edit, "LEFT", -4, 0)
    r.mats.text = W.Text(r.mats, 10, col.text)
    r.mats.text:SetPoint("RIGHT", -2, 0)
    r.mats.text:SetJustifyH("RIGHT")
    function r.mats:SetLabel(t) self.text:SetText(t) end
    -- Transmutes: what the result sells for, as plain text like Mats (not a button)
    r.prod = CreateFrame("Frame", nil, r)
    r.prod:SetSize(62, 18)
    r.prod:SetPoint("RIGHT", r.money, "LEFT", -4, 0)
    r.prod.text = W.Text(r.prod, 10, col.text)
    r.prod.text:SetPoint("RIGHT", -2, 0)
    r.prod.text:SetJustifyH("RIGHT")

    r.len = W.Text(r, 9, col.dim)
    r.len:SetPoint("LEFT", r.edit, "RIGHT", 4, 0)
    r.len:SetWidth(22)
    r.len:SetJustifyH("CENTER")

    r.del = W.Button(r, "x", 18, 18, "ghost")
    r.del:SetPoint("LEFT", r.edit, "RIGHT", 4, 0)
    r.del.text:SetTextColor(unpack(col.bad))
    r.del:SetScript("OnClick", function()
        ns.RemoveCustom(r.id)
        ns.Refresh(true)
    end)

    -- Show the in-ad text when hovering the name
    local hit = CreateFrame("Frame", nil, r)
    hit:SetPoint("TOPLEFT", r.name, "TOPLEFT", -4, 6)
    hit:SetPoint("BOTTOMRIGHT", r.edit, "BOTTOMLEFT", -4, -3)
    hit:SetScript("OnEnter", function(self)
        r:GetScript("OnEnter")(r)
        local e = ns.GetEntry(r.id)
        if not e or e.custom then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local pack = ns.Pack(e.prof)
        if e.link and GameTooltip.SetHyperlink then
            GameTooltip:SetHyperlink(e.link)
        elseif e.item and GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(e.item)
        else
            GameTooltip:SetText(e.recipe or ns.DisplayName(e), 1, 1, 1)
        end
        if not pack.always and (tonumber(e.skill) or 0) > 0 then
            GameTooltip:AddLine("Requires " .. pack.name .. " " .. e.skill, 0.8, 0.8, 0.85)
        end
        local hasText = r.edit:IsShown()
        local hasPrice = r.money:IsShown()
        local coins = r.coin.c:IsShown() and "gold / silver / copper" or "gold / silver"
        if hasText and hasPrice then
            GameTooltip:AddLine("The text box is how it reads in the ad; the " .. coins .. " boxes are your price.", 0.55, 0.55, 0.62, true)
        elseif hasPrice then
            GameTooltip:AddLine("Type your price in the " .. coins .. " boxes to show it after the item.", 0.55, 0.55, 0.62, true)
        elseif hasText then
            GameTooltip:AddLine("Edit the box on the right to change how it reads in the ad.", 0.55, 0.55, 0.62, true)
        end
        GameTooltip:AddLine("Drag up or down to change its place: higher = listed first and gets room first.", 0.55, 0.55, 0.62, true)
        GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() r:GetScript("OnLeave")(r); GameTooltip:Hide() end)
    hit:EnableMouse(true)
    -- the name's hover area must sit under the AH button, price box and x, or
    -- it swallows their clicks
    for _, w in ipairs({ r.ah, r.unit, r.mats, r.edit, r.money, r.del, r.check }) do w:SetFrameLevel(hit:GetFrameLevel() + 2) end
    for _, b in pairs(r.coin) do b:SetFrameLevel(r.money:GetFrameLevel() + 1) end
    hit:RegisterForDrag("LeftButton")
    hit:SetScript("OnDragStart", function() ns.StartRowDrag(r) end)
    hit:SetScript("OnDragStop", function() ns.StopRowDrag() end)

    rows[i] = r
    return r
end

-- The list only builds frames for what's on screen and reuses them while
-- you scroll (a profession can have 500+ recipes).
local layout, layoutHeight = {}, 0
-- bumped on every rebuild: rows filled in this generation are still correct
-- and only need moving while you scroll
local gen = 0
-- AH estimates looked up once per rebuild, not on every scroll step
local ahCache = {}
local function CachedAH(e)
    local v = ahCache[e.id]
    if v == nil then v = ns.AHPrice(e) or false; ahCache[e.id] = v end
    return v or nil
end
local matsCache = {}
local function CachedMats(e)
    local v = matsCache[e.id]
    if v == nil then
        local total, parts, missing = ns.MatsCost(e)
        v = total and { total, missing } or false
        matsCache[e.id] = v
    end
    if v then return v[1], nil, v[2] end
end
function ns.ClearListPriceCache() wipe(ahCache); wipe(matsCache) end
local BUFFER = 60 -- px drawn above/below the view so scrolling never shows gaps

local function FillHead(h, it, width)
    local slot = it.slot
    h.slotKey = slot.key
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 0, -it.y)
    h:SetWidth(width)
    h.title:SetText(slot.label:upper())
    h:SetAlpha((ns.sectionDrag and ns.sectionDrag.key == slot.key) and 0.4 or 1)
    h.count:SetText(it.total > 0 and (it.on .. "/" .. it.total) or "")
    h.add:SetShown(slot.extras and true or false)
    h.clear:SetShown(it.hasPrice and true or false)
    -- the label box only matters when this ad uses slot labels
    local ad = ns.ActiveAd()
    local labels = not slot.extras and ad and ad.slotLabels and not ns.Pack(ns.ProfOf(ad)).always and true or false
    h.short:SetShown(labels)
    h.shortLbl:SetShown(labels)
    h.clear:ClearAllPoints()
    if labels then h.clear:SetPoint("RIGHT", h.shortLbl, "LEFT", -8, 0) else h.clear:SetPoint("RIGHT", -4, 0) end
    if not h.short:HasFocus() then h.short:SetText(ns.SlotShort(slot.key)) end
    h:Show()
end

local function FillRow(r, it, width, ad)
    local e = it.e
    r.id, r.slot, r.layoutIndex, r.gen = e.id, e.slot, it.index, gen
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -it.y)
    r:SetWidth(width)
    r:SetAlpha((ns.rowDrag and ns.rowDrag.id == e.id) and 0.4 or 1)
    r.check:SetChecked(ns.ItemState(ad, e.id))
    r.name:SetText(ns.DisplayName(e) .. (e.nameNote and ("  |cff7a7a85" .. e.nameNote .. "|r") or ""))
    r.name:SetTextColor(unpack(e.custom and col.dim or ns.QualityColor(e.quality) or col.text))
    -- portals and summon places: a name box plus price boxes
    local pricedText = not e.item and not e.custom and ns.Pack(e.prof).pricedText
    r.edit:SetShown(not e.item)
    r.money:SetShown((e.item or pricedText) and true or false)
    r.edit:ClearAllPoints()
    -- custom lines keep room for their x; everything else runs to the edge
    if pricedText then r.edit:SetPoint("RIGHT", r.money, "LEFT", -4, 0)
    else r.edit:SetPoint("RIGHT", e.custom and -28 or -4, 0) end -- -4: lines up with the header's label box
    -- portals, summons and conjured food are priced in gold and silver only
    local noCopper = pricedText or e.noCopper
    r.coin.c:SetShown(not noCopper)
    r.money:SetWidth(noCopper and 86 or 122) -- gold 50 (4 digits), silver / copper 34 (2 digits + cursor)
    if not e.service then r.prod:Hide() end
    if not e.item or e.service then r.unit:Hide() end
    if not e.item and not r.edit:HasFocus() then
        local t = ns.ItemText(e.id)
        if r.edit:GetText() ~= t then r.edit:SetText(t) end
        r.edit:SetCursorPosition(0) -- long names show their start ("Dustwallow Marsh"), not their end
    end
    if e.item then
        r:ShowPrice()
        local p = CachedAH(e)
        if e.service then
            -- a service (transmute): what the materials cost, then what the
            -- result sells for, so you can judge your fee
            local total, _, missing = CachedMats(e)
            -- one line of plain text: "Mats 37g / AH 60g"
            r.ah:Hide()
            r.prod:Hide()
            local parts = {}
            if total then parts[#parts + 1] = "Mats " .. (total > 0 and ns.FormatMoney(total) or "?") .. (missing > 0 and total > 0 and "+" or "") end
            if ns.db.settings.ahPrices then parts[#parts + 1] = p and ("AH " .. ns.FormatMoney(p)) or "AH -" end
            r.mats:ClearAllPoints()
            r.mats:SetPoint("RIGHT", r.money, "LEFT", -4, 0)
            r.mats:SetWidth(152)
            r.mats:SetShown(#parts > 0)
            r.mats:SetLabel(table.concat(parts, " / "))
            r.mats.text:SetTextColor(unpack((total and missing == 0) and col.text or col.dim))
        elseif not ns.db.settings.ahPrices then
            r.ah:Hide()
            r.unit:SetShown(ns.CanStack(e))
        else
            -- per stack: show what a stack goes for
            local stackN = ns.PriceUnit(e) == "stack" and ns.StackSize(e)
            local shown = p and stackN and p * stackN or p
            r.ah:SetLabel(shown and ("AH " .. ns.FormatMoney(shown)) or "AH -")
            r.ah.text:SetTextColor(unpack(p and col.accent or col.dim))
            r.ah:SetAlpha(p and 1 or 0.5)
            r.ah:Show()
            r.unit:SetShown(ns.CanStack(e))
        end
        -- conjured food & water: no AH, always per stack, so no switch either
        if e.noAH then r.ah:Hide() end
        local stacky = ns.CanStack(e) and not e.fixedUnit
        if e.fixedUnit then r.unit:Hide() end
        if stacky then
            r.unit:SetLabel(ns.PriceUnit(e) == "stack" and "stack" or "each")
            r.ah:ClearAllPoints()
            r.ah:SetPoint("RIGHT", r.unit, "LEFT", -4, 0)
        else
            r.unit:Hide()
            r.ah:ClearAllPoints()
            r.ah:SetPoint("RIGHT", r.money, "LEFT", -4, 0)
        end
        r.name:SetWidth(e.service and 142 or (e.noAH and 288 or (stacky and 172 or 216)))
    else
        r.ah:Hide()
        local total, _, missing = CachedMats(e)
        if total and not e.custom then
            r.edit:SetWidth(136)
            r.mats:SetWidth(80)
            r.mats:ClearAllPoints()
            r.mats:SetPoint("RIGHT", r.edit, "LEFT", -4, 0)
            r.mats:SetLabel("Mats " .. (total > 0 and ns.FormatMoney(total) or "?") .. (missing > 0 and total > 0 and "+" or ""))
            r.mats.text:SetTextColor(unpack(missing > 0 and col.dim or col.text))
            r.mats:Show()
            r.name:SetWidth(216)
        elseif pricedText then
            r:ShowPrice()
            r.edit:SetWidth(110)
            r.mats:Hide()
            r.name:SetWidth(200)
        else
            r.edit:SetWidth(e.custom and 150 or 174)
            r.mats:Hide()
            r.name:SetWidth(266)
        end
    end
    if e.item and not e.service then r.mats:Hide() end
    r.del:SetShown(e.custom and true or false)
    r.len:Hide() -- (the per-row character count was dropped; the meter shows the total)
    r.hl:SetShown(ns.rowDrag and ns.rowDrag.targetId == e.id and ns.rowDrag.id ~= e.id or false)
    r:Show()
end

-- Place pooled frames for the items in view. While scrolling, a row that's
-- already showing the right item is only moved; only rows coming into view
-- get filled, so each scroll step touches a handful of rows, not all of them.
local function RenderVisible()
    if not list then return end
    local ad = ns.ActiveAd()
    local top = list:GetVerticalScroll() - BUFFER
    local bottom = list:GetVerticalScroll() + list:GetHeight() + BUFFER
    local width = list.child:GetWidth()
    local refillAll = ns.rowDrag ~= nil -- drag highlights change every frame

    local current, stale = {}, {}
    for _, r in ipairs(rows) do
        if r:IsShown() and r:Focused() then
            current[r.id] = r; stale[r] = r.gen ~= gen or refillAll -- the row you're typing in keeps its item
        elseif r:IsShown() and r.gen == gen and not refillAll then
            current[r.id] = r
        end
    end

    local used, pending, hi = {}, {}, 0
    for _, it in ipairs(layout) do
        if it.y + it.h >= top and it.y <= bottom then
            if it.kind == "head" then
                hi = hi + 1
                FillHead(AcquireHead(hi), it, width)
            else
                local r = current[it.e.id]
                if r and stale[r] then
                    FillRow(r, it, width, ad)
                    used[r] = true
                elseif r then
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", 0, -it.y)
                    r:SetWidth(width)
                    r.layoutIndex = it.index
                    used[r] = true
                else
                    pending[#pending + 1] = it
                end
            end
        end
    end
    -- fill rows coming into view with frames nobody is using (never one
    -- you're typing in)
    local ri = 1
    for _, it in ipairs(pending) do
        local r = rows[ri]
        while r and (used[r] or r:Focused()) do ri = ri + 1; r = rows[ri] end
        if not r then r = AcquireRow(#rows + 1); ri = #rows end
        FillRow(r, it, width, ad)
        used[r] = true
        ri = ri + 1
    end
    for _, r in ipairs(rows) do
        if not used[r] then r:Hide() end
    end
    for i = hi + 1, #heads do heads[i]:Hide() end
    ui.visibleHeads, ui.visibleRows = hi, #rows
end
ns.RenderVisibleList = RenderVisible

-- After typing a price: show or hide that section's "Clear prices" button
function ns.UpdateSectionPrices(slotKey)
    local head, any = nil, false
    for _, it in ipairs(layout) do
        if it.kind == "head" and it.slot.key == slotKey then head = it
        elseif it.kind == "row" and it.e.slot == slotKey and ns.GetPriceC(it.e.id) then any = true end
    end
    if head and (head.hasPrice and true or false) ~= any then
        head.hasPrice = any and not head.slot.extras
        RenderVisible()
    end
end

-- Search: matches the recipe name, the item name, or how it reads in the ad
local searchText = ""
local function Matches(e)
    if searchText == "" then return true end
    local hay = table.concat({ ns.DisplayName(e) or "", e.recipe or "", ns.ItemText(e.id) or "", e.text or "" }, "\001"):lower()
    for word in searchText:gmatch("%S+") do
        if not hay:find(word, 1, true) then return false end
    end
    return true
end

local function BuildList()
    gen = gen + 1
    wipe(ahCache); wipe(matsCache)
    local ad = ns.ActiveAd()
    local filter = ns.db.settings.filter
    local bySlot, priced = {}, {}
    local isItem = ns.Pack(ns.ProfOf()).kind == "item" or ns.Pack(ns.ProfOf()).pricedText
    for _, e in ipairs(ns.AllEntries()) do
        if isItem and ns.GetPriceC(e.id) then priced[e.slot] = true end
        if (filter ~= "selected" or ns.ItemState(ad, e.id)) and Matches(e) then
            bySlot[e.slot] = bySlot[e.slot] or {}
            table.insert(bySlot[e.slot], e)
        end
    end

    wipe(layout)
    local y, nrows = 0, 0
    for _, slot in ipairs(ns.OrderedSlots()) do
        local entries = bySlot[slot.key]
        if entries or (slot.extras and searchText == "") then
            local on, total = 0, 0
            for _, e in ipairs(entries or {}) do
                total = total + 1
                if ns.ItemState(ad, e.id) then on = on + 1 end
            end
            layout[#layout + 1] = { kind = "head", slot = slot, y = y, h = HEAD_H, on = on, total = total, index = #layout + 1,
                hasPrice = priced[slot.key] and not slot.extras }
            y = y + HEAD_H + 2
            for _, e in ipairs(entries or {}) do
                layout[#layout + 1] = { kind = "row", e = e, y = y, h = ROW_H, index = #layout + 1 }
                y = y + ROW_H
                nrows = nrows + 1
            end
            y = y + 6
        end
    end
    layoutHeight = y
    if ui.empty then
        local msg
        if ns.Pack(ns.ProfOf()).bags and nrows == 0 and searchText == "" and filter ~= "selected" then
            msg = "Nothing in your bags to sell.\n\nAnything that isn't soulbound shows up here\nas soon as it's in your bags."
        elseif not ns.HasScanned() then
            msg = "Open your |c" .. W.Hex(col.accent) .. ns.Pack(ns.ProfOf()).name .. "|r window once.\n\nShout Out will list every recipe you know\nand grab your profession link for the ad.\n\nDon't have it? Turn on Preview in Settings."
        elseif searchText ~= "" and nrows == 0 then
            msg = "Nothing matches |c" .. W.Hex(col.accent) .. searchText .. "|r" .. (filter == "selected" and " in this ad.\nSwitch to All to search everything." or ".")
        elseif filter == "selected" and nrows == 0 then
            msg = "Nothing in this ad yet.\nSwitch to |c" .. W.Hex(col.accent) .. "All|r and check some recipes."
        end
        ui.empty:SetText(msg or "")
        ui.empty:SetShown(msg ~= nil)
    end
    if ui.listTitle then ui.listTitle:SetText(ns.Pack(ns.ProfOf()).name) end
    if ui.ahFill then
        ui.ahFill:SetShown(ns.Pack(ns.ProfOf()).kind == "item" and ns.db.settings.ahPrices and true or false)
        ui.clearPrices:SetShown((ns.Pack(ns.ProfOf()).kind == "item" or ns.Pack(ns.ProfOf()).pricedText) and true or false)
        ui.clearPrices:ClearAllPoints()
        if ui.ahFill:IsShown() then ui.clearPrices:SetPoint("RIGHT", ui.ahFill, "LEFT", -4, 0)
        else ui.clearPrices:SetPoint("BOTTOMRIGHT", ui.ahFill, "BOTTOMRIGHT", 0, 0) end
    end
    list.child:SetHeight(math.max(y, 1))
    list:ScrollTo(list:GetVerticalScroll()) -- clamps and redraws
    RenderVisible()
end

-------------------------------------------------------------------------------
-- Dragging section headers
-------------------------------------------------------------------------------
local function CursorY(frame)
    local _, y = GetCursorPosition()
    return y / frame:GetEffectiveScale()
end

local function Ghost(text)
    local ghost = ui.dragGhost
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        ghost:SetFrameStrata("TOOLTIP")
        ghost:SetSize(150, 22)
        W.Backdrop(ghost, col.accentD, col.accent)
        ghost.text = W.Text(ghost, 11, col.text)
        ghost.text:SetPoint("CENTER")
        ui.dragGhost = ghost
    end
    ghost.text:SetText(text)
    ghost:SetScale(f:GetEffectiveScale() / UIParent:GetEffectiveScale())
    ghost:Show()
    return ghost
end

local function FollowCursor(ghost)
    local x, y = GetCursorPosition()
    local sc = ghost:GetEffectiveScale()
    ghost:ClearAllPoints()
    ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / sc + 40, y / sc)
    local ly = CursorY(list)
    local top, bottom = list:GetTop(), list:GetBottom()
    if top and ly > top - 16 then list:ScrollTo(list:GetVerticalScroll() - 6)
    elseif bottom and ly < bottom + 16 then list:ScrollTo(list:GetVerticalScroll() + 6) end
end

-- The section under the cursor: the last header whose top is above it
local function SectionUnderCursor()
    local cy = CursorY(list.child)
    local found = heads[1]
    for i = 1, ui.visibleHeads or 0 do
        local top = heads[i]:GetTop()
        if top and cy <= top then found = heads[i] end
    end
    return found
end

function ns.StartSectionDrag(h)
    GameTooltip:Hide()
    local ghost = Ghost(h.title:GetText())
    h:SetAlpha(0.4)
    ns.sectionDrag = { head = h, key = h.slotKey }
    ghost:SetScript("OnUpdate", function(self)
        -- the header frame you grabbed gets reused once it scrolls out of view,
        -- so the drag ends when you let go of the button, not when that frame says so
        if not IsMouseButtonDown("LeftButton") then ns.StopSectionDrag(true) return end
        FollowCursor(self)
        local target = SectionUnderCursor()
        for i = 1, ui.visibleHeads or 0 do heads[i].hl:SetShown(heads[i] == target and target ~= h) end
        ns.sectionDrag.target = target
    end)
end

function ns.StopSectionDrag(released)
    local d = ns.sectionDrag
    if not d then return end
    if not released and IsMouseButtonDown("LeftButton") then return end -- still dragging
    ns.sectionDrag = nil
    ui.dragGhost:Hide()
    ui.dragGhost:SetScript("OnUpdate", nil)
    for i = 1, #heads do heads[i].hl:Hide(); heads[i]:SetAlpha(1) end
    local targetKey = d.target and d.target.slotKey
    if targetKey and targetKey ~= d.key then
        local from, to = ns.SlotRank(d.key), ns.SlotRank(targetKey)
        ns.MoveSlot(d.key, targetKey, to > from) -- dragging down drops after
        ns.Refresh(true)
    end
end

-- Row under the cursor, limited to the dragged recipe's own section
local function RowUnderCursor(slot)
    local cy = CursorY(list.child)
    local found
    for _, r in ipairs(rows) do
        if r:IsShown() and r.slot == slot then
            local top, bottom = r:GetTop(), r:GetBottom()
            if top and bottom and cy <= top and cy >= bottom then return r end
            if top and cy > top and (not found or r.layoutIndex < found.layoutIndex) then found = r end
            if bottom and cy < bottom and (not found or r.layoutIndex > found.layoutIndex) then found = r end
        end
    end
    return found
end

function ns.StartRowDrag(r)
    GameTooltip:Hide()
    local ghost = Ghost(r.name:GetText() or "")
    ns.rowDrag = { id = r.id, slot = r.slot, from = r.layoutIndex }
    r:SetAlpha(0.4)
    ghost:SetScript("OnUpdate", function(self)
        if not IsMouseButtonDown("LeftButton") then ns.StopRowDrag(true) return end
        FollowCursor(self)
        local target = RowUnderCursor(ns.rowDrag.slot)
        ns.rowDrag.targetId = target and target.id
        ns.rowDrag.to = target and target.layoutIndex
        for _, row in ipairs(rows) do
            if row:IsShown() then row.hl:SetShown(row.id == ns.rowDrag.targetId and row.id ~= ns.rowDrag.id) end
        end
    end)
end

function ns.StopRowDrag(released)
    local d = ns.rowDrag
    if not d then return end
    if not released and IsMouseButtonDown("LeftButton") then return end -- still dragging
    ns.rowDrag = nil
    ui.dragGhost:Hide()
    ui.dragGhost:SetScript("OnUpdate", nil)
    ns.justDraggedAt = GetTime()
    for _, row in ipairs(rows) do row.hl:Hide(); row:SetAlpha(1) end
    if d.targetId and d.targetId ~= d.id then
        ns.MoveItem(d.id, d.targetId, (d.to or 0) > (d.from or 0)) -- dragging down drops after
        ns.Refresh(true)
    end
end

-------------------------------------------------------------------------------
-- Ad tabs (top)
-------------------------------------------------------------------------------
-- The tab bar has two parts so it never overflows, however many professions
-- and ads you have:
--   * one icon per profession you have ads for (click to switch profession)
--   * tabs for the ads of the current profession only, shrinking to fit, with
--     a "+N" menu for any that still don't fit
local profBtns, ahead = {}, {}
local function AcquireProfButton(i)
    local b = profBtns[i]
    if b then return b end
    b = W.Button(ui.tabBar, "", 26, 26)
    b:SetFrameLevel(ui.tabBar:GetFrameLevel() + 3)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18) -- square, so the icon keeps its shape
    b.icon:SetPoint("CENTER")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetScript("OnClick", function(self)
        -- go to the ad you last used in that profession
        local best, bestSeen
        for i, ad in ipairs(ns.db.ads) do
            if ns.ProfOf(ad) == self.prof and (not bestSeen or (ad.seen or 0) > bestSeen) then best, bestSeen = i, ad.seen or 0 end
        end
        if best then ns.db.active = best; ns.Refresh(true) end
    end)
    b:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(ns.Pack(self.prof).name, 1, 1, 1)
        GameTooltip:AddLine(self.count .. " ad" .. (self.count == 1 and "" or "s") .. ". Click to show them.", 0.8, 0.8, 0.85)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    profBtns[i] = b
    return b
end

local function AcquireTab(i)
    local t = tabs[i]
    if t then return t end
    t = W.Button(ui.tabBar, "", 100, 22, "ghost")
    t:SetFrameLevel(ui.tabBar:GetFrameLevel() + 3)
    t.dot = t:CreateTexture(nil, "ARTWORK")
    t.dot:SetSize(6, 6)
    t.dot:SetPoint("LEFT", 8, 0)
    t.text:ClearAllPoints()
    t.text:SetPoint("LEFT", t.dot, "RIGHT", 6, 0)
    t.text:SetPoint("RIGHT", -6, 0)
    t.text:SetJustifyH("LEFT")
    t.text:SetWordWrap(false)
    t.under = t:CreateTexture(nil, "OVERLAY")
    t.under:SetColorTexture(unpack(col.accent))
    t.under:SetHeight(2)
    t.under:SetPoint("BOTTOMLEFT", 6, 1)
    t.under:SetPoint("BOTTOMRIGHT", -6, 1)
    t:SetScript("OnClick", function(self)
        ns.db.active = self.index
        ns.Refresh(true)
    end)
    t:HookScript("OnEnter", function(self)
        if self.text:IsTruncated() then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.fullName, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    t:HookScript("OnLeave", function() GameTooltip:Hide() end)
    tabs[i] = t
    return t
end

local function BuildTabs()
    for _, t in ipairs(tabs) do t:Hide() end
    for _, b in ipairs(profBtns) do b:Hide() end
    local active = ns.ActiveAd()
    local curProf = ns.ProfOf(active)
    -- remember which ad you last used in each profession
    if ns.lastActiveAd ~= active then
        ns.db.seq = (ns.db.seq or 0) + 1
        active.seen = ns.db.seq
        ns.lastActiveAd = active
    end

    -- profession icons, in the order their first ad appears
    local order, count = {}, {}
    for _, ad in ipairs(ns.db.ads) do
        local p = ns.ProfOf(ad)
        if not count[p] then count[p] = 0; table.insert(order, p) end
        count[p] = count[p] + 1
    end
    local x = 0
    for i, p in ipairs(order) do
        local b = AcquireProfButton(i)
        local pack = ns.Pack(p)
        b.prof, b.count = p, count[p]
        b.icon:SetTexture(pack.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local on = p == curProf
        b:SetActive(on)
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.75)
        b:ClearAllPoints()
        b:SetPoint("LEFT", ui.tabBar, "LEFT", x, 0)
        b:Show()
        x = x + 28
    end
    ui.tabSep:ClearAllPoints()
    ui.tabSep:SetPoint("LEFT", ui.tabBar, "LEFT", x + 5, 0)
    x = x + 12

    -- this profession's ads
    local mine = {}
    for i, ad in ipairs(ns.db.ads) do if ns.ProfOf(ad) == curProf then mine[#mine + 1] = i end end
    local barW = ui.tabBar:GetWidth() or 860
    local room = barW - x - 84 -- leave space for "+ New ad"
    local MINW, MAXW = 72, 170
    local widths, total = {}, 0
    for k, i in ipairs(mine) do
        local ad, t = ns.db.ads[i], AcquireTab(k)
        t.index, t.fullName = i, (ad.name ~= "" and ad.name or ("Ad " .. i))
        t:SetLabel(t.fullName)
        widths[k] = math.min(MAXW, t.text:GetStringWidth() + 32)
        total = total + widths[k] + 2
    end
    -- too wide: shrink the longest tabs first, down to a minimum
    while total > room do
        local big, bw = nil, MINW
        for k, w in ipairs(widths) do if w > bw then big, bw = k, w end end
        if not big then break end
        local step = math.min(4, bw - MINW)
        widths[big] = bw - step
        total = total - step
    end
    -- still too wide: show what fits and list the rest under "+N"
    local fits = #mine
    if total > room then
        local sum = 0
        fits = 0
        for k, w in ipairs(widths) do
            if sum + w + 2 > room - 44 then break end
            sum = sum + w + 2
            fits = k
        end
    end
    -- keep the active ad visible
    local shown = {}
    for k = 1, fits do shown[k] = mine[k] end
    local activeIdx = ns.db.active
    local activeShown = false
    for _, i in ipairs(shown) do if i == activeIdx then activeShown = true end end
    if not activeShown and fits > 0 then shown[fits] = activeIdx end
    wipe(ahead)
    for k = 1, #mine do
        local i = mine[k]
        local isShown = false
        for _, j in ipairs(shown) do if j == i then isShown = true end end
        if not isShown then ahead[#ahead + 1] = i end
    end

    for k, i in ipairs(shown) do
        local ad, t = ns.db.ads[i], AcquireTab(k)
        t.index, t.fullName = i, (ad.name ~= "" and ad.name or ("Ad " .. i))
        t:SetLabel(t.fullName)
        local w = widths[k] or MINW
        if i ~= mine[k] then w = math.min(MAXW, math.max(MINW, t.text:GetStringWidth() + 32)) end
        t:SetWidth(w)
        local c = ns.AdColor(ad)
        t.dot:SetColorTexture(c[1], c[2], c[3], 1)
        t.under:SetColorTexture(c[1], c[2], c[3], 1)
        local on = i == activeIdx
        t.under:SetShown(on)
        t.text:SetTextColor(unpack(on and col.text or col.dim))
        t:ClearAllPoints()
        t:SetPoint("LEFT", ui.tabBar, "LEFT", x, 0)
        t:Show()
        x = x + w + 2
    end
    ui.moreTabs:SetShown(#ahead > 0)
    if #ahead > 0 then
        ui.moreTabs.emptyText = "+" .. #ahead
        ui.moreTabs:Refresh()
        ui.moreTabs:ClearAllPoints()
        ui.moreTabs:SetPoint("LEFT", ui.tabBar, "LEFT", x + 2, 0)
        x = x + 44
    end
    ui.addTab:ClearAllPoints()
    ui.addTab:SetPoint("LEFT", ui.tabBar, "LEFT", x + 4, 0)
end

-------------------------------------------------------------------------------
-- Preview / settings (right)
-------------------------------------------------------------------------------
-- One chat line as WoW Forever shows it: [4. Trade (Services)] [Name]: text
local function ChatLine(msg, chan)
    local r, g, b = 1, 0.75, 0.75
    local SAY_COLORS = { SAY = { 1, 1, 1 }, YELL = { 1, 0.25, 0.25 }, GUILD = { 0.25, 1, 0.25 } }
    if chan and chan.chatType then r, g, b = unpack(SAY_COLORS[chan.chatType]) end
    local info = chan and ChatTypeInfo and ChatTypeInfo[chan.chatType or ("CHANNEL" .. (chan.id or 0))]
    if info and info.r then r, g, b = info.r, info.g, info.b end
    local hex = string.format("ff%02x%02x%02x", r * 255, g * 255, b * 255)
    local name = UnitName("player") or "You"
    local _, class = UnitClass("player")
    local cc = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if cc and cc.GenerateHexColor then
        name = "|c" .. cc:GenerateHexColor() .. name .. "|r"
    elseif cc and cc.colorStr then
        name = "|c" .. cc.colorStr .. name .. "|r"
    end
    local shown = ns.DisplayText(msg)
    -- raid icons only show in Say, Yell and Guild: draw them there, like the game does
    if chan and chan.chatType then
        shown = shown:gsub("{[Rr][Tt]([1-8])}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%1:0|t")
    end
    local body = shown:gsub("|r", "|r|c" .. hex) -- text color resets after links/names
    local head
    if chan and chan.chatType == "SAY" then
        head = "[" .. name .. "|c" .. hex .. "] says: "
    elseif chan and chan.chatType == "YELL" then
        head = "[" .. name .. "|c" .. hex .. "] yells: "
    elseif chan and chan.chatType == "GUILD" then
        head = "[Guild] [" .. name .. "|c" .. hex .. "]: "
    else
        local tag = chan and ("[" .. chan.id .. ". " .. ns.ChannelLabel(chan.name) .. "]") or "[Trade]"
        head = tag .. " [" .. name .. "|c" .. hex .. "]: "
    end
    return "|c" .. hex .. head .. body .. "|r"
end
ns.ChatLine = ChatLine

local function UpdatePreview()
    local ad = ns.ActiveAd()
    local msg, included, dropped = ns.Build(ad)
    local chan = ns.FindChannel()
    local len = ns.MeasureLen(msg)
    ui.lastMsg = msg
    -- nothing checked yet: the groups (and the text that goes with them, like
    -- "WTS") drop out, leaving only "/w me". Say what's missing instead.
    local nothing = ns.HasListToken(ad) and #included == 0
    ui.preview:SetText((msg ~= "" and not nothing) and ChatLine(msg, chan)
        or "|cff6a6a75Nothing checked yet. Check what you're selling on the left and your ad appears here.|r")
    -- the bar fills against whichever limit is tighter (visible text or the
    -- full message with link code)
    local ratio = math.min(1, ns.Fullness(msg))
    ui.meterFill:SetWidth(math.max(1, (ui.meter:GetWidth() - 2) * ratio))
    local c = (ratio < 0.85) and col.good or (ratio < 0.97 and col.warn or col.accent)
    ui.meterFill:SetVertexColor(unpack(c))
    local rawNote = ""
    -- the hidden link code only matters once it's the tighter limit
    if #msg ~= len and #msg / ns.MaxRaw() > len / ns.MaxLen() then
        rawNote = "  |cffffc857(" .. #msg .. "/" .. ns.MaxRaw() .. " with link code)|r"
    end
    ui.meterText:SetText(len .. " / " .. ns.MaxLen() .. rawNote)

    -- the preview and Next post box already show what fits; only warn when
    -- the message has nowhere to put the enchant list
    ui.dropped:SetText(ns.HasListToken(ad) and "" or "|cffffc857No " .. ns.Pack(ns.ProfOf(ad)).listToken .. " in your message, so nothing is listed.|r")

    -- next post (rotation): only shown when Rotate overflow is on
    local rotating = ns.Rotating(ad)
    ui.nextLabel:SetShown(rotating)
    ui.nextBox:SetShown(rotating)
    ui.remindLabel:ClearAllPoints()
    ui.remindLabel:SetPoint("TOPLEFT", rotating and ui.nextBox or ui.dropped, "BOTTOMLEFT", 0, rotating and -10 or -6)
    ui.nextLabel:SetText(ns.IsOverflowNext(ad) and "NEXT POST (STARTS OVER)" or "NEXT POST (ONLY WHAT DIDN'T FIT)")
    local nextMsg = ns.BuildNext(ad)
    if nextMsg then
        ui.nextPreview:SetText(ChatLine(nextMsg, chan))
    else
        ui.nextPreview:SetText("|cff6a6a75Everything fits, so the next post is the same as this one.|r")
    end

    local blocked = ns.PostBlocked(ad)
    ui.post:SetLabel(blocked and "Preview: test only" or (ns.IsOverflowNext(ad) and "Overflow post" or "Post"))
    ui.post:SetAlpha(blocked and 0.55 or 1)
    ui.copy:SetEnabled(not blocked)
    ui.copy:SetAlpha(blocked and 0.45 or 1)
    ui.post:SetTint(ns.AdColor(ad))
    ui.swatch.fill:SetColorTexture(unpack(ns.AdColor(ad)))
    ui.chanDD.emptyText = "|cffff6b6bNot in Trade/Services|r"
    ui.chanDD:Refresh()
    ui.linkBtn:SetLabel(ns.Pack(ns.ProfOf(ad)).always and "+ [Profession]" or ("+ [" .. ns.Pack(ns.ProfOf(ad)).name .. "]"))
    ui.listBtn.emptyText = ns.Pack(ns.ProfOf(ad)).listLabel or (ns.Pack(ns.ProfOf(ad)).kind == "item" and "+ Items" or "+ Enchants")
    ui.listBtn:Refresh()
    local isItem = ns.Pack(ns.ProfOf(ad)).kind == "item"
    -- per slot only means something when the ad groups by labelled slots
    local showPer = (not isItem and ad.slotLabels and not ns.Pack(ns.ProfOf(ad)).always) and true or false
    ui.perDD:SetShown(showPer)
    ui.lPer:SetShown(showPer)
    -- item ads only use the separator between labelled groups
    -- the Separator only matters where one list covers labelled groups:
    -- Enchanting, or a crafting ad with Slot labels on (and Warlock places)
    local showSep = ns.SepApplies(ad)
    ui.sepDD:SetShown(showSep and true or false)
    ui.lSep:SetShown(showSep and true or false)
    ui.lPreview:SetText(ns.UsingExample(ad) and "PREVIEW  |cff6a6a75(EXAMPLE MESSAGE)|r" or "PREVIEW")
    ui.lPreview:ClearAllPoints()
    if showSep then ui.lPreview:SetPoint("TOPLEFT", ui.sepDD, "BOTTOMLEFT", 0, -12)
    else ui.lPreview:SetPoint("TOPLEFT", ui.cbCaps, "BOTTOMLEFT", 0, -14) end
    ui.FitToolbar()
    ui.profDD:Refresh()
    ui.cbLinks:SetShown(ns.Pack(ns.ProfOf(ad)).kind == "item")
    -- Format rows, laid out from what this ad uses (Mage and Warlock ads
    -- don't need slot labels or rotation), so nothing floats off to the right
    local classAd = ns.Pack(ns.ProfOf(ad)).class ~= nil
    ui.cbLabels:SetShown(not classAd)
    ui.cbRotate:SetShown(not classAd)
    local row1, prev = {}, nil
    for _, cb in ipairs({ ui.cbLabels, ui.cbRotate, ui.cbLinks }) do
        if cb:IsShown() then row1[#row1 + 1] = cb end
    end
    local GAPS = { 110, 118 }
    for k, cb in ipairs(row1) do
        cb:ClearAllPoints()
        if k == 1 then cb:SetPoint("TOPLEFT", ui.lFormat, "BOTTOMLEFT", 0, -8)
        else cb:SetPoint("LEFT", row1[k - 1], "LEFT", GAPS[k - 1] or 110, 0) end
    end
    ui.cbCaps:ClearAllPoints()
    if row1[1] then ui.cbCaps:SetPoint("TOPLEFT", row1[1], "BOTTOMLEFT", 0, -10)
    else ui.cbCaps:SetPoint("TOPLEFT", ui.lFormat, "BOTTOMLEFT", 0, -8) end
    ui.cbCaps:SetChecked(ad.caps and true or false)
    local canRepeat = ns.Pack(ns.ProfOf(ad)).repeatable and true or false
    ui.lRepeat:SetShown(canRepeat)
    ui.repeatDD:SetShown(canRepeat)
    ui.repeatDD:Refresh()
    ui.cbLinks:SetChecked(ad.links)
    ui.linkBtn.text:SetTextColor(unpack((ns.Pack(ns.ProfOf(ad)).always or ns.ProfLink()) and col.accent or col.warn))
end

-- Typing fires this on every key; several calls in one frame (a price box,
-- its section, the row) are drawn once, on the next frame.
local previewQueued = false
function ns.RefreshPreview()
    if previewQueued then return end
    previewQueued = true
    C_Timer.After(0, function()
        previewQueued = false
        if f and f:IsShown() then UpdatePreview() end
        if ns.RefreshMini then ns.RefreshMini() end
    end)
end

local function UpdateSettings()
    local s = ns.db.settings
    local ad = ns.ActiveAd()
    if not ui.template:HasFocus() then ui.template:SetText(ad.template or "") end
    if ui.UpdateTemplateHint then ui.UpdateTemplateHint() end
    if not ui.adName:HasFocus() then ui.adName:SetText(ad.name or "") end
    ui.cbLabels:SetChecked(ad.slotLabels)
    ui.cbRotate:SetChecked(ns.Rotating(ad))
    ui.cbRemind:SetChecked(s.remind)
    ui.cbSound:SetChecked(s.sound)
    ui.sepDD:Refresh()
    ui.perDD:Refresh()
    if not ui.interval:HasFocus() then ui.interval:SetText(s.interval) end
    ui.cbFlash:SetChecked(s.flash)
    ui.delAd:SetEnabled(#ns.db.ads > 1)
    for key, b in pairs(ui.filters) do
        b:SetActive(s.filter == key)
    end
end

function ns.UpdateTimer(left)
    if not f or not f:IsShown() then return end -- nothing to draw while closed
    left = left or ns.SecondsUntilReady()
    if left > 0 then
        ui.timer:SetText("|cff8a8a96Next post in|r " .. ns.FormatTime(left))
        ui.timerBar:SetWidth(math.max(1, (ui.timerTrack:GetWidth()) * (1 - left / ns.db.settings.interval)))
        ui.timerBar:SetVertexColor(unpack(col.accentD))
    else
        ui.timer:SetText(ns.lastPost > 0 and "|cff7ddc8aReady to post|r" or "|cff8a8a96Not posted yet|r")
        ui.timerBar:SetWidth(ui.timerTrack:GetWidth())
        ui.timerBar:SetVertexColor(unpack(col.good))
    end
end

-- full = rebuild the list too (structure changed); otherwise just preview
function ns.Refresh(full)
    if ns.RefreshMini then ns.RefreshMini() end
    if not f or not f:IsShown() then return end
    if full then BuildTabs(); BuildList() else
        -- keep group counts and the per-item length numbers current
        BuildList()
    end
    UpdateSettings()
    UpdatePreview()
end

local function Label(parent, text, anchor, x, y)
    local l = W.Text(parent, 10, col.dim)
    l:SetText(text:upper())
    l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -10)
    return l
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
function ns.CreateUI()
    rows, heads, tabs = {}, {}, {}
    ui.rows, ui.heads = rows, heads
    f = CreateFrame("Frame", "ShoutOutMainFrame", UIParent, "BackdropTemplate")
    ns.frame = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    W.Backdrop(f, col.bg, col.winBorder, "lg")
    f:Hide()
    tinsert(UISpecialFrames, "ShoutOutMainFrame")

    -- accent strip + title bar
    local strip = f:CreateTexture(nil, "ARTWORK")
    strip:SetColorTexture(unpack(col.accent))
    strip:SetPoint("TOPLEFT", 1 + W.radiusLg, -1)   -- kept clear of rounded corners
    strip:SetPoint("TOPRIGHT", -1 - W.radiusLg, -1)
    strip:SetHeight(2)

    local title = CreateFrame("Frame", nil, f)
    title:SetPoint("TOPLEFT", 0, -3)
    title:SetPoint("TOPRIGHT", 0, -3)
    title:SetHeight(36)
    W.Movable(f, "main", title)

    local icon = title:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.ICON_TITLE)
    icon:SetTexCoord(0, 30 / 32, 0, 30 / 32) -- the 30x30 image, drawn 1:1
    icon:SetSize(30, 30)
    icon:SetPoint("LEFT", 10, 0)
    local name = W.Text(title, 17, col.text)
    name:SetText("Shout Out")
    name:SetPoint("LEFT", icon, "RIGHT", 9, 1)
    local sub = W.Text(title, 12, col.dim)
    sub:SetText("v" .. ns.VERSION)
    sub:SetPoint("LEFT", name, "RIGHT", 8, -1)

    local close = W.Button(title, "x", 24, 24, "ghost")
    close:SetPoint("RIGHT", -8, 0)
    close.text:SetFont(W.FONT, 14, "")
    close:SetScript("OnClick", function() f:Hide() end)

    -- ad tabs
    ui.tabBar = CreateFrame("Frame", nil, f)
    ui.tabBar:SetPoint("TOPLEFT", 12, -42)
    ui.tabBar:SetPoint("TOPRIGHT", -12, -42)
    ui.tabBar:SetHeight(26)
    local tabLine = f:CreateTexture(nil, "ARTWORK")
    tabLine:SetColorTexture(unpack(col.border))
    tabLine:SetHeight(1)
    tabLine:SetPoint("TOPLEFT", ui.tabBar, "BOTTOMLEFT", 0, 0)
    tabLine:SetPoint("TOPRIGHT", ui.tabBar, "BOTTOMRIGHT", 0, 0)
    ui.tabSep = ui.tabBar:CreateTexture(nil, "ARTWORK")
    ui.tabSep:SetColorTexture(col.border[1], col.border[2], col.border[3], 1)
    ui.tabSep:SetSize(1, 18)
    -- ads that don't fit as tabs
    ui.moreTabs = W.Dropdown(ui.tabBar, 40, function()
        local items = {}
        for _, i in ipairs(ahead) do
            local ad = ns.db.ads[i]
            items[#items + 1] = { value = i, label = ad.name ~= "" and ad.name or ("Ad " .. i) }
        end
        return items
    end, function(it) ns.db.active = it.value; ns.Refresh(true) end)
    ui.moreTabs:SetHeight(22)
    ui.moreTabs:Hide()
    W.Tooltip(ui.moreTabs, "More ads", "This profession's other ads, the ones that don't fit as tabs.")
    ui.addTab = W.Button(ui.tabBar, "+ New ad", 72, 20)
    ui.addTab:SetScript("OnClick", function()
        local cur = ns.ActiveAd()
        local ad = ns.NewAd("New ad", nil, ns.ProfOf(cur)) -- starts from the profession's default message
        table.insert(ns.db.ads, ad)
        ns.db.active = #ns.db.ads
        ns.Refresh(true)
        ui.adName:SetFocus()
        ui.adName:HighlightText()
    end)

    ---------------------------------------------------------------- left side
    local left = W.Panel(f)
    left:SetPoint("TOPLEFT", 12, -80)
    left:SetPoint("BOTTOMLEFT", 12, 12)
    left:SetWidth(LEFT_W)

    local lt = W.Text(left, 12, col.text)
    lt:SetText("Recipes")
    ui.listTitle = lt
    lt:SetPoint("TOPLEFT", 10, -10)

    ui.filters = {}
    local prev
    for _, def in ipairs({ { "selected", "In ad" }, { "all", "All" } }) do
        local b = W.Button(left, def[2], 52, 18)
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -3, 0) else b:SetPoint("TOPRIGHT", -10, -7) end
        b:SetScript("OnClick", function()
            ns.db.settings.filter = def[1]
            list:ScrollTo(0)
            ns.Refresh(true)
        end)
        ui.filters[def[1]] = b
        prev = b
    end
    ui.filter = function() return ns.db.settings.filter end

    -- search box: filters the list as you type
    ui.search = W.Edit(left, 170, 20, function(t)
        searchText = (t or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        ui.searchPh:SetShown(t == "")
        ui.searchClear:SetShown(t ~= "")
        list:ScrollTo(0)
        BuildList()
    end, 40)
    ui.search:SetPoint("RIGHT", prev, "LEFT", -10, 0)
    ui.search:SetTextInsets(20, 20, 0, 0)
    ui.search:SetFont(W.FONT, 11, "")
    local mag = ui.search:CreateTexture(nil, "OVERLAY")
    mag:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    mag:SetSize(12, 12)
    mag:SetPoint("LEFT", 5, -1)
    mag:SetVertexColor(col.dim[1], col.dim[2], col.dim[3], 1)
    ui.searchPh = W.Text(ui.search, 11, col.dim)
    ui.searchPh:SetPoint("LEFT", 20, 0)
    ui.searchPh:SetText("Search")
    ui.searchClear = W.Button(ui.search, "x", 16, 16, "ghost")
    ui.searchClear:SetPoint("RIGHT", -2, 0)
    ui.searchClear.text:SetTextColor(unpack(col.dim))
    ui.searchClear:Hide()
    ui.searchClear:SetScript("OnClick", function()
        ui.search:SetText("")
        ui.search:ClearFocus()
        searchText = ""
        ui.searchPh:Show()
        ui.searchClear:Hide()
        BuildList()
    end)
    ui.search:SetScript("OnEscapePressed", function() ui.searchClear:Click() end)
    W.Tooltip(ui.search, "Search", "Type part of a name to find a recipe or item, e.g. \"cloak\", \"crusader\" or \"armor kit\". Check All / Uncheck All only affect what's shown. Esc clears it.")


    ui.empty = W.Text(left, 12, col.dim)
    ui.empty:SetPoint("CENTER", 0, 20)
    ui.empty:SetJustifyH("CENTER")
    ui.empty:SetWordWrap(true)
    ui.empty:SetWidth(LEFT_W - 60)
    ui.empty:Hide()

    list = W.Scroll(left)
    list:SetPoint("TOPLEFT", 6, -32)
    list:SetPoint("BOTTOMRIGHT", -12, 40)

    local allBtn = W.Button(left, "Check All", 84, 22)
    allBtn:SetPoint("BOTTOMLEFT", 8, 9)
    allBtn:SetScript("OnClick", function()
        for _, it in ipairs(layout) do if it.kind == "row" then ns.SetItemState(ns.ActiveAd(), it.e.id, true) end end
        ns.Refresh(true)
    end)
    ui.ahFill = W.Button(left, "Use AH prices", 100, 22)
    ui.ahFill:SetPoint("BOTTOMRIGHT", -12, 9)
    ui.ahFill:SetScript("OnClick", function()
        local entries = {}
        for _, it in ipairs(layout) do if it.kind == "row" then entries[#entries + 1] = it.e end end
        local n = ns.FillPricesFromAH(entries)
        ns.Print(n > 0 and ("Filled |cffffffff" .. n .. "|r empty prices from the auction house.")
            or "No empty prices to fill (or no AH data yet). Scan the AH with Auctionator first.")
        ns.Refresh(true)
    end)
    W.Tooltip(ui.ahFill, "Use AH prices", function()
        return "Fills every empty price box with its auction house price from " .. (ns.PriceSourceName and ns.PriceSourceName() or "Auctionator or TradeSkillMaster") .. ". Prices you've typed are never changed. Items with no AH price stay empty."
    end)
    ui.clearPrices = W.Button(left, "Clear all prices", 104, 22)
    ui.clearPrices:SetPoint("RIGHT", ui.ahFill, "LEFT", -4, 0)
    W.ConfirmClick(ui.clearPrices, "Clear all prices", function()
        local n = ns.ClearPrices(ns.AllEntries(ns.ProfOf()))
        ns.Print(n > 0 and ("Cleared |cffffffff" .. n .. "|r " .. ns.Pack(ns.ProfOf()).name .. " prices.") or "No prices to clear.")
        ns.Refresh(true)
    end)
    W.Tooltip(ui.clearPrices, "Clear all prices", function() return "Empties every price box in " .. (ns.Pack(ns.ProfOf()).always and "this ad type" or "this profession") .. ". Your checkmarks stay as they are." end)
    local noneBtn = W.Button(left, "Uncheck All", 90, 22)
    noneBtn:SetPoint("LEFT", allBtn, "RIGHT", 4, 0)
    noneBtn:SetScript("OnClick", function()
        for _, it in ipairs(layout) do if it.kind == "row" then ns.SetItemState(ns.ActiveAd(), it.e.id, false) end end
        ns.Refresh(true)
    end)

    --------------------------------------------------------------- right side
    local right = W.Panel(f)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
    right:SetPoint("BOTTOMRIGHT", -12, 12)
    local RW = WIDTH - LEFT_W - 34 - 24

    local l1 = W.Text(right, 10, col.dim)
    l1:SetText("AD NAME")
    l1:SetPoint("TOPLEFT", 12, -12)
    ui.adName = W.Edit(right, RW - 98 - 116, 22, function(t)
        ns.ActiveAd().name = t
        BuildTabs()
        if ns.RefreshMini then ns.RefreshMini() end
    end, 30)
    ui.adName:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4)
    -- color swatch: click for the palette
    ui.swatch = W.Button(right, "", 22, 22)
    ui.profDD = W.Dropdown(right, 110, function()
        local items = {}
        for _, p in ipairs(ns.PROFESSIONS) do
            -- class ads only for that class (or with Preview on)
            if ns.ClassPackAvailable(p) or p.key == ns.ProfOf() then items[#items + 1] = { value = p.key, label = p.name } end
        end
        return items
    end, function(it)
        local ad = ns.ActiveAd()
        if ad.prof == it.value then return end
        local old = ns.Pack(ns.ProfOf(ad))
        -- an empty box follows the profession (its example); one you've written stays
        if ad.template == old.defaultTemplate then ad.template = "" end
        ad.prof = it.value
        ad.links = ns.Pack(it.value).kind == "item"
        ad.slotLabels = ns.Pack(it.value).kind ~= "item"
        ad.pending = nil
        ns.Refresh(true)
    end, function() return ns.ProfOf() end)
    ui.profDD:SetPoint("LEFT", ui.adName, "RIGHT", 6, 0)
    W.Tooltip(ui.profDD, "Profession", "Which profession this ad advertises. Each ad has its own.")
    ui.swatch:SetPoint("LEFT", ui.profDD, "RIGHT", 6, 0)
    ui.swatch.fill = ui.swatch:CreateTexture(nil, "ARTWORK")
    ui.swatch.fill:SetPoint("TOPLEFT", 4, -4)
    ui.swatch.fill:SetPoint("BOTTOMRIGHT", -4, 4)
    W.Tooltip(ui.swatch, "Ad color", "Colors this ad's tab, the Post button and the quick-post bar button, so you can tell at a glance which ad is up.")

    local pal = CreateFrame("Frame", nil, f, "BackdropTemplate")
    W.Backdrop(pal, col.menu, col.border)
    pal:SetFrameLevel(f:GetFrameLevel() + 30)
    pal:SetSize(#ns.AD_COLORS * 22 + 8, 30)
    pal:SetPoint("TOPRIGHT", ui.swatch, "BOTTOMRIGHT", 0, -3)
    pal:Hide()
    for i, p in ipairs(ns.AD_COLORS) do
        local b = W.Button(pal, "", 20, 20)
        b:SetPoint("LEFT", 4 + (i - 1) * 22, 0)
        local fill = b:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", 3, -3)
        fill:SetPoint("BOTTOMRIGHT", -3, 3)
        fill:SetColorTexture(unpack(p.c))
        W.Tooltip(b, p.name)
        b:SetScript("OnClick", function()
            ns.ActiveAd().color = p.key
            pal:Hide()
            ns.Refresh(true)
        end)
    end
    ui.swatch:SetScript("OnClick", function() pal:SetShown(not pal:IsShown()) end)
    f:HookScript("OnHide", function() pal:Hide() end)

    ui.delAd = W.Button(right, "Delete", 64, 22)
    ui.delAd:SetPoint("LEFT", ui.swatch, "RIGHT", 6, 0)
    ui.delAd.text:SetTextColor(unpack(col.bad))
    ui.delAd:SetScript("OnClick", function(self)
        if not self.confirm then
            self.confirm = true
            self:SetLabel("Sure?")
            C_Timer.After(3, function() self.confirm = nil; self:SetLabel("Delete") end)
            return
        end
        self.confirm = nil
        self:SetLabel("Delete")
        table.remove(ns.db.ads, ns.db.active)
        ns.db.active = math.max(1, math.min(ns.db.active, #ns.db.ads))
        ns.Refresh(true)
    end)

    -- The whole message, fully editable. {enchants} = your packed list,
    -- {prof} = your clickable profession link.
    local l2 = Label(right, "Message", ui.adName, 0, -10)
    ui.template = W.Edit(right, RW, 66, function(t) ns.ActiveAd().template = t; UpdatePreview() end, 500)
    ui.template:SetMultiLine(true)
    ui.template:SetTextInsets(6, 6, 5, 5)
    ui.template:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4)
    ui.template:SetScript("OnMouseDown", function(self) self:SetFocus() end)
    -- Tokens are tinted so you can see your layout at a glance: the box draws
    -- its own text invisibly (cursor and selection still work) and a coloured
    -- copy sits exactly on top of it.
    local TOKEN_COLORS = { prof = "ffffd27a", rt = "ffff8fb1", list = W.Hex(col.accent) }
    local mirror = ui.template:CreateFontString(nil, "OVERLAY")
    mirror:SetFont(ui.template:GetFont())
    mirror:SetPoint("TOPLEFT", 6, -5)
    mirror:SetPoint("TOPRIGHT", -6, -5)
    mirror:SetJustifyH("LEFT")
    mirror:SetJustifyV("TOP")
    mirror:SetWordWrap(true)
    if mirror.SetNonSpaceWrap then mirror:SetNonSpaceWrap(true) end
    ui.templateMirror = mirror
    local tr, tg, tb = unpack(col.text)
    -- the game draws the typing cursor in the box's text color, so while you
    -- type the box shows its own text (cursor visible) and the tinted copy
    -- steps aside; it comes back when you click away
    local function ShowTint(on)
        mirror:SetShown(on)
        ui.template:SetTextColor(tr, tg, tb, on and 0 or 1)
    end
    ShowTint(true)
    ui.template:HookScript("OnEditFocusGained", function() ShowTint(false) end)
    ui.template:HookScript("OnEditFocusLost", function() ShowTint(true) end)
    function ui.UpdateTemplateMirror()
        -- the same raw text the box shows: the box itself shows "||" as one pipe,
        -- so escaping it again here would show two
        local text = ui.template:GetText() or ""
        text = text:gsub("{([^{}]*)}", function(inner)
            local low = inner:lower()
            local hex = (low:match("^prof") and TOKEN_COLORS.prof) or (low:match("^rt%d$") and TOKEN_COLORS.rt) or TOKEN_COLORS.list
            return "|c" .. hex .. "{" .. inner .. "}|r"
        end)
        mirror:SetText(text)
        mirror:SetTextColor(tr, tg, tb, 1)
    end
    -- empty box: the profession's example message, in grey, until you type
    local hint = ui.template:CreateFontString(nil, "OVERLAY")
    hint:SetFont(ui.template:GetFont())
    hint:SetPoint("TOPLEFT", 6, -5)
    hint:SetPoint("TOPRIGHT", -6, -5)
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("TOP")
    hint:SetWordWrap(true)
    if hint.SetNonSpaceWrap then hint:SetNonSpaceWrap(true) end
    hint:SetTextColor(col.dim[1], col.dim[2], col.dim[3], 0.75)
    ui.templateHint = hint
    local measure = ui.template:CreateFontString(nil, "OVERLAY")
    measure:SetFont(ui.template:GetFont())
    measure:SetText("Ag")
    measure:SetAlpha(0)
    local lastExtra = 0
    function ui.UpdateTemplateHint()
        local empty = not (ui.template:GetText() or ""):match("%S")
        hint:SetShown(empty)
        if empty then
            hint:SetText(ns.DefaultTemplate(ns.ProfOf()))
        end
        -- The box grows to fit its own text, so empty it's one line tall and
        -- the example would spill out below. While it's empty, extra space at
        -- the bottom of the box makes it as tall as the example.
        local extra = 0
        if empty then
            local lineH = measure:GetStringHeight() or 0
            local h = hint:GetStringHeight() or 0
            if type(h) == "number" and type(lineH) == "number" and h > lineH then extra = h - lineH end
        end
        if extra ~= lastExtra then
            lastExtra = extra
            ui.template:SetTextInsets(6, 6, 5, 5 + extra)
        end
        if empty and extra > 0 then
            local lineH = measure:GetStringHeight()
            if type(lineH) == "number" then ui.template:SetHeight(lineH + extra + 10) end
        end
    end
    ui.template:HookScript("OnTextChanged", function() ui.UpdateTemplateMirror(); ui.UpdateTemplateHint() end)
    -- double-click selects a word (or a whole {token}), triple-click everything
    local clicks, lastClick = 0, 0
    ui.template:HookScript("OnMouseUp", function(self)
        local now = GetTime()
        clicks = (now - lastClick < 0.35) and clicks + 1 or 1
        lastClick = now
        if clicks < 2 then return end
        local n = clicks
        C_Timer.After(0, function() -- after the game has placed the cursor
            if not self:HasFocus() then return end
            if n >= 3 then self:HighlightText(); return end
            local text = self:GetText() or ""
            local pos = (self:GetCursorPosition() or 0) + 1 -- 1-based char after the cursor
            -- inside a {token}? take the whole token
            local i = 1
            while true do
                local a, b = text:find("{[^{}]*}", i)
                if not a then break end
                if pos >= a and pos <= b + 1 then self:HighlightText(a - 1, b); return end
                i = b + 1
            end
            local function isWord(c) return c ~= "" and c:match("[%w'%%%+%-]") ~= nil end
            local st, en = pos, pos - 1
            if not isWord(text:sub(pos, pos)) and isWord(text:sub(pos - 1, pos - 1)) then st, en = pos - 1, pos - 2 end
            while st > 1 and isWord(text:sub(st - 1, st - 1)) do st = st - 1 end
            while isWord(text:sub(en + 1, en + 1)) do en = en + 1 end
            if en >= st then self:HighlightText(st - 1, en) end
        end)
    end)
    W.Tooltip(ui.template, "Your message", function()
        local pack = ns.Pack(ns.ProfOf())
        local A = "|c" .. W.Hex(col.accent)
        local lines = { "Write the whole ad however you like. While the box is empty, the example shown in grey is what posts." }
        if pack.key == "mage" then
            lines[#lines + 1] = A .. "{portals}|r becomes the portals you checked, e.g. \"UC & TB 40s from ORG\"."
            lines[#lines + 1] = A .. "{items}|r becomes your checked food and water with prices."
        elseif pack.key == "warlock" then
            lines[#lines + 1] = A .. "{places}|r becomes the places you checked, with prices."
        elseif pack.bags then
            lines[#lines + 1] = A .. "{items}|r becomes the bag items you checked, with prices."
        else
            lines[#lines + 1] = A .. pack.listToken .. "|r becomes everything you checked, packed to fit 255 characters."
            lines[#lines + 1] = A .. "{prof}|r becomes your clickable profession link, e.g. [" .. pack.name .. "]."
        end
        lines[#lines + 1] = "Enter or Esc to finish editing."
        return table.concat(lines, "\n")
    end)

    local function InsertToken(token)
        local box = ui.template
        box:SetFocus()
        box:Insert(token)
        ns.ActiveAd().template = box:GetText()
        UpdatePreview()
    end
    -- Insert toolbar: profession link, recipe list, raid icons
    -- sized to fill the panel width exactly: 8 icons + two text buttons
    local ICON, GAP = 17, 2
    local iconsW = 8 * ICON + 7 * GAP
    local textW = RW - iconsW - 6 - 4
    local linkW = math.floor(textW * 0.57)
    ui.linkBtn = W.Button(right, "", linkW, ICON + 2)
    ui.linkBtn.text:SetFont(W.FONT, 10, "")
    ui.linkBtn.text:SetTextColor(unpack(col.accent))
    ui.linkBtn:SetPoint("TOPLEFT", ui.template, "BOTTOMLEFT", 0, -5)
    ui.linkBtn:SetScript("OnClick", function()
        if ns.Pack(ns.ProfOf()).always then ui.profMenu:Click() else InsertToken(ns.PROF_TOKEN) end
    end)
    -- class and custom ads: a menu of your professions to link ("Also offering [Tailoring]")
    ui.profMenu = W.Dropdown(right, 10, function()
        local items = {}
        for _, p in ipairs(ns.PROFESSIONS) do
            if not p.always then
                local has = ns.ProfLink(p.key)
                items[#items + 1] = { value = p.key, label = p.name, note = has and "linked" or "open its window" }
            end
        end
        return items
    end, function(it) InsertToken("{prof:" .. ns.Pack(it.value).name .. "}") end)
    ui.profMenu:SetAllPoints(ui.linkBtn)
    ui.profMenu:SetAlpha(0)
    ui.profMenu:EnableMouse(false)
    ui.linkBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local pack = ns.Pack(ns.ProfOf())
        if pack.always then
            GameTooltip:SetText("Insert a profession link", 1, 1, 1)
            GameTooltip:AddLine("Pick one of your professions, e.g. \"Also offering {prof:Tailoring}\". In chat it becomes your clickable [Tailoring] link, so people can see what you craft. Open a profession's window once so Shout Out has its link.", 0.8, 0.8, 0.85, true)
            GameTooltip:Show()
            return
        end
        GameTooltip:SetText("Insert your [" .. pack.name .. "] link", 1, 1, 1)
        GameTooltip:AddLine("Adds {prof} at the cursor. In chat it becomes your clickable profession link, so people can browse everything you can make.", 0.8, 0.8, 0.85, true)
        if ns.ProfLink() then
            GameTooltip:AddLine("Link captured.", unpack(col.good))
        else
            GameTooltip:AddLine("Open your " .. pack.name .. " window once to capture it. Until then {prof} posts as \"" .. pack.fallback .. "\".", unpack(col.warn))
        end
        GameTooltip:AddLine("It counts as its name length ([" .. pack.name .. "]) toward the 255 limit.", 0.55, 0.55, 0.62, true)
        GameTooltip:Show()
    end)
    ui.linkBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- "+ Items" opens a menu: everything you checked, or just one section,
    -- so you can write your own text between groups
    ui.listBtn = W.Dropdown(right, textW - linkW, function()
        local pack = ns.Pack(ns.ProfOf())
        local word = pack.listToken:match("{(%a+)}") or "items"
        local items = { { value = pack.listToken, label = "All checked", note = pack.listToken } }
        if pack.key == "mage" then
            -- portals have their own token ({items} is food and water only)
            items = {
                { value = "{portals} | {items}", label = "Portals and food", note = "both" },
                { value = "{portals}", label = "Portals", note = "{portals}" },
                { value = "{items}", label = "All food & water", note = "{items}" },
            }
        end
        local present = {}
        for _, e in ipairs(ns.AllEntries(pack.key)) do present[e.slot] = true end
        local groupsAdded = {}
        for _, def in ipairs(ns.OrderedSlots(pack.key)) do
            if present[def.key] and not def.extras and not def.ownToken then
                -- a group of sections (e.g. every Food level) can go in as one
                if def.group and not groupsAdded[def.group] then
                    groupsAdded[def.group] = true
                    items[#items + 1] = { value = "{" .. word .. ":" .. def.group .. "}", label = def.group .. " (all)", note = "whole group" }
                end
                local name = (def.short and def.short ~= "") and def.short or def.label
                local tok = "{" .. word .. ":" .. name .. "}"
                items[#items + 1] = { value = tok, label = def.label, note = "only this" }
            end
        end
        return items
    end, function(it) InsertToken(it.value) end)
    ui.listBtn:SetHeight(ICON + 2)
    ui.listBtn.text:SetFont(W.FONT, 10, "")
    ui.listBtn.text:SetTextColor(unpack(col.accent))
    ui.listBtn:SetPoint("LEFT", ui.linkBtn, "RIGHT", 4, 0)
    -- share the space between the two text buttons by how long their labels are,
    -- shrinking the font if a long profession name still doesn't fit
    function ui.FitToolbar()
        for size = 10, 8, -1 do
            ui.linkBtn.text:SetFont(W.FONT, size, "")
            ui.listBtn.text:SetFont(W.FONT, size, "")
            local a, b = ui.linkBtn.text:GetStringWidth() + 12, ui.listBtn.text:GetStringWidth() + 30
            if a + b + 4 <= textW or size == 8 then
                local extra = math.max(0, textW - 4 - a - b)
                local la = math.floor(a + extra / 2)
                ui.linkBtn:SetWidth(la)
                ui.listBtn:SetWidth(textW - 4 - la)
                return
            end
        end
    end
    W.Tooltip(ui.listBtn, "Insert your list", function()
        local pack = ns.Pack(ns.ProfOf())
        local tok = pack.listToken
        local ex = (pack.sections[1] and pack.sections[1].label) or "Armor Kits"
        if pack.key == "mage" then
            return "{portals}: the portals you checked, with prices.\n{items}: your checked food and water.\n\nOr pick a level, e.g. {items:" .. ex .. "}, to place just that group. A group with nothing checked is left out, along with the label right before it."
        end
        return "All checked: adds " .. tok .. ", where everything you checked goes, packed to fit.\n\nOr pick a section, e.g. {items:" .. ex .. "}, to place just that group and write your own text around it:\n|cffffffffWTS {items:" .. ex .. "} | Also: {items}|r\n\n" .. tok .. " never repeats a section that has its own token. If a group has nothing in a post, the label right before it (like \"Also:\") is left out too."
    end)

    local RAID_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
    local prevIcon = ui.listBtn
    for i = 1, 8 do
        local b = W.IconButton(right, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i, ICON)
        b:SetPoint("LEFT", prevIcon, "RIGHT", i == 1 and 6 or GAP, 0)
        b:SetScript("OnClick", function() InsertToken("{rt" .. i .. "}") end)
        W.Tooltip(b, RAID_NAMES[i] .. "  {rt" .. i .. "}",
            "Inserts the universal {rt" .. i .. "} code, which works in every game language.")
        if i == 1 then ui.firstIcon = b end
        prevIcon = b
    end
    -- note under the icons, exactly as wide as the icon row
    ui.iconNote = W.Text(right, 9, col.dim)
    ui.iconNote:SetPoint("TOPLEFT", ui.firstIcon, "BOTTOMLEFT", 0, -3)
    ui.iconNote:SetPoint("TOPRIGHT", prevIcon, "BOTTOMRIGHT", 0, -3)
    ui.iconNote:SetWordWrap(true)
    ui.iconNote:SetJustifyH("LEFT")
    ui.iconNote:SetText("Raid icons only show in Say, Yell and Guild.")

    local l4 = Label(right, "Format", ui.linkBtn, 0, -30) -- leaves room for the icon note
    ui.lFormat = l4
    ui.cbLabels = W.Check(right, "Slot labels", function(v) ns.ActiveAd().slotLabels = v; ns.Refresh(true) end)
    ui.cbLabels:SetPoint("TOPLEFT", l4, "BOTTOMLEFT", 0, -8)
    W.Tooltip(ui.cbLabels, "Slot labels", "For this ad: put each section's label in front of its group, e.g. \"Cloak: [Hide of the Wild]\" instead of just \"[Hide of the Wild]\". You can change each label in its section header. Turning them off saves space.")
    ui.cbRotate = W.Check(right, "Rotate overflow", function(v)
        local ad = ns.ActiveAd()
        ad.rotate = v
        if not v then ad.pending = nil end
        UpdatePreview()
        if ns.RefreshMini then ns.RefreshMini() end
    end)
    ui.cbRotate:SetPoint("LEFT", ui.cbLabels, "LEFT", 110, 0)
    ui.cbLinks = W.Check(right, "Item links", function(v)
        ns.ActiveAd().links = v
        UpdatePreview()
    end)
    ui.cbLinks:SetPoint("LEFT", ui.cbRotate, "LEFT", 118, 0)
    W.Tooltip(ui.cbLinks, "Item links", function()
        local rot = ns.Pack(ns.ProfOf()).class and "" or " Rotate overflow puts the rest in the next post."
        return "For this ad: post items as clickable links people can inspect, with your price after each one. Links carry hidden code, so fewer fit per post." .. rot
    end)
    W.Tooltip(ui.cbRotate, "Rotate overflow", "For this ad only: when you've checked more than fits, the next post lists only the items that were left out, then it starts over. Never more than two posts. The next post is shown under the preview.")

    ui.perDD = W.Dropdown(right, RW - 156, function()
        local items = {}
        for n = 1, 5 do items[#items + 1] = { value = n, label = n .. " per slot" } end
        return items
    end, function(it) ns.db.settings.perSlot = it.value; UpdatePreview() end,
    function() return ns.PerSlot() end)
    W.Tooltip(ui.perDD, "Enchants per slot",
        "How many enchants each gear slot can show in one post, e.g. with 2 per slot: \"1H: Crusader, Fiery | Chest: +4 Stats, 100 HP\". The rest go into the next post when Rotate overflow is on.")

    -- second format row: ALL CAPS and Repeat (every ad)
    ui.cbCaps = W.Check(right, "ALL CAPS", function(v) ns.ActiveAd().caps = v; UpdatePreview() end)
    W.Tooltip(ui.cbCaps, "ALL CAPS", "For this ad: post your text in capitals, e.g. \"WTS SUMMONS TO EVERLOOK\". Links keep their own names.")
    ui.lRepeat = W.Text(right, 11, col.text)
    ui.lRepeat:SetText("Repeat")
    ui.repeatDD = W.Dropdown(right, 80, function()
        return { { value = 1, label = "1x" }, { value = 2, label = "2x" }, { value = 3, label = "3x" },
                 { value = 4, label = "4x" }, { value = "fill", label = "Fill" } }
    end, function(it) ns.ActiveAd().repeatN = it.value; UpdatePreview() end,
    function() return ns.ActiveAd().repeatN or 1 end)
    ui.repeatDD:SetHeight(20)
    ui.lRepeat:SetPoint("LEFT", ui.cbCaps, "LEFT", 110, 0)
    ui.repeatDD:SetPoint("LEFT", ui.lRepeat, "RIGHT", 8, 0)
    W.Tooltip(ui.repeatDD, "Repeat", "Warlock ads: says your ad more than once in the same post so it stands out, e.g. \"WTS SUMMONS TO EVERLOOK 1g | WTS SUMMONS TO EVERLOOK 1g | /w me\". Everything before your last | part repeats; the last part (like \"/w me\") stays once at the end. Fill repeats as many times as fit.")

    local lSep = Label(right, "Separator", ui.cbCaps, 0, -12)
    ui.lSepLabel = lSep
    ui.lSep = lSep
    ui.sepDD = W.Dropdown(right, 150, function()
        local items = {}
        for _, it in ipairs(ns.SEPARATORS) do
            items[#items + 1] = { value = it.value, label = it.label, icon = it.icon }
        end
        return items
    end, function(it) ns.ActiveAd().sep = it.value; ns.Refresh() end,
    function() return ns.AdSep(ns.ActiveAd()) end)
    ui.sepDD:SetPoint("TOPLEFT", lSep, "BOTTOMLEFT", 0, -4)
    local lPer = W.Text(right, 10, col.dim)
    ui.lPer = lPer
    lPer:SetText("PER SLOT")
    lPer:SetPoint("LEFT", lSep, "LEFT", 156, 0)
    ui.perDD:SetPoint("TOPLEFT", lPer, "BOTTOMLEFT", 0, -4)
    W.Tooltip(ui.sepDD, "Separator", function()
        local tail = " Raid icons only show in Say, Yell and Guild; in Trade and other channels they post as plain text."
        if ns.Pack(ns.ProfOf()).placeSep then
            return "For this ad: what goes between each place, e.g. \"Everlook 1g | Gadgetzan 1g\"." .. tail
        end
        return "For this ad: what goes between labelled groups, e.g. \"Wep: Crusader | Chest: +4 Stats\". Items within a group are always separated by commas." .. tail
    end)


    -- preview
    local l5 = Label(right, "Preview", ui.sepDD, 0, -12)
    ui.lPreview = l5
    local function ChatBox(height)
        local box = CreateFrame("Frame", nil, right, "BackdropTemplate")
        W.Backdrop(box, col.chat, col.border)
        box:SetSize(RW, height)
        local fs = W.Text(box, 12, { 1, 0.86, 0.86, 1 })
        fs:SetFont(ChatFontNormal and ChatFontNormal:GetFont() or W.FONT, 12, "")
        fs:SetWordWrap(true)
        fs:SetJustifyV("TOP")
        fs:SetPoint("TOPLEFT", 7, -6)
        fs:SetPoint("BOTTOMRIGHT", -7, 4)
        return box, fs
    end
    local pv
    pv, ui.preview = ChatBox(84)
    pv:SetPoint("TOPLEFT", l5, "BOTTOMLEFT", 0, -5)

    ui.copy = W.Button(right, "Copy", 52, 18)
    ui.copy.text:SetFont(W.FONT, 10, "")
    ui.copy:SetPoint("BOTTOMRIGHT", pv, "TOPRIGHT", 0, 3)
    ui.copy:SetScript("OnClick", function()
        if ns.PostBlocked() then return end -- previewed ads stay test-only
        ns.ShowCopy(ns.PlainText(ui.lastMsg or ""))
    end)
    ui.sendTest = W.Button(right, "Send test to me", 104, 18)
    ui.sendTest.text:SetFont(W.FONT, 10, "")
    ui.sendTest:SetPoint("RIGHT", ui.copy, "LEFT", -4, 0)
    ui.sendTest:SetScript("OnClick", function() ns.SendTest() end)
    W.Tooltip(ui.sendTest, "Send a test to yourself",
        "Sends this exact message to a private channel only you are in, then shows it in your chat window the way it will look when you post. Nobody else sees it.")
    W.Tooltip(ui.copy, "Copy message", function()
        if ns.PostBlocked() then return "Not available while this profession is previewed. Use Send test to me to see the ad." end
        return "Opens the message selected and ready to copy with Ctrl+C. Links are copied as their [Name] text; addons can't put clickable links on the clipboard."
    end)

    ui.meter = CreateFrame("Frame", nil, right, "BackdropTemplate")
    W.Backdrop(ui.meter, col.input, col.border, math.min(W.radius, 3))
    ui.meter:SetPoint("TOPLEFT", pv, "BOTTOMLEFT", 0, -6)
    ui.meter:SetSize(RW, 8)
    ui.meterFill = ui.meter:CreateTexture(nil, "ARTWORK")
    ui.meterFill:SetTexture("Interface\\Buttons\\WHITE8x8")
    ui.meterFill:SetPoint("TOPLEFT", 1, -1)
    ui.meterFill:SetPoint("BOTTOMLEFT", 1, 1)
    ui.meterText = W.Text(right, 10, col.dim)
    ui.meterText:SetPoint("TOPRIGHT", ui.meter, "BOTTOMRIGHT", 0, -4)
    ui.dropped = W.Text(right, 10, col.dim)
    ui.dropped:SetPoint("TOPLEFT", ui.meter, "BOTTOMLEFT", 0, -4)
    ui.dropped:SetPoint("RIGHT", ui.meterText, "LEFT", -8, 0)
    ui.dropped:SetWordWrap(true)
    ui.dropped:SetJustifyV("TOP")
    ui.dropped:SetHeight(14)
    ui.dropped:SetWordWrap(false)

    -- next post preview (rotation)
    local lNext = Label(right, "Next post (only what didn't fit)", ui.dropped, 0, -4)
    local nx
    nx, ui.nextPreview = ChatBox(70)
    nx:SetPoint("TOPLEFT", lNext, "BOTTOMLEFT", 0, -5)
    ui.nextPreview:SetAlpha(0.85)
    ui.nextLabel, ui.nextBox = lNext, nx

    -- reminder settings
    local l6 = Label(right, "Reminder", nx, 0, -10)
    ui.remindLabel = l6
    ui.cbRemind = W.Check(right, "Remind me every", function(v) ns.db.settings.remind = v end)
    ui.cbRemind:SetPoint("TOPLEFT", l6, "BOTTOMLEFT", 0, -8)
    ui.interval = W.Edit(right, 46, 20, function(t)
        local n = tonumber(t)
        if n and n >= 10 then ns.db.settings.interval = math.min(n, 3600) end
    end, 4)
    ui.interval:SetNumeric(true)
    ui.interval:SetJustifyH("CENTER")
    ui.interval:SetPoint("LEFT", ui.cbRemind, "RIGHT", 112, 0)
    ui.interval:HookScript("OnEditFocusLost", function(self)
        local n = math.min(3600, math.max(10, tonumber(self:GetText()) or ns.db.settings.interval))
        ns.db.settings.interval = n
        self:SetText(n)
    end)
    W.Tooltip(ui.interval, "Reminder interval", "Type the number of seconds between posts (10 to 3600).")
    local secs = W.Text(right, 11, col.dim)
    secs:SetText("seconds")
    secs:SetPoint("LEFT", ui.interval, "RIGHT", 6, 0)
    ui.cbSound = W.Check(right, "Sound", function(v) ns.db.settings.sound = v end)
    ui.cbSound:SetPoint("TOPLEFT", ui.cbRemind, "BOTTOMLEFT", 0, -8)
    ui.cbFlash = W.Check(right, "Flash quick-post bar outline", function(v)
        ns.db.settings.flash = v
        if ns.TickMini then ns.TickMini(ns.SecondsUntilReady()) end
    end)
    ui.cbFlash:SetPoint("LEFT", ui.cbSound, "LEFT", 80, 0)
    W.Tooltip(ui.cbFlash, "Flash quick-post bar", "When it's time to post again, a flashing outline goes around the quick-post bar.")

    -- post button + timer
    ui.chanDD = W.Dropdown(right, 150, function()
        local items = {}
        for _, c in ipairs(ns.GetJoinedChannels()) do
            items[#items + 1] = { value = c.name, label = c.id .. ". " .. ns.ChannelLabel(c.name) }
        end
        for _, t in ipairs(ns.CHAT_TARGETS) do
            if not t.needsGuild or (IsInGuild and IsInGuild()) then
                items[#items + 1] = { value = t.key, label = "/" .. t.name:lower() }
            end
        end
        return items
    end, function(it) if it.value ~= "" then ns.db.settings.channel = it.value; UpdatePreview() end end,
    function() local c = ns.FindChannel(); return c and (c.key or c.name) end)
    ui.chanDD:SetHeight(34)
    ui.chanDD:SetPoint("BOTTOMLEFT", 12, 26)
    W.Tooltip(ui.chanDD, "Channel", "Where Post sends your ad: a channel you're in right now, or /say, /yell or /guild (guild only shows when you're in one). If you leave the channel you picked, Shout Out falls back to Services, then Trade.")

    ui.post = W.Button(right, "Post", RW - 156, 34, "accent")
    ui.post:SetPoint("LEFT", ui.chanDD, "RIGHT", 6, 0)
    ui.post:SetScript("OnClick", function() ns.Post() end)
    ui.post.glow = W.Ring(ui.post, 3, { col.accent[1], col.accent[2], col.accent[3], 0.7 })
    ui.post.glow:Hide()

    ui.timerTrack = CreateFrame("Frame", nil, right)
    ui.timerTrack:SetPoint("BOTTOMLEFT", 12, 16)
    ui.timerTrack:SetSize(RW, 3)
    local tbg = ui.timerTrack:CreateTexture(nil, "BACKGROUND")
    tbg:SetAllPoints()
    tbg:SetColorTexture(1, 1, 1, 0.06)
    ui.timerBar = ui.timerTrack:CreateTexture(nil, "ARTWORK")
    ui.timerBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    ui.timerBar:SetPoint("TOPLEFT")
    ui.timerBar:SetPoint("BOTTOMLEFT")
    ui.timerBar:SetWidth(1)
    ui.timer = W.Text(right, 10, col.dim)
    ui.timer:SetPoint("BOTTOMLEFT", ui.chanDD, "TOPLEFT", 0, 6)
    local keyHint = W.Text(right, 9, col.dim)
    keyHint:SetPoint("BOTTOMRIGHT", ui.post, "TOPRIGHT", 0, 6)
    keyHint:SetText("Bind a key: Options > Keybindings > AddOns")

    f:SetScale(ns.db.settings.scale or 1)
    f:SetScript("OnShow", function()
        ns.Refresh(true); ns.UpdateTimer()
        if ns.PrepareTestChannel then ns.PrepareTestChannel() end
    end)
    f:SetScript("OnHide", function()
        -- give a just-sent test a moment to come back before leaving
        C_Timer.After(5, function() if not f:IsShown() and ns.LeaveTestChannel then ns.LeaveTestChannel() end end)
    end)

    ---------------------------------------------------------------- settings
    local sp = CreateFrame("Frame", nil, f, "BackdropTemplate")
    W.Backdrop(sp, col.bg, { 0, 0, 0, 0 }, "lg")
    sp:SetPoint("TOPLEFT", 1, -40)
    sp:SetPoint("BOTTOMRIGHT", -1, 1)
    sp:SetFrameLevel(f:GetFrameLevel() + 20)
    sp:EnableMouse(true)
    sp:Hide()
    ui.settings = sp

    local inner = W.Panel(sp)
    inner:SetPoint("TOP", 0, -12)
    inner:SetSize(420, 735)
    local st = W.Text(inner, 14, col.text)
    st:SetText("Settings")
    st:SetPoint("TOPLEFT", 16, -14)

    -- label + slider + live percentage. applyLive: apply while dragging
    -- (off for the main window, which would move under the cursor)
    local function ScaleSlider(anchor, label, get, set, applyLive, yOff)
        local l = W.Text(inner, 11, col.text)
        l:SetText(label)
        l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -14)
        local val = W.Text(inner, 11, col.text)
        val:SetJustifyH("RIGHT")
        val:SetWidth(44)
        val:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -16, 0)
        val:SetPoint("TOP", l, "TOP", 0, 0)
        local slider = W.Slider(inner, 150, 0.6, 1.5, 0.05, function(v, final)
            val:SetText(math.floor(v * 100 + 0.5) .. "%")
            if applyLive or final then set(v) end
        end)
        slider:SetPoint("RIGHT", val, "LEFT", -10, 0)
        W.Tooltip(slider, label, "Drag, click or use the mouse wheel. 60% to 150%.")
        l.Show2 = function()
            slider:SetValueQuiet(get())
            val:SetText(math.floor(get() * 100 + 0.5) .. "%")
        end
        l.slider = slider
        return l
    end
    -- every control sits in one right-hand column, lined up with the sliders
    local COLX, COLW = 200, 204
    -- rows start 16px in, so the column is COLX - 16 from a row's left edge;
    -- anchoring by LEFT also centers the control on the row vertically
    local function AtColumn(frame, row, w)
        frame:ClearAllPoints()
        frame:SetPoint("LEFT", row, "LEFT", COLX - 16, 0)
        if w then frame:SetWidth(w) end
    end
    local function Section(anchor, text, yOff)
        local l = W.Text(inner, 10, col.accent)
        l:SetText(text:upper())
        l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -20)
        return l
    end

    -- theme (applies after a reload, since every frame is built with it)
    local sLook = Section(st, "Look", -18)
    ui.themeDD = W.Dropdown(inner, 170, function()
        local items = {}
        for _, key in ipairs(W.THEME_ORDER) do items[#items + 1] = { value = key, label = W.THEMES[key].name } end
        return items
    end, function(it)
        ns.db.settings.theme = it.value
        ui.reloadBtn:SetShown(it.value ~= W.themeKey)
    end, function() return ns.db.settings.theme end)
    local lTheme = W.Text(inner, 11, col.text)
    lTheme:SetText("Theme")
    lTheme:SetPoint("TOPLEFT", sLook, "BOTTOMLEFT", 0, -14)
    AtColumn(ui.themeDD, lTheme, COLW)
    ui.reloadBtn = W.Button(inner, "Reload to apply", 110, 22, "accent")
    ui.reloadBtn:SetPoint("RIGHT", ui.themeDD, "LEFT", -10, 0)
    ui.reloadBtn:SetScript("OnClick", function() ReloadUI() end)
    ui.reloadBtn:Hide()
    W.Tooltip(ui.themeDD, "Theme", "Arcane Glass: soft, rounded, teal. Midnight Violet: the original flat look. Reloads your interface to apply.")

    local sWin = Section(lTheme, "Main window", -22)
    ui.scaleRow = ScaleSlider(sWin, "Window scale", function() return ns.db.settings.scale or 1 end,
        function(v) ns.db.settings.scale = v; ns.ScaleMainWindow(v) end, true, -12)

    local sMini = Section(ui.scaleRow, "Quick-post bar")
    ui.cbMini = W.Check(inner, "Show quick-post bar", function(v)
        ns.db.settings.showMini = v
        if ns.mini then ns.mini:SetShown(v) end
    end)
    ui.cbMini:SetPoint("TOPLEFT", sMini, "BOTTOMLEFT", 0, -12)
    ui.miniScaleRow = ScaleSlider(ui.cbMini, "Quick-post bar scale", function() return ns.db.settings.miniScale or 1 end,
        function(v) ns.db.settings.miniScale = v; if ns.mini then ns.mini:SetScale(v) end end, true)

    local sMap = Section(ui.miniScaleRow, "Minimap")
    ui.cbMinimap = W.Check(inner, "Show minimap button", function(v)
        ns.db.settings.showMinimap = v
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    end)
    ui.cbMinimap:SetPoint("TOPLEFT", sMap, "BOTTOMLEFT", 0, -12)
    W.Tooltip(ui.cbMinimap, "Minimap button", "Left-click: open Shout Out\nRight-click: Settings\nMiddle-click: hide the button\nDrag it around the minimap to move it.")

    -- Preview: build ads for a profession this character doesn't have
    local sPrev = Section(ui.cbMinimap, "Preview a profession")
    local prevNote = W.Text(inner, 10, col.dim)
    prevNote:SetPoint("TOPLEFT", sPrev, "BOTTOMLEFT", 0, -6)
    prevNote:SetText("Pretend you know every recipe. Previewed ads can only be sent as a test.")
    ui.previewChecks = {}
    local anchor = prevNote
    local previewable = {}
    for _, p in ipairs(ns.PROFESSIONS) do if not p.noPreview then previewable[#previewable + 1] = p end end
    for i, p in ipairs(previewable) do
        local cb = W.Check(inner, p.name, function(v) ns.SetPreview(p.key, v) end)
        -- three per row, so every profession fits the panel
        local col3 = (i - 1) % 3
        if i == 1 then cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
        elseif col3 == 0 then cb:SetPoint("TOPLEFT", ui.previewChecks[i - 3], "BOTTOMLEFT", 0, -8)
        else cb:SetPoint("LEFT", ui.previewChecks[i - 1], "LEFT", 130, 0) end
        ui.previewChecks[i] = cb
        cb.prof = p.key
    end

    -- first section under the Preview checkboxes
    local lastRowFirst = ui.previewChecks[#ui.previewChecks - (#ui.previewChecks - 1) % 3]
    -- AH price estimates
    local sAH = Section(lastRowFirst, "Auction house prices", -18)
    ui.cbAH = W.Check(inner, "Show AH price estimates", function(v)
        ns.db.settings.ahPrices = v
        ns.Refresh(true)
    end)
    ui.cbAH:SetPoint("TOPLEFT", sAH, "BOTTOMLEFT", 0, -12)
    ui.priceStatus = W.Text(inner, 10, col.dim)
    ui.priceStatus:SetPoint("LEFT", ui.cbAH, "LEFT", COLX - 16, 0)
    W.Tooltip(ui.cbAH, "AH price estimates", "Shows an auction house estimate next to each crafted item, as a reference for your own prices. Comes from Auctionator or TradeSkillMaster, whichever you use.")
    -- where prices come from: picked automatically from what's installed, or chosen
    local lSrc = W.Text(inner, 11, col.text)
    lSrc:SetText("Prices from")
    lSrc:SetPoint("TOPLEFT", ui.cbAH, "BOTTOMLEFT", 0, -14)
    ui.srcDD = W.Dropdown(inner, 130, function()
        local items = {}
        for _, it in ipairs(ns.PRICE_SOURCES) do
            local note
            if it.value == "auctionator" then note = ns.HasAuctionator() and "found" or "not installed"
            elseif it.value == "tsm" then note = ns.HasTSM() and "found" or "not installed"
            else note = ns.PriceSourceName() and ("now: " .. (ns.PriceSource() == "tsm" and "TSM" or "Auctionator")) or "none found" end
            items[#items + 1] = { value = it.value, label = it.label, note = note }
        end
        return items
    end, function(it) ns.db.settings.priceSource = it.value; ns.UpdatePriceSettings(); ns.Refresh(true) end,
    function() return ns.db.settings.priceSource or "auto" end)
    ui.srcDD:SetHeight(20)
    AtColumn(ui.srcDD, lSrc, COLW)
    W.Tooltip(ui.srcDD, "Price source", "Automatic uses whichever is installed (Auctionator if you have both). Or pick one.")
    -- which TSM price to show
    ui.tsmDD = W.Dropdown(inner, 130, function()
        local items = {}
        for _, it in ipairs(ns.TSM_VALUES) do items[#items + 1] = { value = it.value, label = it.label } end
        return items
    end, function(it) ns.db.settings.tsmValue = it.value; ns.Refresh(true) end,
    function() return ns.db.settings.tsmValue or "DBMarket" end)
    ui.tsmDD:SetHeight(20)
    -- which TSM price: its own row, same column
    ui.lTsm = W.Text(inner, 11, col.text)
    ui.lTsm:SetText("TSM price")
    ui.lTsm:SetPoint("TOPLEFT", lSrc, "BOTTOMLEFT", 0, -14)
    AtColumn(ui.tsmDD, ui.lTsm, COLW)
    W.Tooltip(ui.tsmDD, "TSM price", "Which TradeSkillMaster price to show: Market Value (TSM's usual), Minimum Buyout, Recent Value, or the region average.")
    function ns.UpdatePriceSettings()
        ui.srcDD:Refresh()
        ui.tsmDD:Refresh()
        local tsm = ns.PriceSource() == "tsm"
        ui.tsmDD:SetShown(tsm)
        ui.lTsm:SetShown(tsm)
        ui.sInv:ClearAllPoints()
        ui.sInv:SetPoint("TOPLEFT", tsm and ui.lTsm or ui.lSrcRow, "BOTTOMLEFT", 0, -20)
        local name = ns.PriceSourceName()
        ui.priceStatus:SetText(name and ("|cff7ddc8aUsing " .. name .. "|r") or "|cffffc857Auctionator or TSM not found|r")
    end

    -- whispers
    ui.lSrcRow = lSrc
    local sInv = Section(lSrc, "Customers", -20)
    ui.sInv = sInv
    ui.cbInvite = W.Check(inner, "Auto-invite when someone whispers \"inv\" or \"invite\"", function(v)
        ns.db.settings.autoInvite = v
        if ns.RefreshMini then ns.RefreshMini() end
    end)
    ui.cbInvite:SetPoint("TOPLEFT", sInv, "BOTTOMLEFT", 0, -12)
    local invNote = W.Text(inner, 9, col.dim)
    invNote:SetPoint("TOPLEFT", ui.cbInvite, "BOTTOMLEFT", 20, -4)
    invNote:SetWidth(368)
    invNote:SetJustifyH("LEFT")
    invNote:SetWordWrap(true)
    invNote:SetText("Using LayerSwap or a similar layer-hopping addon? Turn off its hosting / auto-invite while selling: it treats \"inv\" whispers as layer requests and may remove buyers from your group right away.")
    W.Tooltip(ui.cbInvite, "Auto-invite", "When a whisper is just \"inv\" or \"invite\" (any capitals), Shout Out sends that player a group invite, so customers can come straight to you. Longer whispers are left alone. If LayerSwap is hosting swaps, it already invites these whispers, so Shout Out leaves them to it.")

    -- Customer radar: buyers asking in chat for what you sell
    ui.cbRadar = W.Check(inner, "Customer radar", function(v) ns.db.settings.radar = v end)
    ui.cbRadar:SetPoint("TOPLEFT", invNote, "BOTTOMLEFT", -20, -10)
    W.Tooltip(ui.cbRadar, "Customer radar", "Watches Trade, Services, General, /say and /yell for people looking for what you sell, like \"LF enchanter\", \"LF ench Fiery\" or a linked recipe, and shows a small card with Invite, Whisper and Ignore. Only professions you really have (not previewed) and have an ad for. Capitals don't matter.")
    ui.cbRadarSound = W.Check(inner, "Sound", function(v) ns.db.settings.radarSound = v end)
    AtColumn(ui.cbRadarSound, ui.cbRadar)
    W.Tooltip(ui.cbRadarSound, "Radar sound", "Plays the whisper sound when a customer card pops up.")
    ui.cbRadarAuto = W.Check(inner, "Auto-invite exact requests", function(v) ns.db.settings.radarAuto = v end)
    ui.cbRadarAuto:SetPoint("TOPLEFT", ui.cbRadar, "BOTTOMLEFT", 0, -8)
    W.Tooltip(ui.cbRadarAuto, "Auto-invite exact requests", "Invites on its own only when the whole message is exactly a request: \"LF enchanter\", \"LF ench\", \"LF enchanter Fiery\", \"LF enchant Crusader\" (any capitals, and only for things you make). Anything longer, like \"LF enchanter to DE my stuff\", just gets the card.")
    local lWhisper = W.Text(inner, 11, col.text)
    lWhisper:SetText("Radar whisper")
    lWhisper:SetPoint("TOPLEFT", ui.cbRadarAuto, "BOTTOMLEFT", 0, -14)
    ui.radarWhisper = W.Edit(inner, COLW, 20, function(t) ns.db.settings.radarWhisper = t end, 200)
    AtColumn(ui.radarWhisper, lWhisper, COLW)
    W.Tooltip(ui.radarWhisper, "Radar whisper", "What the Whisper button on a customer card sends.")

    local resetPos = W.Button(inner, "Reset window positions", 160, 22)
    resetPos:SetPoint("BOTTOMLEFT", 16, 16)
    resetPos:SetScript("OnClick", function() SlashCmdList.SHOUTOUT("reset") end)
    local back = W.Button(inner, "Done", 80, 22, "accent")
    back:SetPoint("BOTTOMRIGHT", -16, 16)
    back:SetScript("OnClick", function() ns.ShowSettings(false) end)
    sp:SetScript("OnShow", function()
        ui.scaleRow.Show2(); ui.miniScaleRow.Show2()
        ui.cbMini:SetChecked(ns.db.settings.showMini)
        ui.cbMinimap:SetChecked(ns.db.settings.showMinimap)
        ui.themeDD:Refresh()
        for _, cb in ipairs(ui.previewChecks) do cb:SetChecked(ns.db.preview[cb.prof]) end
        ui.cbAH:SetChecked(ns.db.settings.ahPrices)
        ui.cbInvite:SetChecked(ns.db.settings.autoInvite)
        ui.cbRadar:SetChecked(ns.db.settings.radar)
        ui.cbRadarSound:SetChecked(ns.db.settings.radarSound)
        ui.cbRadarAuto:SetChecked(ns.db.settings.radarAuto)
        if not ui.radarWhisper:HasFocus() then ui.radarWhisper:SetText(ns.db.settings.radarWhisper or "") end
        ns.UpdatePriceSettings()
        ui.reloadBtn:SetShown(ns.db.settings.theme ~= W.themeKey)
    end)

    ui.gear = W.Button(title, "Settings", 74, 22)
    ui.gear:SetPoint("RIGHT", close, "LEFT", -8, 0)
    ui.gear:SetScript("OnClick", function() ns.ShowSettings(not sp:IsShown()) end)

    -- How it Works page
    ui.how = ns.CreateHowItWorks(f)
    ui.howBtn = W.Button(title, "How it Works", 96, 22)
    ui.howBtn:SetPoint("RIGHT", ui.gear, "LEFT", -6, 0)
    ui.howBtn:SetScript("OnClick", function() ns.ShowHow(not ui.how:IsShown()) end)
    list:SetScript("OnSizeChanged", function(self, w)
        self.child:SetWidth(w)
        self:UpdateThumb()
        if f:IsShown() then BuildList() end
    end)
    list.OnScrolled = RenderVisible
end

-- Pulse the post button when it's time to post again
local pulse = 0
function ns.OnTick(left)
    ns.UpdateTimer(left)
    if ns.TickMini then ns.TickMini(left) end
    if not f or not ui.post then return end
    local ready = left <= 0 and ns.lastPost > 0 and ns.db.settings.remind
    ui.post.glow:SetShown(ready)
    if ready then
        pulse = pulse + 1
        ui.post.glow:SetAlpha(pulse % 2 == 0 and 1 or 0.4)
    end
end

-- Resize the main window live while keeping the scale slider fixed on screen,
-- so the window grows/shrinks around your cursor instead of sliding away.
function ns.ScaleMainWindow(scale)
    if not f then return end
    -- anchor on the slider thumb, which is under the cursor while dragging
    local slider = ui.scaleRow and ui.scaleRow.slider
    local anchor = slider and (slider.GetThumbTexture and slider:GetThumbTexture() or slider)
    local ax, ay
    if anchor and anchor.GetCenter then ax, ay = anchor:GetCenter() end
    local left, top = f:GetLeft(), f:GetTop()
    if not (ax and left and top) or not ui.settings:IsShown() then
        f:SetScale(scale)
        return
    end
    local es = f:GetEffectiveScale()
    local sx, sy = ax * es, ay * es         -- slider position on screen
    local dx, dy = ax - left, ay - top      -- slider position inside the window
    f:SetScale(scale)
    local nes = f:GetEffectiveScale()
    local x, y = sx / nes - dx, sy / nes - dy
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    ns.db.pos.main = { "TOPLEFT", "BOTTOMLEFT", x, y }
end

function ns.ShowSettings(on)
    if not f then return end
    if on and ui.how:IsShown() then ns.ShowHow(false) end
    ui.settings:SetShown(on)
    ui.gear:SetActive(on and true or false) -- lit while Settings is open
end

function ns.ShowHow(on)
    if not f then return end
    if on then
        f:Show()
        if ui.settings:IsShown() then ns.ShowSettings(false) end
    end
    ui.how:SetShown(on)
    ui.howBtn:SetActive(on and true or false)
end

function ns.OpenSettings()
    if not f then return end
    f:Show()
    ns.ShowSettings(true)
end

-- Copy popup: addons can't write to the clipboard, so show the text
-- selected and let Ctrl+C do it.
function ns.ShowCopy(text)
    local cp = ui.copyFrame
    if not cp then
        cp = CreateFrame("Frame", "ShoutOutCopyFrame", UIParent, "BackdropTemplate")
        cp:SetSize(460, 130)
        cp:SetPoint("CENTER", 0, 120)
        cp:SetFrameStrata("DIALOG")
        W.Backdrop(cp, col.bg, col.accentD)
        tinsert(UISpecialFrames, "ShoutOutCopyFrame")
        local t = W.Text(cp, 11, col.text)
        t:SetPoint("TOPLEFT", 12, -10)
        t:SetText("Press |c" .. W.Hex(col.accent) .. "Ctrl+C|r to copy, then Esc to close")
        local x = W.Button(cp, "x", 20, 20, "ghost")
        x:SetPoint("TOPRIGHT", -6, -6)
        x:SetScript("OnClick", function() cp:Hide() end)
        cp.edit = W.Edit(cp, 436, 86, nil, 0)
        cp.edit:SetMultiLine(true)
        cp.edit:SetTextInsets(6, 6, 5, 5)
        cp.edit:SetPoint("TOPLEFT", 12, -32)
        cp.edit:SetScript("OnEscapePressed", function() cp:Hide() end)
        cp.edit:SetScript("OnKeyUp", function(self, key)
            if key == "C" and IsControlKeyDown() then C_Timer.After(0.05, function() cp:Hide() end) end
        end)
        cp.edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(cp.text); self:HighlightText() end end)
        ui.copyFrame = cp
    end
    cp.text = text
    cp:Show()
    cp.edit:SetText(text)
    cp.edit:SetFocus()
    cp.edit:HighlightText()
end

function ns.OnPosted()
    ns.Refresh()
    ns.UpdateTimer()
end
