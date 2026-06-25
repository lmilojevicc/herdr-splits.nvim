---@class HerdrSplitsConfig
---@field default_amount number Resize amount as Herdr ratio (float, e.g. 0.03 = 3%)
---@field neovim_amount number Resize amount for native Neovim resizes (integer cells, default 3)
---@field at_edge 'wrap'|'stop'|'split'|function Behavior when cursor at Neovim edge
---@field ignored_buftypes string[] Buffer types ignored during resize
---@field ignored_filetypes string[] Filetypes ignored during resize
---@field move_cursor_same_row boolean Keep cursor on same screen row when moving left/right
---@field disable_nav_when_zoomed boolean Disable Herdr navigation when pane is zoomed
---@field herdr_bin string|nil Path to herdr binary (auto-detected if nil)
---@field ignored_events string[] Autocmd events to ignore during resize operations

local M = {
  default_amount = 0.03,
  neovim_amount = 3,
  at_edge = 'wrap',
  ignored_buftypes = { 'nofile', 'quickfix', 'prompt' },
  ignored_filetypes = { 'NvimTree' },
  move_cursor_same_row = false,
  disable_nav_when_zoomed = true,
  herdr_bin = nil,
  ignored_events = { 'BufEnter', 'WinEnter' },
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
