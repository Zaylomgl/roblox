#!/usr/bin/env bash
# Crée un jeu de bout en bout : choix d'après les tendances, script de
# construction, tests + validation du pipeline, aperçu en images.
#
# Usage : ./fabrique/nouveau-jeu.sh                    (la Fabrique choisit)
#         ./fabrique/nouveau-jeu.sh --format tour --theme glace --graine 52
#         ./fabrique/nouveau-jeu.sh --photo            (reprend d'abord une photo des classements Roblox)
#         ./fabrique/nouveau-jeu.sh --sans-apercu      (pas d'image : ni Node ni Chromium requis)
# Les autres options sont celles de fabrique/creer.luau (--etapes, --remplacer…).
set -euo pipefail
cd "$(dirname "$0")/.."

photo=0
apercu=1
options=()
for a in "$@"; do
	case "$a" in
	--photo) photo=1 ;;
	--sans-apercu) apercu=0 ;;
	*) options+=("$a") ;;
	esac
done

if [ "$photo" -eq 1 ]; then
	echo "═══ Photo des classements Roblox"
	python3 recherche/niche.py
fi

echo "═══ Création du jeu"
journal="$(mktemp)"
lune run fabrique/creer -- "${options[@]}" | tee "$journal"
nom="$(sed -n 's/^NOM=//p' "$journal")"
rm -f "$journal"
[ -n "$nom" ] || { echo "✖ La Fabrique n'a créé aucun jeu"; exit 1; }

echo "═══ Tests, lint, construction et validation"
./pipeline/run.sh "maps/$nom.lua"

if [ "$apercu" -eq 1 ]; then
	echo "═══ Aperçu en images (rendu approximatif, hors Roblox)"
	./fabrique/apercu/apercu.sh "$nom"
fi

echo "✔ Jeu prêt : maps/$nom.lua · fiche jeux/$nom.md · rapport reports/$nom.md · place build/$nom.rbxl"
