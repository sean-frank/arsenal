#!/usr/bin/env bash
# ipcheck.sh
# takes url(s), checks the page status, outputs status info, and follows
# meta redirects to check the final status of the page

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

# Initialize term colorization
setup_colors

# Set default values for options
VERSION="1.0.0"
VERBOSE=false
FULL=false
SHORT=false
JSON=false

# Function to display help
function display_help() {
    echo "Usage: ipcheck [OPTIONS]... [URL or FILE]"
    echo " "

    echo "Read URLs from stdin, a file, or direct argument and print their status to stdout"
    echo "If no input or file is provided, ipcheck drops into a TTY for input value"
    echo " "
    echo "Options:"
    echo "  --help         display this help and exit"
    echo "  --json         format the output as a JSON object"
    echo "  --verbose,-v   print more detailed output"
    echo "  --version,-V   print the version of the script and exit"
    echo " "
    echo "Examples:"
    echo "  echo '212.22.45.32' | ipcheck"
    echo "  ipcheck <(echo '212.22.45.32')"
    echo "  ipcheck <<< '212.22.45.32'"
    echo "  ipcheck"
    exit 0
}

function display_header() {
    printf '%s\n' "${RED}  _         _           _   ${RESET}"
    printf '%s\n' "${RED} (_)_ __ __| |_  ___ __| |__${RESET}"
    printf '%s\n' "${RED} | | '_ / _| ' \/ -_/ _| / /${RESET}"
    printf '%s\n' "${RED} |_| .__\__|_||_\___\__|_\_\\${RESET}"
    printf '%s\n' "${RED}   |_|                      ${RESET}"
    printf '%s\n' "${BLUE}         version: ${VERSION}${RESET}"
    printf '\n'
}

args=()
# iterate over
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --help)
        display_help
        ;;
    --json)
        JSON=true
        ;;
    --verbose | -v)
        VERBOSE=true
        ;;
    --version | -V)
        echo "ipcheck v${VERSION}"
        exit 0
        ;;
    -*)
        echo "Unknown option: $1"
        exit 1
        ;;
    *)
        args+=("$1")
        ;;
    esac
    shift
done

# Reset positional parameters
set -- "${args[@]}"

# Checking if input is from a pipe, file or terminal
if [[ -p /dev/stdin ]]; then
    while IFS= read -r line; do
        args+=("$line")
    done
elif [[ -n "$1" ]]; then
    # Checking if input is a file, file descriptor, or symlink
    if [[ -f "$1" || -L "$1" || -c "$1" || -b "$1" ]]; then
        # It's a file
        while IFS= read -r line; do
            args+=("$line")
        done <"$1"
    else
        # Assume it's a URL
        args=("$@")
    fi
else
    # Wait for 0.1 second to see if any input is coming, if not drop into a TTY.
    if read -t 0.1 line; then
        args+=("$line")
        while IFS= read -r line; do
            args+=("$line")
        done
    else
        display_header
        printf '%s\n' "${BOLD}[Interactive Mode]${RESET}"
        printf '%s\n' "${YELLOW}Enter an IP address to check, or press CTRL+D to finish.${RESET}"
        while IFS= read -r line; do
            args+=("$line")
        done
    fi
fi

# Remove dupes and empty lines from the array
dupes=0
for i in "${!args[@]}"; do
    if [ -z "${args[$i]}" ]; then
        unset 'args[$i]'
    else
        for j in "${!args[@]}"; do
            if [ "$i" -ne "$j" ] && [ "${args[$i]}" = "${args[$j]}" ]; then
                unset 'args[$j]'
                dupes=$((dupes + 1))
            fi
        done
    fi
done

# Print the number of dupes removed
if [ "$dupes" -gt 0 ] && [ "$VERBOSE" = true ] && [ "$JSON" = false ]; then
    printf '%s\n\n' "${BG_YELLOW}${BOLD}Duplicate IP address(es) found, ${dupes} removed.${RESET}"
fi

# check if for valid ipv4 and ipv6 addresses
valid_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\. ]]; then
        IFS='.'
        ip=($ip)
        [[ "${ip[0]}" -le 255 && "${ip[1]}" -le 255 ]]
        stat=$?
    elif [[ "$ip" =~ ^[0-9a-fA-F]{1,4}\:[0-9a-fA-F]{1,4}\: ]]; then
        IFS=':'
        ip=($ip)
        [[ "${ip[0]}" -le 65535 && "${ip[1]}" -le 65535 ]]
        stat=$?
    fi
    return $stat
}

data=""
if [ "$JSON" = true ]; then
    data='['
fi

# Iterate over the array
for i in "${!args[@]}"; do
    ipaddr="${args[$i]}"

    # Check if the IP address is valid
    if ! valid_ip "$ipaddr"; then
        if [ "$JSON" = true ]; then
            data="$data{\"ip\": \"$ipaddr\", \"error\": \"Invalid IP address\"}"
        else
            error "Invalid IP address: $ipaddr"
        fi
        continue
    fi

    output=$(curl -skL "https://ipinfo.io/$ipaddr/json")
    ret=$? # capture return code
    if [ $ret -ne 0 ]; then
        if [[ "$output" == *"not found"* ]]; then
            if [ "$JSON" = true ]; then
                data="$data{\"ip\": \"$ipaddr\", \"error\": \"No records found\"}"
            else
                echo "No records found."
            fi
        elif [[ "$output" == *"timed out"* ]]; then
            if [ "$JSON" = true ]; then
                data="$data{\"ip\": \"$ipaddr\", \"error\": \"DNS lookup timed out\"}"
            else
                echo "DNS lookup timed out."
            fi
        else
            if [ "$JSON" = true ]; then
                data="$data{\"ip\": \"$ipaddr\", \"error\": \"Unknown error\"}"
            else
                echo "Unknown error."
                echo "$output"
            fi
        fi
        continue
    fi

    if [ "$JSON" = true ]; then
        data="$data$output"
    else
        echo "> $ipaddr"
        echo "  Hostname     : $(jq -r '.hostname' <<<"$output")"
        echo "  City         : $(jq -r '.city' <<<"$output")"
        echo "  Region       : $(jq -r '.region' <<<"$output")"
        echo "  Country      : $(jq -r '.country' <<<"$output")"
        echo "  Timezone     : $(jq -r '.timezone' <<<"$output")"
        echo "  Organization : $(jq -r '.org' <<<"$output")"
        echo "  Postal       : $(jq -r '.postal' <<<"$output")"
        echo "  Location     : $(jq -r '.loc' <<<"$output")"
    fi

    # print spacing between urls
    if [ "$i" -lt "$((${#args[@]} - 1))" ]; then
        if [ "$JSON" = true ]; then
            data="$data,"
        else
            printf "\n"
        fi
    fi
done

if [ "$JSON" = true ]; then
    data="$data]"
    echo "$data" | jq .
fi

exit 0
