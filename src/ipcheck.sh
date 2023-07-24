#!/usr/bin/env bash
# ./src/ipcheck.sh
# Description: get info about an ip addr

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SELF_DIR="$(dirname "$SELF")"

import() {
    # get the directory of the current script
    for path in "$@"; do
        filepath="$(readlink -f "$SELF_DIR/$path")"

        # source the file, if it exists
        if [ -f "$filepath" ]; then
            . "$filepath"
            continue
        else
            echo "File not found: $path"
            exit 1
        fi
    done
}

# dependencies
import version.sh
import commons.sh

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
