#!/usr/bin/env bash

ret=0 # exit code

# Protect against running with shells other than zsh
if [ -z "$BASH_VERSION" ]; then
  exec bash "$0" "$@"
fi

# Protect against unwanted sourcing
case "$BASH_EVAL_CONTEXT" in
  *:file)
    echo "error: this file should not be sourced" && return ;;
esac

set -e

# Make sure important variables exist if not already defined
#
# $USER is defined by login(1) which is not always executed (e.g. containers)
# POSIX: https://pubs.opengroup.org/onlinepubs/009695299/utilities/id.html
USER=${USER:-$(id -u -n)}
# $HOME is defined at the time of login, but it could be unset. If it is unset,
# a tilde by itself (~) will not be expanded to the current user's home directory.
# POSIX: https://pubs.opengroup.org/onlinepubs/009696899/basedefs/xbd_chap08.html#tag_08_03
HOME="${HOME:-$(getent passwd $USER 2>/dev/null | cut -d: -f6)}"
# macOS does not have getent, but this works even if $HOME is unset
HOME="${HOME:-$(eval echo ~$USER)}"

# Use $ARSENAL_DOT to keep track of where the directory is for zsh dotfiles
# To check if $ARSENAL_DOTDIR was provided, explicitly check for $ARSENAL_DOTDIR
ARSENAL_DOT="${ARSENAL_DOTDIR:-$HOME}"

# Default value for $ARSENAL_BASH
# a) if $ARSENAL_DOTDIR is supplied and not $HOME: $ARSENAL_DOTDIR/arsenal
# b) otherwise, $HOME/.arsenal
[ "$ARSENAL_DOTDIR" = "$HOME" ] || ARSENAL_BASH="${ARSENAL_BASH:-${ARSENAL_DOTDIR:+$ARSENAL_DOTDIR/arsenal}}"
ARSENAL_BASH="${ARSENAL_BASH:-$HOME/.arsenal}"

cd "$ARSENAL_BASH"

verbose_mode="default"
interactive=false

for opt in "$@"; do
  case $opt in
    -v|--verbose)
      verbose_mode="verbose"
      ;;
    -q|--quiet)
      verbose_mode="silent"
      ;;
    -i|--interactive)
      interactive=true
      ;;
    -h|--help)
      echo "Usage: $0 [-v|--verbose] [-s|--silent] [-i|--interactive] [-h|--help]"
      echo "  -v|--verbose:   verbose mode"
      echo "  -q|--quiet:     quiet mode"
      echo "  -i|--interactive: interactive mode"
      echo "  -h|--help:      show this help message"
      exit 0
      ;;
  esac
done

# Default settings
REPO=${REPO:-xransum/arsenal}
REMOTE=${REMOTE:-https://github.com/${REPO}.git}
BRANCH=${BRANCH:-master}


# Use colors, but only if connected to a terminal
# and that terminal supports them.

# The [ -t 1 ] check only works when the function is not called from
# a subshell (like in `$(...)` or `(...)`, so this hack redefines the
# function at the top level to always return false when stdout is not
# a tty.
if [ -t 1 ]; then
  is_tty() {
    true
  }
else
  is_tty() {
    false
  }
fi

# This function uses the logic from supports-hyperlinks[1][2], which is
# made by Kat Marchán (@zkat) and licensed under the Apache License 2.0.
# [1] https://github.com/zkat/supports-hyperlinks
# [2] https://crates.io/crates/supports-hyperlinks
#
# Copyright (c) 2021 Kat Marchán
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
supports_hyperlinks() {
  # $FORCE_HYPERLINK must be set and be non-zero (this acts as a logic bypass)
  if [ -n "$FORCE_HYPERLINK" ]; then
    [ "$FORCE_HYPERLINK" != 0 ]
    return $?
  fi

  # If stdout is not a tty, it doesn't support hyperlinks
  is_tty || return 1

  # DomTerm terminal emulator (domterm.org)
  if [ -n "$DOMTERM" ]; then
    return 0
  fi

  # VTE-based terminals above v0.50 (Gnome Terminal, Guake, ROXTerm, etc)
  if [ -n "$VTE_VERSION" ]; then
    [ $VTE_VERSION -ge 5000 ]
    return $?
  fi

  # If $TERM_PROGRAM is set, these terminals support hyperlinks
  case "$TERM_PROGRAM" in
  Hyper|iTerm.app|terminology|WezTerm) return 0 ;;
  esac

  # kitty supports hyperlinks
  if [ "$TERM" = xterm-kitty ]; then
    return 0
  fi

  # Windows Terminal also supports hyperlinks
  if [ -n "$WT_SESSION" ]; then
    return 0
  fi

  # Konsole supports hyperlinks, but it's an opt-in setting that can't be detected
  # https://github.com/xransum/arsenal/issues/10964
  # if [ -n "$KONSOLE_VERSION" ]; then
  #   return 0
  # fi

  return 1
}

# Adapted from code and information by Anton Kochkov (@XVilka)
# Source: https://gist.github.com/XVilka/8346728
supports_truecolor() {
  case "$COLORTERM" in
  truecolor|24bit) return 0 ;;
  esac

  case "$TERM" in
  iterm           |\
  tmux-truecolor  |\
  linux-truecolor |\
  xterm-truecolor |\
  screen-truecolor) return 0 ;;
  esac

  return 1
}

