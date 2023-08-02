#!/usr/bin/env bash
# ./src/sniper.sh
# Description: check url status, follow redirects (including meta tags), and print the results

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
    echo "Usage: sniper [OPTIONS]... [URL or FILE]"
    echo "Read URLs from stdin, a file, or direct argument and print their status to stdout"
    echo "If no input or file is provided, sniper drops into a TTY for input value"
    echo " "
    echo "Options:"
    echo "  --help         display this help and exit"
    echo "  --json         format the output as a JSON object"
    echo "  --verbose,-v   print more detailed output"
    echo "  --version,-V   print the version of the script and exit"
    echo " "
    echo "Examples:"
    echo "  echo 'https://example.com' | sniper"
    echo "  sniper <(echo 'https://example.com')"
    echo "  sniper <<< 'https://example.com'"
    echo "  sniper"
    exit 0
}

function display_header() {
    printf '%s\n' "${RED}         _             ${RESET}"
    printf '%s\n' "${RED} ___ ___|_|___ ___ ___ ${RESET}"
    printf '%s\n' "${RED}|_ -|   | | . | -_|  _|${RESET}"
    printf '%s\n' "${RED}|___|_|_|_|  _|___|_|  ${RESET}"
    printf '%s\n' "${RED}          |_|          ${RESET}"
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
        echo "sniper v${VERSION}"
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

build_url() {
    prev_url="$1"
    next_url="$2"

    # https://example.com/aabc
    # ://example.com/aabc
    # /aabc
    # aabc
    if [[ "$next_url" != http* ]]; then
        debug "relative redirect detected, appending to url"
        next_url=$(sed -E "s/\/[^\/]*$/\/${next_url}/" <<<"$prev_url")

        # when empty leave empty
        if [[ -z "$next_url" ]]; then
            debug "empty url detected, leaving empty"
        # incomplete schema
        elif [[ "$next_url" =~ ^:// ]]; then
            debug "url missing scheme, defaulting to https"
            next_url="https${next_url}"
        # url hash
        elif [[ "$next_url" =~ ^# ]]; then
            debug "url hash detected, appending to url"
            next_url="${prev_url}${next_url}"
        # new root path on same domain
        elif [[ "$next_url" =~ ^/ ]]; then
            debug "new page, appending to url"
            # split the url by the first slash and append the next url
            next_url=$(sed -E "s/\/[^\/]*$/\/${next_url}/" <<<"$prev_url")
        # query string
        elif [[ "$next_url" =~ ^\? ]]; then
            debug "query string detected, appending to url"
            next_url="${prev_url}${next_url}"
        else
            debug "unknown redirect, leaving empty"
            next_url=''
        fi
    fi
}

# Initializing variables
url=""
redirected=false
max_redirects=10
user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36'
header_filters='^(Location|x-amz-apigw-id|CloudFront|x-amz-cf-id|AmazonS3).*:|Content-(Length|Type)'

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
    url="${args[$i]}"

    redirects=0

    # Handle URL redirects and status codes
    while [ -n "$url" ]; do
        unset exit_code results result next_url

        domain=$(awk -F/ '{print $3}' <<<"$url")
        depth=$((redirects + 1))

        # print the URL pretty
        leading="> (${depth})"
        if [ "$depth" -gt 1 ]; then
            leading=">${leading}"
        fi

        trailing=""
        if [ "$redirected" = false ]; then
            datetime=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
            trailing=" at ${YELLOW}${datetime}${RESET}"
        fi

        printf '%s\n' "${leading} ${BOLD}${url}${RESET}${trailing}"

        response=$(curl --insecure --fail --show-error --no-progress-meter \
            --connect-timeout 30 --max-time 120 \
            -H 'Cache-Control: no-cache' \
            --user-agent "$user_agent" --dump-header - --no-keepalive \
            "$url" 2>/dev/null)

        exit_code=$?
        # When exit code is not 0, handle the error
        if [ $exit_code -ne 0 ]; then
            if [ $exit_code -eq 3 ]; then
                printf '   %s\n' "${RED}Error: Malformed URL${RESET} - ${domain}"
            elif [ $exit_code -eq 6 ]; then
                printf '   %s\n' "${RED}Error: Could not resolve host${RESET} - ${domain}"
            elif [ $exit_code -eq 7 ]; then
                printf '   %s\n' "${RED}Error: Failed to connect to host${RESET} - ${domain}"
            elif [ $exit_code -eq 28 ]; then
                printf '   %s\n' "${RED}Error: Connection timed out${RESET} - ${domain}"
            else
                printf '   %s\n' "${RED}Error: Unknown error ($exit_code)${RESET} - ${domain}"
                echo "$response"
            fi
            break
        fi

        head=true
        headers=""
        body=""
        while IFS= read -r line; do
            if $head; then
                if [[ -z $line ]]; then
                    head=false
                else
                    headers="$headers"$'\n'"$line"
                fi
            else
                body="$body"$'\n'"$line"
            fi
        done < <(sed 's/\r$//' <<<"$response")

        http_status=$(grep -E '^HTTP\/.*$' <<<"$headers")
        location=$(grep -E '^Location: ' <<<"$headers" | cut -d ":" -f 2- | sed -E 's/^[[:space:]]+//g')
        headers=$(sed -E '/^(HTTP\/|Location: )/d' <<<"$headers")

        http_version=$(cut -d " " -f 1 <<<"$http_status")
        status_code=$(cut -d " " -f 2 <<<"$http_status")
        status_reason=$(cut -d " " -f 3- <<<"$http_status")

        headers_filtered=$(grep -iE "$header_filters" <<<"$headers")
        if [ $FULL = true ]; then
            headers_filtered="$headers"
        fi

        # print the status code
        # right pad the status code with spaces
        # HTTP/2: 200 HTTP/2: 200

        printf '   %s: ' "${BOLD}${http_version}${RESET}"
        if [ "$status_code" -ge 100 ] && [ "$status_code" -lt 200 ]; then
            printf '%s' "${BLUE}${status_code}${RESET}"
        elif [ "$status_code" -ge 200 ] && [ "$status_code" -lt 300 ]; then
            printf '%s' "${GREEN}${status_code}${RESET}"
        elif [ "$status_code" -ge 300 ] && [ "$status_code" -lt 400 ]; then
            printf '%s' "${YELLOW}${status_code}${RESET}"
        elif [ "$status_code" -ge 400 ] && [ "$status_code" -lt 500 ]; then
            printf '%s' "${RED}${status_code}${RESET}"
        elif [ "$status_code" -ge 500 ] && [ "$status_code" -lt 600 ]; then
            printf '%s' "${RED}${status_code}${RESET}"
        else
            printf '%s' "${RED}${status_code}${RESET}"
        fi

        # print the status reason
        if [ -n "$status_reason" ]; then
            printf ' - %s\n' "${status_reason}"
        else
            printf '\n'
        fi

        # print the filtered headers
        if [ -n "$headers_filtered" ] && [ "$SHORT" = false ]; then
            while IFS= read -r line; do
                # split the line by the first colon
                header_name=$(cut -d ":" -f 1 <<<"$line" | sed -E 's/(^| |-)([a-z])/\U\2/g')
                header_value=$(cut -d ":" -f 2- <<<"$line" | sed -E 's/^[[:space:]]+//g')
                echo "   ${header_name}: ${BLUE}${header_value}${RESET}"
            done <<<"$headers_filtered"
        fi

        # extract the next url from the "Location:" header
        next_url="$location"

        # next_url is not empty
        if [ -n "$next_url" ]; then
            #next_url=$(build_url "$url" "$next_url")
            build_url "$url" "$next_url"
        else
            # if the next url is empty and the response code is 100-399, then we need to
            # check the body for the next url, which will require a new safe request for the body
            if [[ "$status_code" =~ ^[1-3][0-9][0-9]$ ]]; then
                debug "next url is empty, checking body for next url"

                # get only the meta tag in question
                meta_refresh=$(grep -Ei '<meta.+http-equiv="refresh".+>' <<<"${body[@]}")
                if [ -n "$meta_refresh" ]; then
                    meta_url=$(sed -E 's/.*url=(.*)".*/\1/g' <<<"$meta_refresh")
                    debug "meta refresh found, setting next url to: $meta_url"
                    next_url="$meta_url"
                    #next_url=$(build_url "$url" "$next_url")
                    build_url "$url" "$next_url"
                fi

                # clear meta refresh from memory
                unset meta_refresh
            fi
        fi

        # check if we've been redirected
        if [ -n "$next_url" ]; then
            redirected=true
            #echo "  ${GREEN}Redirected to: ${next_url}${RESET}"
        fi

        # set url to next url
        url="$next_url"

        # increment max redirects
        redirects=$((redirects + 1))

        # check if we've exceeded the max redirects
        if [ "$redirected" = true ] && [ "$redirects" -eq "$max_redirects" ]; then
            error "   Max redirects exceeded"
            exit 1
        fi
    done

    # print spacing between urls
    if [ "$i" -lt "$((${#args[@]} - 1))" ]; then
        printf "\n"
    fi
done

exit 0
