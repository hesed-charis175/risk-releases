#!/usr/bin/env bash
set -e

REPO="hesed-charis175/risk-releases"   
VERSION="latest"
BINARY_NAME="riskc"
INSTALL_DIR="/usr/local/bin"
STDLIB_DIR="$HOME/.risk/lib"

BOLD="\033[1m"
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

info()    { echo -e "${BOLD}[~]${RESET} $1"; }
success() { echo -e "${GREEN}[=]${RESET} $1"; }
error()   { echo -e "${RED}[X]${RESET} $1"; exit 1; }

ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
  error "Unsupported architecture: $ARCH. Only x86_64 is supported right now."
fi

BASE_URL="https://github.com/$REPO/releases/latest/download"
BINARY_URL="$BASE_URL/riskc-linux-x86_64.tar.gz"
STDLIB_URL="$BASE_URL/risk-stdlib.tar.gz"

info "Downloading riskc..."
TMP_DIR=$(mktemp -d)
curl -fsSL "$BINARY_URL" -o "$TMP_DIR/riskc.tar.gz" \
  || error "Failed to download binary. Check your connection or the release URL."

tar -xzf "$TMP_DIR/riskc.tar.gz" -C "$TMP_DIR"
chmod +x "$TMP_DIR/riskc"

info "Installing to $INSTALL_DIR/$BINARY_NAME (requires sudo)..."
SUDO=""
if [ "$(id -u)" != "0" ]; then SUDO="sudo"; fi

$SUDO mv "$TMP_DIR/riskc" "$INSTALL_DIR/$BINARY_NAME" \
  || error "Failed to install binary. Do you have sudo access?"
rm -rf "$TMP_DIR"

success "riskc installed to $INSTALL_DIR/$BINARY_NAME"

info "Installing standard library to $STDLIB_DIR..."
mkdir -p "$STDLIB_DIR"

TMP_STD=$(mktemp -d)
curl -fsSL "$STDLIB_URL" -o "$TMP_STD/stdlib.tar.gz" \
  || error "Failed to download standard library."

tar -xzf "$TMP_STD/stdlib.tar.gz" -C "$STDLIB_DIR" --strip-components=1
rm -rf "$TMP_STD"

success "Standard library installed to $STDLIB_DIR"

info "Compiling standard library..."
MANIFEST="$STDLIB_DIR/manifest"
if [ ! -f "$MANIFEST" ]; then
  error "Stdlib manifest not found at $MANIFEST"
fi

while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  TARGET="$STDLIB_DIR/$line"
  if [ ! -f "$TARGET" ]; then
    info "Warning: $TARGET not found, skipping"
    continue
  fi
  info "  compiling $line..."
  RISK_STDLIB="$STDLIB_DIR" riskc "$TARGET" || error "Failed to compile $line"
done < "$MANIFEST"

success "Standard library compiled"

# Set RISK_STDLIB system-wide
if ! grep -qF "RISK_STDLIB" /etc/environment 2>/dev/null; then
  echo "RISK_STDLIB=$STDLIB_DIR" | $SUDO tee -a /etc/environment > /dev/null
  info "RISK_STDLIB set in /etc/environment"
fi

export RISK_STDLIB="$STDLIB_DIR"

if command -v riskc &>/dev/null; then
  success "riskc is ready. Docs: https://risk-releases.pages.dev"
else
  echo ""
  info "riskc was installed but is not in your PATH."
  info "Add this to your shell config (~/.bashrc or ~/.zshrc):"
  echo ""
  echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
  echo ""
fi
