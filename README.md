# herdr-splits.nvim

Seamless navigation and resizing between Neovim splits and [Herdr](https://herdr.dev) panes. Makes Herdr terminal splits behave like native Neovim windows — move and resize as if they were all part of the same editor.

Inspired by [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim), ported to Herdr's CLI.

## Features

- **Seamless navigation**: Same keys work in Neovim and plain shells — Herdr forwards them to Neovim when appropriate, Neovim delegates to Herdr at edges.
- **Seamless resizing**: `<M-h/j/k/l>` resizes Neovim splits natively, delegates to Herdr when a window fills the terminal.
- **at_edge behaviours**: `wrap` (default), `stop`, `split`, or a custom function.
- **Auto-unzoom**: Navigating or resizing from a zoomed pane unzooms first (toggleable via single config file).
- **Count prefix support**: `3<C-h>` moves three splits left; `5<M-l>` resizes five steps right.

## Requirements

- Neovim ≥ 0.9
- [Herdr](https://herdr.dev) ≥ 0.7.0 (for plugin actions)

## Installation

Three steps — install on both the Herdr side and the Neovim side, then add keybinds.

### 1. Install the Herdr plugin

This provides the `nav-*` and `resize-*` actions that Herdr keybinds invoke.

```bash
# From GitHub (once published):
herdr plugin install lmilojevicc/herdr-splits.nvim

# Local development:
herdr plugin link /path/to/herdr-splits
```

### 2. Install the Neovim plugin

## lazy.nvim

```lua
{
  'lmilojevicc/herdr-splits.nvim',
  -- or local path during development:
  -- dir = '~/Projects/herdr-splits',
  cond = vim.env.HERDR_ENV == '1',
  event = 'VeryLazy',
  -- Optional: auto-sync the Herdr-side scripts when lazy updates this plugin.
  -- Requires `auto_sync_herdr = true` in setup() below to take effect.
  -- build = 'lua require("herdr-splits").sync_herdr()',
  config = function()
    require('herdr-splits').setup({
      -- Defaults shown. All fields optional.
      default_amount = 0.03,       -- Herdr resize ratio
      neovim_amount = 3,           -- Neovim resize cells
      at_edge = 'wrap',            -- 'wrap' | 'stop' | 'split' | function
      ignored_buftypes = { 'nofile', 'quickfix', 'prompt' },
      ignored_filetypes = { 'NvimTree' },
      move_cursor_same_row = false,
      herdr_bin = nil,                -- auto-detected from HERDR_BIN_PATH
      -- auto_sync_herdr = true,      -- opt-in: sync Herdr-side scripts on update
    })
  end,
  keys = {
    { '<C-h>', function() require('herdr-splits').move_cursor_left() end,  desc = 'Navigate left' },
    { '<C-j>', function() require('herdr-splits').move_cursor_down() end,  desc = 'Navigate down' },
    { '<C-k>', function() require('herdr-splits').move_cursor_up() end,    desc = 'Navigate up' },
    { '<C-l>', function() require('herdr-splits').move_cursor_right() end, desc = 'Navigate right' },
    { '<M-h>', function() require('herdr-splits').resize_left() end,  desc = 'Resize left' },
    { '<M-j>', function() require('herdr-splits').resize_down() end,  desc = 'Resize down' },
    { '<M-k>', function() require('herdr-splits').resize_up() end,    desc = 'Resize up' },
    { '<M-l>', function() require('herdr-splits').resize_right() end, desc = 'Resize right' },
  },
}
```

## packer.nvim

```lua
use {
  'lmilojevicc/herdr-splits.nvim',
  config = function()
    require('herdr-splits').setup()
  end,
}
```

### 3. Add keybinds to Herdr config

Add these to `~/.config/herdr/config.toml`, then run `herdr server reload-config`:

```toml
[[keys.command]]
key = "ctrl+h"
type = "plugin_action"
command = "herdr-splits.nav-left"

[[keys.command]]
key = "ctrl+j"
type = "plugin_action"
command = "herdr-splits.nav-down"

[[keys.command]]
key = "ctrl+k"
type = "plugin_action"
command = "herdr-splits.nav-up"

[[keys.command]]
key = "ctrl+l"
type = "plugin_action"
command = "herdr-splits.nav-right"

[[keys.command]]
key = "alt+h"
type = "plugin_action"
command = "herdr-splits.resize-left"

[[keys.command]]
key = "alt+j"
type = "plugin_action"
command = "herdr-splits.resize-down"

[[keys.command]]
key = "alt+k"
type = "plugin_action"
command = "herdr-splits.resize-up"

[[keys.command]]
key = "alt+l"
type = "plugin_action"
command = "herdr-splits.resize-right"
```

> **Note for macOS**: Terminals treat Option as a special character modifier by default. You need to set Option = Alt/Meta:
>
> - **Ghostty**: `macos-option-as-alt = true`
> - **Alacritty**: `option_as_alt = "Both"`
> - **kitty**: `macos_option_as_alt yes`
> - **iTerm**: Profiles → Keys → Left Option key → Esc+
>
> If you're using [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim) for tmux, add `cond = vim.env.HERDR_ENV ~= '1'` to its spec so the two plugins don't conflict.

### Auto-unzoom

When you navigate or resize from a zoomed Herdr pane, the pane is automatically
unzoomed first. This is enabled by default.

**To disable**, create `herdr-splits.conf` in the plugin config directory (default `~/.config/herdr/plugins/config/herdr-splits/herdr-splits.conf`; print it with `herdr plugin config-dir herdr-splits`):

```text
unzoom_on_nav=false
```

Set `HERDR_SPLITS_CONFIG` to override the path.

_Previously this file lived at `~/.config/herdr-splits/herdr-splits.conf`; move it to the new location above._

This single file controls both the Herdr-side and Neovim-side behaviour — no
need to configure it twice.

## Lua API

```lua
require('herdr-splits').setup(opts)

-- Resize (amount defaults to config.default_amount, multiplied by count prefix)
require('herdr-splits').resize_left(amount)
require('herdr-splits').resize_down(amount)
require('herdr-splits').resize_up(amount)
require('herdr-splits').resize_right(amount)

-- Navigate (opts can override same_row and at_edge per-call)
require('herdr-splits').move_cursor_left({ same_row = true, at_edge = 'stop' })
require('herdr-splits').move_cursor_down(opts)
require('herdr-splits').move_cursor_up(opts)
require('herdr-splits').move_cursor_right(opts)
```

## How It Works

Two sides cooperate for seamless two-way navigation:

```text
You press C-h in a Herdr pane:

  ┌─ Herdr intercepts the key (plugin_action keybind)
  │
  ├─ Is the focused pane running Neovim?
  │   │
  │   ├─ YES → forward "ctrl+h" into that pane
  │   │         └─ Neovim plugin receives it
  │   │              ├─ Has a window to the left? → wincmd h
  │   │              └─ At Neovim edge? → herdr pane focus --direction left
  │   │
  │   └─ NO (plain shell, etc.) → herdr pane focus --direction left
  │
  └─ Result: same keys move you everywhere
```

### Navigation

```text
1. Try moving within Neovim (wincmd h/j/k/l)
   ├─ Window changed → done (stayed within Neovim splits)
   └─ Window didn't change → at Neovim edge
        ├─ Zoomed? → unzoom first
        ├─ Check if Herdr is running (HERDR_ENV=1)
        ├─ Check if Herdr pane has a neighbour in this direction
        │   └─ Yes → herdr pane focus --direction → done
        └─ No (at both Neovim AND Herdr edge) →
             apply at_edge behaviour (wrap/stop/split/custom)
```

### Resizing

```text
1. Only one Neovim window in this dimension AND fills terminal?
   └─ Yes → herdr pane resize --direction --amount <ratio> → done
2. Otherwise:
   └─ Native Neovim resize with position-aware +/- operators
```

## Herdr Detection

Detected automatically through environment variables Herdr injects into every pane:

- `HERDR_ENV=1` — set when running inside a Herdr-managed pane
- `HERDR_PANE_ID` — the public pane ID (e.g., `w1:p1`)
- `HERDR_BIN_PATH` — path to the herdr binary (for subprocess calls)

## Comparison with vim-herdr-navigation

| Feature                     | vim-herdr-navigation | herdr-splits.nvim            |
| --------------------------- | -------------------- | ---------------------------- |
| Navigation                  | ✓                    | ✓                            |
| Resizing                    | ✗                    | ✓                            |
| at_edge behaviours          | ✗                    | wrap / stop / split / custom |
| Count prefix                | ✗                    | ✓ (3<C-h> = move 3 left)     |
| Auto-unzoom                 | ✗                    | ✓ (toggleable)               |
| Floating window handling    | ✗                    | ✓                            |
| Herdr plugin (for keybinds) | ✓                    | ✓                            |
| Neovim plugin               | ✓                    | ✓                            |

## Updating

The Neovim side (lua) auto-updates via lazy.nvim — it pulls `main` on
`LazySync`. The Herdr side (the bash scripts under the Herdr-managed
checkout) does **not** auto-update by default: Herdr v1 has no
`herdr plugin update`, so a managed checkout stays frozen at the commit it
was installed from.

**Option A — opt into automatic sync (recommended):** set
`auto_sync_herdr = true` in `setup()`. The plugin then reinstalls the
Herdr-managed checkout pinned to the exact commit lazy fetched, so the bash
scripts always match the lua side. It is a no-op when already in sync, when
in local-dev (`plugin link`) mode, or when the `herdr` binary is unavailable.

For maximum efficiency, also add a `build` hook so the sync fires only when
lazy actually updates the plugin, instead of on every Neovim startup:

```lua
{
  'lmilojevicc/herdr-splits.nvim',
  build = 'lua require("herdr-splits").sync_herdr()',
  config = function()
    require('herdr-splits').setup({ auto_sync_herdr = true })
  end,
}
```

**Option B — manual:** after an update, re-run
`herdr plugin install lmilojevicc/herdr-splits.nvim` to refresh the
Herdr-side scripts.

## License

MIT
