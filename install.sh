#!/usr/bin/env bash
# claude-code-bootstrap: macOS and Linux installer
#
# One line, no sudo needed:
#   curl -fsSL https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/install.sh | bash
#
# Options (environment variables):
#   CCB_CHANNEL=stable        stable (default) | latest | version number, e.g. 2.1.89
#   CCB_EXTRAS=node,python    optional extra tools, installed with mise into your home
#   CCB_SKIP_GIT=1            do not try to install git
#
#   curl -fsSL .../install.sh | CCB_EXTRAS=node,python bash
#
# Everything goes into $HOME. Safe to run again.

main() {
  CHANNEL="${CCB_CHANNEL:-stable}"
  EXTRAS="${CCB_EXTRAS:-}"
  LOCAL_BIN="$HOME/.local/bin"
  CLAUDE_BIN="$LOCAL_BIN/claude"
  LOG="${TMPDIR:-/tmp}/claude-code-bootstrap-$(date +%Y%m%d-%H%M%S).log"
  PROBLEMS=()

  if [ -t 1 ]; then C='\033[36m'; G='\033[32m'; Y='\033[33m'; R='\033[31m'; N='\033[0m'; else C=''; G=''; Y=''; R=''; N=''; fi
  say()  { printf "${C}==> %s${N}\n" "$*"; }
  ok()   { printf "${G}  [OK]   %s${N}\n" "$*"; }
  warn() { printf "${Y}  [WARN] %s${N}\n" "$*"; PROBLEMS+=("$*"); }
  fail() { printf "${R}  [FAIL] %s${N}\n" "$*"; PROBLEMS+=("$*"); }
  has()  { command -v "$1" >/dev/null 2>&1; }

  # Root, or sudo that works without a password prompt. Never asks for a password.
  SUDO=""
  if [ "$(id -u)" -eq 0 ]; then CAN_ROOT=1
  elif has sudo && sudo -n true 2>/dev/null; then CAN_ROOT=1; SUDO="sudo -n"
  else CAN_ROOT=0; fi

  fetch() { # fetch URL -> stdout
    if has curl; then curl -fsSL --retry 3 "$1"
    elif has wget; then wget -qO- "$1"
    else return 127; fi
  }

  pkg_install() { # best effort system packages, only with root
    [ "$CAN_ROOT" -eq 1 ] || return 1
    if   has apt-get; then $SUDO apt-get update -qq && DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq "$@"
    elif has dnf;     then $SUDO dnf install -y -q "$@"
    elif has yum;     then $SUDO yum install -y -q "$@"
    elif has apk;     then $SUDO apk add --no-cache "$@"
    elif has pacman;  then $SUDO pacman -Sy --noconfirm "$@"
    elif has zypper;  then $SUDO zypper -n install "$@"
    else return 1; fi
  }

  add_line_once() { # file line
    local f="$1" line="$2"
    [ -f "$f" ] || touch "$f"
    grep -qsF "$line" "$f" || printf '\n# added by claude-code-bootstrap\n%s\n' "$line" >> "$f"
  }

  exec > >(tee -a "$LOG") 2>&1

  echo
  echo "  claude-code-bootstrap for $(uname -s)"
  echo "  channel: $CHANNEL   extras: ${EXTRAS:-none}"
  echo

  # 1. System check -----------------------------------------------------
  say "Checking the system"
  OS="$(uname -s)"; ARCH="$(uname -m)"; MUSL=0
  case "$OS" in
    Darwin)
      MACV="$(sw_vers -productVersion 2>/dev/null)"
      if [ "${MACV%%.*}" -lt 13 ] 2>/dev/null; then
        fail "macOS $MACV is too old. Claude Code needs macOS 13 or newer."; summary; return 1
      fi
      ok "macOS $MACV, $ARCH" ;;
    Linux)
      DISTRO="$( . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown Linux}")"
      if ldd --version 2>&1 | grep -qi musl || [ -f /etc/alpine-release ]; then MUSL=1; fi
      ok "$DISTRO, $ARCH$( [ $MUSL -eq 1 ] && echo ', musl')" ;;
    *)
      fail "Unsupported system: $OS. On Windows use install.ps1 in PowerShell."; summary; return 1 ;;
  esac

  if ! has curl && ! has wget; then
    pkg_install curl ca-certificates || true
  fi
  if ! has curl && ! has wget; then
    fail "Neither curl nor wget is available and they cannot be installed without root."; summary; return 1
  fi
  if fetch https://claude.ai/install.sh >/dev/null; then ok "Internet access to claude.ai works"
  else fail "Cannot reach https://claude.ai. Check internet or proxy (export HTTPS_PROXY=...)."; summary; return 1; fi

  # 2. Alpine / musl runtime dependencies --------------------------------
  if [ "$MUSL" -eq 1 ]; then
    say "musl runtime dependencies"
    if pkg_install bash curl libgcc libstdc++ ripgrep; then ok "bash curl libgcc libstdc++ ripgrep"
    else warn "Run as root: apk add bash curl libgcc libstdc++ ripgrep"; fi
  fi

  # 3. Git ----------------------------------------------------------------
  say "Git"
  if has git && git --version >/dev/null 2>&1; then
    ok "$(git --version)"
  elif [ "${CCB_SKIP_GIT:-}" = "1" ]; then
    warn "git skipped (CCB_SKIP_GIT=1)"
  elif [ "$OS" = "Darwin" ]; then
    # On a clean Mac 'git' is a stub that asks for Command Line Tools.
    xcode-select --install >/dev/null 2>&1 || true
    warn "git missing: a macOS window should ask to install Command Line Tools. Accept it, then run this installer again. Claude Code works without git."
  elif pkg_install git; then
    ok "$(git --version)"
  else
    warn "git missing and no root to install it. Claude Code works without git; ask your admin for the 'git' package."
  fi

  # 4. Claude Code (official native installer) ---------------------------
  say "Claude Code"
  if [ -x "$CLAUDE_BIN" ]; then
    ok "Already installed: $CLAUDE_BIN (it auto-updates; run 'claude update' to force)"
  else
    [ "$MUSL" -eq 1 ] && export USE_BUILTIN_RIPGREP=0
    for attempt in 1 2 3; do
      fetch https://claude.ai/install.sh | bash -s "$CHANNEL"
      [ -x "$CLAUDE_BIN" ] && break
      [ "$attempt" -lt 3 ] && { echo "  Download failed, retrying in 5 s (attempt $((attempt + 1))/3)..."; sleep 5; }
    done
    if [ -x "$CLAUDE_BIN" ]; then ok "Claude Code installed"
    else fail "Official Claude Code installer failed 3 times (details above)"; fi
  fi

  # 5. PATH and shell config ----------------------------------------------
  say "Shell configuration"
  echo "  (If the official installer said ~/.local/bin is not in your PATH: this step fixes it.)"
  export PATH="$LOCAL_BIN:$PATH"
  PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
  RC_FILES=("$HOME/.profile" "$HOME/.bashrc")
  [ "$OS" = "Darwin" ] && RC_FILES+=("$HOME/.zshrc" "$HOME/.bash_profile")
  has zsh && [ "$OS" != "Darwin" ] && RC_FILES+=("$HOME/.zshrc")
  for f in "${RC_FILES[@]}"; do
    add_line_once "$f" "$PATH_LINE"
    [ "$MUSL" -eq 1 ] && add_line_once "$f" 'export USE_BUILTIN_RIPGREP=0'
  done
  ok "~/.local/bin is on PATH in: ${RC_FILES[*]}"

  # 6. Optional extras via mise (user-level, no root) ---------------------
  if [ -n "$EXTRAS" ]; then
    say "Extras: $EXTRAS"
    if ! has mise && [ ! -x "$LOCAL_BIN/mise" ]; then
      fetch https://mise.run | sh || fail "mise install failed"
    fi
    MISE="$(command -v mise || echo "$LOCAL_BIN/mise")"
    if [ -x "$MISE" ]; then
      IFS=',' read -r -a items <<< "$EXTRAS"
      for e in "${items[@]}"; do
        e="$(echo "$e" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
        case "$e" in
          node|nodejs) tool="node@lts" ;;
          python)      tool="python@3.12" ;;
          uv)          tool="uv@latest" ;;
          ripgrep|rg)  tool="ripgrep@latest" ;;
          *) warn "Unknown extra '$e'. Known: node, python, uv, ripgrep"; continue ;;
        esac
        if MISE_YES=1 "$MISE" use -g "$tool"; then ok "$tool"; else fail "$tool install failed"; fi
      done
      for f in "${RC_FILES[@]}"; do
        case "$f" in
          *zshrc)  add_line_once "$f" 'eval "$(~/.local/bin/mise activate zsh)"' ;;
          *bashrc) add_line_once "$f" 'eval "$(~/.local/bin/mise activate bash)"' ;;
        esac
      done
    fi
  fi

  # 7. Verification ---------------------------------------------------------
  say "Verification"
  if [ -x "$CLAUDE_BIN" ]; then
    if v="$("$CLAUDE_BIN" --version 2>&1)"; then ok "claude --version: $v"; CLAUDE_OK=1; else fail "claude --version failed: $v"; fi
  fi
  summary

  # 8. Start Claude Code ----------------------------------------------------
  # With 'curl | bash' stdin is the script itself, so Claude gets the keyboard
  # straight from /dev/tty. Skipped in CI, without a terminal, or with CCB_NO_LAUNCH=1.
  if [ "${CLAUDE_OK:-0}" = "1" ] && [ -z "${CI:-}" ] && [ "${CCB_NO_LAUNCH:-}" != "1" ] && ( : </dev/tty ) 2>/dev/null; then
    say "Starting Claude Code in $HOME (exit with /exit or Ctrl+C twice)"
    echo
    cd "$HOME" 2>/dev/null || true
    "$CLAUDE_BIN" </dev/tty >/dev/tty 2>/dev/tty
  fi
}

summary() {
  echo
  if [ "${#PROBLEMS[@]}" -eq 0 ]; then
    printf "${G}  DONE. Everything is installed.${N}\n\n"
    echo "  Next steps:"
    echo "    1. Open a NEW terminal window (or run: exec \$SHELL -l)"
    echo "    2. Go to your project folder:   cd ~/path/to/project"
    echo "    3. Start Claude Code:           claude"
    echo "       The first start opens the browser to log in."
  else
    printf "${Y}  FINISHED WITH %s PROBLEM(S):${N}\n" "${#PROBLEMS[@]}"
    for p in "${PROBLEMS[@]}"; do printf "${Y}    - %s${N}\n" "$p"; done
    echo
    echo "  You can run the same command again, it continues where it stopped."
  fi
  echo "  Full log: $LOG"
  echo
}

# Called on the last line, so a partially downloaded script does nothing.
main "$@"
