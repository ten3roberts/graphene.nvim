local util = require("graphene.util")
local config = require("graphene.config")

---@class Context
---@field items table
---@field dir string
---@field bufnr number
---@field old_buf number
---@field old_win number
---@field show_hidden boolean
---@field selected table<string, string>
local M = {}

---@class Item
---@field name string
---@field type string
---@field path string
M.__index = M

local contexts = {}
local a = vim.api
local fn = vim.fn

local history = {}

--- Create a new context (async)
--- Reads files from the provided directory
function M.new(dir, callback)
  util.readdir(
    dir,
    config.show_hidden,
    vim.schedule_wrap(function(items, d)
      table.sort(items, config.sort)

      local old_buf = a.nvim_get_current_buf()
      local old_win = a.nvim_get_current_win()
      local bufnr = a.nvim_create_buf(false, true)

      a.nvim_buf_set_var(bufnr, "graphene_dir", d)
      a.nvim_buf_set_option(bufnr, "filetype", "graphene")

      local ctx = {
        items = items,
        dir = d,
        bufnr = bufnr,
        old_buf = old_buf,
        old_win = old_win,
        show_hidden = config.show_hidden,
        selected = {},
      }

      contexts[bufnr] = ctx

      setmetatable(ctx, M)

      callback(ctx)
    end)
  )
end

function M:quit()
  self:add_history()
  a.nvim_set_current_win(self.old_win)
  a.nvim_set_current_buf(self.old_buf)
  a.nvim_buf_delete(self.bufnr, {})
  contexts[self.bufnr] = nil
end

---@return Context|nil
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
  self:add_history()

  util.readdir(
    dir,
    self.show_hidden,
    vim.schedule_wrap(function(items, d)
      self.dir = d
      a.nvim_buf_set_var(self.bufnr, "graphene_dir", d)
      table.sort(items, config.sort)
      self.items = items
      self:display(focus)
      if callback then
        callback(self)
      end
    end)
  )
end

function M:reload(callback, focus)
  focus = focus or self:cur_item()
  util.readdir(
    self.dir,
    self.show_hidden,
    vim.schedule_wrap(function(items)
      table.sort(items, config.sort)
      self.items = items
      self:display(focus)
      if callback then
        callback(self)
      end
    end)
  )
end

function M:display(focus)
  local bufnr = self.bufnr

  a.nvim_buf_set_option(bufnr, "modifiable", true)
  -- Fill
  local fmt = config.format_item
  local lines = vim.tbl_map(function(item)
    return fmt(item)
  end, self.items)

  if #lines == 0 then
    lines = { " --- empty ---" }
  end

  a.nvim_buf_set_lines(bufnr, 0, -1, true, lines)

  local hi = config.options.highlight_items
  hi(self)

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

  return self.items[line]
end

function M:cur_items()
  local t = {}
  if a.nvim_get_mode().mode:lower() == "v" then
    local left = fn.line(".")
    local right = fn.line("v")
    local l = math.min(left, right)
    local r = math.max(left, right)
    for i = l, r do
      local item = self.items[i]
      t[#t + 1] = item
    end
    return t
  else
    for _, item in ipairs(self.items) do
      if self.selected[item.path] then
        t[#t + 1] = item
      end
    end

    if #t > 0 then
      return t
    else
      return { self:cur_item() }
    end
  end
end

function M:select(item, select)
  self.selected[item.path] = (select or nil)
end

function M:is_selected(item)
  return self.selected[item.path] or false
end

function M:toggle_select(item)
  self.selected[item.path] = not (self.selected[item.path] or false)
end

---@param left number
---@param right number
function M:toggle_range(left, right)
  local l = math.min(left, right)
  local r = math.max(left, right)

  local select = true
  for i = l, r do
    local item = self.items[i]
    select = select and (self.selected[item.path] or false)
  end

  select = not select

  for i = l, r do
    local item = self.items[i]
    self.selected[item.path] = select
  end
end

function M:clear_selected()
  self.selected = {}
end

function M:path(name)
  return self.dir .. "/" .. name
end

return M
