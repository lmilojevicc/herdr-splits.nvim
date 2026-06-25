---Resize logic: seamless resize between Neovim splits and Herdr panes.
---
---Mental model (same as smart-splits.nvim):
---  resize_left/up   → shrink current window, giving space in that direction
---  resize_right/down → grow current window, taking space from that direction
---
---When the Neovim window fills the terminal and is at the corresponding
---Neovim edge, the resize is forwarded to Herdr using a ratio.
---Otherwise Neovim native resize is used with integer cell counts.
---@class HerdrSplitsResize
local M = {}

local config = require('herdr-splits.config')
local herdr = require('herdr-splits.herdr')
local win = require('herdr-splits.win')

-- resize_left/up shrink current (-); resize_right/down grow current (+)
local resize_op = {
  left = '-',
  right = '+',
  up = '-',
  down = '+',
}

-- Whether a direction uses :vertical resize (true) or :resize (false)
local is_vertical = {
  left = true,
  right = true,
  up = false,
  down = false,
}

M.is_resizing = false

---Resize in a direction.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@param amount number|nil Override amount in Neovim cells.
---        When nil, uses vim.v.count1 * config.neovim_amount for native resize
---        or vim.v.count1 * config.default_amount for Herdr ratio.
function M.resize(direction, amount)
  local count = vim.v.count1
  local has_explicit = amount ~= nil

  -- Floating windows: forward to Herdr
  if win.is_floating() then
    local ratio = amount or (count * config.default_amount)
    herdr.resize_pane(direction, ratio)
    return
  end

  -- Decide: delegate to Herdr vs native Neovim resize.
  -- Delegate to Herdr ONLY when the window fills the terminal in that dimension
  -- AND is at the Neovim edge in the corresponding direction.
  local delegate_to_herdr = false

  if direction == 'left' or direction == 'right' then
    if win.is_full_width() and win.at_left_edge() and win.at_right_edge() then
      delegate_to_herdr = herdr.is_in_session()
    end
  elseif direction == 'up' or direction == 'down' then
    if win.is_full_height() and win.at_top_edge() and win.at_bottom_edge() then
      delegate_to_herdr = herdr.is_in_session()
    end
  end

  if delegate_to_herdr then
    -- Use ratio from config.default_amount (or explicit amount if provided as a ratio)
    local ratio
    if has_explicit and amount < 1 then
      -- Explicit amount < 1 → treat as ratio directly
      ratio = amount
    else
      ratio = count * config.default_amount
    end
    herdr.resize_pane(direction, ratio)
    return
  end

  -- Native Neovim resize using integer cell counts
  local cells = has_explicit and math.floor(amount) or (count * config.neovim_amount)
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
