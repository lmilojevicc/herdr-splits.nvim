---Resize logic: seamless resize between Neovim splits and Herdr panes.
---When the Neovim window fills the terminal dimension, the resize is
---forwarded to Herdr using a ratio (config.default_amount). Otherwise,
---Neovim's native resize is used with integer cell counts (config.neovim_amount).
---@class HerdrSplitsResize
local M = {}

local config = require('herdr-splits.config')
local herdr = require('herdr-splits.herdr')
local win = require('herdr-splits.win')

M.is_resizing = false

---Resize in a direction. If the current Neovim window spans the full terminal
---width (for left/right) or height (for up/down), the resize is delegated to
---Herdr using the ratio amount. Otherwise, Neovim's native wincmd resize is
---used with integer cell counts.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@param amount number|nil Override amount (ratio for Herdr, cells for Neovim)
function M.resize(direction, amount)
  local count = vim.v.count1

  -- Floating windows: forward to Herdr
  if win.is_floating() then
    herdr.resize_pane(direction, amount or (count * config.default_amount))
    return
  end

  -- Horizontal resize: check if window fills terminal width
  if direction == 'left' or direction == 'right' then
    if win.is_full_width() and herdr.is_in_session() then
      herdr.resize_pane(direction, amount or (count * config.default_amount))
      return
    end
  end

  -- Vertical resize: check if window fills terminal height
  if direction == 'up' or direction == 'down' then
    if win.is_full_height() and herdr.is_in_session() then
      herdr.resize_pane(direction, amount or (count * config.default_amount))
      return
    end
  end

  -- Native Neovim resize (uses integer cell counts)
  local cells = amount or (count * config.neovim_amount)
  local cur_win = vim.api.nvim_get_current_win()

  if direction == 'left' then
    M._resize_left_native(cells, cur_win)
  elseif direction == 'right' then
    M._resize_right_native(cells, cur_win)
  elseif direction == 'up' then
    M._resize_up_native(cells, cur_win)
  elseif direction == 'down' then
    M._resize_down_native(cells, cur_win)
  end
end

---Native Neovim resize left: steal from the window on the left.
---We go to the left window, shrink it (vertical resize -N), then return.
---@param amount number Integer cell count
---@param cur_win number
function M._resize_left_native(amount, cur_win)
  if win.at_left_edge() then
    return
  end

  vim.cmd('wincmd h')

  while win.is_ignored_win() and not win.at_left_edge() do
    vim.cmd('wincmd h')
  end

  if not win.is_ignored_win() then
    pcall(vim.cmd, 'vertical resize -' .. math.floor(amount))
  end

  vim.api.nvim_set_current_win(cur_win)
end

---Native Neovim resize right: grow current window, stealing from the right.
---@param amount number Integer cell count
---@param cur_win number
function M._resize_right_native(amount, cur_win)
  pcall(vim.cmd, 'vertical resize +' .. math.floor(amount))
end

---Native Neovim resize up: steal from the window above.
---@param amount number Integer cell count
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
    pcall(vim.cmd, 'resize -' .. math.floor(amount))
  end

  vim.api.nvim_set_current_win(cur_win)
end

---Native Neovim resize down: grow current window, stealing from below.
---@param amount number Integer cell count
---@param cur_win number
function M._resize_down_native(amount, cur_win)
  if win.at_bottom_edge() then
    return
  end
  pcall(vim.cmd, 'resize +' .. math.floor(amount))
end

return M
