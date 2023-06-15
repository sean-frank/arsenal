#!/bin/sh
#
# This script should be run via curl:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/xransum/arsenal/master/tools/install.sh)"
# or via wget:
#   sh -c "$(wget -qO- https://raw.githubusercontent.com/xransum/arsenal/master/tools/install.sh)"
# or via fetch:
#   sh -c "$(fetch -o - https://raw.githubusercontent.com/xransum/arsenal/master/tools/install.sh)"
#
# As an alternative, you can first download the install script and run it afterwards:
#   wget https://raw.githubusercontent.com/xransum/arsenal/master/tools/install.sh
#   sh install.sh
#
# You can tweak the install behavior by setting variables when running the script. For
# example, to change the path to the Arsenal repository:
#   ARSENAL_BASH=~/.zsh sh install.sh
#
# Respects the following environment variables:
#   ARSENAL_DOTDIR - path to Zsh dotfiles directory (default: unset). See [1][2]
#             [1] https://zsh.sourceforge.io/Doc/Release/Parameters.html#index-ARSENAL_DOTDIR
#             [2] https://zsh.sourceforge.io/Doc/Release/Files.html#index-ARSENAL_DOTDIR_002c-use-of
#   ARSENAL_BASH     - path to the Arsenal repository folder (default: $HOME/.arsenal)
#   REPO    - name of the GitHub repo to install from (default: xransum/arsenal)
#   REMOTE  - full remote URL of the git repo to install (default: GitHub via HTTPS)
#   BRANCH  - branch to check out immediately after install (default: master)
#
# Other options:
#   CHSH       - 'no' means the installer will not change the default shell (default: yes)
#   RUNBASH     - 'no' means the installer will not run zsh after the install (default: yes)
#   KEEP_BASHRC - 'yes' means the installer will not replace an existing .bashrc (default: no)
#
# You can also pass some arguments to the install script to set some these options:
#   --skip-chsh: has the same behavior as setting CHSH to 'no'
#   --unattended: sets both CHSH and RUNBASH to 'no'
#   --keep-bashrc: sets KEEP_BASHRC to 'yes'
# For example:
#   sh install.sh --unattended
# or:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/xransum/arsenal/master/tools/install.sh)" "" --unattended
#
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


# Track if $ARSENAL_BASH was provided
custom_bash=${ARSENAL_BASH:+yes}

# Use $ARSENAL_DOT to keep track of where the directory is for zsh dotfiles
# To check if $ARSENAL_DOTDIR was provided, explicitly check for $ARSENAL_DOTDIR
ARSENAL_DOT="${ARSENAL_DOTDIR:-$HOME}"

# Default value for $ARSENAL_BASH
# a) if $ARSENAL_DOTDIR is supplied and not $HOME: $ARSENAL_DOTDIR/arsenal
# b) otherwise, $HOME/.arsenal
[ "$ARSENAL_DOTDIR" = "$HOME" ] || ARSENAL_BASH="${ARSENAL_BASH:-${ARSENAL_DOTDIR:+$ARSENAL_DOTDIR/arsenal}}"
ARSENAL_BASH="${ARSENAL_BASH:-$HOME/.arsenal}"

