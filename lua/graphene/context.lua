local util = require "graphene.util"

---@field items
---@field dir
local Context = {

}

Context.__index = Context

--- Create a new context (async)
--- Reads files from the provided directory
function Context:new(dir, callback)
  util.readdir(dir, function(items)
    local ctx = {
      items = items,
      dir = dir
    }

    setmetatable(ctx, Context)

    callback(ctx)
  end)
end
