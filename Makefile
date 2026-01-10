# Claude Code Sandbox Container
# ==============================

IMAGE_NAME := claude-code-sandbox
REGISTRY := # Set your registry here (e.g., ghcr.io/username)
VERSION := latest

# Host context (used for run/debug)
HOST_PATH := $(shell pwd)
HOST_HOME := $(HOME)
TMUX_SOCKET := /tmp/tmux-$(shell id -u)

# Auto-detect container runtime (prefer podman)
RUNTIME := $(shell command -v podman 2>/dev/null || echo docker)

.PHONY: build build-podman build-docker transfer run debug shell push clean install uninstall help

## build: Build the container image (uses podman if available, else docker)
build:
	$(RUNTIME) build -t $(IMAGE_NAME):$(VERSION) .

## build-podman: Build the container image with podman
build-podman:
	podman build -t $(IMAGE_NAME):$(VERSION) .

## build-docker: Build the container image with docker
build-docker:
	docker build -t $(IMAGE_NAME):$(VERSION) .

## transfer: Transfer image from podman to docker (podman save | docker load)
transfer:
	podman save $(IMAGE_NAME):$(VERSION) | docker load

## run: Run claude in the container (use from project directory)
run:
	docker run -it --rm \
		--name "claude-session-$$$$" \
		--hostname "claude-sandbox" \
		-e "CLAUDE_HOST_PATH=$(HOST_PATH)" \
		-e "CLAUDE_HOST_HOME=$(HOST_HOME)" \
		-e "TERM=$(TERM)" \
		-v "$(HOST_PATH):$(HOST_PATH)" \
		-v "$(HOST_HOME)/.claude:$(HOST_HOME)/.claude" \
		-v "$(HOST_HOME)/.claude.json:$(HOST_HOME)/.claude.json" \
		-v "$(TMUX_SOCKET):$(TMUX_SOCKET):rw" \
		--network host \
		$(IMAGE_NAME):$(VERSION)

## debug: Run container with bash for debugging
debug:
	docker run -it --rm \
		--name "claude-debug-$$$$" \
		--hostname "claude-sandbox" \
		-e "CLAUDE_HOST_PATH=$(HOST_PATH)" \
		-e "CLAUDE_HOST_HOME=$(HOST_HOME)" \
		-e "TERM=$(TERM)" \
		-v "$(HOST_PATH):$(HOST_PATH)" \
		-v "$(HOST_HOME)/.claude:$(HOST_HOME)/.claude" \
		-v "$(HOST_HOME)/.claude.json:$(HOST_HOME)/.claude.json" \
		-v "$(TMUX_SOCKET):$(TMUX_SOCKET):rw" \
		--network host \
		--entrypoint sh \
		$(IMAGE_NAME):$(VERSION)

## shell: Run an interactive shell in the container
shell:
	docker run -it --rm \
		--name "claude-shell-$$$$" \
		--hostname "claude-sandbox" \
		-e "CLAUDE_HOST_PATH=$(HOST_PATH)" \
		-e "CLAUDE_HOST_HOME=$(HOST_HOME)" \
		-e "TERM=$(TERM)" \
		-v "$(HOST_PATH):$(HOST_PATH)" \
		-v "$(HOST_HOME)/.claude:$(HOST_HOME)/.claude" \
		-v "$(HOST_HOME)/.claude.json:$(HOST_HOME)/.claude.json" \
		-v "$(TMUX_SOCKET):$(TMUX_SOCKET):rw" \
		--network host \
		$(IMAGE_NAME):$(VERSION) sh

## push: Push image to registry (set REGISTRY variable first)
push:
ifndef REGISTRY
	$(error REGISTRY is not set. Use: make push REGISTRY=ghcr.io/username)
endif
	docker tag $(IMAGE_NAME):$(VERSION) $(REGISTRY)/$(IMAGE_NAME):$(VERSION)
	docker push $(REGISTRY)/$(IMAGE_NAME):$(VERSION)

## clean: Remove the local image
clean:
	docker rmi $(IMAGE_NAME):$(VERSION) 2>/dev/null || true

