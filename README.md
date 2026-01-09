# ccc - Claude Code Container

A CLI tool for running Claude Code in isolated containers with full godmode support.

## Why?

Claude Code's `--dangerously-skip-permissions` flag (godmode) lets Claude execute commands without manual approval - great for automation, but risky on your main system. Running Claude in a container provides:

- **Isolation**: Claude can only affect files you explicitly mount
- **Safety**: Mistakes are contained to the container
- **Godmode**: Full automation without risking your system
- **Persistence**: Sessions survive container restarts

## Quick Start

```bash
# Run a one-off prompt with godmode
./ccc new -g -p "create a hello world python script"

# Start an interactive session
./ccc new -g -i

# List running containers
./ccc list

# Attach to an existing session
./ccc attach -n <container-name>

# Stop a container
./ccc stop -n <container-name>
```

## Requirements

- **Podman** (recommended) or **Docker**
- **gum** (for pretty terminal UI) - auto-installed via nix-shell if missing
- Your `~/.claude` directory with valid credentials

## Installation

```bash
# Clone the repository
git clone <repo-url>
cd claude-container

# Build the container image
podman build -t claude-code-sandbox:latest .

# (Optional) Add to PATH
ln -s $(pwd)/ccc ~/.local/bin/ccc
```

### First-Time Setup for Podman

For godmode to work with Podman, you need to set ACLs on your Claude config files:

```bash
# Grant group access via ACLs (required for container file access)
setfacl -R -m g::rwX ~/.claude
setfacl -R -d -m g::rwX ~/.claude
setfacl -m g::rw ~/.claude.json
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for why this is necessary.

## Usage

### Create a New Container

```bash
# Basic usage - headless mode with a prompt
./ccc new -p "your prompt here"

# With godmode (auto-approve all actions)
./ccc new -g -p "your prompt here"

# Interactive mode (opens claude TUI)
./ccc new -g -i

# Specify working directory
./ccc new -g -d /path/to/project -p "analyze this codebase"

# Custom container name
./ccc new -g -n my-project -p "your prompt"
```

### Manage Containers

```bash
# List all ccc containers
./ccc list

# Attach to a running container
./ccc attach -n <name>

# Stop a container
./ccc stop -n <name>

# Start a stopped container
./ccc start -n <name>

# View container logs
./ccc logs -n <name>
./ccc logs -n <name> -f  # follow mode

# Execute commands in a container
./ccc exec -n <name> -- ls -la
./ccc exec -n <name>  # opens a shell
```

## Supported Runtimes

| Runtime | Godmode | Notes |
|---------|---------|-------|
| Podman (rootless) | Yes | Recommended. Requires ACL setup. |
| Docker (rootful) | Yes | Full support via user switching. |
| Docker (rootless) | No | Container runs as uid 0, godmode refused. |

## How It Works

1. **Container Creation**: Mounts your project directory and `~/.claude` credentials
2. **User Switching**: Runs as non-root user inside container (required for godmode)
3. **File Access**: Uses ACLs to grant the container user access to mounted files
4. **Session Persistence**: Sessions are stored and can be resumed with `ccc attach`

See [DOCUMENTATION.md](DOCUMENTATION.md) for technical details.

## Files

- `ccc` - Main CLI script
- `Dockerfile` - Container image definition (based on nixos/nix)
- `entrypoint.sh` - Container entrypoint handling user setup

## License

MIT
