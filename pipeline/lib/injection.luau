--[[
	Injecte une arborescence de fichiers Luau dans une place (à la manière de Rojo).

	Convention :
	- src/<Service>/…            → dans le service Roblox du même nom
	- un dossier                 → Folder (ou la classe Roblox du même nom si elle
	                               existe déjà / est connue, ex. StarterPlayerScripts)
	- nom.server.luau            → Script
	- nom.client.luau            → LocalScript
	- nom.luau                   → ModuleScript
]]

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local M = {}

-- Conteneurs spéciaux qui ne sont pas des Folders.
local CLASSES_CONTENEURS = {
	StarterPlayerScripts = "StarterPlayerScripts",
	StarterCharacterScripts = "StarterCharacterScripts",
}

local function enfantOuCree(parent, nom: string)
	local existant = parent:FindFirstChild(nom)
	if existant then
		return existant
	end
	local objet = roblox.Instance.new(CLASSES_CONTENEURS[nom] or "Folder")
	objet.Name = nom
	objet.Parent = parent
	return objet
end

local function scriptDepuis(fichier: string, chemin: string)
	local classe, nom
	if string.match(fichier, "%.server%.luau$") then
		classe, nom = "Script", string.gsub(fichier, "%.server%.luau$", "")
	elseif string.match(fichier, "%.client%.luau$") then
		classe, nom = "LocalScript", string.gsub(fichier, "%.client%.luau$", "")
	elseif string.match(fichier, "%.luau$") then
		classe, nom = "ModuleScript", string.gsub(fichier, "%.luau$", "")
	else
		return nil
	end
	local s = roblox.Instance.new(classe)
	s.Name = nom
	s.Source = fs.readFile(chemin)
	return s
end

local function injecterDossier(dossier: string, parent, compte: { n: number })
	local entrees = fs.readDir(dossier)
	table.sort(entrees)
	for _, entree in entrees do
		local chemin = dossier .. "/" .. entree
		if fs.isDir(chemin) then
			injecterDossier(chemin, enfantOuCree(parent, entree), compte)
		else
			local s = scriptDepuis(entree, chemin)
			if s then
				local ancien = parent:FindFirstChild(s.Name)
				if ancien then
					ancien:Destroy()
				end
				s.Parent = parent
				compte.n += 1
			end
		end
	end
end

-- Renvoie le nombre de scripts injectés.
function M.injecter(game, racine: string): number
	local compte = { n = 0 }
	for _, service in fs.readDir(racine) do
		local chemin = racine .. "/" .. service
		if fs.isDir(chemin) then
			injecterDossier(chemin, game:GetService(service), compte)
		end
	end
	return compte.n
end

return M
