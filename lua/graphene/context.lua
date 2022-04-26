local util = require "graphene.util"

---@class graphene.context
---@field items List<Item>
---@field dir string
---@field bufnr number
local M = {}

---@class Item
---@field name string
---@field type string

M.__index = M

local contexts = {}
local a = vim.api
local fn = vim.fn

--- Create a new context (async)
--- Reads files from the provided directory
function M.new(dir, callback)
  util.readdir(dir, vim.schedule_wrap(function(items)
    local bufnr = a.nvim_create_buf(false, true)

    a.nvim_buf_set_option(bufnr, "filetype", "graphene")

    local ctx = {
      items = items,
      dir = dir,
      bufnr = bufnr
    }

    contexts[bufnr] = ctx

    setmetatable(ctx, M)

    callback(ctx)
  end))
end

---@return graphene.context|nil
function M:get(bufnr)
  bufnr = (bufnr ~= nil and bufnr ~= 0) or a.nvim_get_current_buf()
  return contexts[bufnr]
end

--- Set dir async
function M:set_dir(dir, callback)
  dir = fn.fnamemodify(dir, ":p")
  self.dir = dir

  util.readdir(dir, vim.schedule_wrap(function(items)
    self.items = items
    self:display()
    if callback then callback(self) end
  end))
end

function M:reload(callback)
  util.readdir(self.dir, vim.schedule_wrap(function(items)
    self.items = items
    self:display()
    if callback then callback(self) end
  end))
end

function M:display(focus)
  local config = require "graphene.config"
  local bufnr = self.bufnr
  a.nvim_buf_set_option(bufnr, "modifiable", true)
  -- Fill
  local fmt = config.format_item;
  local lines = vim.tbl_map(function(item)
    return fmt(item)
  end, self.items)

  a.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  a.nvim_buf_set_option(bufnr, "modifiable", false)

end

function M:focus(name)
  for i, v in ipairs(self.items) do
    if v.name == name then
      fn.setpos(".", { 0, i, 0, 0 })
      return
    end
  end
end

---@return Item
function M:cur_item()
  local line = fn.getpos(".")[2]

  local item = self.items[line]
  return item, self.dir .. "/" .. item.name
end

return M
