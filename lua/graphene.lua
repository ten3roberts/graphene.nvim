local M = {}
local fn = vim.fn
local a = vim.api

local config = require("graphene.config")
local Context = require("graphene.context")

function M.init(dir)
  local cur_file = fn.expand("%:p:t")

  if not dir then
    if vim.bo.buftype == "" then
      dir = fn.expand("%:p:h")
    else
      dir = fn.getcwd()
    end
  end

  print("Opening graphene: ", dir, cur_file)

  Context.new(
    dir,
    vim.schedule_wrap(function(ctx)
      ctx:display()

      M.setup_mappings(ctx)

      a.nvim_win_set_buf(0, ctx.bufnr)

      ctx:focus(cur_file)
    end)
  )
end

function M.setup_mappings(ctx)
  local function map(l, r)
    vim.keymap.set({ "n", "v" }, l, r, { buffer = ctx.bufnr, nowait = true })
  end

  for k, v in pairs(config.mappings) do
    map(k, function()
      v(ctx)
    end)
  end
end

---@param opts graphene.config
function M.setup(opts)
  config.setup(opts)

  local group = a.nvim_create_augroup("FileExplorer", { clear = true })
  local function au(event, o)
    opts.group = group
    a.nvim_create_autocmd(event, o)
  end

  if config.override_netrw then
    -- vim.g.loaded_netrw = 1
    -- vim.g.loaded_netrwPlugin = 1
    au({ "BufEnter" }, {
      callback = function(o)
        if vim.fn.isdirectory(o.file) == 1 then
          M.init(o.file)
        end
      end,
    })
  end

  a.nvim_create_user_command("Graphene", function(o)
    local args = o.args ~= "" and o.args
    require("graphene").init(args)
  end, { nargs = "?", desc = "Open graphene file browser", complete = "file" })
end

---@class StatuslineOpts
---@field icon boolean|nil
---@field hl boolean|nil

---@param opts StatuslineOpts
---@return function
function M.make_statusline(opts)
  opts = opts or {}
  local icon = opts.icon ~= false
  local hl = opts.hl ~= false
  local sl = require("graphene.statusline").statusline
  return function()
    return sl(icon, hl)
  end
end

function M.status()
  local icons = require("graphene.icons")
  local ctx = Context.get()

  if not ctx then
    return {}
  end

  local path = fn.fnamemodify(ctx.dir, ":~:.")
  local dirname = fn.fnamemodify(ctx.dir, ":t")
  local icon = icons.get_inner(dirname, "directory")
  return {
    path = path,
    dirname = dirname,
    icon = icon,
  }
end

return M
