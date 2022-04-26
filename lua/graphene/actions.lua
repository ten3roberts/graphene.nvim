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
  ctx:set_dir(parent, function()
    ctx:focus(cur)
  end)
end

---@param ctx graphene.context
function M.open(ctx)
  vim.ui.input({ prompt = "Path: " }, function(name)
    local path = ctx.dir .. "/" .. name
    if string.find(name, "/$") then
      fn.mkdir(path, "p")
      ctx:reload()
    else
      vim.cmd("edit " .. fn.fnameescape(path))
    end
  end)
end

return M
