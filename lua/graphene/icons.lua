local M = {}
local a = vim.api

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

---@class Icon
---@field hl string
---@field icon string

---@class ItemDisplayMeta
---@field icon_end number byte position where icon ends
---@field modtime_start number|nil byte position where modtime starts (nil if not shown)
---@field modtime_end number|nil byte position where modtime ends

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

	-- Highlight header line (line 0) with Comment highlight group (muted/darker)
	a.nvim_buf_add_highlight(bufnr, namespace, "Comment", 0, 0, -1)

	-- Items start at line 1 (after header)
	for i, item in ipairs(ctx.items) do
		local line = i -- line index is i (0-based: header=0, first item=1)
		local meta = item.display_meta

		-- Gitignored files get muted (Comment) highlight for entire line
		if item.is_gitignored then
			a.nvim_buf_add_highlight(bufnr, namespace, "Comment", line, 0, -1)
		elseif meta then
			-- Icon highlight (use stored byte position)
			a.nvim_buf_add_highlight(bufnr, namespace, item.icon.hl, line, 0, meta.icon_end)

			-- Modtime highlight in muted text (Comment highlight group)
			if meta.modtime_start then
				a.nvim_buf_add_highlight(bufnr, namespace, "Comment", line, meta.modtime_start, meta.modtime_end)
			end

			-- Permission icon highlights (colored based on permission level)
			if meta.perms_hl and meta.perms_start then
				local pos = meta.perms_start
				for j, perm in ipairs(meta.perms_hl) do
					local icon_len = #perm.icon
					a.nvim_buf_add_highlight(bufnr, namespace, perm.hl, line, pos, pos + icon_len)
					-- Move past icon + space separator (except for last icon)
					pos = pos + icon_len + (j < #meta.perms_hl and 1 or 0)
				end
			end
		end

		-- Selected items override other highlights
		if ctx:is_selected(item) then
			a.nvim_buf_add_highlight(bufnr, namespace, "String", line, 0, -1)
		end
	end
end

-- Fixed column widths for strict alignment
local ICON_WIDTH = 2 -- icon + space
local MODTIME_WIDTH = 16 -- "Jan 10 2026 17:11"
local SIZE_WIDTH = 7 -- "999.9kB" or "      -"
-- PERMS_WIDTH is now dynamic via get_perms_width()
local COL_SEP = 2 -- spaces between columns

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

--- Truncate a string to fit within max_width, adding "..." if truncated
---@param str string
---@param max_width number
---@return string
local function truncate(str, max_width)
	local display_width = vim.fn.strdisplaywidth(str)
	if display_width <= max_width then
		return str
	end
	-- Binary search for the right truncation point
	local len = vim.fn.strchars(str)
	local low, high = 1, len
	while low < high do
		local mid = math.ceil((low + high) / 2)
		local substr = vim.fn.strcharpart(str, 0, mid)
		if vim.fn.strdisplaywidth(substr) + 3 <= max_width then
			low = mid
		else
			high = mid - 1
		end
	end
	return vim.fn.strcharpart(str, 0, low) .. "..."
end

-- Permission formatting: symbolic style (rwxr-xr-x)
local function modmask_symbolic(bits)
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

-- Permission formatting: octal style (755)
local function modmask_octal(bits)
	-- Extract the lower 9 bits (rwxrwxrwx) and format as octal
	local mode = bit.band(bits, 0x1FF) -- 0777 in octal = 0x1FF
	return string.format("%03o", mode), nil
end

-- Permission icons (Nerd Font)
-- \u{f013} = cog (execute)
-- \u{f040} = pencil (write)
-- \u{f06e} = eye (read)
-- \u{f023} = lock (none)
local PERM_ICON_EXEC = "\xef\x80\x93" -- U+F013 cog
local PERM_ICON_WRITE = "\xef\x81\x80" -- U+F040 pencil
local PERM_ICON_READ = "\xef\x81\xae" -- U+F06E eye
local PERM_ICON_NONE = "\xef\x80\xa3" -- U+F023 lock

-- Highlight groups for permission icons (Sign variants = no background)
local PERM_HL_EXEC = "DiagnosticSignOk" -- green for execute
local PERM_HL_WRITE = "DiagnosticSignWarn" -- yellow/orange for write
local PERM_HL_READ = "DiagnosticSignInfo" -- blue for read
local PERM_HL_NONE = "DiagnosticSignError" -- red for no perms

-- Get icon and highlight for a permission triplet (3 bits)
local function get_perm_icon_and_hl(triplet)
	if bit.band(triplet, 1) == 1 then
		return PERM_ICON_EXEC, PERM_HL_EXEC -- has execute (highest)
	elseif bit.band(triplet, 2) == 2 then
		return PERM_ICON_WRITE, PERM_HL_WRITE -- has write
	elseif bit.band(triplet, 4) == 4 then
		return PERM_ICON_READ, PERM_HL_READ -- has read only
	else
		return PERM_ICON_NONE, PERM_HL_NONE -- no permissions
	end
end

-- Check if permissions are "normal" (owner has more or equal perms than group/others)
-- Normal patterns: 644, 755, 700, 600, etc. where owner >= group >= others
local function is_normal_perms(owner, group, others)
	-- Others should not have more permissions than group
	if others > group then
		return false
	end
	-- Group should not have more permissions than owner
	if group > owner then
		return false
	end
	return true
end

-- Permission formatting: icons style (compact, shows single icon for normal files)
-- Returns: formatted_string, highlights_table
local function modmask_icons(bits)
	local mode = bit.band(bits, 0x1FF) -- extract lower 9 bits

	-- Extract individual triplets
	local owner = bit.band(bit.rshift(mode, 6), 7)
	local group = bit.band(bit.rshift(mode, 3), 7)
	local others = bit.band(mode, 7)

	-- For normal permission patterns, just show owner's permission level
	-- This covers common cases like 644, 755, 700, 600, etc.
	if is_normal_perms(owner, group, others) then
		local icon, hl = get_perm_icon_and_hl(owner)
		-- Single icon, padded to align with 3-icon case
		-- 3 icons + 2 spaces = 5 display width, so pad with 4 spaces
		return icon .. "    ", { { icon = icon, hl = hl } }
	end

	-- Unusual permissions - show all 3 to highlight the anomaly
	local icons = {}
	local highlights = {}

	local icon, hl = get_perm_icon_and_hl(owner)
	table.insert(icons, icon)
	table.insert(highlights, { icon = icon, hl = hl })

	icon, hl = get_perm_icon_and_hl(group)
	table.insert(icons, icon)
	table.insert(highlights, { icon = icon, hl = hl })

	icon, hl = get_perm_icon_and_hl(others)
	table.insert(icons, icon)
	table.insert(highlights, { icon = icon, hl = hl })

	return table.concat(icons, " "), highlights
end

-- Get the appropriate permission formatter based on config
-- Returns: formatted_string, highlights_table (or nil)
local function format_permissions(bits)
	local config = require("graphene.config")
	local style = config.permission_style or "symbolic"

	if style == "octal" then
		return modmask_octal(bits)
	elseif style == "icons" then
		return modmask_icons(bits)
	else
		return modmask_symbolic(bits), nil
	end
end

-- Get permission column width based on style
local function get_perms_width()
	local config = require("graphene.config")
	local style = config.permission_style or "symbolic"

	if style == "octal" then
		return 3 -- "755"
	elseif style == "icons" then
		return 5 -- max: 3 icons + 2 spaces (display width), or 1 icon when collapsed
	else
		return 9 -- "rwxr-xr-x"
	end
end

--- Format the legend header line
---@param width number window width
---@return string header line
function M.format_header(width)
	-- Determine if we show modtime (window wide enough)
	local show_modtime = width > 80
	local perms_width = get_perms_width()

	-- Calculate available width for name column (same logic as format())
	local fixed_width = ICON_WIDTH + perms_width + SIZE_WIDTH + COL_SEP
	if show_modtime then
		fixed_width = fixed_width + MODTIME_WIDTH + COL_SEP
	end
	local name_width = math.max(10, width - fixed_width - 1)

	-- Build header with same column alignment as format()
	local name_header = "Name" .. string.rep(" ", name_width - 4)

	local header
	if show_modtime then
		-- "Modified" is 8 chars, MODTIME_WIDTH is 16, pad to align
		local modtime_header = string.format("%-" .. MODTIME_WIDTH .. "s", "Modified")
		-- "Size" is 4 chars, SIZE_WIDTH is 7, right-align
		local size_header = string.format("%" .. SIZE_WIDTH .. "s", "Size")
		local perms_header = string.format("%-" .. perms_width .. "s", "Perms")
		header = string.format("  %s%s  %s %s", name_header, modtime_header, size_header, perms_header)
	else
		local size_header = string.format("%" .. SIZE_WIDTH .. "s", "Size")
		local perms_header = string.format("%-" .. perms_width .. "s", "Perms")
		header = string.format("  %s%s %s", name_header, size_header, perms_header)
	end

	return header
end

---@param item Item
function M.format(item, width)
	local icon = M.get(item)

	if clipboard:find(item.path) ~= nil then
		icon = { icon = "\xc2\xb7", hl = "Keyword" } -- middle dot U+00B7
	end

	item.icon = icon
	local icon_byte_len = #icon.icon

	-- Determine if we show modtime (window wide enough)
	local show_modtime = width > 80
	local perms_width = get_perms_width()

	-- Calculate available width for name column
	local fixed_width = ICON_WIDTH + perms_width + SIZE_WIDTH + COL_SEP
	if show_modtime then
		fixed_width = fixed_width + MODTIME_WIDTH + COL_SEP
	end
	local name_width = math.max(10, width - fixed_width - 1) -- -1 for right margin

	-- Build name with directory suffix
	local name = item.name .. (item.type == "directory" and "/" or "")
	local name_display_width = vim.fn.strdisplaywidth(name)

	-- Truncate if needed, or pad to fixed width
	local formatted_name
	if name_display_width > name_width then
		formatted_name = truncate(name, name_width)
		-- Pad truncated name to exact width
		local truncated_width = vim.fn.strdisplaywidth(formatted_name)
		formatted_name = formatted_name .. string.rep(" ", name_width - truncated_width)
	else
		formatted_name = name .. string.rep(" ", name_width - name_display_width)
	end

	-- Format modtime (Jan 10 2026 17:11)
	local modtime = ""
	local modtime_byte_len = 0
	if show_modtime then
		modtime = os.date("%b %d %Y %H:%M", item.modified)
		modtime_byte_len = #modtime
	end

	-- Format size (files get size, directories get "-")
	local size
	if item.type == "file" then
		size = string.format("%6sB", prefixed(item.size))
	else
		size = string.format("%7s", "-")
	end

	-- Format permissions (returns string and optional highlight info)
	local perms, perms_hl = format_permissions(item.mode)

	-- Build the line with icon
	local left = string.format("%s %s", icon.icon, formatted_name)
	local left_byte_len = #left

	-- Build right section
	local right
	local perms_start
	if show_modtime then
		-- perms starts after: left + modtime + "  " + size + " "
		perms_start = left_byte_len + modtime_byte_len + 2 + #size + 1
		right = string.format("%s  %s %s", modtime, size, perms)
	else
		-- perms starts after: left + size + " "
		perms_start = left_byte_len + #size + 1
		right = string.format("%s %s", size, perms)
	end

	-- Store byte positions for highlighting
	item.display_meta = {
		icon_end = icon_byte_len,
		modtime_start = modtime_byte_len > 0 and left_byte_len or nil,
		modtime_end = modtime_byte_len > 0 and (left_byte_len + modtime_byte_len) or nil,
		perms_start = perms_start,
		perms_hl = perms_hl, -- array of {icon, hl} for each permission icon (nil for non-icons styles)
	}

	return left .. right
end

return M
