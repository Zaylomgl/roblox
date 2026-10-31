--[[
	Valide une place Roblox (.rbxl) et produit un rapport.

	Usage : lune run pipeline/validate <place.rbxl> [dossier-rapport]

	Sorties (dans dossier-rapport, par défaut reports/) :
	- <nom>.json : rapport complet lisible par machine (pour la boucle d'amélioration)
	- <nom>.md   : le même rapport en français, lisible par un humain
	- build/<nom>/scripts/*.luau : sources des scripts embarqués (pour le linter)

	Code de sortie : 1 s'il y a au moins une ERREUR, 0 sinon.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local analyse = require("./lib/analyse")

local cheminPlace = process.args[1]
if not cheminPlace then
	print("Usage : lune run pipeline/validate <place.rbxl> [dossier-rapport]")
	process.exit(2)
end
local dossierRapport = process.args[2] or "reports"
local nom = string.match(cheminPlace, "([^/\\]+)%.rbxl$") or "place"

local game = roblox.deserializePlace(fs.readFile(cheminPlace))
local rapport, sourcesScripts = analyse.analyser(game, nom)
rapport.fichier = cheminPlace
local problemes, compte, stats = rapport.problemes, rapport.resume, rapport.statistiques

-- Sources des scripts embarqués, pour le linter (selene).
local dossierScripts = `build/{nom}/scripts`
if fs.isDir(dossierScripts) then
	fs.removeDir(dossierScripts)
end
fs.writeDir(dossierScripts)
for _, sc in sourcesScripts do
	fs.writeFile(`{dossierScripts}/{string.gsub(sc.chemin, "[^%w%._-]", "_")}.luau`, sc.source)
end

if not fs.isDir(dossierRapport) then
	fs.writeDir(dossierRapport)
end
fs.writeFile(`{dossierRapport}/{nom}.json`, serde.encode("json", rapport, true))

local md = {}
local function ajouter(ligne: string)
	table.insert(md, ligne)
end
local icones = { erreur = "❌", avertissement = "⚠️", info = "ℹ️" }
ajouter(`# Rapport de validation — {nom}`)
ajouter("")
ajouter(`**Statut : {if rapport.statut == "OK" then "✅ OK" else "❌ À corriger"}** — {compte.erreur} erreur(s), {compte.avertissement} avertissement(s), {compte.info} info(s).`)
ajouter("")
ajouter("## Chiffres clés")
ajouter("")
ajouter("| Mesure | Valeur |")
ajouter("|---|---|")
ajouter(`| Pièces | {stats.pieces} (dont {stats.piecesNonAncrees} non ancrées) |`)
ajouter(`| Lumières (dont avec ombres) | {stats.lumieres} ({stats.lumieresAvecOmbres}) |`)
ajouter(`| Particules / s | {math.floor(stats.particulesParSeconde)} |`)
ajouter(`| Scripts | {stats.scripts} |`)
ajouter(`| Spawns | {stats.spawns} |`)
ajouter(`| Pads de saut | {stats.padsDeSaut} |`)
if rapport.terrain and rapport.terrain.operations > 0 then
	ajouter(`| Terrain (plan rejoué au démarrage) | {rapport.terrain.operations} opérations, {rapport.terrain.surfacesMarchables} sols marchables |`)
end
local acc = rapport.accessibilite
local services = rapport.systemes
local function ouiNon(b: boolean): string
	return if b then "oui" else "non"
end
ajouter(`| Collectibles accessibles | {acc.collectiblesAccessibles} / {acc.collectiblesTotal} |`)
ajouter(`| Surfaces atteintes depuis le spawn | {acc.surfacesAtteintes} / {acc.surfacesMarchables} |`)
if acc.profondeurMedianeCollectibles then
	ajouter(
		`| Déplacements pour atteindre un collectible (médiane / max) | {acc.profondeurMedianeCollectibles} / {acc.profondeurMaxCollectibles} |`
	)
end
ajouter(`| Saut théorique (hauteur / portée à plat) | {rapport.monde.hauteurSautTheorique} / {rapport.monde.porteeSautAPlat} studs |`)
ajouter(
	`| Sauvegarde (DataStore) / Monétisation (Marketplace) / Badges | {ouiNon(services.DataStoreService)} / {ouiNon(services.MarketplaceService)} / {ouiNon(services.BadgeService)} |`
)
ajouter("")
ajouter("## Problèmes")
ajouter("")
if #problemes == 0 then
	ajouter("Aucun problème détecté.")
end
for _, p in problemes do
	ajouter(`- {icones[p.gravite]} **[{p.categorie}] {p.code}** — {p.message}`)
	if p.objets then
		for i, o in p.objets do
			if i > 10 then
				ajouter(`  - … et {#p.objets - 10} autre(s)`)
				break
			end
			ajouter(`  - \`{o}\``)
		end
	end
end
ajouter("")
ajouter("---")
ajouter("_Rapport généré automatiquement par `pipeline/validate.luau`. L'accessibilité est une estimation géométrique (voir pipeline/README.md) : un « inaccessible » doit être confirmé en jeu._")
fs.writeFile(`{dossierRapport}/{nom}.md`, table.concat(md, "\n") .. "\n")

print(`{if rapport.statut == "OK" then "✔" else "✖"} {nom} : {compte.erreur} erreur(s), {compte.avertissement} avertissement(s), {compte.info} info(s) → {dossierRapport}/{nom}.md`)
if compte.erreur > 0 then
	process.exit(1)
end
