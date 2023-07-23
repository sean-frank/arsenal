# Arsenal

A set of scripts and tools to be use for investigating abuse on the cloud.

## Scripts

> Work in Progress

- **sniper**: checks status of urls, follows redirects, and inspects page contents for meta redirects.
- **spotter**: checks urls status, with proper sanity checks for dangerous content.
- **digs**: checks host info for an ip address(es).
- **whobe**: get the whois/rdap/arin for a domain or ip addr, determines the netloc owner for the matching subnet of the ip.
- **geoip**: get the geo location info for a given domain.
- **uview**: retrieves the contents of the URL and parses it as text
- **nstrace**: perform a deep nameserver lookup, recursively checks the name servers associated with a domain, checks each for current ip records, and verifies relationship of domain registrar with nameservers.
- **robots**: parses a sites robots.txt, if exists, and verifies compliance for specified user agents.
- **security**: verifies a rfc9116 compliant site for it's security.txt, for it's reporting info.
- **torcheck**: checks an ip addr to see if it is used as an active TOR node.
- **proxus**: similar to curls but allows for manually set proxies or proxy by next closest location.
- **refang**: refangs urls
- **defang**: defangs urls
- **urlscan**: aperforms a scan for a url using the urlscan.io service.
- **virustotal**: performs a scan and lookup for a url or domain using the virustotal service.
- **spamit**: parse and perform checks on a raw email and/or header, auto-unquotes, redacts recipient info
- **sentry**: interactive and easily adaptive vuln checks and port scans (enforced unobtrusive scans only)
- **blister**: checks top email, domain, and ip addr blacklistings for a given email, domain, or ip addr
- **netcheck**: check if ip is within netrange
- **malvera**: downloadless verification of a URL for potential malicious data

## Installation

```bash
bash <(curl -skL https://raw.githubusercontent.com/xransum/arsenal/master/install.sh)
```
Flags:
- `--no-deps`: skip system dependency installs
- `--no-py`: skip python package installs
- `--force`: force install, no confirmations

## Uninstallation

```bash
bash <(curl -skL https://raw.githubusercontent.com/xransum/arsenal/master/uninstall.sh)
```
- `--force`: force uninstall, no confirmations

## Usage

```bash
arsenal
```

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
