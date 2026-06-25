-- herdr-splits.nvim plugin bootstrap.
-- This file is loaded by Neovim when the plugin is found on the runtimepath.
-- It defers all work to `require('herdr-splits')`.

if vim.g.loaded_herdr_splits then
  return
end
vim.g.loaded_herdr_splits = true

-- Defer loading until user calls setup() or invokes a function.
-- The main module is available as require('herdr-splits').
