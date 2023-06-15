#!/usr/bin/env sh

# TODO: Add installer scripts to ~/bin/ with arsenal_<update|uninstall> so that
# they can be called from anywhere and easily updated.

SOURCE=${BASH_SOURCE[0]}
# resolve $SOURCE until the file is no longer a symlink
while [ -L "$SOURCE" ]; do
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  # if $SOURCE was a relative symlink, we need to resolve it
  # relative to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done

DIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
REPO_DIR=$(cd -P "$(dirname "$DIR")" >/dev/null 2>&1 && pwd)

REPO_NAME=$(basename "$REPO_DIR")
SRC_DIR="$REPO_DIR/src"
BIN_DIR="$REPO_DIR/bin"

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

setup_color() {
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

setup_color
print_header

printf '\n'
printf '%s\n' "!!! ${RED}FOR DEVELOPMENTAL USE ONLY${RESET} !!!"
printf '%s\n' "PLEASE READ ON HOW-TO USE: $(fmt_link @DEVELOPMENT https://github.com/xransum/arsenal/blob/master/DEVELOPMENT.md)"
printf '\n'
printf '%s\n' "${YELLOW}This script will automatically generate the symlinks for the scripts in the src directory.${RESET}"
printf '%s\n' "${YELLOW}It will also remove any broken symlinks that don't resolve properly.${RESET}"
# printf '%s\n' "${BLUE}After running this script and testing the scripts, you can run the build.sh script to generate the binaries.${RESET}"
printf '%s\n' "${YELLOW}After running this script and testing the symlinks, you need to commit the changes to the repo.${RESET}"
printf '\n'

# remove all symlinks in bin that don't point to a src file that is real
SYMBOLIC_SCRIPTS=$(find $BIN_DIR -type l)
printf '%s\n' "${BLUE}Discovered ${#SYMBOLIC_SCRIPTS[@]} symbolically linked scripts...${RESET}"

printf '\n%s\n' "${BLUE}Checking for broken symbolic links...${RESET}"
for SYMBOLIC_LINK in $SYMBOLIC_SCRIPTS; do
    SCRIPT_SRC=$(readlink "$SYMBOLIC_LINK")
    RELATIVE_SYMBOLIC_LINK=$(realpath --relative-to="$BIN_DIR" "$SYMBOLIC_LINK")
    RELATIVE_SCRIPT_SRC=$(realpath --relative-to="$SRC_DIR" "$SCRIPT_SRC")

    # remove symbolic link if src doesn't exist
    if [ ! -f "$SCRIPT_SRC" ]; then
        printf '%s\n' "Removing symlink: ${RED}${RELATIVE_SYMBOLIC_LINK}${RESET} - Source doesn't exist."
        rm -f "$SYMBOLIC_LINK"
    # remove symbolic link if src isn't executable
    elif [ ! -x "$SCRIPT_SRC" ]; then
        printf '%s\n' "Removing symlink: ${RED}${RELATIVE_SYMBOLIC_LINK}${RESET} - No longer executable"
        rm -f "$SYMBOLIC_LINK"
    # remove symbolic link if src is a symlink
    elif [ -L "$SCRIPT_SRC" ]; then
        printf '%s\n' "Removing symlink: ${RED}${RELATIVE_SYMBOLIC_LINK}${RESET} - Source is a symlink"
        rm -f "$SYMBOLIC_LINK"
    # remove symbolic link if src is a directory
    elif [ -d "$SCRIPT_SRC" ]; then
        printf '%s\n' "Removing symlink: ${RED}${RELATIVE_SYMBOLIC_LINK}${RESET} - Source is a directory"
        rm -f "$SYMBOLIC_LINK"
    # remove symbolic link if src is a broken symlink
    elif [ ! -e "$SCRIPT_SRC" ]; then
        printf '%s\n' "Removing symlink: ${RED}${RELATIVE_SYMBOLIC_LINK}${RESET} - Source is a broken symlink"
        rm -f "$SYMBOLIC_LINK"
    else
        printf '%s\n' "Keeping symlink: ${GREEN}${RELATIVE_SYMBOLIC_LINK}${RESET}"
    fi
done

printf '\n%s\n' "${BLUE}Checking for missing symbolic links...${RESET}"
# find all executable scripts in src and create symlinks in bin,
# removing all extensions, and replacing all dashes with underscores
find $SCRIPT_SRC -type f -perm -u+x | while IFS= read -r SRCNAME; do
    SCRIPT_FILENAME=$(basename "$SRCNAME")
    SYMBOLIC_LINK_NAME=${SCRIPT_FILENAME%.*}
    SYMBOLIC_LINK_NAME=${SYMBOLIC_LINK_NAME//-/_}
    SYMBOLIC_LINK="$BIN_DIR/$SYMBOLIC_LINK_NAME"
    
    SCRIPT_SRC_REL=$(realpath --relative-to="$BIN_DIR" "$SRCNAME")
    SYMBOLIC_LINK_REL=$(realpath --relative-to="$BIN_DIR" "$SYMBOLIC_LINK")
    
    if [ ! -L "$SYMBOLIC_LINK" ]; then
        printf '%s\n' "Creating symlink: ${YELLOW}${SYMBOLIC_LINK_REL}${RESET} -> ${BLUE}${SCRIPT_SRC_REL}${RESET}"
        ln -sf "$SRCNAME" "$SYMBOLIC_LINK"
    else
        printf '%s\n' "Skipping: ${GREEN}${SCRIPT_SRC_REL}${RESET} - Symlink already exists."
    fi
done

printf '\n%s\n' "${GREEN}Finished generating symlink farm.${RESET}"