# Arsenal

A set of scripts and tools to be use for investigating abuse on the cloud.

-   robots: check robots file
-   security: check /.well-known/security.txt
-   netcheck: check if ip is within netrange

## Benefits

-   Easy to install, remove and update.
-   Installs system dependencies as needed, supports Redhat, CentOS, & Debian
    based OS.
-   Installs Python packages, as needed.
-   Creates backups of the users shell prior to running and existing dotfiles
    for the users configured shell.
    -   Max 3 dotfile backups.
-   Installs zsh and configures it as the default shell, unless specified
    otherwise.
    -   Sets zsh as the users default shell.
-   Installs oh-my-zshell, as long as zsh is installed or specified otherwise.
    -   Installs plugins that would best improve your workflow.
    -   Sets configs according to best practices.
    -   Overrides default theme to use `mh`, a minimalist theme.
    -   Enables the plugins installed.
    -   Enables non-interactive updates every 14 days, overrides user specified
        (No compliance breaking allowed).
    -   Sets user prompt to be minimal, yet informative.
    -   Removes RPROMPT (right prompt) to save space.
-   Installs [arsenal] (https://github.com/xransum/arsenal) scripts and tools.
    -   Builds a symlink farm in repo's root bin `.arsenal/bin`, allows for
        fully dynamic ease of use.
    -   Adds arsenal scripts bin to users `PATH`.
-   Installs deprecating [toy-box] (https://github.com/drampil/toy-box)
    -   Downloads script sources to `.arsenal/toybox`.
    -   Builds a symlink farm in the repo's root bin `.arsenal/bin`.
