---Navigation logic: seamless movement between Neovim splits and Herdr panes.
---@class HerdrSplitsNav
local M = {}

local config = require('herdr-splits.config')
local herdr = require('herdr-splits.herdr')
local win = require('herdr-splits.win')

---Split a new Neovim window at the edge in the given direction.
---Respects 'splitright' and 'splitbelow' options.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
local function split_edge(direction)
  if direction == 'left' or direction == 'right' then
    vim.cmd('vsp')
    if vim.opt.splitright:get() and direction == 'left' then
      vim.cmd('wincmd h')
    end
  else
    vim.cmd('sp')
    if vim.opt.splitbelow:get() and direction == 'up' then
      vim.cmd('wincmd k')
    end
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

  -- Handle floating windows: just forward to Herdr
  if win.is_floating() then
    herdr.focus_pane(direction)
    return
  end

  local dir_key = win.dir_keys[direction]
  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]

  -- Save current window to detect if wincmd changes it
  local prev_win = vim.api.nvim_get_current_win()

  -- Try moving within Neovim first
  local will_wrap = false
  local count = vim.v.count1
  local target_winnr = vim.fn.winnr(count .. dir_key)
  if count > 1 then
    local prev_winnr = vim.fn.winnr((count - 1) .. dir_key)
    will_wrap = target_winnr == prev_winnr
  else
    will_wrap = target_winnr == vim.fn.winnr()
  end

  -- Execute the wincmd
  if will_wrap and count == 1 then
    -- Don't wrap yet, we might want to go to Herdr instead
    vim.cmd('wincmd ' .. dir_key)
  else
    vim.cmd(count .. 'wincmd ' .. dir_key)
  end

  if vim.api.nvim_get_current_win() ~= prev_win then
    -- Moved within Neovim. Restore same-row if configured.
    if (direction == 'left' or direction == 'right') and same_row then
      offset = offset - vim.api.nvim_win_get_position(0)[1]
      vim.cmd('normal! ' .. offset .. 'H')
    end
    return
  end

  -- We're at a Neovim edge. Try to cross into Herdr.
  if not herdr.is_in_session() then
    -- Not in Herdr: apply at_edge behavior within Neovim
    if will_wrap and count == 1 then
      if type(at_edge_behavior) == 'function' then
        at_edge_behavior({
          direction = direction,
          split = function() split_edge(direction) end,
          wrap = function()
            local reverse_key = win.dir_keys_reverse[direction]
            vim.cmd('wincmd ' .. reverse_key)
          end,
        })
      elseif at_edge_behavior == 'stop' then
        return
      elseif at_edge_behavior == 'split' then
        if not win.is_ignored_win() then
          split_edge(direction)
        end
      else -- 'wrap' (default)
        local reverse_key = win.dir_keys_reverse[direction]
        vim.cmd('wincmd ' .. reverse_key)
      end
    end
    return
  end

  -- Check zoom state
  if config.disable_nav_when_zoomed and herdr.current_pane_is_zoomed() then
    if will_wrap and count == 1 then
      vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
    end
    return
  end

  -- Check if we're at the Herdr edge too
  local at_herdr_edge = herdr.current_pane_at_edge(direction)
  if at_herdr_edge == nil then
    -- Error querying Herdr. Fall back to at_edge behavior.
    if will_wrap and count == 1 then
      vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
    end
    return
  end

  if not at_herdr_edge then
    -- There's a Herdr pane in this direction. Cross the boundary.
    local moved = herdr.focus_pane(direction)
    if not moved and will_wrap and count == 1 then
      -- Herdr focus failed, wrap within Neovim
      vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
    end
    return
  end

  -- At both Neovim AND Herdr edges. Apply at_edge behavior.
  if type(at_edge_behavior) == 'function' then
    at_edge_behavior({
      direction = direction,
      split = function() split_edge(direction) end,
      wrap = function()
        vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
      end,
    })
  elseif at_edge_behavior == 'stop' then
    return
  elseif at_edge_behavior == 'split' then
    if not win.is_ignored_win() then
      split_edge(direction)
    end
  else -- 'wrap' (default)
    if will_wrap and count == 1 then
      vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
    end
  end
end

return M
