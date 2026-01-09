# ccc Documentation

Technical documentation for the Claude Code Container CLI.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Host System                          │
│                                                             │
│  ~/.claude/          ~/.claude.json      ~/your-project/   │
│  (credentials)       (config)            (code)            │
│       │                   │                   │             │
│       └───────────────────┼───────────────────┘             │
│                           │                                 │
│                    bind mounts                              │
│                           │                                 │
│  ┌────────────────────────▼────────────────────────────┐   │
│  │              Container (claude-code-sandbox)         │   │
│  │                                                      │   │
│  │   entrypoint.sh                                      │   │
│  │        │                                             │   │
│  │        ▼                                             │   │
│  │   Creates user (uid 1000, gid 0)                     │   │
│  │        │                                             │   │
│  │        ▼                                             │   │
│  │   gosu → claude --dangerously-skip-permissions       │   │
│  │                                                      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## CLI Reference

### `ccc new`

Creates and starts a new container.

```
Usage: ccc new [OPTIONS]

Options:
  -n, --name <name>      Container name (auto-generated if not specified)
  -d, --dir <path>       Working directory to mount (default: current dir)
  -p, --prompt <text>    Prompt to run (headless mode)
  -f <file>              Read prompt from file
  -g, --godmode          Enable --dangerously-skip-permissions
  -i, --interactive      Interactive mode (opens TUI)
  -t, --tmux             Mount tmux socket for integration
  --cc-args <args>       Additional arguments to pass to claude
  -q, --quiet            Minimal output, print container name only

Short flags can be combined: -giq = godmode + interactive + quiet
```

### `ccc list`

Lists all ccc-managed containers.

```
Usage: ccc list [-q|--quiet]

Options:
  -q, --quiet    Only print container names
```

### `ccc attach`

Attaches to an existing container's Claude session.

```
Usage: ccc attach [-n|--name <name>]

If no name specified, shows interactive picker.
```

### `ccc stop`

Stops a running container.

```
Usage: ccc stop [-n|--name <name>] [-a|--all]

Options:
  -n, --name <name>    Stop specific container
  -a, --all            Stop all ccc containers
```

### `ccc start`

Starts a stopped container.

```
Usage: ccc start [-n|--name <name>] [-a|--attach]

Options:
  -n, --name <name>    Container to start
  -a, --attach         Attach after starting
```

### `ccc logs`

View container logs.

```
Usage: ccc logs [-n|--name <name>] [-f|--follow]

Options:
  -n, --name <name>    Container name
  -f, --follow         Follow log output
```

### `ccc exec`

Execute a command in a running container.

```
Usage: ccc exec [-n|--name <name>] [-- command...]

If no command specified, opens a shell.
```

## Container Labels

ccc uses container labels to track state:

| Label | Description |
|-------|-------------|
| `ccc.managed` | Always `true` for ccc containers |
| `ccc.name` | Container name |
| `ccc.directory` | Mounted working directory |
| `ccc.runtime` | Runtime mode (podman/docker-rootful/docker-rootless) |
| `ccc.session-id` | Claude session UUID for resuming |
| `ccc.mode` | `interactive` or `headless` |
| `ccc.godmode` | `true` if godmode was enabled |

## Container Image

The container is based on `nixos/nix:latest` and includes:

- Node.js (for Claude Code)
- Claude Code CLI (`@anthropic-ai/claude-code`)
- tmux (for session management)
- gosu (for user switching)
- shadow (for user creation)
- git

### Dockerfile Overview

```dockerfile
FROM nixos/nix:latest

# Install tools via nix
RUN nix-env -iA nixpkgs.nodejs nixpkgs.tmux nixpkgs.gosu nixpkgs.shadow

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Setup permissions for non-root nix usage
RUN chmod 700 /nix/var/nix/builds && \
    chmod -R a+rwX /nix/var/nix/profiles ...

ENTRYPOINT ["/entrypoint.sh"]
CMD ["claude"]
```

## Entrypoint Behavior

The `entrypoint.sh` script handles user setup:

1. **Reads environment variables**:
   - `CLAUDE_HOST_PATH` - Working directory
   - `CLAUDE_HOST_HOME` - Home directory path
   - `CLAUDE_HOST_UID` - User ID to create
   - `CLAUDE_HOST_USER` - Username to create

2. **Creates non-root user** with:
   - UID from `CLAUDE_HOST_UID` (default: 1000)
   - Primary group: 0 (root) - for file access
   - Home: `CLAUDE_HOST_HOME`

3. **Executes command** via `gosu` as the non-root user

## Runtime Detection

ccc auto-detects the container runtime:

```bash
# Check order:
1. Is podman available? → podman
2. Is docker available?
   - Is dockerd running as root? → docker-rootful
   - Is dockerd running rootless? → docker-rootless
```

## Modes

### Headless Mode (default with -p)

- Container runs `tail -f /dev/null` as main process
- Claude runs via `podman exec`
- Session can be resumed with `ccc attach`

### Interactive Mode (-i)

- Claude runs as the main container process
- Attach with `podman attach` or `ccc attach`
- Use `Ctrl+P, Ctrl+Q` to detach without stopping

## Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| Working directory | Same path | Project files |
| `~/.claude` | Same path | Credentials, settings, history |
| `~/.claude.json` | Same path | Claude config |
| Prompt file (temp) | `/tmp/claude-prompt.md` | Prompt content |

## Environment Variables

Passed to the container:

| Variable | Description |
|----------|-------------|
| `CLAUDE_HOST_PATH` | Working directory |
| `CLAUDE_HOST_HOME` | Home directory |
| `CLAUDE_HOST_UID` | Host user's UID |
| `CLAUDE_HOST_USER` | Host username |
| `TERM` | Terminal type |

## Session Persistence

Claude sessions are identified by UUID and stored in the session-id label. When you run `ccc attach`, it:

1. Reads the session-id from container labels
2. Runs `claude --resume <session-id>`
3. If godmode was enabled at creation, adds `--dangerously-skip-permissions`
