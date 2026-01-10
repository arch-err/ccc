# Architecture

Technical details about how ccc works internally.

## System Overview

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
