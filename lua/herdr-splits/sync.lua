---Auto-sync the Herdr-managed checkout to match the lazy.nvim checkout.
---
---Herdr has no `plugin update` command in v1; the only sanctioned refresh is
---reinstall from GitHub. When lazy.nvim pulls a new commit, the bash scripts
---under the Herdr-managed checkout stay frozen at the old commit unless the
---user manually reinstalls. This module closes that gap: it reinstalls the
---Herdr-managed checkout pinned to the exact commit lazy fetched, so the bash
---scripts match the lua side byte-for-byte.
---
---Entirely a no-op unless `auto_sync_herdr = true` is set in setup(). Also a
---no-op when: the herdr binary is unavailable, the plugin is installed as a
---local link (dev mode — reinstall would be refused anyway), the plugin is not
---installed, or the commits already match.
local M = {}

local config = require('herdr-splits.config')

---Plugin id and GitHub source as used by `herdr plugin install`.
local PLUGIN_ID = 'herdr-splits'
local PLUGIN_SOURCE = 'lmilojevicc/herdr-splits.nvim'

---Run the sync. Safe to call at any time; never throws.
function M.sync()
  if config.auto_sync_herdr ~= true then
    return
  end

  local ok, err = pcall(function()
    local bin = config.herdr_bin or vim.env.HERDR_BIN_PATH or 'herdr'
    if vim.fn.executable(bin) ~= 1 then
      return
    end

    -- Resolve this plugin's own checkout root (the lazy clone).
    local source = debug.getinfo(1, 'S').source -- "@<abs>/lua/herdr-splits/sync.lua"
    local this_file = source:sub(2) -- strip leading '@'
    local plugin_root = vim.fn.fnamemodify(this_file, ':p:h:h:h') -- up 3: file<-herdr-splits<-lua<-root
    if vim.fn.isdirectory(plugin_root .. '/.git') == 0
      and vim.fn.filereadable(plugin_root .. '/herdr-plugin.toml') == 0 then
      return -- not a real checkout
    end

    -- Get the lazy checkout HEAD.
    local obj = vim.system({ 'git', '-C', plugin_root, 'rev-parse', 'HEAD' }, { text = true }):wait()
    if obj.code ~= 0 then
      return
    end
    local lazy_sha = vim.trim(obj.stdout or '')
    if lazy_sha == '' then
      return
    end

    -- Get the managed install info.
    local obj2 = vim.system({ bin, 'plugin', 'list', '--plugin', PLUGIN_ID, '--json' }, { text = true }):wait()
    if obj2.code ~= 0 then
      return
    end

    local decoded, data = pcall(vim.json.decode, obj2.stdout or '')
    if not decoded or type(data) ~= 'table' then
      return
    end

    -- Output may be a single object or an array; find our entry.
    local entry = data
    if data[1] ~= nil then
      for _, e in ipairs(data) do
        if e.plugin_id == PLUGIN_ID then
          entry = e
          break
        end
      end
    end

    local src = entry and entry.source
    if not src then
      return
    end
    -- Dev mode (plugin link) or unknown kind: nothing to do.
    if src.kind ~= 'github' then
      return
    end

    -- Already in sync?
    local managed_sha = vim.trim(src.resolved_commit or '')
    if managed_sha ~= '' and managed_sha:lower() == lazy_sha:lower() then
      return
    end

    -- Reinstall pinned to the lazy commit.
    local obj3 = vim.system(
      { bin, 'plugin', 'install', PLUGIN_SOURCE, '--ref', lazy_sha, '--yes' },
      { text = true }
    ):wait()
    if obj3.code == 0 then
      vim.notify('herdr-splits: synced Herdr-side scripts to ' .. lazy_sha:sub(1, 7), vim.log.levels.INFO)
    else
      vim.notify('herdr-splits: Herdr-side sync skipped (install failed; local link or offline)', vim.log.levels.INFO)
    end
  end)

  if not ok then
    vim.notify('herdr-splits: sync error: ' .. tostring(err), vim.log.levels.DEBUG)
  end
end

return M
