local T
local expect = MiniTest.expect
local child = MiniTest.new_child_neovim()

local source = debug.getinfo(1, 'S').source
local root = vim.fn.fnamemodify(source:sub(2), ':p:h:h')
local lazy_sha = 'ABCDEF1234567890'

local function run_sync(params)
  return child.lua_func(function(case)
    local config = require('herdr-splits.config')
    config.auto_sync_herdr = case.auto_sync ~= false
    config.herdr_bin = vim.v.progpath

    local queue = {}
    if config.auto_sync_herdr then
      queue = {
        { code = 0, stdout = case.lazy_sha .. '\n', stderr = '' },
        { code = 0, stdout = case.plugin_list, stderr = '' },
      }
      if case.install_code ~= nil then
        queue[#queue + 1] = { code = case.install_code, stdout = '', stderr = '' }
      end
    end

    local calls = {}
    local notifications = {}
    vim.system = function(argv, opts)
      calls[#calls + 1] = { argv = vim.deepcopy(argv), opts = vim.deepcopy(opts) }
      local item = table.remove(queue, 1) or { code = 99, stdout = '', stderr = 'unexpected call' }
      return { wait = function() return item end }
    end
    vim.notify = function(message, level)
      notifications[#notifications + 1] = { message = message, level = level }
    end

    package.loaded['herdr-splits.sync'] = nil
    require('herdr-splits.sync').sync()

    return {
      bin = config.herdr_bin,
      calls = calls,
      notifications = notifications,
    }
  end, {
    auto_sync = params.auto_sync,
    lazy_sha = params.lazy_sha or lazy_sha,
    plugin_list = params.plugin_list or '',
    install_code = params.install_code,
  })
end

local function expect_common_calls(result, expected_count)
  expect.equality(#result.calls, expected_count)
  expect.equality(result.calls[1], {
    argv = { 'git', '-C', root, 'rev-parse', 'HEAD' },
    opts = { text = true },
  })
  expect.equality(result.calls[2], {
    argv = { result.bin, 'plugin', 'list', '--plugin', 'herdr-splits', '--json' },
    opts = { text = true },
  })
end

local function expect_install(result)
  expect_common_calls(result, 3)
  expect.equality(result.calls[3], {
    argv = {
      result.bin,
      'plugin',
      'install',
      'lmilojevicc/herdr-splits.nvim',
      '--ref',
      lazy_sha,
      '--yes',
    },
    opts = { text = true },
  })
  expect.equality(result.notifications, {
    {
      message = 'herdr-splits: synced Herdr-side scripts to ' .. lazy_sha:sub(1, 7),
      level = vim.log.levels.INFO,
    },
  })
end

local function github_entry(commit)
  return {
    plugin_id = 'herdr-splits',
    source = { kind = 'github', resolved_commit = commit },
  }
end

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

T['installs a stale target from the Herdr response envelope'] = function()
  local result = run_sync({
    plugin_list = vim.json.encode({
      id = 'cli:plugin',
      result = {
        plugins = {
          'malformed',
          { plugin_id = 'other', source = { kind = 'github', resolved_commit = 'other' } },
          github_entry('stale'),
        },
      },
    }),
    install_code = 0,
  })

  expect_install(result)
end

T['does not install when commits match case-insensitively'] = function()
  local result = run_sync({
    plugin_list = vim.json.encode({
      id = 'cli:plugin',
      result = { plugins = { github_entry(lazy_sha:lower()) } },
    }),
  })

  expect_common_calls(result, 2)
  expect.equality(result.notifications, {})
end

T['supports a legacy bare plugin object'] = function()
  local result = run_sync({
    plugin_list = vim.json.encode(github_entry('stale')),
    install_code = 0,
  })

  expect_install(result)
end

T['supports a legacy top-level plugin array'] = function()
  local result = run_sync({
    plugin_list = vim.json.encode({
      'malformed',
      { plugin_id = 'other', source = { kind = 'github', resolved_commit = 'other' } },
      github_entry('stale'),
    }),
    install_code = 0,
  })

  expect_install(result)
end

T['keeps malformed and missing plugin-list data as silent no-ops'] = function()
  local cases = {
    '{bad',
    vim.json.encode({ id = 'cli:plugin' }),
    vim.json.encode({ id = 'cli:plugin', result = 1 }),
    vim.json.encode({ id = 'cli:plugin', result = {} }),
    vim.json.encode({ id = 'cli:plugin', result = { plugins = 'bad' } }),
    vim.json.encode({ id = 'cli:plugin', result = { plugins = {} } }),
    vim.json.encode({
      id = 'cli:plugin',
      result = { plugins = { { plugin_id = 'herdr-splits', source = 1 } } },
    }),
    vim.json.encode({
      id = 'cli:plugin',
      result = {
        plugins = {
          { plugin_id = 'herdr-splits', source = { kind = 'github', resolved_commit = 1 } },
        },
      },
    }),
    vim.json.encode({
      id = 'cli:plugin',
      result = {
        plugins = {
          'malformed',
          { plugin_id = 'other', source = { kind = 'github', resolved_commit = 'other' } },
        },
      },
    }),
  }

  for _, plugin_list in ipairs(cases) do
    local result = run_sync({ plugin_list = plugin_list })
    expect_common_calls(result, 2)
    expect.equality(result.notifications, {})
  end
end

T['keeps non-GitHub sources as a no-op'] = function()
  local result = run_sync({
    plugin_list = vim.json.encode({
      id = 'cli:plugin',
      result = {
        plugins = {
          { plugin_id = 'herdr-splits', source = { kind = 'path', resolved_commit = 'stale' } },
        },
      },
    }),
  })

  expect_common_calls(result, 2)
  expect.equality(result.notifications, {})
end

T['performs no subprocess work when auto-sync is disabled'] = function()
  local result = run_sync({ auto_sync = false })

  expect.equality(result.calls, {})
  expect.equality(result.notifications, {})
end

return T