## install: Install ccc CLI with dependency checks and runtime selection
install:
	@bash -c '\
	set -e; \
	\
	# Pretty printing functions \
	if command -v gum &>/dev/null; then \
		info() { gum style --foreground 4 "$$1"; }; \
		success() { gum style --foreground 2 --bold "$$1"; }; \
		warn() { gum style --foreground 3 "$$1"; }; \
		error() { gum style --foreground 1 --bold "$$1"; }; \
		HAS_GUM=true; \
	else \
		info() { echo "[INFO] $$1"; }; \
		success() { echo "[OK] $$1"; }; \
		warn() { echo "[WARN] $$1"; }; \
		error() { echo "[ERROR] $$1" >&2; }; \
		HAS_GUM=false; \
	fi; \
	\
	echo ""; \
	info "ccc - Claude Code Container Installer"; \
	echo ""; \
	\
	# Check for Claude Code (required) \
	if ! command -v claude &>/dev/null; then \
		error "Claude Code is required but not installed"; \
		echo ""; \
		echo "Install Claude Code first:"; \
		echo "  https://docs.anthropic.com/en/docs/claude-code"; \
		echo ""; \
		exit 1; \
	fi; \
	success "Claude Code found"; \
	\
	# Check for container runtimes \
	HAS_DOCKER=false; \
	HAS_PODMAN=false; \
	if command -v docker &>/dev/null; then HAS_DOCKER=true; fi; \
	if command -v podman &>/dev/null; then HAS_PODMAN=true; fi; \
	\
	if [[ "$$HAS_DOCKER" == "false" && "$$HAS_PODMAN" == "false" ]]; then \
		error "No container runtime found (docker or podman required)"; \
		echo ""; \
		echo "Install one of:"; \
		echo "  Docker: https://docs.docker.com/get-docker/"; \
		echo "  Podman: https://podman.io/getting-started/installation"; \
		echo ""; \
		exit 1; \
	fi; \
	\
	# Select runtime \
	SELECTED_BACKEND=""; \
	if [[ "$$HAS_DOCKER" == "true" && "$$HAS_PODMAN" == "true" ]]; then \
		info "Both Docker and Podman are available"; \
		if [[ -t 0 ]]; then \
			if [[ "$$HAS_GUM" == "true" ]]; then \
				SELECTED_BACKEND=$$(gum choose --header "Select container runtime:" "podman" "docker"); \
			else \
				echo "Select container runtime:"; \
				echo "  1) podman"; \
				echo "  2) docker"; \
				read -p "Choice [1/2]: " choice; \
				case "$$choice" in \
					2) SELECTED_BACKEND="docker" ;; \
					*) SELECTED_BACKEND="podman" ;; \
				esac; \
			fi; \
		else \
			SELECTED_BACKEND="podman"; \
			info "No TTY available, defaulting to podman"; \
		fi; \
	elif [[ "$$HAS_PODMAN" == "true" ]]; then \
		SELECTED_BACKEND="podman"; \
	else \
		SELECTED_BACKEND="docker"; \
	fi; \
	success "Using $$SELECTED_BACKEND as container runtime"; \
	\
	# Check for gum (optional) \
	if [[ "$$HAS_GUM" == "false" ]]; then \
		warn "gum not found (optional, but recommended for better UI)"; \
		echo "  Install: https://github.com/charmbracelet/gum"; \
	else \
		success "gum found"; \
	fi; \
	\
	echo ""; \
	info "Installing ccc..."; \
	\
	# Create symlink \
	mkdir -p $(HOME)/.local/bin; \
	ln -sf "$(shell pwd)/ccc" "$(HOME)/.local/bin/ccc"; \
	success "Symlink created: ~/.local/bin/ccc"; \
	\
	# Setup config \
	CONFIG_DIR="$${XDG_CONFIG_HOME:-$(HOME)/.config}/ccc"; \
	mkdir -p "$$CONFIG_DIR"; \
	if [ ! -f "$$CONFIG_DIR/config.yaml" ]; then \
		sed "s/^backend:.*/backend: $$SELECTED_BACKEND/" "$(shell pwd)/example_config/config.yaml" > "$$CONFIG_DIR/config.yaml"; \
		success "Config created with backend: $$SELECTED_BACKEND"; \
	else \
		info "Config exists (not overwritten)"; \
		if grep -q "^backend:" "$$CONFIG_DIR/config.yaml"; then \
			sed -i "s/^backend:.*/backend: $$SELECTED_BACKEND/" "$$CONFIG_DIR/config.yaml"; \
			success "Updated backend to: $$SELECTED_BACKEND"; \
		fi; \
	fi; \
	\
	echo ""; \
	success "Installation complete!"; \
	echo ""; \
	\
	# PATH check \
	if ! echo "$$PATH" | grep -q "$(HOME)/.local/bin"; then \
		warn "~/.local/bin is not in your PATH"; \
		echo "  Add this to your shell profile:"; \
		echo "    export PATH=\"\$$HOME/.local/bin:\$$PATH\""; \
		echo ""; \
	fi; \
	\
	echo "Next steps:"; \
	echo "  1. Pull the container image:"; \
	echo "     $$SELECTED_BACKEND pull ghcr.io/arch-err/ccc:latest"; \
	echo ""; \
	echo "  2. Start using ccc:"; \
	echo "     ccc new -ig                  # Interactive with godmode"; \
	echo "     ccc new -gp \"your prompt\"    # Run a prompt"; \
	echo ""; \
	'

## uninstall: Remove ccc CLI from ~/.local/bin
uninstall:
	@rm -f $(HOME)/.local/bin/ccc
	@echo "Removed ccc from ~/.local/bin"

## logs: Show build logs (useful after failed build)
logs:
	docker logs claude-session-$$$$ 2>/dev/null || echo "No running container found"

## help: Show this help
help:
	@echo "Claude Code Container"
	@echo "=============================="
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "Examples:"
	@echo "  make build              # Build with auto-detected runtime"
	@echo "  make build-podman       # Build with podman"
	@echo "  make build-docker       # Build with docker"
	@echo "  make transfer           # Copy image from podman to docker"
	@echo "  make run                # Run claude (from any project dir)"
	@echo "  make debug              # Debug with bash"
	@echo "  make push REGISTRY=ghcr.io/user  # Push to registry"
