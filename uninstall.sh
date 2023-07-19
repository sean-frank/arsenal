#!/bin/sh

read -r -p "Are you sure you want to remove Arsenal? [y/N] " confirmation
if [ "$confirmation" != y ] && [ "$confirmation" != Y ]; then
    echo "Uninstall cancelled"
    exit
fi

echo "Removing ~/.arsenal"
if [ -d ~/.arsenal ]; then
    rm -rf ~/.arsenal
fi

if [ -e ~/.bashrc ]; then
    BASHRC_SAVE=~/.bashrc.uninstalled-$(date +%Y-%m-%d_%H-%M-%S)
    echo "Found ~/.bashrc -- Renaming to ${BASHRC_SAVE}"
    mv ~/.bashrc "${BASHRC_SAVE}"
fi

echo "Looking for original zsh config..."
BASHRC_ORIG=~/.bashrc.pre-arsenal
if [ -e "$BASHRC_ORIG" ]; then
    echo "Found $BASHRC_ORIG -- Restoring to ~/.bashrc"
    mv "$BASHRC_ORIG" ~/.bashrc
    echo "Your original bash config was restored."
else
    echo "No original bash config found"
fi

echo "Thanks for trying out Arsenal! We've successfully uninstalled it."
echo "Don't forget to restart your terminal!"
