local M = {}
local a = vim.api

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

---@class Icon
---@field hl string
---@field icon string

local folders = {
  default = {
    icon = "",
    hl = "Directory"
  },
  [".git"] = {

    icon = "",
    hl = "Directory"
  },
}


function M.get_inner(name, type)
  name = string.match(name, "[^/\\]*")
  if type == "directory" then
    return folders[name] or folders.default
  elseif has_devicons then
    local icon, hl = devicons.get_icon(name, string.match(name, "%a+$"), { default = true })
    return { icon = icon, hl = hl }
  else
    return { icon = "-", hl = "" }
  end

end

function M.get(item)
  return M.get_inner(item.name, item.type)
end

local namespace = a.nvim_create_namespace("graphene-icons")
local clipboard = require("graphene.clipboard")

---@param ctx Context
function M.highlight(ctx)
  local bufnr = ctx.bufnr
  a.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  for i, item in ipairs(ctx.items) do
    local icon = item.icon.icon;
    local len = #icon
    a.nvim_buf_add_highlight(bufnr, namespace, item.icon.hl, i - 1, 0, len)
    if ctx:is_selected(item) then
      a.nvim_buf_add_highlight(bufnr, namespace, "String", i - 1, 0, -1)
    end
  end
end

---@param item Item
function M.format(item)
  local icon = M.get(item)
  if clipboard:find(item.path) ~= nil then
    icon = { icon = "·", hl = "Keyword" }
  end
  item.icon = icon

  return string.format("%s %s%s", icon.icon, item.name, item.type == "directory" and "/" or "")
end

return M
