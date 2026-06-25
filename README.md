# herdr-splits.nvim

Seamless navigation and resizing between Neovim splits and [Herdr](https://herdr.dev) panes. Makes Herdr terminal splits behave like native Neovim windows — move and resize as if they were all part of the same editor.

Inspired by [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim), ported to Herdr's CLI.

## Features

- **Seamless navigation**: `<C-h/j/k/l>` moves between Neovim splits, and crosses into neighbouring Herdr panes when you hit a Neovim edge. The same keys work everywhere.
- **Seamless resizing**: `<M-h/j/k/l>` resizes the current split. When a Neovim window fills the terminal width or height, the resize is forwarded to Herdr automatically.
- **at_edge behaviours**: `wrap` (default), `stop`, `split`, or a custom function — choose what happens when your cursor is at both a Neovim and Herdr edge.
- **Zoom-aware**: Optionally disables Herdr navigation when the current pane is zoomed.
- **Count prefix support**: `3<C-h>` moves three splits left; `5<M-l>` resizes five steps right.
- **Zero Herdr config needed**: No Herdr keybindings or plugin actions required. All logic lives in Neovim.

## Requirements

- Neovim ≥ 0.9
- [Herdr](https://herdr.dev) installed and running (detected via `HERDR_ENV` and `HERDR_PANE_ID` environment variables)

## Install

### lazy.nvim

```lua
{
  'your-org/herdr-splits.nvim',
  -- or local path:
  -- dir = '~/Projects/herdr-splits',
  config = function()
    require('herdr-splits').setup({
      -- Defaults shown below. All fields are optional.
      -- Resize amount as a Herdr ratio (0.03 = 3% of terminal in that dimension).
      default_amount = 0.03,
      -- Behavior when cursor is at a Neovim edge:
      -- 'wrap'  — wrap to the opposite side of Neovim
      -- 'stop'  — do nothing
      -- 'split' — create a new Neovim split
      -- function(context) — custom callback
      at_edge = 'wrap',
      -- Buffer types / filetypes ignored during resize operations.
      ignored_buftypes = { 'nofile', 'quickfix', 'prompt' },
      ignored_filetypes = { 'NvimTree' },
      -- When moving left/right, keep the cursor on the same screen row.
      move_cursor_same_row = false,
      -- Disable Herdr navigation when the current pane is zoomed.
      disable_nav_when_zoomed = true,
      -- Path to the herdr binary (auto-detected from HERDR_BIN_PATH if nil).
      herdr_bin = nil,
    })
  end,
}
```

### packer.nvim

```lua
use {
  'your-org/herdr-splits.nvim',
  config = function()
    require('herdr-splits').setup()
  end,
}
```

### Manual

Clone the repository and add it to your Neovim runtime path:

```bash
git clone https://github.com/your-org/herdr-splits.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/herdr-splits.nvim
```

## Key Mappings

The plugin does **not** set any keymaps automatically. Add these to your Neovim config:

```lua
-- Navigation (Ctrl + hjkl)
vim.keymap.set('n', '<C-h>', require('herdr-splits').move_cursor_left,  { desc = 'Navigate left' })
vim.keymap.set('n', '<C-j>', require('herdr-splits').move_cursor_down,  { desc = 'Navigate down' })
vim.keymap.set('n', '<C-k>', require('herdr-splits').move_cursor_up,    { desc = 'Navigate up' })
vim.keymap.set('n', '<C-l>', require('herdr-splits').move_cursor_right, { desc = 'Navigate right' })

-- Resizing (Alt/Option + hjkl)
vim.keymap.set('n', '<M-h>', require('herdr-splits').resize_left,  { desc = 'Resize left' })
vim.keymap.set('n', '<M-j>', require('herdr-splits').resize_down,  { desc = 'Resize down' })
vim.keymap.set('n', '<M-k>', require('herdr-splits').resize_up,    { desc = 'Resize up' })
vim.keymap.set('n', '<M-l>', require('herdr-splits').resize_right, { desc = 'Resize right' })
```

> **Note**: On macOS, some terminals require configuration to treat Option as Alt.  
> Ghostty: [`macos-option-as-alt = true`](https://ghostty.org/docs/config/reference#macos-option-as-alt)  
> Alacritty: [`option_as_alt = "Both"`](https://alacritty.org/config-alacritty.html#s20)

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

### Navigation

```
1. Try moving within Neovim (wincmd h/j/k/l)
   ├─ Window changed → done (stayed within Neovim splits)
   └─ Window didn't change → at Neovim edge
        ├─ Check if Herdr is running (HERDR_ENV=1)
        ├─ Check if Herdr pane is zoomed (optional)
        ├─ Check if Herdr pane has a neighbour in this direction
        │   └─ Yes → herdr pane focus --direction → done
        └─ No (at both Neovim AND Herdr edge) →
             apply at_edge behaviour (wrap/stop/split/custom)
```

### Resizing

```
1. Is the Neovim window full-width (for left/right) or full-height (for up/down)?
   └─ Yes → herdr pane resize --direction --amount <ratio> → done
2. Otherwise:
   └─ Native Neovim resize (wincmd resize)
```

### Herdr Detection

The plugin detects Herdr automatically through environment variables that Herdr injects into every pane:

- `HERDR_ENV=1` — set when running inside a Herdr-managed pane
- `HERDR_PANE_ID` — the public pane ID (e.g., `w1:p1`)
- `HERDR_BIN_PATH` — path to the herdr binary (for subprocess calls)

No Herdr configuration is required.

## Comparison with vim-herdr-navigation

[vim-herdr-navigation](https://github.com/paulbkim-dev/vim-herdr-navigation) takes a two-sided approach (Herdr plugin + editor mappings) modeled after `vim-tmux-navigator`. `herdr-splits.nvim` takes the opposite approach: all logic lives in Neovim, and Herdr is treated as a passive multiplexer. This means:

| Feature | vim-herdr-navigation | herdr-splits.nvim |
|---------|---------------------|-------------------|
| Navigation | ✓ | ✓ |
| Resizing | ✗ | ✓ |
| Herdr config needed | Yes (keybinds + plugin) | None |
| at_edge behaviours | ✗ | wrap / stop / split / custom |
| Count prefix | ✗ | ✓ (3<C-h> = move 3 left) |
| Zoom detection | ✗ | ✓ |
| Floating window handling | ✗ | ✓ |

## License

MIT
