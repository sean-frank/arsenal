#!/usr/bin/env bash
# ./src/security.sh
# Description: checks for a security.txt file for a domain

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

# Function to display help
function display_help() {
    echo "Usage: security [OPTIONS]... [URL or FILE]"
    echo "Read URLs from stdin, a file, or direct argument and print their status to stdout"
    echo "If no input or file is provided, security drops into a TTY for input value"
    echo " "
    echo "Options:"
    echo "  --help         display this help and exit"
    echo "  --json         format the output as a JSON object"
    echo "  --verbose,-v   print more detailed output"
    echo "  --version,-V   print the version of the script and exit"
    echo " "
    echo "Examples:"
    echo "  echo 'https://example.com' | security"
    echo "  security <(echo 'https://example.com')"
    echo "  security <<< 'https://example.com'"
    echo "  security"
    exit 0
}

function display_header() {
    printf '%s\n' "${RED}                     _ _       ${RESET}"
    printf '%s\n' "${RED} ___ ___ ___ _ _ ___|_| |_ _ _ ${RESET}"
    printf '%s\n' "${RED}|_ -| -_|  _| | |  _| |  _| | |${RESET}"
    printf '%s\n' "${RED}|___|___|___|___|_| |_|_| |_  |${RESET}"
    printf '%s\n' "${RED}                          |___|${RESET}"
    printf '%s\n' "${BLUE}         version: ${VERSION}${RESET}"
    printf '\n'
}

args=()
# iterate over
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --help)
        display_help
        exit 0
        ;;
    --full)
        FULL=true
        ;;
    --simple | --short)
        SHORT=true
        ;;
    --verbose | -v)
        VERBOSE=true
        ;;
    --version | -V)
        echo "security v${VERSION}"
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
if [ "$dupes" -gt 0 ]; then
    printf '%s\n\n' "${BG_YELLOW}${BOLD}Duplicate URL(s) found, ${dupes} removed.${RESET}"
fi

# Iterate over the array
for i in "${!args[@]}"; do
    domain="${args[$i]}"
    # check if domain is a url and extract the domain
    if [[ "$domain" =~ ^https?:// ]]; then
        domain=$(awk -F/ '{print $3}' <<<"$domain")
    fi

    url="https://$domain/.well-known/security.txt"

    # Check if the domain has a security.txt file
    if curl -s -IL "$url" | grep -qE "HTTP\/.+200"; then
        # Check if the user wants the full output
        if [ "$FULL" = true ]; then
            # Print the full output
            printf '%s\n' "${GREEN}✓${RESET} ${url} ${GREEN}has a security.txt file.${RESET}"
        else
            # Print the simple output
            printf '%s\n' "${GREEN}✓${RESET} ${url}"
        fi
    else
        # Check if the user wants the full output
        if [ "$FULL" = true ]; then
            # Print the full output
            printf '%s\n' "${RED}✗${RESET} ${url} ${RED}does not have a security.txt file.${RESET}"
        else
            # Print the simple output
            printf '%s\n' "${RED}✗${RESET} ${url}"
        fi
    fi

    # print spacing between urls
    if [ "$i" -lt "$((${#args[@]} - 1))" ]; then
        printf "\n"
    fi
done

exit 0
