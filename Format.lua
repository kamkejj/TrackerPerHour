-- Turns a session into the text the window and the minimap tooltip show. Calls no WoW API either.
local _, ns = ...
local Session = ns.Session
local Format = {}
ns.Format = Format

local COIN_LETTERS = { "g", "s", "c" }

-- units: what to write after the gold, silver and copper amounts. The game passes coin icons.
function Format.coin(copper, units)
  units = units or COIN_LETTERS
  local c = math.floor(math.abs(copper) + 0.5)
  local sign = (copper < 0 and c > 0) and "-" or ""
  local gold, silver = math.floor(c / 10000), math.floor(c / 100) % 100
  if gold > 0 then return string.format("%s%d%s %02d%s", sign, gold, units[1], silver, units[2]) end
  if silver > 0 then return string.format("%s%d%s %02d%s", sign, silver, units[2], c % 100, units[3]) end
  return string.format("%s%d%s", sign, c, units[3])
end

function Format.count(n)
  if n < 999.5 then return string.format("%d", math.floor(n + 0.5)) end
  if n < 999950 then return string.format("%.1fk", n / 1000) end
  return string.format("%.1fm", n / 1000000)
end

function Format.clock(seconds)
  local t = math.floor(seconds)
  return string.format("%d:%02d:%02d", math.floor(t / 3600), math.floor(t / 60) % 60, t % 60)
end

function Format.duration(seconds)
  local minutes = math.floor(seconds / 60)
  if minutes < 1 then return "<1m" end
  if minutes < 60 then return string.format("%dm", minutes) end
  return string.format("%dh %dm", math.floor(minutes / 60), minutes % 60)
end

local NO_VALUE = "--"

local function rateText(rate, format)
  return rate and format(rate) .. " /hr" or NO_VALUE, rate
end

local function perHourText(s, total, now, format)
  return rateText(Session.perHour(s, total, now), format)
end

-- view: { goldNet, goldGross, kills, xp = which rows to show; xpNow, xpMax = the XP bar;
--         level = the character's level; xpOff = character cannot gain XP; coinUnits = see Format.coin }
-- Returns rows of { label, rate, total }, used by both the window and the minimap tooltip.
function Format.lines(s, now, view)
  local lines = {}
  local function coin(copper) return Format.coin(copper, view.coinUnits) end
  if view.goldNet then
    lines[#lines + 1] = { "Gold (rolling)", rateText(Session.rollingPerHour(s, s.recentMoney, now), coin),
      coin(s.gained - s.spent) .. " /net" }
  end
  if view.goldGross then
    -- All coin gained this session, not a rate, so the last column says so instead of repeating it.
    lines[#lines + 1] = { "Gold gross", coin(s.gained), "session" }
  end
  if view.kills then
    lines[#lines + 1] = { "Kills", perHourText(s, s.kills, now, Format.count), tostring(s.kills) }
  end
  if view.xp and view.xpOff then
    lines[#lines + 1] = { "XP (rolling)", NO_VALUE, NO_VALUE }
  elseif view.xp then
    -- The time to level runs on the rolling rate too, so it follows the current pace.
    local text, rate = rateText(Session.rollingPerHour(s, s.recentXP, now), Format.count)
    lines[#lines + 1] = { "XP (rolling)", text, Format.count(s.xp) }
    local needed = view.xpMax - view.xpNow
    local eta = rate and rate > 0 and Format.duration(needed / rate * 3600) or NO_VALUE
    lines[#lines + 1] = { "To level " .. (view.level + 1), Format.count(needed) .. " XP", eta }
  end
  return lines
end
