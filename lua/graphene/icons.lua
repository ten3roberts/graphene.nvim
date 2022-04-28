local M = {}
local a = vim.api

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

function M.get(item)
  if item.type == "directory" then
    return "", "directory"
  elseif has_devicons then
    return devicons.get_icon(item.name, string.match(item.name, "%a+$"), { default = true })
  else
    return "-", ""
  end
end

local namespace = a.nvim_create_namespace("graphene-icons")

---@param files List<Item>
function M.highlight(bufnr, files)

  a.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  print("Here", #files)

  for i, file in ipairs(files) do
    local len = #file.icon.icon
    a.nvim_buf_add_highlight(bufnr, 0, file.icon.hi, i - 1, 0, len)
  end
end

---@param item Item
function M.format(item)
  local icon, hi = M.get(item)

  item.icon = { icon = icon, hi = hi }

  return string.format("%s %s%s", icon, item.name, item.type == "directory" and "/" or "")
end

return M
