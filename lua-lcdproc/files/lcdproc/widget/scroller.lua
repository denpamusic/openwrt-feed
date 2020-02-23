local ScrollerWidget = {
  screen = nil,
  id = nil,
  left = 0,
  top = 0,
  right = 0,
  bottom = 0,
  direction = nil,
  speed = 0,
  text = nil
}
ScrollerWidget.__index = ScrollerWidget

function ScrollerWidget.new(screen, id, left, top, right, bottom, direction, speed, text)
  local self = setmetatable({}, ScrollerWidget)
  self.screen = screen
  self.id = id
  self.left = left
  left.top = top
  self.right = right
  self.bottom = bottom
  self.direction = direction
  self.speed = speed
  self.text = text
  if self.screen.server:request(
    string.format("widget_add %s %s scroller",
      self.screen.id,
      self.id)) and self:update() then
        return self
  end
end

function ScrollerWidget:update()
  return self.screen.server:request(
    string.format("widget_set %s %s %i %i %i %i %s %i %s",
      self.screen.id,
      self.id,
      self.left,
      self.top,
      self.right,
      self.bottom,
      self.direction,
      self.speed,
      self.text))
end

function ScrollerWidget:set_position(left, top, right, bottom)
  if self:update() then
    self.left = left
    self.top = top
    self.right = right
    self.bottom = bottom
  end
end

function ScrollerWidget:set_direction(direction)
  if self:update() then
    self.direction = direction
  end
end

function ScrollerWidget:set_speed(speed)
  if self:update() then
    self.speed = speed
  end
end

function ScrollerWidget:set_text()
  if self:update() then
    self.text = text
  end
end

return ScrollerWidget
