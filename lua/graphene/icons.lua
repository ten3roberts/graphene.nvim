local M = {}
local a = vim.api

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

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

function M.get(item)
  if item.type == "directory" then
    return folders[item.name] or folders.default
  elseif has_devicons then
    local icon, hl = devicons.get_icon(item.name, string.match(item.name, "%a+$"), { default = true })
    return { icon = icon, hl = hl }
  else
    return { icon = "-", hl = "" }
  end
end

local namespace = a.nvim_create_namespace("graphene-icons")

function M.highlight(bufnr, files)
  a.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  for i, file in ipairs(files) do
    local len = #file.icon.icon
    a.nvim_buf_add_highlight(bufnr, 0, file.icon.hl, i - 1, 0, len)
  end
end

---@param item Item
function M.format(item)
  local icon = M.get(item)
  item.icon = icon

  return string.format("%s %s%s", icon.icon, item.name, item.type == "directory" and "/" or "")
end

return M
