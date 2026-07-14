---@class HerdrSplitsConfig
---@field default_amount number Resize amount as Herdr ratio (float, e.g. 0.03 = 3%)
---@field neovim_amount number Resize amount for native Neovim resizes (integer cells, default 3)
---@field at_edge 'wrap'|'stop'|'split'|function Neovim window-edge behavior (distinct from nav_at_edge below)
---@field ignored_buftypes string[] Buffer types ignored during resize
---@field ignored_filetypes string[] Filetypes ignored during resize
---@field move_cursor_same_row boolean Keep cursor on same screen row when moving left/right
---@field herdr_bin string|nil Path to herdr binary (auto-detected if nil)
---@field ignored_events string[] Autocmd events to ignore during resize operations
---@field auto_sync_herdr boolean|nil If true, auto-sync the Herdr-managed checkout to match this lazy commit (opt-in; default false)
---@field floating_zindex_max number Threshold below which a floating window's zindex classifies it as an embedded sidebar (default 50; Neovim's default float zindex)
---@field ignore_previewwindows boolean If true, vim.wo[winid].previewwindow windows (e.g. dadbod `.dbout`) are treated as sidebars (opt-in; default false)
--- Managed config (written to herdr-splits.conf by setup()). Pass Neovim
--- notation (e.g. `<C-h>`, `<M-Left>`); stored/written in Herdr notation.
---@field nav_keys table<string,string> Forward chords per direction: {left,down,up,right} (Neovim notation in opts; Herdr notation internally)
---@field resize_keys table<string,string> Resize forward chords per direction: {left,down,up,right} (Neovim notation in opts; Herdr notation internally)
---@field unzoom_on_nav boolean If true, auto-unzoom when navigating away from a zoomed pane (default true)
---@field nav_at_edge 'wrap'|'stop' Herdr pane-boundary wrap behavior (distinct from at_edge, which is the Neovim window-edge behavior)

local M = {
  default_amount = 0.03,
  neovim_amount = 3,
  at_edge = 'wrap',
  ignored_buftypes = { 'nofile', 'quickfix', 'prompt', 'help', 'terminal' },
  ignored_filetypes = {
    'NvimTree',
    -- sidebars
    'neo-tree',
    'snacks_dashboard',
    'snacks_explorer',
    'snacks_picker',
    -- DB / REPL / data sidebars
    'dadbod-ui',
    'dbout',
    -- outlines / symbols
    'aerial',
    'Outline',
    -- diagnostics / quick lists
    'Trouble',
    'quickfix',
  },
  move_cursor_same_row = false,
  herdr_bin = nil,
  ignored_events = { 'BufEnter', 'WinEnter' },
  auto_sync_herdr = false,
  floating_zindex_max = 50,
  ignore_previewwindows = false,
  -- Managed config: stored in Herdr chord notation; setup() translates user
  -- Neovim notation and writes these to herdr-splits.conf for the scripts.
  nav_keys = { left = 'ctrl+h', down = 'ctrl+j', up = 'ctrl+k', right = 'ctrl+l' },
  resize_keys = { left = 'alt+h', down = 'alt+j', up = 'alt+k', right = 'alt+l' },
  unzoom_on_nav = true,
  nav_at_edge = 'wrap',
}

-- Defaults for the managed key set (Herdr notation). Used as the base layer
-- of the adopt-existing merge in setup(). Keep in sync with the public M.* defaults above.
M._managed_defaults = {
  nav_keys = { left = 'ctrl+h', down = 'ctrl+j', up = 'ctrl+k', right = 'ctrl+l' },
  resize_keys = { left = 'alt+h', down = 'alt+j', up = 'alt+k', right = 'alt+l' },
  unzoom_on_nav = true,
  nav_at_edge = 'wrap',
}

local conf = require('herdr-splits.conf')

---Apply user configuration on top of defaults and publish the managed keys
---to the shared `herdr-splits.conf` (so the Herdr-side scripts agree).
---Idempotent — calling again merges into existing config.
---
---Managed keys (nav_keys/resize_keys/unzoom_on_nav/nav_at_edge) resolve with
---precedence: defaults -> existing conf value (adopt-once) -> explicit opt.
---User chords are given in Neovim notation and translated to Herdr notation
---before merging; the resolved set is written to the conf atomically (write
---failures never crash startup).
---@param opts table|nil
function M.setup(opts)
  opts = opts or {}

  -- Managed opts: translate user chords nvim -> herdr, capture only what was passed.
  local user = {}
  if opts.nav_keys then
    user.nav_keys = {}
    for dir, k in pairs(opts.nav_keys) do user.nav_keys[dir] = conf.to_herdr(k) end
  end
  if opts.resize_keys then
    user.resize_keys = {}
    for dir, k in pairs(opts.resize_keys) do user.resize_keys[dir] = conf.to_herdr(k) end
  end
  if opts.unzoom_on_nav ~= nil then user.unzoom_on_nav = opts.unzoom_on_nav end
  if opts.nav_at_edge ~= nil then user.nav_at_edge = opts.nav_at_edge end

  -- Precedence: defaults -> existing conf (adopt) -> explicit user opts.
  local resolved = vim.deepcopy(M._managed_defaults)
  resolved = vim.tbl_deep_extend('force', resolved, conf.read_managed())
  resolved = vim.tbl_deep_extend('force', resolved, user)

  M.nav_keys, M.resize_keys = resolved.nav_keys, resolved.resize_keys
  M.unzoom_on_nav, M.nav_at_edge = resolved.unzoom_on_nav, resolved.nav_at_edge

  -- Non-managed opts (default_amount, at_edge, ignored_filetypes, …) merge as before.
  local other = vim.deepcopy(opts)
  other.nav_keys, other.resize_keys = nil, nil
  other.unzoom_on_nav, other.nav_at_edge = nil, nil
  local merged = vim.tbl_deep_extend('force', M, other)
  for k, v in pairs(merged) do M[k] = v end

  -- Publish to the shared conf for the Herdr scripts (never fatal).
  pcall(conf.write, resolved)
end

return M
