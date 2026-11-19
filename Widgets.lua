-- Shout Out: small flat widget kit (no Blizzard templates beyond BackdropTemplate,
-- so it keeps working across client UI changes)

local ADDON, ns = ...
local W = {}
ns.W = W

local FLAT = "Interface\\Buttons\\WHITE8x8"
local CIRCLE = "Interface\\AddOns\\" .. ADDON .. "\\Media\\circle"
W.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- Themes. W.col is filled in place by W.ApplyTheme (other files keep a
-- reference to the same table), so pick the theme before building any UI.
W.THEMES = {
    glass = { -- Arcane Glass: soft, teal, rounded (all solid, nothing see-through)
        name = "Arcane Glass",
        bg       = { 0.059, 0.102, 0.129, 1 },
        panel    = { 0.092, 0.133, 0.160, 1 },
        raised   = { 0.125, 0.165, 0.190, 1 },
        hover    = { 0.172, 0.210, 0.234, 1 },
        border   = { 0.165, 0.205, 0.228, 1 },
        winBorder = { 0.146, 0.320, 0.325, 1 },
        input    = { 0.060, 0.086, 0.104, 1 },
        chat     = { 0.051, 0.073, 0.088, 1 },
        menu     = { 0.060, 0.100, 0.120, 1 },
        accent   = { 0.37, 0.88, 0.83, 1 },
        accentD  = { 0.11, 0.31, 0.30, 1 },
        text     = { 0.90, 0.96, 0.96, 1 },
        dim      = { 0.58, 0.67, 0.69, 1 },
        radius = 6, radiusLg = 10,
    },
    violet = { -- Midnight Violet: the original flat look
        name = "Midnight Violet",
        bg       = { 0.055, 0.055, 0.07, 0.97 },
        panel    = { 0.09, 0.09, 0.115, 1 },
        raised   = { 0.13, 0.13, 0.165, 1 },
        hover    = { 0.18, 0.18, 0.225, 1 },
        border   = { 0.22, 0.22, 0.28, 1 },
        winBorder = { 0, 0, 0, 1 },
        input    = { 0.04, 0.04, 0.05, 1 },
        chat     = { 0.03, 0.03, 0.04, 0.92 },
        menu     = { 0.07, 0.07, 0.09, 0.98 },
        accent   = { 0.71, 0.55, 1.00, 1 },
        accentD  = { 0.38, 0.26, 0.62, 1 },
        text     = { 0.92, 0.92, 0.95, 1 },
        dim      = { 0.55, 0.55, 0.62, 1 },
        radius = 0, radiusLg = 0,
    },
}
W.THEME_ORDER = { "glass", "violet" }

W.col = {
    gold    = { 1.00, 0.80, 0.30, 1 },
    good    = { 0.49, 0.86, 0.54, 1 },
    warn    = { 1.00, 0.78, 0.34, 1 },
    bad     = { 1.00, 0.42, 0.42, 1 },
}

function W.ApplyTheme(key)
    local t = W.THEMES[key] or W.THEMES.glass
    for k, v in pairs(t) do
        if type(v) == "table" then W.col[k] = { v[1], v[2], v[3], v[4] } end
    end
    W.radius, W.radiusLg, W.themeKey = t.radius, t.radiusLg, W.THEMES[key] and key or "glass"
    if ns.C then ns.C.accent = W.Hex(W.col.accent) end
end

