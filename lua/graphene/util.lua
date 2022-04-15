local util = {}

local uv = vim.loop
local a = vim.api

function util.readdir(dir, callback)
  uv.fs_opendir(dir, function(err, dirent)
    assert(dirent, err)

    local function read_cb(err1, entries)
      -- assert(entries, err1)

      local t = {}
      if entries ~= nil then
        for _, v in ipairs(entries) do
          t[#t + 1] = { name = v.name, type = v.type }
        end

        uv.fs_readdir(dirent, read_cb)
      else
        vim.notify("Done")
        callback()
      end


      -- if entries then
      --   dirent:readdir(read)
      -- end
      -- uv.fs_closedir(dirent, function() callback(t) end)
    end

    uv.fs_readdir(dirent, read_cb)
  end, 8)
end

return util
