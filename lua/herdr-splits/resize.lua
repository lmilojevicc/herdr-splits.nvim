---Resize logic: seamless resize between Neovim splits and Herdr panes.
---When the Neovim window fills the terminal dimension, the resize is
---forwarded to Herdr. Otherwise, Neovim's native resize is used.
---@class HerdrSplitsResize
local M = {}

local config = require('herdr-splits.config')
local herdr = require('herdr-splits.herdr')
local win = require('herdr-splits.win')

M.is_resizing = false

---Resize in a direction. If the current Neovim window spans the full terminal
---width (for left/right) or height (for up/down), the resize is delegated to
---Herdr. Otherwise, Neovim's native wincmd resize is used.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@param amount number|nil Resize ratio (defaults to config.default_amount * count)
function M.resize(direction, amount)
  amount = amount or (vim.v.count1 * config.default_amount)

  -- Floating windows: forward to Herdr
  if win.is_floating() then
    herdr.resize_pane(direction, amount)
    return
  end

  -- Horizontal resize: check if window fills terminal width
  if direction == 'left' or direction == 'right' then
    if win.is_full_width() and herdr.is_in_session() then
      herdr.resize_pane(direction, amount)
      return
    end
  end

  -- Vertical resize: check if window fills terminal height
  if direction == 'up' or direction == 'down' then
    if win.is_full_height() and herdr.is_in_session() then
      herdr.resize_pane(direction, amount)
      return
    end
  end

  -- Native Neovim resize
  local cur_win = vim.api.nvim_get_current_win()

  if direction == 'left' then
    M._resize_left_native(amount, cur_win)
  elseif direction == 'right' then
    M._resize_right_native(amount, cur_win)
  elseif direction == 'up' then
    M._resize_up_native(amount, cur_win)
  elseif direction == 'down' then
    M._resize_down_native(amount, cur_win)
  end
end

---Native Neovim resize left: steal from the window on the left.
---We go to the left window, shrink it (vertical resize -N), then return.
---@param amount number
---@param cur_win number
function M._resize_left_native(amount, cur_win)
  if win.at_left_edge() then
    -- At Neovim left edge, nowhere to go. Wrapped back from full_width check.
    return
  end

  -- Jump to the window on the left
  vim.cmd('wincmd h')

  -- Skip ignored windows
  while win.is_ignored_win() and not win.at_left_edge() do
    vim.cmd('wincmd h')
  end

  if not win.is_ignored_win() then
    -- Shrink the left neighbor, giving space to our original window
    pcall(vim.cmd, 'vertical resize -' .. amount)
  end

  -- Return to original window
  vim.api.nvim_set_current_win(cur_win)
end

---Native Neovim resize right: grow current window, stealing from the right.
---@param amount number
---@param cur_win number
function M._resize_right_native(amount, cur_win)
  -- vertical resize +N makes current window bigger, taking from the right
  pcall(vim.cmd, 'vertical resize +' .. amount)

  -- Handle middle window compensation: if the window position shifted
  -- (because we're in the middle and Neovim adjusted differently),
  -- we need to compensate by going right and adjusting back.
  -- This only applies when NOT at the right edge and NOT at the left edge.
  if win.win_position('right') == 'middle' then
    local new_pos = vim.api.nvim_win_get_position(0)
    -- Check if the window moved vertically (row changed) — which shouldn't happen
    -- for horizontal resize, but we check anyway
    -- The smart-splits compensation is more nuanced; skip for simplicity
  end
end

---Native Neovim resize up: steal from the window above.
---@param amount number
---@param cur_win number
function M._resize_up_native(amount, cur_win)
  if win.at_top_edge() then
    return
  end

  vim.cmd('wincmd k')

  while win.is_ignored_win() and not win.at_top_edge() do
    vim.cmd('wincmd k')
  end

  if not win.is_ignored_win() then
    pcall(vim.cmd, 'resize -' .. amount)
  end

  vim.api.nvim_set_current_win(cur_win)
end

---Native Neovim resize down: grow current window, stealing from below.
---@param amount number
---@param cur_win number
function M._resize_down_native(amount, cur_win)
  pcall(vim.cmd, 'resize +' .. amount)
end

return M