-- "ffRRGGBB" for |c color codes
function W.Hex(c)
    return string.format("ff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local col = W.col
W.ApplyTheme("glass")

-- A rounded rectangle from 7 non-overlapping pieces: 4 quarter circles and
-- 3 bands, so translucent colors stay even.
local function RoundShape(f, inset, r, sublevel)
    local s = {}
    local function T(tex)
        local t = f:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        t:SetTexture(tex)
        s[#s + 1] = t
        return t
    end
    local corners = {
        { "TOPLEFT", 0, 0.5, 0, 0.5, 1, -1 }, { "TOPRIGHT", 0.5, 1, 0, 0.5, -1, -1 },
        { "BOTTOMLEFT", 0, 0.5, 0.5, 1, 1, 1 }, { "BOTTOMRIGHT", 0.5, 1, 0.5, 1, -1, 1 },
    }
    for _, c in ipairs(corners) do
        local t = T(CIRCLE)
        t:SetTexCoord(c[2], c[3], c[4], c[5])
        t:SetSize(r, r)
        t:SetPoint(c[1], f, c[1], c[6] * inset, c[7] * inset)
    end
    local top = T(FLAT)
    top:SetPoint("TOPLEFT", inset + r, -inset); top:SetPoint("TOPRIGHT", -inset - r, -inset); top:SetHeight(r)
    local bot = T(FLAT)
    bot:SetPoint("BOTTOMLEFT", inset + r, inset); bot:SetPoint("BOTTOMRIGHT", -inset - r, inset); bot:SetHeight(r)
    local mid = T(FLAT)
    mid:SetPoint("TOPLEFT", inset, -inset - r); mid:SetPoint("BOTTOMRIGHT", -inset, inset + r)
    function s.Color(_, cr, cg, cb, ca) for _, t in ipairs(s) do t:SetVertexColor(cr, cg, cb, ca or 1) end end
    return s
end

-- Background + 1px border. Rounded when the theme has a radius; the frame's
-- SetBackdropColor / SetBackdropBorderColor keep working either way.
-- radius: nil = theme default, "lg" = window size, or a number.
function W.Backdrop(f, bg, border, radius)
    local r = radius == "lg" and W.radiusLg or radius or W.radius
    if not r or r <= 0 then
        if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
        f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
        f:SetBackdropColor(unpack(bg or col.panel))
        f:SetBackdropBorderColor(unpack(border or col.border))
        return
    end
    if f.SetBackdrop then pcall(f.SetBackdrop, f, nil) end
    local edge = RoundShape(f, 0, r, -8)
    local fill = RoundShape(f, 1, math.max(r - 1, 1), -7)
    f.SetBackdropColor = function(_, cr, cg, cb, ca) fill:Color(cr, cg, cb, ca) end
    f.SetBackdropBorderColor = function(_, cr, cg, cb, ca) edge:Color(cr, cg, cb, ca) end
    f:SetBackdropColor(unpack(bg or col.panel))
    f:SetBackdropBorderColor(unpack(border or col.border))
end

-- An outline ring around a frame (rounded to match the theme). Returns a
-- frame you can Show/Hide/SetAlpha. Two 1px rings make it 2px thick.
function W.Ring(target, offset, color, levelBoost)
    local holder = CreateFrame("Frame", nil, target)
    holder:SetPoint("TOPLEFT", -offset, offset)
    holder:SetPoint("BOTTOMRIGHT", offset, -offset)
    holder:SetFrameLevel(target:GetFrameLevel() + (levelBoost or 0))
    local r = (W.radius > 0) and (W.radius + offset) or 0
    for i = 0, 1 do
        local ring = CreateFrame("Frame", nil, holder)
        ring:SetPoint("TOPLEFT", i, -i)
        ring:SetPoint("BOTTOMRIGHT", -i, i)
        W.Backdrop(ring, { 0, 0, 0, 0 }, color, r > 0 and (r - i) or 0)
    end
    return holder
end

function W.Text(parent, size, color, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(W.FONT, size or 12, flags or "")
    fs:SetTextColor(unpack(color or col.text))
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

function W.Panel(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    W.Backdrop(f, col.panel, col.border)
    return f
end

-- title / body can be functions, for tooltips that depend on the current ad
function W.Tooltip(owner, title, body)
    owner:HookScript("OnEnter", function(self)
        local t = type(title) == "function" and title(self) or title
        local b = type(body) == "function" and body(self) or body
        if not t then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(t, 1, 1, 1)
        if b then GameTooltip:AddLine(b, 0.8, 0.8, 0.85, true) end
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Flat button. style: "normal" | "accent" | "ghost"
function W.Button(parent, label, width, height, style)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 80, height or 22)
    local bg, bgH, bd = col.raised, col.hover, col.border
    if style == "accent" then bg, bgH, bd = col.accentD, { 0.47, 0.33, 0.76, 1 }, col.accent end
    if style == "ghost" then bg, bgH, bd = { 0, 0, 0, 0 }, col.raised, { 0, 0, 0, 0 } end
    W.Backdrop(b, bg, bd)
    b.text = W.Text(b, style == "accent" and 13 or 11, col.text, style == "accent" and "" or "")
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label or "")
    b.bgColor, b.bdColor = bg, bd
    b:SetScript("OnEnter", function(self) if self:IsEnabled() then self:SetBackdropColor(unpack(type(self.hoverColor) == "table" and self.hoverColor or bgH)) end end)
    -- recolor a button around one color (used for ad colors)
    function b:SetTint(c)
        self.bgColor = { c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1 }
        self.hoverColor = { c[1] * 0.7, c[2] * 0.7, c[3] * 0.7, 1 }
        self:SetBackdropColor(unpack(self.bgColor))
        self:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    end
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(self.bgColor)) end)
    -- highlighted "selected" state, used by filter toggles
    function b:SetActive(on)
        self.bgColor = on and col.accentD or bg
        self:SetBackdropColor(unpack(self.bgColor))
        self:SetBackdropBorderColor(unpack(on and col.accent or bd))
    end
    -- pressed look: nudge the label 1px down-right, keeping however it's anchored
    local pressedPts
    b:SetScript("OnMouseDown", function(self)
        if not self:IsEnabled() or pressedPts then return end
        local pts = {}
        for i = 1, self.text:GetNumPoints() do pts[i] = { self.text:GetPoint(i) } end
        pressedPts = pts
        self.text:ClearAllPoints()
        for _, p in ipairs(pts) do self.text:SetPoint(p[1], p[2], p[3], (p[4] or 0) + 1, (p[5] or 0) - 1) end
    end)
    b:SetScript("OnMouseUp", function(self)
        local pts = pressedPts
        if not pts then return end
        pressedPts = nil
        self.text:ClearAllPoints()
        for _, p in ipairs(pts) do self.text:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    end)
    hooksecurefunc(b, "SetEnabled", function(self, on) self.text:SetAlpha(on and 1 or 0.4) end)
    function b:SetLabel(t) self.text:SetText(t) end
    return b
end

-- Plain action button helper (label + click)
function W.ConfirmClick(b, label, onClick)
    b:SetLabel(label)
    b:SetScript("OnClick", function() onClick() end)
end

-- Square button showing a texture (used for the raid icon inserts)
function W.IconButton(parent, texture, size)
    local b = W.Button(parent, "", size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(texture)
    b.icon:SetPoint("TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    return b
end

-- Square checkbox with a label. onChange(checked)
function W.Check(parent, label, onChange)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(14, 14)
    local box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    box:SetAllPoints()
    W.Backdrop(box, col.input, col.border, math.min(W.radius, 3))
    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(FLAT)
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    fill:SetVertexColor(unpack(col.accent))
    b.fill = fill
    if label then
        b.label = W.Text(b, 11, col.text)
        b.label:SetPoint("LEFT", b, "RIGHT", 6, 0)
        b.label:SetText(label)
        b:SetHitRectInsets(0, -(b.label:GetStringWidth() + 8), 0, 0)
    end
    b:SetScript("OnEnter", function() box:SetBackdropBorderColor(unpack(col.accent)) end)
    b:SetScript("OnLeave", function() box:SetBackdropBorderColor(unpack(col.border)) end)
    function b:SetChecked(on) self.checked = on and true or false; fill:SetShown(self.checked) end
    function b:GetChecked() return self.checked end
    b:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        if onChange then onChange(self.checked) end
    end)
    b:SetChecked(false)
    return b
end

-- Single-line edit box. onChange(text) fires as the user types.
function W.Edit(parent, width, height, onChange, maxLetters)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(width or 120, height or 20)
    W.Backdrop(e, col.input, col.border)
    e:SetFont(W.FONT, 11, "")
    e:SetTextColor(unpack(col.text))
    e:SetTextInsets(6, 6, 0, 0)
    e:SetAutoFocus(false)
    if maxLetters then e:SetMaxLetters(maxLetters) end
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(col.accent)) end)
    e:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpack(col.border))
        -- a long one-line entry shows its start again, not its end
        if self.IsMultiLine and self:IsMultiLine() ~= true then self:SetCursorPosition(0) end
    end)
    e:SetScript("OnTextChanged", function(self, user)
        if user and onChange then onChange(self:GetText()) end
    end)
    return e
