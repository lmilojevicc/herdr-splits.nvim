<!-- Thanks for the PR! Fill in the sections below. -->

## Summary

<!-- What does this change do, and why? One or two sentences. -->

## Changes

<!-- Bullet list of the notable changes. Mention any user-facing changes. -->

- 

## Validation

<!-- There is no automated test suite yet. Describe what you ran manually. -->

- [ ] Plugin loads with no errors in a Neovim + Herdr session (`HERDR_ENV=1`)
- [ ] `:checkhealth herdr-splits` reports no failures
- [ ] Navigation (`<C-h/j/k/l>`) works across Neovim splits and Herdr panes
- [ ] Resizing (`<M-h/j/k/l>`) works across Neovim splits and Herdr panes
- [ ] Edge cases relevant to this change exercised (at_edge, count prefix,
      floats, auto-unzoom)
- [ ] Bash changes checked with `bash -n scripts/*.sh` (if applicable)
- [ ] `README.md` / `herdr-plugin.toml` updated (if user-facing)

## Notes for review

<!-- Anything reviewers should pay attention to, or follow-up work. -->

Closes #NN
