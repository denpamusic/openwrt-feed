local cjson = require "cjson"
local socket = require "socket"

local CgMiner = { sock = nil }
CgMiner.__index = CgMiner

function CgMiner.new(host, port)
  port = port or 4028
  local self = setmetatable({}, CgMiner)
  self.sock = assert(socket.tcp())
  self.sock:settimeout(3)
  local ret, err = self.sock:connect(host, port)
  if ret then
    return self
  end
  print("Sock Error: " .. err)
end

function CgMiner:prepare(command, parameter)
  if type(command) == "table" then
    command = table.concat(command, "+")
  end
  local json = cjson.encode({
    command = command,
    parameter = parameter or {}
  })
  return json
end

function CgMiner:decode(json)
  local data = cjson.decode(json)
  local dt = {}
  for k, v in pairs(data) do
    if k ~= "STATUS" and type(v) == "table" then
      if v[1][string.upper(k)] then
        dt[string.lower(k)] = v[1][string.upper(k)]
      else
        dt = v
      end
    end
  end
  return dt
end

function CgMiner:receive()
  if self.sock then
    local ret = self.sock:receive("*a")
    if ret then
      return self:decode(ret:sub(1, -2))
    end
  end
end

function CgMiner:send(command, parameter)
  if self.sock then
    local str = self:prepare(command, parameter)
    self.sock:send(str)
  end
end

function CgMiner:close()
  self.sock:close()
end

return CgMiner
