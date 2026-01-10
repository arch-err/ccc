FROM nixos/nix:latest

# Configure nix for flexibility
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "sandbox = false" >> /etc/nix/nix.conf

# Install base tools via nix (git-minimal already in base image)
RUN nix-env -iA nixpkgs.nodejs nixpkgs.tmux

# Create fake UID library for godmode support
# This makes Claude think we're not root while keeping root's file access
RUN mkdir -p /usr/local/lib && \
    echo '#define _GNU_SOURCE' > /tmp/fakeuid.c && \
    echo '#include <sys/types.h>' >> /tmp/fakeuid.c && \
    echo 'uid_t getuid(void) { return 1000; }' >> /tmp/fakeuid.c && \
    echo 'uid_t geteuid(void) { return 1000; }' >> /tmp/fakeuid.c && \
    echo 'gid_t getgid(void) { return 1000; }' >> /tmp/fakeuid.c && \
    echo 'gid_t getegid(void) { return 1000; }' >> /tmp/fakeuid.c && \
    nix-shell -p gcc --run "gcc -shared -fPIC -o /usr/local/lib/libfakeuid.so /tmp/fakeuid.c" && \
    rm /tmp/fakeuid.c

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create stable symlink for claude
RUN mkdir -p /usr/local/bin && \
    ln -s "$(npm config get prefix)/bin/claude" /usr/local/bin/claude

# Nix permissions for container usage:
# - /nix/store: read-only is fine (packages already installed)
# - /nix/var/nix/builds: MUST be 700 (nix security requirement)
# - /nix/var/nix/db: needs write for nix-env database operations
# - profiles/gcroots/per-user: need write for nix-shell -p to create per-user profiles
RUN chmod 700 /nix/var/nix/builds && \
    chmod -R g+rwX /nix/var/nix/db && \
    chmod g+rw /nix/var/nix/gc.lock && \
    chmod -R a+rwX /nix/var/nix/profiles /nix/var/nix/gcroots /nix/var/nix/temproots && \
    chmod a+rwx /nix/var/nix/profiles/per-user /nix/var/nix/gcroots/per-user && \
    chmod a+rx /nix/store

# Setup bashrc for all users
RUN echo '# Claude Code Container Environment' > /etc/bashrc && \
    echo 'export PATH="/usr/local/bin:/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"' >> /etc/bashrc && \
    echo 'export NIX_PROFILES="/nix/var/nix/profiles/default"' >> /etc/bashrc && \
    echo '[ -f /root/.nix-profile/etc/profile.d/nix.sh ] && . /root/.nix-profile/etc/profile.d/nix.sh' >> /etc/bashrc && \
    cp /etc/bashrc /root/.bashrc && \
    cp /etc/bashrc /root/.profile

# Setup default git config to avoid prompts
RUN git config --global user.name "Claude Sandbox" && \
    git config --global user.email "sandbox@localhost" && \
    git config --global init.defaultBranch main

# Set ENV for non-interactive use
ENV PATH="/usr/local/bin:/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
ENV BASH_ENV="/etc/bashrc"
ENV GIT_TERMINAL_PROMPT=0

# Copy entrypoint (world-executable for non-root user support)
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh



ENTRYPOINT ["/entrypoint.sh"]
CMD ["claude"]
