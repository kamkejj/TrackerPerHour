-- The addon's windows and the two looks they can have, chosen by ns.db.settings.style. A window is a
-- plain frame; a skin is a child that fills it and draws the look.
local _, ns = ...

ns.ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01"

-- Measurements a window needs to lay its content out inside a skin.
--   headerHeight: room the title (and the classic portrait) take at the top
--   panelMargin:  gap from the window's edge to the content panel
--   edge:         gap from the window's edge to the bottom buttons
ns.STYLES = {
  -- The client's own portrait frame, which WoW: Forever draws with its bronze rim, title bar and
  -- round portrait badge.
  classic = {
    trackerWidth = 360, configWidth = 300,
    headerHeight = 66, panelMargin = 10, edge = 12,
    rowHeight = 18,
    labelFont = "GameFontNormal", rateFont = "GameFontHighlight", totalFont = "GameFontDisableSmall",
    clockFont = "GameFontHighlightLarge",
    clockPoint = { "TOPLEFT", 64, -30 }, statePoint = { "TOPLEFT", 64, -50 },
  },
  -- A flat dark rectangle with small text.
  minimal = {
    trackerWidth = 330, configWidth = 280,
    headerHeight = 30, panelMargin = 2, edge = 10,
    rowHeight = 16,
    labelFont = "GameFontNormalSmall", rateFont = "GameFontHighlightSmall", totalFont = "GameFontDisableSmall",
    clockFont = "GameFontHighlight",
    clockPoint = { "TOPRIGHT", -32, -10 }, statePoint = { "TOPRIGHT", -100, -11 },
  },
}

local function classicSkin(window, title)
  local skin = CreateFrame("Frame", nil, window, "PortraitFrameTemplate")
  skin:SetTitle(title)
  skin:GetPortrait():SetTexture(ns.ICON)
  -- The recessed dark panel the client puts behind a window's content.
  skin.panel = CreateFrame("Frame", nil, skin, "InsetFrameTemplate")
  return skin
end

local function minimalSkin(window, title)
  local skin = CreateFrame("Frame", nil, window)
  local background = skin:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(skin)
  background:SetColorTexture(0, 0, 0, 0.8)
  local titleText = skin:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  titleText:SetPoint("TOPLEFT", skin, "TOPLEFT", 10, -10)
  titleText:SetText(title)
  skin.CloseButton = CreateFrame("Button", nil, skin, "UIPanelCloseButton")
  skin.CloseButton:SetSize(22, 22)
  skin.CloseButton:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -2, -4)
  skin.panel = CreateFrame("Frame", nil, skin)
  return skin
end

-- Returns the skin: a frame with .style (its ns.STYLES entry) and .panel (the frame to put content
-- on, anchored under the header; the caller sets its height or bottom edge).
local function newSkin(window, styleName, title, onClose)
  local skin = (styleName == "classic" and classicSkin or minimalSkin)(window, title)
  local style = ns.STYLES[styleName]
  skin.style = style
  skin:SetAllPoints(window)
  skin.panel:SetPoint("TOPLEFT", skin, "TOPLEFT", style.panelMargin, -style.headerHeight)
  skin.panel:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -style.panelMargin, -style.headerHeight)
  -- The classic template's own close button would hide only the skin.
  skin.CloseButton:SetScript("OnClick", onClose)
  -- The skin covers the window, so it takes the mouse and passes drags on to it.
  skin:EnableMouse(true)
  skin:RegisterForDrag("LeftButton")
  skin:SetScript("OnDragStart", function() window:GetScript("OnDragStart")(window) end)
  skin:SetScript("OnDragStop", function() window:GetScript("OnDragStop")(window) end)
  return skin
end

-- Returns a hidden, movable, top-level window whose look follows ns.db.settings.style.
--   build(skin): adds the window's content to a new skin and sets skin.draw(), which fills the
--                content in and sizes the window to fit. Each skin is built the first time it is used.
--   onClose:     runs when the corner close button is clicked; hides the window if left out.
-- window.refresh() draws the window in the current style, shown or not, so it is up to date when opened.
function ns.newWindow(name, title, build, onClose)
  local window = CreateFrame("Frame", name, UIParent)
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:Hide()
  onClose = onClose or function() window:Hide() end

  local skins = {}
  function window.refresh()
    local styleName = ns.db.settings.style
    if not skins[styleName] then
      skins[styleName] = newSkin(window, styleName, title, onClose)
      build(skins[styleName])
    end
    for skinName, skin in pairs(skins) do skin:SetShown(skinName == styleName) end
    skins[styleName].draw()
  end
  return window
end
