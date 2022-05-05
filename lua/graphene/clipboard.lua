---@class Clipboard
---@field items Item[]
---@field action function
local clipboard = {
  items = {},
  action = function(_, _) end
}

---@param items Item[]
function clipboard:set(items, action)
  self.items = {}
  for _, v in pairs(items) do
    self.items[v.path] = v
  end
  self.action = action
end

function clipboard:clear()
  self.items = {}
  self.action = function()
  end
end

function clipboard:find(path)
  return self.items[path]
end

return clipboard
