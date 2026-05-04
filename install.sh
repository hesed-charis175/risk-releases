#!/usr/bin/env bash
set -e

REPO="hesed-charis175/risk-releases"   # TODO: change this
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
BINARY_URL="$BASE_URL/riskc-linux-x86_64"
STDLIB_URL="$BASE_URL/risk-stdlib.tar.gz"

info "Downloading riskc..."
TMP_BIN=$(mktemp)
curl -fsSL "$BINARY_URL" -o "$TMP_BIN" \
  || error "Failed to download binary. Check your connection or the release URL."

chmod +x "$TMP_BIN"

info "Installing to $INSTALL_DIR/$BINARY_NAME (requires sudo)..."
sudo mv "$TMP_BIN" "$INSTALL_DIR/$BINARY_NAME" \
  || error "Failed to install binary. Do you have sudo access?"

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
  riskc "$TARGET" || error "Failed to compile $line"
done < "$MANIFEST"

success "Standard library compiled"

if command -v riskc &>/dev/null; then
  success "riskc is ready. Run: riskc --version"
else
  echo ""
  info "riskc was installed but is not in your PATH."
  info "Add this to your shell config (~/.bashrc or ~/.zshrc):"
  echo ""
  echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
  echo ""
fi
