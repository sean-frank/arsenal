#!/usr/bin/env bash

set -e

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

link() {
    # $1: text, $2: url, $3: fallback mode
    if supports_hyperlinks; then
        printf '\033]8;;%s\033\\%s\033]8;;\033\\\n' "$2" "$1"
        return
    fi

    case "$3" in
    --text) printf '%s\n' "$1" ;;
    --url | *) underline "$2" ;;
    esac
}

underline() {
    is_tty && printf '\033[4m%s\033[24m\n' "$*" || printf '%s\n' "$*"
}

# shellcheck disable=SC2016 # backtick in single-quote
code() {
    is_tty && printf '`\033[2m%s\033[22m`\n' "$*" || printf '`%s`\n' "$*"
}

error() {
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

# Initialize term colorization
setup_colors

help() {
    cat <<EOF
Usage: $(basename "$0") [arguments]
Arguments:
  --force           Skip confirmation prompt
  --help            Show this help message
EOF
}

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
    printf '%s      ...is now uninstalled!%s\n' "$GREEN" "$RESET"
    printf '\n\n%s\n\n%s\n%s\n\n%s\n\n%s\n' \
        "${BOLD}${YELLOW}Thanks for using Arsenal!${RESET} We're sad to see you go... :(" \
        "If you have any feedback, please let us know by opening an issue on GitHub." \
        "• Check out the Arsenal issues: $(link @arsenal https://github.com/xransum/arsenal/issues)" \
        "${YELLOW}Don't forget to restart your terminal!${RESET}" \
        "${BOLD}${GREEN}Hack the Plant${RESET}!"
}

# Check command exists easily
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

# Check whether running user can escalate using sudo
can_root() {
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

# Check if user is currently running as root
am_root() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Grab running users default shell
default_shell() {
    if command_exists getent; then
        getent passwd "$(running_user)" | cut -d: -f7
    else
        grep "^$(running_user):" /etc/passwd | cut -d: -f7
    fi
}

# Function for setting a users shell to a specific shell
set_default_shell() {
    # Skip setup if the user wants or stdin is closed (not running interactively).
    if [ "$CHSH" = no ]; then
        return
    fi

    target_shell="$1"
    # If this user's login shell is already the target shell, do not attempt to switch.
    if [ "$(default_shell)" = "$target_shell" ]; then
        return
    fi

    # If this platform doesn't provide a "chsh" command, bail out.
    if ! command_exists chsh; then
        printf '%s\n%s%s%s\n' "I can't change your shell automatically because this system does not have chsh." \
            "$BLUE" "Please manually change your default shell to $target_shell" "$RESET"
        return
    fi

    echo "${BLUE}Time to change your default shell to $target_shell:${RESET}"

    # Check if we're running on Termux
    case "$PREFIX" in
    *com.termux*)
        termux=true
        shell_path="$target_shell"
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
            error "could not find /etc/shells file. Change your default shell manually."
            return
        fi

        # Get the path to the right target shell binary
        # 1. Use the most preceding one based on $PATH, then check that it's in the shells file
        # 2. If that fails, get a target shell path from the shells file, then check it actually exists
        if ! shell_path=$(command -v "$target_shell") || ! grep -qx "$shell_path" "$shells_file"; then
            if ! shell_path=$(grep "^/.*/$target_shell$" "$shells_file" | tail -n 1) || [ ! -f "$shell_path" ]; then
                error "no $target_shell binary found or not present in '$shells_file'"
                error "change your default shell manually."
                return
            fi
        fi
    fi

    echo "${BLUE}Checking if your shell is already $target_shell...${RESET}"

    # check if the shell is already set or default is already set
    if [ "$(default_shell)" != "$shell_path" ]; then
        echo "${YELLOW}Shell not set to '$target_shell'.${RESET}"
        # Check if the current user is root or the target user, so we don't need sudo
        if [ "$(id -u)" -eq 0 ]; then
            chsh -s "$shell_path" "$USER" # run chsh normally
        else
            # Check if user has sudo privileges to run `chsh` with or without `sudo`
            #
            # This allows the call to succeed without a password on systems where the
            # user does not have a password but does have sudo privileges, like in
            # Google Cloud Shell.
            #
            # On systems that don't have a user with passwordless sudo, the user will
            # be prompted for the password either way, so this shouldn't cause any issues.
            #
            if can_root; then
                sudo -k chsh -s "$shell_path" "$USER" # -k forces the password prompt
            else
                error "you don't have permission to change the shell. Change your default shell manually."
                return 1
            fi
        fi
    else
        echo "${GREEN}Shell already set to '$target_shell'.${RESET}"
    fi

    # Check if the shell change was successful
    if [ $? -ne 0 ]; then
        error "chsh command unsuccessful. Change your default shell manually."
    else
        export SHELL="$shell_path"
        echo "${GREEN}Shell successfully changed to '$target_shell'.${RESET}"
    fi

    echo
}

