local socket = require "socket"
local utils = require "lcdproc/utils"
local Screen = require "lcdproc/screen"

local LcdProc = {
  sock = nil,
  server = { version = nil, protocol = nil },
  lcd = { width = nil, height = nil, cell_width = nil, cell_height = nil },
  name = nil,
  screens = {},
  keys = {},
  handlers = { listen = {}, ignore = {} }
}
LcdProc.__index = LcdProc

function LcdProc.new(host, port)
  local self = setmetatable({}, LcdProc)
  self.sock = assert(socket.tcp())
  self.sock:settimeout(3)
  local ret, err = self.sock:connect((host or "localhost"), (port or 13666))
  if ret then
    self:hello()
    return self
  end
  return nil, err
end

function LcdProc:request(line)
  self.sock:send(utils.trim(line) .. "\n")
  local line, err = self.sock:receive("*l")

  if not line then
    return nil, err
  elseif line:match "^success" or line:match "^connect" then
    return utils.trim(line)
  else
    err = line:match "huh%? (.*)"
    if err then
      return nil, err
    end
  end
end

function LcdProc:hello()
  local line = self:request("hello")
  if line then
    self.server = {
      version = line:match "LCDproc ([0-9%.]+)",
      protocol = line:match "protocol ([0-9%.]+)"
    }
    self.lcd = {
      width = line:match " wid ([0-9]+)",
      height = line:match " hgt ([0-9]+)",
      cell_width = line:match " cellwid ([0-9]+)",
      cell_height = line:match " cellhgt ([0-9]+)"
    }
  end
end

function LcdProc:set_name(name)
  if self:request(string.format("client_set name %s", name)) then
    self.name = name
  end
end

function LcdProc:add_screen(id)
  self.screens[id] = Screen.new(self, id)
  return self.screens[id]
end

function LcdProc:del_screen(id)
  if self.screens[id] and self:request("screen_del " .. id) then
    self.screens[id] = nil
  end
end

function LcdProc:add_key(id, mode)
  mode = mode or "shared"
  if not self.keys[id] then
    if self:request(string.format("client_add_key -%s %s", id, mode)) then
      self.keys[id] = id
    end
  end
end

function LcdProc:del_key(id)
  if self.keys[id] then
    if self:request("client_del_key " .. id) then
      self.keys[id] = nil
    end
  end
end

function LcdProc:backlight(state)
  return self:request("backlight " .. state)
end

function LcdProc:output(state)
  return self:request("output " .. state)
end

function LcdProc:info()
  return self:request("info")
end

function LcdProc:noop()
  return self:request("noop")
end

function LcdProc:sleep(seconds)
  return self:request("sleep " .. seconds)
end

function LcdProc:close()
  self:request("bye")
  self.sock:close()
end

function LcdProc:on_listen(fn)
  table.insert(self.handlers.listen, fn)
end

function LcdProc:on_ignore(fn)
  table.insert(self.handlers.ignore, fn)
end

function LcdProc:poll()
  local canread = socket.select({ self.sock }, nil, 1)
  for _, c in ipairs(canread) do
    local line, err = self.sock:receive("*l")
    if line then
      local listen = line:match "listen (%a+)"
      if listen then
        for _, fn in ipairs(self.handlers.listen) do
          fn(self.screens[listen], self)
        end
      else
        local ignore = line:match "ignore (%a+)"
        if ignore then
          for _, fn in ipairs(self.handlers.ignore) do
            fn(self.screens[ignore], self)
          end
        end
      end
      return line, err
    end
  end
end

return LcdProc
