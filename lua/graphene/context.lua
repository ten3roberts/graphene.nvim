local util = require("graphene.util")
local config = require("graphene.config")
local a = require("plenary.async")

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
---@field modified number
---@field mode number
---@field size number

M.__index = M

local contexts = {}
local api = vim.api
local fn = vim.fn

local history = {}

--- Create a new context (async)
--- Reads files from the provided directory

--- Creates a new context
---@param dir string
---@return Context
function M.new(dir)
  a.util.scheduler()
  local old_buf = api.nvim_get_current_buf()
  local old_win = api.nvim_get_current_win()
  local bufnr = api.nvim_create_buf(false, true)
  local _, d = a.uv.fs_realpath(dir)

  a.util.scheduler()

  api.nvim_buf_set_var(bufnr, "graphene_dir", d)
  api.nvim_buf_set_option(bufnr, "filetype", "graphene")

  local ctx = {
    items = {},
    dir = d,
    bufnr = bufnr,
    old_buf = old_buf,
    old_win = old_win,
    show_hidden = config.show_hidden,
    selected = {},
  }

  contexts[bufnr] = ctx

  setmetatable(ctx, M)

  api.nvim_create_autocmd({ "VimResized", "WinEnter" }, {
    callback = a.void(function()
      ctx:display()
    end),
    buffer = bufnr,
  })

  api.nvim_create_autocmd({ "ShellCmdPost", "BufNewFile" }, {
    callback = a.void(function()
      ctx:reload()
    end),
    buffer = bufnr,
  })

  ctx:read_files()

  return ctx
end

function M:read_files()
  local items = util.readdir(self.dir, self.show_hidden) or {}
  table.sort(items, config.sort)
  self.items = items
end

function M:quit()
  self:add_history()

  if api.nvim_buf_is_valid(self.old_buf) then
    api.nvim_set_current_buf(self.old_buf)
  elseif api.nvim_win_is_valid(self.old_win) then
    api.nvim_set_current_win(self.old_win)
  end

  api.nvim_buf_delete(self.bufnr, {})
  contexts[self.bufnr] = nil
end

---@return Context|nil
function M:get(bufnr)
  bufnr = (bufnr ~= nil and bufnr ~= 0) or api.nvim_get_current_buf()
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
function M:set_dir(dir, focus)
  self:add_history()
  local _, d = a.uv.fs_realpath(dir)
  self.dir = d

  assert(self.dir, "Invalid dir")

  self:read_files()

  a.util.scheduler()
  api.nvim_buf_set_var(self.bufnr, "graphene_dir", self.dir)

  self:display(focus)
end

function M:reload_all(callback, focus)
  for _, ctx in pairs(contexts) do
    ctx:reload(callback, focus)
  end
end

function M:reload(focus)
  focus = focus or self:cur_item()
  self:read_files()
  self:display(focus)
end

function M:display(focus)
  a.util.scheduler()
  local bufnr = self.bufnr

  api.nvim_buf_set_option(bufnr, "modifiable", true)
  local windows = vim.fn.win_findbuf(self.bufnr)
  local width = 120
  for _, w in ipairs(windows) do
    width = math.min(width, api.nvim_win_get_width(w))
  end

  -- Fill
  local fmt = config.format_item
  local lines = vim.tbl_map(function(item)
    return fmt(item, width)
  end, self.items)

  if #lines == 0 then
    lines = { " --- empty ---" }
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)

  local hi = config.options.highlight_items
  hi(self)

  api.nvim_buf_set_option(bufnr, "modifiable", false)

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
  if api.nvim_get_mode().mode:lower() == "v" then
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
