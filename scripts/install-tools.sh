#!/usr/bin/env bash
# Installs the tool versions pinned in rokit.toml (Linux x86_64) without Rokit.
# Used by CI; locally prefer `rokit install`.
#
# Usage: scripts/install-tools.sh [target-bin-dir]   (default: .tools/bin)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${1:-$ROOT/.tools/bin}"
mkdir -p "$BIN"

version() {
	local found
	found="$(sed -nE "s/^$1 = \"[^@]+@([^\"]+)\"$/\1/p" "$ROOT/rokit.toml")"
	if [ -z "$found" ]; then
		echo "error: $1 is not pinned in rokit.toml" >&2
		exit 1
	fi
	echo "$found"
}

fetch_zip() {
	local tmp
	tmp="$(mktemp -d)"
	curl -fsSL --retry 3 -o "$tmp/tool.zip" "$1"
	unzip -o -q "$tmp/tool.zip" -d "$BIN"
	rm -rf "$tmp"
}

ROJO="$(version rojo)"
LUNE="$(version lune)"
SELENE="$(version selene)"
STYLUA="$(version stylua)"
LUAU_LSP="$(version luau-lsp)"

fetch_zip "https://github.com/rojo-rbx/rojo/releases/download/v$ROJO/rojo-$ROJO-linux-x86_64.zip"
fetch_zip "https://github.com/lune-org/lune/releases/download/v$LUNE/lune-$LUNE-linux-x86_64.zip"
fetch_zip "https://github.com/Kampfkarren/selene/releases/download/$SELENE/selene-$SELENE-linux.zip"
fetch_zip "https://github.com/JohnnyMorganz/StyLua/releases/download/v$STYLUA/stylua-linux-x86_64.zip"
fetch_zip "https://github.com/JohnnyMorganz/luau-lsp/releases/download/$LUAU_LSP/luau-lsp-linux-x86_64.zip"
chmod +x "$BIN"/*

# Roblox API type definitions matching the pinned luau-lsp release.
curl -fsSL --retry 3 -o "$ROOT/globalTypes.d.luau" \
	"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$LUAU_LSP/scripts/globalTypes.d.luau"

echo "Installed rojo $ROJO, lune $LUNE, selene $SELENE, stylua $STYLUA, luau-lsp $LUAU_LSP into $BIN"
