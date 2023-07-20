#!/usr/bin/env bash
# ./src/security.sh
# Description: checks for a website's security.txt file.

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
import utils/commons.sh

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <website>"
    exit 1
fi

url="$1"
security_txt_url="$url/.well-known/security.txt"

security_txt_content=$(curl -sk "$security_txt_url")

if [ -z "$security_txt_content" ]; then
    echo "No security.txt file found for $url"
else
    echo "Security.txt file content for $url:"
    echo "$security_txt_content"
fi
