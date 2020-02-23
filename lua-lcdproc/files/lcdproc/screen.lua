local widget = require "lcdproc.widget"

local Screen = {
  server = nil,
  id = nil,
  name = nil,
  width = 0,
  height = 0,
  priority = nil,
  heartbeat = nil,
  backlight = nil,
  duration = 0,
  timeout = 0,
  cursor = nil,
  cursor_x = 0,
  cursor_y = 0,
  widgets = {}
}
Screen.__index = Screen

function Screen.new(server, id)
  local self = setmetatable({}, Screen)
  self.server = server
  self.id = id
  if self.server:request("screen_add " .. self.id) then
    return self
  end
end

function Screen:set_name(name)
  if self.server:request(
    string.format("screen_set %s {%s}",
      self.id,
      self.name)) then
        self.name = name
  end
end

function Screen:set_size(width, height)
  if self.server:request(string.format("screen_set %s wid %i hgt %i",
    self.id,
    self.width,
    self.height)) then
      self.width = width
      self.height = height
  end
end

function Screen:set_priority(priority)
  if self.server:request(string.format("screen_set %s priority %s",
    self.id,
    self.priority)) then
      self.priority = priority
  end
end

function Screen:set_heartbeat(heartbeat)
  if self.server:request(string.format("screen_set %s heartbeat %s",
    self.id,
    self.heartbeat)) then
      self.heartbeat = heartbeat
  end
end

function Screen:set_backlight(backlight)
  if self.server:request(string.format("screen_set %s backlight %s",
    self.id,
    self.backlight)) then
      self.backlight = backlight
  end
end

function Screen:set_duration(duration)
  if self.server:request(string.format("screen_set %s duration %i",
    self.id,
    self.duration)) then
      self.duration = duration
  end
end

function Screen:set_timeout(timeout)
  if self.server:request(string.format("screen_set %s timeout %i",
    self.id,
    self.timeout)) then
      self.timeout = timeout
  end
end

function Screen:set_cursor(cursor, x, y)
  if self.server:request(string.format("screen_set %s cursor %s cursor_x %i cursor_y %i",
    self.id,
    self.cursor,
    self.cursor_x,
    self.cursor_y)) then
      self.cursor = cursor
      self.cursor_x = x
      self.cursor_y = y
  end
end

function Screen:add_string_widget(id, x, y, text)
  self.widgets[id] = widget.string.new(self, id, x, y, text)
end

function Screen:add_title_widget(id, text)
  self.widgets[id] = widget.title.new(self, id, text)
end

function Screen:add_hbar_widget(id, x, y, length)
  self.widgets[id] = widget.hbar.new(self, id, x, y, length)
end

function Screen:add_vbar_widget(id, x, y, length)
  self.widgets[id] = widget.vbar.new(self, id, x, y, length)
end

function Screen:add_icon_widget(id, x, y, icon)
  self.widgets[id] = widget.icon.new(self, id, x, y, icon)
end

function Screen:add_scroller_widget(id, left, top, right, bottom, direction, speed, text)
  self.widgets[id] = widget.scroller.new(self, id, left, top, right, bottom, direction, speed, text)
end

function Screen:add_frame_widget(id, left, top, right, bottom, width, height, direction, speed)
  self.widgets[id] = widget.frame.new(self, id, left, top, right, bottom, width, height, direction, speed)
end

function Screen:add_number_widget(id, x, number)
  self.widgets[id] = widget.number.new(self, id, x, number)
end

function Screen:del_widget(id)
  if self.widgets[id] and self.server:request("del_widget " .. id) then
    self.widgets[id] = nil
  end
end

return Screen
