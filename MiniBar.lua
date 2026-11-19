-- Shout Out: small movable quick-post bar, so you don't need the big window open

local _, ns = ...
local W = ns.W
local col = W.col

local m

local H = 24 -- bar height

-- Drag the bar from anywhere on it, buttons included. A drag that ends on a
-- button must not also count as a click on it.
local function StartDrag() m:StartMoving(); m.dragging = true end
local function StopDrag()
    m:StopMovingOrSizing()
    local p, _, rp, x, y = m:GetPoint()
    ns.db.pos.mini = { p, rp, x, y }
    m.dragging = false
    m.dragEndedAt = GetTime()
end
local function Draggable(f)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", StartDrag)
    f:SetScript("OnDragStop", StopDrag)
end
-- wraps a click handler so it's skipped right after a drag
local function Click(fn)
    return function(...)
        if m.dragging == true or (type(m.dragEndedAt) == "number" and GetTime() - m.dragEndedAt < 0.2) then return end
        fn(...)
    end
end

-- Size the bar to its contents so there's no dead space
local function Layout()
    local postW = math.max(60, m.post.text:GetStringWidth() + 14)
    m.post:SetWidth(postW)
    -- the timer only takes room when it has something to show
    local tw = (m.timer:GetText() or "") ~= "" and (m.timer:GetStringWidth() + 4) or 0
    m.timer:SetWidth(math.max(tw, 1))
    m:SetWidth(4 + 16 + 1 + postW + 1 + 16 + tw + 2 + 26 + 18 + 4)
end

