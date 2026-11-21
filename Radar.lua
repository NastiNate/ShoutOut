-- Shout Out: Customer radar
-- Watches public chat for people looking for what you sell ("LF enchanter",
-- "LF ench Fiery", "WTB [Enchant Weapon - Crusader]") and pops up a small
-- card with Invite / Whisper / Ignore. Optionally invites on its own, but
-- only when the whole message is exactly a request: "LF enchanter",
-- "LF ench", "LF enchanter Fiery", "LF enchant Crusader". Anything longer
-- ("LF enchanter to DE my stuff") only gets the card.

local _, ns = ...
local W = ns.W
local col = W.col

-- what people call each profession in chat
local KEYWORDS = {
    enchanting     = { "enchanter", "enchanters", "ench", "enchant", "enchants", "enchanting", "chanter" },
    leatherworking = { "leatherworker", "leatherworking", "lw" },
    blacksmithing  = { "blacksmith", "blacksmithing", "smith", "bs" },
    tailoring      = { "tailor", "tailoring" },
    alchemy        = { "alchemist", "alchemy", "alch", "transmute", "xmute" },
    engineering    = { "engineer", "engineering", "engi" },
    cooking        = { "cook", "cooking" },
    mage           = { "mage", "port", "portal", "ports", "portals" },
    warlock        = { "warlock", "lock", "summon", "summons", "summ", "summs" },
}
ns.RADAR_KEYWORDS = KEYWORDS

-- A buyer asks; a seller advertises (those are skipped).
-- Strong asks count anywhere before what they ask for ("LF ... enchanter").
-- "anyone" / "any" only count right before a profession word ("anyone ench?",
-- "any enchanters around"), since sellers say them too ("if anyone wants a pair").
local ASK = { lf = true, lfm = true, wtb = true, need = true, needs = true, needing = true }
local WEAK = { anyone = true, any = true }
local SELLER = { wts = true, lfw = true, selling = true, sell = true, wtt = true }
local SELLER_PHRASES = { "on ah", "for sale", "in stock" }

-- "|cff..|Hitem:123|h[Hide of the Wild]|h|r 5g!" -> "hide of the wild 5g"
local function Plain(msg)
    msg = tostring(msg or "")
    msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
    msg = msg:gsub("|H.-|h%[?(.-)%]?|h", "%1")
    msg = msg:lower():gsub("[^%w]+", " ")
    return (msg:gsub("^%s+", ""):gsub("%s+$", ""))
end
ns.RadarPlain = Plain

local function PlayerName() return UnitName and UnitName("player") or "" end
local function PlayerClass() local _, c = UnitClass("player"); return c end

-- professions this character really sells: has an ad for it, and really has
-- it (scanned, not just previewed), or it's your own class's ad
local function ActiveProfs()
    local hasAd = {}
    for _, ad in ipairs(ns.db.ads or {}) do hasAd[ns.ProfOf(ad)] = true end
    local out = {}
    for key in pairs(KEYWORDS) do
        local pack = ns.PROF_BY_KEY[key]
        if pack and hasAd[key] then
            if pack.class then
                if PlayerClass() == pack.class then out[key] = true end
            elseif ns.db.scannedProfs[key] and not ns.db.preview[key] then
                out[key] = true
            end
        end
    end
    return out
end

