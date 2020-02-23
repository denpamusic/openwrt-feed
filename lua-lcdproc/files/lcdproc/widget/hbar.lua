local BarWidget = require "lcdproc.widget.bar"

local HBarWidget = {}
HBarWidget.__index = HBarWidget

function HBarWidget.new(screen, id, x, y, length)
  local self = setmetatable({}, HBarWidget)
  setmetatable(self, { __index = BarWidget })
  self.screen = screen
  self.id = id
  self.x = x
  self.y = y
  self.length = length
  if self.screen.server:request(
    string.format("widget_add %s %s hbar",
      self.screen.id,
      self.id)) and self:update() then
        return self
  end
end

return HBarWidget
