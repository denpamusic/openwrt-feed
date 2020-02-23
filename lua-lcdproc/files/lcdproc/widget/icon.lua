local IconWidget = {
  screen = nil,
  id = nil,
  x = 0,
  y = 0,
  icon = nil,
  -- @see widget.c
  icons = {
    "BLOCK_FILLED",
    "HEART_OPEN",
    "HEART_FILLED",
    "ARROW_UP",
    "ARROW_DOWN",
    "ARROW_LEFT",
    "ARROW_RIGHT",
    "CHECKBOX_OFF",
    "CHECKBOX_ON",
    "CHECKBOX_GRAY",
    "SELECTOR_AT_LEFT",
    "SELECTOR_AT_RIGHT",
    "ELLIPSIS",
    "STOP",
    "PAUSE",
    "PLAY",
    "PLAYR",
    "FF",
    "FR",
    "NEXT",
    "PREV",
    "REC"
  }
}
IconWidget.__index = IconWidget

function IconWidget.new(screen, id, x, y, icon)
  local self = setmetatable({}, IconWidget)
  self.id = id
  self.x = x
  self.y = y
  self.icon = icon
  if self.screen.server:request(
    string.format("widget_add %s %s icon",
      self.screen.id,
      self.id)) and self:update() then
        return self
  end
end

function IconWidget:update()
  return self.screen.server:request(
    string.format("widget_set %s %s %i %i %s",
      self.screen.id,
      self.id,
      self.x,
      self.y,
      self.icon))
end

function IconWidget:set_position(x, y)
  if self:update() then
    self.x = x
    self.y = y
  end
end

function IconWidget:set_icon(icon)
  if self:update() then
    self.icon = icon
  end
end

return IconWidget
