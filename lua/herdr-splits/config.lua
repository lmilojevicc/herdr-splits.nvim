---@class HerdrSplitsConfig
---@field default_amount number Resize amount as Herdr ratio (float, e.g. 0.03 = 3%)
---@field neovim_amount number Resize amount for native Neovim resizes (integer cells, default 3)
---@field at_edge 'wrap'|'stop'|'split'|function Behavior when cursor at Neovim edge
---@field ignored_buftypes string[] Buffer types ignored during resize
---@field ignored_filetypes string[] Filetypes ignored during resize
---@field move_cursor_same_row boolean Keep cursor on same screen row when moving left/right
---@field herdr_bin string|nil Path to herdr binary (auto-detected if nil)
---@field ignored_events string[] Autocmd events to ignore during resize operations
---@field auto_sync_herdr boolean|nil If true, auto-sync the Herdr-managed checkout to match this lazy commit (opt-in; default false)
---@field floating_zindex_max number Threshold below which a floating window's zindex classifies it as an embedded sidebar (default 50; Neovim's default float zindex)
---@field ignore_previewwindows boolean If true, vim.wo[winid].previewwindow windows (e.g. dadbod `.dbout`) are treated as sidebars (opt-in; default false)

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
}

---Apply user configuration on top of defaults.
---Idempotent — calling again merges into existing config.
---@param opts table|nil
function M.setup(opts)
  if opts then
    -- vim.tbl_deep_extend returns a new table; we must mutate M in place
    -- so that other modules holding require('herdr-splits.config') see the changes.
    local merged = vim.tbl_deep_extend('force', M, opts)
    for k, v in pairs(merged) do
      M[k] = v
    end
  end
end

return M
