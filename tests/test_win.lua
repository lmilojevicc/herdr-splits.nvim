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

T['win_position identifies horizontal split positions'] = function()
  local positions = child.lua_func(function()
    vim.cmd('vsplit | vsplit')
    local wins = vim.api.nvim_tabpage_list_wins(0)
    table.sort(wins, function(a, b)
      return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
    end)

    local out = {}
    for _, win in ipairs(wins) do
      vim.api.nvim_set_current_win(win)
      out[#out + 1] = require('herdr-splits.win').win_position('left')
    end
    return out
  end)

  expect.equality(positions, { 'start', 'middle', 'last' })
end

T['win_position identifies vertical split positions'] = function()
  local positions = child.lua_func(function()
    vim.cmd('split | split')
    local wins = vim.api.nvim_tabpage_list_wins(0)
    table.sort(wins, function(a, b)
      return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
    end)

    local out = {}
    for _, win in ipairs(wins) do
      vim.api.nvim_set_current_win(win)
      out[#out + 1] = require('herdr-splits.win').win_position('up')
    end
    return out
  end)

  expect.equality(positions, { 'start', 'middle', 'last' })
end

T['floating classification distinguishes embedded floats'] = function()
  local result = child.lua_func(function()
    local win = require('herdr-splits.win')
    local normal = vim.api.nvim_get_current_win()
    local low = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
      relative = 'editor', row = 1, col = 1, width = 10, height = 3, zindex = 49,
    })
    local default = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
      relative = 'editor', row = 2, col = 2, width = 10, height = 3, zindex = 50,
    })

    return {
      normal_floating = win.is_floating(normal),
      normal_embedded = win.is_embedded_floating_window(normal),
      low_floating = win.is_floating(low),
      low_embedded = win.is_embedded_floating_window(low),
      default_floating = win.is_floating(default),
      default_embedded = win.is_embedded_floating_window(default),
    }
  end)

  expect.equality(result, {
    normal_floating = false,
    normal_embedded = false,
    low_floating = true,
    low_embedded = true,
    default_floating = true,
    default_embedded = false,
  })
end

T['resolves embedded floats through window-relative ancestry'] = function()
  local result = child.lua_func(function()
    local win = require('herdr-splits.win')
    vim.o.splitright = true
    vim.cmd('vsplit')
    local roots = vim.api.nvim_tabpage_list_wins(0)
    table.sort(roots, function(a, b)
      return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
    end)
    local root = roots[1]

    local direct = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
      relative = 'win', win = root, row = 0, col = 0, width = 10, height = 3, zindex = 49,
    })
    local middle = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
      relative = 'win', win = root, row = 0, col = 0, width = 12, height = 4, zindex = 60,
    })
    local nested = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
      relative = 'win', win = middle, row = 0, col = 0, width = 8, height = 2, zindex = 49,
    })
    local editor_relative = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
      relative = 'editor', row = 1, col = 1, width = 10, height = 3, zindex = 49,
    })

    return {
      direct = win.resolve_embedded_parent(direct) == root,
      nested = win.resolve_embedded_parent(nested) == root,
      editor_relative = win.resolve_embedded_parent(editor_relative) == nil,
      normal = win.resolve_embedded_parent(root) == nil,
    }
  end)

  expect.equality(result, {
    direct = true,
    nested = true,
    editor_relative = true,
    normal = true,
  })
end

T['embedded parent resolution rejects cyclic ancestry'] = function()
  local result = child.lua_func(function()
    local win = require('herdr-splits.win')
    vim.cmd('vsplit')
    local wins = vim.api.nvim_tabpage_list_wins(0)
    local first, second = wins[1], wins[2]
    local original = vim.api.nvim_win_get_config

    vim.api.nvim_win_get_config = function(winid)
      if winid == first then
        return { relative = 'win', win = second, zindex = 49 }
      end
      if winid == second then
        return { relative = 'win', win = first, zindex = 60 }
      end
      return original(winid)
    end
    local cycle_ok, cycle = pcall(win.resolve_embedded_parent, first)

    vim.api.nvim_win_get_config = function(winid)
      if winid == first then
        return { relative = 'win', win = 1.5, zindex = 49 }
      end
      return original(winid)
    end
    local malformed_ok, malformed = pcall(win.resolve_embedded_parent, first)
    vim.api.nvim_win_get_config = original
    return {
      cycle_safe = cycle_ok,
      cycle_unresolved = cycle == nil,
      malformed_safe = malformed_ok,
      malformed_unresolved = malformed == nil,
    }
  end)

  expect.equality(result, {
    cycle_safe = true,
    cycle_unresolved = true,
    malformed_safe = true,
    malformed_unresolved = true,
  })
end

