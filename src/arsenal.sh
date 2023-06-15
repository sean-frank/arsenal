#!/usr/bin/env sh

SOURCE=${BASH_SOURCE[0]}

# resolve $SOURCE until the file is no longer a symlink
while [ -L "$SOURCE" ]; do
  SRC_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  # if $SOURCE was a relative symlink, we need to resolve it
  # relative to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE=$SRC_DIR/$SOURCE
done
SRC_DIR=$(cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd)
BIN_DIR="$(dirname "$SRC_DIR")/bin"
cd "$SRC_DIR"


import() {
    for v in "$@"; do
        if [ -f "$v" ]; then
            source "$(readlink -f "$v")"
        else
            echo "File not found: $v"
            exit 1
        fi
    done
}

# dependencies
import version.sh
import utils/commons.sh

print_header() {
  printf '%s                                    __%s\n' $RED $RESET
  printf '%s  ____ ______________  ____  ____ _/ /%s\n' $RED $RESET
  printf '%s / __ `/ ___/ ___/ _ \/ __ \/ __ `/ / %s\n' $RED $RESET
  printf '%s/ /_/ / /  (__  )  __/ / / / /_/ / /  %s\n' $RED $RESET
  printf '%s\__,_/_/  /____/\___/_/ /_/\__,_/_/   %s\n' $RED $RESET
  printf '\n'
}

setup_colors
print_header

printf '%s\n' "Version: ${YELLOW}${__version__}${RESET}"
printf '%s\n' "Build: ${YELLOW}${__build__}${RESET}"
printf '%s\n' "Author: ${YELLOW}${__author__}${RESET}"
printf '%s\n' "Email: ${YELLOW}${__author_email__}${RESET}"
printf '%s\n' "License: ${YELLOW}${__license__}${RESET}"
printf '%s\n' "URL: ${YELLOW}${__url__}${RESET}"
printf '%s\n' "Description: ${YELLOW}${__description__}${RESET}"
printf '\n'

printf '%s\n' "Scripts currently available:"
# all scripts should have symlinks within the $DIR

for f in $(find "$BIN_DIR" -type l); do
    script_name=$(basename "$f")
    printf ' - %s\n' "${YELLOW}${script_name}${RESET}"
done

printf '\n'
printf "Here's some cake ${__cake__}\n"
printf '\n'

exit 0