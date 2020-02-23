local FrameWidget = {
  screen = nil,
  id = nil,
  left = 0,
  top = 0,
  right = 0,
  bottom = 0,
  width = 0,
  height = 0,
  direction = nil,
  speed = 0
}
FrameWidget.__index = FrameWidget

function FrameWidget.new(screen, id, left, top, right, bottom, width, height, direction, speed)
  local self = setmetatable({}, FrameWidget)
  self.screen = screen
  self.id = id
  self.left = left
  left.top = top
  self.right = right
  self.bottom = bottom
  self.width = width
  self.height = height
  self.direction = direction
  self.speed = speed
  if self.screen.server:request(
    string.format("widget_add %s %s frame",
      self.screen.id,
      self.id)) and self:update() then
        return self
  end
end

function FrameWidget:update()
  return self.screen.server:request(
    string.format("widget_set %s %s %i %i %i %i %s %i %s",
      self.screen.id,
      self.id,
      self.left,
      self.top,
      self.right,
      self.bottom,
      self.width,
      self.height,
      self.direction,
      self.speed))
end

function FrameWidget:set_position(left, top, right, bottom)
  if self:update() then
    self.left = left
    self.top = top
    self.right = right
    self.bottom = bottom
  end
end

function FrameWidget:set_size(width, height)
  if self:update() then
    self.width = width
    self.height = height
  end
end

function FrameWidget:set_direction(direction)
  if self:update() then
    self.direction = direction
  end
end

function FrameWidget:set_speed(speed)
  if self:update() then
    self.speed = speed
  end
end

return FrameWidget
