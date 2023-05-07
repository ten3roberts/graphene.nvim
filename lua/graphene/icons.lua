local M = {}
local a = vim.api

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

---@class Icon
---@field hl string
---@field icon string

local folders = {
	default = {
		icon = "",
		hl = "Directory",
	},
	[".git"] = {

		icon = "",
		hl = "Directory",
	},
	test = {
		icon = "",
		hl = "String",
	},
	src = {
		icon = "",
		hl = "Directory",
	},
}

folders.tests = folders.test

function M.get_inner(name, type)
	local options = require("graphene.config").options
	name = string.match(name, "[^/\\]*")
	if type == "directory" then
		return (options.extended_folder_icons and folders[name]) or folders.default
	elseif has_devicons then
		local icon, hl = devicons.get_icon(name, string.match(name, "%a+$"), { default = true })
		return { icon = icon, hl = hl }
	else
		return { icon = "-", hl = "" }
	end
end

function M.get(item)
	return M.get_inner(item.name, item.type)
end

local namespace = a.nvim_create_namespace("graphene-icons")
local clipboard = require("graphene.clipboard")

---@param ctx Context
function M.highlight(ctx)
	local bufnr = ctx.bufnr
	a.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

	for i, item in ipairs(ctx.items) do
		local icon = item.icon.icon
		local len = #icon
		a.nvim_buf_add_highlight(bufnr, namespace, item.icon.hl, i - 1, 0, len)
		if ctx:is_selected(item) then
			a.nvim_buf_add_highlight(bufnr, namespace, "String", i - 1, 0, -1)
		end
	end
end

local function prefixed(val)
	if val > 1e9 then
		return string.format("%.1f", val / 1e9) .. "G"
	elseif val > 1e6 then
		return string.format("%.1f", val / 1e6) .. "M"
	elseif val > 1e3 then
		return string.format("%.1f", val / 1e3) .. "k"
	else
		return string.format("%.1f", val)
	end
end

local function modmask(bits)
	local t = {}
	for _ = 1, 3 do
		local s = (bit.band(bits, 4) == 4 and "r" or "-")
			.. (bit.band(bits, 2) == 2 and "w" or "-")
			.. (bit.band(bits, 1) == 1 and "x" or "-")
		table.insert(t, 1, s)
		bits = bit.rshift(bits, 3)
	end

	return table.concat(t)
end

---@param item Item
function M.format(item, width)
	local icon = M.get(item)

	if clipboard:find(item.path) ~= nil then
		icon = { icon = "·", hl = "Keyword" }
	end

	item.icon = icon

	local left = string.format("%s %s%s", icon.icon, item.name, item.type == "directory" and "/" or "")
	local right

	if item.type == "file" then
		right = string.format("%6sB %s", prefixed(item.size), modmask(item.mode))
	else
		right = string.format("%s", modmask(item.mode))
	end

	local padding = string.rep(" ", math.max(width - #left - #right - 1, 0))

	return left .. padding .. right
	-- vim.fn.strftime("%c", item.modified)
end

return M
