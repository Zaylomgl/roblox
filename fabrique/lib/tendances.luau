--[[
	Lecture des tendances (recherche/rapport-niche.json) et choix du jeu à créer.

	Module pur (hors lecture du fichier) : testé par pipeline/tests/fabrique.test.luau.

	Ce que disent — et ne disent pas — ces chiffres :
	- `mots_ascension` compte, dans les NOMS des jeux du classement « En pleine
	  ascension », les 25 mots les plus fréquents. Un mot absent de cette liste
	  vaut 0 ici, ce qui veut dire « pas dans les 25 premiers », pas « personne
	  n'y joue ».
	- Un score élevé dit que beaucoup de jeux récents portent ce mot dans leur
	  nom, pas qu'un nouveau jeu de ce format attirera des joueurs.
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local M = {}

function M.lire(chemin: string)
	local rapport = serde.decode("json", fs.readFile(chemin))
	local mots = {}
	for _, ligne in rapport.mots_ascension or {} do
		mots[ligne[1]] = ligne[2]
	end
	return {
		mots = mots,
		photos = rapport.photos,
		periode = rapport.periode,
		jeuxUniques = rapport.jeux_uniques,
		genres = rapport.genres or {},
	}
end

-- Somme des occurrences des mots d'une liste, et le détail mot par mot.
function M.score(tendances, mots: { string }): (number, { { mot: string, jeux: number } })
	local total, detail = 0, {}
	for _, mot in mots do
		local n = tendances.mots[mot] or 0
		total += n
		table.insert(detail, { mot = mot, jeux = n })
	end
	return total, detail
end

-- Tous les formats, du plus porté par les tendances au moins porté.
function M.classerFormats(tendances, formats)
	local classement = {}
	for rang, format in formats do
		local score, detail = M.score(tendances, format.mots)
		table.insert(classement, { format = format, score = score, detail = detail, rang = rang })
	end
	table.sort(classement, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.rang < b.rang
	end)
	return classement
end

-- Générateur pseudo-aléatoire déterministe (Park–Miller), pour des choix reproductibles.
function M.hasard(graine: number)
	local etat = math.floor(graine) % 2147483646 + 1
	return function(n: number): number
		etat = (etat * 48271) % 2147483647
		return etat % n + 1
	end
end

--[[
	Choisit le format et le thème du prochain jeu.

	Format : parmi ceux que la Fabrique sait construire, celui qui maximise
	score / (1 + nombre de jeux déjà créés dans ce format). On suit donc la
	tendance la plus forte, sans refaire dix fois le même format.

	Thème : parmi ceux pas encore utilisés avec ce format (tous, s'ils l'ont
	tous été), celui dont les mots sont le plus présents dans les tendances ;
	à égalité, tirage au sort reproductible (graine).
]]
function M.choisir(tendances, formats, themes, catalogue, graine: number)
	local dejaParFormat, dejaCombinaison = {}, {}
	for _, jeu in catalogue do
		dejaParFormat[jeu.format] = (dejaParFormat[jeu.format] or 0) + 1
		dejaCombinaison[jeu.format .. "/" .. jeu.theme] = true
	end

	local meilleur, meilleurePriorite = nil, -1
	for _, ligne in M.classerFormats(tendances, formats) do
		if ligne.format.gabarit then
			local priorite = ligne.score / (1 + (dejaParFormat[ligne.format.cle] or 0))
			if priorite > meilleurePriorite then
				meilleur, meilleurePriorite = ligne, priorite
			end
		end
	end
	assert(meilleur, "aucun format constructible dans le catalogue")

	local candidats = {}
	for _, theme in themes do
		if not dejaCombinaison[meilleur.format.cle .. "/" .. theme.cle] then
			table.insert(candidats, theme)
		end
	end
	if #candidats == 0 then
		candidats = table.clone(themes)
	end
	local tirer = M.hasard(graine)
	local notes = {}
	for i, theme in candidats do
		notes[i] = { theme = theme, score = M.score(tendances, theme.motsTendance or {}), sort = tirer(1000000) }
	end
	table.sort(notes, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.sort < b.sort
	end)

	return meilleur.format, notes[1].theme, meilleur
end

return M
