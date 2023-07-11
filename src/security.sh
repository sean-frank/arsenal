#!/usr/bin/env sh

# security.sh - Check a website for its security.txt file, in case it's RFC 9116 compliant.

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
