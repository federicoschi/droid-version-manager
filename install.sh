#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${DVM_INSTALL_DIR:-$HOME/.local/bin}"
REPO_URL="https://raw.githubusercontent.com/$(git -C "$(dirname "$0")" remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]||;s|\.git$||' || echo 'user/droid-version-manager')/main/dvm"

main() {
  local src
  src="$(cd "$(dirname "$0")" && pwd)/dvm"

  if [[ ! -f "$src" ]]; then
    echo "error: dvm script not found at $src" >&2
    exit 1
  fi

  mkdir -p "$INSTALL_DIR"
  cp "$src" "$INSTALL_DIR/dvm"
  chmod +x "$INSTALL_DIR/dvm"

  echo "Installed dvm to $INSTALL_DIR/dvm"

  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    echo ""
    echo "Add this to your shell profile (~/.zshrc or ~/.bashrc):"
    echo ""
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
  else
    echo "dvm is ready — run 'dvm help' to get started."
  fi
}

main "$@"
