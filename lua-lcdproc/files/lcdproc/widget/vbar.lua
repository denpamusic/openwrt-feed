local BarWidget = require "lcdproc.widget.bar"

local VBarWidget = {}
VBarWidget.__index = VBarWidget

function VBarWidget.new(screen, id, x, y, length)
  local self = setmetatable({}, VBarWidget)
  setmetatable(self, { __index = BarWidget })
  self.screen = screen
  self.id = id
  self.x = x
  self.y = y
  self.length = length
  if self.screen.server:request(
    string.format("widget_add %s %s vbar",
      self.screen.id,
      self.id)) and self:update() then
        return self
  end
end

return VBarWidget