function ns.CreateMini()
    m = CreateFrame("Frame", "ShoutOutMiniBar", UIParent, "BackdropTemplate")
    ns.mini = m
    m:SetSize(200, H)
    m:SetPoint("CENTER", 0, -200)
    W.Backdrop(m, col.bg, col.winBorder)
    W.Movable(m, "mini")
    Draggable(m)

    local strip = m:CreateTexture(nil, "ARTWORK")
    strip:SetColorTexture(unpack(col.accent))
    strip:SetPoint("TOPLEFT", 1, -1 - W.radius)
    strip:SetPoint("BOTTOMLEFT", 1, 1 + W.radius)
    strip:SetWidth(2)

    local prev = W.Button(m, "<", 16, H - 4, "ghost")
    prev:SetPoint("LEFT", 4, 0)
    m.post = W.Button(m, "", 100, H - 4, "accent")
    m.post.text:SetFont(W.FONT, 11, "")
    m.post:SetPoint("LEFT", prev, "RIGHT", 1, 0)
    m.post:SetScript("OnClick", Click(function() ns.Post() end))
    local nextB = W.Button(m, ">", 16, H - 4, "ghost")
    nextB:SetPoint("LEFT", m.post, "RIGHT", 1, 0)

    local function Cycle(d)
        local n = #ns.db.ads
        ns.db.active = ((ns.db.active - 1 + d) % n) + 1
        ns.Refresh(true)
    end
    prev:SetScript("OnClick", Click(function() Cycle(-1) end))
    nextB:SetScript("OnClick", Click(function() Cycle(1) end))
    W.Tooltip(prev, "Previous ad")
    W.Tooltip(nextB, "Next ad")

    m.timer = W.Text(m, 10, col.dim)
    m.timer:SetPoint("LEFT", nextB, "RIGHT", 0, 0)
    m.timer:SetJustifyH("CENTER")

    -- gear: open the main window
    local gear = W.IconButton(m, "Interface\\Buttons\\UI-OptionsButton", 18)
    gear:SetBackdropColor(0, 0, 0, 0)
    gear:SetBackdropBorderColor(0, 0, 0, 0)
    gear.bgColor = { 0, 0, 0, 0 }
    -- auto-invite on/off (same setting as in Settings > Whispers)
    m.inv = W.Button(m, "inv", 26, H - 4, "ghost")
    m.inv.text:SetFont(W.FONT, 10, "")
    m.inv:SetPoint("LEFT", m.timer, "RIGHT", 2, 0)
    m.inv:SetScript("OnClick", Click(function()
        ns.db.settings.autoInvite = not ns.db.settings.autoInvite
        ns.Print("Auto-invite " .. (ns.db.settings.autoInvite and "|cff7ddc8aon|r: whispers of \"inv\" or \"invite\" get a group invite." or "|cffff6b6boff|r."))
        if ns.ui and ns.ui.cbInvite then ns.ui.cbInvite:SetChecked(ns.db.settings.autoInvite) end
        ns.RefreshMini()
    end))
    m.inv:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Auto-invite: " .. (ns.db.settings.autoInvite and "|cff7ddc8aon|r" or "|cffff6b6boff|r"), 1, 1, 1)
        GameTooltip:AddLine("Click to turn it " .. (ns.db.settings.autoInvite and "off" or "on") .. ". When on, anyone who whispers just \"inv\" or \"invite\" gets a group invite.", 0.8, 0.8, 0.85, true)
        local other = ns.OtherInviter()
        if other and ns.db.settings.autoInvite then
            GameTooltip:AddLine(other .. " is inviting whispers right now, so Shout Out is standing aside until it stops.", 1, 0.78, 0.34, true)
        end
        GameTooltip:AddLine("Using LayerSwap or a similar layer addon? Turn its hosting / auto-invite off while selling, or it may remove buyers from your group right away.", 0.55, 0.55, 0.62, true)
        GameTooltip:Show()
    end)
    m.inv:HookScript("OnLeave", function() GameTooltip:Hide() end)
    gear:SetPoint("LEFT", m.inv, "RIGHT", 0, 0)
    gear:SetScript("OnClick", Click(ns.Toggle))
    for _, b in ipairs({ prev, m.post, nextB, m.inv, gear }) do Draggable(b) end
    W.Tooltip(gear, "Open Shout Out", "Edit ads and wording.")

    m.post:HookScript("OnEnter", function(self)
        local msg, _, drop = ns.Build()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.ActiveAd().name, 1, 1, 1)
        GameTooltip:AddLine(ns.DisplayText(msg), 1, 0.86, 0.86, true)
        GameTooltip:AddLine(ns.MeasureLen(msg) .. " / " .. ns.MaxLen() .. " characters (" .. #msg .. "/" .. ns.MaxRaw() .. " with link code)" ..
            (#drop > 0 and ("   |cffffc857" .. #drop .. " in the next post|r") or ""), 0.55, 0.55, 0.62)
        GameTooltip:Show()
    end)
    m.post:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- flashing outline when it's time to post again
    local o = W.Ring(m, 3, col.accent, 5)
    local t = 0
    o:SetScript("OnUpdate", function(self, elapsed)
        t = t + (elapsed or 0)
        self:SetAlpha(0.25 + 0.75 * math.abs(math.sin(t * 3)))
    end)
    o:Hide()
    m.outline = o

    m:SetScale(ns.db.settings.miniScale or 1)
    m:SetShown(ns.db.settings.showMini)
    ns.RefreshMini()
end

function ns.RefreshMini()
    if not m then return end
    local ad = ns.ActiveAd()
    local name = ad.name ~= "" and ad.name or "Ad"
    if #name > 18 then name = name:sub(1, 17) .. "." end
    local blocked = ns.PostBlocked(ad)
    m.post:SetLabel((blocked and "Test only: " or (ns.IsOverflowNext(ad) and "Overflow: " or "Post: ")) .. name)
    m.post:SetAlpha(blocked and 0.6 or 1)
    m.post:SetTint(ns.AdColor(ad))
    -- lit when auto-invite is on
    local on = ns.db.settings.autoInvite and true or false
    m.inv:SetActive(on)
    -- amber while another addon (LayerSwap hosting) handles invites instead
    m.inv.text:SetTextColor(unpack((on and ns.OtherInviter()) and col.warn or (on and col.text or col.dim)))
    Layout()
end

local lastTimer
function ns.TickMini(left)
    if not m or not m:IsShown() then return end
    local ready = left <= 0 and ns.lastPost > 0
    local text = left > 0 and ns.FormatTime(left) or (ns.lastPost > 0 and "now" or "")
    m.outline:SetShown(ready and ns.db.settings.remind and ns.db.settings.flash and true or false)
    if text == lastTimer then return end -- unchanged: skip the relayout
    local resize = #text ~= #(lastTimer or "")
    lastTimer = text
    m.timer:SetText(text)
    m.timer:SetTextColor(unpack(left > 0 and col.dim or col.good))
    if resize then Layout() end
end