# Default settings
REPO=${REPO:-xransum/arsenal}
REMOTE=${REMOTE:-https://github.com/${REPO}.git}
BRANCH=${BRANCH:-master}
RAW_REMOTE=${RAW_REMOTE:-https://raw.githubusercontent.com/${REPO}/${BRANCH}}

# Other options
CHSH=${CHSH:-yes}
RUNBASH=${RUNBASH:-yes}
KEEP_BASHRC=${KEEP_BASHRC:-no}
FORCE=${FORCE:-no}

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

user_can_sudo() {
  # Check if sudo is installed
  command_exists sudo || return 1
  # Termux can't run sudo, so we can detect it and exit the function early.
  case "$PREFIX" in
  *com.termux*) return 1 ;;
  esac
  # The following command has 3 parts:
  #
  # 1. Run `sudo` with `-v`. Does the following:
  #    • with privilege: asks for a password immediately.
  #    • without privilege: exits with error code 1 and prints the message:
  #      Sorry, user <username> may not run sudo on <hostname>
  #
  # 2. Pass `-n` to `sudo` to tell it to not ask for a password. If the
  #    password is not required, the command will finish with exit code 0.
  #    If one is required, sudo will exit with error code 1 and print the
  #    message:
  #    sudo: a password is required
  #
  # 3. Check for the words "may not run sudo" in the output to really tell
  #    whether the user has privileges or not. For that we have to make sure
  #    to run `sudo` in the default locale (with `LANG=`) so that the message
  #    stays consistent regardless of the user's locale.
  #
  ! LANG= sudo -n -v 2>&1 | grep -q "may not run sudo"
}

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

# shellcheck disable=SC2016 # backtick in single-quote
fmt_code() {
  is_tty && printf '`\033[2m%s\033[22m`\n' "$*" || printf '`%s`\n' "$*"
}

fmt_error() {
  printf '%sError: %s%s\n' "${BOLD}${RED}" "$*" "$RESET" >&2
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

setup_arsenal() {
  # Prevent the cloned repository from having insecure permissions. Failing to do
  # so causes compinit() calls to fail with "command not found: compdef" errors
  # for users with insecure umasks (e.g., "002", allowing group writability). Note
  # that this will be ignored under Cygwin by default, as Windows ACLs take
  # precedence over umasks except for filesystems mounted with option "noacl".
  umask g-w,o-w

  echo "${BLUE}Cloning Arsenal..${RESET}"

  command_exists git || {
    fmt_error "git is not installed"
    exit 1
  }

  ostype=$(uname)
  if [ -z "${ostype%CYGWIN*}" ] && git --version | grep -Eq 'msysgit|windows'; then
    fmt_error "Windows/MSYS Git is not supported on Cygwin"
    fmt_error "Make sure the Cygwin git package is installed and is first on the \$PATH"
    exit 1
  fi

  # Manual clone with git config options to support git < v1.7.2
  git init "$ARSENAL_BASH" \
    && cd "$ARSENAL_BASH" \
    && git config core.eol lf \
    && git config core.autocrlf false \
    && git config fsck.zeroPaddedFilemode ignore \
    && git config fetch.fsck.zeroPaddedFilemode ignore \
    && git config receive.fsck.zeroPaddedFilemode ignore \
    && git config arsenal.remote origin \
    && git config arsenal.branch "$BRANCH" \
    && git remote add origin "$REMOTE" \
    && git fetch --depth=1 origin \
    && git checkout -b "$BRANCH" "origin/$BRANCH" || {
      [ ! -d "$ARSENAL_BASH" ] || {
        cd -
        rm -rf "$ARSENAL_BASH" 2>/dev/null
      }
      fmt_error "git clone of arsenal repo failed"
      exit 1
  }
  # Exit installation directory
  cd -

  echo ""
}

setup_bashrc() {
  # Keep most recent old .bashrc at .bashrc.pre-arsenal, and older ones
  # with datestamp of installation that moved them aside, so we never actually
  # destroy a user's original bashrc
  echo "${BLUE}Looking for an existing bash config...${RESET}"

  # Must use this exact name so uninstall.sh can find it
  OLD_BASHRC="$ARSENAL_DOT/.bashrc.pre-arsenal"
  if [ -f "$ARSENAL_DOT/.bashrc" ] || [ -h "$ARSENAL_DOT/.bashrc" ]; then
    # Skip this if the user doesn't want to replace an existing .bashrc
    if [ "$KEEP_BASHRC" = yes ]; then
      echo "${YELLOW}Found ${ARSENAL_DOT}/.bashrc.${RESET} ${GREEN}Keeping...${RESET}"
      return
    fi
    
    if [ -e "$OLD_BASHRC" ]; then
      OLD_OLD_BASHRC="${OLD_BASHRC}-$(date +%Y-%m-%d_%H-%M-%S)"
      if [ -e "$OLD_OLD_BASHRC" ]; then
        fmt_error "$OLD_OLD_BASHRC exists. Can't back up ${OLD_BASHRC}"
        fmt_error "re-run the installer again in a couple of seconds"
        exit 1
      fi
      
      mv "$OLD_BASHRC" "${OLD_OLD_BASHRC}"

      echo "${YELLOW}Found old .bashrc.pre-arsenal." \
        "${GREEN}Backing up to ${OLD_OLD_BASHRC}${RESET}"
    fi
    
    echo "${YELLOW}Found ${ARSENAL_DOT}/.bashrc.${RESET} ${GREEN}Backing up to ${OLD_BASHRC}${RESET}"
    cp "$ARSENAL_DOT/.bashrc" "$OLD_BASHRC"
  fi
  
  # if .bashrc doesn't exist, use skeleton config or create an empty one
  if [ ! -f "$ARSENAL_DOT/.bashrc" ]; then
    # copy default skeleton config to users home, otherwise
    # we just create a blank one
    if [ -f "/etc/skel/.bashrc" ]; then
      cp -f "/etc/skel/.bashrc" "$ARSENAL_DOT/.bashrc"
    else
      touch "$ARSENAL_DOT/.bashrc"
    fi
  fi
  
  # check for .bash_profile since if it exists, it's necessary to source
  # .bashrc
  if [ -f "$ARSENAL_DOT/.bash_profile" ]; then
    echo "${BLUE}Checking if your $(fmt_code ".bash_profile") config sources your $(fmt_code ".bash") config...${RESET}"
    
    # crudely check if .bashrc is sourced from the .bashrc_profile, thus
    # adding it when it doesn't
    if ! grep -q -E "(source|\.) +($HOME|\$HOME|~)/.bashrc" "$ARSENAL_DOT/.bash_profile"; then
      echo "${YELLOW}Updated your $(fmt_code ".bash_profile") config to source your $(fmt_code ".bash") config.${RESET}"
      echo "[ -f ~/.bashrc ] && . ~/.bashrc" >> "$ARSENAL_DOT/.bash_profile"
    fi
  fi
  
  # check to see if the arsenal
  if ! grep -q -E "PATH=.*$ARSENAL_BASH/bin" "$ARSENAL_DOT/.bashrc"; then
     echo "${YELLOW}Added Arsenal scripts to PATH in your $(fmt_code ".bash") config.${RESET}"
     echo "export PATH=\"\$PATH:$ARSENAL_BASH/bin\"" >> "$ARSENAL_DOT/.bashrc"
  fi
  
  echo ""
}

setup_dependencies() {
  DEPENDENCIES_URL="$RAW_REMOTE/deps/linux.txt"
  DEPENDENCIES=$(curl -fsSL "$DEPENDENCIES_URL" | sed 's/#.*//' | tr '\n' ' ')
  
  printf '%s\n' "Installing dependencies... This may take a few minutes."
  
  if [ -z "$DEPENDENCIES" ]; then
    fmt_error "Failed to fetch dependencies list from $DEPENDENCIES_URL"
    exit 1
  fi
  
  if ! (command_exists apt-get || command_exists yum); then
    fmt_error "Sorry, Arsenal only supports Debian and Red Hat-based systems at this time."
    exit 1
  fi
  
  if command_exists apt-get; then
    if user_can_sudo; then
      sudo apt-get update -y 2>&1 >/dev/null
      sudo apt-get install -y $DEPENDENCIES 2>&1 >/dev/null
    else
      apt-get update -y 2>&1 >/dev/null
      apt-get install -y $DEPENDENCIES 2>&1 >/dev/null
    fi
  elif command_exists yum; then
    if user_can_sudo; then
      sudo yum install -y $DEPENDENCIES 2>&1 >/dev/null
    else
      yum install -y $DEPENDENCIES 2>&1 >/dev/null
    fi
  fi
  
  if [ $? -ne 0 ]; then
    if user_can_sudo; then
      fmt_error "Failed to install dependencies. Please install them manually."
      
      for dep in $DEPENDENCIES; do
        printf "  %s\n" "- $dep"
      done
    else
      fmt_error "Failed to install dependencies. Please run this script as root."
    fi
  fi
}

print_header() {
  printf '%s                                    __%s\n' $RED $RESET
  printf '%s  ____ ______________  ____  ____ _/ /%s\n' $RED $RESET
  printf '%s / __ `/ ___/ ___/ _ \/ __ \/ __ `/ / %s\n' $RED $RESET
  printf '%s/ /_/ / /  (__  )  __/ / / / /_/ / /  %s\n' $RED $RESET
  printf '%s\__,_/_/  /____/\___/_/ /_/\__,_/_/   %s\n' $RED $RESET
}

# shellcheck disable=SC2183  # printf string has more %s than arguments ($RAINBOW expands to multiple arguments)
print_success() {
  print_header
  printf '%s      ...is now installed!            %s\n' $GREEN $RESET
  printf '\n'
  printf '\n'
  printf '%s %s %s\n' \
    "Before you go all ${BOLD}${YELLOW}Hacking the Gibson${RESET} with your new tools," \
    "we recommend you look over your $(fmt_code "$(fmt_link ".bashrc" "file://$zdot/.bashrc" --text)") " \
    "file to ensure your options haven't been broken."
  printf '\n'
  printf '%s\n' "• Check out the Arsenal Wiki: $(fmt_link @arsenal https://github.com/xransum/arsenal/wiki)"
  printf '\n'
  printf '%s\n' "Get started by using the command:"
  printf '%s\n' "  ${BOLD}$(fmt_code arsenal --help)${RESET}"
  printf '\n'
  printf '%s %s\n' "Happy scripting!" "${BOLD}${GREEN}Hack the Plant${RESET}!"
  printf '%s\n' $RESET
}

main() {
  # Run as unattended if stdin is not a tty
  if [ ! -t 0 ]; then
    RUNBASH=no
    CHSH=no
  fi

  # Parse arguments
  while [ $# -gt 0 ]; do
    case $1 in
      --unattended) RUNBASH=no; CHSH=no ;;
      --skip-chsh) CHSH=no ;;
      --keep-bashrc) KEEP_BASHRC=yes ;;
      --force) FORCE=yes ;;
    esac
    shift
  done

  setup_colors
  
  if [ -d "$ARSENAL_BASH" ]; then
    echo "${YELLOW}The \$ARSENAL_BASH folder already exists ($ARSENAL_BASH).${RESET}"
    
    if [ "$FORCE" = yes ]; then
      # Remove previous versions of Arsenal
      printf '%s\n' "Removing previous version of Arsenal..."
      rm -rf "$ARSENAL_BASH" 2>/dev/null

    else
      if [ "$custom_bash" = yes ]; then
          cat <<EOF

