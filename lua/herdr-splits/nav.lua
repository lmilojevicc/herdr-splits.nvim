---Navigation logic: seamless movement between Neovim splits and Herdr panes.
---@class HerdrSplitsNav
local M = {}

local config = require('herdr-splits.config')
local herdr = require('herdr-splits.herdr')
local win = require('herdr-splits.win')

---Treat the current window as a sidebar that should not be navigated through.
---Combines the configured ignore lists with the embedded-float heuristic.
---@return boolean
local function is_sidebar()
  return win.is_ignored_or_preview() or win.is_embedded_floating_window()
end

---Split a new Neovim window using the user's placement preferences.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
local function split_edge(direction)
  if direction == 'left' or direction == 'right' then
    vim.cmd('vsp')
  else
    vim.cmd('sp')
  end
end

---@param winid number
---@param callback function
---@return any
local function call_in_window(winid, callback)
  if winid == vim.api.nvim_get_current_win() then
    return callback()
  end
  local ok, result = pcall(vim.api.nvim_win_call, winid, callback)
  if ok then
    return result
  end
end

---@param winid number
---@param key string
---@param count number
---@return number|nil, number|nil, number|nil
local function layout_winnrs(winid, key, count)
  local result = call_in_window(winid, function()
    local current = vim.fn.winnr()
    return {
      target = vim.fn.winnr(count .. key),
      previous = count > 1 and vim.fn.winnr((count - 1) .. key) or current,
      current = current,
    }
  end)
  if result then
    return result.target, result.previous, result.current
  end
end

---Move cursor between Neovim splits, falling through to Herdr at edges.
---This is the core navigation function.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@param opts table|nil { same_row: boolean|nil, at_edge: string|function|nil }
function M.move_cursor(direction, opts)
  local same_row = config.move_cursor_same_row
  local at_edge_behavior = config.at_edge

  if type(opts) == 'table' then
    if opts.same_row ~= nil then
      same_row = opts.same_row
    end
    if opts.at_edge ~= nil then
      at_edge_behavior = opts.at_edge
    end
  end

  local embedded = win.is_embedded_floating_window()
  if win.is_floating() and not embedded then
    herdr.focus_pane(direction)
    return
  end

  local dir_key = win.dir_keys[direction]
  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  local prev_win = vim.api.nvim_get_current_win()
  local geometry_win = prev_win
  if embedded then
    geometry_win = win.resolve_embedded_parent(prev_win)
    if not geometry_win then
      return
    end
  end

  local count = vim.v.count1
  local target_winnr, previous_winnr, current_winnr = layout_winnrs(geometry_win, dir_key, count)
  if not target_winnr then
    return
  end
  local will_wrap
  if count > 1 then
    will_wrap = target_winnr == previous_winnr
  else
    will_wrap = target_winnr == current_winnr
  end

  local function restore_same_row()
    if (direction == 'left' or direction == 'right') and same_row then
      local row = offset - vim.api.nvim_win_get_position(0)[1]
      if row > 0 then
        vim.cmd('normal! ' .. row .. 'H')
      end
    end
  end

  local function move_local(key, move_count)
    if not embedded then
      local before = vim.api.nvim_get_current_win()
      vim.cmd(move_count .. 'wincmd ' .. key)
      return vim.api.nvim_get_current_win() ~= before
    end

    local target = call_in_window(geometry_win, function()
      return vim.fn.win_getid(vim.fn.winnr(move_count .. key))
    end)
    if not target or target == geometry_win then
      return false
    end
    local ok = pcall(vim.api.nvim_set_current_win, target)
    return ok and vim.api.nvim_get_current_win() == target
  end

  local function wrap_local()
    return move_local(win.dir_keys_reverse[direction], 1)
  end

  -- Command-line window (q:, q/, q?): Neovim forbids all window commands
  -- (E11). Never wincmd; at a Neovim screen edge, delegate to Herdr
  -- (subprocess-safe, does not close the cmdwin); otherwise silent no-op.
  -- Mirrors smart-splits.nvim PR #464.
  if win.is_command_line_window() then
    if will_wrap and herdr.is_in_session() then
      local at_herdr_edge = herdr.current_pane_at_edge(direction)
      if at_herdr_edge == false then
        herdr.focus_pane(direction)
      elseif at_herdr_edge == true and herdr.nav_at_edge() ~= 'stop' then
        herdr.focus_pane(win.reverse_direction[direction])
      end
    end
    return
  end

  if move_local(dir_key, count) then
    restore_same_row()
    return
  end

  -- We're at a Neovim edge. Try to cross into Herdr.
  if not herdr.is_in_session() then
    if will_wrap and count == 1 then
      local sidebar = is_sidebar()
      if type(at_edge_behavior) == 'function' then
        at_edge_behavior({
          direction = direction,
          split = function() split_edge(direction) end,
          is_sidebar = sidebar,
          wrap = wrap_local,
        })
      elseif at_edge_behavior == 'stop' then
        return
      elseif at_edge_behavior == 'split' then
        if not sidebar then
          split_edge(direction)
        end
      else -- 'wrap' (default)
        wrap_local()
      end
    end
    return
  end

  -- Check zoom state: unzoom first, then retry Neovim navigation.
  -- Must happen BEFORE the at_herdr_edge check — when zoomed, the pane fills
  -- the screen so herdr reports it as being at every edge, making
  -- at_herdr_edge useless until we unzoom.
  if herdr.unzoom_enabled() and herdr.current_pane_is_zoomed() then
    herdr.unzoom()
    if embedded then
      geometry_win = win.resolve_embedded_parent(prev_win)
      if not geometry_win then
        return
      end
    end
    if move_local(dir_key, 1) then
      restore_same_row()
      return
    end
    -- Still at edge after unzoom; fall through to Herdr edge check.
  end

  -- Check if we're at the Herdr edge too
  local at_herdr_edge = herdr.current_pane_at_edge(direction)
  if at_herdr_edge == nil then
    if will_wrap and count == 1 then
      wrap_local()
    end
    return
  end

  if not at_herdr_edge then
    -- There's a Herdr pane in this direction. Cross the boundary.
    local moved = herdr.focus_pane(direction)
    if not moved and will_wrap and count == 1 then
      wrap_local()
    end
    return
  end

  -- At both Neovim AND Herdr edges (no herdr pane to cross into).
  -- Apply at_edge behavior. (Any needed unzoom already happened above.)
  if type(at_edge_behavior) == 'function' then
    at_edge_behavior({
      direction = direction,
      split = function() split_edge(direction) end,
      is_sidebar = is_sidebar(),
      wrap = wrap_local,
    })
  elseif at_edge_behavior == 'stop' then
    return
  elseif at_edge_behavior == 'split' then
    if not is_sidebar() then
      split_edge(direction)
    end
  else -- 'wrap' (default)
    if will_wrap and count == 1 then
      -- Wrap to the opposite side. If a Herdr pane exists there AND nav_at_edge
      -- allows wrap-across-boundary (the default), cross into it; otherwise
      -- wrap within Neovim. nav_at_edge=stop keeps the wrap inside Neovim.
      if herdr.nav_at_edge() ~= 'stop'
          and herdr.current_pane_at_edge(win.reverse_direction[direction]) == false
      then
        herdr.focus_pane(win.reverse_direction[direction])
      else
        wrap_local()
      end
    end
  end
end

return M
