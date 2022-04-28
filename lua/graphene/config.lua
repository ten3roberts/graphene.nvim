local actions = require "graphene.actions"
---@class graphene.config
---@field format_item function
local defaults = {
  format_item = require "graphene.icons".format,
  highlight_items = require "graphene.icons".highlight,
  mappings = {
    ["<CR>"] = actions.edit,
    ["<Tab>"] = actions.edit,
    ["l"] = actions.edit,
    ["s"] = actions.split,
    ["v"] = actions.vsplit,
    ["u"] = actions.up,
    ["h"] = actions.up,
    ["i"] = actions.open,
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
