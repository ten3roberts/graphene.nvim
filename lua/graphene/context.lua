local util = require("graphene.util")
local config = require("graphene.config")
local icons = require("graphene.icons")
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
---@field is_gitignored boolean
---@field is_hidden boolean

M.__index = M

local contexts = {}
local api = vim.api
local fn = vim.fn

local history = {}

-- Global show_hidden state that persists across contexts
local global_show_hidden = nil

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
  if not d then
    d = dir
  end

  a.util.scheduler()

  api.nvim_buf_set_var(bufnr, "graphene_dir", d)
  vim.bo[bufnr].filetype = "graphene"

  -- Use global state if set, otherwise use config default
  local show_hidden = global_show_hidden
  if show_hidden == nil then
    show_hidden = config.show_hidden
  end

  local ctx = {
    items = {},
    dir = d,
    bufnr = bufnr,
    old_buf = old_buf,
    old_win = old_win,
    show_hidden = show_hidden,
    selected = {},
  }

  contexts[bufnr] = ctx

  setmetatable(ctx, M)

  api.nvim_create_autocmd({ "VimResized", "WinResized", "WinEnter", "BufEnter", "BufWinEnter" }, {
    callback = a.void(function()
      ctx:display()
    end),
    buffer = bufnr,
  })

  api.nvim_create_autocmd({ "ShellCmdPost", "BufNewFile" }, {
    callback = a.void(function()
      -- ctx:reload()
    end),
    buffer = bufnr,
  })

  -- Prevent cursor from navigating to header line (line 1)
  api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    callback = function()
      local line = fn.line(".")
      if line == 1 then
        -- Move cursor to line 2 (first item) if there are items, otherwise stay
        local line_count = api.nvim_buf_line_count(bufnr)
        if line_count > 1 then
          fn.setpos(".", { 0, 2, 1, 0 })
        end
      end
    end,
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

  local restore_buf = self.old_buf

  -- Check if old_buf is a directory buffer pointing to the same directory
  -- This happens when graphene was opened via `:e dir/`
  -- Restoring to it would trigger BufEnter and reopen graphene
  if api.nvim_buf_is_valid(restore_buf) then
    local old_buf_name = api.nvim_buf_get_name(restore_buf)
    local old_buf_type = vim.bo[restore_buf].buftype
    if old_buf_type == "" and fn.isdirectory(old_buf_name) == 1 then
      -- old_buf is a directory buffer, find an alternative
      restore_buf = nil
      for _, buf in ipairs(api.nvim_list_bufs()) do
        if buf ~= self.bufnr and buf ~= self.old_buf and api.nvim_buf_is_valid(buf) and api.nvim_buf_is_loaded(buf) then
          local name = api.nvim_buf_get_name(buf)
          local bt = vim.bo[buf].buftype
          -- Find a normal buffer that's not a directory
          if bt == "" and fn.isdirectory(name) == 0 then
            restore_buf = buf
            break
          end
        end
      end
      -- Delete the directory buffer to prevent it from causing issues
      api.nvim_buf_delete(self.old_buf, { force = true })
    end
  end

  if restore_buf and api.nvim_buf_is_valid(restore_buf) then
    api.nvim_set_current_buf(restore_buf)
  elseif api.nvim_win_is_valid(self.old_win) then
    -- Create a new empty buffer if no valid buffer found
    local new_buf = api.nvim_create_buf(true, false)
    api.nvim_set_current_buf(new_buf)
  end

  api.nvim_buf_delete(self.bufnr, {})
  contexts[self.bufnr] = nil
end

---@bufnr number|nil
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
  a.util.scheduler()
  focus = focus or self:cur_item()
  self:read_files()
  self:display(focus)
end

function M:display(focus)
  a.util.scheduler()
  local bufnr = self.bufnr

  vim.bo[bufnr].modifiable = true
  local windows = vim.fn.win_findbuf(self.bufnr)
  local width = 120
  for _, w in ipairs(windows) do
    width = math.min(width, api.nvim_win_get_width(w))
  end

  -- Generate header line
  local header = icons.format_header(width)

  -- Fill
  local fmt = config.format_item
  local lines = vim.tbl_map(function(item)
    return fmt(item, width)
  end, self.items)

  -- Prepend header
  table.insert(lines, 1, header)

  if #self.items == 0 then
    table.insert(lines, " --- empty ---")
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)

  local hi = config.options.highlight_items
  hi(self)

  vim.bo[bufnr].modifiable = false

  focus = focus or history[self.dir]
  if focus then
    self:focus(focus)
  elseif #self.items > 0 then
    -- Default cursor to first item (line 2, after header)
    fn.setpos(".", { 0, 2, 1, 0 })
  end
end

function M:focus(name)
  for i, v in ipairs(self.items) do
    if v.name == name then
      -- +1 because header is on line 1, items start at line 2
      fn.setpos(".", { 0, i + 1, 0, 0 })
      return
    end
  end
end

---@return Item
function M:cur_item()
  local line = fn.getpos(".")[2]

  -- -1 because header is on line 1, items start at line 2
  return self.items[line - 1]
end

function M:cur_items()
  local t = {}
  if api.nvim_get_mode().mode:lower() == "v" then
    local left = fn.line(".")
    local right = fn.line("v")
    local l = math.min(left, right)
    local r = math.max(left, right)
    -- -1 because header is on line 1, items start at line 2
    for i = l - 1, r - 1 do
      local item = self.items[i]
      if item then
        t[#t + 1] = item
      end
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

---@param left number line number (1-based, includes header offset)
---@param right number line number (1-based, includes header offset)
function M:toggle_range(left, right)
  -- -1 because header is on line 1, items start at line 2
  local l = math.min(left, right) - 1
  local r = math.max(left, right) - 1

  local select = true
  for i = l, r do
    local item = self.items[i]
    if item then
      select = select and (self.selected[item.path] or false)
    end
  end

  select = not select

  for i = l, r do
    local item = self.items[i]
    if item then
      self.selected[item.path] = select
    end
  end
end

function M:clear_selected()
  self.selected = {}
end

function M:path(name)
  return self.dir .. "/" .. name
end

--- Set show_hidden for this context and persist globally
function M:set_show_hidden(value)
  self.show_hidden = value
  global_show_hidden = value
end

return M
