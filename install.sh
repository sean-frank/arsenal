#!/usr/bin/env bash
#
# This script should be run via curl:
#   bash <(curl -fsSL https://raw.githubusercontent.com/xransum/arsenal/master/tools/install.sh)
# or via wget:
#   bash <(wget -qO- https://raw.githubusercontent.com/xransum/arsenal/master/tools/install.sh)
# or via fetch:
#   bash <(fetch -o - https://raw.githubusercontent.com/xransum/arsenal/master/tools/install.sh)
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
#   bash install.sh --unattended
# or:
#   bash <(curl -fsSL https://raw.githubusercontent.com/xransum/arsenal/master/tools/install.sh) --unattended
#
set -e

# Global arguments
CHSH=${CHSH:-yes}
RUNBASH=${RUNBASH:-yes}
KEEP_BASHRC=${KEEP_BASHRC:-no}
FORCE=${FORCE:-no}
SKIP_OMZ=${SKIP_OMZ:-no}
NO_DEPS=${NO_DEPS:-no}
BRANCH=${BRANCH:-master}

help() {
    cat <<EOF
Usage: $(basename "$0") [arguments]
Arguments:
  --skip-chsh       Skip changing the shell to zsh
  --unattended      Skip changing the shell and running zsh after install
  --keep-bashrc     Keep the existing .bashrc file
  --no-deps         Skip installing dependencies
  --force           Skip the prompt and install Arsenal
  --branch          Install a specific branch (default: master)
  --help            Show this help message
EOF
}

# parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
    --skip-chsh)
        CHSH=no
        ;;
    --unattended)
        CHSH=no
        RUNBASH=no
        ;;
    --keep-bashrc)
        KEEP_BASHRC=yes
        ;;
    --no-deps)
        NO_DEPS=yes
        ;;
    --force)
        FORCE=yes
        ;;
    --branch)
        BRANCH=$2
        shift
        ;;
    --help)
        help
        exit 0
        ;;
    *)
        echo "Invalid argument: $1"
        exit 1
        ;;
    esac
    shift
done

command_exists() {
    command -v "$@" >/dev/null 2>&1
}

# A function for universally setting RUNNING_USER to the user
# even if running with sudo or sudo su $SUDO_USER is not set
# in sudo su. This is a hack to work around for any Linux
# operating systems
running_user() {
    if command_exists logname; then
        logname
    elif [ -n "${SUDO_USER:-}" ]; then
        echo "$SUDO_USER"
    elif [ -n "${USER:-}" ]; then
        echo "$USER"
    elif [ -n "${USERNAME:-}" ]; then
        echo "$USERNAME"
    else
        whoami
    fi
}

# Make sure important variables exist if not already defined
#
# $USER is defined by login(1) which is not always executed (e.g. containers)
# POSIX: https://pubs.opengroup.org/onlinepubs/009695299/utilities/id.html
# USER=${USER:-$(id -u -n)}
USER="$(running_user)"
# $HOME is defined at the time of login, but it could be unset. If it is unset,
# a tilde by itself (~) will not be expanded to the current user's home directory.
# POSIX: https://pubs.opengroup.org/onlinepubs/009696899/basedefs/xbd_chap08.html#tag_08_03
HOME="${HOME:-$(getent passwd "$USER" 2>/dev/null | cut -d: -f6)}"
# macOS does not have getent, but this works even if $HOME is unset
HOME="${HOME:-$(eval echo ~"$USER")}"

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
    ! LANG=$(sudo -n -v 2>&1 | grep -q "may not run sudo")
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
        [ "$VTE_VERSION" -ge 5000 ]
        return $?
    fi

    # If $TERM_PROGRAM is set, these terminals support hyperlinks
    case "$TERM_PROGRAM" in
    Hyper | iTerm.app | terminology | WezTerm) return 0 ;;
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
    truecolor | 24bit) return 0 ;;
    esac

    case "$TERM" in
    iterm | \
        tmux-truecolor | \
        linux-truecolor | \
        xterm-truecolor | \
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
    --url | *) fmt_underline "$2" ;;
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

# A function for checking if the user can run sudo or not
can_root() {
    # Check if sudo is installed
    command_exists sudo || return 1
    # Termux can't run sudo, so we can detect it and exit the function early.
    case "$PREFIX" in *com.termux*)
        return 1
        ;;
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
    ! LANG=$(sudo -n -v 2>&1 | grep -q "may not run sudo")
}

