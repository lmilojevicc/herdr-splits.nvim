<!-- Thanks for the PR! Fill in the sections below. -->

## Summary

<!-- What does this change do, and why? One or two sentences. -->

## Changes

<!-- Bullet list of the notable changes. Mention any user-facing changes. -->

- 

## Validation

<!-- Check the automated commands you ran and describe any manual coverage. -->

- [ ] `make test` passes
- [ ] `make check-shell` passes
- [ ] Plugin loads with no errors in a Neovim + Herdr session (`HERDR_ENV=1`)
- [ ] `:checkhealth herdr-splits` reports no failures
- [ ] Navigation (`<C-h/j/k/l>`) works across Neovim splits and Herdr panes
- [ ] Resizing (`<M-h/j/k/l>`) works across Neovim splits and Herdr panes
- [ ] Edge cases relevant to this change exercised (at_edge, count prefix,
      floats, auto-unzoom)
- [ ] `README.md` / `herdr-plugin.toml` updated (if user-facing)

## Notes for review

<!-- Anything reviewers should pay attention to, or follow-up work. -->

Closes #NN
