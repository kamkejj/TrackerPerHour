-- Session state and maths. Calls no WoW API, so addons/tests/test_trackerperhour.py runs it under luajit.
-- A session is a plain table so it can be the saved variable itself.
local _, ns = ...
local Session = {}
ns.Session = Session

local RATE_GATE_SECONDS = 30

function Session.reset(s)
  s.running, s.startedAt, s.banked = false, nil, 0
  s.gained, s.spent, s.kills, s.xp = 0, 0, 0, 0
  s.lastMoney, s.lastXP, s.lastXPMax = nil, nil, nil
  return s
end

function Session.new()
  return Session.reset({})
end

function Session.start(s, now, money, xp, xpMax)
  if s.running then return end
  s.running, s.startedAt = true, now
  s.lastMoney, s.lastXP, s.lastXPMax = money, xp, xpMax
end

function Session.stop(s, now)
  if not s.running then return end
  s.banked = Session.seconds(s, now)
  s.running, s.startedAt = false, nil
end

function Session.seconds(s, now)
  return s.banked + (s.running and now - s.startedAt or 0)
end

function Session.perHour(s, total, now)
  local seconds = Session.seconds(s, now)
  if seconds < RATE_GATE_SECONDS then return nil end
  return total * 3600 / seconds
end

function Session.money(s, money)
  if not s.running then return end
  local change = money - s.lastMoney
  if change > 0 then s.gained = s.gained + change else s.spent = s.spent - change end
  s.lastMoney = money
end

function Session.kill(s)
  if s.running then s.kills = s.kills + 1 end
end

function Session.xp(s, xp, xpMax)
  if not s.running then return end
  -- The bar's size changes on a level-up, and XP is never lost, so a smaller value means the same.
  local levelled = xpMax ~= s.lastXPMax or xp < s.lastXP
  s.xp = s.xp + (levelled and (s.lastXPMax - s.lastXP) + xp or xp - s.lastXP)
  s.lastXP, s.lastXPMax = xp, xpMax
end

local COIN_LETTERS = { "g", "s", "c" }

-- units: what to write after the gold, silver and copper amounts. The game passes coin icons.
function Session.coin(copper, units)
  units = units or COIN_LETTERS
  local c = math.floor(math.abs(copper) + 0.5)
  local sign = (copper < 0 and c > 0) and "-" or ""
  local gold, silver = math.floor(c / 10000), math.floor(c / 100) % 100
  if gold > 0 then return string.format("%s%d%s %02d%s", sign, gold, units[1], silver, units[2]) end
  if silver > 0 then return string.format("%s%d%s %02d%s", sign, silver, units[2], c % 100, units[3]) end
  return string.format("%s%d%s", sign, c, units[3])
end

function Session.count(n)
  if n < 999.5 then return string.format("%d", math.floor(n + 0.5)) end
  if n < 999950 then return string.format("%.1fk", n / 1000) end
  return string.format("%.1fm", n / 1000000)
end

function Session.clock(seconds)
  local t = math.floor(seconds)
  return string.format("%d:%02d:%02d", math.floor(t / 3600), math.floor(t / 60) % 60, t % 60)
end

function Session.duration(seconds)
  local minutes = math.floor(seconds / 60)
  if minutes < 1 then return "<1m" end
  if minutes < 60 then return string.format("%dm", minutes) end
  return string.format("%dh %dm", math.floor(minutes / 60), minutes % 60)
end

local NO_VALUE = "--"

local function perHourText(s, total, now, format)
  local rate = Session.perHour(s, total, now)
  return rate and format(rate) .. " /hr" or NO_VALUE, rate
end

-- view: { goldNet, goldGross, kills, xp = which rows to show; xpNow, xpMax = the XP bar;
--         level = the character's level; xpOff = character cannot gain XP; coinUnits = see Session.coin }
-- Returns rows of { label, rate, total }, used by both the window and the minimap tooltip.
function Session.lines(s, now, view)
  local lines = {}
  local function coin(copper) return Session.coin(copper, view.coinUnits) end
  if view.goldNet then
    local net = s.gained - s.spent
    lines[#lines + 1] = { "Gold net", perHourText(s, net, now, coin), coin(net) }
  end
  if view.goldGross then
    lines[#lines + 1] = { "Gold gross", perHourText(s, s.gained, now, coin), coin(s.gained) }
  end
  if view.kills then
    lines[#lines + 1] = { "Kills", perHourText(s, s.kills, now, Session.count), tostring(s.kills) }
  end
  if view.xp and view.xpOff then
    lines[#lines + 1] = { "XP", NO_VALUE, NO_VALUE }
  elseif view.xp then
    local text, rate = perHourText(s, s.xp, now, Session.count)
    lines[#lines + 1] = { "XP", text, Session.count(s.xp) }
    local needed = view.xpMax - view.xpNow
    local eta = rate and rate > 0 and Session.duration(needed / rate * 3600) or NO_VALUE
    lines[#lines + 1] = { "To level " .. (view.level + 1), Session.count(needed) .. " XP", eta }
  end
  return lines
end