# A function for checking if the user is root or not
am_root() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# A function for universally setting RUNNING_USER to the user
# even if running with sudo or sudo su $SUDO_USER is not set
# in sudo su. This is a hack to work around for any Linux
# operating systems
running_user() {
    if command_exists logname; then
        echo "$(logname)"
    elif [ -n "${SUDO_USER:-}" ]; then
        echo "$SUDO_USER"
    elif [ -n "${USER:-}" ]; then
        echo "$USER"
    elif [ -n "${USERNAME:-}" ]; then
        echo "$USERNAME"
    else
        echo "$(whoami)"
    fi
}

users_default_shell() {
    basename $(awk -F: -v user="$USER" '$1 == user {print $NF}' /etc/passwd)
}

# Grab running users default shell
running_shell() {
    if command_exists getent; then
        getent passwd "$(running_user)" | cut -d: -f7
    else
        grep "^$(running_user):" /etc/passwd | cut -d: -f7
    fi
}

install_dependencies() {
    # Skip setup if the user wants or stdin is closed (not running interactively).
    if [ "$NO_DEPS" = yes ]; then
        printf '%s\n' "Skipping dependencies installation."
        return
    fi

    printf '%s\n' "Installing dependencies... This may take a few minutes."
    DEPENDENCIES_URL="$RAW_REMOTE/deps/linux.txt"
    DEPENDENCIES=$(curl -fsSL "$DEPENDENCIES_URL" | sed 's/#.*//' | tr '\n' ' ' | tr -s ' ')

    if [ -z "$DEPENDENCIES" ]; then
        fmt_error "Failed to fetch dependencies list from $DEPENDENCIES_URL"
        exit 1
    fi

    if ! (command_exists apt-get || command_exists yum); then
        fmt_error "Sorry, Arsenal only supports Debian and Red Hat-based systems at this time."
        exit 1
    fi

    printf '%s\n' "Download package information from all package sources..."
    # Debian
    if command_exists apt-get; then
        if $sudo apt-get update -y 2>&1 >/dev/null; then
            echo "Package information updated successfully."
        else
            echo "Package information update failed."
        fi
    # CentOS
    elif command_exists yum; then
        if $sudo yum update -y 2>&1 >/dev/null; then
            echo "Package information updated successfully."
        else
            echo "Package information update failed."
        fi

        if $sudo yum upgrade -y 2>&1 >/dev/null; then
            echo "Package information upgraded successfully."
        else
            echo "Package information upgrade failed."
        fi
    else
        fmt_error "Sorry, Arsenal only supports Debian and Red Hat-based systems at this time."
        exit 1
    fi

    printf '%s\n' "Installing packages dependencies..."
    for dep in $DEPENDENCIES; do
        echo -n "Installing $dep... "

        # Debian
        if command_exists apt-get; then
            if $sudo apt-get install -y "$dep" 2>&1 >/dev/null; then
                echo "Done."
            else
                echo "Failed."
            fi
        # CentOS
        elif command_exists yum; then
            # For CentOS 7, we need to install git from a different repo,
            # but only if it's git and git version is 1.x
            if [ "$dep" = "git" ] && [ "$(cat /etc/os-release | grep -oP '(?<=VERSION_ID=")\d+' | head -n 1)" = "7" ] && [ "$(git --version | grep -oP '(?<=git version )\d+' | head -n 1)" = "1" ]; then
                # This is entirely a me problem and the fact that I natively use CentOS 7
                # and git 1.x is the default. I'm not going to bother with CentOS 8
                $sudo yum remove git -y 2>&1 >/dev/null
                $sudo rpm -U http://opensource.wandisco.com/centos/7/git/x86_64/wandisco-git-release-7-2.noarch.rpm
                $sudo yum install git -y 2>&1 >/dev/null
                echo "Done."
            else
                if ! $sudo yum install -y "$dep" 2>&1 | grep -q "Error: Nothing to do" >/dev/null; then
                    echo "Done."
                else
                    echo "Failed."
                fi
            fi
        fi
    done

    if [ $? -ne 0 ]; then
        fmt_error "Failed to install dependencies. Please install them manually."
        exit 1
    fi

    echo
}

