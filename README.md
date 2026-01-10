# ccc - Claude Code Container

![ccc logo](./docs/assets/claude_container_no_background.png)


<p align="center">

[![Claude](https://img.shields.io/badge/Claude-D97757?logo=anthropic&logoColor=fff)](https://claude.ai)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=fff)](https://www.docker.com/)
[![Podman](https://img.shields.io/badge/Podman-892CA0?logo=podman&logoColor=fff)](https://podman.io/)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=fff)](https://www.gnu.org/software/bash/)
[![gum](https://img.shields.io/badge/Gum-FF5F87?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xMiAyQzYuNDggMiAyIDYuNDggMiAxMnM0LjQ4IDEwIDEwIDEwIDEwLTQuNDggMTAtMTBTMTcuNTIgMiAxMiAyem0wIDE4Yy00LjQxIDAtOC0zLjU5LTgtOHMzLjU5LTggOC04IDggMy41OSA4IDgtMy41OSA4LTggOHoiLz48L3N2Zz4=)](https://github.com/charmbracelet/gum)

</p>

CLI for running Claude Code in isolated containers, so you can use `--dangerously-skip-permissions` without feeling guilty.

**[📖 Full Documentation](https://arch-err.github.io/ccc)**

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/arch-err/ccc/refs/heads/main/install.sh | bash

# Pull container image
podman pull ghcr.io/arch-err/ccc:latest

# Run an interactive session with godmode
ccc new -ig

# Run a one-off prompt
ccc new -g -p "create a hello world python script"
```

## Requirements

| Dependency | Required | Description |
|------------|----------|-------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Yes | The CLI tool this wraps |
| [Docker](https://docs.docker.com/get-docker/) | One of | Container runtime |
| [Podman](https://podman.io/getting-started/installation) | One of | Container runtime |
| [gum](https://github.com/charmbracelet/gum) | Yes | Terminal UI components |

## How It Works

1. **Container Creation**: Mounts your project directory and `~/.claude` credentials
2. **LD_PRELOAD Magic**: A tiny library fakes uid/gid syscalls, making Claude think it's non-root
3. **Root File Access**: Actually runs as root inside container, so all mounted files are accessible
4. **Session Persistence**: Sessions are stored and can be resumed with `ccc attach`

## Documentation

- [Installation](https://arch-err.github.io/ccc/installation/) - Setup guide
- [Usage](https://arch-err.github.io/ccc/usage/) - Container management
- [Isolation](https://arch-err.github.io/ccc/isolation/) - Advanced security features
- [CLI Reference](https://arch-err.github.io/ccc/reference/cli/) - All commands
- [Troubleshooting](https://arch-err.github.io/ccc/troubleshooting/) - Common issues

## License

MIT License - see [LICENSE](LICENSE) for details.
