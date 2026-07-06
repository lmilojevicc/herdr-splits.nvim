---Resize logic: seamless resize between Neovim splits and Herdr panes.
---
---Mental model (same as smart-splits.nvim):
---  The direction (up/down/left/right) is which way to move the split border.
---  The +/- operator depends on whether current window is above/below or
---  left/right of the neighbor being resized against.
---
---When at a Neovim edge with no neighbor in that direction, and the window
---fills the terminal, the resize is forwarded to Herdr.
---@class HerdrSplitsResize
local M = {}

local config = require('herdr-splits.config')
local herdr = require('herdr-splits.herdr')
local win = require('herdr-splits.win')

M.is_resizing = false

---Compute the +/- operator for a vertical resize.
---At start/middle: resize_up shrinks (-), resize_down grows (+).
---At last (bottom): inverted — resize_up grows (+), resize_down shrinks (-).
---@param direction '"up"'|'"down"'
---@return '"+""'|'"-""'
local function compute_vertical(direction)
  local pos = win.win_position(direction)
  if pos == 'start' or pos == 'middle' then
    return direction == 'down' and '+' or '-'
  end
  return direction == 'down' and '-' or '+'
end

---Compute the +/- operator for a horizontal resize.
---At start/middle: resize_left shrinks (-), resize_right grows (+).
---At last (right): inverted — resize_left grows (+), resize_right shrinks (-).
---@param direction '"left"'|'"right"'
---@return '"+""'|'"-""'
local function compute_horizontal(direction)
  local pos = win.win_position(direction)
  if pos == 'start' or pos == 'middle' then
    return direction == 'right' and '+' or '-'
  end
  return direction == 'right' and '-' or '+'
end

---Resize in a direction.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@param amount number|nil Override amount in Neovim cells. When nil, uses
---        vim.v.count1 * neovim_amount for native or count * default_amount for Herdr.
function M.resize(direction, amount)
  local count = vim.v.count1
  local has_explicit = amount ~= nil

  -- Embedded floating sidebars (snacks float, neo-tree float, aerial float):
  -- refuse to resize; the picker owns its own dimensions.
  if win.is_embedded_floating_window() then
    return
  end

  -- Floating windows: forward to Herdr
  if win.is_floating() then
    local ratio = has_explicit and amount or (count * config.default_amount)
    herdr.resize_pane(direction, ratio)
    return
  end

  -- Delegate to Herdr ONLY when at both Neovim edges in this dimension
  -- AND the window fills the terminal (full_width or full_height).
  local delegate = false
  -- Never delegate from inside a sidebar; the ignore list applies to resize too.
  local in_sidebar = win.is_ignored_or_preview()
  if direction == 'left' or direction == 'right' then
    delegate = win.is_full_width() and win.at_left_edge() and win.at_right_edge() and herdr.is_in_session()
  else
    delegate = win.is_full_height() and win.at_top_edge() and win.at_bottom_edge() and herdr.is_in_session()
  end
  if delegate and in_sidebar then
    delegate = false
  end

  if delegate and herdr.current_pane_is_zoomed() then
    delegate = false
  end

  if delegate then
    local ratio = (has_explicit and amount < 1) and amount or (count * config.default_amount)
    herdr.resize_pane(direction, ratio)
    return
  end

  -- Native Neovim resize
  local cells = has_explicit and math.floor(amount) or (count * config.neovim_amount)
  if cells <= 0 then
    cells = 1
  end

  local is_horiz = direction == 'left' or direction == 'right'
  local op = is_horiz and compute_horizontal(direction) or compute_vertical(direction)

  if is_horiz then
    pcall(vim.cmd, 'vertical resize ' .. op .. cells)
  else
    pcall(vim.cmd, 'resize ' .. op .. cells)
  end
end

return M