# Function for setting a users shell to a specific shell
change_users_shell() {
    # Skip setup if the user wants or stdin is closed (not running interactively).
    if [ "$CHSH" = no ]; then
        return
    fi

    # If this user's login shell is already "zsh", do not attempt to switch.
    SHELL=$(users_default_shell)
    if [ "$SHELL" = "zsh" ]; then
        return
    fi

    # If this platform doesn't provide a "chsh" command, bail out.
    if ! command_exists chsh; then
        printf '%s\n%s%s%s\n' "I can't change your shell automatically because this system does not have chsh." \
            "$FMT_BLUE" "Please manually change your default shell to zsh" "$FMT_RESET"

        return
    fi

    echo "${FMT_BLUE}Time to change your default shell to zsh:${FMT_RESET}"

    # Prompt for user choice on changing the default login shell
    # printf '%sDo you want to change your default shell to zsh? [Y/n]%s ' \
    #     "$FMT_YELLOW" "$FMT_RESET"

    # read -r opt
    # case $opt in
    # y* | Y* | "") ;;
    # n* | N*)
    #     echo "Shell change skipped."
    #     return
    #     ;;
    # *)
    #     echo "Invalid choice. Shell change skipped."
    #     return
    #     ;;
    # esac

    # Check if we're running on Termux
    case "$PREFIX" in
    *com.termux*)
        termux=true
        zsh=zsh
        ;;
    *) termux=false ;;
    esac

    if [ "$termux" != true ]; then
        # Test for the right location of the "shells" file
        if [ -f /etc/shells ]; then
            shells_file=/etc/shells
        elif [ -f /usr/share/defaults/etc/shells ]; then # Solus OS
            shells_file=/usr/share/defaults/etc/shells
        else
            fmt_error "could not find /etc/shells file. Change your default shell manually."
            return
        fi

        # Get the path to the right zsh binary
        # 1. Use the most preceding one based on $PATH, then check that it's in the shells file
        # 2. If that fails, get a zsh path from the shells file, then check it actually exists
        if ! zsh=$(command -v zsh) || ! grep -qx "$zsh" "$shells_file"; then
            if ! zsh=$(grep '^/.*/zsh$' "$shells_file" | tail -n 1) || [ ! -f "$zsh" ]; then
                fmt_error "no zsh binary found or not present in '$shells_file'"
                fmt_error "change your default shell manually."
                return
            fi
        fi
    fi

    # We're going to change the default shell, so back up the current one
    if [ -n "$SHELL" ]; then
        echo "$SHELL" >"$ARSENAL_DOT/.shell.pre-arsenal"
    else
        grep "^$USER:" /etc/passwd | awk -F: '{print $7}' >"$ARSENAL_DOT/.shell.pre-arsenal"
    fi

    echo "Changing your shell to $zsh..."

    # Check if user has sudo privileges to run `chsh` with or without `sudo`
    #
    # This allows the call to succeed without password on systems where the
    # user does not have a password but does have sudo privileges, like in
    # Google Cloud Shell.
    #
    # On systems that don't have a user with passwordless sudo, the user will
    # be prompted for the password either way, so this shouldn't cause any issues.
    #
    if user_can_sudo; then
        sudo -k chsh -s "$zsh" "$USER" # -k forces the password prompt
    else
        chsh -s "$zsh" "$USER" # run chsh normally
    fi

    # Check if the shell change was successful
    if [ $? -ne 0 ]; then
        fmt_error "chsh command unsuccessful. Change your default shell manually."
    else
        export SHELL="$zsh"
        echo "${FMT_GREEN}Shell successfully changed to '$zsh'.${FMT_RESET}"
    fi

    echo
}

