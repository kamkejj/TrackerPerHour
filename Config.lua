-- The settings window: sections of options, each stored in ns.db.settings.
local ADDON, ns = ...
local Config = {}
ns.Config = Config

-- An option is { key, label } for an on/off setting.
local SECTIONS = {
  { "Tracker rows", {
    { "showGoldNet", "Show gold (rolling) row" },
    { "showGoldGross", "Show gold gross row" },
    { "showKills", "Show kills row" },
    { "showXP", "Show XP (rolling) row" },
  } },
  { "Session", {
    { "countPet", "Count pet kills as mine" },
    { "autoStart", "Start a session on login" },
  } },
  { "Window", {
    { "locked", "Lock tracker window position" },
    { "showMinimap", "Show minimap button" },
  } },
}
local STYLE_CHOICES = {
  { "Minimalist style", "minimal" },
  { "Classic WoW style", "classic" },
}
local STYLE_LABELS = { minimal = "Minimalist style", classic = "Classic WoW style" }
local PAD = 10
local HEADING_HEIGHT, ROW_HEIGHT, SECTION_GAP, INDENT = 20, 26, 10, 8
local DROPDOWN_WIDTH, DROPDOWN_HEIGHT = 190, 24

local frame

-- Adds the options to a new skin. skin.draw() ticks the boxes and sizes the window to fit.
local function build(skin)
  local style, panel = skin.style, skin.panel
  panel:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT", style.panelMargin, style.panelMargin)
  local left = style.panelMargin + PAD

  -- Everything is drawn on the panel so it sits above the panel's background.
  local checks = {}
  local function addCheck(option, y)
    local key, label = option[1], option[2]
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", skin, "TOPLEFT", left + INDENT, y)
    check.label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check.label:SetText(label)
    check:SetScript("OnClick", function(self)
      ns.db.settings[key] = self:GetChecked() and true or false
      ns.changed()
    end)
    function check.sync()
      check:SetChecked(ns.db.settings[key])
    end
    checks[#checks + 1] = check
  end

  -- y is the top of the next thing to place, measured down from the top of the window.
  local y = -(style.headerHeight + PAD)
  for i, section in ipairs(SECTIONS) do
    if i > 1 then y = y - SECTION_GAP end
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", skin, "TOPLEFT", left, y)
    heading:SetText(section[1])
    y = y - HEADING_HEIGHT
    for _, option in ipairs(section[2]) do
      addCheck(option, y)
      y = y - ROW_HEIGHT
    end
  end

  y = y - SECTION_GAP
  local styleHeading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  styleHeading:SetPoint("TOPLEFT", skin, "TOPLEFT", left, y)
  styleHeading:SetText("Style")
  y = y - HEADING_HEIGHT

  local styleDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
  styleDropdown:SetSize(DROPDOWN_WIDTH, DROPDOWN_HEIGHT)
  styleDropdown:SetPoint("TOPLEFT", skin, "TOPLEFT", left + INDENT, y)
  styleDropdown:SetupMenu(function(_, root)
    for _, choice in ipairs(STYLE_CHOICES) do
      local label, value = choice[1], choice[2]
      root:CreateRadio(label, function()
        return ns.db.settings.style == value
      end, function()
        ns.db.settings.style = value
        ns.changed()
      end)
    end
  end)
  y = y - ROW_HEIGHT

  local height = -y + PAD + style.panelMargin

  function skin.draw()
    for _, check in ipairs(checks) do check.sync() end
    styleDropdown:SetDefaultText(STYLE_LABELS[ns.db.settings.style])
    frame:SetSize(style.configWidth, height)
  end
end

frame = ns.newWindow("TrackerPerHourConfig", ADDON .. " settings", build)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
-- Escape closes any frame named in this list.
UISpecialFrames[#UISpecialFrames + 1] = "TrackerPerHourConfig"

function Config.toggle()
  frame:SetShown(not frame:IsShown())
end

table.insert(ns.listeners, frame.refresh)
