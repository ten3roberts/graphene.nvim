local M = {}
local fn = vim.fn
local a = vim.api

local config = require "graphene.config"
local Context = require "graphene.context"

function M.init(dir)
  dir = dir or fn.expand("%:p:h")
  Context.new(dir, vim.schedule_wrap(function(ctx)

    ctx:display()
    M.setup_mappings(ctx)

    a.nvim_win_set_buf(0, ctx.bufnr)
  end))
end

function M.setup_mappings(ctx)
  local function map(l, r)
    vim.keymap.set({ "n" }, l, r, { buffer = ctx.bufnr })
  end

  for k, v in pairs(config.mappings) do
    print("Setting: ", k, v)
    map(k, function()
      v(ctx)
    end)
  end
end

return M;
