# Installation

## Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/arch-err/ccc/refs/heads/main/install.sh | bash
```

This will:

1. Clone the repository to `~/.local/share/ccc`
2. Run the interactive installer (detects runtimes, checks dependencies)
3. Create symlink at `~/.local/bin/ccc`

## Manual Install

```bash
git clone https://github.com/arch-err/ccc.git ~/.local/share/ccc
cd ~/.local/share/ccc
make install
```

## Pull Container Image

After installation, pull the pre-built container:

```bash
# With Podman
podman pull ghcr.io/arch-err/ccc:latest

# With Docker
docker pull ghcr.io/arch-err/ccc:latest
```

Or build it locally:

```bash
cd ~/.local/share/ccc
make build
```

## Requirements

| Dependency | Required | Description |
|------------|----------|-------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Yes | The CLI tool this wraps |
| [Docker](https://docs.docker.com/get-docker/) | One of | Container runtime |
| [Podman](https://podman.io/getting-started/installation) | One of | Container runtime |
| [gum](https://github.com/charmbracelet/gum) | Yes | Terminal UI components |

## Verifying Installation

After installation, verify everything works:

```bash
# Check ccc is available
ccc --help

# Check container image is available
podman images | grep ccc
# or
docker images | grep ccc
```
