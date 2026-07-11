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

---Split a new Neovim window at the edge in the given direction.
---Temporarily overrides splitright/splitbelow to place the new window correctly.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
local function split_edge(direction)
  if direction == 'left' or direction == 'right' then
    local orig_splitright = vim.opt.splitright:get()
    if direction == 'left' then
      vim.opt.splitright = false
      vim.cmd('vsp')
      vim.opt.splitright = orig_splitright
    else
      vim.cmd('vsp')
      if orig_splitright then
        vim.cmd('wincmd h')
      end
    end
  else
    local orig_splitbelow = vim.opt.splitbelow:get()
    if direction == 'up' then
      vim.opt.splitbelow = false
      vim.cmd('sp')
      vim.opt.splitbelow = orig_splitbelow
    else
      vim.cmd('sp')
      if orig_splitbelow then
        vim.cmd('wincmd k')
      end
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

  -- Handle floating windows: just forward to Herdr,
  -- EXCEPT for embedded sidebars (snacks/neo-tree float/aerial float):
  -- those should stay in Neovim so the user can keep interacting
  -- with the picker.
  if win.is_floating() and not win.is_embedded_floating_window() then
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
    vim.cmd('wincmd ' .. dir_key)
  else
    vim.cmd(count .. 'wincmd ' .. dir_key)
  end

  if vim.api.nvim_get_current_win() ~= prev_win then
    -- Moved within Neovim. Restore same-row if configured.
    if (direction == 'left' or direction == 'right') and same_row then
      local row = offset - vim.api.nvim_win_get_position(0)[1]
      if row > 0 then
        vim.cmd('normal! ' .. row .. 'H')
      end
    end
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
          wrap = function()
            vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
          end,
        })
      elseif at_edge_behavior == 'stop' then
        return
      elseif at_edge_behavior == 'split' then
        if not sidebar then
          split_edge(direction)
        end
      else -- 'wrap' (default)
        -- Wrap is allowed even from filetype-based sidebars (dbui, neo-tree,
        -- ...) so the user can leave them; only embedded floats stay gated.
        if not win.is_embedded_floating_window() then
          vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
        end
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
    -- Retry wincmd — other Neovim splits may now be visible
    vim.cmd('wincmd ' .. dir_key)
    if vim.api.nvim_get_current_win() ~= prev_win then
      if (direction == 'left' or direction == 'right') and same_row then
        local row = offset - vim.api.nvim_win_get_position(0)[1]
        if row > 0 then
          vim.cmd('normal! ' .. row .. 'H')
        end
      end
      return
    end
    -- Still at edge after unzoom; fall through to Herdr edge check.
  end

  -- Check if we're at the Herdr edge too
  local at_herdr_edge = herdr.current_pane_at_edge(direction)
  if at_herdr_edge == nil then
    if will_wrap and count == 1 and not win.is_embedded_floating_window() then
      vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
    end
    return
  end

  if not at_herdr_edge then
    -- There's a Herdr pane in this direction. Cross the boundary.
    local moved = herdr.focus_pane(direction)
    if not moved and will_wrap and count == 1 and not win.is_embedded_floating_window() then
      vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
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
      wrap = function()
        vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
      end,
    })
  elseif at_edge_behavior == 'stop' then
    return
  elseif at_edge_behavior == 'split' then
    if not is_sidebar() then
      split_edge(direction)
    end
  else -- 'wrap' (default)
    -- Wrap is allowed from filetype-based sidebars (dbui, neo-tree, ...) so
    -- you can leave them at an edge; only embedded floating overlays stay gated.
    if will_wrap and count == 1 and not win.is_embedded_floating_window() then
      -- Wrap to the opposite side. If a Herdr pane exists there AND nav_at_edge
      -- allows wrap-across-boundary (the default), cross into it; otherwise
      -- wrap within Neovim. nav_at_edge=stop keeps the wrap inside Neovim.
      if herdr.nav_at_edge() ~= 'stop'
          and herdr.current_pane_at_edge(win.reverse_direction[direction]) == false
      then
        herdr.focus_pane(win.reverse_direction[direction])
      else
        vim.cmd('wincmd ' .. win.dir_keys_reverse[direction])
      end
    end
  end
end

return M
