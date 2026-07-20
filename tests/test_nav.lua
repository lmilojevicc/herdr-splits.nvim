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

T['moves through native horizontal and vertical splits without delegation'] = function()
  local result = child.lua_func(function()
    local calls = {}
    package.loaded['herdr-splits.herdr'] = {
      focus_pane = function(direction) calls[#calls + 1] = direction end,
      is_in_session = function() return false end,
    }
    package.loaded['herdr-splits.nav'] = nil
    local nav = require('herdr-splits.nav')

    vim.o.splitright = true
    vim.cmd('vsplit')
    local horizontal = vim.api.nvim_tabpage_list_wins(0)
    table.sort(horizontal, function(a, b)
      return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
    end)
    vim.api.nvim_set_current_win(horizontal[1])
    nav.move_cursor('right')
    local moved_right = vim.api.nvim_get_current_win() == horizontal[2]

    vim.cmd('only')
    vim.o.splitbelow = true
    vim.cmd('split')
    local vertical = vim.api.nvim_tabpage_list_wins(0)
    table.sort(vertical, function(a, b)
      return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
    end)
    vim.api.nvim_set_current_win(vertical[1])
    nav.move_cursor('down')
    local moved_down = vim.api.nvim_get_current_win() == vertical[2]

    return { moved_right = moved_right, moved_down = moved_down, calls = calls }
  end)

  expect.equality(result, { moved_right = true, moved_down = true, calls = {} })
end

T['applies typed navigation counts without wrapping or delegation'] = function()
  child.lua_func(function()
    _G.nav_delegations = {}
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return false end,
      focus_pane = function(direction)
        _G.nav_delegations[#_G.nav_delegations + 1] = direction
        return true
      end,
    }
    package.loaded['herdr-splits.nav'] = nil
    local nav = require('herdr-splits.nav')

    vim.o.splitright = true
    for _ = 1, 3 do
      vim.cmd('vsplit')
    end
    _G.nav_count_wins = vim.api.nvim_tabpage_list_wins(0)
    table.sort(_G.nav_count_wins, function(a, b)
      return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
    end)
    vim.api.nvim_set_current_win(_G.nav_count_wins[1])
    vim.keymap.set('n', 'x', function()
      nav.move_cursor('right', { at_edge = 'stop' })
    end)
  end)

  child.type_keys('2x')
  local after_two = child.lua_get('vim.api.nvim_get_current_win() == _G.nav_count_wins[3]')
  child.type_keys('5x')
  local exhausted_at_last = child.lua_get('vim.api.nvim_get_current_win() == _G.nav_count_wins[4]')
  child.type_keys('5x')
  local stayed_at_last = child.lua_get('vim.api.nvim_get_current_win() == _G.nav_count_wins[4]')
  local delegations = child.lua_get('_G.nav_delegations')

  expect.equality({
    after_two = after_two,
    exhausted_at_last = exhausted_at_last,
    stayed_at_last = stayed_at_last,
    delegations = delegations,
  }, {
    after_two = true,
    exhausted_at_last = true,
    stayed_at_last = true,
    delegations = {},
  })
end

T['delegates normal floats but not embedded floats'] = function()
  local result = child.lua_func(function()
    local calls = {}
    package.loaded['herdr-splits.herdr'] = {
      focus_pane = function(direction)
        calls[#calls + 1] = direction
        return true
      end,
      is_in_session = function() return false end,
    }
    package.loaded['herdr-splits.nav'] = nil
    local nav = require('herdr-splits.nav')

    local normal = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
      relative = 'editor', row = 1, col = 1, width = 12, height = 3, zindex = 50,
    })
    nav.move_cursor('right')
    local normal_stayed = vim.api.nvim_get_current_win() == normal

    vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
      relative = 'editor', row = 2, col = 2, width = 12, height = 3, zindex = 49,
    })
    nav.move_cursor('left')

    return { calls = calls, normal_stayed = normal_stayed }
  end)

  expect.equality(result, {
    calls = { 'right' },
    normal_stayed = true,
  })
end