end

-- Scroll area with mouse wheel and a slim draggable thumb.
function W.Scroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf.child = child

    local track = CreateFrame("Frame", nil, parent)
    track:SetWidth(4)
    track:SetPoint("TOPLEFT", sf, "TOPRIGHT", 3, 0)
    track:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 3, 0)
    local tbg = track:CreateTexture(nil, "BACKGROUND")
    tbg:SetAllPoints()
    tbg:SetColorTexture(1, 1, 1, 0.04)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetWidth(4)
    local tt = thumb:CreateTexture(nil, "ARTWORK")
    tt:SetAllPoints()
    tt:SetColorTexture(col.accent[1], col.accent[2], col.accent[3], 0.6)
    thumb:EnableMouse(true)

    local function Max() return math.max(0, child:GetHeight() - sf:GetHeight()) end
    function sf:UpdateThumb()
        local max = Max()
        local h = sf:GetHeight()
        if max <= 0 or h <= 0 then thumb:Hide() return end
        thumb:Show()
        local th = math.max(20, h * h / child:GetHeight())
        thumb:SetHeight(th)
        local y = (sf:GetVerticalScroll() / max) * (h - th)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -y)
    end
    function sf:ScrollTo(v)
        sf:SetVerticalScroll(math.min(math.max(0, v), Max()))
        sf:UpdateThumb()
        if sf.OnScrolled then sf.OnScrolled() end
    end
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d) self:ScrollTo(self:GetVerticalScroll() - d * 44) end)
    sf:SetScript("OnSizeChanged", function(self, w) child:SetWidth(w); self:UpdateThumb() end)

    thumb:SetScript("OnMouseDown", function(self)
        local _, cy = GetCursorPosition()
        self.startY, self.startScroll = cy / UIParent:GetEffectiveScale(), sf:GetVerticalScroll()
        self:SetScript("OnUpdate", function(s)
            local _, y = GetCursorPosition()
            y = y / UIParent:GetEffectiveScale()
            local range = sf:GetHeight() - s:GetHeight()
            if range > 0 then sf:ScrollTo(s.startScroll + (s.startY - y) / range * Max()) end
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    return sf
end

-- Saves and restores a frame position under db.pos[key]
function W.Movable(f, key, handle)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    handle = handle or f
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() f:StartMoving() end)
    handle:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local p, _, rp, x, y = f:GetPoint()
        ns.db.pos[key] = { p, rp, x, y }
    end)
    local saved = ns.db.pos[key]
    if saved then
        f:ClearAllPoints()
        f:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    end
