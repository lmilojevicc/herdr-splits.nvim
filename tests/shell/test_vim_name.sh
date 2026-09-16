#!/usr/bin/env bash
# Regression coverage for the foreground-process name match used by
# herdr-nav.sh and herdr-resize.sh to decide "is this pane running Vim?".
#
# The pattern is duplicated in both scripts; this test extracts it from
# herdr-nav.sh so it can never drift from the thing it claims to cover.
#
# Usage: tests/shell/test_vim_name.sh

set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
nav="$root/scripts/herdr-nav.sh"
resize="$root/scripts/herdr-resize.sh"

# Pull the ERE out of the `grep -qiE '...'` line so the test and the script
# can never disagree about what is being matched.
extract_re() {
  sed -n "s/.*grep -qiE '\(.*\)' 2>\/dev\/null.*/\1/p" "$1" | head -1
}

re="$(extract_re "$nav")"
re_resize="$(extract_re "$resize")"

if [ -z "$re" ]; then
  echo "FAIL: could not extract the name pattern from $nav" >&2
  exit 1
fi

if [ "$re" != "$re_resize" ]; then
  echo "FAIL: nav and resize disagree on the name pattern" >&2
  echo "  nav:    $re" >&2
  echo "  resize: $re_resize" >&2
  exit 1
fi

fails=0

expect_match() {
  if printf '{"name": "%s"}' "$1" | grep -qiE "$re"; then
    return 0
  fi
  echo "FAIL: expected $1 to be treated as Vim" >&2
  fails=$((fails + 1))
}

expect_no_match() {
  if printf '{"name": "%s"}' "$1" | grep -qiE "$re"; then
    echo "FAIL: expected $1 NOT to be treated as Vim" >&2
    fails=$((fails + 1))
  fi
}

# POSIX process names.
expect_match vim
expect_match nvim
expect_match view
expect_match gvim
expect_match vimdiff
expect_match gvimdiff
expect_match nvimdiff

# Windows reports PROCESSENTRY32W.szExeFile verbatim, extension included.
expect_match nvim.exe
expect_match vim.exe
expect_match gvim.exe
expect_match vimdiff.exe
expect_match NVIM.EXE

# Near misses that must not be mistaken for an editor.
expect_no_match bash
expect_no_match node
expect_no_match pwsh.exe
expect_no_match nvimpager
expect_no_match vimrc
expect_no_match nvim-qt
expect_no_match myvim.exe

if [ "$fails" -ne 0 ]; then
  echo "$fails assertion(s) failed" >&2
  exit 1
fi

echo "ok: vim name matching"
