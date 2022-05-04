local util = require "graphene.util"
local M = {}
local a = vim.api
local uv = vim.loop
local fn = vim.fn

--- Open the item under the cursor
---@param ctx graphene.context
function M.edit(ctx, cmd)
  cmd = cmd or "edit"

  if ctx then
    local cur, path = ctx:cur_item()
    if not cur then return end

    if cur.type == "directory" and (cmd == "edit") then
      ctx:set_dir(path)
    else
      vim.cmd(cmd .. " " .. fn.fnameescape(path))
    end
  end
end

function M.split(ctx)
  M.edit(ctx, "split")
end

function M.vsplit(ctx)
  M.edit(ctx, "vsplit")
end

---@param ctx graphene.context
function M.up(ctx)
  local cur = fn.fnamemodify(ctx.dir, ":p:h:t")
  local parent = fn.fnamemodify(ctx.dir, ":p:h:h")
  ctx:set_dir(parent, cur)
end

---@param ctx graphene.context
function M.quit(ctx)
  ctx:quit()
end

---@param ctx graphene.context
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
      vim.cmd("edit " .. fn.fnameescape(path))
    end
  end)
end

---@param ctx graphene.context
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

---@param ctx graphene.context
function M.toggle_hidden(ctx)
  ctx.show_hidden = not ctx.show_hidden
  ctx:reload()
end

---@param ctx graphene.context
function M.delete(ctx, force)
  local cur, path = ctx:cur_item()

  if not cur then return end

  local function delete()
    if fn.delete(path, "rf") ~= 0 then
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
