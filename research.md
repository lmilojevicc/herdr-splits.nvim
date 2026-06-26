# Research: smart-splits.nvim tmux integration

## Summary

smart-splits.nvim is **not** "zero multiplexer config." It requires tmux-side configuration — either TPM plugin entries or manual `bind-key` commands in `tmux.conf` — for two-way seamless navigation. The Neovim side handles Neovim→tmux navigation via `tmux select-pane` CLI calls, but tmux→Neovim navigation depends entirely on tmux-side keybindings that conditionally pass keys through to Neovim using the `@pane-is-vim` pane variable.

## Findings

1. **`@pane-is-vim` is the core mechanism, and the Neovim plugin sets it automatically** — On plugin load (`VimEnter`), the Neovim plugin runs `tmux set-option -pt <pane_id> @pane-is-vim 1` via `M.on_init()`. It unsets it to `0` on `VimSuspend` and `VimLeavePre` via `M.on_exit()`. Nested Neovim instances are detected and skipped to avoid overwriting. [Source: `lua/smart-splits/mux/tmux.lua` lines 140-167](https://github.com/mrjones2014/smart-splits.nvim/blob/main/lua/smart-splits/mux/tmux.lua)

2. **tmux-side configuration is REQUIRED, not optional** — The README explicitly states: *"You will need to set up keymaps in your tmux, wezterm, or kitty configs to match the Neovim keymaps."* Two configuration methods are provided: (a) TPM plugin with `set -g @plugin 'mrjones2014/smart-splits.nvim'`, or (b) manual `bind-key -n` entries in `tmux.conf`. Without either, tmux→Neovim navigation does not work. [Source: README.md "Multiplexer Integrations → Tmux" section](https://github.com/mrjones2014/smart-splits.nvim#tmux)

3. **The `smart-splits.tmux` file is a bash-driven TPM config script** — It reads user options like `@smart-splits_move_left_key` (default `C-h`) and generates `bind-key -n` commands. The key pattern: `if -F '#{@pane-is-vim}' 'send-keys <key>' 'select-pane -<direction>'`. If the current pane has `@pane-is-vim` set (i.e., Neovim is running there), it forwards the key to Neovim; otherwise, tmux handles the pane switch itself. [Source: `smart-splits.tmux` lines 29-56](https://github.com/mrjones2014/smart-splits.nvim/blob/main/smart-splits.tmux)

4. **Neovim→tmux navigation uses CLI commands, not keybindings** — When Neovim has no more splits in a direction, it calls `tmux -S <socket> select-pane -<direction>` directly via the `M.next_pane()` method in `tmux.lua`. This works purely from the Neovim side without any tmux keybindings. The plugin auto-detects tmux via `$TERM_PROGRAM` environment variable. [Source: `lua/smart-splits/mux/tmux.lua` lines 119-124](https://github.com/mrjones2014/smart-splits.nvim/blob/main/lua/smart-splits/mux/tmux.lua)

5. **Navigation from a plain tmux shell pane uses tmux's own keybindings** — When you press `C-h` in a shell pane (not running Neovim), the `@pane-is-vim` variable is not set on that pane (`0` or unset), so the `if -F` condition evaluates to false and tmux executes `select-pane -L`. This is handled entirely by the tmux-side bindings, not the Neovim plugin. Without the tmux bindings, a plain shell pane has NO way to navigate to adjacent panes using these keys.

6. **Lazy-loading is explicitly discouraged for tmux integration** — The README warns: *"It is recommended to not lazy load smart-splits.nvim when using this integration. It depends on the plugin setting the @pane-is-vim tmux variable, which won't happen until the plugin is loaded."* This means `@pane-is-vim` is set on `VimEnter` (when the plugin loads), not before. If you lazy-load on e.g. `CmdLineEnter` or `BufRead`, there's a window where the variable is not set and tmux keybindings won't forward keys to Neovim. [Source: README.md Tmux section](https://github.com/mrjones2014/smart-splits.nvim#tmux)

7. **Resizing works on the same two-way model** — Tmux-side resize bindings use `if -F '#{@pane-is-vim}' 'send-keys <resize-key>' 'resize-pane -<dir> <step>'`, while the Neovim side calls `tmux resize-pane -<dir> <amount>` via `M.resize_pane()`. Both sides must be configured for resizing to work in both directions. [Source: `smart-splits.tmux` lines 59-63 and `lua/smart-splits/mux/tmux.lua` lines 126-130](https://github.com/mrjones2014/smart-splits.nvim)

## Sources

- **Kept**: smart-splits.nvim GitHub README (`/tmp/pi-github-repos/mrjones2014/smart-splits.nvim/README.md`) — Primary authoritative source for configuration requirements.
- **Kept**: `smart-splits.tmux` (`/tmp/pi-github-repos/mrjones2014/smart-splits.nvim/smart-splits.tmux`) — The actual TPM config script showing the exact bind-key logic.
- **Kept**: `lua/smart-splits/mux/tmux.lua` — The Neovim-side tmux integration, showing how `@pane-is-vim` is set/unset and how CLI commands are used.
- **Kept**: `lua/smart-splits/mux/utils.lua` — Shows the startup/lifecycle hooks for `on_init`/`on_exit` and auto-detection.
- **Kept**: `plugin/smart-splits.lua` — Main plugin entry point, confirming that `set_default_multiplexer()` and `startup()` run at load time.
- **Kept**: `lua/smart-splits/config.lua` — Configuration defaults including auto-detection of tmux via `$TERM_PROGRAM`.

## Gaps

- **Which tmux features require tmux ≥ 3.0?** — The `smart-splits.tmux` script includes a version check for the `C-\` (previous pane) binding, using different escape sequences for tmux < 3.0 vs ≥ 3.0. Most other features seem fine on older tmux, but this wasn't definitively confirmed.
- **SSH/nested tmux edge cases** — The code detects nested Neovim via `@pane-is-vim` but the behavior when tmux is running on a remote host (while the Neovim plugin thinks it's talking to a local tmux socket) is not fully explored here.
- **Performance/latency of `tmux` CLI calls** — Each `next_pane()`, `resize_pane()`, and `current_pane_at_edge()` call spawns a `tmux` subprocess. The latency implications for rapid key presses were not measured.

## Acceptance Report

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "7 concrete findings with specific file paths (smart-splits.tmux, lua/smart-splits/mux/tmux.lua, README.md) and line-number references. Core question answered: smart-splits.nvim is NOT zero multiplexer config; it requires tmux.conf keybindings for two-way navigation."
    }
  ],
  "changedFiles": [
    "/Users/milo/Projects/herdr-splits/research.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [],
  "validationOutput": [],
  "residualRisks": [
    "Performance of rapid tmux CLI subprocess spawns not measured",
    "SSH/nested tmux edge case behavior not fully explored",
    "tmux version compatibility (< 3.0) partially covered but not comprehensively verified"
  ],
  "noStagedFiles": true,
  "diffSummary": "Created research.md with detailed findings on smart-splits.nvim tmux integration",
  "reviewFindings": [
    "no blockers"
  ],
  "manualNotes": "The key architectural insight: Neovim→tmux uses CLI subprocess calls (zero tmux config needed), but tmux→Neovim requires tmux.conf bind-key entries using @pane-is-vim conditional forwarding. This is inherently asymmetric and cannot be fixed without tmux-side config."
}
```
