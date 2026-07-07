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

---Check if a window is an "embedded" floating window — one that is technically
---floating (relative ~= '') but visually behaves like a sidebar (e.g. snacks
---explorer). Neovim's default floating zindex is 50; anything explicitly set
---below that signals the window is meant to coexist with normal splits.
---@param winid number|nil window ID, defaults to current
---@return boolean
function M.is_embedded_floating_window(winid)
  if not M.is_floating(winid) then
    return false
  end
  local cfg = vim.api.nvim_win_get_config(winid or 0)
  local threshold = config.floating_zindex_max or 50
  return cfg.zindex ~= nil and cfg.zindex < threshold
end

---Same as M.is_ignored_win but also checks previewwindow when opt-in.
---@param winid number|nil window ID, defaults to current
---@return boolean
function M.is_ignored_or_preview(winid)
  if M.is_ignored_win(winid) then
    return true
  end
  if config.ignore_previewwindows then
    local ok, pw = pcall(vim.api.nvim_win_get_option, winid or 0, 'previewwindow')
    if ok and pw then
      return true
    end
  end
  return false
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

---Reverse of a direction name: left<->right, up<->down.
M.reverse_direction = {
  left = 'right',
  right = 'left',
  up = 'down',
  down = 'up',
}

return M
