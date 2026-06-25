---Window utility functions for Neovim split detection.
---@class HerdrSplitsWin
local M = {}

local config = require('herdr-splits.config')

---Check if the current window spans the full terminal width.
---@param winid number|nil window ID, defaults to current
---@return boolean
function M.is_full_width(winid)
  return vim.api.nvim_win_get_width(winid or 0) == vim.o.columns
end

---Check if the current window spans the full terminal height.
---Accounts for cmdheight, statusline, and tabline.
---@param winid number|nil window ID, defaults to current
---@return boolean
function M.is_full_height(winid)
  local height = vim.o.lines - vim.o.cmdheight
  local tabpages = #vim.api.nvim_list_tabpages()
  local wins = #vim.api.nvim_tabpage_list_wins(0)

  if (vim.o.laststatus == 1 and wins > 1) or vim.o.laststatus > 1 then
    height = height - 1
  end
  if (vim.o.showtabline == 1 and tabpages > 1) or vim.o.showtabline == 2 then
    height = height - 1
  end

  return vim.api.nvim_win_get_height(winid or 0) == height
end

---@return boolean
function M.at_left_edge()
  return vim.fn.winnr() == vim.fn.winnr('h')
end

---@return boolean
function M.at_right_edge()
  return vim.fn.winnr() == vim.fn.winnr('l')
end

---@return boolean
function M.at_top_edge()
  return vim.fn.winnr() == vim.fn.winnr('k')
end

---@return boolean
function M.at_bottom_edge()
  return vim.fn.winnr() == vim.fn.winnr('j')
end

---Determine where the current window sits in the Neovim split layout
---for a given direction (horizontal or vertical).
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@return '"start"'|'"middle"'|'"last"'
function M.win_position(direction)
  if direction == 'left' or direction == 'right' then
    if M.at_left_edge() then
      return 'start'
    end
    if M.at_right_edge() then
      return 'last'
    end
    return 'middle'
  end

  if M.at_top_edge() then
    return 'start'
  end
  if M.at_bottom_edge() then
    return 'last'
  end
  return 'middle'
end

---Check if a window should be ignored during resize operations.
---@param winid number|nil window ID, defaults to current
---@return boolean
function M.is_ignored_win(winid)
  local bufnr = vim.api.nvim_win_get_buf(winid or 0)
  return vim.tbl_contains(config.ignored_buftypes, vim.api.nvim_get_option_value('buftype', { buf = bufnr }))
    or vim.tbl_contains(config.ignored_filetypes, vim.api.nvim_get_option_value('filetype', { buf = bufnr }))
end

---Check if the current window is a floating window.
---@param winid number|nil
---@return boolean
function M.is_floating(winid)
  return vim.api.nvim_win_get_config(winid or 0).relative ~= ''
end

---Direction key shorthand for wincmd.
M.dir_keys = {
  left = 'h',
  right = 'l',
  up = 'k',
  down = 'j',
}

M.dir_keys_reverse = {
  left = 'l',
  right = 'h',
  up = 'j',
  down = 'k',
}

---Move to the next Neovim window in the given direction, handling count prefix.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@param wrap boolean Whether to allow wrapping to opposite side
function M.next_window(direction, wrap)
  local dir_key = M.dir_keys[direction]
  local count = vim.v.count1
  if wrap and count == 1 then
    -- Use large count to wrap to the opposite side
    count = 99999
  end
  vim.cmd(count .. 'wincmd ' .. dir_key)
end

return M
