local M = {}
local symbols = {}
local start_col = 0

local completefunc_original = vim.bo.completefunc

-- Read symbol-description pairs from a file.
-- expect each line to be of form
-- ^<symbol><spaces><description>$
-- lines starting with double pound ## are ignored
-- lines not matching the grep also ignored
local function load_symbols(path)
	symbols = {}

	local file = io.open(path, "r")
	if not file then
		vim.notify("Cannot open: " .. path, vim.log.levels.ERROR)
		return
	end

	for line in file:lines() do
		local symbol, descrp = line:match("^(%S+)%s+(%S.*)")
		if symbol and descrp and not symbol:match("^##") then
			table.insert(symbols, {descrp, symbol})
		end
	end

	file:close()
end

-- expect mode = 0 or 1, anything else default to 0
-- mode determines where the partial word begins
-- mode 0: from the cursor when trigger is called (start search with filter "")
-- mode 1: go as far back as matched with %w or _
function M.trigger(mode)
	-- register our completion provider for this buffer, remove when CompleteDone
	vim.bo.completefunc =  "v:lua.require'symbol_complete'.complete"
	local line = vim.api.nvim_get_current_line()
	start_col = vim.api.nvim_win_get_cursor(0)[2]
	if (mode == 1) then
		local last_word = line:sub(1, start_col):match("[%w_]+$") or ""
		start_col = start_col - #last_word
	end

	-- trigger completefunc
	local keys = vim.api.nvim_replace_termcodes("<C-x><C-u>", true, false, true)
	vim.api.nvim_feedkeys(keys, "i", false)
end

-- callback for vim.bo.completefunc, called twice:
-- 1. findstart = 1: return start (col num) of subword to complete
--    (we already prepared this in M.trigger, just start_col)
-- 2. else: called with base = subword, return list of completions
function M.complete(findstart, base)
	if findstart == 1 then
		return start_col
	end

	local matches = {}
	for _, entry in ipairs(symbols) do
		local descrp, symbol = unpack(entry)
		if string.find(descrp, base) ~= nil then
			table.insert(matches, {
				word = descrp,
				abbr = symbol,
				menu = descrp,
				user_data = "symbol_complete",
        dup = 1,
			})
		end
	end
	
	return {
		words = matches,
		refresh = "always",
	}
end


function M.setup(path)
	load_symbols(vim.fn.expand(path))

	local group = vim.api.nvim_create_augroup(
		"SymbolComplete",
		{ clear = true }
	)

	-- specifies the action to take once the item has been selected
	-- actually by the time the callback is called,
	-- neovim would have already inserted the completed word (in our case, item.word)
	-- hence the logic of start_col = col - #item.word is correct
	-- always called, even if user didn't select item
	vim.api.nvim_create_autocmd("CompleteDone", {
		group = group,
		callback = function()
			-- reset completefunc
			vim.bo.completefunc = completefunc_original

			local item = vim.v.completed_item
			if not item or item.user_data ~= "symbol_complete" then
				return
			end

			-- now we replace word [ (row,start_col) -- (row,col) ) with symbol, set cursor
			local buf = vim.api.nvim_get_current_buf()
			local row, col = unpack(vim.api.nvim_win_get_cursor(0))

			-- for safety: check that inserted word in buffer is same as item.word
			local original = vim.api.nvim_buf_get_text(
				buf, row - 1, start_col, row - 1, col, {}
			)[1]
			if original ~= item.word then
				print("Inserted word (" .. original .. ") doesn't match item.word (" .. item.word .. ")\r\n")
				return
			end

			-- now we replace word [ (row,start_col) -- (row,col) ) with symbol, set cursor
			local buf = vim.api.nvim_get_current_buf()
			local symbol = item.abbr
			vim.api.nvim_buf_set_text(buf, row - 1, start_col, row - 1, col, { symbol })

			vim.api.nvim_win_set_cursor(0, { row, start_col + #symbol })
		end,
	})
end

return M

