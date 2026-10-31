--[[
	Construit une map hors de Roblox Studio.

	Usage : lune run pipeline/build <script-de-map.lua> [sortie.rbxl] [--silencieux] [--src <dossier>]

	Exécute le script de construction (celui qu'on collerait dans la barre de
	commande de Studio) dans un environnement Roblox simulé, puis enregistre le
	résultat en fichier de place .rbxl, ouvrable dans Roblox Studio.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local injection = require("./lib/injection")
local rbxenv = require("./lib/rbxenv")

local args = {}
local silencieux = false
local dossierSrc = nil
local i = 1
while i <= #process.args do
	local a = process.args[i]
	if a == "--silencieux" then
		silencieux = true
	elseif a == "--src" then
		i += 1
		dossierSrc = process.args[i]
	else
		table.insert(args, a)
	end
	i += 1
end

local cheminScript = args[1]
if not cheminScript then
	print("Usage : lune run pipeline/build <script-de-map.lua> [sortie.rbxl] [--silencieux] [--src <dossier>]")
	process.exit(2)
end

local nom = string.match(cheminScript, "([^/\\]+)%.lua[u]?$") or "map"
local sortie = args[2] or ("build/" .. nom .. ".rbxl")

local source = fs.readFile(cheminScript)
local env, game, journal = rbxenv.creer({ silencieux = silencieux })

print(`▶ Construction de {cheminScript}`)
local debut = os.clock()
local okCompil, fonction = pcall(luau.load, source, { debugName = nom, environment = env })
if not okCompil then
	print(`✖ Erreur de syntaxe dans {cheminScript} :\n{fonction}`)
	process.exit(1)
end

local ok, erreur = pcall(fonction)
if not ok then
	print(`✖ Le script de map a planté pendant la construction :\n{erreur}`)
	process.exit(1)
end

-- Scripts du jeu (noyau commun, etc.) versionnés en fichiers dans src/.
if dossierSrc then
	local n = injection.injecter(game, dossierSrc)
	print(`  + {n} script(s) injecté(s) depuis {dossierSrc}/`)
end

rbxenv.preparerPourEnregistrement(game)

local dossierSortie = string.match(sortie, "^(.*)[/\\][^/\\]+$")
if dossierSortie and not fs.isDir(dossierSortie) then
	fs.writeDir(dossierSortie)
end
fs.writeFile(sortie, roblox.serializePlace(game))

-- Journal de construction à côté du .rbxl (utile pour comparer deux versions).
fs.writeFile(string.gsub(sortie, "%.rbxl$", ".log"), table.concat(journal, "\n") .. "\n")

local nbObjets = #game:GetDescendants()
print(`✔ {sortie} écrit ({nbObjets} objets, {string.format("%.2f", os.clock() - debut)} s)`)
