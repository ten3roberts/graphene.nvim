local util = {}

local uv = vim.loop

---@return Item[]
function util.readdir(dir, show_hidden, callback)
  dir = vim.loop.fs_realpath(dir):gsub("/$", "")
  uv.fs_opendir(dir, function(err, dirent)
    assert(dirent, err)

    local t = {}
    repeat
      local entries = uv.fs_readdir(dirent)
      if entries then
        for _, v in ipairs(entries) do
          if show_hidden or v.name:find("^%.") == nil then
            t[#t + 1] = { name = v.name, type = v.type, path = dir .. "/" .. v.name }
          end
        end
      end
    until not entries
    assert(uv.fs_closedir(dirent) == true)
    callback(t, dir)
  end, 64)
end

function util.path_exists(path)
  uv.fs_stat(path)
end

---@param src string
---@param dst string
function util.deep_copy(src, dst)
  vim.fn.mkdir(dst, "p")

  uv.fs_opendir(src, function(err, dirent)
    assert(dirent, err)

    local t = {}
    repeat
      local entries = uv.fs_readdir(dirent)
      if entries then
        for _, v in ipairs(entries) do
          local dst_file = dst .. "/" .. v.name
          local src_file = src .. "/" .. v.name

          if v.type == "directory" then
            util.deep_copy(src_file, dst_file)
          else
            uv.fs_copyfile(src_file, dst_file)
          end
        end
      end
    until not entries
    assert(uv.fs_closedir(dirent) == true)
  end, 64)
end

return util
