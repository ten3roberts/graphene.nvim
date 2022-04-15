local graphene = {}
local fn = vim.fn
local a = vim.api

local Context = require "graphene.context"

function graphene.init(dir)
  dir = dir or fn.expand(":p:h")
  Context.new(dir, function(ctx)
    local bufnr = a.nvim_create_buf(false, false)

    -- Fill
    local lines = vim.tbl_map(function(item)
      return string.format(" - %s", item)
    end)

    a.nvim_buf_set_lines()


    a.nvim_win_set_buf(0, bufnr)
  end)
end

return graphene;
