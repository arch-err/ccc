#!/bin/sh
set -e

# Get host context from environment
HOST_PATH="${CLAUDE_HOST_PATH:-$(pwd)}"
HOST_HOME="${CLAUDE_HOST_HOME:-/root}"

# Setup environment
export HOME="$HOST_HOME"
export PATH="/usr/local/bin:/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

# Use LD_PRELOAD to fake UID for godmode support
# This makes Claude think we're uid 1000 while keeping root's file access
export LD_PRELOAD="/usr/local/lib/libfakeuid.so"

# Create working directory if needed
mkdir -p "$HOST_PATH" 2>/dev/null || true
cd "$HOST_PATH"

# Setup .claude directory with container commands + host config
# Host's .claude is mounted read-only at /host-claude
# We create a writable .claude in container that merges both
mkdir -p "$HOME/.claude"

# Directories that Claude needs to write to (don't symlink, create fresh)
WRITABLE_DIRS="debug cache todos statsig telemetry shell-snapshots session-env file-history"

# Symlink host's .claude contents (except writable dirs and commands)
if [ -d /host-claude ]; then
    for item in /host-claude/*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        # Skip commands directory - we'll handle it specially
        [ "$name" = "commands" ] && continue
        # Skip writable directories - create fresh ones
        case " $WRITABLE_DIRS " in
            *" $name "*) continue ;;
        esac
        ln -sf "$item" "$HOME/.claude/$name" 2>/dev/null || true
    done
fi

# Create writable directories
for dir in $WRITABLE_DIRS; do
    mkdir -p "$HOME/.claude/$dir"
done

# Create merged commands directory with container commands + host commands
mkdir -p "$HOME/.claude/commands"

# Copy container commands first (they take precedence)
if [ -d /ccc/commands ]; then
    cp /ccc/commands/*.md "$HOME/.claude/commands/" 2>/dev/null || true
fi

# Copy host commands (don't overwrite container ones)
if [ -d /host-claude/commands ]; then
    for cmd in /host-claude/commands/*.md; do
        [ -f "$cmd" ] || continue
        cmdname=$(basename "$cmd")
        [ ! -f "$HOME/.claude/commands/$cmdname" ] && cp "$cmd" "$HOME/.claude/commands/$cmdname"
    done
fi

# Check if we should start tmux server (CCC_USE_TMUX env var)
if [ "${CCC_USE_TMUX:-false}" = "true" ]; then
    # Start tmux server with detached session
    /usr/bin/tmux.real \
        -S /tmp/ccc.sock \
        -f /etc/ccc-tmux.conf \
        new-session -d -s main "$@"

    # Keep container alive by waiting on tmux server
    # This exits when tmux server terminates (all sessions closed)
    exec /usr/bin/tmux.real -S /tmp/ccc.sock wait-for ccc-exit
else
    # Legacy mode: run command directly
    exec "$@"
fi
