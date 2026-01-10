# Usage

## Create a New Container

```bash
# Basic usage - headless mode with a prompt
ccc new -p "your prompt here"

# With godmode (auto-approve all actions)
ccc new -g -p "your prompt here"

# Interactive mode (opens Claude TUI)
ccc new -g -i

# Specify working directory
ccc new -g -d /path/to/project -p "analyze this codebase"

# Custom container name
ccc new -g -n my-project -p "your prompt"
```

## Manage Containers

### List Containers

```bash
# List all ccc containers
ccc list
```

### Attach to a Container

```bash
# Attach to a running container
ccc attach -n <name>
```

### Stop and Start

```bash
# Stop a container
ccc stop -n <name>

# Start a stopped container
ccc start -n <name>
```

### View Logs

```bash
# View container logs
ccc logs -n <name>

# Follow log output
ccc logs -n <name> -f
```

### Execute Commands

```bash
# Execute commands in a container
ccc exec -n <name> -- ls -la

# Open a shell
ccc exec -n <name>
```

## Modes

### Headless Mode (default with `-p`)

- Container runs `tail -f /dev/null` as main process
- Claude runs via `podman exec`
- Session can be resumed with `ccc attach`

### Interactive Mode (`-i`)

- Claude runs as the main container process
- Attach with `podman attach` or `ccc attach`
- Use `Ctrl+P, Ctrl+Q` to detach without stopping

## Files

The main files in the ccc repository:

- `ccc` - Main CLI script
- `Dockerfile` - Container image definition (based on nixos/nix)
- `entrypoint.sh` - Container entrypoint handling user setup