You ran the installer with the \$ARSENAL_BASH setting or the \$ARSENAL_BASH variable is
exported. You have 3 options:

1. Unset the ARSENAL_BASH variable when calling the installer:
   $(fmt_code "ARSENAL_BASH= sh install.sh")
2. Install Arsenal to a directory that doesn't exist yet:
   $(fmt_code "ARSENAL_BASH=path/to/new/arsenal/folder sh install.sh")
3. (Caution) If the folder doesn't contain important information,
   you can just remove it with $(fmt_code "rm -r $ARSENAL_BASH")

EOF
        else
          echo ""
          echo "${BOLD}${YELLOW}Uh-oh!${RESET} ${BOLD}It looks like you already have Arsenal installed!${RESET}"
          echo ""
          echo "This can be fixed with either of the following options:"
          echo "1. Run the installer with the ${YELLOW}$(fmt_code "--force")${RESET}:"
          echo ""
          echo "2. Remove the previous version of Arsenal manually:"
          echo "  ${YELLOW}$(fmt_code "rm -rf $ARSENAL_BASH")${RESET}"
          echo ""
        fi
        exit 1
    fi
  fi

  # Create ARSENAL_DOTDIR folder structure if it doesn't exist
  if [ -n "$ARSENAL_DOTDIR" ]; then
    mkdir -p "$ARSENAL_DOTDIR"
  fi

  setup_dependencies
  setup_arsenal
  setup_bashrc

  print_success

  if [ $RUNBASH = no ]; then
    echo "${YELLOW}Run bash to try it out.${RESET}"
    exit
  fi

  exec bash -l
}

main "$@"