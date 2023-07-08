#!/bin/env bash
# digs.sh
# Description: domain name system lookup

# parse args
function help {
    echo "Usage: digs [DOMAIN]..."
    echo ""
    echo "domain name system lookup, equivalent to -"
    echo "host DOMAIN"
    echo ""
    echo "Startup:"
    echo "  -h,  --help              print this help."
    exit 1
}

# flags: --no-line
# positional args: URL|DOMAIN
noline=false
args=()
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            help
            exit 1
            ;;
        --no-line)
            noline=true
            shift
            ;;
        -*|--*)
            shift
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done
# recover potential lost args
set -- "${args[@]}"

if [ -z "$1" ]; then
    help
    exit 1 # unclean exit
fi

# functions
function clean_url() {
    value="$1"
    echo "$value" \
        | sed 's/ //g' \
        | sed 's/h[tx]\{2\}p/http/gi;' \
        | sed 's/\[\+\.\]\+/./g' \
        | sed 's/\[\+:\/\/\]\+/:\/\//g'
}

function echoline {
    nchars="$1"
    char="$2"
    if [[ "$nchars" == "" ]]; then
        chars=50
    fi
    if [[ "$char" == "" ]]; then
        char="-"
    fi

    if [[ "$noline" == false ]]; then
        for i in $(seq 1 $nchars); do 
            echo -n "$char"
        done
        echo ""
    fi
}

# exit code defailt 0
ret=0
echoline 50 "-"
for value in "${args[@]}"; do
    value="$(clean_url "$value")"

    # extract domain?
    if [[ "$value" == *"http://"* ]] || [[ "$value" == *"https://"* ]]; then
        value=$(awk -F/ '{print $3}'<<<"$value")
    fi
    
    echo "> $value"
    
    #output="$(dig +short $value | sort -n)"
    output="$(host $value 2>&1)"
    ret=$? # capture return code
    
    if [ $ret -ne 0 ]; then
        if [[ "$output" == *"not found"* ]]; then
            echo "No records found."
        elif [[ "$output" == *"timed out"* ]]; then
            echo "DNS lookup timed out."
        else
            echo "Unknown error."
            echo "$output"
        fi
        
        #echo "Whois: https://www.iana.org/whois?q=$value"
    else
        if [[ "$output" ]]; then
            echo "$output"
        else
            echo "No records found."
        fi
    fi
    
    if [[ "${value}" != "${args[-1]}" ]]; then
        echo ""
    fi
done
echoline 50 "-"

exit $ret
