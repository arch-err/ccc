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

.PHONY: build run debug shell push clean install uninstall help

## build: Build the container image (uses podman if available, else docker)
build:
	$(RUNTIME) build -t $(IMAGE_NAME):$(VERSION) .

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

## install: Install ccc CLI to ~/.local/bin and config to ~/.config/ccc
install:
	@mkdir -p $(HOME)/.local/bin
	@ln -sf $(shell pwd)/ccc $(HOME)/.local/bin/ccc
	@echo "Installed ccc to ~/.local/bin/ccc"
	@mkdir -p $${XDG_CONFIG_HOME:-$(HOME)/.config}/ccc
	@if [ ! -f "$${XDG_CONFIG_HOME:-$(HOME)/.config}/ccc/config.yaml" ]; then \
		cp $(shell pwd)/example_config/config.yaml $${XDG_CONFIG_HOME:-$(HOME)/.config}/ccc/config.yaml; \
		echo "Installed default config to $${XDG_CONFIG_HOME:-$(HOME)/.config}/ccc/config.yaml"; \
	else \
		echo "Config already exists at $${XDG_CONFIG_HOME:-$(HOME)/.config}/ccc/config.yaml (not overwritten)"; \
	fi
	@echo "Make sure ~/.local/bin is in your PATH"

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
	@echo "  make build              # Build the image"
	@echo "  make run                # Run claude (from any project dir)"
	@echo "  make debug              # Debug with bash"
	@echo "  make push REGISTRY=ghcr.io/user  # Push to registry"
