local M = {}
local fn = vim.fn
local a = vim.api

local config = require "graphene.config"
local Context = require "graphene.context"

function M.init(dir)
  dir = dir or fn.expand("%:p:h")
  local cur_file = fn.expand("%:p:t")
  Context.new(dir, vim.schedule_wrap(function(ctx)

    ctx:display()

    M.setup_mappings(ctx)

    a.nvim_win_set_buf(0, ctx.bufnr)

    ctx:focus(cur_file)
  end))
end

function M.setup_mappings(ctx)
  local function map(l, r)
    vim.keymap.set({ "n" }, l, r, { buffer = ctx.bufnr })
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

  local group = a.nvim_create_augroup("FileExplorer", { clear = true });
  local function au(event, o)
    opts.group = group
    a.nvim_create_autocmd(event, o)
  end

  if config.override_netrw then
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    au({ "BufEnter" }, { callback = function(o)
      if vim.fn.isdirectory(o.file) == 1 then
        M.init(o.file)
      end
    end })
  end

  a.nvim_create_user_command("Graphene",
    function(o)
      local args = o.args ~= "" and o.args
      require "graphene".init(args)
    end,
    { nargs = "?", desc = "Open graphene file browser", complete = "file" }
  )
end

return M;
