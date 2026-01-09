# Troubleshooting Guide

This document explains common issues and their solutions, including the journey to get godmode working with rootless Podman.

## The Godmode + Podman Challenge

Getting `--dangerously-skip-permissions` (godmode) to work with rootless Podman was non-trivial. Here's the full story.

### The Core Problem

Claude Code refuses to run with godmode when `uid == 0`:
```
--dangerously-skip-permissions cannot be used with root/sudo privileges for security reasons
```

In rootless Podman, containers run as root (uid 0) by default. This creates a conflict.

### What We Tried (And Why It Failed)

#### Attempt 1: `--userns=keep-id`

Podman's `--userns=keep-id` maps your host UID to the same UID inside the container:
- Host uid 1000 → Container uid 1000
- Godmode would work (uid != 0)

**Problem**: Extremely slow with complex images. Podman creates "ID-mapped copies" of every layer. With the nix-based image (many layers), this took 2+ minutes and often timed out.

```
Error: creating container storage: creating an ID-mapped copy of layer "...": signal: terminated
```

#### Attempt 2: Run as Root, Use gosu to Switch

Without `--userns=keep-id`:
- Container runs as root (uid 0)
- Root inside = host user outside (rootless podman mapping)
- Use `gosu` to switch to uid 1000 for godmode

**Problem**: File permissions broke. Mounted files appear as `root:root` inside the container. When we switch to uid 1000 via gosu, that user can't access root-owned files.

```
Error: EACCES: permission denied, open '/home/user/.claude.json'
```

Why? In rootless Podman:
- Host uid 1000 → Container uid 0 (root)
- Container uid 1000 → Host subordinate uid (e.g., 100999)

So `gosu 1000` inside the container is NOT the same as your host user.

#### Attempt 3: Create User in Root Group

The insight: files appear as `root:root` (gid 0) inside the container. If we create a user with gid 0 as their primary group, they could access files via group permissions.

```bash
useradd -u 1000 -g 0 -G 0 ...  # Primary group = root (gid 0)
```

**Problem**: Files on host are `rw-------` (600). Even with correct group membership, there are no group permissions to use.

```
-rw------- 1 root root 46812 ... /home/user/.claude.json
```

### The Solution: ACLs

**Access Control Lists (ACLs)** let us add group permissions without changing the base `chmod` permissions.

```bash
# On the host, grant group read/write via ACL
setfacl -R -m g::rwX ~/.claude
setfacl -R -d -m g::rwX ~/.claude  # Default ACL for new files
setfacl -m g::rw ~/.claude.json
```

Now inside the container:
- Files still appear as `root:root`
- But ACL grants group 0 (root) read/write access
- Our user (uid 1000, gid 0) can access via group ACL

### Final Architecture

```
Host                          Container
────                          ─────────
uid 1000 (you)        ───►    uid 0 (root)
gid 1000 (you)        ───►    gid 0 (root)

File: ~/.claude.json
Owner: you:you        ───►    Appears as: root:root
Perms: rw-------              Perms: rw------- (but ACL grants g::rw)

Container user:
uid 1000, gid 0 (root group)
→ Not root (uid != 0) → godmode works
→ In root group → ACL grants file access
```

## Common Issues

### "Invalid API key" or "Please run /login"

Claude can't find credentials. Check:

1. ACLs are set on `~/.claude`:
   ```bash
   getfacl ~/.claude/.credentials.json
   # Should show: group::rw-
   ```

2. If not, set them:
   ```bash
   setfacl -R -m g::rwX ~/.claude
   setfacl -m g::rw ~/.claude.json
   ```

### "EACCES: permission denied"

File access issue inside container.

1. Check which file is failing (in the error message)
2. Set ACL on that file:
   ```bash
   setfacl -m g::rw /path/to/file
   ```
3. For directories, also set the default ACL:
   ```bash
   setfacl -d -m g::rwX /path/to/directory
   ```

### "--dangerously-skip-permissions cannot be used with root"

The container is running as root. This happens when:

1. Using Docker rootless (not supported for godmode)
2. The `--user` flag isn't being passed to `exec`

Check your runtime:
```bash
./ccc list  # Shows runtime in output
```

For Podman, ensure the exec includes `--user`:
```bash
podman exec --user "$(id -u):0" container-name ...
```

### Container Hangs on Start

If using `--userns=keep-id`, it may be creating ID-mapped layer copies. This is slow for images with many layers.

**Solution**: Don't use `--userns=keep-id`. The current ccc implementation avoids this.

### "setfacl: Operation not permitted"

Some files can't have ACLs set, usually because:
- They're owned by another user/process
- The filesystem doesn't support ACLs

For files owned by another Claude session, you can usually ignore these errors - the important files (credentials, config) should work.

### New Files Don't Have Correct Permissions

When Claude creates new files in `~/.claude`, they need ACL inheritance.

Set default ACLs:
```bash
setfacl -R -d -m g::rwX ~/.claude
```

The `-d` flag sets a default ACL that new files inherit.

## Verifying Your Setup

### Check ACLs
```bash
# Files should show "group::rw-" in ACL
getfacl ~/.claude.json
getfacl ~/.claude/.credentials.json
```

### Check Container User
```bash
# Should show uid=1000 gid=0(root)
podman exec --user "$(id -u):0" <container> id
```

### Check File Access in Container
```bash
# Should succeed
podman exec --user "$(id -u):0" <container> cat /home/you/.claude.json | head -1
```

### Check Godmode Works
```bash
# Should NOT show "cannot be used with root" error
./ccc new -g -p "echo test"
```

## Runtime Comparison

| Feature | Podman (rootless) | Docker (rootful) | Docker (rootless) |
|---------|-------------------|------------------|-------------------|
| Godmode | Yes (with ACLs) | Yes | No |
| Setup | ACLs required | None | N/A |
| File ownership | Via ACL group | Via UID matching | Root only |
| Security | Best | Good | Good (no godmode) |

## Nix Package Installation

`nix-shell -p <package>` **works** inside the container! You can install packages on-the-fly:

```bash
# Example: Install and use cowsay
nix-shell -p cowsay --run "cowsay hello"

# Example: Install python and run a script
nix-shell -p python3 --run "python3 script.py"

# Example: Multiple packages
nix-shell -p python3 nodejs --run "node -v && python3 --version"
```

**Pre-installed packages** (always available without nix-shell):
- nodejs, npm
- tmux
- git

**How it works**: The entrypoint sets up nix profiles and permissions for the non-root user, allowing nix-shell to download and use packages from the nix cache.

## Still Having Issues?

1. Check container logs: `./ccc logs -n <name>`
2. Shell into container: `./ccc exec -n <name>`
3. Verify environment: `./ccc exec -n <name> -- env | grep CLAUDE`
