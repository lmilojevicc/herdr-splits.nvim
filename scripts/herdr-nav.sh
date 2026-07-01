#!/usr/bin/env bash
# Herdr navigation helper — used by herdr keybinds for seamless two-way nav.
#
# When a navigation key (ctrl+h/j/k/l) is pressed in Herdr:
# 1. Check if the focused pane is running Neovim in the foreground
# 2. If yes: forward the key chord into that pane (Neovim's plugin handles it)
# 3. If no: move Herdr pane focus directly
#
# If the pane is zoomed, unzoom first.
# To disable: create a herdr-splits.conf in the plugin config dir with:
#   unzoom_on_nav=false
# Default location: ~/.config/herdr/plugins/config/herdr-splits/herdr-splits.conf
# (override the path with HERDR_SPLITS_CONFIG)
#
# Usage: herdr-nav.sh <left|down|up|right>

set -euo pipefail

dir="${1:?usage: herdr-nav.sh <left|down|up|right>}"
herdr="${HERDR_BIN_PATH:-herdr}"

# --- config ---
# Read from config file, then env var, default to enabled.
unzoom=1
# Resolve the shared config file. Precedence: explicit HERDR_SPLITS_CONFIG
# override, then Herdr's plugin config dir (injected as HERDR_PLUGIN_CONFIG_DIR
# when Herdr launches this action), then the XDG default.
if [ -n "${HERDR_SPLITS_CONFIG:-}" ]; then
  config_file="$HERDR_SPLITS_CONFIG"
else
  base="${HERDR_PLUGIN_CONFIG_DIR:-}"
  if [ -z "$base" ]; then
    if [ -n "${XDG_CONFIG_HOME:-}" ] && [ "${XDG_CONFIG_HOME#/}" != "$XDG_CONFIG_HOME" ]; then
      base="$XDG_CONFIG_HOME/herdr/plugins/config/herdr-splits"
    else
      base="${HOME:-}/.config/herdr/plugins/config/herdr-splits"
    fi
  fi
  config_file="$base/herdr-splits.conf"
fi
if [ -f "$config_file" ]; then
  if grep -q '^\s*unzoom_on_nav\s*=\s*false' "$config_file" 2>/dev/null; then
    unzoom=0
  fi
elif [ "${HERDR_SPLITS_UNZOOM_NAV:-}" = "0" ]; then
  unzoom=0
fi
# --- end config ---

case "$dir" in
  left)  key="ctrl+h" ;;
  down)  key="ctrl+j" ;;
  up)    key="ctrl+k" ;;
  right) key="ctrl+l" ;;
  *) echo "herdr-nav.sh: unknown direction: $dir" >&2; exit 2 ;;
esac

# Get focused pane ID from server
pane_id=$("$herdr" pane current --current 2>/dev/null | grep -o '"pane_id"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
if [ -z "$pane_id" ]; then
  exec "$herdr" pane focus --direction "$dir" --current
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
  exec "$herdr" pane focus --direction "$dir" --current
fi
