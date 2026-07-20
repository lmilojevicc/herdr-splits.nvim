local T
local expect = MiniTest.expect
local child = MiniTest.new_child_neovim()

local source = debug.getinfo(1, 'S').source
local root = vim.fn.fnamemodify(source:sub(2), ':p:h:h')

T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '--noplugin', '-u', 'NONE', '-i', 'NONE' })
      child.cmd('set runtimepath^=' .. vim.fn.fnameescape(root))
    end,
    post_case = function()
      child.stop()
    end,
  },
})

T['uses the correct horizontal resize sign at both sides'] = function()
  local deltas = child.lua_func(function()
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return false end,
    }
    package.loaded['herdr-splits.resize'] = nil
    local resize = require('herdr-splits.resize')
    vim.o.equalalways = false
    vim.o.winminwidth = 1

    local function delta(side, direction)
      vim.cmd('only')
      vim.o.splitright = true
      vim.cmd('vsplit')
      local wins = vim.api.nvim_tabpage_list_wins(0)
      table.sort(wins, function(a, b)
        return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
      end)
      vim.api.nvim_set_current_win(wins[side == 'left' and 1 or 2])
      local before = vim.api.nvim_win_get_width(0)
      resize.resize(direction, 2)
      return vim.api.nvim_win_get_width(0) - before
    end

    return {
      left_left = delta('left', 'left'),
      left_right = delta('left', 'right'),
      right_left = delta('right', 'left'),
      right_right = delta('right', 'right'),
    }
  end)

  expect.equality(deltas, { left_left = -2, left_right = 2, right_left = 2, right_right = -2 })
end

T['uses the correct vertical resize sign at top and bottom'] = function()
  local deltas = child.lua_func(function()
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return false end,
    }
    package.loaded['herdr-splits.resize'] = nil
    local resize = require('herdr-splits.resize')
    vim.o.equalalways = false
    vim.o.winminheight = 1

    local function delta(side, direction)
      vim.cmd('only')
      vim.o.splitbelow = true
      vim.cmd('split')
      local wins = vim.api.nvim_tabpage_list_wins(0)
      table.sort(wins, function(a, b)
        return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
      end)
      vim.api.nvim_set_current_win(wins[side == 'top' and 1 or 2])
      local before = vim.api.nvim_win_get_height(0)
      resize.resize(direction, 2)
      return vim.api.nvim_win_get_height(0) - before
    end

    return {
      top_up = delta('top', 'up'),
      top_down = delta('top', 'down'),
      bottom_up = delta('bottom', 'up'),
      bottom_down = delta('bottom', 'down'),
    }
  end)

  expect.equality(deltas, { top_up = -2, top_down = 2, bottom_up = 2, bottom_down = -2 })
end

T['floors explicit cell amounts and clamps nonpositive values'] = function()
  local deltas = child.lua_func(function()
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return false end,
    }
    package.loaded['herdr-splits.resize'] = nil
    local resize = require('herdr-splits.resize')
    vim.o.equalalways = false
    vim.o.winminwidth = 1

    local function delta(amount)
      vim.cmd('only')
      vim.o.splitright = true
      vim.cmd('vsplit')
      local wins = vim.api.nvim_tabpage_list_wins(0)
      table.sort(wins, function(a, b)
        return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
      end)
      vim.api.nvim_set_current_win(wins[1])
      local before = vim.api.nvim_win_get_width(0)
      resize.resize('right', amount)
      return vim.api.nvim_win_get_width(0) - before
    end

    return { floored = delta(2.9), zero = delta(0), negative = delta(-4) }
  end)

  expect.equality(deltas, { floored = 2, zero = 1, negative = 1 })
end

T['multiplies native resize cells by the typed count'] = function()
  local before = child.lua_func(function()
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return false end,
    }
    package.loaded['herdr-splits.resize'] = nil
    local config = require('herdr-splits.config')
    config.neovim_amount = 2
    vim.o.equalalways = false
    vim.o.winminwidth = 1
    vim.o.splitright = true
    vim.cmd('vsplit')
    local wins = vim.api.nvim_tabpage_list_wins(0)
    table.sort(wins, function(a, b)
      return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
    end)
    vim.api.nvim_set_current_win(wins[1])
    vim.keymap.set('n', 'x', function()
      require('herdr-splits.resize').resize('right')
    end)
    return vim.api.nvim_win_get_width(0)
  end)

  child.type_keys('3x')
  local after = child.lua_get('vim.api.nvim_win_get_width(0)')
  expect.equality(after - before, 6)
end

