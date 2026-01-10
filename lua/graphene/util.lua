local M = {}
local a = require("plenary.async")

local uv = vim.loop

-- Cache for git-ignored files per directory
local gitignore_cache = {}

--- Check if a directory is inside a git repository
---@param dir string
---@return string|nil git_root
local function find_git_root(dir)
  local current = dir
  while current and current ~= "" and current ~= "/" do
    if uv.fs_stat(current .. "/.git") then
      return current
    end
    current = vim.fn.fnamemodify(current, ":h")
  end
  return nil
end

--- Get list of git-ignored files in a directory
---@param dir string
---@return table<string, boolean> ignored_files map of filename -> true
local function get_gitignored_files(dir)
  -- Check cache first
  if gitignore_cache[dir] then
    return gitignore_cache[dir]
  end

  local ignored = {}
  local git_root = find_git_root(dir)

  if git_root then
    -- Use git check-ignore to get ignored files
    -- Run synchronously since we're in async context anyway
    local result = vim.fn.systemlist({ "git", "-C", dir, "ls-files", "--others", "--ignored", "--exclude-standard", "--directory" })
    if vim.v.shell_error == 0 then
      for _, file in ipairs(result) do
        -- Remove trailing slash from directories
        file = file:gsub("/$", "")
        ignored[file] = true
      end
    end
  end

  gitignore_cache[dir] = ignored
  return ignored
end

--- Clear gitignore cache for a directory (call after file operations)
function M.clear_gitignore_cache(dir)
  if dir then
    gitignore_cache[dir] = nil
  else
    gitignore_cache = {}
  end
end

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

	-- Get gitignored files for this directory (only if not showing hidden)
	local ignored_files = {}
	if not show_hidden then
		ignored_files = get_gitignored_files(real)
	end

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
			-- Hide files that are git-ignored (when not showing hidden)
			local is_ignored = ignored_files[v.name]
			if show_hidden or not is_ignored then
				local path = real .. "/" .. v.name
				local err, stat = a.uv.fs_stat(path)
				if not stat then
					vim.notify("Failed to stat: " .. path .. ". " .. err, vim.log.levels.ERROR)
				end

				local item = {
					name = v.name,
					type = v.type,
					path = path,
					modified = stat.mtime.sec,
					mode = stat.mode,
					size = stat.size,
				}
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
