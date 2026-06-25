---Resize logic: seamless resize between Neovim splits and Herdr panes.
---
---Mental model (same as smart-splits.nvim):
---  resize_left/up   → shrink current window, giving space in that direction
---  resize_right/down → grow current window, taking space from that direction
---
---When the Neovim window fills the terminal dimension, the resize is
---forwarded to Herdr using a ratio. Otherwise Neovim native resize is used.
---@class HerdrSplitsResize
local M = {}

local config = require('herdr-splits.config')
local herdr = require('herdr-splits.herdr')
local win = require('herdr-splits.win')

---Direction → wincmd resize operator.
---resize_left/up shrink current (-); resize_right/down grow current (+).
local resize_op = {
  left = '-',
  right = '+',
  up = '-',
  down = '+',
}

---Whether a direction uses vertical (horizontal) or plain (vertical) resize.
local is_vertical = {
  left = true,
  right = true,
  up = false,
  down = false,
}

M.is_resizing = false

---Resize in a direction.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@param amount number|nil Override amount (ratio for Herdr, cells for Neovim)
function M.resize(direction, amount)
  local count = vim.v.count1

  -- Floating windows: forward to Herdr
  if win.is_floating() then
    herdr.resize_pane(direction, amount or (count * config.default_amount))
    return
  end

  -- Horizontal resize: if window fills terminal width, delegate to Herdr
  if direction == 'left' or direction == 'right' then
    if win.is_full_width() and herdr.is_in_session() then
      herdr.resize_pane(direction, amount or (count * config.default_amount))
      return
    end
  end

  -- Vertical resize: if window fills terminal height, delegate to Herdr
  if direction == 'up' or direction == 'down' then
    if win.is_full_height() and herdr.is_in_session() then
      herdr.resize_pane(direction, amount or (count * config.default_amount))
      return
    end
  end

  -- Native Neovim resize
  local cells = math.floor(amount or (count * config.neovim_amount))
  if cells <= 0 then
    cells = 1
  end

  local op = resize_op[direction]

  if is_vertical[direction] then
    pcall(vim.cmd, 'vertical resize ' .. op .. cells)
  else
    pcall(vim.cmd, 'resize ' .. op .. cells)
  end
end

return M
