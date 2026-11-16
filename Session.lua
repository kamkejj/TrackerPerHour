-- Session state and maths. Calls no WoW API, so addons/tests/test_trackerperhour.py runs it under luajit.
-- Turning a session into text is Format.lua's job.
-- A session is a plain table so it can be the saved variable itself.
local _, ns = ...
local Session = {}
ns.Session = Session

local RATE_GATE_SECONDS = 30
local ROLLING_SECONDS = 3600

function Session.reset(s)
  -- firstStartedAt: when Start was first pressed, which a stop does not move. The rolling rates use it.
  s.running, s.startedAt, s.firstStartedAt, s.banked = false, nil, nil, 0
  s.gained, s.spent, s.kills, s.xp = 0, 0, 0, 0
  -- Each coin or XP change as { at = GetTime() seconds, change = amount }, oldest first, for the rolling rates.
  s.recentMoney, s.recentXP = {}, {}
  s.lastMoney, s.lastXP, s.lastXPMax = nil, nil, nil
  return s
end

function Session.new()
  return Session.reset({})
end

function Session.start(s, now, money, xp, xpMax)
  if s.running then return end
  s.running, s.startedAt = true, now
  s.firstStartedAt = s.firstStartedAt or now
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

-- Amount per hour over the last hour of real time, so an hour with nothing reads zero, and time
-- spent stopped counts as an hour with nothing. Before Start was first pressed an hour ago, the rate
-- is taken over the time since then. recent: s.recentMoney or s.recentXP.
function Session.rollingPerHour(s, recent, now)
  -- Sessions saved before firstStartedAt existed fall back to the current run's start.
  local first = s.firstStartedAt or s.startedAt
  if not first or now - first < RATE_GATE_SECONDS then return nil end
  local total = 0
  for _, entry in ipairs(recent or {}) do
    if entry.at > now - ROLLING_SECONDS then total = total + entry.change end
  end
  -- Spending more coin than came in reads zero, not a negative rate.
  return math.max(0, total * 3600 / math.min(now - first, ROLLING_SECONDS))
end

-- Adds a change to s[key] and drops the ones more than an hour old.
local function remember(s, key, change, now)
  -- Sessions saved before a rolling rate existed have no list for it.
  local recent = s[key] or {}
  s[key] = recent
  recent[#recent + 1] = { at = now, change = change }
  while recent[1].at <= now - ROLLING_SECONDS do table.remove(recent, 1) end
end

function Session.money(s, money, now)
  if not s.running then return end
  local change = money - s.lastMoney
  if change > 0 then s.gained = s.gained + change else s.spent = s.spent - change end
  s.lastMoney = money
  remember(s, "recentMoney", change, now)
end

function Session.kill(s)
  if s.running then s.kills = s.kills + 1 end
end

function Session.xp(s, xp, xpMax, now)
  if not s.running then return end
  -- The bar's size changes on a level-up, and XP is never lost, so a smaller value means the same.
  local levelled = xpMax ~= s.lastXPMax or xp < s.lastXP
  local change = levelled and (s.lastXPMax - s.lastXP) + xp or xp - s.lastXP
  s.xp = s.xp + change
  s.lastXP, s.lastXPMax = xp, xpMax
  if change > 0 then remember(s, "recentXP", change, now) end
end
