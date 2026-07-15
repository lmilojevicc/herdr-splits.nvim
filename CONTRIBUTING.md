# Contributing to herdr-splits.nvim

Thanks for your interest in improving herdr-splits.nvim! This guide covers how
to set up a local development environment and submit changes.

herdr-splits.nvim is a Neovim plugin (Lua) that also ships a Herdr-side plugin
(the bash scripts under `scripts/` plus the `herdr-plugin.toml` manifest). The
two halves cooperate — please consider both when making changes to navigation
or resize behaviour.

## Requirements

- Neovim ≥ 0.10
- [Herdr](https://herdr.dev) ≥ 0.7.0 (only needed to exercise cross-pane
  behaviour; you can develop the Lua side without a running Herdr session)
- A Herdr-compatible terminal with Option/Alt enabled (see the README's macOS
  notes if you're on macOS)

## Repository layout

```
plugin/herdr-splits.lua        Neovim entrypoint
lua/herdr-splits/              Neovim plugin source
  init.lua                     setup() + public API
  nav.lua resize.lua           navigation and resizing
  win.lua                      float / sidebar classification
  sync.lua                     Herdr-side script syncing
  config.lua herdr.lua         config + core
  health.lua                   :checkhealth herdr-splits
scripts/herdr-nav.sh           Herdr-side navigation action
scripts/herdr-resize.sh        Herdr-side resize action
scripts/minimal_init.lua       Isolated Neovim test bootstrap
tests/                         mini.test suites
Makefile                       Local and CI validation commands
herdr-plugin.toml              Herdr plugin manifest (actions + metadata)
```

## Local development setup

### Neovim side

Point your plugin manager at a local clone instead of the published repo:

```lua
-- lazy.nvim
{
  dir = '~/Projects/herdr-splits',
  cond = vim.env.HERDR_ENV == '1',
  config = function()
    require('herdr-splits').setup({})
  end,
}
```

Changes to files under `lua/` take effect after `:source` or a Neovim restart
(unless your plugin manager hot-reloads).

### Herdr side

Link the clone so Herdr loads its scripts from your working tree:

```bash
herdr plugin link /path/to/herdr-splits
```

After changing `scripts/*.sh` or `herdr-plugin.toml`, run
`herdr server reload-config` to pick them up.

## Coding style

- Match the surrounding Lua style — indentation, quoting, and table layout in
  the file you're editing are the source of truth.
- Run [StyLua](https://github.com/JohnnyMorganz/StyLua) if you use it, but note
  that no `.stylua.toml` is committed yet; when one is added it will be the
  canonical formatter config.
- Run [luacheck](https://github.com/mpeterv/luacheck) where practical to catch
  undefined globals and unused variables.
- Keep the bash scripts POSIX-friendly where possible; they run on both Linux
  and macOS as declared in `herdr-plugin.toml`.

## Validation

The Make targets initialize and update the pinned test dependency automatically.
To prepare it separately, run `make deps`.

Run the automated checks with:

```bash
make test         # isolated mini.test suite in headless Neovim
make check-shell  # bash syntax checks for both shipped scripts
make check        # all of the above
```

Cross-pane behaviour still requires manual validation in a Herdr session:

1. Load the plugin in Neovim inside a Herdr session (`HERDR_ENV=1`).
2. Run `:checkhealth herdr-splits` and confirm it reports no failures.
3. Exercise navigation (`<C-h/j/k/l>`) and resizing (`<M-h/j/k/l>`) across both
   Neovim splits and Herdr panes, including the edge cases you changed:
   - `at_edge` behaviour (`wrap` / `stop` / `split` / custom)
   - count prefixes (e.g. `3<C-h>`)
   - floating windows and embedded-sidebar floats
   - auto-unzoom when crossing into a sibling Herdr pane

## Submitting changes

1. Fork the repo and create a branch from `main`.
2. Make focused commits with descriptive messages.
3. Open a pull request against `main` and fill in the PR template — include the
   manual validation steps you ran.
4. If your change affects user-facing behaviour or config, update `README.md`
   and, for manifest-level changes, `herdr-plugin.toml`.

Keep PRs scoped to one concern. Large changes are easier to review when split
into smaller, independently understandable commits.

## Reporting bugs and ideas

Use the GitHub issue templates (bug report / feature request). Include the
output of `nvim --version`, your plugin manager, the Herdr version
(`herdr --version`), and a minimal reproduction.

## License

By contributing you agree that your contributions are licensed under the MIT
License, the same terms as the rest of the project (see `LICENSE`).
