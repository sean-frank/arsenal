#!/usr/bin/env bash
SELF="$0"

import() {
    # get the directory of the current script
    DIR="$(dirname "$SELF")"
    for path in "$@"; do
        filepath="$(readlink -f "$DIR/$path")"

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
import utils/commons.sh

setup_colors

# global variables
__name__="curls"
__description__="check content status for a url, safely."
__version__="${__name__} (${__repo_name__} utils) ${__version__}"
__help__="""Usage: ${__name__} [URL]...

${__description__}

SELinux options:
  -v, --verbose            print verbose output
       --description       print description and exit
       --help              display this help and exit
       --version           output version information and exit

Exit status:
 0  if OK,
 1  if minor problems (e.g., cannot access url),
 2  if serious trouble (e.g., invalid command-line argument).

${__version__}"""

# parse args
help() {
    printf '%s\n' "$__help__"
    exit 0
}
version() {
    printf '%s\n' "$__version__"
    exit 0
}
description() {
    printf '%s\n' "$__description__"
    exit 0
}
verbose() {
    if [ "$verbosity" = 'default' ]; then
        printf '%s\n' "${YELLOW}[${__name__}]: $*${RESET}"
    fi
}

# default values
verbosity='default'

while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help) help ;;
    -v | --verbose) verbosity='verbose' ;;
    --version) version ;;
    --description) description ;;
    --)
        shift
        break
        ;;
    -*)
        echo "invalid option: $1" 1>&2
        exit 2
        ;;
    *) break ;;
    esac
    shift
