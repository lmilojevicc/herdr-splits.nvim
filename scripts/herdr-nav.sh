#!/usr/bin/env bash
# Herdr navigation helper — used by herdr keybinds for seamless two-way nav.
#
# When a navigation key (ctrl+h/j/k/l) is pressed in Herdr:
# 1. Check if the focused pane is running Neovim in the foreground.
#    - If yes: forward the key chord into that pane. The Neovim plugin owns
#      in-split movement, edge crossing, and unzoom — do NOT unzoom here, or
#      moving between Neovim splits would incorrectly unzoom the pane.
# 2. If no (a plain Herdr pane): unzoom if needed, then move Herdr pane focus.
#    At a layout edge, focus wraps around to the opposite side (smart-splits
#    style), so navigating past the last pane lands on the first — unless
#    `nav_at_edge=stop`, in which case it halts at the edge.
#
# Auto-unzoom is configurable via `unzoom_on_nav=false` in
# `~/.config/herdr/plugins/config/herdr-splits/herdr-splits.conf`
# (same file the Neovim plugin reads). Default: enabled.
#
# Edge behaviour for plain Herdr panes is configurable via `nav_at_edge` in
# the same conf file: `wrap` (default; wraps to the opposite side at an edge)
# or `stop` (navigation halts at the edge instead of wrapping).
#
# Usage: herdr-nav.sh <left|down|up|right>

set -euo pipefail

dir="${1:?usage: herdr-nav.sh <left|down|up|right>}"
herdr="${HERDR_BIN_PATH:-herdr}"

case "$dir" in
  left)  key="ctrl+h"; opp="right" ;;
  down)  key="ctrl+j"; opp="up" ;;
  up)    key="ctrl+k"; opp="down" ;;
  right) key="ctrl+l"; opp="left" ;;
  *) echo "herdr-nav.sh: unknown direction: $dir" >&2; exit 2 ;;
esac

# Resolve `unzoom_on_nav` and `nav_at_edge` from the shared config file.
# Defaults: unzoom enabled, nav_at_edge=wrap (backward compatible).
unzoom=1
nav_at_edge=wrap
config_path="${HERDR_SPLITS_CONFIG:-$HOME/.config/herdr/plugins/config/herdr-splits/herdr-splits.conf}"
if [ -r "$config_path" ]; then
  if grep -Eq '^[[:space:]]*unzoom_on_nav[[:space:]]*=[[:space:]]*false' "$config_path"; then
    unzoom=0
  fi
  if grep -Eq '^[[:space:]]*nav_at_edge[[:space:]]*=[[:space:]]*stop' "$config_path"; then
    nav_at_edge=stop
  fi
fi

# Get focused pane ID from server (best-effort; empty is fine — we fall
# through to the non-vim path below, which uses --current directly).
pane_id=$("$herdr" pane current --current 2>/dev/null | grep -o '"pane_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)

# Check if focused pane is running vim/nvim as foreground process.
is_vim=0
if [ -n "$pane_id" ] && pane_info=$("$herdr" pane process-info --current 2>/dev/null); then
  if echo "$pane_info" | grep -qiE '"name"[[:space:]]*:[[:space:]]*"(g?(view|l?n?vim?x?)(diff)?)"' 2>/dev/null; then
    is_vim=1
  fi
fi

# Vim pane: forward the chord; the Neovim plugin decides movement + unzoom.
if [ "$is_vim" -eq 1 ]; then
  exec "$herdr" pane send-keys "$pane_id" "$key"
fi

# --- Non-vim Herdr pane: unzoom if needed, then focus (wrapping at edges) ---

# `pane edges` reports both edge flags and the zoomed state in one call.
edges_out=$("$herdr" pane edges --current 2>/dev/null || true)

# A zoomed pane fills the tab and reports itself at every edge, so the edge
# flags are useless for the wrap decision. Unzoom (if enabled) so we can
# trust them. If unzoom is disabled we leave zoom untouched and must NOT use
# the (all-true) edge flags — wrap is skipped below in that case.
edges_trusted=1
if printf '%s' "$edges_out" | grep -q '"zoomed"[[:space:]]*:[[:space:]]*true'; then
  if [ "$unzoom" -eq 1 ]; then
    "$herdr" pane zoom --off --current 2>/dev/null || true
    # Layout changed; re-read edges so the wrap check is accurate.
    edges_out=$("$herdr" pane edges --current 2>/dev/null || true)
  else
    edges_trusted=0
  fi
fi

# Move to the neighbor in the requested direction. When already at the
# requested edge (no neighbor there): wrap to the opposite side, or — when
# nav_at_edge=stop — do nothing. Skip the edge check when the flags are
# unreliable (still zoomed, unzoom disabled); in that case we can't tell
# whether we're at an edge, so we just focus in the requested direction.
if [ "$edges_trusted" -eq 1 ] && printf '%s' "$edges_out" | grep -q "\"$dir\"[[:space:]]*:[[:space:]]*true"; then
  if [ "$nav_at_edge" = stop ]; then
    exit 0
  fi
  exec "$herdr" pane focus --direction "$opp" --current
else
  exec "$herdr" pane focus --direction "$dir" --current
fi