# Function to revert the user's shell to the previous shell
revert_users_shell() {
    # Skip setup if the user wants or stdin is closed (not running interactively).
    if [ "$CHSH" = no ]; then
        return
    fi

    # Check if the .shell.pre-arsenal file exists and contains the backup shell path
    if [ -f "$ARSENAL_DOT/.shell.pre-arsenal" ]; then
        prev_shell=$(cat "$ARSENAL_DOT/.shell.pre-arsenal")

        # Check if the previous shell path exists and is in the shells file
        shells_file="/etc/shells" # Update this path if needed
        if [ -f "$prev_shell" ] && grep -qx "$prev_shell" "$shells_file"; then
            echo "Reverting your shell to $prev_shell..."

            # Use the set_default_shell() function to set the previous shell
            set_default_shell "$(basename "$prev_shell")"
        else
            error "previous shell '$prev_shell' is not valid or not present in '$shells_file'"
            error "change your default shell manually."
        fi
    else
        error "could not find the .shell.pre-arsenal file. Shell reversion skipped."
    fi
}

# Function to restore the original dot file
restore_dot_file() {
    # Get specific file from args
    dot_file="$1"

    current_dotfile_backup=~/.${dot_file}.uninstalled-$(date +%Y-%m-%d_%H-%M-%S)
    if [ -f "$dot_file" ] && [ ! -f "$current_dotfile_backup" ]; then
        echo "Before we restore your original ${dot_file}, we're going to save your current dot file to ${current_dotfile_backup}"
        echo "You can restore it manually if you want to, it's not deleted."
        echo

        echo "Restoring the original ${dot_file}..."
        # Restore the original dot file if it was backed up
        mv "$current_dotfile_backup" "$dot_file"
        echo "Original ${dot_file} has been restored."
    fi

    backup_dot_file="${dot_file}.pre-arsenal"
    if [ -f "$backup_dot_file" ]; then
        # Save the dot file to a backup file, just in case
        current_dotfile_backup=~/.${dot_file}.uninstalled-$(date +%Y-%m-%d_%H-%M-%S)
        echo "Restoring the original ${dot_file}..."
        mv "$backup_dot_file" "$dot_file"
        echo "Original ${dot_file} has been restored."
    fi
}

# Function to uninstall dot file changes
uninstall_dot_rc() {
    # Determine the dot file based on the user's default shell
    case "$SHELL" in
    bash) dot_file="$ARSENAL_DOT/.bashrc" ;;
    zsh) dot_file="$ARSENAL_DOT/.zshrc" ;;
    *) dot_file="" ;;
    esac

    if [ -z "$dot_file" ]; then
        echo "Unsupported shell. Skipping dot file uninstall. $dot_file"
        return
    fi

    # Restore the original dot file if it was backed up
    restore_dot_file "$dot_file"

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

            # Remove the sourcing line from the primary RC file
            sed -i "/[[ -f $dot_file ]] && . $dot_file/d" "$primary_rc_file"
        fi
    fi

    echo "Dot file changes have been uninstalled."
}