fmt_link() {
  # $1: text, $2: url, $3: fallback mode
  if supports_hyperlinks; then
    printf '\033]8;;%s\033\\%s\033]8;;\033\\\n' "$2" "$1"
    return
  fi

  case "$3" in
  --text) printf '%s\n' "$1" ;;
  --url|*) fmt_underline "$2" ;;
  esac
}

fmt_underline() {
  is_tty && printf '\033[4m%s\033[24m\n' "$*" || printf '%s\n' "$*"
}

setup_colors() {
  # Only use colors if connected to a terminal
  if ! is_tty; then
    RAINBOW=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    RESET=""
    return
  fi

  if supports_truecolor; then
    RAINBOW="
      $(printf '\033[38;2;255;0;0m')
      $(printf '\033[38;2;255;97;0m')
      $(printf '\033[38;2;247;255;0m')
      $(printf '\033[38;2;0;255;30m')
      $(printf '\033[38;2;77;0;255m')
      $(printf '\033[38;2;168;0;255m')
      $(printf '\033[38;2;245;0;172m')
    "
  else
    RAINBOW="
      $(printf '\033[38;5;196m')
      $(printf '\033[38;5;202m')
      $(printf '\033[38;5;226m')
      $(printf '\033[38;5;082m')
      $(printf '\033[38;5;021m')
      $(printf '\033[38;5;093m')
      $(printf '\033[38;5;163m')
    "
  fi

  RED=$(printf '\033[31m')
  GREEN=$(printf '\033[32m')
  YELLOW=$(printf '\033[33m')
  BLUE=$(printf '\033[34m')
  BOLD=$(printf '\033[1m')
  RESET=$(printf '\033[0m')
}

print_header() {
  printf '%s                                    __%s\n' $RED $RESET
  printf '%s  ____ ______________  ____  ____ _/ /%s\n' $RED $RESET
  printf '%s / __ `/ ___/ ___/ _ \/ __ \/ __ `/ / %s\n' $RED $RESET
  printf '%s/ /_/ / /  (__  )  __/ / / / /_/ / /  %s\n' $RED $RESET
  printf '%s\__,_/_/  /____/\___/_/ /_/\__,_/_/   %s\n' $RED $RESET
}

setup_colors

git remote -v | while read remote url extra; do
  case "$url" in
    git://github.com/xransum/arsenal*)
      # Update out-of-date "unauthenticated git protocol on port 9418" to https
      git remote set-url "$remote" "https://github.com/xransum/arsenal.git" ;;
    https://github.com/xransum/arsenal*)
      git remote set-url "$remote" "https://github.com/xransum/arsenal.git" ;;
    git@github.com:xransum/arsenal*)
      git remote set-url "$remote" "git@github.com:xransum/arsenal.git" ;;
    https://github.com/xransum/arsenal*) ;;
    git@github.com:xransum/arsenal*) ;;
    *) continue ;;
  esac

  # If we reach this point we have found the proper arsenal upstream remote. If we don't,
  # we'll only update from the set remote if `oh-my-zsh.remote` has been set to a remote,
  # as when installing from a fork.
  git config --local oh-my-zsh.remote "$remote"
  break
done

# Set git-config values known to fix git errors
# Line endings (#4069)
git config core.eol lf
git config core.autocrlf false
# zeroPaddedFilemode fsck errors (#4963)
git config fsck.zeroPaddedFilemode ignore
git config fetch.fsck.zeroPaddedFilemode ignore
git config receive.fsck.zeroPaddedFilemode ignore
# autostash on rebase (#7172)
#resetAutoStash=$(git config --bool rebase.autoStash 2>/dev/null)
git config rebase.autoStash true
# repository settings
# remote=${"$(git config --local arsenal.remote)":-origin}
remote="$(git config --local arsenal.remote)"
branch="$(git config --local arsenal.branch)"

if [[ -z "$remote" ]]; then
  remote=origin
fi
if [[ -z "$branch" ]]; then
  branch=master
fi

# repository state
last_head=$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)
# checkout update branch
git checkout -q "$branch" -- || exit 1
# branch commit before update (used in changelog)
last_commit=$(git rev-parse "$branch")

# Update Arsenal
if [[ $verbose_mode != silent ]]; then
  printf "${BLUE}%s${RESET}\n" "Updating Arsenal"
fi

if LANG= git pull --quiet --rebase $remote $branch; then
  # Check if it was really updated or not
  if [[ "$(git rev-parse HEAD)" = "$last_commit" ]]; then
    message="Arsenal is already at the latest version."
  else
    message="Hooray! Arsenal has been updated!"

    # Save the commit prior to updating
    git config arsenal.lastVersion "$last_commit"

  fi

  if [[ $verbose_mode == default ]]; then
    print_header
    printf '\n'
    printf "${BLUE}%s${RESET}\n\n" "$message"
  elif [[ $verbose_mode == minimal ]]; then
    printf "${BLUE}%s${RESET}\n" "$message"
  fi
else
  ret=$?
  printf "${RED}%s${RESET}\n" 'There was an error updating. Try again later?'
fi

# go back to HEAD previous to update
git checkout -q "$last_head" --

# Unset git-config values set just for the upgrade
case "$resetAutoStash" in
  "") git config --unset rebase.autoStash ;;
  *) git config rebase.autoStash "$resetAutoStash" ;;
esac

# Exit with `1` if the update failed
exit $ret