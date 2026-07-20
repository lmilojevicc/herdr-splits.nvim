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
