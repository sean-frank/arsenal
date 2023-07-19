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

## References / Assets

> Work in progress

### nslookup

- Query your system's default name server for an IP address (A record) of the domain:  
  ```bash
  nslookup example.com
  ```
- Query a given name server for a NS record of the domain:  
  ```bash
  nslookup -type=NS example.com 8.8.8.8
  ```
- Query for a reverse lookup (PTR record) of an IP address:  
  ```bash
  nslookup -type=PTR 54.240.162.118
  ```
- Query for ANY available records using TCP protocol:  
  ```bash
  nslookup -vc -type=ANY example.com
  ```
- Query a given name server for the whole zone file (zone transfer) of the domain using TCP protocol:  
  ```bash
  nslookup -vc -type=AXFR example.com name_server
  ```
- Query for a mail server (MX record) of the domain, showing details of the transaction:  
  ```bash
  nslookup -type=MX -debug example.com
  ```
- Query a given name server on a specific port number for a TXT record of the domain:  
  ```bash
  nslookup -port=port_number -type=TXT example.com name_server
  ```

### dig

- Lookup the IP(s) associated with a hostname (A records):  
    ```bash
    dig +short example.com
    ```
- Get a detailed answer for a given domain (A records):  
    ```bash
    dig +noall +answer example.com
    ```
- Query a specific DNS record type associated with a given domain name:  
    ```bash
    dig +short example.com A|MX|TXT|CNAME|NS
    ```
- Get all types of records for a given domain name:  
    ```bash
    dig example.com ANY
    ```
- Specify an alternate DNS server to query:  
    ```bash
    dig @8.8.8.8 example.com
    ```
- Perform a reverse DNS lookup on an IP address (PTR record):  
    ```bash
    dig -x 8.8.8.8
    ```
- Find authoritative name servers for the zone and display SOA records:  
    ```bash
    dig +nssearch example.com
    ```
- Perform iterative queries and display the entire trace path to resolve a domain name:  
    ```bash
    dig +trace example.com
    ```

## Contributing

> Work in progress

## License

> Work in progress
