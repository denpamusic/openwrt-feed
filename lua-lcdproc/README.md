# lua-lcdproc
 Lua lcdproc is simple lcdproc client

# Usage
```lua
local lcd = LcdProc.new("localhost", 13666)
lcd:set_name("MyClient")

local screen = lcd:add_screen("MyScreen")
screen:add_title_widget("one", "Title Line")
screen:add_string_widget("two", 1, 2, "First Line")
screen:add_string_widget("three", 1, 3, "Second Line")
screen:add_string_widget("four", 1, 4, "Third Line")

lcd:on_listen(function (screen)
  -- text will be updated once screen is visible
  screen.widgets.two:set_text("First Line Now Has New Text")
  screen.widgets.three:set_text("Second Line Also Does")
end)

lcd:on_ignore(function (screen)
  -- do something on screen hide
end)

while true do
  --[[
    poll lcdproc server for new responses and
    execute event handlers defined above
  --]]
  local line = lcd:poll()
end

lcd:close()
```
