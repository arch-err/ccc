#!/bin/sh
set -e

# Get host context from environment
HOST_PATH="${CLAUDE_HOST_PATH:-$(pwd)}"
HOST_HOME="${CLAUDE_HOST_HOME:-/root}"

# Setup environment
export HOME="$HOST_HOME"
export PATH="/usr/local/bin:/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

# Use LD_PRELOAD to fake UID for godmode support
# This makes Claude think we're uid 1000 while keeping root's file access
export LD_PRELOAD="/usr/local/lib/libfakeuid.so"

# Create working directory if needed
mkdir -p "$HOST_PATH" 2>/dev/null || true
cd "$HOST_PATH"

exec "$@"
