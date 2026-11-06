#!/usr/bin/env bash
# claude-code-bootstrap: remove Claude Code from macOS / Linux (user level).
# Keeps ~/.claude unless CCB_PURGE=1. Git and mise are left in place.
#   curl -fsSL https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/uninstall.sh | bash
main() {
  rm -f "$HOME/.local/bin/claude" && rm -rf "$HOME/.local/share/claude"
  echo "  removed ~/.local/bin/claude and ~/.local/share/claude"
  if [ "${CCB_PURGE:-}" = "1" ]; then
    rm -rf "$HOME/.claude" "$HOME/.claude.json"
    echo "  removed ~/.claude and ~/.claude.json"
  else
    echo "  settings kept in ~/.claude (CCB_PURGE=1 deletes them too)"
  fi
  echo "  The PATH line in your shell rc files is harmless and was left in place."
}
main "$@"
