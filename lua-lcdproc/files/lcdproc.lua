local socket = require "socket"

local function trim(s)
  return s:match "^%s*(.-)%s*$"
end

local LcdProc = { sock = nil, server = {}, lcd = {} }

LcdProc.__index = LcdProc

function LcdProc.new(host, port)
  port = port or 13666
  local self = setmetatable({}, LcdProc)
  self.sock = assert(socket.tcp())
  self.sock:settimeout(3)
  local ret, err = self.sock:connect(host, port)
  if ret then
    self:hello()
    return self
  end
  print('Sock Error: ' .. err)
end

function LcdProc:send(str)
  if self.sock then
    self.sock:send(str .. "\n")
  end
end

function LcdProc:receive()
  if self.sock then
    local ret = self.sock:receive("*l")
    if not ret then
      return false
    end
    return trim(ret)
  end
end

function LcdProc:hello()
  self:send("hello")
  local ret = self:receive()
  if ret then
    -- set non-blocking mode
    self.sock:settimeout(0)
    self.server = {
      version = string.match(ret, "LCDproc ([0-9\.]+)"),
      protocol = string.match(ret, "protocol ([0-9\.]+)")
    }
    self.lcd = {
      wid = string.match(ret, " wid ([0-9]+)"),
      hgt = string.match(ret, " hgt ([0-9]+)"),
      cellwid = string.match(ret, " cellwid ([0-9]+)"),
      cellhgt = string.match(ret, " cellhgt ([0-9]+)")
    }
  end
end

function LcdProc:attributes_str(attrs)
  local str = ""
  for k, v in pairs(attrs) do
    str = str .. " -" .. k .. ' "' .. v .. '"'
  end
  -- remove first space an return string
  return string.sub(str, 2, #str)
end

function LcdProc:client_set(attrs)
  self:send("client_set " .. self:attributes_str(attrs))
end

function LcdProc:screen_add(new_screen_id)
  self:send("screen_add " .. new_screen_id)
end

function LcdProc:screen_del(screen_id)
  self:send("screen_del " .. screen_id)
end

function LcdProc:screen_set(screen_id, attrs)
  self:send("screen_set " .. screen_id .. " " .. self:attributes_str(attrs))
end

function LcdProc:widget_add(screen_id, new_widget_id, widgettype, frame_id)
  local str = "widget_add " .. screen_id .. " " .. new_widget_id .. " " .. widgettype
  if frame_id then
    str = str .. " -in " .. frame_id
  end
  self:send(str)
end

function LcdProc:widget_del(screen_id, widget_id)
  self:send("widget_del " .. screen_id .. " " .. widget_id)
end

function LcdProc:widget_set(screen_id, widget_id, widgettype_specific_parameters)
  self:send("widget_set " .. screen_id .. " " .. widget_id .. " " .. widgettype_specific_parameters)
end

function LcdProc:client_add_key(key, mode)
  self:send("client_add_key -" .. mode .. " " .. key)
end

function LcdProc:client_del_key(key)
  self:send("client_del_key " .. key)
end

function LcdProc:menu_add_item(menu_id, new_item_id, type)
  self:send("menu_add_item " .. menu_id .. " " .. new_item_id .. " " .. type)
end

function LcdProc:menu_del_item(menu_id, item_id)
  self:send("menu_del_item " .. menu_id .. " " .. item_id)
end

function LcdProc:menu_set_item(menu_id, item_id, attrs)
  self:send("menu_set_item " .. menu_id .. " " .. item_id .. " " .. self:attributes_str(attrs))
end

function LcdProc:menu_goto(menu_id, parent_id)
  local str = "menu_goto " .. menu_id
  if parent_id then
    str = str .. " " .. parent_id
  end
  self:send(str)
end

function LcdProc:menu_set_main(menu_id)
  self:send("menu_set_main " .. menu_id)
end

function LcdProc:noop()
  self:send("noop")
end

function LcdProc:close()
  self:request("bye")
  self.sock:close()
end

return LcdProc
