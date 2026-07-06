---:checkhealth herdr-splits integration.
---Discovered automatically by Neovim's built-in `:checkhealth` via the
---runtimefile lookup in `lua/<plugin>/health.lua`.
---Requires Neovim ≥ 0.10 for `vim.health`.

local M = {}

function M.check()
  local config = require('herdr-splits.config')
  local herdr = require('herdr-splits.herdr')
  local win = require('herdr-splits.win')

  vim.health.start('herdr-splits')

  if herdr.is_in_session() then
    vim.health.ok(
      string.format(
        'Running inside a Herdr session (HERDR_ENV=1, HERDR_PANE_ID=%s)',
        tostring(vim.env.HERDR_PANE_ID)
      )
    )
  else
    vim.health.warn(
      'Not inside a Herdr session (HERDR_ENV='
        .. tostring(vim.env.HERDR_ENV)
        .. ') — nav/resize will not cross pane boundaries.'
    )
  end

  vim.health.info(string.format('ignored_buftypes: %s', vim.inspect(config.ignored_buftypes)))
  vim.health.info(string.format('ignored_filetypes: %s', vim.inspect(config.ignored_filetypes)))
  vim.health.info(string.format('floating_zindex_max: %s', tostring(config.floating_zindex_max)))
  vim.health.info(string.format('ignore_previewwindows: %s', tostring(config.ignore_previewwindows)))

  if win.is_embedded_floating_window() then
    vim.health.warn('Current window is an embedded floating window (zindex < 50) — treat as sidebar.')
  end
  if win.is_ignored_win() then
    vim.health.info('Current window matches an ignored filetype/buftype.')
  end
  if win.is_floating() and not win.is_embedded_floating_window() then
    vim.health.info('Current window is a true floating popup — nav/resize will forward to Herdr.')
  end
end

return M