# Function to prompt for confirmation before proceeding
confirm() {
    prompt="$1"
    echo -n "$prompt [y/N]: "

    while true; do
        read -r user_res

        # If the user presses Enter without giving any
        # response, consider it as 'No'
        if [ -z "$user_res" ]; then
            return 1
        fi

        # Convert the user response to lowercase for
        # case-insensitive comparison
        user_res_lc=$(echo "$user_res" | tr '[:upper:]' '[:lower:]')

        case "$user_res_lc" in
        y | yes)
            return 0
            ;;
        n | no)
            return 1
            ;;
        *)
            echo "Invalid response. Please enter 'y' or 'n': "
            ;;
        esac
    done
}

# Function to print a countdown message and run a countdown timer
last_chance_timer() {
    local countdown=$1

    # Print the countdown message
    echo
    echo "This is your last chance to cancel."

    # Run the countdown in the background
    for ((i = countdown; i > 0; i--)); do
        echo -ne "\rPress 'Ctrl+C' to cancel in the next $i secs..."
        #echo -ne "\rUninstaller starting in $i secs..."
        sleep 1
    done

    # Print a new line after the countdown is done
    echo ""
}

# Global arguments
FORCE=${FORCE:-no}

# parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
    -f | --force)
        FORCE=yes
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
CUSTOM_BASH=${ARSENAL_BASH:+yes}

# Use $ARSENAL_DOT to keep track of where the directory is for zsh dotfiles
# To check if $ARSENAL_DOTDIR was provided, explicitly check for $ARSENAL_DOTDIR
ARSENAL_DOT="${ARSENAL_DOTDIR:-$HOME}"

# Default value for $ARSENAL_BASH
# a) if $ARSENAL_DOTDIR is supplied and not $HOME: $ARSENAL_DOTDIR/arsenal
# b) otherwise, $HOME/.arsenal
[ "$ARSENAL_DOTDIR" = "$HOME" ] || ARSENAL_BASH="${ARSENAL_BASH:-${ARSENAL_DOTDIR:+$ARSENAL_DOTDIR/arsenal}}"
ARSENAL_BASH="${ARSENAL_BASH:-$HOME/.arsenal}"

# Unified way of setting sudo to a variable
unset sudo
if am_root; then
    sudo=""
elif can_root; then
    sudo="sudo"
fi

main() {
    # Prompt confirmation before running the Arsenal uninstaller
    if [ "$FORCE" = no ]; then
        confirm "Are you sure you want to run the Arsenal uninstaller?" || exit
        last_chance_timer 5
    fi

    echo "${BLUE}Running the Arsenal uninstaller...${RESET}"

    if [ -d "$ARSENAL_BASH" ]; then
        echo "Removing Arsenal..."
        rm -rf "$ARSENAL_BASH"
    else
        echo "Arsenal is not installed. Nothing to do."
    fi

    # Confirm if user also wants us to remove oh-my-zsh
    if [ -d "$HOME/.oh-my-zsh" ]; then
        if [ "$FORCE" = no ]; then
            confirm "Do you also want to remove oh-my-zsh?" || exit
        fi

        rm -rf "$HOME/.oh-my-zsh"
    else
        echo "oh-my-zsh is not installed. Nothing to do."
    fi

    echo "${BLUE}Reverting dot file changes...${RESET}"
    uninstall_dot_rc

    echo "${BLUE}Reverting the users shell to the original shell...${RESET}"
    revert_users_shell

    echo "${BLUE}Removing Arsenal from the PATH...${RESET}"
    # Remove Arsenal from the PATH
    if [ -f "$HOME/.bashrc" ]; then
        sed -i '/# Added by Arsenal/d' "$HOME/.bashrc"
        sed -i "s/export PATH=.*\/.arsenal\/bin.*$//g" "$HOME/.bashrc"
    fi

    print_success

    # Bounce into a fresh shell for the users prefered default
    # shell
    if [ -n "$CUSTOM_BASH" ]; then
        echo "Restarting into your default shell..."
        exec "$SHELL"
    fi

    echo
    echo "${GREEN}Uninstallation complete!${RESET}"
    exec "$(default_shell)" -l
}

main "$@"
exit 0
