-- The tracker window: a clock, one row per tracked thing, and the session buttons.
local _, ns = ...
local Session, Format = ns.Session, ns.Format
local Window = {}
ns.Window = Window

local ROW_PAD, RATE_COLUMN = 8, 90
local BUTTON_HEIGHT, BUTTON_GAP = 22, 8
local REDRAW_SECONDS = 0.25
local GRIP_SIZE = 16
local RUNNING_COLOR, STOPPED_COLOR = { 0.25, 1, 0.25 }, { 0.6, 0.6, 0.6 }
local RESET_POPUP = "TRACKERPERHOUR_RESET"

local frame

local function setShown(shown)
  ns.db.window.shown = shown
  ns.changed()
end

StaticPopupDialogs[RESET_POPUP] = {
  text = "Reset the Tracker Per Hour session? This clears the clock and all totals.",
  button1 = YES, button2 = NO,
  OnAccept = function() ns.reset() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- True while the player is dragging the resize grip, so redraws leave the size alone.
local sizing = false

-- Sets the smallest size the window may take and grows the window to it if needed. The player can
-- make the window bigger than its content with the grip; the size they chose is kept in ns.db.window.size.
local function fitSize(minWidth, minHeight)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(minWidth, minHeight)
  else
    frame:SetMinResize(minWidth, minHeight)
  end
  if sizing then return end
  local saved = ns.db.window.size
  frame:SetSize(math.max(minWidth, saved and saved[1] or 0), math.max(minHeight, saved and saved[2] or 0))
end

-- Adds the tracker's content to a new skin. skin.draw() fills it in and sizes the window to fit.
local function build(skin)
  local style, panel = skin.style, skin.panel

  local clock = skin:CreateFontString(nil, "ARTWORK", style.clockFont)
  clock:SetPoint(style.clockPoint[1], skin, style.clockPoint[1], style.clockPoint[2], style.clockPoint[3])
  local state = skin:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  state:SetPoint(style.statePoint[1], skin, style.statePoint[1], style.statePoint[2], style.statePoint[3])

  local function rowText(font, justify)
    local fontString = panel:CreateFontString(nil, "ARTWORK", font)
    fontString:SetJustifyH(justify)
    return fontString
  end

  -- One row per line, made the first time that many lines are shown.
  local rows = {}
  local function row(i)
    if rows[i] then return rows[i] end
    local y = -(ROW_PAD + (i - 1) * style.rowHeight)
    local r = {
      label = rowText(style.labelFont, "LEFT"),
      rate = rowText(style.rateFont, "LEFT"),
      total = rowText(style.totalFont, "RIGHT"),
    }
    r.label:SetPoint("TOPLEFT", panel, "TOPLEFT", ROW_PAD, y)
    r.rate:SetPoint("TOPLEFT", panel, "TOPLEFT", ROW_PAD + RATE_COLUMN, y)
    r.total:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -ROW_PAD, y)
    rows[i] = r
    return r
  end

  local function button(label, width, onClick)
    local b = CreateFrame("Button", nil, skin, "UIPanelButtonTemplate")
    b:SetSize(width, BUTTON_HEIGHT)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
  end

  local startStop = button("Start", 76, function()
    if ns.db.session.running then ns.stop() else ns.start() end
  end)
  startStop:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT", style.edge, style.edge)
  local reset = button("Reset", 76, function() StaticPopup_Show(RESET_POPUP) end)
  reset:SetPoint("LEFT", startStop, "RIGHT", 6, 0)
  local settings = button("Settings", 86, function() ns.Config.toggle() end)
  -- Leaves the bottom-right corner free for the resize grip.
  settings:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -(style.edge + GRIP_SIZE / 2), style.edge)

  -- The panel stretches down to the buttons, so a taller window gives it the extra room.
  panel:SetPoint("BOTTOM", skin, "BOTTOM", 0, style.edge + BUTTON_HEIGHT + BUTTON_GAP)

  function skin.draw()
    local session = ns.db.session
    clock:SetText(Format.clock(Session.seconds(session, GetTime())))
    state:SetText(session.running and "running" or "stopped")
    state:SetTextColor(unpack(session.running and RUNNING_COLOR or STOPPED_COLOR))
    startStop:SetText(session.running and "Stop" or "Start")

    local lines = ns.lines()
    for i = 1, math.max(#lines, #rows) do
      local line, r = lines[i], row(i)
      r.label:SetText(line and line[1] or "")
      r.rate:SetText(line and line[2] or "")
      r.total:SetText(line and "(" .. line[3] .. ")" or "")
    end
    -- With every row switched off there is nothing to put in the panel, so it goes too.
    local panelHeight = #lines > 0 and ROW_PAD * 2 + #lines * style.rowHeight or 0
    panel:SetShown(#lines > 0)
    fitSize(style.trackerWidth, style.headerHeight + panelHeight + BUTTON_GAP + BUTTON_HEIGHT + style.edge)
  end
end

frame = ns.newWindow("TrackerPerHourWindow", ns.TITLE, build, function() setShown(false) end)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetResizable(true)

local function savePosition()
  local point, _, relativePoint, x, y = frame:GetPoint()
  ns.db.window.position = { point, relativePoint, x, y }
end

-- Drag the bottom-right corner to resize. It sits above every skin and hides while the window is locked.
local grip = CreateFrame("Button", nil, frame)
grip:SetSize(GRIP_SIZE, GRIP_SIZE)
grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
grip:SetFrameLevel(frame:GetFrameLevel() + 20)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
grip:SetScript("OnMouseDown", function(_, mouseButton)
  if mouseButton ~= "LeftButton" or ns.db.settings.locked then return end
  sizing = true
  frame:StartSizing("BOTTOMRIGHT")
end)
grip:SetScript("OnMouseUp", function()
  if not sizing then return end
  frame:StopMovingOrSizing()
  sizing = false
  ns.db.window.size = { frame:GetWidth(), frame:GetHeight() }
  -- Sizing can re-anchor the window, so its position is saved again too.
  savePosition()
end)

function Window.toggle()
  setShown(not ns.db.window.shown)
end

function Window.open()
  setShown(true)
end

table.insert(ns.listeners, function()
  frame:SetShown(ns.db.window.shown)
  grip:SetShown(not ns.db.settings.locked)
  frame.refresh()
end)

local sinceDraw = 0
frame:SetScript("OnUpdate", function(_, elapsed)
  sinceDraw = sinceDraw + elapsed
  if sinceDraw < REDRAW_SECONDS then return end
  sinceDraw = 0
  frame.refresh()
end)

frame:SetScript("OnDragStart", function(self)
  if not ns.db.settings.locked then self:StartMoving() end
end)

frame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  savePosition()
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
  local position = ns.db.window.position
  if not position then return end
  self:ClearAllPoints()
  self:SetPoint(position[1], UIParent, position[2], position[3], position[4])
end)
