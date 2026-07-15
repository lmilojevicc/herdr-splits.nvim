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

T['resolves the binary and requires a complete session environment'] = function()
  local result = child.lua_func(function()
    local config = require('herdr-splits.config')
    local herdr = require('herdr-splits.herdr')

    vim.env.HERDR_BIN_PATH = '/env/herdr'
    config.herdr_bin = nil
    local from_env = herdr.herdr_bin()
    config.herdr_bin = '/config/herdr'
    local from_config = herdr.herdr_bin()
    config.herdr_bin = nil
    vim.env.HERDR_BIN_PATH = nil
    local fallback = herdr.herdr_bin()

    vim.env.HERDR_ENV = nil
    vim.env.HERDR_PANE_ID = nil
    local absent = { herdr.is_in_session(), herdr.current_pane_id() or '<nil>' }
    vim.env.HERDR_ENV = '1'
    vim.env.HERDR_PANE_ID = ''
    local empty = { herdr.is_in_session(), herdr.current_pane_id() or '<nil>' }
    vim.env.HERDR_PANE_ID = 'pane-7'
    local present = { herdr.is_in_session(), herdr.current_pane_id() }

    return {
      binaries = { from_env, from_config, fallback },
      absent = absent,
      empty = empty,
      present = present,
    }
  end)

  expect.equality(result, {
    binaries = { '/env/herdr', '/config/herdr', 'herdr' },
    absent = { false, '<nil>' },
    empty = { false, '<nil>' },
    present = { true, 'pane-7' },
  })
end

