# Troubleshooting

Common issues and their solutions.

## The Godmode + Podman Challenge

Getting `--dangerously-skip-permissions` (godmode) to work with rootless Podman was non-trivial. Here's the full story.

### The Core Problem

Claude Code refuses to run with godmode when `uid == 0`:

```
--dangerously-skip-permissions cannot be used with root/sudo privileges for security reasons
```

In rootless Podman, containers run as root (uid 0) by default. This creates a conflict:

- We need uid 0 (root) for file access (mounted files appear as root:root)
- Claude refuses godmode when uid == 0

### What We Tried (And Why It Failed)

#### Attempt 1: `--userns=keep-id`

Podman's `--userns=keep-id` maps your host UID to the same UID inside the container. Godmode would work (uid != 0).

**Problem**: Extremely slow with complex images. Podman creates "ID-mapped copies" of every layer. With the nix-based image, this took 2+ minutes and often timed out.

#### Attempt 2: User Switching with gosu

Run as root, then use `gosu` to switch to uid 1000 for Claude.

**Problem**: File permissions broke. Mounted files appear as `root:root` inside the container. When we switch to uid 1000, that user can't read root-owned files.

#### Attempt 3: ACLs for Group Access

Create a user in root group (gid 0), then use ACLs on host files to grant group access.

**Problem**: Requires setting ACLs on every project directory. Not sustainable.

### The Solution: LD_PRELOAD

The elegant solution: **fake the UID**.

We created a tiny shared library that intercepts `getuid()`, `geteuid()`, `getgid()`, and `getegid()` syscalls and returns 1000 instead of 0.

```c
// libfakeuid.so
uid_t getuid(void) { return 1000; }
uid_t geteuid(void) { return 1000; }
gid_t getgid(void) { return 1000; }
gid_t getegid(void) { return 1000; }
```

The entrypoint sets `LD_PRELOAD=/usr/local/lib/libfakeuid.so`, so:

- **Actual user**: root (uid 0) - has full file access
- **Perceived user**: uid 1000 - Claude accepts godmode

### Final Architecture

```
Container Reality                    What Claude Sees
──────────────────                   ────────────────
uid=0 (root)           ──►           uid=1000
Full file access       ──►           "Not root, godmode OK!"

Mounted files:
/home/user/project     ──►           Readable/writable (we're root)
/home/user/.claude     ──►           Readable/writable (we're root)
```

## Common Issues

### "Invalid API key" or "Please run /login"

Claude can't find credentials. Check that `~/.claude` directory exists and contains `.credentials.json`:

```bash
ls -la ~/.claude/.credentials.json
```

If missing, run `claude` on your host first to authenticate.

### Container Hangs on Start

If you accidentally use `--userns=keep-id`, it will be slow. The current ccc implementation avoids this, but if you're debugging:

```bash
# This is SLOW - don't use it
podman run --userns=keep-id ...

# This is FAST - what ccc uses
podman run ...  # runs as root, LD_PRELOAD fakes UID
```

### Claude Shows Wrong UID

If `id` inside the container shows uid=0 instead of uid=1000, LD_PRELOAD isn't working.

Check:

```bash
podman exec <container> sh -c 'echo $LD_PRELOAD'
# Should show: /usr/local/lib/libfakeuid.so

podman exec <container> ls -la /usr/local/lib/libfakeuid.so
# Should exist
```

If missing, rebuild the container image:

```bash
podman build --no-cache -t claude-code-sandbox:latest .
```

### nix-shell Not Working

`nix-shell -p <package>` should work inside the container. If it fails:

1. Check you're running as root (which has nix access):
   ```bash
   podman exec <container> whoami  # Should show "root" (real uid)
   ```

2. Try a simple package:
   ```bash
   podman exec <container> nix-shell -p hello --run "hello"
   ```

## Runtime Comparison

| Feature | Podman (rootless) | Docker (rootful) | Docker (rootless) |
|---------|-------------------|------------------|-------------------|
| Godmode | Yes | Yes | Yes |
| Setup | None | None | None |
| File access | Via root + LD_PRELOAD | Via root + LD_PRELOAD | Via root + LD_PRELOAD |

All runtimes now work the same way thanks to the LD_PRELOAD approach.

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

## Verifying Your Setup

### Check UID Faking Works

```bash
# Inside container, should show uid=1000
podman exec <container> id
```

### Check File Access

```bash
# Should succeed (we're actually root)
podman exec <container> cat /home/you/.claude.json | head -1
```

### Check Godmode Works

```bash
# Should NOT show "cannot be used with root" error
./ccc new -g -p "echo test"
```

## Still Having Issues?

1. Check container logs: `./ccc logs -n <name>`
2. Shell into container: `./ccc exec -n <name>`
3. Verify environment: `./ccc exec -n <name> -- env | grep -E "(LD_PRELOAD|HOME)"`
4. Rebuild image: `podman build --no-cache -t claude-code-sandbox:latest .`
