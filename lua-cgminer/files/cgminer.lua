local cjson = require "cjson"
local socket = require "socket"

local CgMiner = { sock = nil }
CgMiner.__index = CgMiner

function CgMiner.new(host, port)
  local self = setmetatable({}, CgMiner)
  self.sock = assert(socket.tcp())
  self.sock:settimeout(3)
  local ret, err = self.sock:connect((host or "localhost"), (port or 4028))
  if ret then
    return self
  end
  print("Sock Error: " .. err)
end

function CgMiner:prepare(command, parameter)
  if type(command) == "table" then
    command = table.concat(command, "+")
  end
  return cjson.encode({
    command = command,
    parameter = (parameter or {})
  })
end

function CgMiner:decode(json)
  local data = cjson.decode(json)
  local t = {}
  for k, v in pairs(data) do
    if k ~= "STATUS" and type(v) == "table" then
      t[k:lower()] = v[1][k:upper()] or v
    end
  end
  return t
end

function CgMiner:request(command, parameter) 
  self.sock:send(self:prepare(command, parameter))
  local ret, err = self.sock:receive("*a")
  if ret then
    return self:decode(ret:sub(1, -2))
  end
end

function CgMiner:close()
  self.sock:close()
end

return CgMiner
