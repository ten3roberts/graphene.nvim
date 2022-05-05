local util = require "graphene.util"
local M = {}
local a = vim.api
local uv = vim.loop
local fn = vim.fn

--- Open the item under the cursor
---@param ctx Context
function M.edit(ctx, cmd)
  cmd = cmd or "edit"

  if ctx then
    local item = ctx:cur_item()
    if not item then return end

    if item.type == "directory" and (cmd == "edit") then
      ctx:set_dir(item.path)
    else
      vim.cmd(cmd .. " " .. fn.fnameescape(item.path))
    end
  end
end

function M.split(ctx)
  M.edit(ctx, "split")
end

function M.vsplit(ctx)
  M.edit(ctx, "vsplit")
end

---@param ctx Context
function M.up(ctx)
  local cur = fn.fnamemodify(ctx.dir, ":p:h:t")
  local parent = fn.fnamemodify(ctx.dir, ":p:h:h")
  ctx:set_dir(parent, cur)
end

---@param ctx Context
function M.quit(ctx)
  ctx:quit()
end

---@param ctx Context
function M.open(ctx)
  vim.ui.input({ prompt = "Name: " }, function(name)
    if not name then
      return
    end

    local path = ctx:path(name)
    if string.find(name, "/$") then
      fn.mkdir(path, "p")
      ctx:reload(nil, name)
    else
      fn.mkdir(fn.fnamemodify(path, ":p:h"), "p")
      vim.cmd("edit " .. fn.fnameescape(path))
    end
  end)
end

---@param ctx Context
function M.rename(ctx)
  local cur, path = ctx:cur_item()
  local default = cur

  if not cur then return end

  local opts = {
    completion = "dir",
    prompt = "Rename: ",
    default = default,
  }

  -- cd to the currently focused dir to get completion from the current directory
  local old_dir = fn.getcwd()

  a.nvim_set_current_dir(ctx.dir)

  vim.ui.input(opts, function(new)
    if new == nil or new == cur.name then
      a.nvim_set_current_dir(old_dir)
      return
    end

    -- Restore working directory
    a.nvim_set_current_dir(old_dir)

    -- If target is a directory, move the file into the directory.
    -- Makes it work like linux `mv`
    local stat = uv.fs_stat(ctx.dir .. new)
    if stat and stat.type == "directory" then
      new = string.format("%s/%s", new, cur.name)
    end


    new = ctx.dir .. new

    -- Rename buffer
    local buf = fn.bufnr(vim.fn.fnameescape(path))

    if buf ~= -1 then
      a.nvim_buf_set_name(buf, new)
    end

    if not uv.fs_rename(path, new) then
      vim.notify("Failed to rename " .. cur.name .. " => " .. new, vim.log.levels.ERROR)
    end

    ctx:reload()
  end)
end

---@param ctx Context
function M.toggle_hidden(ctx)
  ctx.show_hidden = not ctx.show_hidden
  ctx:reload()
end

---@param ctx Context
function M.toggle_selected(ctx)
  local cur = ctx:cur_item()
  if a.nvim_get_mode().mode:lower() == "v" then
    local left = fn.line(".")
    local right = fn.line("v");
    ctx:toggle_range(left, right)
  else
    if not cur then return end
    ctx:toggle_select(cur)
  end

  ctx:reload(nil, cur)
end

---@param dst string
---@param src string
local function rename(src, dst)
  vim.notify(string.format("%s => %s", src, dst))
  if not uv.fs_rename(src, dst) then
    vim.notify("Failed to rename " .. src .. " => " .. dst, vim.log.levels.ERROR)
  end
end

local function copy(src, dst)
  util.deep_copy(src, dst)
end

local clipboard = require "graphene.clipboard"

---@param ctx Context
function M.yank(ctx)
  local items = ctx:cur_items()
  clipboard:set(items, rename)
  ctx:clear_selected()
  ctx:reload()
end

---@param ctx Context
function M.paste(ctx)
  local action = clipboard.action
  local dir = ctx.dir
  for _, item in pairs(clipboard.items) do
    local dst = dir .. "/" .. item.name
    if util.path_exists(path) then
      local choice = vim.fn.confirm(string.format("Destination %s already exists", dst), "&Skip\n&Rename\n&Force Replace")
      if choice == 1 then
      elseif choice == 2 then
        local new_name = vim.fn.input("Enter new name: ")
        dst = dir .. "/" .. new_name
        action(item.path, dst)
      elseif choice == 3 then
        vim.fn.delete(dst)
        action(item.path, dst)
      end
    else
      action(item.path, dst)
    end
  end

  ctx:reload()
end

---@param ctx Context
function M.delete(ctx, force)
  local cur = ctx:cur_items()

  if not cur then return end

  local path = cur.path;

  local function delete()
    if fn.delete(cur.path, "rf") ~= 0 then
      vim.notify("Failed to delete " .. path, vim.log.levels.ERROR)
    end
    local buf = fn.bufnr(vim.fn.fnameescape(path))

    if buf ~= -1 then
      a.nvim_buf_delete(buf, {})
    end

    ctx:reload()
  end

  local stat = uv.fs_stat(path)
  if stat and stat.type == "directory" then
    util.readdir(path, true, vim.schedule_wrap(function(items)
      local count = #items
      if not force and vim.fn.confirm(string.format("Delete directory %s containing %d items", path, count), "&Yes\n&No", 1) ~= 1 then
        return
      end

      delete()
    end))
  else
    if not force and vim.fn.confirm(string.format("Delete file %s", path), "&Yes\n&No", 1) ~= 1 then
      return
    end

    delete()
  end
end

return M
