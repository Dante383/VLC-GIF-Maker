#!/usr/bin/env bash
#
# VLC GIF Maker — one-click installer for Debian-based Linux.
#
# Installs the VLC GIF Maker Lua extension
# (https://github.com/Dante383/VLC-GIF-Maker) either for the current user or
# for all users. It copies vlc_gif_maker.lua into VLC's extensions directory
# and offers to install VLC/ffmpeg through apt when they are missing.
#
#   ./vlc-gif-maker.sh            # interactive: 1) current user  2) all users
#   ./vlc-gif-maker.sh -user      # current user (no prompt)
#   ./vlc-gif-maker.sh -system    # all users (needs sudo)
#   ./vlc-gif-maker.sh -h
#
# Environment overrides:
#   VLC_GIF_MAKER_LUA       source .lua file (default: sibling file, else download)
#   VLC_GIF_MAKER_URL       download URL for vlc_gif_maker.lua
#   VLC_GIF_MAKER_EXT_DIR   target VLC extensions directory (mainly for testing)
#   VLC_GIF_MAKER_ASSUME_NO set to 1 to decline all apt prompts (testing)
#
set -euo pipefail

VLC_GIF_MAKER_URL="${VLC_GIF_MAKER_URL:-https://raw.githubusercontent.com/Dante383/VLC-GIF-Maker/main/vlc_gif_maker.lua}"

INSTALL_TYPE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [-user | -system | -h]

  (no flag)  interactively choose:
               1) current user
               2) all users (requires sudo)
  -user      install for the current user
  -system    install for all users (requires sudo)
  -h         show this help

Environment overrides:
  VLC_GIF_MAKER_LUA       source .lua file (default: sibling file, else download)
  VLC_GIF_MAKER_URL       download URL for vlc_gif_maker.lua
  VLC_GIF_MAKER_EXT_DIR   target VLC extensions directory
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -system|--system) INSTALL_TYPE="system"; shift ;;
    -user|--user)     INSTALL_TYPE="user";   shift ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1 (use -user, -system, or -h)" >&2; exit 1 ;;
  esac
done

log()  { printf '[vlc-gif-maker] %s\n' "$*"; }
warn() { printf '[vlc-gif-maker] warning: %s\n' "$*" >&2; }
die()  { printf '[vlc-gif-maker] error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

TMP_DIR=""
LUA_SOURCE=""
APT_UPDATED=0

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
  return 0
}
trap cleanup EXIT

# ---- Mode selection --------------------------------------------------------

select_mode() {
  [[ -n "$INSTALL_TYPE" ]] && return 0

  if [[ ! -t 0 ]]; then
    INSTALL_TYPE="user"
    log "non-interactive input; defaulting to a current-user install"
    return 0
  fi

  local choice
  printf 'Install VLC GIF Maker for:\n'
  printf '  1) current user (%s)\n' "$(id -un)"
  printf '  2) all users (requires sudo)\n'
  read -rp "Select [1/2] (default 1): " choice || choice=""
  case "$choice" in
    2) INSTALL_TYPE="system" ;;
    ''|1) INSTALL_TYPE="user" ;;
    *) die "invalid selection '$choice' (expected 1 or 2)" ;;
  esac
}

# ---- Prerequisites ---------------------------------------------------------

require_debian() {
  [[ -f /etc/debian_version ]] || have apt-get \
    || die "this installer targets Debian-based Linux (apt-get not found)"
}

setup_privileges() {
  if [[ $EUID -eq 0 ]]; then
    SUDO=""
  else
    SUDO="sudo"
  fi
}

apt_install() {
  if [[ -n "$SUDO" ]] && ! have sudo; then
    die "sudo is required to install packages but was not found"
  fi
  if [[ "$APT_UPDATED" -eq 0 ]]; then
    $SUDO apt-get update \
      || warn "apt-get update reported errors (a configured repository may be broken); continuing"
    APT_UPDATED=1
  fi
  $SUDO apt-get install -y "$@" \
    || die "failed to install package(s): $*"
}

