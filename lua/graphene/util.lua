local M = {}
local a = require("plenary.async")

local uv = vim.loop

--- Loads a directory into file items
---@param dir string
---@param show_hidden boolean
---@return Item[]|nil
function M.readdir(dir, show_hidden)
  local err, real = a.uv.fs_realpath(dir)
  if not real then
    vim.notify("No such directory: " .. dir, vim.log.levels.ERROR)
    return nil
  end

  real = real:gsub("/$", "")
  local err, dirent = a.wrap(function(cb)
    uv.fs_opendir(real, cb, 4)
  end, 1)()
  assert(dirent, err, "Failed to open dir")

  local t = {}
  while true do
    local _, entries = a.uv.fs_readdir(dirent)

    if not entries then
      break
    end

    for _, v in ipairs(entries) do
      if show_hidden or v.name:find("^%.") == nil then
        local path = real .. "/" .. v.name
        local _, stat = a.uv.fs_stat(path)
        local item =
          { name = v.name, type = v.type, path = path, modified = stat.mtime.sec, mode = stat.mode, size = stat.size }
        table.insert(t, item)
      end
    end
  end

  return t
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
  -- vim.fn.mkdir(dst, "p")

  local function copy()
    local err, dirent = a.wrap(function(cb)
      uv.fs_opendir(src, cb, 256)
    end, 1)()

    assert(dirent, err)

    if err then
      vim.notify(string.format("Failed to read %q. %s", dirent, err), vim.log.levels.ERROR)
    end

    while true do
      local err, entries = a.uv.fs_readdir(dirent)
      if not entries then
        break
      end
      for _, v in ipairs(entries) do
        local dst_file = dst .. "/" .. v.name
        local src_file = src .. "/" .. v.name

        if v.type == "directory" then
          M.deep_copy(src_file, dst_file)
        else
          a.uv.fs_copyfile(src_file, dst_file)
        end
      end
    end
  end

  M.create_path(dst, true)
  copy()
end

--- Creates a path
---@param path string
---@param is_dir boolean
function M.create_path(path, is_dir)
  local parts = {}
  for part in path:gmatch("([^/\\]+/?)") do
    table.insert(parts, part)
  end

  local i = 1
  local trail = "/"

  while true do
    local cur = parts[i]
    i = i + 1
    if cur == nil then
      --- drwx------
      break
    end

    trail = trail .. cur

    if i <= #parts or is_dir then
      if not M.path_exists(trail) then
        local err = a.uv.fs_mkdir(trail, 448)
        if err then
          vim.notify(string.format("Failed to create path %q. %s", trail, err), vim.log.levels.ERROR)
          return
        end
      end
    else
      --- Owner can read write, other can only read
      --- .rw-r--r--
      if not M.path_exists(trail) then
        local err = a.uv.fs_open(trail, "a", 420)
        if err then
          vim.notify(string.format("Failed to create file %q. %s", trail, err), vim.log.levels.ERROR)
          return
        end
      end
    end
  end
end

-- a.run(function()
--   M.create_path("/home/tei/dev/nvim/graphene.nvim/foo/bar", true)
-- end)

-- a.run(function()
--   M.deep_copy("/home/tei/dev/desync/", "/home/tei/dev/nvim/graphene.nvim/")
-- end)
return M
