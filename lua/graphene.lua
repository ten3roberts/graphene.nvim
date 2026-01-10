local M = {}
local fn = vim.fn
local api = vim.api

local config = require("graphene.config")
local Context = require("graphene.context")

-- Check for required dependencies
local has_plenary, a = pcall(require, "plenary.async")
if not has_plenary then
  vim.notify(
    "graphene.nvim requires plenary.nvim. Please install it: https://github.com/nvim-lua/plenary.nvim",
    vim.log.levels.ERROR
  )
  -- Return a stub module that does nothing
  return {
    setup = function() end,
    init = function() end,
    make_statusline = function() return function() return "" end end,
    status = function() return {} end,
  }
end
function M.init(dir)
  local cur_file = fn.expand("%:p:t")

  if not dir then
    if vim.bo.buftype == "" then
      dir = fn.expand("%:p:h")
    else
      dir = fn.getcwd()
    end
  end

  -- Check if we're opening from a hidden file (starts with .)
  local force_show_hidden = cur_file:match("^%.") ~= nil

  a.run(function()
    local ctx = Context.new(dir)

    -- If opening from a hidden file, force show hidden files
    if force_show_hidden and not ctx.show_hidden then
      ctx:set_show_hidden(true)
      ctx:read_files()
    end

    a.util.scheduler()
    api.nvim_win_set_buf(0, ctx.bufnr)
    ctx:display()

    M.setup_mappings(ctx)

    ctx:focus(cur_file)
  end)
end

function M.setup_mappings(ctx)
  local function map(l, r)
    vim.keymap.set({ "n", "v" }, l, r, { buffer = ctx.bufnr, nowait = true })
  end

  for k, v in pairs(config.mappings) do
    map(
      k,
      a.void(function()
        v(ctx)
      end)
    )
  end
end

---@param opts graphene.config
function M.setup(opts)
  config.setup(opts)

  local group = api.nvim_create_augroup("FileExplorer", { clear = true })
  local function au(event, o)
    opts.group = group
    api.nvim_create_autocmd(event, o)
  end

  if config.override_netrw then
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    au({ "BufEnter" }, {
      callback = function(o)
        if vim.fn.isdirectory(o.file) == 1 and vim.bo[o.buf].buftype == "" then
          M.init(o.file)
        end
      end,
    })
  end

  api.nvim_create_user_command("Graphene", function(o)
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
