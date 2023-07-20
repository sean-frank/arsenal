#!/usr/bin/env bash
# ./src/ipcheck.sh
# Description: checks ip address information from ipinfo.io

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

# prints script help menu
function help {
    echo "Usage: ipcheck [IP_ADDRESS]..."
    echo ""
    echo "checks ip address information from ipinfo.io"
    echo ""
    echo "Startup:"
    echo "  -h,  --help              print this help."
    exit 1
}

# for --help|-h flags or empty flags, print help
# TODO: add support for flags for each object key
if [ -z "$1" ] || [[ "$@" == *"-h"* ]]; then
    help
    exit 1
fi

function valid_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 &&
            ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

for ipaddr in "$@"; do
    #echo "Checking $ipaddr"
    if valid_ip "$ipaddr"; then
        res=$(curl -skL "https://ipinfo.io/$ipaddr/json")
        echo "$res"
        #echo "IP Address: $(jq '.ip' <<<"$res")"
        #echo "Hostname: $(jq '.hostname' <<<"$res")"
        #echo "City: $(jq '.city' <<<"$res")"
        #echo "Region: $(jq '.region' <<<"$res")"
        #echo "Country: $(jq '.country' <<<"$res")"
        #echo "Loc: $(jq '.loc' <<<"$res")"
        #echo "Org: $(jq '.org' <<<"$res")"
        #echo "Postal: $(jq '.postal' <<<"$res")"
        #echo "Timezone: $(jq '.timezone' <<<"$res")"
        #echo "Readme: $(jq '.readme' <<<"$res")"
        #echo ""
    else
        echo "Input is not a valid IP address"
    fi
done

exit 0
