#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${1:-${SWIFTBAR_PLUGIN_DIR:-$HOME/SwiftBar}}"
PLUGIN_NAME="dev-servers.10s.sh"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install it from https://brew.sh and re-run."
  exit 1
fi

if ! mdfind "kMDItemCFBundleIdentifier == 'com.ameba.SwiftBar'" 2>/dev/null | grep -q .; then
  brew tap melonamin/formulae >/dev/null
  brew install swiftbar
fi

mkdir -p "$PLUGIN_DIR"

if [[ ! -f "$ROOT_DIR/$PLUGIN_NAME" ]]; then
  echo "Missing $PLUGIN_NAME in repo root."
  exit 1
fi

install -m 0755 "$ROOT_DIR/$PLUGIN_NAME" "$PLUGIN_DIR/$PLUGIN_NAME"

open -a SwiftBar >/dev/null 2>&1 || true

cat <<EOF

Installed:
  $PLUGIN_DIR/$PLUGIN_NAME

If this is your first time:
  SwiftBar -> Preferences -> Plugin Folder -> set to:
  $PLUGIN_DIR

EOF
