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
  local target = winid or 0
  local height = vim.o.lines - vim.o.cmdheight
  local tabpages = #vim.api.nvim_list_tabpages()
  local wins = 0
  local tabpage = vim.api.nvim_win_get_tabpage(target)
  for _, listed_win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    if not M.is_floating(listed_win) then
      wins = wins + 1
    end
  end

  if (vim.o.laststatus == 1 and wins > 1) or vim.o.laststatus > 1 then
    height = height - 1
  end
  if (vim.o.showtabline == 1 and tabpages > 1) or vim.o.showtabline == 2 then
    height = height - 1
  end

  return vim.api.nvim_win_get_height(target) == height
end

---@param winid number|nil window ID, defaults to current
---@param callback function
---@return any
local function win_call(winid, callback)
  if winid == nil or winid == 0 or winid == vim.api.nvim_get_current_win() then
    return callback()
  end
  return vim.api.nvim_win_call(winid, callback)
end

---@param winid number|nil window ID, defaults to current
---@return boolean
function M.at_left_edge(winid)
  return win_call(winid, function()
    return vim.fn.winnr() == vim.fn.winnr('h')
  end)
end

---@param winid number|nil window ID, defaults to current
---@return boolean
function M.at_right_edge(winid)
  return win_call(winid, function()
    return vim.fn.winnr() == vim.fn.winnr('l')
  end)
end

---@param winid number|nil window ID, defaults to current
---@return boolean
function M.at_top_edge(winid)
  return win_call(winid, function()
    return vim.fn.winnr() == vim.fn.winnr('k')
  end)
end

---@param winid number|nil window ID, defaults to current
---@return boolean
function M.at_bottom_edge(winid)
  return win_call(winid, function()
    return vim.fn.winnr() == vim.fn.winnr('j')
  end)
end

---Determine where a window sits in the Neovim split layout
---for a given direction (horizontal or vertical).
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@param winid number|nil window ID, defaults to current
---@return '"start"'|'"middle"'|'"last"'
function M.win_position(direction, winid)
  if direction == 'left' or direction == 'right' then
    if M.at_left_edge(winid) then
      return 'start'
    end
    if M.at_right_edge(winid) then
      return 'last'
    end
    return 'middle'
  end

  if M.at_top_edge(winid) then
    return 'start'
  end
  if M.at_bottom_edge(winid) then
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

---Resolve an embedded float to the normal window that contains its layout.
---Only window-relative ancestry is followed; malformed or unsafe chains no-op.
---@param winid number|nil window ID, defaults to current
---@return number|nil
function M.resolve_embedded_parent(winid)
  local current = winid or vim.api.nvim_get_current_win()
  if current == 0 then
    current = vim.api.nvim_get_current_win()
  end

  local embedded_ok, embedded = pcall(M.is_embedded_floating_window, current)
  if not embedded_ok or not embedded then
    return nil
  end

  local tab_ok, tabpage = pcall(vim.api.nvim_win_get_tabpage, current)
  if not tab_ok then
    return nil
  end

  local visited = {}
  while true do
    if visited[current] then
      return nil
    end
    visited[current] = true

    local cfg_ok, cfg = pcall(vim.api.nvim_win_get_config, current)
    if not cfg_ok or type(cfg) ~= 'table' then
      return nil
    end
    if cfg.relative == '' then
      return current
    end
    if cfg.relative ~= 'win' or type(cfg.win) ~= 'number' or cfg.win <= 0 then
      return nil
    end

    local parent = cfg.win
    local valid_ok, valid = pcall(vim.api.nvim_win_is_valid, parent)
    if not valid_ok or not valid then
      return nil
    end
    local parent_tab_ok, parent_tab = pcall(vim.api.nvim_win_get_tabpage, parent)
    if not parent_tab_ok or parent_tab ~= tabpage then
      return nil
    end
    current = parent
  end
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

---Returns true while Neovim's command-line window (q:, q/, q?) is open.
---Inside it all window commands raise E11, so callers must short-circuit.
---@return boolean
function M.is_command_line_window()
  return vim.fn.getcmdwintype() ~= ''
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
