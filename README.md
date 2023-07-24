# Arsenal

A set of scripts and tools to be use for investigating abuse on the cloud.

## Scripts Overview

### Content Verification

- **spotter**: checks a url status, safely checks aliveness.
- **sniper**: same as **spotter**, except it inspects content for client-side redirects and follows it, e.g. html-meta tags.
- **sapper**: similar to **spotter**, except the text content is output.
- **proxus**: similar to **spotter**, but allows for easier use of proxies by region name, also supports manual proxy.
- **urlscan**: submits scans for a url using the urlscan.io service.
- **virustotal**: submits scans and lookups (domains or urls) using the virustotal service.

### Domains & IP Addresses

- **hoster**: checks host info for a domain or ip address.
- **whobe**: get the whois/rdap/arin for a domain or ip addr, determines the netloc owner for the matching subnet of the ip.
- **blister**: checks top email, domain, and ip addr blacklistings for a given email, domain, or ip addr

### Domains

- **nstrace**: perform a deep nameserver lookup, recursively checks the name servers associated with a domain, checks each for current ip records, and verifies relationship of domain registrar with nameservers.
- **robots**: checks for a domains robots.txt and verifies compliance for specified user agents.
- **security**: checks a rfc9116 compliant domains security.txt file for reporting info.

### IP Addresses

- **netcheck**: check an ip addr for its netrange or verify if ip is within a netrange.
- **geoip**: get the geo location info for a given domain.
- **torcheck**: check an ip addr for an active TOR node.

### Servers & Hosts

- **sentry**: interactive and easily adaptive vuln checks and port scans (enforced unobtrusive scans only)

### Utilities

- **refang**: refangs urls, domains, and ip addresses from text.
- **defang**: defangs urls, domains, and ip addresses from text.
- **spamit**: parse and perform checks on a raw email and/or header, auto-unquotes, redacts recipient info



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
