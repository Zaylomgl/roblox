--[[
	Assemble le script de construction d'un jeu : en-tête + réglages + gabarits.

	Le résultat est un script Luau autonome, comme les maps écrites à la main :
	on peut le coller dans la barre de commande de Roblox Studio, ou le
	construire hors Studio avec le pipeline (`./pipeline/run.sh maps/<nom>.lua`).
]]

local fs = require("@lune/fs")

local M = {}

local GABARITS = {
	parcours = { "kit.lua", "parcours.lua", "scenes.lua" },
}
local SCRIPTS_JEU = {
	parcours = "jeu.server.lua",
}

local function estListe(t): boolean
	local n = 0
	for _ in t do
		n += 1
	end
	return n == #t
end

-- Écrit une valeur (nombre, texte, booléen, table) sous forme de littéral Luau.
local function litteral(valeur: any, retrait: string): string
	local genre = type(valeur)
	if genre == "table" then
		local interieur = retrait .. "\t"
		local lignes = {}
		if estListe(valeur) then
			local simples = true
			for _, v in valeur do
				if type(v) == "table" then
					simples = false
				end
			end
			if simples then
				local morceaux = {}
				for _, v in valeur do
					table.insert(morceaux, litteral(v, interieur))
				end
				return "{ " .. table.concat(morceaux, ", ") .. " }"
			end
			for _, v in valeur do
				table.insert(lignes, interieur .. litteral(v, interieur) .. ",")
			end
		else
			local cles = {}
			for cle in valeur do
				table.insert(cles, cle)
			end
			table.sort(cles)
			for _, cle in cles do
				assert(string.match(cle, "^[%a_][%w_]*$"), `clé non exprimable : {cle}`)
				table.insert(lignes, `{interieur}{cle} = {litteral(valeur[cle], interieur)},`)
			end
		end
		return "{\n" .. table.concat(lignes, "\n") .. "\n" .. retrait .. "}"
	elseif genre == "string" then
		return string.format("%q", valeur)
	end
	return tostring(valeur)
end
M.litteral = litteral

--[[
	jeu : { nom, titre, format, gabarit, graine, etapes, theme, source }
	Renvoie le texte du script de construction.
]]
function M.assembler(jeu, dossierGabarits: string): string
	local fichiers = assert(GABARITS[jeu.gabarit], `gabarit inconnu : {jeu.gabarit}`)
	local sourceJeu = fs.readFile(`{dossierGabarits}/{SCRIPTS_JEU[jeu.gabarit]}`)
	assert(not string.find(sourceJeu, "]==]", 1, true), "le script de jeu ne doit pas contenir ]==]")

	local reglages = {
		nom = jeu.nom,
		titre = jeu.titre,
		format = jeu.format,
		graine = jeu.graine,
		etapes = jeu.etapes,
		theme = jeu.theme,
	}

	local morceaux = {
		"--------------------------------------------------------------------------------",
		`-- ✦ {jeu.titre} ✦`,
		"--",
		`-- Jeu Roblox créé par la Fabrique (fabrique/README.md).`,
		`-- Format : {jeu.format} · thème : {jeu.theme.nom} · graine : {jeu.graine} · étapes : {jeu.etapes}`,
		`-- {jeu.source}`,
		"--",
		"-- NE PAS MODIFIER À LA MAIN : ce fichier est réécrit par la Fabrique. Pour le",
		"-- changer, modifier fabrique/gabarits/ ou fabrique/themes.luau puis relancer :",
		`--   lune run fabrique/creer -- --format {jeu.format} --theme {jeu.theme.cle} --graine {jeu.graine} --etapes {jeu.etapes} --remplacer`,
		"--",
		"-- UTILISATION DANS STUDIO : View → Command Bar, coller TOUT ce script, Entrée, puis Play.",
		"-- Relancer le script reconstruit la map proprement (l'ancienne est supprimée).",
		"--------------------------------------------------------------------------------",
		"",
		"local FABRIQUE = " .. litteral(reglages, ""),
		"",
		"local SOURCE_JEU = [==[",
		sourceJeu .. "]==]",
		"",
	}
	for _, fichier in fichiers do
		table.insert(morceaux, fs.readFile(`{dossierGabarits}/{fichier}`))
	end
	return table.concat(morceaux, "\n")
end

return M
