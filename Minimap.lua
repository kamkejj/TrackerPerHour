-- The minimap button, drawn and dragged by LibDBIcon.
local ADDON, ns = ...
local broker = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")

local launcher = broker:NewDataObject(ADDON, {
  type = "launcher",
  text = ns.TITLE,
  icon = ns.ICON,
  OnClick = function(_, mouseButton)
    if mouseButton == "RightButton" then ns.Config.toggle() else ns.Window.toggle() end
  end,
  OnTooltipShow = function(tooltip)
    tooltip:AddLine(ns.TITLE)
    for _, line in ipairs(ns.lines()) do tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1) end
    tooltip:AddLine("Left-click: show or hide the tracker", 0.6, 0.6, 0.6)
    tooltip:AddLine("Right-click: settings", 0.6, 0.6, 0.6)
  end,
})

-- LibDBIcon keeps the button's position in this table and reads `hide` from it.
local function iconSettings()
  ns.db.minimap = ns.db.minimap or {}
  ns.db.minimap.hide = not ns.db.settings.showMinimap
  return ns.db.minimap
end

local registered = false
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
  icon:Register(ADDON, launcher, iconSettings())
  registered = true
end)

table.insert(ns.listeners, function()
  if not registered then return end
  if iconSettings().hide then icon:Hide(ADDON) else icon:Show(ADDON) end
end)
