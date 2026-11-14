#!/usr/bin/env bash
# Planche d'aperçu d'un jeu déjà construit (build/<nom>.rbxl) → jeux/apercus/<nom>.jpg
# Usage : ./fabrique/apercu/apercu.sh <nom> [<nom>…]
# Demande Node.js, `npm install` dans fabrique/apercu/ et le Chromium de Playwright.
set -euo pipefail
cd "$(dirname "$0")/../.."
[ -d fabrique/apercu/node_modules/three ] || (cd fabrique/apercu && npm install --no-audit --no-fund)
(cd fabrique/apercu && node -e "require('playwright')" 2>/dev/null) || {
	echo "✖ Playwright introuvable : dans fabrique/apercu/, lancer « npm install --no-save playwright » puis « npx playwright install chromium »"
	exit 2
}
for nom in "$@"; do
	lune run fabrique/apercu/exporter "build/$nom.rbxl" "build/$nom/scene.json"
	node fabrique/apercu/rendre.mjs "build/$nom/scene.json" "jeux/apercus/$nom.jpg"
done
