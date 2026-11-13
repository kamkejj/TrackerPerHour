-- Session state and maths. Calls no WoW API, so addons/tests/test_trackerperhour.py runs it under luajit.
-- Turning a session into text is Format.lua's job.
-- A session is a plain table so it can be the saved variable itself.
local _, ns = ...
local Session = {}
ns.Session = Session

local RATE_GATE_SECONDS = 30
local ROLLING_SECONDS = 3600

function Session.reset(s)
  s.running, s.startedAt, s.banked = false, nil, 0
  s.gained, s.spent, s.kills, s.xp = 0, 0, 0, 0
  -- Each coin change as { at = session seconds, change = copper }, oldest first, for the rolling rate.
  s.recentMoney = {}
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

-- Net coin per hour over the last hour of running time, so an hour with no coin reads zero.
-- Before the session is an hour old, the rate is taken over the time it has run.
function Session.rollingPerHour(s, now)
  local seconds = Session.seconds(s, now)
  if seconds < RATE_GATE_SECONDS then return nil end
  local total = 0
  for _, entry in ipairs(s.recentMoney or {}) do
    if entry.at > seconds - ROLLING_SECONDS then total = total + entry.change end
  end
  return total * 3600 / math.min(seconds, ROLLING_SECONDS)
end

function Session.money(s, money, now)
  if not s.running then return end
  local change = money - s.lastMoney
  if change > 0 then s.gained = s.gained + change else s.spent = s.spent - change end
  s.lastMoney = money
  -- Sessions saved before the rolling rate existed have no list.
  local recent = s.recentMoney or {}
  s.recentMoney = recent
  local at = Session.seconds(s, now)
  recent[#recent + 1] = { at = at, change = change }
  while recent[1].at <= at - ROLLING_SECONDS do table.remove(recent, 1) end
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
