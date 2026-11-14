#!/usr/bin/env bash
# Lance tout le pipeline : tests du validateur, lint, construction et validation
# de chaque map de maps/. S'arrête au premier échec (code de sortie ≠ 0).
#
# Usage : ./pipeline/run.sh            (toutes les maps)
#         ./pipeline/run.sh maps/x.lua (une seule map)
set -euo pipefail
cd "$(dirname "$0")/.."

for outil in lune selene stylua; do
	command -v "$outil" >/dev/null || { echo "✖ $outil introuvable (voir pipeline/README.md, section Installation)"; exit 2; }
done

echo "═══ 1/4 Tests du validateur"
lune run pipeline/test

echo "═══ 2/4 Lint et formatage (pipeline + scripts du jeu)"
selene pipeline/ fabrique/creer.luau fabrique/formats.luau fabrique/themes.luau fabrique/lib/ fabrique/apercu/exporter.luau
(cd pipeline/lint && selene ../../src ../reel)
# fabrique/gabarits/ : fragments, vérifiés une fois assemblés dans maps/ (étape 3/4)
# stylua doit être compilé avec la syntaxe Luau (--features luau) : sans elle, il ignore
# en silence les fichiers qui utilisent des chaînes entre accents graves.
if ! printf 'local _x = `a{1}`\n' | stylua --check - >/dev/null 2>&1; then
	echo "✖ stylua ne comprend pas la syntaxe Luau : réinstaller avec « cargo install --locked stylua@2.6.0 --features luau »"
	exit 2
fi
stylua --check pipeline/ src/ fabrique/creer.luau fabrique/formats.luau fabrique/themes.luau fabrique/lib/ fabrique/apercu/exporter.luau

if [ "$#" -gt 0 ]; then maps=("$@"); else maps=(maps/*.lua); fi

echo "═══ 3/4 Lint des scripts de map"
(cd pipeline/lint && selene "${maps[@]/#/../../}")

echo "═══ 4/4 Construction + validation"
echec=0
for map in "${maps[@]}"; do
	nom="$(basename "$map" .lua)"
	lune run pipeline/build "$map" "build/$nom.rbxl" --silencieux --src src
	if ! lune run pipeline/validate "build/$nom.rbxl" reports; then echec=1; fi
	# Lint des scripts embarqués (extraits par le validateur)
	if compgen -G "build/$nom/scripts/*.luau" >/dev/null; then
		(cd pipeline/lint && selene "../../build/$nom/scripts/")
	fi
done

if [ "$echec" -ne 0 ]; then
	echo "✖ Au moins une map a des erreurs : voir reports/*.md"
	exit 1
fi
echo "✔ Pipeline terminé sans erreur. Rapports : reports/*.md"
