local M = {}

local uv = vim.loop

---@return Item[]
function M.readdir(dir, show_hidden, callback)
  local real = uv.fs_realpath(dir)
  if not real then
    vim.notify("No such directory: " .. dir, vim.log.levels.ERROR)
    return
  end
  real = real:gsub("/$", "")
  uv.fs_opendir(real, function(err, dirent)
    assert(dirent, err)

    local t = {}
    repeat
      local entries = uv.fs_readdir(dirent)
      if entries then
        for _, v in ipairs(entries) do
          if show_hidden or v.name:find("^%.") == nil then
            t[#t + 1] = { name = v.name, type = v.type, path = real .. "/" .. v.name }
          end
        end
      end
    until not entries
    assert(uv.fs_closedir(dirent) == true)
    callback(t, real)
  end, 64)
end

function M.path_exists(path)
  return uv.fs_stat(path)
end

function M.bind_exists(path, truthy, falsy)
  uv.fs_stat(path, function(err, stat)
    if stat == nil then
      if falsy then
        falsy()
      end
    elseif stat then
      if truthy then
        truthy()
      end
    elseif err then
      vim.notify(string.format("Failed to stat %q. %s", path, err), vim.log.levels.ERROR)
    end
  end)
end

---@param src string
---@param dst string
function M.deep_copy(src, dst)
  vim.fn.mkdir(dst, "p")

  uv.fs_opendir(src, function(err, dirent)
    assert(dirent, err)

    repeat
      local entries = uv.fs_readdir(dirent)
      if entries then
        for _, v in ipairs(entries) do
          local dst_file = dst .. "/" .. v.name
          local src_file = src .. "/" .. v.name

          if v.type == "directory" then
            M.deep_copy(src_file, dst_file)
          else
            uv.fs_copyfile(src_file, dst_file)
          end
        end
      end
    until not entries
    assert(uv.fs_closedir(dirent) == true)
  end, 64)
end

--- Creates a path
---@param path string
---@param is_dir boolean
function M.create_path(path, is_dir, callback)
  local parts = {}
  for part in path:gmatch("([^/\\]+/?)") do
    table.insert(parts, part)
  end

  local i = 1
  local trail = "/"

  local function f(err)
    if err then
      return vim.notify(string.format("Failed to create path %q. %s", trail, err), vim.log.levels.ERROR)
    end
    local cur = parts[i]
    i = i + 1
    if cur == nil then
      --- drwx------
      if callback then
        return callback()
      else
        return
      end
    end

    trail = trail .. cur

    if i <= #parts or is_dir then
      M.bind_exists(trail, f, function()
        uv.fs_mkdir(trail, 448, f)
      end)
    else
      --- Owner can read write, other can only read
      --- .rw-r--r--
      M.bind_exists(trail, f, function()
        uv.fs_open(trail, "a", 420, f)
      end)
    end
  end

  f()
end
return M
