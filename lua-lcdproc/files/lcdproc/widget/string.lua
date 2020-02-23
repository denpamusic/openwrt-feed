local StringWidget = { screen = nil, id = nil, x = 0, y = 0, text = nil}
StringWidget.__index = StringWidget

function StringWidget.new(screen, id, x, y, text)
  local self = setmetatable({}, StringWidget)
  self.screen = screen
  self.id = id
  self.x = x
  self.y = y
  self.text = text
  if self.screen.server:request(
    string.format("widget_add %s %s string",
      self.screen.id,
      self.id)) and self:update() then
        return self
  end
end

function StringWidget:update()
  return self.screen.server:request(
    string.format("widget_set %s %s %i %i {%s}",
      self.screen.id,
      self.id,
      self.x,
      self.y,
      self.text))
end

function StringWidget:set_position(x, y)
  self.x = x
  self.y = y
  return self:update()
end

function StringWidget:set_text(text)
  self.text = text
  return self:update()
end

return StringWidget