T['parses edge responses and rejects invalid command output'] = function()
  local result = child.lua_func(function()
    vim.env.HERDR_ENV = '1'
    vim.env.HERDR_PANE_ID = 'pane-7'
    local config = require('herdr-splits.config')
    config.herdr_bin = '/fake/herdr'

    local queue = {
      { stdout = vim.json.encode({ result = { edges = { left = true } } }), stderr = '', code = 0 },
      { stdout = vim.json.encode({ result = { edges = { left = false } } }), stderr = '', code = 0 },
      { stdout = '{bad', stderr = '', code = 0 },
      { stdout = '', stderr = '', code = 0 },
      { stdout = vim.json.encode({ result = {} }), stderr = '', code = 0 },
      { stdout = '{}', stderr = 'failed', code = 2 },
      { stdout = vim.json.encode({ result = { edges = {} } }), stderr = '', code = 0 },
      { stdout = '{"result":{"edges":{"left":null}}}', stderr = '', code = 0 },
      { stdout = vim.json.encode({ result = { edges = { left = 'yes' } } }), stderr = '', code = 0 },
    }
    local calls = {}
    vim.system = function(argv, opts)
      calls[#calls + 1] = { argv = vim.deepcopy(argv), opts = vim.deepcopy(opts) }
      local item = table.remove(queue, 1)
      return { wait = function() return item end }
    end

    package.loaded['herdr-splits.herdr'] = nil
    local herdr = require('herdr-splits.herdr')
    local values = {}
    for i = 1, 9 do
      local value = herdr.current_pane_at_edge('left')
      values[i] = value == nil and '<nil>' or value
    end
    return { values = values, calls = calls }
  end)

  expect.equality(result.values, {
    true, false, '<nil>', '<nil>', '<nil>', '<nil>', '<nil>', '<nil>', '<nil>',
  })
  expect.equality(#result.calls, 9)
  for _, call in ipairs(result.calls) do
    expect.equality(call, {
      argv = { '/fake/herdr', 'pane', 'edges', '--current' },
      opts = { text = true },
    })
  end
end

T['parses zoom responses and rejects invalid command output'] = function()
  local result = child.lua_func(function()
    vim.env.HERDR_ENV = '1'
    vim.env.HERDR_PANE_ID = 'pane-7'
    local queue = {
      { stdout = vim.json.encode({ result = { layout = { zoomed = true } } }), stderr = '', code = 0 },
      { stdout = vim.json.encode({ result = { layout = { zoomed = false } } }), stderr = '', code = 0 },
      { stdout = '{bad', stderr = '', code = 0 },
      { stdout = vim.json.encode({ result = {} }), stderr = '', code = 0 },
      { stdout = '{}', stderr = '', code = 1 },
      { stdout = vim.json.encode({ result = { layout = {} } }), stderr = '', code = 0 },
      { stdout = '{"result":{"layout":{"zoomed":null}}}', stderr = '', code = 0 },
      { stdout = vim.json.encode({ result = { layout = { zoomed = 1 } } }), stderr = '', code = 0 },
    }
    local calls = {}
    vim.system = function(argv, opts)
      calls[#calls + 1] = { argv = vim.deepcopy(argv), opts = vim.deepcopy(opts) }
      local item = table.remove(queue, 1)
      return { wait = function() return item end }
    end

    package.loaded['herdr-splits.herdr'] = nil
    local herdr = require('herdr-splits.herdr')
    local values = {}
    for i = 1, 8 do
      local value = herdr.current_pane_is_zoomed()
      values[i] = value == nil and '<nil>' or value
    end
    return { values = values, calls = calls }
  end)

  expect.equality(result.values, {
    true, false, '<nil>', '<nil>', '<nil>', '<nil>', '<nil>', '<nil>',
  })
  expect.equality(#result.calls, 8)
  for _, call in ipairs(result.calls) do
    expect.equality(call.argv, { 'herdr', 'pane', 'layout', '--current' })
    expect.equality(call.opts, { text = true })
  end
end

T['rejects JSON null for pane queries'] = function()
  local result = child.lua_func(function()
    vim.env.HERDR_ENV = '1'
    vim.env.HERDR_PANE_ID = 'pane-7'
    local queue = {
      'null',
      '{"result":null}',
      '{"result":{"edges":null}}',
      'null',
      '{"result":null}',
      '{"result":{"layout":null}}',
    }
    vim.system = function()
      local stdout = table.remove(queue, 1)
      return {
        wait = function()
          return { stdout = stdout, stderr = '', code = 0 }
        end,
      }
    end

    package.loaded['herdr-splits.herdr'] = nil
    local herdr = require('herdr-splits.herdr')
    local values = {}
    for _ = 1, 3 do
      local ok, value = pcall(herdr.current_pane_at_edge, 'left')
      values[#values + 1] = { ok, value == nil and '<nil>' or value }
    end
    for _ = 1, 3 do
      local ok, value = pcall(herdr.current_pane_is_zoomed)
      values[#values + 1] = { ok, value == nil and '<nil>' or value }
    end
    return values
  end)

  expect.equality(result, {
    { true, '<nil>' },
    { true, '<nil>' },
    { true, '<nil>' },
    { true, '<nil>' },
    { true, '<nil>' },
    { true, '<nil>' },
  })
end

T['focus and unzoom use exact commands and report exit status'] = function()
  local result = child.lua_func(function()
    vim.env.HERDR_ENV = '1'
    vim.env.HERDR_PANE_ID = 'pane-7'
    local queue = {
      { stdout = '', stderr = '', code = 0 },
      { stdout = '', stderr = 'no neighbor', code = 1 },
      { stdout = '', stderr = '', code = 0 },
      { stdout = '', stderr = 'failed', code = 1 },
    }
    local calls = {}
    vim.system = function(argv, opts)
      calls[#calls + 1] = { argv = vim.deepcopy(argv), opts = vim.deepcopy(opts) }
      local item = table.remove(queue, 1)
      return { wait = function() return item end }
    end

    package.loaded['herdr-splits.herdr'] = nil
    local herdr = require('herdr-splits.herdr')
    return {
      values = {
        herdr.focus_pane('right'),
        herdr.focus_pane('left'),
        herdr.unzoom(),
        herdr.unzoom(),
      },
      calls = calls,
    }
  end)

  expect.equality(result.values, { true, false, true, false })
  expect.equality(result.calls, {
    { argv = { 'herdr', 'pane', 'focus', '--direction', 'right', '--current' }, opts = { text = true } },
    { argv = { 'herdr', 'pane', 'focus', '--direction', 'left', '--current' }, opts = { text = true } },
    { argv = { 'herdr', 'pane', 'zoom', '--off', '--current' }, opts = { text = true } },
    { argv = { 'herdr', 'pane', 'zoom', '--off', '--current' }, opts = { text = true } },
  })
end

T['resize formats ratios and reports exit status'] = function()
  local result = child.lua_func(function()
    vim.env.HERDR_ENV = '1'
    vim.env.HERDR_PANE_ID = 'pane-7'
    local queue = {
      { stdout = '', stderr = '', code = 0 },
      { stdout = '', stderr = 'failed', code = 1 },
    }
    local calls = {}
    vim.system = function(argv, opts)
      calls[#calls + 1] = { argv = vim.deepcopy(argv), opts = vim.deepcopy(opts) }
      local item = table.remove(queue, 1)
      return { wait = function() return item end }
    end

    package.loaded['herdr-splits.herdr'] = nil
    local herdr = require('herdr-splits.herdr')
    return {
      values = { herdr.resize_pane('down', 0.03), herdr.resize_pane('left', 1 / 3) },
      calls = calls,
    }
  end)

  expect.equality(result.values, { true, false })
  expect.equality(result.calls, {
    {
      argv = { 'herdr', 'pane', 'resize', '--direction', 'down', '--amount', '0.0300', '--current' },
      opts = { text = true },
    },
    {
      argv = { 'herdr', 'pane', 'resize', '--direction', 'left', '--amount', '0.3333', '--current' },
      opts = { text = true },
    },
  })
end

return T
