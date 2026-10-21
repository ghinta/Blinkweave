#!/usr/bin/env bash
# Strict Luau type check of src/ against the Roblox API definitions.
# Needs rojo + luau-lsp on PATH and globalTypes.d.luau (see scripts/install-tools.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -f globalTypes.d.luau ]; then
	echo "error: globalTypes.d.luau missing; run scripts/install-tools.sh first" >&2
	exit 1
fi

rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze \
	--platform=roblox \
	--definitions=@roblox=globalTypes.d.luau \
	--sourcemap=sourcemap.json \
	--base-luaurc=.luaurc \
	src/