-- names of what you sell, per profession, rebuilt now and then (cheap enough,
-- but chat can be busy)
local index, indexAt = nil, 0
local function Index()
    local now = GetTime and GetTime() or 0
    if index and now - indexAt < 30 then return index end
    index, indexAt = { profs = ActiveProfs(), names = {}, ids = {} }, now
    for prof in pairs(index.profs) do
        local names = {}
        for _, e in ipairs(ns.AllEntries(prof)) do
            if not e.custom then
                local cands = { ns.ItemText(e.id), ns.DisplayName(e), e.recipe }
                if e.item then cands[#cands + 1] = ns.ItemName(e) end
                for _, c in ipairs(cands) do
                    local p = c and Plain(c)
                    if p and #p >= 3 then names[p] = names[p] or ns.DisplayName(e) end
                end
                if e.item then index.ids["item:" .. e.item] = { prof = prof, name = ns.DisplayName(e) } end
                if e.spell then index.ids["spell:" .. e.spell] = { prof = prof, name = ns.DisplayName(e) } end
            end
        end
        index.names[prof] = names
    end
    return index
end
function ns.RadarReindex() index = nil end

-- Is this a buyer asking for something you sell?
-- Returns { prof, what, exact } or nil.
function ns.RadarMatch(msg)
    local raw = tostring(msg or "")
    local plain = Plain(raw)
    if plain == "" then return end
    local words, set = {}, {}
    for w in plain:gmatch("%S+") do words[#words + 1] = w; set[w] = true end
    for w in pairs(SELLER) do if set[w] then return end end
    local padded = " " .. plain .. " "
    for _, p in ipairs(SELLER_PHRASES) do if padded:find(" " .. p .. " ", 1, true) then return end end
    -- where the asks are (word positions)
    local strong, weak = nil, {}
    for i, w in ipairs(words) do
        if ASK[w] or (w == "looking" and words[i + 1] == "for") then strong = strong or i end
        if WEAK[w] then weak[#weak + 1] = i end
    end
    if not strong and #weak == 0 then return end
    -- word position of a phrase in the message
    local function PosOf(phrase)
        local a = padded:find(" " .. phrase .. " ", 1, true)
        if not a then return end
        local n = 1
        for _ in padded:sub(1, a):gmatch("%S+") do n = n + 1 end
        return n
    end
    local function AskedBefore(pos, isProfWord)
        if strong and strong < pos then return true end
        if isProfWord then
            for _, i in ipairs(weak) do if i < pos and pos - i <= 3 then return true end end
        end
        return false
    end

    local idx = Index()
    local hit
    -- a pasted link to something you make (needs a strong ask)
    if strong then
        for kind, id in raw:gmatch("|H(%a+):(%d+)") do
            local k = (kind == "item" and "item:" or "spell:") .. id
            if (kind == "enchant" or kind == "spell" or kind == "item") and idx.ids[k] then
                hit = { prof = idx.ids[k].prof, what = idx.ids[k].name }
                break
            end
        end
    end
    -- the profession's name ("LF enchanter"), asked for before it
    if not hit then
        for prof in pairs(idx.profs) do
            for _, kw in ipairs(KEYWORDS[prof]) do
                local pos = set[kw] and PosOf(kw)
                if pos and AskedBefore(pos, true) then hit = { prof = prof, kw = kw } break end
            end
            if hit then break end
        end
    end
    -- something you make ("LF Crusader"), after a strong ask
    local function NameIn(prof)
        local best
        for name, label in pairs(idx.names[prof] or {}) do
            local pos = PosOf(name)
            if pos and AskedBefore(pos, false) and (not best or #name > #best) then best = name; hit.what = label end
        end
        return best
    end
    local matchedName
    if hit and not hit.what then matchedName = NameIn(hit.prof) end
    if not hit then
        for prof in pairs(idx.profs) do
            hit = { prof = prof }
            matchedName = NameIn(prof)
            if matchedName then break end
            hit = nil
        end
    end
    if not hit then return end

    -- exactly a request: "lf <profession>" or "lf <profession> <thing you make>"
    if hit.kw and words[1] == "lf" and words[2] == hit.kw then
        local rest = table.concat(words, " ", 3)
        if rest == "" or (matchedName and rest == matchedName) then hit.exact = true end
    end
    return hit
end

-------------------------------------------------------------------------------
-- Pop-up cards
-------------------------------------------------------------------------------
local frame, cards = nil, {}
local seen = {} -- sender -> time, so one buyer pops up once every few minutes
local COOLDOWN, LIFETIME, MAX_CARDS = 180, 90, 3

local function Short(name) return (Ambiguate and Ambiguate(name, "short")) or name end

-- true only when the invite really went out (WoW refuses full groups and
-- non-leaders without telling us, so ns.CanInvite checks first)
local function Invite(name)
    if not ns.CanInvite() then return false end
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if invite then return (pcall(invite, name)) end
end

local function Layout()
    local y = -26
    for _, c in ipairs(cards) do
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, y)
        c:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, y)
        y = y - c:GetHeight() - 6
    end
    frame:SetHeight(-y + 2)
    frame:SetShown(#cards > 0)
end

local function Remove(card)
    for i, c in ipairs(cards) do if c == card then table.remove(cards, i) break end end
    card:Hide()
    Layout()
end

local function MakeFrame()
    frame = CreateFrame("Frame", "ShoutOutRadar", UIParent, "BackdropTemplate")
    W.Backdrop(frame, col.panel, col.accent)
    frame:SetSize(340, 60)
    frame:SetFrameStrata("HIGH")
    frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    local head = W.Text(frame, 11, col.accent)
    head:SetText("CUSTOMER RADAR")
    head:SetPoint("TOPLEFT", 10, -8)
    local hint = W.Text(frame, 9, col.dim)
    hint:SetText("drag to move")
    hint:SetPoint("TOPRIGHT", -10, -9)
    W.Movable(frame, "radar") -- also puts it back where you last dragged it
    frame:Hide()
end

local function NewCard(sender, msg, hit)
    local c = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    W.Backdrop(c, col.input, col.border)
    c:SetHeight(58)
    local who = W.Text(c, 11, col.text)
    who:SetPoint("TOPLEFT", 8, -6)
    local pack = ns.Pack(hit.prof)
    who:SetText("|cffffffff" .. Short(sender) .. "|r  |cff8a8a96" .. pack.name .. (hit.what and (" · " .. hit.what) or "") .. "|r")
    local said = W.Text(c, 10, { 1, 0.75, 0.75, 1 })
    said:SetPoint("TOPLEFT", 8, -21)
    said:SetPoint("RIGHT", c, "RIGHT", -8, 0)
    said:SetText(Plain(msg) ~= "" and ns.PlainText(msg) or msg)
    local inv = W.Button(c, "Invite", 70, 18, "accent")
    inv.text:SetFont(W.FONT, 10, "")
    inv:SetPoint("BOTTOMLEFT", 8, 5)
    local wsp = W.Button(c, "Whisper", 70, 18)
    wsp.text:SetFont(W.FONT, 10, "")
    wsp:SetPoint("LEFT", inv, "RIGHT", 4, 0)
    local ign = W.Button(c, "Ignore", 60, 18, "ghost")
    ign.text:SetFont(W.FONT, 10, "")
    ign.text:SetTextColor(unpack(col.dim))
    ign:SetPoint("BOTTOMRIGHT", -6, 5)
    local function Invited()
        inv:SetLabel("Invited")
        inv:SetEnabled(false)
        inv:SetAlpha(0.6)
    end
    -- "Group full" / "Not leader" on the button while you can't invite; it
    -- stays clickable, so once there's room one click invites
    local function ShowState()
        local can, why = ns.CanInvite()
        inv:SetLabel(can and "Invite" or why)
        inv:SetAlpha(can and 1 or 0.6)
    end
    ShowState()
    inv:SetScript("OnClick", function()
        if Invite(sender) then Invited() else ShowState() end
    end)
    W.Tooltip(inv, "Invite", function()
        local can, why = ns.CanInvite()
        if can then return "Sends " .. Short(sender) .. " a group invite." end
        return (why == "Group full" and "Your group is full. Make room, then click to invite." or "Only the group leader can invite. Ask them to invite, or leave the group, then click.") .. " The Whisper button still works."
    end)
    wsp:SetScript("OnClick", function()
        local text = ns.db.settings.radarWhisper
        if not text or text == "" then return end
        local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
        pcall(send, text, "WHISPER", nil, sender)
        wsp:SetLabel("Sent")
        wsp:SetEnabled(false)
        wsp:SetAlpha(0.6)
    end)
    W.Tooltip(wsp, "Whisper them", function() return "Sends: \"" .. (ns.db.settings.radarWhisper or "") .. "\"\nChange it in Settings > Customers." end)
    ign:SetScript("OnClick", function() Remove(c) end)
    c.Invited = Invited
    C_Timer.After(LIFETIME, function() if c:IsShown() then Remove(c) end end)
    return c
end

-- one chat line from a public channel, /say or /yell
function ns.OnRadarMessage(msg, sender, channelBaseName)
    local s = ns.db and ns.db.settings
    if not s or not s.radar or type(sender) ~= "string" or sender == "" then return end
    if Short(sender) == PlayerName() then return end
    if type(channelBaseName) == "string" and channelBaseName:find("^ShoutOutTest") then return end
    local hit = ns.RadarMatch(msg)
    if not hit then return end
    local now = GetTime()
    if seen[sender] and now - seen[sender] < COOLDOWN then return end
    seen[sender] = now
    if UnitInParty and (UnitInParty(Short(sender)) or (UnitInRaid and UnitInRaid(Short(sender)))) then return end

    if not frame then MakeFrame() end
    local card = NewCard(sender, msg, hit)
    table.insert(cards, 1, card)
    while #cards > MAX_CARDS do Remove(cards[#cards]) end
    Layout()
    -- a map-ping blip, so a card never sounds like a real whisper
    if s.radarSound and PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.MAP_PING or 3175, "Master") end

    -- exactly "LF enchanter" (etc.): invite on its own, if that's turned on
    if hit.exact and s.radarAuto and not ns.OtherInviter() then
        if Invite(sender) then
            card.Invited()
            ns.Print("Invited |cffffffff" .. Short(sender) .. "|r (they said \"" .. ns.PlainText(msg) .. "\").")
        end
    end
end

ns.radarCards = cards
