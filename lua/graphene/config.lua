local actions = require "graphene.actions"

local default_sort = function(a, b)
  if a.type == b.type then
    return a.name < b.name
  else
    return a.type < b.type
  end
end

---@class graphene.config
---@field format_item function
local defaults = {
  format_item = require "graphene.icons".format,
  highlight_items = require "graphene.icons".highlight,
  sort = default_sort,
  override_netrw = true,
  show_hidden = false,
  mappings = {
    ["<CR>"] = actions.edit,
    ["<Tab>"] = actions.edit,
    ["q"] = actions.quit,
    ["l"] = actions.edit,
    ["<C-s>"] = actions.split,
    ["<C-v>"] = actions.vsplit,
    ["<C-w>v"] = actions.vsplit,
    ["<C-w>s"] = actions.split,
    ["u"] = actions.up,
    ["h"] = actions.up,
    ["i"] = actions.open,
    ["r"] = actions.rename,
    ["D"] = actions.delete,
    [","] = actions.toggle_selected,
    ["y"] = actions.yank,
    ["d"] = actions.cut,
    ["p"] = actions.paste,
  }
}

local M = {
  options = defaults
}

M.__index = M.options

setmetatable(M, M)

---@param config graphene.config
function M.setup(config)
  config = vim.tbl_extend("force", defaults, config or {})
  M.options = config
end

return M
