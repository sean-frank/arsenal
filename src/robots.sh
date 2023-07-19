#!/usr/bin/env bash

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
