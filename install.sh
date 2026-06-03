#!/usr/bin/env bash
set -e

# ── rtsp-ndi installer ────────────────────────────────────────────────────────
# Installs rtsp-ndi and all dependencies, working around the broken
# Homebrew Python on macOS 26 (Tahoe) by using pyenv when necessary.

PYTHON_VERSION="3.12.10"
PACKAGE="rtsp-ndi"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}==>${NC} $1"; }
warn()    { echo -e "${YELLOW}Warning:${NC} $1"; }
die()     { echo -e "${RED}Error:${NC} $1"; exit 1; }

# ── check for Homebrew ────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    die "Homebrew is required. Install it first:\n  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
fi

# ── check for FFmpeg ──────────────────────────────────────────────────────────
if ! command -v ffmpeg &>/dev/null; then
    info "Installing FFmpeg..."
    brew install ffmpeg
else
    info "FFmpeg already installed."
fi

# ── find a working Python 3.12 ────────────────────────────────────────────────
find_working_python() {
    for py in \
        "$HOME/.pyenv/versions/$PYTHON_VERSION/bin/python3.12" \
        "$(brew --prefix python@3.12 2>/dev/null)/bin/python3.12" \
        "$(command -v python3.12 2>/dev/null)"; do
        if [[ -x "$py" ]] && "$py" -c "import xml.parsers.expat" &>/dev/null; then
            echo "$py"
            return 0
        fi
    done
    return 1
}

PYTHON=$(find_working_python || true)

if [[ -z "$PYTHON" ]]; then
    warn "Homebrew Python 3.12 is incompatible with this macOS version. Installing via pyenv..."

    if ! command -v pyenv &>/dev/null; then
        info "Installing pyenv..."
        brew install pyenv
    fi

    if [[ ! -d "$HOME/.pyenv/versions/$PYTHON_VERSION" ]]; then
        info "Installing Python $PYTHON_VERSION via pyenv..."
        pyenv install "$PYTHON_VERSION"
    else
        info "Python $PYTHON_VERSION already installed via pyenv."
    fi

    PYTHON="$HOME/.pyenv/versions/$PYTHON_VERSION/bin/python3.12"
fi

info "Using Python: $PYTHON ($($PYTHON --version))"

# ── install pipx via the working Python ──────────────────────────────────────
PIPX="$($PYTHON -c 'import sys; print(sys.prefix)')/bin/pipx"

if [[ ! -x "$PIPX" ]]; then
    info "Installing pipx..."
    "$PYTHON" -m pip install --quiet pipx
fi

# ── install or upgrade rtsp-ndi ───────────────────────────────────────────────
if "$PIPX" list 2>/dev/null | grep -q "$PACKAGE"; then
    info "Upgrading $PACKAGE..."
    "$PIPX" upgrade "$PACKAGE"
else
    info "Installing $PACKAGE..."
    "$PYTHON" -m pipx install "$PACKAGE"
fi

# ── ensure ~/.local/bin is on PATH ────────────────────────────────────────────
LOCAL_BIN="$HOME/.local/bin"
SHELL_RC=""

if [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]] && ! grep -q "$LOCAL_BIN" "$SHELL_RC" 2>/dev/null; then
    echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >> "$SHELL_RC"
    info "Added $LOCAL_BIN to PATH in $SHELL_RC"
fi

export PATH="$LOCAL_BIN:$PATH"

# ── done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo "Usage:"
echo "  rtsp-to-ndi --url 'rtsp://user:password@camera-ip/stream' --name 'My Camera'"
echo ""
echo "If rtsp-to-ndi is not found, restart your terminal or run:"
echo "  export PATH=\"$LOCAL_BIN:\$PATH\""