end

-- Dropdown. getItems() returns { {value=, label=, icon=, note=}, ... };
-- onSelect(item) fires on pick; getValue() returns the current value.
local openMenu
local catcher -- full-screen click catcher that closes an open menu
local function CloseMenu()
    if openMenu then openMenu:Hide(); openMenu = nil end
    if catcher then catcher:Hide() end
end
W.CloseMenu = CloseMenu

function W.Dropdown(parent, width, getItems, onSelect, getValue)
    local d = W.Button(parent, "", width, 22)
    d.text:ClearAllPoints()
    d.text:SetPoint("LEFT", 8, 0)
    d.text:SetPoint("RIGHT", -20, 0)
    d.text:SetJustifyH("LEFT")
    local arrow = W.Text(d, 10, col.dim)
    arrow:SetPoint("RIGHT", -7, 0)
    arrow:SetText("v")

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    W.Backdrop(menu, col.menu, col.accentD)
    menu:Hide()
    menu.rows = {}

    local function Build()
        local items = getItems() or {}
        local cur = getValue and getValue()
        for _, r in ipairs(menu.rows) do r:Hide() end
        local h, wide = 4, 0
        for i, it in ipairs(items) do
            local r = menu.rows[i]
            if not r then
                r = CreateFrame("Button", nil, menu)
                r:SetHeight(20)
                r.hl = r:CreateTexture(nil, "BACKGROUND")
                r.hl:SetAllPoints()
                r.hl:SetColorTexture(col.accent[1], col.accent[2], col.accent[3], 0.18)
                r.hl:Hide()
                r.mark = r:CreateTexture(nil, "ARTWORK")
                r.mark:SetColorTexture(unpack(col.accent))
                r.mark:SetSize(2, 14)
                r.mark:SetPoint("LEFT", 2, 0)
                r.icon = r:CreateTexture(nil, "ARTWORK")
                r.icon:SetSize(14, 14)
                r.icon:SetPoint("LEFT", 10, 0)
                r.label = W.Text(r, 11, col.text)
                r.note = W.Text(r, 9, col.dim)
                r.note:SetPoint("RIGHT", -8, 0)
                r:SetScript("OnEnter", function(self) self.hl:Show() end)
                r:SetScript("OnLeave", function(self) self.hl:Hide() end)
                r:SetScript("OnClick", function(self)
                    CloseMenu()
                    onSelect(self.item)
                    d:Refresh()
                end)
                menu.rows[i] = r
            end
            r.item = it
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 2, -h)
            r:SetPoint("TOPRIGHT", -2, -h)
            r.label:ClearAllPoints()
            if it.icon then
                r.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. it.icon)
                r.icon:Show()
                r.label:SetPoint("LEFT", 30, 0)
            else
                r.icon:Hide()
                r.label:SetPoint("LEFT", 10, 0)
            end
            r.note:SetText(it.note or "")
            -- long names end in "..." instead of running out of the menu
            r.label:SetPoint("RIGHT", (it.note and it.note ~= "") and r.note or r, (it.note and it.note ~= "") and "LEFT" or "RIGHT", -6, 0)
            r.label:SetJustifyH("LEFT")
            r.label:SetWordWrap(false)
            r.label:SetText(it.label)
            r.mark:SetShown(cur ~= nil and it.value == cur)
            r:Show()
            h = h + 20
            -- widen the menu to fit its longest row, so names aren't cut off
            local need = (it.icon and 30 or 10) + (r.label:GetStringWidth() or 0) + 6
                + ((it.note and it.note ~= "") and ((r.note:GetStringWidth() or 0) + 14) or 8) + 4
            if type(need) == "number" and need > wide then wide = need end
        end
        if #items == 0 then h = h + 20 end
        menu:SetSize(math.min(math.max(width, 160, math.ceil(wide)), 360), h + 4)
    end

    d:SetScript("OnClick", function()
        if openMenu == menu then CloseMenu() return end
        CloseMenu()
        Build()
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -2)
        if not catcher then
            catcher = CreateFrame("Button", nil, UIParent)
            catcher:SetAllPoints(UIParent)
            catcher:SetFrameStrata("FULLSCREEN")
            catcher:SetScript("OnClick", CloseMenu)
        end
        catcher:Show()
        menu:Show()
        openMenu = menu
    end)
    d:HookScript("OnHide", function() if openMenu == menu then CloseMenu() end end)

    function d:Refresh()
        local cur = getValue and getValue()
        local label
        for _, it in ipairs(getItems() or {}) do
            if it.value == cur then
                label = it.icon and ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. it.icon .. ":12|t  " .. it.label) or it.label
            end
        end
        self:SetLabel(label or (self.emptyText or "Choose..."))
    end
    return d
