local M = {}
local fn = vim.fn

local context = require("graphene.context")
local icons = require("graphene.icons")
---@param icon Icon
function M.statusline(icon, hl)
  local ctx = context:get()

  if not ctx then
    return ""
  end

  local path = fn.fnamemodify(ctx.dir, ":~:.")
  local dirname = fn.fnamemodify(ctx.dir, ":t")
  if icon then
    icon = icons.get_inner(dirname, "directory")
    return string.format("%%#Normal# %%#%s#%s%%#Directory# %s", hl and icon.hl or "", icon.icon, path)
  else
    return path
  end
end

return M
