local _M = {}

function _M.trim(s)
  return s:match "^%s*(.-)%s*$"
end

return _M
