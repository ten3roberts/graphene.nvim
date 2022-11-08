local M = {}
local fn = vim.fn
local api = vim.api

local config = require("graphene.config")
local Context = require("graphene.context")

local a = require("plenary.async")
function M.init(dir)
  local cur_file = fn.expand("%:p:t")

  if not dir then
    if vim.bo.buftype == "" then
      dir = fn.expand("%:p:h")
    else
      dir = fn.getcwd()
    end
  end

  a.run(function()
    local ctx = Context.new(dir)
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

return M