T['delegates full-terminal ratios for defaults, counts, and explicit amounts'] = function()
  child.lua_func(function()
    _G.resize_calls = {}
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return true end,
      current_pane_is_zoomed = function() return false end,
      resize_pane = function(direction, amount)
        _G.resize_calls[#_G.resize_calls + 1] = { direction, amount }
        return true
      end,
    }
    package.loaded['herdr-splits.resize'] = nil
    local config = require('herdr-splits.config')
    config.default_amount = 0.03
    local resize = require('herdr-splits.resize')
    resize.resize('left')
    resize.resize('right', 0.2)
    resize.resize('left', 2)
    vim.keymap.set('n', 'x', function() resize.resize('right') end)
  end)

  child.type_keys('3x')
  local calls = child.lua_get('_G.resize_calls')
  expect.equality(calls, {
    { 'left', 0.03 },
    { 'right', 0.2 },
    { 'left', 0.03 },
    { 'right', 0.09 },
  })
end

T['delegates vertical full-terminal ratios using real geometry'] = function()
  local result = child.lua_func(function()
    local calls = {}
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return true end,
      current_pane_is_zoomed = function() return false end,
      resize_pane = function(direction, amount)
        calls[#calls + 1] = { direction, amount }
        return true
      end,
    }
    package.loaded['herdr-splits.resize'] = nil
    local config = require('herdr-splits.config')
    config.default_amount = 0.03
    local win = require('herdr-splits.win')
    local resize = require('herdr-splits.resize')

    local geometry = {
      full_height = win.is_full_height(),
      at_top = win.at_top_edge(),
      at_bottom = win.at_bottom_edge(),
    }
    resize.resize('up')
    resize.resize('down', 0.2)
    return { geometry = geometry, calls = calls }
  end)

  expect.equality(result, {
    geometry = { full_height = true, at_top = true, at_bottom = true },
    calls = { { 'up', 0.03 }, { 'down', 0.2 } },
  })
end

T['delegates normal floats but suppresses embedded, sidebar, and zoomed windows'] = function()
  local result = child.lua_func(function()
    local calls = {}
    local zoomed = false
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return true end,
      current_pane_is_zoomed = function() return zoomed end,
      resize_pane = function(direction, amount)
        calls[#calls + 1] = { direction, amount }
        return true
      end,
    }
    package.loaded['herdr-splits.resize'] = nil
    local resize = require('herdr-splits.resize')
    local base = vim.api.nvim_get_current_win()

    local normal = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
      relative = 'editor', row = 1, col = 1, width = 12, height = 3, zindex = 50,
    })
    resize.resize('right', 0.15)

    local embedded = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
      relative = 'editor', row = 2, col = 2, width = 12, height = 3, zindex = 49,
    })
    resize.resize('left')

    vim.api.nvim_set_current_win(base)
    vim.api.nvim_win_close(embedded, true)
    vim.api.nvim_win_close(normal, true)
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
    resize.resize('left')

    vim.api.nvim_set_option_value('buftype', '', { buf = bufnr })
    zoomed = true
    resize.resize('right')

    return { calls = calls, current = vim.api.nvim_get_current_win() == base }
  end)

  expect.equality(result, { calls = { { 'right', 0.15 } }, current = true })
end

T['command-line window horizontal resize delegates past the nofile sidebar rule'] = function()
  local result = child.lua_func(function()
    local calls = {}
    local cmdwin = true
    package.loaded['herdr-splits.win'] = {
      is_command_line_window = function() return cmdwin end,
      is_embedded_floating_window = function() return false end,
      is_floating = function() return false end,
      is_ignored_or_preview = function() return true end,
      is_full_width = function() return true end,
      is_full_height = function() return false end,
      at_left_edge = function() return true end,
      at_right_edge = function() return true end,
      at_top_edge = function() return true end,
      at_bottom_edge = function() return true end,
      win_position = function() return 'start' end,
    }
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return true end,
      current_pane_is_zoomed = function() return false end,
      resize_pane = function(direction, amount)
        calls[#calls + 1] = { direction, amount }
        return true
      end,
    }
    package.loaded['herdr-splits.resize'] = nil
    local config = require('herdr-splits.config')
    config.default_amount = 0.03
    local resize = require('herdr-splits.resize')

    -- cmdwin + full-width + nofile: horizontal resize delegates to Herdr
    cmdwin = true
    resize.resize('left')
    resize.resize('right', 0.2)

    -- ordinary nofile buffer (not cmdwin): sidebar rule still blocks delegation
    cmdwin = false
    resize.resize('left')

    return { calls = calls }
  end)

  expect.equality(result, {
    calls = { { 'left', 0.03 }, { 'right', 0.2 } },
  })
end

return T
