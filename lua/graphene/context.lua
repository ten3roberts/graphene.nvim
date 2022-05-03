local util = require "graphene.util"
local config = require "graphene.config"

---@class graphene.context
---@field items table
---@field dir string
---@field bufnr number
---@field old_buf number
---@field old_win number
local M = {}

---@class Item
---@field name string
---@field type string

M.__index = M

local contexts = {}
local a = vim.api
local fn = vim.fn

local history = {}

--- Create a new context (async)
--- Reads files from the provided directory
function M.new(dir, callback)
  dir = vim.loop.fs_realpath(dir)

  util.readdir(dir, vim.schedule_wrap(function(items)
    table.sort(items, config.sort)

    local old_buf = a.nvim_get_current_buf()
    local old_win = a.nvim_get_current_win()
    local bufnr = a.nvim_create_buf(false, true)

    a.nvim_buf_set_option(bufnr, "filetype", "graphene")

    if not dir:find("/$") then
      dir = dir .. "/"
    end

    local ctx = {
      items = items,
      dir = dir,
      bufnr = bufnr,
      old_buf = old_buf,
      old_win = old_win,
    }

    contexts[bufnr] = ctx

    setmetatable(ctx, M)

    callback(ctx)
  end))
end

function M:quit()
  self:add_history()
  a.nvim_set_current_win(self.old_win)
  a.nvim_set_current_buf(self.old_buf)
  a.nvim_buf_delete(self.bufnr, {})
  contexts[self.bufnr] = nil
end

---@return graphene.context|nil
function M:get(bufnr)
  bufnr = (bufnr ~= nil and bufnr ~= 0) or a.nvim_get_current_buf()
  return contexts[bufnr]
end

function M:add_history()
  -- Add to history
  local cur = self:cur_item()
  if cur then
    history[self.dir] = cur.name
  end
end

--- Set dir async
function M:set_dir(dir, focus, callback)
  dir = vim.loop.fs_realpath(dir)

  self:add_history()
  self.dir = dir

  util.readdir(dir, vim.schedule_wrap(function(items)
    table.sort(items, config.sort)
    self.items = items
    self:display(focus)
    if callback then callback(self) end
  end))
end

function M:reload(callback)
  util.readdir(self.dir, vim.schedule_wrap(function(items)
    table.sort(items, config.sort)
    self.items = items
    self:display()
    if callback then callback(self) end
  end))
end

function M:display(focus)
  local bufnr = self.bufnr

  a.nvim_buf_set_option(bufnr, "modifiable", true)
  -- Fill
  local fmt = config.format_item;
  local lines = vim.tbl_map(function(item)
    return fmt(item)
  end, self.items)

  if #lines == 0 then
    lines = { " --- empty ---" }
  end

  a.nvim_buf_set_lines(bufnr, 0, -1, true, lines)

  local hi = config.options.highlight_items;
  hi(bufnr, self.items)

  a.nvim_buf_set_option(bufnr, "modifiable", false)

  focus = focus or history[self.dir]
  if focus then
    self:focus(focus)
  end
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
  if not item then return nil end
  return item, self.dir .. "/" .. item.name, line
end

return M
