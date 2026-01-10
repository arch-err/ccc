# Advanced Isolation

`ccc` provides multiple layers of isolation for security-conscious users who want to run Claude Code in highly controlled environments.

## Clean Sessions (`-c/--clean`)

Create ephemeral workspaces that don't clutter your projects:

```bash
# Temporary project directory in /tmp/ccc/tmpXXXXXX
ccc new -igc

# Great for one-off experiments
ccc new -gc -p "create a test script"
```

The directory is created automatically and shown in `ccc list`. Useful for throwaway experiments without leaving traces in your home directory.

## Anonymous Mode (`-a/--anonymous`)

Run Claude without mounting your credentials or configuration:

```bash
# No ~/.claude or ~/.claude.json mounted
ccc new -iga

# Requires re-authentication inside the container
# No access to your conversation history or custom commands
```

This creates a completely fresh Claude environment with no connection to your identity.

## Network Isolation (`--network`)

Override the default host networking for complete network control:

```bash
# Use a custom Docker/Podman network
ccc new -ig --network my-isolated-net

# Combine with other isolation flags
ccc new -igca --network air-gapped-net
```

## Maximum Isolation

For the most secure setup, combine all isolation features:

```bash
ccc new -igca --network isolated-net
```

This creates:

- **Clean workspace**: Temporary directory, no project file access
- **Anonymous session**: No credentials or history
- **Network isolated**: Custom network with controlled egress

## Example: Isolated Network Setup

Create a network that only allows access to Claude's API:

```bash
# Create isolated network (Docker)
docker network create \
  --driver bridge \
  --subnet 172.30.0.0/24 \
  claude-isolated

# Add firewall rules (iptables example)
# Allow only api.anthropic.com (resolve IPs first)
iptables -I DOCKER-USER -s 172.30.0.0/24 -d api.anthropic.com -j ACCEPT
iptables -I DOCKER-USER -s 172.30.0.0/24 -j DROP

# Run fully isolated session
ccc new -igca --network claude-isolated
```

This gives you a Claude session that:

- Cannot access your local files
- Cannot access your credentials
- Can only reach Anthropic's API
- Leaves no traces after cleanup

Perfect for running untrusted code generation or sensitive experiments.
