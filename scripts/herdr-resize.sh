#!/bin/sh
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
# Kept POSIX sh and run via /bin/sh to minimise per-keypress process spawns
# (see herdr-nav.sh).
#
# Usage: herdr-resize.sh <left|down|up|right> [amount]

set -eu

dir="${1:?usage: herdr-resize.sh <left|down|up|right> [amount]}"
amount="${2:-0.03}"
herdr="${HERDR_BIN_PATH:-herdr}"

case "$dir" in
  left)  key="alt+h"; config_key="resize_key_left" ;;
  down)  key="alt+j"; config_key="resize_key_down" ;;
  up)    key="alt+k"; config_key="resize_key_up" ;;
  right) key="alt+l"; config_key="resize_key_right" ;;
  *) echo "herdr-resize.sh: unknown direction: $dir" >&2; exit 2 ;;
esac

# Resolve the forward chord from the shared config file.
# Unset values keep the alt+hjkl default.
config_path="${HERDR_SPLITS_CONFIG:-${HERDR_PLUGIN_CONFIG_DIR:-$HOME/.config/herdr/plugins/config/herdr-splits}/herdr-splits.conf}"
if [ -r "$config_path" ]; then
  configured_key=$(sed -n -E "s/^[[:space:]]*${config_key}[[:space:]]*=[[:space:]]*([^[:space:]#]+).*$/\\1/p" "$config_path" | tail -n 1)
  if [ -n "$configured_key" ]; then
    key="$configured_key"
  fi
fi

# Check if the focused pane is running vim/nvim as its foreground process.
# When it is, the key is forwarded into Neovim so the plugin can decide
# whether to resize a Neovim split or hand off to Herdr. `process-info` also
# reports the pane ID, so one call answers both questions.
is_vim=0
pane_id=
if pane_info=$("$herdr" pane process-info --current 2>/dev/null); then
  if printf '%s' "$pane_info" | grep -qiE '"name"[[:space:]]*:[[:space:]]*"(g?(view|l?n?vim?x?)(diff)?)"' 2>/dev/null; then
    pane_id=$(printf '%s' "$pane_info" | grep -o '"pane_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)
    # Older Herdr releases may omit the pane ID from process-info.
    if [ -z "$pane_id" ]; then
      pane_id=$("$herdr" pane current --current 2>/dev/null | grep -o '"pane_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)
    fi
    [ -n "$pane_id" ] && is_vim=1
  fi
fi

if [ "$is_vim" -eq 1 ]; then
  exec "$herdr" pane send-keys "$pane_id" "$key"
else
  exec "$herdr" pane resize --direction "$dir" --amount "$amount" --current
fi
