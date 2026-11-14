--[[
	La Fabrique : crée un nouveau jeu Roblox à partir des tendances.

	Usage :
	    lune run fabrique/creer                       choisit format et thème d'après les tendances
	    lune run fabrique/creer -- --tendances        affiche seulement le classement des formats
	    lune run fabrique/creer -- --format tour --theme glace --graine 4127 --etapes 10
	    lune run fabrique/creer -- ... --remplacer    réécrit un jeu existant du même nom

	Écrit maps/<nom>.lua (script de construction), jeux/<nom>.md (fiche) et met
	à jour jeux/catalogue.json. Le jeu se construit et se valide ensuite avec
	./pipeline/run.sh maps/<nom>.lua (ou d'un coup : ./fabrique/nouveau-jeu.sh).
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local assemblage = require("./lib/assemblage")
local formats = require("./formats")
local tendancesLib = require("./lib/tendances")
local themes = require("./themes")

local RAPPORT = "recherche/rapport-niche.json"
local CATALOGUE = "jeux/catalogue.json"

local options = { etapes = 10 }
do
	local i = 1
	while i <= #process.args do
		local a = process.args[i]
		if a == "--tendances" or a == "--remplacer" then
			options[string.sub(a, 3)] = true
		elseif a == "--format" or a == "--theme" or a == "--graine" or a == "--etapes" then
			i += 1
			local valeur = process.args[i]
			if not valeur then
				print(`✖ {a} attend une valeur`)
				process.exit(2)
			end
			options[string.sub(a, 3)] = if a == "--format" or a == "--theme" then valeur else tonumber(valeur)
		elseif a ~= "--" then
			print(`✖ option inconnue : {a}`)
			process.exit(2)
		end
		i += 1
	end
end

if not fs.isFile(RAPPORT) then
	print(`✖ {RAPPORT} introuvable : lancer d'abord python3 recherche/niche.py`)
	process.exit(1)
end
local tendances = tendancesLib.lire(RAPPORT)
local source = `Tendances : {tendances.photos} relevés des classements Roblox, du {string.sub(
	tendances.periode[1],
	1,
	10
)} au {string.sub(tendances.periode[2], 1, 10)} (recherche/rapport-niche.md).`

local function trouver(liste, cle: string, genre: string)
	for _, element in liste do
		if element.cle == cle then
			return element
		end
	end
	local connus = {}
	for _, element in liste do
		table.insert(connus, element.cle)
	end
	print(`✖ {genre} inconnu : {cle} (connus : {table.concat(connus, ", ")})`)
	process.exit(2)
	return nil
end

--------------------------------------------------------------------------------
-- Classement des formats
--------------------------------------------------------------------------------

local classement = tendancesLib.classerFormats(tendances, formats)
print(`▶ {source}`)
print("  Formats, du plus présent au moins présent dans les noms des jeux « En pleine ascension » :")
for _, ligne in classement do
	local mots = {}
	for _, d in ligne.detail do
		table.insert(mots, `{d.mot} {d.jeux}`)
	end
	local etat = if ligne.format.gabarit then "constructible" else "pas encore constructible"
	print(string.format("  %4d  %-26s %-24s (%s)", ligne.score, ligne.format.nom, etat, table.concat(mots, ", ")))
end
if options.tendances then
	process.exit(0)
end

--------------------------------------------------------------------------------
-- Choix du jeu
--------------------------------------------------------------------------------

local catalogue = if fs.isFile(CATALOGUE) then serde.decode("json", fs.readFile(CATALOGUE)) else {}
local graine = options.graine or (os.time() % 90000 + 10000)

local format, theme, ligneFormat = tendancesLib.choisir(tendances, formats, themes, catalogue, graine)
if options.format then
	format = trouver(formats, options.format, "format")
	for _, ligne in classement do
		if ligne.format == format then
			ligneFormat = ligne
		end
	end
	if not format.gabarit then
		print(
			`✖ Le format « {format.nom} » est repéré dans les tendances mais la Fabrique ne sait pas encore le construire.`
		)
		process.exit(1)
	end
end
if options.theme then
	theme = trouver(themes, options.theme, "thème")
elseif options.format then
	-- Format imposé : on refait le choix du thème pour ce format.
	local seulement = { format }
	_, theme = tendancesLib.choisir(tendances, seulement, themes, catalogue, graine)
end

local tirer = tendancesLib.hasard(graine)
local titre = string.format(format.modelesTitre[tirer(#format.modelesTitre)], theme.motsTitre[tirer(#theme.motsTitre)])
-- Évite les répétitions du genre « Prison Prison Run ».
titre = string.gsub(titre, "(%a+) %1", "%1")

local nom = `{format.cle}-{theme.cle}`
local existant = nil
for i, jeu in catalogue do
	if jeu.nom == nom then
		existant = i
	end
end
if existant and not options.remplacer then
	nom = `{nom}-{graine}`
	existant = nil
end

-- Au-delà de 12 étapes, le format « evasion » dépasse le seuil de 4000 pièces du
-- validateur (mesuré : jusqu'à 3582 pièces à 12 étapes, 4171 à 14).
local ETAPES_MAX = 12
local etapes = math.clamp(math.floor(options.etapes), 3, ETAPES_MAX)
local jeu = {
	nom = nom,
	titre = titre,
	format = format.cle,
	gabarit = format.gabarit,
	graine = graine,
	etapes = etapes,
	theme = theme,
	source = source,
}

--------------------------------------------------------------------------------
-- Écriture
--------------------------------------------------------------------------------

for _, dossier in { "maps", "jeux" } do
	if not fs.isDir(dossier) then
		fs.writeDir(dossier)
	end
end
fs.writeFile(`maps/{nom}.lua`, assemblage.assembler(jeu, "fabrique/gabarits"))

local lignesMots = {}
for _, d in ligneFormat.detail do
	table.insert(lignesMots, `| {d.mot} | {d.jeux} |`)
end
local genreStats = nil
for _, g in tendances.genres do
	if g.genre == format.genreRoblox then
		genreStats = g
	end
end
local fiche = {
	`# {theme.emoji} {titre}`,
	"",
	`Jeu créé par la Fabrique le {os.date("!%Y-%m-%d")} — script de construction : [\`maps/{nom}.lua\`](../maps/{nom}.lua).`,
	"",
	"| | |",
	"|---|---|",
	`| Format | {format.nom} — {format.resume} |`,
	`| Thème | {theme.nom} |`,
	`| Étapes | {etapes} |`,
	`| Graine | {graine} |`,
	`| Genre à choisir sur Roblox | {format.genreRoblox} |`,
	"",
	"## Pourquoi ce format",
	"",
	source,
	"",
	"Nombre de jeux du classement « En pleine ascension » dont le nom contient chaque mot du format :",
	"",
	"| Mot | Jeux en ascension |",
	"|---|---|",
	table.concat(lignesMots, "\n"),
	"",
	"Un mot à 0 n'est pas dans les 25 mots les plus fréquents du rapport ; cela ne veut pas dire qu'aucun jeu ne le porte.",
	"",
}
if genreStats then
	table.insert(
		fiche,
		string.format(
			"Genre « %s » sur la période : %d jeux classés, %d %% des joueurs connectés relevés, %d jeux en ascension, %d parmi les plus revisités, %d %% de votes positifs (médiane).",
			genreStats.genre,
			genreStats.jeux,
			math.floor(genreStats.part_joueurs * 100 + 0.5),
			genreStats.ascension,
			genreStats.revisites,
			math.floor(genreStats.ratio_votes_median * 100 + 0.5)
		)
	)
	table.insert(fiche, "")
end
for _, ligne in
	{
		"## Ce que ces chiffres ne disent pas",
		"",
		"Ils montrent ce qui monte dans les classements, pas ce qui marchera pour ce jeu : aucun de ces chiffres ne garantit des joueurs. Le rendu réel (lumières, matériaux) et le plaisir de jeu ne se vérifient que dans Roblox Studio, en jouant.",
		"",
		"## Page Roblox (proposition)",
		"",
		`- **Nom** : {theme.emoji} {titre}`,
		`- **Description** : Climb, jump and dodge your way through {etapes} stages of the {theme.motsTitre[1]} world. Your stage is saved: come back and finish later. Collect gems, reach the top and count your wins!`,
		"",
		"L'interface du jeu (boutique, récompense du jour) est en français ; le titre et la description sont en anglais, comme les noms relevés dans les classements.",
		"",
		"## Construire, valider, tester",
		"",
		"```bash",
		`./pipeline/run.sh maps/{nom}.lua`,
		"```",
		"",
		`Le rapport de validation est écrit dans \`reports/{nom}.md\`, la place dans \`build/{nom}.rbxl\` (ouvrable dans Roblox Studio).`,
		"",
	}
do
	table.insert(fiche, ligne)
end
fs.writeFile(`jeux/{nom}.md`, table.concat(fiche, "\n"))

local entree = {
	nom = nom,
	titre = titre,
	format = format.cle,
	theme = theme.cle,
	graine = graine,
	etapes = etapes,
	cree_le = os.date("!%Y-%m-%d"),
	score_tendance = ligneFormat.score,
	tendances_jusqu_au = string.sub(tendances.periode[2], 1, 10),
}
if existant then
	catalogue[existant] = entree
else
	table.insert(catalogue, entree)
end
fs.writeFile(CATALOGUE, serde.encode("json", catalogue, true) .. "\n")

print("")
print(`✔ {theme.emoji} {titre}`)
print(`  format {format.cle} (score {ligneFormat.score}) · thème {theme.cle} · graine {graine} · {etapes} étapes`)
print(`  → maps/{nom}.lua, jeux/{nom}.md, {CATALOGUE}`)
print(`  Suite : ./pipeline/run.sh maps/{nom}.lua`)
print(`NOM={nom}`)