# Update the users dot file to source Arsenal scripts
setup_dot_rc() {
    # Skip setup if the user wants or stdin is closed (not running interactively).
    if [ "$RUNBASH" = no ]; then
        return
    fi

    # Determine the dot file based on the user's default shell
    case "$SHELL" in
    bash) dot_file="$ARSENAL_DOT/.bashrc" ;;
    zsh) dot_file="$ARSENAL_DOT/.zshrc" ;;
    *) dot_file="" ;;
    esac

    if [ -z "$dot_file" ]; then
        echo "Unsupported shell. Skipping dot file setup. $dot_file"
        return
    fi

    # Backup the user's original dot file
    backup_dot_file "$dot_file"

    # Check if the dot file is sourced from .bash_profile or .profile
    if [[ "$dot_file" == *".bashrc" ]]; then
        local primary_rc_file

        # Look for .bash_profile or .profile
        for rc_file in "$ARSENAL_DOT/.bash_profile" "$ARSENAL_DOT/.profile"; do
            if [ -f "$rc_file" ]; then
                primary_rc_file="$rc_file"
                break
            fi
        done

        if [ -n "$primary_rc_file" ]; then
            echo "${BLUE}Checking if ${primary_rc_file} sources ${dot_file}...${RESET}"

            # Check if the dot file is sourced from the primary RC file
            if ! grep -q -E "(source|\.) +($HOME|\$HOME|~)/$(basename "$dot_file")" "$primary_rc_file"; then
                echo "${YELLOW}Updated ${primary_rc_file} to source ${dot_file}.${RESET}"
                echo "[[ -f $dot_file ]] && . $dot_file" >>"$primary_rc_file"
            fi
        fi
    fi

    echo
}

# Backup the user's original dot file
backup_dot_file() {
    # Skip backup if the user wants or stdin is closed (not running interactively).
    if [ "$RUNBASH" = no ]; then
        return
    fi

    # Get specific file from args
    dot_file="$1"

    echo "${BLUE}Looking for an existing shell config file (${dot_file})...${RESET}"
    # Backup the user's original dot file
    backup_dot_file="${dot_file}.pre-arsenal"
    if [ -f "$dot_file" ] || [ -h "$dot_file" ]; then
        if [ "$KEEP_DOT_FILE" = yes ]; then
            echo "${YELLOW}Found ${dot_file}.${RESET} ${GREEN}Keeping...${RESET}"
            return
        fi

        if [ -e "$backup_dot_file" ]; then
            old_backup_dot_file="${backup_dot_file}-$(date +%Y-%m-%d_%H-%M-%S)"
            if [ -e "$old_backup_dot_file" ]; then
                fmt_error "$old_backup_dot_file exists. Can't back up ${backup_dot_file}"
                fmt_error "Re-run the installer again in a few seconds."
                exit 1
            fi

            mv "$backup_dot_file" "$old_backup_dot_file"

            echo "${YELLOW}Found old ${dot_file}.pre-arsenal." \
                "${GREEN}Backing up to ${old_backup_dot_file}${RESET}"
        fi

        echo "${YELLOW}Found ${dot_file}.${RESET} ${GREEN}Backing up to ${backup_dot_file}${RESET}"
        cp "$dot_file" "$backup_dot_file"
    fi
}

