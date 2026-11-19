-- Shout Out: minimap button
--   Left-click: open/close Shout Out   Right-click: settings
--   Middle-click: hide the button   Drag: move it around the minimap

local _, ns = ...
local btn

local function Place()
    if not btn then return end
    local a = math.rad(ns.db.settings.minimapAngle or 200)
    local r = (Minimap:GetWidth() / 2) + 10
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    return math.atan(y, x)
end

function ns.UpdateMinimapButton()
    if not btn then return end
    btn:SetShown(ns.db.settings.showMinimap)
    Place()
end

function ns.CreateMinimapButton()
    if btn or not Minimap then return end
    btn = CreateFrame("Button", "ShoutOutMinimapButton", Minimap)
    ns.minimapButton = btn
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture(ns.ICON_MINIMAP)
    icon:SetTexCoord(0, 18 / 32, 0, 18 / 32) -- the 18x18 image, drawn 1:1
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.OpenSettings()
        elseif button == "MiddleButton" then
            ns.db.settings.showMinimap = false
            ns.UpdateMinimapButton()
            GameTooltip:Hide()
            ns.Print("Minimap button hidden. Bring it back in Settings or with |cffffffff/shoutout minimap|r.")
        else
            ns.Toggle()
        end
    end)

    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            ns.db.settings.minimapAngle = math.deg(Atan2(py / s - my, px / s - mx))
            Place()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Shout Out", 0.71, 0.55, 1)
        GameTooltip:AddLine("Left-click: open Shout Out", 1, 1, 1)
        GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Middle-click: hide this button", 1, 1, 1)
        GameTooltip:AddLine("Drag to move it around the minimap", 0.55, 0.55, 0.62)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.UpdateMinimapButton()
end
