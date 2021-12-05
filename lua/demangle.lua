local M ={}
local scheduler = require'plenary.async.util'.scheduler
local void = require'plenary.async.async'.void
local ns_id = vim.api.nvim_create_namespace('demangle')

function demangle_line(buf, line, i_line)
	local col_start, col_end = string.find(line, "_Z[%w%d_]*")
	if col_start then
		local mangled = string.sub(line, col_start,col_end)
		local handle = io.popen("c++filt " .. mangled)
		local result = string.sub(handle:read("*a"), 1, -2)
		handle:close()
		local opts = {
			end_line = i_line,
			end_col = col_end-1,
			virt_text = {{result, {'asmIdentifier', 'Cursorline'}}},
			virt_text_pos = 'overlay',
			virt_text_hide = false,
		}
		vim.api.nvim_buf_set_extmark(buf, ns_id, i_line, col_start-1, opts)
	end
end

local showFileNames = function(line_width, buf, files, line, i_line)
	-- check for definition of a new file
	local col_start, _, file_nr, file_name = string.find(line, '.file (%d+) "(.-)"')
	if col_start then
		files[file_nr] = file_name
		return files
	end
	-- check for referencing an already defined file and put the file name as
	-- virtual text there
	local n_space_for_tab = vim.api.nvim_buf_get_option(buf, "tabstop")
	line = string.gsub(line, "\t", string.rep(" ", n_space_for_tab))
	local col_start, col_end, file_nr = string.find(line, ".loc (%d+) %d+ %d+")
	if col_start then
		local max_len = line_width - col_end
		local file_name = files[file_nr]
		if string.len(file_name) > max_len then
			file_name = "..." .. string.sub(file_name, -max_len+3, -1)
		end
		local opts = {
			end_line = i_ine,
			virt_text = {{file_name, 'Comment'}},
			virt_text_pos = 'eol',
			virt_text_hide = false,
		}
		vim.api.nvim_buf_set_extmark(buf, ns_id, i_line, col_start, opts)
	end
	return files
end

local demangle_buf = function(buf, n_line, line_width)
	local files = {}
	for i_line = 0,n_line-1 do
		local line = vim.api.nvim_buf_get_lines(buf, i_line, i_line+1, true)[1]
		if line then
			scheduler()
			vim.schedule_wrap(demangle_line(buf, line, i_line))
			files = showFileNames(line_width, buf, files, line, i_line)
		end
	end
end

local get_line_width = function()
	-- just using the current window
	-- how could we handle different configurations for multiple windows?
	local win = vim.api.nvim_get_current_win()
	local sign_width = string.find(vim.api.nvim_win_get_option(win, "signcolumn"), "%d+")
	if not sign_width then
		sign_width = 0
	end
	local win_width = vim.api.nvim_win_get_width(win)
	local number_width = vim.api.nvim_win_get_option(win, "numberwidth")
	return win_width - number_width - sign_width
end

M.run = function(buf)
	if buf == 0 then
		buf = vim.api.nvim_get_current_buf()
	end
	local line_width = get_line_width(buf)
	local n_line = vim.api.nvim_buf_line_count(buf)
	void(function() demangle_buf(buf, n_line, line_width) end)()
end

return M
