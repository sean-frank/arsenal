# Common functions and variables used by other scripts

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

warn() {
    printf '%sWarning: %s%s\n' "${BOLD}${YELLOW}" "$*" "$RESET" >&2
}

error() {
    printf '%sError: %s%s\n' "${BOLD}${RED}" "$*" "$RESET" >&2
}

debug() {
    if [ "$VERBOSE" = true ]; then
        printf '%s%s%s\n' "${BOLD}${YELLOW}[${__name__}]: " "$*" "$RESET" >&2
    fi
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
        BG_RED=""
        BG_GREEN=""
        BG_YELLOW=""
        BG_BLUE=""
        BG_RESET=""
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
    BG_RED=$(printf '\033[41m')
    BG_GREEN=$(printf '\033[42m')
    BG_YELLOW=$(printf '\033[43m')
    BG_BLUE=$(printf '\033[44m')
    BG_RESET=$(printf '\033[49m')
}

COLORS=("$RED" "$GREEN" "$YELLOW" "$BLUE")
rng_color() {
    local color=${COLORS[$RANDOM % ${#COLORS[@]}]}
    printf '%s' "${!color}"
}

# Initialize term colorization
setup_colors

# Check command exists easily
command_exists() {
    command -v "$@" >/dev/null 2>&1
}

# Function to display a loading bar until the process is finished
display_loading_bar() {
    local pid=$1
    local duration=$2
    local message=$3
    local chars='/-\|'
    while kill -0 "$pid" >/dev/null 2>&1; do
        for ((i = 0; i <= $duration; i++)); do
            cc="${COLORS[$RANDOM % ${#COLORS[@]}]}"
            sleep 0.1
            echo -ne "${message} [${cc}${chars:$((i % ${#chars})):1}${RESET}] \\r"
        done
    done
    echo
}

# A function for universally setting RUNNING_USER to the user
# even if running with sudo or sudo su $SUDO_USER is not set
# in sudo su. This is a hack to work around for any Linux
# operating systems
running_user() {
    # Check if the script is running in WSL
    if grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
        # If running in WSL, use whoami to get the current user
        whoami
    elif command_exists logname; then
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

defang() {
    echo "$@" | sed 's/ //g' |
        sed 's/h[tx]\{2\}p/http/gi;' |
        sed 's/\[\+\.\]\+/./g' |
        sed 's/\[\+:\/\/\]\+/:\/\//g' |
        sed 's/\((@|at)\)/@/gi;' |
        sed 's/\[(@|at)\]/@/gi;'
}

fang() {
    echo "$@" | sed 's/http/hxxp/gi;' |
        sed 's/\/\//\/\/+/g' |
        sed 's/\./[+\.]/g'
}
