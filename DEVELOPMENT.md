# Development

## Setup

> Work in progress

## Setup

> Work in progress

## Building

> Work in progress

## Testing

> Work in progress

### Running Localized Distribution

Create a local distribution of the script using a simplified HTTP server.

```bash
python3 -m http.server --bind 127.0.0.1 --port 8080 --directory .
```

### Running Localized Script

Run the script locally.

```bash
bash <(curl -skL http://LHOST:LPORT/install.sh) --no-deps --branch dev --force
```


## Processing

1. Try to determine the running user even if the script is run as root.
2. Check if the user can escalate to root, required for installing dependencies.
3. Attempt to install dependencies, which "should" install chsh and zsh.
4. Check if the user's default shell is zsh, if not, change it.
   1. Saving the users current shell to a dot file.
   2. Changing the users default shell to zsh, if --no-csh is not set.
5. Check if the user has oh-my-zsh installed, if not, install it.
   1. Skip if --no-omz is set.
   2. Backup the users .zshrc file.
   3. Install/Update default plugins.
   4. Install/Update default themes.
   5. Install/Update default configs.
   6. Update default oh-my-zsh config to require non-interactive updates every 2 weeks.
6. Install Arsenal repository tools.
   1. Backup the users dot file for their default shell, if it's not zsh.
   2. Manually clone the repository to ~/.arsenal.
   3. Build the arsenal binaries.
   4. Install the arsenal binaries to ~/.arsenal/bin.
   5. Updating/Removing any existing arsenal binaries.
   6. Add ~/.arsenal/bin to the users PATH.
   7. Add ~/.arsenal/bin to the users default shell's PATH.
   8. Add ~/.arsenal/bin to the users default shell's startup file, if exists.
7. Install deprecating toy-box scripts to ~/.arsenal/bin.

## Contributing

> Work in progress

## License

> Work in progress
