#!/usr/bin/env bash
# ./src/robots.sh
# Description: checks for a website's robots.txt file.

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

# robots.sh - Checks for a website's robots.txt file, parsing and outputting its rules.

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <url>"
    exit 1
fi

url="$1"
robots_url="$url/robots.txt"

robots_content=$(curl -sK "$robots_url")

if [ -z "$robots_content" ]; then
    echo "No robots.txt file found for $url"
else
    echo "Robots.txt rules for $url:"
    echo "$robots_content"
fi
