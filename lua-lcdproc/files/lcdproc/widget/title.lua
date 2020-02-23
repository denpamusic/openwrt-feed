local TitleWidget = { screen = nil, id = nil, text = nil }
TitleWidget.__index = TitleWidget

function TitleWidget.new(screen, id, text)
  local self = setmetatable({}, TitleWidget)
  self.screen = screen
  self.id = id
  self.text = text
  if self.screen.server:request(
    string.format("widget_add %s %s title",
      self.screen.id,
      self.id)) and self:update() then
        return self
  end
end

function TitleWidget:update()
  return self.screen.server:request(
    string.format("widget_set %s %s {%s}",
      self.screen.id,
      self.id,
      self.text))
end

function TitleWidget:set_text(text)
  self.text = text
  return self:update()
end

return TitleWidget
