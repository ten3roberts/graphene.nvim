local util = require("graphene.util")
local async = require("plenary.async")
local M = {}
local api = vim.api
local uv = vim.loop
local fn = vim.fn

--- Open the item under the cursor
---@param ctx Context
function M.edit(ctx, cmd)
  cmd = cmd or "edit"

  if ctx then
    local item = ctx:cur_item()
    if not item then
      return
    end

    if item.type == "directory" and cmd == "edit" then
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
function M.create(ctx)
  vim.ui.input(
    { prompt = "Name: " },
    async.void(function(name)
      if not name then
        return
      end

      local path = ctx:path(name)
      local is_dir = string.find(name, "/$")
      util.create_path(path, is_dir ~= nil)

      async.util.scheduler()
      if not is_dir then
        vim.cmd("edit " .. fn.fnameescape(path))
      end
      ctx:reload(name)
    end)
  )
end
local function open_external(path)
  local job = vim.fn.jobstart({ "xdg-open", path }, {
    detached = true,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.notify("Failed to execute xdg-open for " .. path, vim.log.levels.ERROR)
      end
    end,
  })

  if job < 0 then
    vim.notify("Failed to start xdg-open ", vim.log.levels.ERROR)
  end
end

---@param ctx Context
function M.open_external(ctx)
  local cur = ctx:cur_item()

  if not cur then
    return
  end

  local path = cur.path
  open_external(path)
end

---@param ctx Context
function M.open_dir_external(ctx)
  open_external(ctx.dir)
end

---@param ctx Context
function M.rename(ctx)
  local cur = ctx:cur_item()

  if not cur then
    return
  end

  local path = cur.path

  local opts = {
    completion = "dir",
    prompt = "Rename: ",
    default = cur.name,
  }

  -- cd to the currently focused dir to get completion from the current directory
  -- local old_dir = fn.getcwd()

  vim.ui.input(
    opts,
    async.void(function(dst)
      if dst == nil or dst == cur.name then
        return
      end

      -- If target is a directory, move the file into the directory.
      -- Makes it work like linux `mv`
      local stat = uv.fs_stat(ctx.dir .. "/" .. dst)

      async.util.scheduler()
      if type(stat) == "table" then
        if stat.type == "directory" then
          dst = string.format("%s/%s", dst, cur.name)
        elseif vim.fn.confirm(string.format("%q already exists. Replace?", dst), "&Yes\n&No") ~= 1 then
          return
        end
      end

      dst = ctx.dir .. "/" .. dst

      -- Rename buffer
      local buf = fn.bufnr(vim.fn.fnameescape(path))

      if buf ~= -1 then
        api.nvim_buf_set_name(buf, dst)
      end

      if async.uv.fs_rename(path, dst) then
        vim.notify("Failed to rename " .. cur.name .. " => " .. dst, vim.log.levels.ERROR)
      end

      async.util.scheduler()
      ctx:reload(dst:match(".-/"))
    end)
  )
end

---@param ctx Context
function M.toggle_hidden(ctx)
  ctx.show_hidden = not ctx.show_hidden
  ctx:reload()
end

---@param ctx Context
function M.toggle_selected(ctx)
  local cur = ctx:cur_item()
  if api.nvim_get_mode().mode:lower() == "v" then
    local left = fn.line(".")
    local right = fn.line("v")
    ctx:toggle_range(left, right)
  else
    if not cur then
      return
    end
    ctx:toggle_select(cur)
  end

  ctx:reload(cur)
end

---@param item Item
---@param dst string
local function rename(item, dst)
  if not uv.fs_rename(item.path, dst) then
    vim.notify("Failed to rename " .. item.path .. " => " .. dst, vim.log.levels.ERROR)
  end
end

local function copy(item, dst, callback)
  if item.type == "directory" then
    util.deep_copy(item.path, dst, callback)
  else
    uv.fs_copyfile(item.path, dst, nil, function(err, ok)
      assert(ok, err)
      if callback then
        callback()
      end
    end)
  end
end

local clipboard = require("graphene.clipboard")

---@param ctx Context
function M.yank(ctx)
  local items = ctx:cur_items()
  clipboard:set(items, copy)
  ctx:clear_selected()
  ctx:reload()
end

---@param ctx Context
function M.cut(ctx)
  local items = ctx:cur_items()
  clipboard:set(items, rename)
  ctx:clear_selected()
  ctx:reload()
end

---@param ctx Context
function M.clear_clipboard(ctx)
  clipboard:clear()
  ctx:reload()
end

---@param ctx Context
function M.reload(ctx)
  ctx:reload()
end

---@param ctx Context
function M.paste(ctx)
  local action = clipboard.action
  local dir = ctx.dir
  for _, item in pairs(clipboard.items) do
    local dst_path = dir .. "/" .. item.name
    if util.path_exists(dst_path) then
      async.util.scheduler()
      local choice =
        vim.fn.confirm(string.format("Destination %s already exists", dst_path), "&Skip\n&Rename\n&Force Replace")
      if choice == 1 then
      elseif choice == 2 then
        local new_name = vim.fn.input("Enter new name: ")
        dst_path = dir .. "/" .. new_name
        action(item, dst_path)
      elseif choice == 3 then
        vim.fn.delete(dst_path)
        action(
          item,
          dst_path,
          async.void(function()
            ctx:reload_all()
          end)
        )
      end
    else
      action(
        item,
        dst_path,
        async.void(function()
          ctx:reload_all()
        end)
      )
    end
  end

  clipboard:clear()

  ctx:reload()
end

---@param ctx Context
function M.delete(ctx, force)
  local items = ctx:cur_items()

  for _, item in ipairs(items) do
    if not items then
      return
    end

    local path = item.path

    local all = ""
    if #items > 1 then
      all = string.format("\nAll %d", #items)
    end

    local choice = (force and 1)
      or vim.fn.confirm(string.format("Delete %s %s", item.type, path), "&Yes\n&No" .. all, 1)

    if choice == 3 then
      force = true
    end

    if choice == 1 or choice == 3 then
      if fn.delete(path, "rf") ~= 0 then
        vim.notify("Failed to delete " .. path, vim.log.levels.ERROR)
      end
      local buf = fn.bufnr(vim.fn.fnameescape(path))

      if buf ~= -1 then
        api.nvim_buf_delete(buf, {})
      end
    else
      break
    end
  end

  ctx:reload()
end

return M
