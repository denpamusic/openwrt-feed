local NumberWidget = {
  screen = nil,
  id = nil,
  x = 0,
  number = 0
}
NumberWidget.__index = NumberWidget

function NumberWidget.new(screen, id, x, number)
  local self = setmetatable({}, NumberWidget)
  self.screen = screen
  self.id = id
  self.x = x
  self.number = number
  if self.screen.server:request(
    string.format("widget_add %s %s num",
      self.screen.id,
      self.id)) and self:update() then
        return self
  end
end

function NumberWidget:update()
  return self.screen.server:request(
    string.format("widget_set %s %s %i %i",
      self.screen.id,
      self.id,
      self.x,
      self.number))
end

function NumberWidget:set_position(x)
  if self:update() then
    self.x = x
  end
end

function NumberWidget:set_number(number)
  if self:update() then
    self.number = number
  end
end

return NumberWidget
