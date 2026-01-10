# CLI Reference

Complete reference for all ccc commands.

## `ccc new`

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
  -c, --clean            Use temporary directory as workspace
  -a, --anonymous        Don't mount credentials
  -t, --tmux             Mount tmux socket for integration
  --network <name>       Use custom network instead of host
  --cc-args <args>       Additional arguments to pass to claude
  -q, --quiet            Minimal output, print container name only

Short flags can be combined: -giq = godmode + interactive + quiet
```

## `ccc list`

Lists all ccc-managed containers.

```
Usage: ccc list [-q|--quiet]

Options:
  -q, --quiet    Only print container names
```

## `ccc attach`

Attaches to an existing container's Claude session.

```
Usage: ccc attach [-n|--name <name>]

If no name specified, shows interactive picker.
```

## `ccc stop`

Stops a running container.

```
Usage: ccc stop [-n|--name <name>] [-a|--all]

Options:
  -n, --name <name>    Stop specific container
  -a, --all            Stop all ccc containers
```

## `ccc start`

Starts a stopped container.

```
Usage: ccc start [-n|--name <name>] [-a|--attach]

Options:
  -n, --name <name>    Container to start
  -a, --attach         Attach after starting
```

## `ccc logs`

View container logs.

```
Usage: ccc logs [-n|--name <name>] [-f|--follow]

Options:
  -n, --name <name>    Container name
  -f, --follow         Follow log output
```

## `ccc exec`

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