install_oh_my_zsh() {
    # Install oh-my-zsh base
    printf '%s\n' "Installing oh-my-zsh..."

    # Check for NO_OMZ flag
    if [ "$SKIP_OMZ" = yes ]; then
        return
    # Check for --force flag
    elif [ "$FORCE" = yes ]; then
        rm -rf "$HOME/.oh-my-zsh"
    fi

    if [ -d "$HOME/.oh-my-zsh" ]; then
        git -C "$HOME/.oh-my-zsh" pull
    else
        git clone https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
    fi

    setup_dot_rc

    echo
    printf '%s\n' "Copying zsh rc config from templates..."
    # Install oh-my-zsh configs
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"

    echo
    # Install oh-my-zsh plugins
    printf '%s\n' "Installing oh-my-zsh plugins..."
    set -- "https://github.com/marlonrichert/zsh-autocomplete" \
        "https://github.com/zsh-users/zsh-autosuggestions" \
        "https://github.com/zsh-users/zsh-completions"
    #"https://github.com/romkatv/powerlevel10k"
    #"https://github.com/z-shell/F-Sy-H"
    #"https://github.com/djui/alias-tips"
    #"https://github.com/unixorn/git-extra-commands"
    #"https://github.com/Aloxaf/fzf-tab"
    #"https://github.com/hlissner/zsh-autopair"
    #"https://github.com/MichaelAquilina/zsh-auto-notify"

    for plugin in "$@"; do
        echo "Plugin $plugin is installing..."
        plugin_repo=$(basename "$plugin")

        if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/$plugin_repo" ]; then
            git clone "$plugin" "$HOME/.oh-my-zsh/custom/plugins/$plugin_repo"
        else
            git -C "$HOME/.oh-my-zsh/custom/plugins/$plugin_repo" pull
        fi
    done

    echo
    echo "Setting configs, please wait..."
    echo "Setting theme to mh..."
    # Set theme to mh, it's the least obstructive and doesn't require
    # 3rd party fonts to view non-ascii chars.
    sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="mh"/' "$HOME/.zshrc"
    if ! grep -qE 'ZSH_THEME=".*"' "$HOME/.zshrc"; then
        echo 'ZSH_THEME="mh"' >>"$HOME/.zshrc"
    else
        sed -i "s/^zstyle ':omz:update' mode disabled/# zstyle ':omz:update' mode disabled/g" "$HOME/.zshrc"
    fi

    printf '%s\n' "Enabling default plugins, to enable more plugins, please edit ~/.zshrc manually."
    # Set default enabled plugins
    if ! grep -qE "plugins=\(.*\)" "$HOME/.zshrc"; then
        echo 'plugins=(git zsh-autosuggestions zsh-completions zsh-autocomplete)' >>"$HOME/.zshrc"
    else
        sed -i "s/^plugins=\(.*\)$/plugins=(git zsh-autosuggestions zsh-completions zsh-autocomplete)/g" "$HOME/.zshrc"
    fi

    # Enforce updates
    printf '%s\n' "Enforcing updates..."
    if grep -qE "^zstyle ':omz:update' mode disabled" "$HOME/.zshrc"; then
        sed -i "s/^zstyle ':omz:update' mode disabled/# zstyle ':omz:update' mode disabled/g" "$HOME/.zshrc"
    fi

    # Disable reminders
    printf '%s\n' "Disabling reminders..."
    if grep -qE "^zstyle ':omz:update' mode reminder" "$HOME/.zshrc"; then
        sed -i "s/^zstyle ':omz:update' mode reminder/# zstyle ':omz:update' mode reminder/g" "$HOME/.zshrc"
    fi

    # Set auto-updates
    printf '%s\n' "Setting auto-updates..."
    if ! grep -qE "zstyle ':omz:update' mode auto" "$HOME/.zshrc"; then
        echo "zstyle ':omz:update' mode auto" >>"$HOME/.zshrc"
    else
        sed -i "s/^# zstyle ':omz:update' mode auto/zstyle ':omz:update' mode auto/g" "$HOME/.zshrc"
    fi

    # Enable standard frequency, default: 13 days
    printf '%s\n' "Setting update frequency..."
    if ! grep -qE "zstyle ':omz:update' frequency" "$HOME/.zshrc"; then
        echo "zstyle ':omz:update' frequency 13" >>"$HOME/.zshrc"
    elif grep -qE "^# zstyle ':omz:update' frequency" "$HOME/.zshrc"; then
        sed -i "s/^# zstyle ':omz:update' frequency/zstyle ':omz:update' frequency/g" "$HOME/.zshrc"
    fi

    echo
}

