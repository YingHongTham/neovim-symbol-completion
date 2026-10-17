# Autocomplete for inserting Unicode in Neovim

Similar to the regular autocomplete (default `<C-p>/<C-n>`), this creates a list of Unicode symbols taken from a user-provided table (extracted from symbol_table.txt, and filters the list based on string, match against symbol description (again, in symbol_table.txt.

## Setup
put symbol_complete.lua and symbol_table.txt in \<neovim config\>/lua/
and enable it in init.lua:
```
  local symbol_complete = require("symbol_complete")
  symbol_complete.setup( vim.fn.stdpath("config") .. "/lua/symbol_table.txt")
  vim.keymap.set("i", "<C-u><C-i>", function() symbol_complete.trigger(0) end, {
      desc = "Open symbol completion (begin filter with empty string)" })
  vim.keymap.set("i", "<C-u><C-u>", function() symbol_complete.trigger(1) end, {
      desc = "Open symbol completion (begin filter with current word)" })
```

## Basic workings
We use the builtin word completion functionality,
set vim.bo.completefunc to M.complete, and reset it to its original value when done.
`trigger(mode)` finds the start of the word to complete:
- `mode = 0`: start at current cursor position, so search begins with no filter
- `mode = 1`: start as far as possible back
then calls the builtin word completion functionality `<C-X><C-U>`, which we redirected to M.complete.
When user selects an item, neovim pastes the description into the buffer. We replace the inserted description by the symbol we want (implemented in the "CompleteDone" callback).

Warning: the resetting of vim.bo.completefunc interfere with other plugins if they change vim.bo.completefunc while this completion session is running.
