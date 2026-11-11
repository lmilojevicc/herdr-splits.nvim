#!/bin/sh
# Isolated tests for the Herdr-side scripts. A fake `herdr` binary (passed via
# HERDR_BIN_PATH) records every invocation and returns canned JSON, so no
# Herdr server is needed.
#
# Usage: tests/scripts_test.sh [shell...]   (default: sh, plus dash/bash if found)

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fake="$tmp/herdr"
cat >"$fake" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_LOG"
case "$1 $2" in
  "pane process-info")
    [ "${FAKE_PROCINFO_FAIL:-0}" = 1 ] && exit 1
    pane_field='"pane_id":"w1:p7",'
    [ "${FAKE_PROCINFO_NO_PANE_ID:-0}" = 1 ] && pane_field=
    printf '{"id":"cli:pane:process_info","result":{"process_info":{"foreground_process_group_id":1,"foreground_processes":[{"argv":["%s"],"argv0":"%s","cmdline":"%s \\"pane_id\\":\\"bogus\\"","name":"%s","pid":2}],%s"shell_pid":1},"type":"pane_process_info"}}\n' \
      "$FAKE_PROC" "$FAKE_PROC" "$FAKE_PROC" "$FAKE_PROC" "$pane_field"
    ;;
  "pane current")
    printf '{"id":"cli:pane:current","result":{"pane":{"pane_id":"w1:p9"}}}\n'
    ;;
  "pane edges")
    zoomed=false
    if [ "${FAKE_ZOOMED:-0}" = 1 ] && ! grep -q 'zoom --off' "$FAKE_LOG"; then zoomed=true; fi
    printf '{"result":{"type":"pane_edges","edges":{"pane_id":"w1:p7","left":%s,"right":false,"up":false,"down":false,"zoomed":%s}}}\n' \
      "${FAKE_LEFT_EDGE:-false}" "$zoomed"
    ;;
esac
exit 0
EOF
chmod +x "$fake"

conf="$tmp/herdr-splits.conf"
pass=0
fail=0

# run <shell> <name> <expected-calls> <script> <args...>
# Scenario knobs come from the environment (FAKE_*, conf contents).
run() {
  shell=$1 name=$2 expected=$3 script=$4
  shift 4
  FAKE_LOG="$tmp/log"
  : >"$FAKE_LOG"
  export FAKE_LOG
  HERDR_BIN_PATH="$fake" HERDR_SPLITS_CONFIG="$conf" "$shell" "$root/scripts/$script" "$@" >/dev/null 2>&1 || true
  actual=$(cat "$FAKE_LOG")
  if [ "$actual" = "$expected" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL [%s] %s\n  expected:\n%s\n  actual:\n%s\n' "$shell" "$name" \
      "$(printf '%s' "$expected" | sed 's/^/    /')" "$(printf '%s' "$actual" | sed 's/^/    /')"
  fi
}

reset() {
  FAKE_PROC=zsh FAKE_PROCINFO_FAIL=0 FAKE_PROCINFO_NO_PANE_ID=0 FAKE_ZOOMED=0 FAKE_LEFT_EDGE=false
  export FAKE_PROC FAKE_PROCINFO_FAIL FAKE_PROCINFO_NO_PANE_ID FAKE_ZOOMED FAKE_LEFT_EDGE
  : >"$conf"
}

nl='
'

suite() {
  sh=$1

  reset; FAKE_PROC=nvim
  run "$sh" 'nav: nvim pane forwards key with one lookup' \
    "pane process-info --current${nl}pane send-keys w1:p7 ctrl+h" herdr-nav.sh left

  reset; FAKE_PROC=nvim; printf 'nav_key_left=alt+left\n' >"$conf"
  run "$sh" 'nav: configured forward key' \
    "pane process-info --current${nl}pane send-keys w1:p7 alt+left" herdr-nav.sh left

  reset; FAKE_PROC=nvim; FAKE_PROCINFO_NO_PANE_ID=1
  run "$sh" 'nav: falls back to pane current when process-info lacks pane_id' \
    "pane process-info --current${nl}pane current --current${nl}pane send-keys w1:p9 ctrl+h" herdr-nav.sh left

  reset
  run "$sh" 'nav: shell pane moves focus' \
    "pane process-info --current${nl}pane edges --current${nl}pane focus --direction left --current" herdr-nav.sh left

  reset; FAKE_LEFT_EDGE=true
  run "$sh" 'nav: wraps at edge' \
    "pane process-info --current${nl}pane edges --current${nl}pane focus --direction right --current" herdr-nav.sh left

  reset; FAKE_LEFT_EDGE=true; printf 'nav_at_edge=stop\n' >"$conf"
  run "$sh" 'nav: nav_at_edge=stop halts at edge' \
    "pane process-info --current${nl}pane edges --current" herdr-nav.sh left

  reset; FAKE_ZOOMED=1
  run "$sh" 'nav: unzooms before moving' \
    "pane process-info --current${nl}pane edges --current${nl}pane zoom --off --current${nl}pane edges --current${nl}pane focus --direction left --current" herdr-nav.sh left

  reset; FAKE_ZOOMED=1; printf 'unzoom_on_nav=false\n' >"$conf"
  run "$sh" 'nav: unzoom disabled skips edge check' \
    "pane process-info --current${nl}pane edges --current${nl}pane focus --direction left --current" herdr-nav.sh left

  reset; FAKE_PROC=nvim; FAKE_PROCINFO_FAIL=1
  run "$sh" 'nav: process-info failure falls back to Herdr focus' \
    "pane process-info --current${nl}pane edges --current${nl}pane focus --direction left --current" herdr-nav.sh left

  reset; FAKE_PROC=nvim
  run "$sh" 'resize: nvim pane forwards key with one lookup' \
    "pane process-info --current${nl}pane send-keys w1:p7 alt+h" herdr-resize.sh left

  reset; FAKE_PROC=nvim; printf 'resize_key_left=ctrl+left\n' >"$conf"
  run "$sh" 'resize: configured forward key' \
    "pane process-info --current${nl}pane send-keys w1:p7 ctrl+left" herdr-resize.sh left

  reset; FAKE_PROC=nvim; FAKE_PROCINFO_NO_PANE_ID=1
  run "$sh" 'resize: falls back to pane current when process-info lacks pane_id' \
    "pane process-info --current${nl}pane current --current${nl}pane send-keys w1:p9 alt+h" herdr-resize.sh left

  reset
  run "$sh" 'resize: shell pane resizes Herdr pane' \
    "pane process-info --current${nl}pane resize --direction left --amount 0.03 --current" herdr-resize.sh left

  reset; FAKE_PROC=nvim; FAKE_PROCINFO_FAIL=1
  run "$sh" 'resize: process-info failure falls back to Herdr resize' \
    "pane process-info --current${nl}pane resize --direction up --amount 0.05 --current" herdr-resize.sh up 0.05
}

if [ "$#" -gt 0 ]; then
  shells="$*"
else
  shells='sh'
  for candidate in dash bash; do
    command -v "$candidate" >/dev/null 2>&1 && shells="$shells $candidate"
  done
fi

for sh in $shells; do
  suite "$sh"
done

printf '%d passed, %d failed (shells: %s)\n' "$pass" "$fail" "$shells"
[ "$fail" -eq 0 ]
