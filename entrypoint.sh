#!/bin/sh
set -e

# Get host context from environment
HOST_PATH="${CLAUDE_HOST_PATH:-$(pwd)}"
HOST_HOME="${CLAUDE_HOST_HOME:-/root}"
HOST_UID="${CLAUDE_HOST_UID:-1000}"
HOST_USER="${CLAUDE_HOST_USER:-claude}"

# Setup environment
export PATH="/usr/local/bin:/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

# Create working directory (only inside container, not touching mounts)
mkdir -p "$HOST_PATH" 2>/dev/null || true

cd "$HOST_PATH"

# Switch to non-root user for godmode support
# Key insight: In rootless podman, mounted files appear as root:root (gid 0)
# By adding user to root group (gid 0), they can access mounted files via group perms
if [ "$(id -u)" = "0" ]; then
    # Replace nix symlinks with actual files so useradd can modify them
    # (nix /etc/passwd and /etc/group are symlinks to read-only store)
    for f in /etc/passwd /etc/group /etc/shadow; do
        if [ -L "$f" ]; then
            target=$(readlink "$f")
            rm "$f"
            cat "$target" > "$f"
            chmod 644 "$f"
        fi
    done
    chmod 600 /etc/shadow 2>/dev/null || true

    # Create user with PRIMARY group 0 (root) for file access
    # Home dir is /home/$HOST_USER (container-local, owned by user)
    # This allows nix-shell to work (nix checks home ownership)
    # User is added to nixbld group (30000) to allow nix store writes
    CONTAINER_HOME="/home/$HOST_USER"
    if ! grep -q "^[^:]*:[^:]*:$HOST_UID:" /etc/passwd 2>/dev/null; then
        useradd -u "$HOST_UID" -g 0 -G 0,30000 -d "$CONTAINER_HOME" -s /bin/sh -M "$HOST_USER" 2>/dev/null || true
    fi

    # Create container-local home directory owned by the user
    mkdir -p "$CONTAINER_HOME" 2>/dev/null || true
    chown "$HOST_UID:0" "$CONTAINER_HOME" 2>/dev/null || true

    # Symlink claude config from host home to container home
    # This gives claude access to ~/.claude and ~/.claude.json
    ln -sf "$HOST_HOME/.claude" "$CONTAINER_HOME/.claude" 2>/dev/null || true
    ln -sf "$HOST_HOME/.claude.json" "$CONTAINER_HOME/.claude.json" 2>/dev/null || true

    # Setup nix for the non-root user
    # nix tries to chmod per-user directories - this only works if user owns them
    # Chown the per-user directories to the non-root user so nix-shell works
    chown "$HOST_UID:0" /nix/var/nix/profiles/per-user 2>/dev/null || true
    chown "$HOST_UID:0" /nix/var/nix/gcroots/per-user 2>/dev/null || true

    # Create per-user profile directory
    mkdir -p "/nix/var/nix/profiles/per-user/$HOST_USER" 2>/dev/null || true
    mkdir -p "/nix/var/nix/gcroots/per-user/$HOST_USER" 2>/dev/null || true
    chown -R "$HOST_UID:0" "/nix/var/nix/profiles/per-user/$HOST_USER" 2>/dev/null || true
    chown -R "$HOST_UID:0" "/nix/var/nix/gcroots/per-user/$HOST_USER" 2>/dev/null || true

    # Link nix profile to container home
    ln -sf "/nix/var/nix/profiles/per-user/$HOST_USER" "$CONTAINER_HOME/.nix-profile" 2>/dev/null || true

    # Create .nix-defexpr for nix-shell (points to system channels)
    mkdir -p "$CONTAINER_HOME/.nix-defexpr" 2>/dev/null || true
    ln -sf /nix/var/nix/profiles/per-user/root/channels "$CONTAINER_HOME/.nix-defexpr/channels" 2>/dev/null || true
    chown -R "$HOST_UID:0" "$CONTAINER_HOME/.nix-defexpr" 2>/dev/null || true

    # Run as the non-root user (godmode works because uid != 0)
    # File access works because user is in group 0 (root)
    # Use username (not uid:gid) so gosu loads supplementary groups from /etc/group
    # NIX_USER_PROFILE_DIR bypasses the per-user directory chmod issue
    exec gosu "$HOST_USER" env \
        HOME="$CONTAINER_HOME" \
        PATH="$PATH" \
        NIX_USER_PROFILE_DIR="/nix/var/nix/profiles/per-user/$HOST_USER" \
        "$@"
else
    # Already non-root, just run
    export HOME="${HOME:-/root}"
    exec env HOME="$HOME" PATH="$PATH" "$@"
fi
