---herdr-splits.nvim — Seamless navigation and resizing between Neovim splits
---and Herdr panes. Makes Herdr terminal splits behave like native Neovim windows.
---
---Usage:
---   require('herdr-splits').setup({ ... })
---   vim.keymap.set('n', '<C-h>', require('herdr-splits').move_cursor_left)
---   vim.keymap.set('n', '<M-h>', require('herdr-splits').resize_left)

local config = require('herdr-splits.config')
local nav = require('herdr-splits.nav')
local resize_mod = require('herdr-splits.resize')
local win = require('herdr-splits.win')
local sync = require('herdr-splits.sync')

local M = {}

---Apply configuration. Idempotent — calling again merges into existing config.
---@param opts table|nil Configuration options (see config.lua for defaults)
function M.setup(opts)
  config.setup(opts)
  pcall(sync.sync)
end

---Sync the Herdr-managed checkout to match this lazy commit.
---Intended as a lazy.nvim `build` hook entry point; respects `auto_sync_herdr`.
---Safe to call at any time; no-op unless opted in.
function M.sync_herdr()
  pcall(sync.sync)
end

---Resize the current split to the left.
---Amount defaults to config.default_amount. Multiplied by vim.v.count1.
---@param amount number|nil
function M.resize_left(amount)
  local eventignore_orig = vim.o.eventignore
  vim.o.eventignore = table.concat(config.ignored_events, ',')
  resize_mod.is_resizing = true
  local cur_win = vim.api.nvim_get_current_win()
  local ok, err = pcall(resize_mod.resize, 'left', amount)
  if not ok then
    vim.notify('herdr-splits: resize_left failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
  pcall(vim.api.nvim_set_current_win, cur_win)
  resize_mod.is_resizing = false
  vim.o.eventignore = eventignore_orig
end

---Resize the current split downward.
---@param amount number|nil
function M.resize_down(amount)
  local eventignore_orig = vim.o.eventignore
  vim.o.eventignore = table.concat(config.ignored_events, ',')
  resize_mod.is_resizing = true
  local cur_win = vim.api.nvim_get_current_win()
  local ok, err = pcall(resize_mod.resize, 'down', amount)
  if not ok then
    vim.notify('herdr-splits: resize_down failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
  pcall(vim.api.nvim_set_current_win, cur_win)
  resize_mod.is_resizing = false
  vim.o.eventignore = eventignore_orig
end

---Resize the current split upward.
---@param amount number|nil
function M.resize_up(amount)
  local eventignore_orig = vim.o.eventignore
  vim.o.eventignore = table.concat(config.ignored_events, ',')
  resize_mod.is_resizing = true
  local cur_win = vim.api.nvim_get_current_win()
  local ok, err = pcall(resize_mod.resize, 'up', amount)
  if not ok then
    vim.notify('herdr-splits: resize_up failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
  pcall(vim.api.nvim_set_current_win, cur_win)
  resize_mod.is_resizing = false
  vim.o.eventignore = eventignore_orig
end

---Resize the current split to the right.
---@param amount number|nil
function M.resize_right(amount)
  local eventignore_orig = vim.o.eventignore
  vim.o.eventignore = table.concat(config.ignored_events, ',')
  resize_mod.is_resizing = true
  local cur_win = vim.api.nvim_get_current_win()
  local ok, err = pcall(resize_mod.resize, 'right', amount)
  if not ok then
    vim.notify('herdr-splits: resize_right failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
  pcall(vim.api.nvim_set_current_win, cur_win)
  resize_mod.is_resizing = false
  vim.o.eventignore = eventignore_orig
end

---Move cursor to the left, crossing into Herdr pane if at Neovim edge.
---@param opts table|nil { same_row: boolean|nil, at_edge: string|function|nil }
function M.move_cursor_left(opts)
  resize_mod.is_resizing = false
  local ok, err = pcall(nav.move_cursor, 'left', opts)
  if not ok then
    vim.notify('herdr-splits: move_cursor_left failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

---Move cursor downward, crossing into Herdr pane if at Neovim edge.
---@param opts table|nil
function M.move_cursor_down(opts)
  resize_mod.is_resizing = false
  local ok, err = pcall(nav.move_cursor, 'down', opts)
  if not ok then
    vim.notify('herdr-splits: move_cursor_down failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

---Move cursor upward, crossing into Herdr pane if at Neovim edge.
---@param opts table|nil
function M.move_cursor_up(opts)
  resize_mod.is_resizing = false
  local ok, err = pcall(nav.move_cursor, 'up', opts)
  if not ok then
    vim.notify('herdr-splits: move_cursor_up failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

---Move cursor to the right, crossing into Herdr pane if at Neovim edge.
---@param opts table|nil
function M.move_cursor_right(opts)
  resize_mod.is_resizing = false
  local ok, err = pcall(nav.move_cursor, 'right', opts)
  if not ok then
    vim.notify('herdr-splits: move_cursor_right failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

---Append a filetype to ignored_filetypes at runtime (de-duped).
---@param name string Filetype name, e.g. 'fugitive'
---@return boolean true if added, false if already present
function M.add_ignored_filetype(name)
  for _, v in ipairs(config.ignored_filetypes) do
    if v == name then
      return false
    end
  end
  table.insert(config.ignored_filetypes, name)
  return true
end

---Append a buftype to ignored_buftypes at runtime (de-duped).
---@param name string Buffer type, e.g. 'help'
---@return boolean true if added, false if already present
function M.add_ignored_buftype(name)
  for _, v in ipairs(config.ignored_buftypes) do
    if v == name then
      return false
    end
  end
  table.insert(config.ignored_buftypes, name)
  return true
end

return M