T['applies no-session stop, wrap, and callback edge behavior'] = function()
  local result = child.lua_func(function()
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return false end,
    }
    package.loaded['herdr-splits.nav'] = nil
    local nav = require('herdr-splits.nav')

    local function horizontal_pair()
      vim.cmd('only')
      vim.o.splitright = true
      vim.cmd('vsplit')
      local wins = vim.api.nvim_tabpage_list_wins(0)
      table.sort(wins, function(a, b)
        return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
      end)
      vim.api.nvim_set_current_win(wins[1])
      return wins
    end

    local stop_wins = horizontal_pair()
    nav.move_cursor('left', { at_edge = 'stop' })
    local stopped = vim.api.nvim_get_current_win() == stop_wins[1]

    local wrap_wins = horizontal_pair()
    nav.move_cursor('left', { at_edge = 'wrap' })
    local wrapped = vim.api.nvim_get_current_win() == wrap_wins[2]

    local callback_wins = horizontal_pair()
    local callback = {}
    nav.move_cursor('left', {
      at_edge = function(ctx)
        callback.direction = ctx.direction
        callback.is_sidebar = ctx.is_sidebar
        callback.has_split = type(ctx.split) == 'function'
        callback.has_wrap = type(ctx.wrap) == 'function'
        ctx.wrap()
      end,
    })
    callback.wrapped = vim.api.nvim_get_current_win() == callback_wins[2]

    return {
      stopped = stopped,
      wrapped = wrapped,
      callback = callback,
    }
  end)

  expect.equality(result, {
    stopped = true,
    wrapped = true,
    callback = {
      direction = 'left',
      is_sidebar = false,
      has_split = true,
      has_wrap = true,
      wrapped = true,
    },
  })
end

T['creates local edge splits and preserves split preferences'] = function()
  local result = child.lua_func(function()
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return false end,
    }
    package.loaded['herdr-splits.nav'] = nil
    local nav = require('herdr-splits.nav')
    local cases = {}

    local function exercise(direction, preference)
      vim.cmd('only')
      vim.o.splitright = preference
      vim.o.splitbelow = preference
      local before = #vim.api.nvim_tabpage_list_wins(0)
      local original = vim.api.nvim_get_current_win()

      nav.move_cursor(direction, { at_edge = 'split' })

      local current = vim.api.nvim_get_current_win()
      local original_position = vim.api.nvim_win_get_position(original)
      local current_position = vim.api.nvim_win_get_position(current)
      local placement_matches_preference
      if direction == 'left' or direction == 'right' then
        if preference then
          placement_matches_preference = current_position[2] > original_position[2]
        else
          placement_matches_preference = current_position[2] < original_position[2]
        end
      elseif preference then
        placement_matches_preference = current_position[1] > original_position[1]
      else
        placement_matches_preference = current_position[1] < original_position[1]
      end

      cases[#cases + 1] = {
        direction = direction,
        preference = preference,
        created_one = #vim.api.nvim_tabpage_list_wins(0) == before + 1,
        focused_new = current ~= original,
        placement_matches_preference = placement_matches_preference,
        splitright_restored = vim.o.splitright == preference,
        splitbelow_restored = vim.o.splitbelow == preference,
      }
    end

    for _, direction in ipairs({ 'left', 'right', 'up', 'down' }) do
      exercise(direction, false)
      exercise(direction, true)
    end
    return cases
  end)

  local expected = {}
  for _, direction in ipairs({ 'left', 'right', 'up', 'down' }) do
    for _, preference in ipairs({ false, true }) do
      expected[#expected + 1] = {
        direction = direction,
        preference = preference,
        created_one = true,
        focused_new = true,
        placement_matches_preference = true,
        splitright_restored = true,
        splitbelow_restored = true,
      }
    end
  end
  expect.equality(result, expected)
end

