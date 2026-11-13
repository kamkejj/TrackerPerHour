-- Game events, saved variables and slash commands. addons/tests/test_trackerperhour.py drives this through a stub.
local ADDON, ns = ...
local Session = ns.Session

local DEFAULT_SETTINGS = {
  showMinimap = true, locked = false,
  showGoldNet = true, showGoldGross = true, showKills = true, showXP = true,
  countPet = true, autoStart = false,
  style = "minimal",
}

-- The client's own coin icons, sized to the text they sit in.
local COIN_ICONS = {
  "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t",
  "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
  "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t",
}

-- The windows add functions here to redraw when the session or a setting changes.
ns.listeners = {}
function ns.changed()
  for _, listener in ipairs(ns.listeners) do listener() end
end

function ns.start()
  Session.start(ns.db.session, GetTime(), GetMoney(), UnitXP("player"), UnitXPMax("player"))
  ns.changed()
end

function ns.stop()
  Session.stop(ns.db.session, GetTime())
  ns.changed()
end

function ns.reset()
  Session.reset(ns.db.session)
  ns.changed()
end

-- Neither function is confirmed to exist on Forever, so a missing one means "can gain XP".
local function cannotGainXP()
  if IsXPUserDisabled and IsXPUserDisabled() then return true end
  local cap = GetMaxPlayerLevel and GetMaxPlayerLevel()
  return cap ~= nil and UnitLevel("player") >= cap
end

function ns.lines()
  local settings = ns.db.settings
  return Session.lines(ns.db.session, GetTime(), {
    goldNet = settings.showGoldNet, goldGross = settings.showGoldGross,
    kills = settings.showKills, xp = settings.showXP,
    xpNow = UnitXP("player"), xpMax = UnitXPMax("player"), level = UnitLevel("player"),
    xpOff = cannotGainXP(), coinUnits = COIN_ICONS,
  })
end

-- Comparing a secret value raises an error, so both sides are checked first.
local function sameGUID(a, b)
  return not issecretvalue(a) and not issecretvalue(b) and a ~= nil and a == b
end

local events = {}

function events.ADDON_LOADED(name)
  if name ~= ADDON then return end
  TrackerPerHourDB = TrackerPerHourDB or {}
  ns.db = TrackerPerHourDB
  ns.db.session = ns.db.session or Session.new()
  ns.db.window = ns.db.window or { shown = true }
  ns.db.settings = ns.db.settings or {}
  local settings = ns.db.settings
  -- Version 0.1.0 had one switch for both gold rows.
  if settings.showGold ~= nil then
    settings.showGoldNet, settings.showGoldGross, settings.showGold = settings.showGold, settings.showGold, nil
  end
  for key, value in pairs(DEFAULT_SETTINGS) do
    if settings[key] == nil then settings[key] = value end
  end
end

function events.PLAYER_ENTERING_WORLD(isInitialLogin)
  if isInitialLogin then
    Session.reset(ns.db.session)
    if ns.db.settings.autoStart then ns.start() end
  end
  ns.changed()
end

function events.PLAYER_MONEY()
  Session.money(ns.db.session, GetMoney())
end

function events.PLAYER_XP_UPDATE()
  Session.xp(ns.db.session, UnitXP("player"), UnitXPMax("player"))
end

function events.PARTY_KILL(attackerGUID)
  local mine = sameGUID(attackerGUID, UnitGUID("player"))
    or (ns.db.settings.countPet and sameGUID(attackerGUID, UnitGUID("pet")))
  if mine then Session.kill(ns.db.session) end
end

local frame = CreateFrame("Frame")
for event in pairs(events) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, ...) events[event](...) end)

local commands = {
  start = ns.start, stop = ns.stop, reset = ns.reset,
  open = function() ns.Window.open() end,
  config = function() ns.Config.toggle() end,
}

SLASH_TRACKERPERHOUR1 = "/tph"
SLASH_TRACKERPERHOUR2 = "/trackerperhour"
SlashCmdList.TRACKERPERHOUR = function(msg)
  local command = commands[msg:match("^%s*(.-)%s*$"):lower()]
  if command then command() else ns.Window.toggle() end
end
