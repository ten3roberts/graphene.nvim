local util = {}

local uv = vim.loop
local a = vim.api

function util.readdir(dir, callback)
  uv.fs_opendir(dir, function(err, dirent)
    assert(dirent, err)

    local t = {}
    repeat
      local entries = uv.fs_readdir(dirent)
      if entries then
        for _, v in ipairs(entries) do
          t[#t + 1] = { name = v.name, type = v.type }
        end
      end
    until not entries
    assert(uv.fs_closedir(dirent) == true)
    callback(t)
  end, 64)
end

return util
