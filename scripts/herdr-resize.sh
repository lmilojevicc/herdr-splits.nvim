#!/usr/bin/env bash
# Herdr resize helper — used by herdr keybinds for seamless two-way resize.
#
# When a resize key (alt+h/j/k/l) is pressed in Herdr:
# 1. Check if the focused pane is running Neovim in the foreground
# 2. If yes: forward the key chord into that pane (Neovim's plugin handles it)
# 3. If no: resize Herdr pane directly
#
# Zoom state is left untouched (matches smart-splits.nvim's
# disable_multiplexer_nav_when_zoomed default).
#
# Usage: herdr-resize.sh <left|down|up|right> [amount]

set -euo pipefail

dir="${1:?usage: herdr-resize.sh <left|down|up|right> [amount]}"
amount="${2:-0.03}"
herdr="${HERDR_BIN_PATH:-herdr}"

case "$dir" in
  left)  key="alt+h" ;;
  down)  key="alt+j" ;;
  up)    key="alt+k" ;;
  right) key="alt+l" ;;
  *) echo "herdr-resize.sh: unknown direction: $dir" >&2; exit 2 ;;
esac

# Get focused pane ID from server
pane_id=$("$herdr" pane current --current 2>/dev/null | grep -o '"pane_id"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
if [ -z "$pane_id" ]; then
  exec "$herdr" pane resize --direction "$dir" --amount "$amount" --current
fi

# Check if focused pane is running vim/nvim as foreground process.
# When it is, the key is forwarded into Neovim so the plugin can decide
# whether to resize a Neovim split or hand off to Herdr.
is_vim=0
if pane_info=$("$herdr" pane process-info --current 2>/dev/null); then
  if echo "$pane_info" | grep -qiE '"name"\s*:\s*"(g?(view|l?n?vim?x?)(diff)?)"' 2>/dev/null; then
    is_vim=1
  fi
fi

if [ "$is_vim" -eq 1 ]; then
  exec "$herdr" pane send-keys "$pane_id" "$key"
else
  exec "$herdr" pane resize --direction "$dir" --amount "$amount" --current
fi
