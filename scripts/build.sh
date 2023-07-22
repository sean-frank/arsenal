#!/usr/bin/env bash

FULL_PATH="$0"
THIS_SCRIPT_DIR="$(readlink -f "$(dirname "$FULL_PATH")")"
THIS_ROOT_DIR="$(dirname "$THIS_SCRIPT_DIR")"
BIN_DIR="$THIS_ROOT_DIR/bin"
SRC_DIR="$THIS_ROOT_DIR/src"

# Create a directory to store the arsenal scripts
if [ ! -d "$BIN_DIR" ]; then
    mkdir -p "$BIN_DIR"
fi

for script in "$SRC_DIR"/*; do
    script_name=$(basename "$script")
    script_name="${script_name%.*}"
    script_path="$BIN_DIR/$script_name"

    # Check if the script has a valid shebang
    if [ -f "$script" ] && head -n 1 "$script" | grep -qE "^#\!/.+?$"; then
        # Make the script executable if it's not
        if [ ! -x "$script" ]; then
            chmod +x "$script"
        else
            echo "Script '$script' is already executable, skipping..."
        fi

        # If the script doesn't exist, create it
        if [ ! -f "$script_path" ]; then
            echo "Adding to symlink farm: $script_name"
            ln -s "$script" "$script_path"
        else
            echo "There was a possible script collision, symlink exists already for '$script' to '$script_name'."
        fi
    else
        echo "Script '$script' does not contain a valid shebang, skipping..."
    fi
done

echo "${BLUE}Validating symlinks from symlink farm for any discrepancies...${RESET}"
# Locate all symlinks from $ARSENAL_BASH/bin and remove those that don't have
# a corresponding script that is a valid executable file in $ARSENAL_BASH/src
for symlink in "$BIN_DIR"/*; do
    symlink_name=$(basename "$symlink")
    symlink_name="${symlink_name%.*}"
    symlink_path="$BIN_DIR/$symlink_name"

    # Check if the symlink is a symlink and if it's not a valid executable file
    if [ -L "$symlink" ] && [ ! -f "$symlink_path" ] && [ ! -x "$symlink_path" ]; then
        echo "Removing from symlink farm: $symlink_name"
        rm "$symlink"
    fi
done

exit 0