end

-- Flat horizontal slider. onChange(value, final): final is true on release.
function W.Slider(parent, width, minV, maxV, step, onChange)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(width, 14)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouse(true)
    s:SetHitRectInsets(0, 0, -6, -6)
    -- track
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.04, 0.04, 0.05, 1)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    s.fill = s:CreateTexture(nil, "BORDER")
    s.fill:SetColorTexture(col.accentD[1], col.accentD[2], col.accentD[3], 1)
    s.fill:SetPoint("LEFT")
    s.fill:SetHeight(4)
    -- thumb
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(unpack(col.accent))
    thumb:SetSize(8, 14)
    s:SetThumbTexture(thumb)

    local quiet = false
    local function UpdateFill(v)
        local frac = (v - minV) / (maxV - minV)
        s.fill:SetWidth(math.max(1, width * frac))
    end
    s:SetScript("OnValueChanged", function(self, v, user)
        v = math.floor(v / step + 0.5) * step
        UpdateFill(v)
        if not quiet and user ~= false and onChange then onChange(v, false) end
    end)
    s:SetScript("OnMouseUp", function(self)
        if onChange then onChange(math.floor(self:GetValue() / step + 0.5) * step, true) end
    end)
    s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
    s:EnableMouseWheel(true)
    function s:SetValueQuiet(v)
        quiet = true
        self:SetValue(v)
        UpdateFill(v)
        quiet = false
    end
    return s
end
