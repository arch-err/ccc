# Claude Code Container (ccc)

A CLI tool for managing Claude Code in isolated containers.

> **⚠️ WARNING: Rootless Docker Limitation**
>
> If you're using **rootless Docker**, the `-g/--godmode` flag will NOT enable `--dangerously-skip-permissions`.
> This is a fundamental limitation due to how rootless Docker maps UIDs.
>
> **For full godmode support, use one of:**
> - **Podman** (recommended) - `ccc` will auto-detect and use it
> - **Rootful Docker** - requires running Docker daemon as root
>
> The container still provides filesystem isolation even without godmode.

## Overview

`ccc` provides a secure, containerized environment for running Claude Code with:
- **Multi-runtime support:** Podman, rootful Docker, rootless Docker (auto-detected)
- Filesystem isolation (only mounted directories accessible)
- Session management via container labels
- Pretty CLI interface using `gum`
- Support for both interactive and headless modes

## Runtime Priority

`ccc` automatically detects and uses the best available runtime:

| Priority | Runtime | Godmode Support | Notes |
|----------|---------|-----------------|-------|
| 1 | **Podman** | ✅ Full | Uses `--userns=keep-id` for perfect UID mapping |
| 2 | **Docker (rootful)** | ✅ Full | Uses `--userns=host` with UID matching |
| 3 | **Docker (rootless)** | ❌ Limited | Runs as container root, no `--dangerously-skip-permissions` |

## Quick Start

```bash
# Build the container image
make build

# Start interactive session in current directory
./ccc new -i

# Start with godmode (auto-approve permissions)
./ccc new -ig

# List running containers
./ccc list

# Attach to a container
./ccc attach

# Stop all containers
./ccc stop -a
```

## Commands

### `ccc new`
Start a new container.

| Flag | Description |
|------|-------------|
| `-d, --directory <path>` | Mount directory (default: `$(pwd)`) |
| `-t, --tmux-mount` | Mount tmux socket |
| `-n, --name <name>` | Container name (auto-generated if omitted) |
| `-i, --interactive` | Attach to session immediately |
| `-p <prompt\|->` | System prompt (argument or stdin with `-`) |
| `-f <file>` | System prompt from file |
| `-g, --godmode` | Full permissions mode |
| `--cc-args <args>` | Additional arguments to pass to claude |

**Combined short flags:** `-ig`, `-igt`, etc. are supported.

### `ccc list`
List managed containers.

| Flag | Description |
|------|-------------|
| `-q, --quiet` | Only show container names |

### `ccc stop`
Stop containers.

| Flag | Description |
|------|-------------|
| `-n, --name <name>` | Stop specific container |
| `-a, --all` | Stop all (with confirmation) |

### `ccc attach`
Attach to a running container.

| Flag | Description |
|------|-------------|
| `-n, --name <name>` | Container name (or select interactively) |

### `ccc logs`
View container logs.

| Flag | Description |
|------|-------------|
| `-n, --name <name>` | Container name |
| `-f, --follow` | Follow log output |

### `ccc exec`
Execute command in container.

| Flag | Description |
|------|-------------|
| `-n, --name <name>` | Container name |
| `<command...>` | Command to run |

## Global Flags

| Flag | Description |
|------|-------------|
| `-q, --quiet` | Suppress verbose output |
| `-h, --help` | Show help |

## Design Decisions

- **Session tracking:** Docker labels only (no external state file)
- **Headless mode:** Daemon mode - start in background, attach later
- **Tmux mount:** Disabled by default (use `-t` to enable)
- **Directory:** Defaults to current working directory
- **Naming:** Auto-generated from directory name + hash (e.g., `ccc-my-project-a1b2`)

## Container Architecture

### Dockerfile
- Base: `nixos/nix:latest`
- Tools: nodejs, tmux, gosu, shadow (for UID switching)
- Claude Code installed globally via npm
- Git pre-configured with sandbox identity
- nix-shell available for on-demand tooling

### Mounts
- Project directory (path-mirrored for session compatibility)
- `~/.claude` (Claude Code config)
- `~/.claude.json` (Claude Code state)
- Tmux socket (optional, for host tmux integration)

### Security Model
- Filesystem isolation: only mounted directories accessible
- Network: host networking for simplicity
- UID matching: container user matches host user (in rootful Docker)

## Rootless Docker Technical Details

### Why Godmode Doesn't Work

In rootless Docker, UID mapping works like this:
```
Container UID 0   → Host UID 1000 (your user)
Container UID 1000 → Host UID 101000 (NOT your user)
```

This creates an impossible situation:
- To access your mounted files, you must run as container root (UID 0)
- But Claude Code refuses `--dangerously-skip-permissions` when running as root
- **This cannot be changed** - it's hardcoded in rootless Docker

### Podman's Solution

Podman has `--userns=keep-id` which creates a different mapping:
```
Container UID 1000 → Host UID 1000 (your user) ✓
```

This allows running as non-root while still accessing your files.

### What Still Works in Rootless Docker

Even without godmode, you get:
- ✅ Filesystem isolation (container can only see mounted dirs)
- ✅ Network isolation (if not using `--network host`)
- ✅ Session management and persistence
- ✅ nix-shell for on-demand tooling
- ❌ Auto-approve permissions (must approve manually)

## Files

```
claude-container/
├── Dockerfile      # Container image definition
├── entrypoint.sh   # Container entrypoint (UID switching)
├── Makefile        # Build/run/install targets
├── ccc             # CLI script
└── PLAN.md         # This file
```

## Dependencies

- **Container runtime** (one of):
  - Podman (recommended for full godmode support)
  - Docker rootful (full godmode support)
  - Docker rootless (limited - no godmode)
- **gum** - auto-installed via nix-shell if not present

## Installation

```bash
# Symlink to ~/.local/bin
make install

# Or use directly
./ccc <command>
```
