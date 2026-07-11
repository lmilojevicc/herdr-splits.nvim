---Herdr CLI wrapper. All Herdr subprocess calls go through this module.
---@class HerdrSplitsHerdr
local M = {}

local config = require('herdr-splits.config')

---Resolve the herdr binary path.
---@return string
function M.herdr_bin()
  return config.herdr_bin or vim.env.HERDR_BIN_PATH or 'herdr'
end

---Check if Neovim is running inside a Herdr session.
---@return boolean
function M.is_in_session()
  return vim.env.HERDR_ENV == '1' and vim.env.HERDR_PANE_ID ~= nil and #vim.env.HERDR_PANE_ID > 0
end

---Get the current Herdr pane ID.
---@return string|nil
function M.current_pane_id()
  if not M.is_in_session() then
    return nil
  end
  return vim.env.HERDR_PANE_ID
end

---Run a herdr CLI command and return stdout, stderr, and exit code.
---@param args string[]
---@return string stdout, string stderr, number exit_code
local function herdr_exec(args)
  local cmd = vim.list_extend({ M.herdr_bin() }, args, 1, #args)
  local obj = vim.system(cmd, { text = true }):wait()
  return obj.stdout, obj.stderr, obj.code
end

---Check if the current Herdr pane is at the layout boundary in the given direction.
---Calls `herdr pane edges --current` and parses the JSON response.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@return boolean|nil true if at edge, false if neighbor exists, nil on error
function M.current_pane_at_edge(direction)
  if not M.is_in_session() then
    return nil
  end

  local edge_key = direction
  local stdout, _, code = herdr_exec({ 'pane', 'edges', '--current' })

  if code ~= 0 or not stdout or #stdout == 0 then
    return nil
  end

  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or not data or not data.result or not data.result.edges then
    return nil
  end

  return data.result.edges[edge_key] == true
end

---Check if the current Herdr pane is zoomed.
---Calls `herdr pane layout --current` and parses JSON.
---@return boolean|nil true if zoomed, false if not, nil on error
function M.current_pane_is_zoomed()
  if not M.is_in_session() then
    return nil
  end

  local stdout, _, code = herdr_exec({ 'pane', 'layout', '--current' })

  if code ~= 0 or not stdout or #stdout == 0 then
    return nil
  end

  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or not data or not data.result or not data.result.layout then
    return nil
  end

  return data.result.layout.zoomed == true
end

---Focus a Herdr pane in the given direction.
---Calls `herdr pane focus --direction <dir> --current`.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@return boolean true on success
function M.focus_pane(direction)
  if not M.is_in_session() then
    return false
  end

  local _, _, code = herdr_exec({ 'pane', 'focus', '--direction', direction, '--current' })
  return code == 0
end

---Unzoom the current Herdr pane (turn off zoom).
---Calls `herdr pane zoom --off --current`.
---@return boolean true on success
function M.unzoom()
  if not M.is_in_session() then
    return false
  end

  local _, _, code = herdr_exec({ 'pane', 'zoom', '--off', '--current' })
  return code == 0
end

---Path to the shared herdr-splits config file (same file the Herdr-side
---scripts read). Honors HERDR_SPLITS_CONFIG and XDG_CONFIG_HOME.
---@return string
local function conf_path()
  local xdg = vim.env.XDG_CONFIG_HOME
  local base
  if xdg and xdg:sub(1, 1) == '/' then
    base = xdg .. '/herdr/plugins/config/herdr-splits'
  else
    base = (vim.env.HOME or '~') .. '/.config/herdr/plugins/config/herdr-splits'
  end
  return vim.env.HERDR_SPLITS_CONFIG or (base .. '/herdr-splits.conf')
end

---Scan the shared config file for a line matching `pattern`.
---Returns true on first match; false if the file is missing or no line matches.
---@param pattern string Lua pattern matched against each whole line
---@return boolean
local function conf_matches(pattern)
  local f = io.open(conf_path(), 'r')
  if not f then
    return false
  end
  for line in f:lines() do
    if line:match(pattern) then
      f:close()
      return true
    end
  end
  f:close()
  return false
end

---Check whether auto-unzoom is enabled.
---Reads `unzoom_on_nav` from the shared config file (default: enabled).
---@return boolean
function M.unzoom_enabled()
  return not conf_matches('^%s*unzoom_on_nav%s*=%s*false')
end

---Edge-wrap behavior across the Herdr pane boundary, read from the shared
---config file (same file the Herdr-side scripts read). `stop` suppresses
---wrap-across-boundary on both the plain-pane side (handled by the Herdr
---script) and the Neovim edge-wrap side (handled here). Anything else,
---including a missing file, defaults to `wrap`.
---@return '"wrap"'|'"stop"'
function M.nav_at_edge()
  if conf_matches('^%s*nav_at_edge%s*=%s*stop') then
    return 'stop'
  end
  return 'wrap'
end

---Resize the current Herdr pane in the given direction.
---Calls `herdr pane resize --direction <dir> --amount <float> --current`.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@param amount number Float ratio (e.g., 0.03 = 3% of terminal dimension)
---@return boolean true on success
function M.resize_pane(direction, amount)
  if not M.is_in_session() then
    return false
  end

  local amount_str = string.format('%.4f', amount)
  local _, _, code = herdr_exec({
    'pane', 'resize', '--direction', direction, '--amount', amount_str, '--current',
  })
  return code == 0
end

return M