install_arsenal() {
    # Prevent the cloned repository from having insecure permissions. Failing to do
    # so causes compinit() calls to fail with "command not found: compdef" errors
    # for users with insecure umasks (e.g., "002", allowing group writability). Note
    # that this will be ignored under Cygwin by default, as Windows ACLs take
    # precedence over umasks except for filesystems mounted with option "noacl".
    umask g-w,o-w

    echo "${BLUE}Installing Arsenal..${RESET}"

    # Check if git is installed
    command_exists git || {
        fmt_error "git is not installed"
        exit 1
    }

    # The Windows (MSYS) Git is not compatible with normal use on cygwin
    ostype=$(uname)
    if [ -z "${ostype%CYGWIN*}" ] && git --version | grep -Eq 'msysgit|windows'; then
        fmt_error "Windows/MSYS Git is not supported on Cygwin"
        fmt_error "Make sure the Cygwin git package is installed and is first on the \$PATH"
        exit 1
    fi

    # Check for --force
    if [ "$FORCE" = yes ]; then
        echo "Arsenal forced install, nuking previous version..."
        rm -rf "$ARSENAL_BASH"
    fi

    CURRENT_DIR=$(pwd)

    # Check if "$ARSENAL_BASH" is already cloned
    if [ ! -d "$ARSENAL_BASH" ]; then
        echo "No $ARSENAL_BASH, initializing local repository..."
        git init "$ARSENAL_BASH" &&
            cd "$ARSENAL_BASH" &&
            git config core.eol lf &&
            git config core.autocrlf false &&
            git config fsck.zeroPaddedFilemode ignore &&
            git config fetch.fsck.zeroPaddedFilemode ignore &&
            git config receive.fsck.zeroPaddedFilemode ignore &&
            git config arsenal.remote origin &&
            git config arsenal.branch "$BRANCH"
    fi

    # Check if current dir is $CURRENT_DIR
    if [ "$CURRENT_DIR" != "$ARSENAL_BASH" ]; then
        cd "$ARSENAL_BASH"
    fi

    # Check if the "origin" remote already exists
    if ! git remote | grep -q "origin"; then
        echo "Configuring remote origin to $REMOTE"
        git remote add origin "$REMOTE"
    fi

    echo "Pulling latest changes from remote"
    git fetch --depth=1 origin

    if git rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
        echo "Checking out to remote branch '$BRANCH'"
        git checkout -b "$BRANCH" "origin/$BRANCH" || {
            [ ! -d "$ARSENAL_BASH" ] || {
                echo "Installation failed, clearing all installs"
                cd "$CURRENT_DIR"
                rm -rf "$ARSENAL_BASH" 2>/dev/null
            }
            fmt_error "git clone of arsenal repo failed"
            exit 1
        }
    else
        fmt_error "The branch '$BRANCH' does not exist in the remote repository."
        exit 1
    fi

    cd "$CURRENT_DIR"

    # Create a directory to store the arsenal scripts
    if [ ! -d "$ARSENAL_BASH/bin" ]; then
        mkdir -p "$ARSENAL_BASH/bin"
    fi

    echo "Generating symlink farm from Arsenal sources, '$ARSENAL_BASH/src'..."
    # Go through each of the scripts within $ARSENAL_BASH/src, taking each of them
    # checking which have valid shebangs, and then symlinking them to $ARSENAL_BASH/bin
    # with the script name without the extension. This allows us to update the scripts
    # without having to update the symlinks.
    for script in "$ARSENAL_BASH/src"/*; do
        script_name=$(basename "$script")
        script_name="${script_name%.*}"
        script_path="$ARSENAL_BASH/bin/$script_name"

        # Check if the script has a valid shebang
        if [ -f "$script" ] && head -n 1 "$script" | grep -qE "^#\!/.+?$"; then
            # Make the script executable if it's not
            if [ ! -x "$script" ]; then
                chmod +x "$script"
            else
                echo "Script '$script' is already executable, skipping..."
            fi

            # If the script doesn't exist, create it
            if [ ! -f "$script_path" ]; then
                echo "Adding to symlink farm: $script_name"
                ln -s "$script" "$script_path"
            else
                echo "There was a possible script collision, symlink exists already for '$script' to '$script_name'."
            fi
        else
            echo "Script '$script' does not contain a valid shebang, skipping..."
        fi
    done

    echo "Validating symlinks from symlink farm for any discrepancies..."
    # Locate all symlinks from $ARSENAL_BASH/bin and remove those that don't have
    # a corresponding script that is a valid executable file in $ARSENAL_BASH/src
    for symlink in "$ARSENAL_BASH/bin"/*; do
        symlink_name=$(basename "$symlink")
        symlink_name="${symlink_name%.*}"
        symlink_path="$ARSENAL_BASH/bin/$symlink_name"

        # Check if the symlink is a symlink and if it's not a valid executable file
        if [ -L "$symlink" ] && [ ! -f "$symlink_path" ] && [ ! -x "$symlink_path" ]; then
            echo "Removing from symlink farm: $symlink_name"
            rm "$symlink"
        fi
    done

    # Append the Arsenal script path to the dot file if not already present
    if ! grep -q -E "PATH=.*$ARSENAL_BASH/bin" "$dot_file"; then
        echo "${YELLOW}Added Arsenal scripts to PATH in ${dot_file}${RESET}"
        echo "export PATH=\"\$PATH:$ARSENAL_BASH/bin\"" >>"$dot_file"
    fi

    # Exit installation directory
    cd "$CURRENT_DIR"
    echo
}

TOYBOX_REPO='drampil/toy-box'
TOYBOX_BRANCH="main"
TOYBOX_RAW_REMOTE="https://raw.githubusercontent.com/${TOYBOX_REPO}/${TOYBOX_BRANCH}"
install_toybox_scripts() {
    echo "Installing toy-box scripts..."

    ARSENAL_TOYBOX="$ARSENAL_BASH/toybox"
    if [ ! -d "$ARSENAL_TOYBOX" ]; then
        mkdir -p "$ARSENAL_TOYBOX"
    fi

    # Current curated toy-box scripts
    set -- "$TOYBOX_RAW_REMOTE/megac" \
        "$TOYBOX_RAW_REMOTE/javelin" \
        "$TOYBOX_RAW_REMOTE/ghost" \
        "$TOYBOX_RAW_REMOTE/warpath" \
        "$TOYBOX_RAW_REMOTE/aris" \
        "$TOYBOX_RAW_REMOTE/tracer" \
        "$TOYBOX_RAW_REMOTE/imgur" \
        "$TOYBOX_RAW_REMOTE/tess" \
        "$TOYBOX_RAW_REMOTE/hostc"

    # Download toy-box scripts and place them in $ARSENAL_BASH/toybox,
    # take scriptname without extension and symlink to $ARSENAL_BASH/bin,
    # updating only if the script has changed.
    for script_url in "$@"; do
        script_name=$(basename "$script_url")
        script_name="${script_name%.*}"
        script_path="$ARSENAL_TOYBOX/$script_name"

        # Download the script if it doesn't exist, otherwise update it
        if [ ! -f "$script_path" ]; then
            curl -fsSL "$script_url" -o "$script_path"
        else
            # create a tempt file
            tmp_file=$(mktemp -q)
            curl -fsSL "$script_url" -o "$tmp_file"

            if ! cmp -s "$script_path" "$tmp_file"; then
                echo "Script $script_name has changed, updating..."
                mv "$tmp_file" "$script_path"
            else
                echo "Script $script_name has not changed, skipping..."
                rm "$tmp_file"
            fi
        fi

        chmod +x "$script_path"

        if [ ! -f "$ARSENAL_BASH/bin/$script_name" ]; then
            echo "Adding to symlink farm: $script_name"
            ln -s "$script_path" "$ARSENAL_BASH/bin/$script_name"
        fi
    done

    echo
}

# Unified way of setting sudo to a variable
if am_root; then
    sudo=""
elif can_root; then
    sudo="sudo"
else
    sudo=""
fi

print_header() {
    printf "%s                                    __%s\n" "$RED" "$RESET"
    printf "%s  ____ ______________  ____  ____ _/ /%s\n" "$RED" "$RESET"
    printf "%s / __  / ___/ ___/ _ \/ __ \/ __/ / / %s\n" "$RED" "$RESET"
    printf "%s/ /_/ / /  (__  )  __/ / / / /_/ / /  %s\n" "$RED" "$RESET"
    printf "%s\__,_/_/  /____/\___/_/ /_/\__,_/_/   %s\n" "$RED" "$RESET"
}

# shellcheck disable=SC2183  # printf string has more %s than arguments ($RAINBOW expands to multiple arguments)
print_success() {
    print_header
    printf '%s      ...is now installed!            %s\n' "$GREEN" "$RESET"
    printf '\n'
    printf '\n'
    printf '%s %s %s\n' \
        "Before you go all ${BOLD}${YELLOW}Hacking the Gibson${RESET} with your new tools," \
        "we recommend you look over your $(fmt_code "$(fmt_link "$dot_file" "file://$dot_file" --text)") " \
        "file to ensure your options haven't been broken."
    printf '\n'
    printf '%s\n' "• Check out the Arsenal Wiki: $(fmt_link @arsenal https://github.com/xransum/arsenal/wiki)"
    printf '\n'
    printf '%s\n' "Get started by using the command:"
    printf '%s\n' "  ${BOLD}$(fmt_code arsenal --help)${RESET}"
    printf '\n'
    printf '%s %s\n' "Happy scripting!" "${BOLD}${GREEN}Hack the Plant${RESET}!"
    printf '%s\n' "$RESET"
}

main() {
    # Run as unattended if stdin is not a tty
    if [ ! -t 0 ]; then
        RUNBASH=no
        CHSH=no
    fi
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

    setup_colors
    install_dependencies
    change_users_shell
    install_oh_my_zsh
    install_arsenal
    install_toybox_scripts

    print_success

    if [ "$RUNBASH" = no ]; then
        echo "${YELLOW}Run bash to try it out.${RESET}"
        exit
    fi

    exec bash -l
}

main "$@"
exit 0
