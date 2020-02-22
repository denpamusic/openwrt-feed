#!/usr/bin/env lua

local uci = require "uci"
local nixio = require "nixio"
local CgMiner = require "cgminer"
local LcdProc = require "lcdproc"

-- get uci cursor
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

local function etos(t)
	return t * 8
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
  local dt = {}
  curs:foreach("lcdproc", "screen", function(s)
    if s["client"] == "cgminer" then
      dt[s[".name"]] = {
        duration = etos(s["duration"] or 3),
        heartbeat = s["heartbeat"] or "open",
        backlight = s["backlight"] or "open",
        priority = s["priority"] or "info"
      }
    end
  end)
  return dt
end

local function cgminer_stats()
  local dt = { ["total"] = {}, ["rates"] = {}, ["temps"] = {}, ["fans"] = {} }
  local cgminer = CgMiner.new(cgminer_config())
  cgminer:send("stats+fanctrl")
  local stats = cgminer:receive()
  if stats and stats['stats'][2] then
    local s = stats['stats'][2]
    dt["total"] = {
       string.format("Now: %s Gh/s", rpad(round(s["GHS 5s"], 1), 10)),
       string.format("Avg: %s Gh/s", rpad(round(s["GHS av"], 1), 10)),
       string.format("Ideal: %s Gh/s", rpad(round(s["total_rateideal"], 1), 8))
    }
    dt["fans"] = {
      string.format("Front: %s RPM", rpad(round(s["fan6"], 0), 9)),
      string.format("Back: %s RPM", rpad(round(s["fan5"], 0), 10)),
      string.format("Duty: %s %%", rpad(round(stats["fanctrl"][1]["Output"], 0), 12))
    }
    for chain=6,8 do
      local rate = rpad(round(s["chain_rate" .. chain], 1), 6)
      local temp = rpad(round(s["temp2_" .. chain], 2), 9)
      dt["rates"][chain-5] = string.format("Chain %u: %s Gh/s", chain, rate)
      dt["temps"][chain-5] = string.format("Chain %u: %s C", chain, temp)
    end
  end
  cgminer:close()
  return dt
end

local function update_screen(lcdproc, s, dt)
  if dt[s] then
    lcdproc:widget_set(s, "S2", "1 2 {" .. dt[s][1] .. "}")
    lcdproc:widget_set(s, "S3", "1 3 {" .. dt[s][2] .. "}")
    lcdproc:widget_set(s, "S4", "1 4 {" .. dt[s][3] .. "}")
  end
end

local function setup_screens(lcdproc, screens, dt)
  for s, v in pairs(screens) do
    lcdproc:screen_add(s)
    lcdproc:screen_set(s, v)
    lcdproc:widget_add(s, "S1", "title")
    lcdproc:widget_add(s, "S2", "string")
    lcdproc:widget_add(s, "S3", "string")
    lcdproc:widget_add(s, "S4", "string")
    lcdproc:widget_set(s, "S1", string.format("{%s: %s}", ucwords(s), client_name()))
    update_screen(lcdproc, s, dt)
  end
end

local lcdproc = LcdProc.new(lcdproc_config())
lcdproc:client_set({ name = client_name() })

local stats = cgminer_stats()
local screens = screens_config()
setup_screens(lcdproc, screens, stats)

local active = nil
while true do
  local line = lcdproc:receive()

  if line and line ~= "success" then
    active = string.match(line, "listen (%a+)") or active
    local ignore = string.match(line, "ignore (%a+)")
    if ignore and ignore == active then
      -- update stats on screen hide
      stats = cgminer_stats()
      active = nil
    end

    if active then
      update_screen(lcdproc, active, stats)
    end
  end

  nixio.nanosleep(0, 20000000)
end

lcdproc:close()