done
if [ $# -eq 0 ]; then
    printf '%s\n' "try '${__name__} --help' for more information"
    exit 2
fi

# set args to an array
args=("$@")

ret=0 # exit code
header_filters='^HTTP|(Location|x-amz-apigw-id|CloudFront|x-amz-cf-id|AmazonS3).*:|Could not resolve host|Content-(Length|Type)'
user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36'

# $ curls 'https[://]le[.]com/'
# > https://le.com/
#   HTTP/1.1 301 Moved Permanently
#   Content-Type: text/html
#   Content-Length: 178
#   Location: http://www.le.com/
#
# >> http://www.le.com/
#   HTTP/1.1 302 Moved Temporarily
#   Content-Type: text/html
#   Content-Length: 218
#   Location: https://www.le.com/
#
# >> http://www.le.com/
#   HTTP/1.1 200 OK
#   Content-Type: text/html; charset=utf-8
#   Content-Length: 202743

# main
main() {
    for i in "${!args[@]}"; do
        unclean="${args[$i]}"
        url="$(defang "$unclean")"

        # urls without a scheme should default to https, incase the url passed is
        # a domain
        if [[ ! "$url" =~ ^https?:// ]]; then
            verbose "url missing scheme, defaulting to https"
            url="https://${url}"
        elif [[ "$url" =~ ^:// ]]; then
            verbose "url missing scheme, defaulting to https"
            url="https${url}"
        fi

        verbose "checking url: $url"
        echo "> ${url}"

        result=$(curl --insecure \
            --silent \
            --fail \
            --show-error \
            --location \
            --no-progress-meter \
            --connect-timeout 30 \
            --max-time 120 \
            --max-redirs 10 \
            --user-agent "$user_agent" \
            --dump-header - \
            --no-keepalive \
            -o /dev/null \
            "${url}" | egrep -iE "$header_filters")

        # title case headers
        result=$(echo "$result" | sed -E 's/(^|:|-)([a-z])/\1\u\2/g')

        # determine the redirects by the location header,
        # then adding
        if [ $? -eq 0 ]; then
            echo "${result}"
        else
            echo "${RED}Error: ${unclean} is unreachable.${RESET}"
        fi

        # print spacing between urls
        if [[ "$i" -lt "$((${#args[@]} - 1))" ]]; then
            echo ""
        fi
    done
}

#main "$@"

build_url() {
    prev_url="$1"
    next_url="$2"

    # https://example.com/aabc
    # ://example.com/aabc
    # /aabc
    # aabc
    if [[ "$next_url" != http* ]]; then
        verbose "relative redirect detected, appending to url"
        next_url=$(echo "$url" | sed -E "s/\/[^\/]*$/\/${next_url}/")

        # when empty leave empty
        if [[ -z "$next_url" ]]; then
            verbose "empty url detected, leaving empty"
        # incomplete schema
        elif [[ "$next_url" =~ ^:// ]]; then
            verbose "url missing scheme, defaulting to https"
            next_url="https${next_url}"
        # url hash
        elif [[ "$next_url" =~ ^# ]]; then
            verbose "url hash detected, appending to url"
            next_url="${url}${next_url}"
        # new root path on same domain
        elif [[ "$next_url" =~ ^/ ]]; then
            verbose "new page, appending to url"
            # split the url by the first slash and append the next url
            next_url=$(echo "$url" | sed -E "s/\/[^\/]*$/\/${next_url}/")
        # query string
        elif [[ "$next_url" =~ ^\? ]]; then
            verbose "query string detected, appending to url"
            next_url="${url}${next_url}"
        else
            verbose "unknown redirect, leaving empty"
            next_url=''
        fi
    fi

    echo "$next_url"
}

IFS=$'\n'
for i in "${!args[@]}"; do
    redirected=false
    redirects=0
    max_redirects=10

    prev_url=''
    url="${args[$i]}"

    # request until prev_url is equal to url
    while [ "$prev_url" != "$url" ]; do
        unset exit_code results result next_url

        # clean the url
        url="$(defang "$url")"
        verbose "checking url: $url"

        # print the url pretty if redirected
        if [ "$redirected" = true ]; then
            printf ">> ${url}\n"
        else
            printf "> ${url}\n"
        fi

        # make the request
        results="$(curl --insecure \
            --silent \
            --fail \
            --show-error \
            --no-progress-meter \
            --connect-timeout 30 \
            --max-time 120 \
            --max-redirs 10 \
            --user-agent "$user_agent" \
            --dump-header - \
            --no-keepalive -o /dev/null \
            "${url}")"

        exit_code=$?
        # when exit code is not 0, handle the error
        if [ $exit_code -ne 0 ]; then
            if [ $exit_code -eq 6 ]; then
                printf "${RED}Error: ${unclean} is unreachable.${RESET}\n"
            elif [ $exit_code -eq 7 ]; then
                printf "${RED}Error: ${unclean} is unreachable.${RESET}\n"
            fi
        fi

        # parse results
        http_version=$(echo "$results" | grep -E '^HTTP\/' | awk '{print $1}')
        response_code=$(echo "$results" | grep -E '^HTTP\/' | awk '{print $2}')
        all_headers=$(echo "$results" | grep -E '^(.+): (.+)$' | sed -E 's/(^|:|-)([a-z])/\1\u\2/g')
        filtered_headers=$(echo "$all_headers" | egrep -iE "$header_filters")

        # print http version and response code
        printf "  ${http_version} ${response_code}\n"
        # print headers
        for header in $filtered_headers; do
            printf "  ${header}\n"
        done

        # we need to handle our redirects here
        unset next_url

        # extract the next url from the "Location:" header
        next_url=$(echo "$all_headers" | grep -E '^Location: ' | awk '{print $2}')

        # next_url is not empty
        if [ ! -z "$next_url" ]; then
            next_url=$(build_url "$url" "$next_url")
        else
            # if the next url is empty and the response code is 100-399, then we need to
            # check the body for the next url, which will require a new safe request for the body
            if [[ "$response_code" =~ ^[1-3][0-9][0-9]$ ]]; then
                verbose "next url is empty, checking body for next url"

                # get only the meta tag in question
                meta_refresh="$(curl -fsSL --user-agent "$user_agent" "${url}" | grep -E '<meta http-equiv="refresh" content="0; url=)' | sed -E 's/.*<meta http-equiv="refresh" content="0; url=([^"]*)".*/\1/g')"
                if [ ! -z "$meta_refresh" ]; then
                    verbose "meta refresh found, setting next url to: $meta_refresh"
                    next_url="$meta_refresh"
                    next_url=$(build_url "$url" "$next_url")
                fi

                # clear meta refresh from memory
                unset meta_refresh
            fi
        fi

        # check if we've been redirected
        if [ ! -z "$next_url" ]; then
            redirected=true
        fi

        # print spacing between urls
        if [ ! -z "$next_url" ]; then
            printf "\n"
        fi

        # set prev_url to current url
        prev_url="$url"
        # set url to next url
        url="$next_url"

        # check if we've exceeded the max redirects
        if [ "$redirected" = true ] && [ "$max_redirects" -eq 0 ]; then
            fmt_error "  Max redirects exceeded"
            exit 1
        fi

        # decrement max redirects
        max_redirects=$((max_redirects - 1))
    done

    # print spacing between urls
    if [[ "$i" -lt "$((${#args[@]} - 1))" ]]; then
        printf "\n"
    fi

done

exit 0