# Ask before touching the system. Returns 0 only when the user agrees.
ask_install() {
  local package="$1"
  if [[ "${VLC_GIF_MAKER_ASSUME_NO:-0}" == "1" || ! -t 0 ]]; then
    return 1
  fi
  local answer
  read -rp "Install '$package' now via apt-get? [y/N] " answer || answer=""
  case "$answer" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_vlc() {
  if have vlc || dpkg -s vlc >/dev/null 2>&1; then
    log "VLC is installed"
    return 0
  fi
  warn "VLC is not installed"
  if ask_install vlc; then
    apt_install vlc
    have vlc || die "VLC installation failed"
    log "VLC installed"
  else
    warn "continuing without VLC; the extension will not appear until VLC is installed"
  fi
}

ensure_ffmpeg() {
  if have ffmpeg; then
    log "ffmpeg is installed"
    return 0
  fi
  warn "ffmpeg is not installed; it is required to generate GIFs"
  if ask_install ffmpeg; then
    apt_install ffmpeg
    have ffmpeg || die "ffmpeg installation failed"
    log "ffmpeg installed"
  else
    warn "continuing without ffmpeg; GIF generation will fail until it is installed"
  fi
}

# ---- Lua source ------------------------------------------------------------

# Sets the global LUA_SOURCE. Kept global (not printed) because it may create a
# temporary download that the EXIT trap must still see in the parent shell.
resolve_lua() {
  if [[ -n "${VLC_GIF_MAKER_LUA:-}" ]]; then
    [[ -f "$VLC_GIF_MAKER_LUA" ]] || die "VLC_GIF_MAKER_LUA does not exist: $VLC_GIF_MAKER_LUA"
    LUA_SOURCE="$VLC_GIF_MAKER_LUA"
    return 0
  fi

  local sibling
  sibling="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vlc_gif_maker.lua"
  if [[ -f "$sibling" ]]; then
    LUA_SOURCE="$sibling"
    return 0
  fi

  TMP_DIR="$(mktemp -d)"
  local dest="$TMP_DIR/vlc_gif_maker.lua"
  log "downloading vlc_gif_maker.lua"
  if have curl; then
    curl -fsSL --retry 3 -o "$dest" "$VLC_GIF_MAKER_URL" \
      || die "failed to download $VLC_GIF_MAKER_URL"
  elif have wget; then
    wget -q -O "$dest" "$VLC_GIF_MAKER_URL" \
      || die "failed to download $VLC_GIF_MAKER_URL"
  else
    die "neither curl nor wget is available to download the extension"
  fi
  [[ -s "$dest" ]] || die "downloaded file is empty: $VLC_GIF_MAKER_URL"
  LUA_SOURCE="$dest"
}

# ---- Target directory ------------------------------------------------------

detect_system_ext_dir() {
  local dir=""

  if have dpkg; then
    dir="$(dpkg -L vlc-plugin-base 2>/dev/null \
      | awk '/\/vlc\/lua\/extensions$/ { print; exit }')" || true
    [[ -n "$dir" ]] || dir="$(dpkg -L vlc 2>/dev/null \
      | awk '/\/vlc\/lua\/extensions$/ { print; exit }')" || true
  fi
  if [[ -z "$dir" ]]; then
    dir="$(find /usr/lib -type d -path '*/vlc/lua/extensions' 2>/dev/null | head -n1)" || true
  fi
  [[ -n "$dir" ]] || dir="/usr/lib/vlc/lua/extensions"

  printf '%s\n' "$dir"
}

resolve_ext_dir() {
  if [[ -n "${VLC_GIF_MAKER_EXT_DIR:-}" ]]; then
    printf '%s\n' "$VLC_GIF_MAKER_EXT_DIR"
  elif [[ "$INSTALL_TYPE" == "system" ]]; then
    detect_system_ext_dir
  else
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/vlc/lua/extensions"
  fi
}

# ---- Installation ----------------------------------------------------------

install_extension() {
  local source="$1" target_dir="$2"
  mkdir -p "$target_dir" 2>/dev/null || $SUDO mkdir -p "$target_dir"
  if [[ -w "$target_dir" ]]; then
    cp -f "$source" "$target_dir/vlc_gif_maker.lua"
    chmod 644 "$target_dir/vlc_gif_maker.lua"
  else
    $SUDO cp -f "$source" "$target_dir/vlc_gif_maker.lua"
    $SUDO chmod 644 "$target_dir/vlc_gif_maker.lua"
  fi
  [[ -f "$target_dir/vlc_gif_maker.lua" ]] \
    || die "installation verification failed: $target_dir/vlc_gif_maker.lua is missing"
  log "installed: $target_dir/vlc_gif_maker.lua"
}

# ---- Main ------------------------------------------------------------------

# Testing hook: source with VLC_GIF_MAKER_LIB_ONLY=1 to load functions only.
if [[ "${VLC_GIF_MAKER_LIB_ONLY:-0}" == "1" ]]; then return 0 2>/dev/null || exit 0; fi

select_mode
setup_privileges
require_debian
ensure_vlc
ensure_ffmpeg

resolve_lua
EXT_DIR="$(resolve_ext_dir)"

log "installing for $INSTALL_TYPE (target: $EXT_DIR)"
install_extension "$LUA_SOURCE" "$EXT_DIR"

cat <<EOF

============================================================
VLC GIF Maker is installed.

  mode   : $INSTALL_TYPE
  file   : $EXT_DIR/vlc_gif_maker.lua

Restart VLC, then open:
  View > VLC GIF Maker

ffmpeg must be on PATH to generate GIFs.
============================================================
EOF
