--[[
  @abstract
--]]

local BarWidget = { screen = nil, id = nil, x = 0, y = 0, length = 0 }
BarWidget.__index = BarWidget

function BarWidget:update()
  return self.screen.server:request(
    string.format("widget_set %s %s %i %i %i",
      self.screen.id,
      self.id,
      self.x,
      self.y,
      self.length))
end

function BarWidget:set_position(x, y)
  self.x = x
  self.y = y
  return self:update()
end

function BarWidget:set_length(length)
  self.length = length
  return self:update()
end

return BarWidget
