#!/usr/bin/env bash
# Herdr resize helper — used by herdr keybinds for seamless two-way resize.
#
# When a resize key (alt+h/j/k/l) is pressed in Herdr:
# 1. Check if the focused pane is running Neovim in the foreground
# 2. If yes: forward the key chord into that pane (Neovim's plugin handles it)
# 3. If no: resize Herdr pane directly
#
# If the pane is zoomed, unzoom first.
# To disable: create ~/.config/herdr-splits/herdr-splits.conf with:
#   unzoom_on_nav=false
#
# Usage: herdr-resize.sh <left|down|up|right> [amount]

set -euo pipefail

dir="${1:?usage: herdr-resize.sh <left|down|up|right> [amount]}"
amount="${2:-0.03}"
herdr="${HERDR_BIN_PATH:-herdr}"

# --- config ---
unzoom=1
config_file="${HERDR_SPLITS_CONFIG:-$HOME/.config/herdr-splits/herdr-splits.conf}"
if [ -f "$config_file" ]; then
  if grep -q '^\s*unzoom_on_nav\s*=\s*false' "$config_file" 2>/dev/null; then
    unzoom=0
  fi
elif [ "${HERDR_SPLITS_UNZOOM_NAV:-}" = "0" ]; then
  unzoom=0
fi
# --- end config ---

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

# Unzoom if configured and pane is zoomed
if [ "$unzoom" != "0" ]; then
  is_zoomed=$("$herdr" pane layout --current 2>/dev/null | grep -o '"zoomed"\s*:\s*true' || true)
  if [ -n "$is_zoomed" ]; then
    "$herdr" pane zoom --off --current 2>/dev/null || true
  fi
fi

# Check if focused pane is running vim/nvim as foreground process
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