T['embedded parent resolution safely rejects unavailable ancestry'] = function()
  local result = child.lua_func(function()
    local win = require('herdr-splits.win')
    local original_config = vim.api.nvim_win_get_config

    local function with_config_stub(stub, callback)
      vim.api.nvim_win_get_config = stub
      local ok, value = pcall(callback)
      vim.api.nvim_win_get_config = original_config
      return ok, value, vim.api.nvim_win_get_config == original_config
    end

    local start = vim.api.nvim_get_current_win()
    vim.cmd('vsplit')
    local deleted = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(start)
    vim.api.nvim_win_close(deleted, true)

    local invalid_ok, invalid, invalid_restored = with_config_stub(function(winid)
      if winid == start then
        return { relative = 'win', win = 2147483647, zindex = 49 }
      end
      return original_config(winid)
    end, function()
      return win.resolve_embedded_parent(start)
    end)

    local deleted_ok, deleted_result, deleted_restored = with_config_stub(function(winid)
      if winid == start then
        return { relative = 'win', win = deleted, zindex = 49 }
      end
      return original_config(winid)
    end, function()
      return win.resolve_embedded_parent(start)
    end)

    local start_tab = vim.api.nvim_win_get_tabpage(start)
    vim.cmd('tabnew')
    local other_tab_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_tabpage(start_tab)
    local cross_tab_ok, cross_tab, cross_tab_restored = with_config_stub(function(winid)
      if winid == start then
        return { relative = 'win', win = other_tab_win, zindex = 49 }
      end
      return original_config(winid)
    end, function()
      return win.resolve_embedded_parent(start)
    end)

    local reads = 0
    local read_ok, read_failure, read_restored = with_config_stub(function(winid)
      if winid == start then
        reads = reads + 1
        if reads > 2 then
          error('forced config read failure')
        end
        return { relative = 'win', win = start, zindex = 49 }
      end
      return original_config(winid)
    end, function()
      return win.resolve_embedded_parent(start)
    end)

    return {
      invalid_safe = invalid_ok and invalid == nil,
      deleted_safe = deleted_ok and deleted_result == nil,
      cross_tab_safe = cross_tab_ok and cross_tab == nil,
      read_failure_safe = read_ok and read_failure == nil,
      restored = invalid_restored and deleted_restored and cross_tab_restored and read_restored,
    }
  end)

  expect.equality(result, {
    invalid_safe = true,
    deleted_safe = true,
    cross_tab_safe = true,
    read_failure_safe = true,
    restored = true,
  })
end

T['edge and position queries accept a non-current window'] = function()
  local result = child.lua_func(function()
    local win = require('herdr-splits.win')
    vim.o.splitright = true
    vim.cmd('vsplit')
    local wins = vim.api.nvim_tabpage_list_wins(0)
    table.sort(wins, function(a, b)
      return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
    end)
    vim.api.nvim_set_current_win(wins[2])
    return {
      current = win.win_position('left'),
      left = win.win_position('left', wins[1]),
      left_edge = win.at_left_edge(wins[1]),
      left_right_edge = win.at_right_edge(wins[1]),
    }
  end)

  expect.equality(result, {
    current = 'last',
    left = 'start',
    left_edge = true,
    left_right_edge = false,
  })
end

T['ignored window classification uses buffer type and filetype'] = function()
  local result = child.lua_func(function()
    local win = require('herdr-splits.win')
    local bufnr = vim.api.nvim_get_current_buf()
    local regular = win.is_ignored_win()

    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
    local ignored_buftype = win.is_ignored_win()
    vim.api.nvim_set_option_value('buftype', '', { buf = bufnr })

    vim.api.nvim_set_option_value('filetype', 'neo-tree', { buf = bufnr })
    local ignored_filetype = win.is_ignored_win()
    return {
      regular = regular,
      ignored_buftype = ignored_buftype,
      ignored_filetype = ignored_filetype,
    }
  end)

  expect.equality(result, {
    regular = false,
    ignored_buftype = true,
    ignored_filetype = true,
  })
end

T['preview windows are ignored only when configured'] = function()
  local result = child.lua_func(function()
    local win = require('herdr-splits.win')
    local config = require('herdr-splits.config')
    vim.wo.previewwindow = true

    config.ignore_previewwindows = false
    local disabled = win.is_ignored_or_preview()
    config.ignore_previewwindows = true
    local enabled = win.is_ignored_or_preview()
    return { disabled = disabled, enabled = enabled }
  end)

  expect.equality(result, { disabled = false, enabled = true })
end

T['command-line window is not active in a normal buffer'] = function()
  local result = child.lua_func(function()
    return require('herdr-splits.win').is_command_line_window()
  end)
  expect.equality(result, false)
end

return T
