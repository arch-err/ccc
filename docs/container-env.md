# Container Environment

Information about the tools and environment available inside the container.

## Available Tools

The following tools are pre-installed and available in PATH:

### Editors

- `vim`, `vi`

### Network Tools

- `dig`, `nslookup`, `nsupdate` (DNS utilities)
- `curl`
- `wget`
- `nc` (netcat)

### File Processing

- `jq` (JSON processor)
- `yq` (YAML processor)
- `rg` (ripgrep - fast grep)
- `fd` (fast find)
- `tree`
- `file`
- `unzip`, `gzip`, `tar`

### Development Tools

- `make`
- `sed`, `awk`, `gawk`
- `find`, `xargs`
- `diff`, `cmp`, `patch`
- `less`
- `which`
- `htop`, `ps`, `top`, `free`, `pkill`, `pgrep`

### Core Utilities

Standard coreutils: `cat`, `ls`, `cp`, `mv`, `rm`, `mkdir`, `chmod`, `chown`, `head`, `tail`, `sort`, `uniq`, `wc`, `cut`, `tr`, `tee`, `env`, `printenv`, `basename`, `dirname`, `realpath`

## Installing Additional Tools

For tools NOT listed above, use `nix-shell -p <package>` to temporarily install them:

```bash
# Examples:
nix-shell -p python3 --run "python3 script.py"
nix-shell -p nodejs --run "node app.js"
nix-shell -p rustc cargo --run "cargo build"
nix-shell -p go --run "go build"
```

This approach:

- Does NOT require root/sudo
- Downloads and caches packages automatically
- Works for any package in nixpkgs

## Environment

- `EDITOR=vim` - Default editor for tools like git
- Working directory is mounted from the host
- Network access is available (host networking)
- Git is pre-configured with sandbox identity

## Detaching

Use `/detach` command to detach from this container while keeping it running.
You can reattach later with `ccc attach`.
