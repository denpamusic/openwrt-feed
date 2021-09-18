#!/usr/bin/env lua

local uci = require "uci"
local CgMiner = require "cgminer"
local LCDproc = require "lcdproc"

local curs = uci.cursor()

local function rpad(s, l, c)
  return string.rep((c or " "), l - #s) .. s
end

local function round(n, p)
  return string.format("%." .. (p or 0) .. "f", n)
end

local function ucwords(s)
  local ret = s:gsub("(%a)([%w_']*)", function (f, r)
    return f:upper() .. r:lower()
  end)
  return ret
end

local function client_name()
  return curs:get("lcdproc", "cgminer", "name") or "CGMiner"
end

local function lcdproc_config()
  return
    curs:get("lcdproc", "lcdproc", "host") or "localhost",
    curs:get("lcdproc", "lcdproc", "port") or 13666
end

local function cgminer_config()
  return
    curs:get("lcdproc", "cgminer", "host") or "localhost",
    curs:get("lcdproc", "cgminer", "port") or 4028
end

local function screens_config()
  local t = {}
  curs:foreach("lcdproc", "screen", function (s)
    if s.client == "cgminer" then
      t[s[".name"]] = s
    end
  end)
  return t
end

local function screen_total(s)
  return {
    string.format("Now: %s Gh/s", rpad(round(s[2]["GHS 5s"], 1), 10)),
    string.format("Avg: %s Gh/s", rpad(round(s[2]["GHS av"], 1), 10)),
    string.format("Ideal: %s Gh/s", rpad(round(s[2]["total_rateideal"], 1), 8))
  }
end

local function screen_fans(s, f)
  return {
    string.format("Front: %s RPM", rpad(round(s[2]["fan6"], 0), 9)),
    string.format("Back: %s RPM", rpad(round(s[2]["fan5"], 0), 10)),
    string.format("Duty: %s %%", rpad(round(f[1]["Output"], 0), 12))
  }
end

local function screen_rates(s)
  local t = {}
  for c=6,8 do
    local rate = rpad(round(s[2]["chain_rate" .. c], 1), 6)
    table.insert(t, string.format("Chain %i: %s Gh/s", c, rate))
  end
  return t
end

local function screen_temps(s)
  local t = {}
  for c=6,8 do
    local temp = rpad(round(s[2]["temp2_" .. c], 1), 9)
    table.insert(t, string.format("Chain %i: %s C", c, temp))
  end
  return t
end

local function cgminer_stats()
  local cgminer = CgMiner.new(cgminer_config())
  local resp = cgminer:request("stats+fanctrl")
  cgminer:close()
  if resp then
    return {
      total = screen_total(resp["stats"]),
      fans  = screen_fans(resp["stats"], resp["fanctrl"]),
      rates = screen_rates(resp["stats"]),
      temps = screen_temps(resp["stats"])
    }
  end
end

local function setup_screens(lcd, screens, stats)
  for k, v in pairs(screens) do
    local screen = lcd:add_screen(k)
    screen:set_duration((v.duration or 3) * 8)
    screen:set_heartbeat(v.heartbeat or "open")
    screen:set_backlight(v.backlight or "open")
    screen:set_priority(v.priority or "info")
    screen:add_title("title", ucwords(k) .. ": " .. client_name())
    screen:add_string("one", 1, 2, stats[k][1])
    screen:add_string("two", 1, 3, stats[k][2])
    screen:add_string("three", 1, 4, stats[k][3])
  end
end

local stats = cgminer_stats()
local lcd = LCDproc(lcdproc_config())
lcd:set_name(client_name())
setup_screens(lcd, screens_config(), stats)

local listen = nil
lcd:on_listen(function (s) listen = s end)
lcd:on_ignore(function () listen = nil end)

while true do
  lcd:poll()

  LCDproc.every("5s", function () stats = cgminer_stats() end)

  if listen then
    listen.widgets.one:set_text(stats[listen.id][1])
    listen.widgets.two:set_text(stats[listen.id][2])
    listen.widgets.three:set_text(stats[listen.id][3])
  end
end

lcd:close()