T['uses Herdr neighbors and falls back locally on focus or edge failures'] = function()
  local result = child.lua_func(function()
    local edge_queue = { false, false, '<nil>' }
    local focus_queue = { true, false }
    local calls = {}
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return true end,
      unzoom_enabled = function() return false end,
      current_pane_at_edge = function(direction)
        calls[#calls + 1] = 'edge:' .. direction
        local value = table.remove(edge_queue, 1)
        if value == '<nil>' then return nil end
        return value
      end,
      focus_pane = function(direction)
        calls[#calls + 1] = 'focus:' .. direction
        return table.remove(focus_queue, 1)
      end,
    }
    package.loaded['herdr-splits.nav'] = nil
    local nav = require('herdr-splits.nav')

    local function at_left()
      vim.cmd('only')
      vim.o.splitright = true
      vim.cmd('vsplit')
      local wins = vim.api.nvim_tabpage_list_wins(0)
      table.sort(wins, function(a, b)
        return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
      end)
      vim.api.nvim_set_current_win(wins[1])
      return wins
    end

    local success_wins = at_left()
    nav.move_cursor('left')
    local focus_success_stays = vim.api.nvim_get_current_win() == success_wins[1]

    local failure_wins = at_left()
    nav.move_cursor('left')
    local focus_failure_wraps = vim.api.nvim_get_current_win() == failure_wins[2]

    local unknown_wins = at_left()
    nav.move_cursor('left')
    local unknown_wraps = vim.api.nvim_get_current_win() == unknown_wins[2]

    return {
      focus_success_stays = focus_success_stays,
      focus_failure_wraps = focus_failure_wraps,
      unknown_wraps = unknown_wraps,
      calls = calls,
    }
  end)

  expect.equality(result, {
    focus_success_stays = true,
    focus_failure_wraps = true,
    unknown_wraps = true,
    calls = {
      'edge:left', 'focus:left',
      'edge:left', 'focus:left',
      'edge:left',
    },
  })
end

T['unzooms and retries native movement before querying Herdr edges'] = function()
  local result = child.lua_func(function()
    local calls = {}
    local start_win = vim.api.nvim_get_current_win()
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return true end,
      unzoom_enabled = function() return true end,
      current_pane_is_zoomed = function()
        calls[#calls + 1] = 'zoomed'
        return true
      end,
      unzoom = function()
        calls[#calls + 1] = 'unzoom'
        local old_splitright = vim.o.splitright
        vim.o.splitright = true
        vim.cmd('vsplit')
        vim.api.nvim_set_current_win(start_win)
        vim.o.splitright = old_splitright
        return true
      end,
      current_pane_at_edge = function()
        calls[#calls + 1] = 'edge'
        return false
      end,
      focus_pane = function()
        calls[#calls + 1] = 'focus'
        return true
      end,
    }
    package.loaded['herdr-splits.nav'] = nil
    require('herdr-splits.nav').move_cursor('right')

    return {
      moved = vim.api.nvim_get_current_win() ~= start_win,
      windows = #vim.api.nvim_tabpage_list_wins(0),
      calls = calls,
    }
  end)

  expect.equality(result, { moved = true, windows = 2, calls = { 'zoomed', 'unzoom' } })
end

T['wraps through the reverse Herdr neighbor unless nav_at_edge stops it'] = function()
  local result = child.lua_func(function()
    local mode = 'wrap'
    local calls = {}
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return true end,
      unzoom_enabled = function() return false end,
      current_pane_at_edge = function(direction)
        calls[#calls + 1] = 'edge:' .. direction
        return direction == 'left'
      end,
      nav_at_edge = function() return mode end,
      focus_pane = function(direction)
        calls[#calls + 1] = 'focus:' .. direction
        return true
      end,
    }
    package.loaded['herdr-splits.nav'] = nil
    local nav = require('herdr-splits.nav')

    local function at_left()
      vim.cmd('only')
      vim.o.splitright = true
      vim.cmd('vsplit')
      local wins = vim.api.nvim_tabpage_list_wins(0)
      table.sort(wins, function(a, b)
        return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
      end)
      vim.api.nvim_set_current_win(wins[1])
      return wins
    end

    local herdr_wrap_wins = at_left()
    nav.move_cursor('left')
    local herdr_wrap_stays = vim.api.nvim_get_current_win() == herdr_wrap_wins[1]

    mode = 'stop'
    local local_wrap_wins = at_left()
    nav.move_cursor('left')
    local local_wraps = vim.api.nvim_get_current_win() == local_wrap_wins[2]

    return { herdr_wrap_stays = herdr_wrap_stays, local_wraps = local_wraps, calls = calls }
  end)

  expect.equality(result, {
    herdr_wrap_stays = true,
    local_wraps = true,
    calls = { 'edge:left', 'edge:right', 'focus:right', 'edge:left' },
  })
end

T['command-line window delegates to Herdr at the screen edge and never wincmds'] = function()
  local result = child.lua_func(function()
    local calls = {}
    local edge = false
    local nav_mode = 'wrap'
    package.loaded['herdr-splits.win'] = {
      is_command_line_window = function() return true end,
      is_floating = function() return false end,
      is_embedded_floating_window = function() return false end,
      is_ignored_or_preview = function() return false end,
      dir_keys = { left = 'h', right = 'l', up = 'k', down = 'j' },
      dir_keys_reverse = { left = 'l', right = 'h', up = 'j', down = 'k' },
      reverse_direction = { left = 'right', right = 'left', up = 'down', down = 'up' },
    }
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return true end,
      current_pane_at_edge = function(direction)
        calls[#calls + 1] = 'edge:' .. direction
        return edge
      end,
      nav_at_edge = function() return nav_mode end,
      focus_pane = function(direction)
        calls[#calls + 1] = 'focus:' .. direction
        return true
      end,
    }
    package.loaded['herdr-splits.nav'] = nil
    local nav = require('herdr-splits.nav')

    -- single window: will_wrap is true in every direction, mirroring the
    -- full-width/bottom command-line window geometry.
    vim.cmd('only')

    edge = false
    nav.move_cursor('left')
    local c1 = vim.deepcopy(calls); calls = {}

    edge = true
    nav_mode = 'wrap'
    nav.move_cursor('right')
    local c2 = vim.deepcopy(calls); calls = {}

    nav_mode = 'stop'
    nav.move_cursor('right')
    local c3 = vim.deepcopy(calls)

    return { neighbor = c1, wrap_reverse = c2, stop_noop = c3 }
  end)

  expect.equality(result, {
    neighbor = { 'edge:left', 'focus:left' },
    wrap_reverse = { 'edge:right', 'focus:left' },
    stop_noop = { 'edge:right' },
  })
end

T['command-line window no-ops silently when not at a screen edge'] = function()
  local result = child.lua_func(function()
    package.loaded['herdr-splits.win'] = {
      is_command_line_window = function() return true end,
      is_floating = function() return false end,
      is_embedded_floating_window = function() return false end,
      is_ignored_or_preview = function() return false end,
      dir_keys = { left = 'h', right = 'l', up = 'k', down = 'j' },
      dir_keys_reverse = { left = 'l', right = 'h', up = 'j', down = 'k' },
      reverse_direction = { left = 'right', right = 'left', up = 'down', down = 'up' },
    }
    local focused = {}
    package.loaded['herdr-splits.herdr'] = {
      is_in_session = function() return true end,
      current_pane_at_edge = function() return false end,
      nav_at_edge = function() return 'wrap' end,
      focus_pane = function(d) focused[#focused + 1] = d; return true end,
    }
    package.loaded['herdr-splits.nav'] = nil
    local nav = require('herdr-splits.nav')

    vim.o.splitright = true
    vim.cmd('vsplit')
    local wins = vim.api.nvim_tabpage_list_wins(0)
    table.sort(wins, function(a, b)
      return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
    end)
    -- left window: 'right' has a Neovim neighbor -> will_wrap == false
    vim.api.nvim_set_current_win(wins[1])
    nav.move_cursor('right')
    return { stayed = vim.api.nvim_get_current_win() == wins[1], focused = focused }
  end)

  -- Without the guard, wincmd l would move to wins[2]; with it, silent no-op.
  expect.equality(result, { stayed = true, focused = {} })
end

return T
