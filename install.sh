#!/bin/bash
# ccc installer - Claude Code Container
# Usage: curl -fsSL https://raw.githubusercontent.com/arch-err/ccc/refs/heads/main/install.sh | bash

set -e

INSTALL_DIR="${HOME}/.local/share/ccc"
REPO_URL="https://github.com/arch-err/ccc.git"

# Colors (if terminal supports it)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}${BOLD}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}${BOLD}[ERROR]${NC} $1" >&2; }

# Check for git
if ! command -v git &>/dev/null; then
    error "git is required but not installed"
    echo ""
    echo "Install git first:"
    echo "  - Debian/Ubuntu: sudo apt install git"
    echo "  - Fedora: sudo dnf install git"
    echo "  - Arch: sudo pacman -S git"
    echo "  - macOS: xcode-select --install"
    exit 1
fi

# Check if already installed
if [[ -d "$INSTALL_DIR" ]]; then
    warn "ccc is already installed at $INSTALL_DIR"
    echo ""
    read -p "Update existing installation? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull --ff-only || {
            error "Failed to update. You may need to manually resolve conflicts."
            exit 1
        }
        success "Repository updated"
    else
        info "Aborting installation"
        exit 0
    fi
else
    # Fresh install
    info "Installing ccc to $INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$REPO_URL" "$INSTALL_DIR" || {
        error "Failed to clone repository"
        exit 1
    }
    success "Repository cloned"
fi

# Run make install
info "Running make install..."
cd "$INSTALL_DIR"
make install || {
    error "make install failed"
    exit 1
}

success "ccc installation complete!"
