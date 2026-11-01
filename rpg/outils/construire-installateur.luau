--[[
	Génère rpg/studio/installer-combat.lua : un script à coller dans la barre de
	commandes de Roblox Studio (ou à exécuter par le MCP avec execute_luau) qui
	installe le combat de Givrecendre et le noyau (sauvegarde) dans la place
	ouverte. Ré-exécutable : remplace les scripts existants du même nom.

	Usage : lune run rpg/outils/construire-installateur
]]

local fs = require("@lune/fs")

-- { chemin dans le dépôt, service, dossiers, nom, classe }
local FICHIERS = {
	{ "rpg/src/ReplicatedStorage/Givrecendre/Regles.luau", "ReplicatedStorage", { "Givrecendre" }, "Regles", "ModuleScript" },
	{ "rpg/src/ReplicatedStorage/Givrecendre/IAOgre.luau", "ReplicatedStorage", { "Givrecendre" }, "IAOgre", "ModuleScript" },
	{ "rpg/src/ServerScriptService/Givrecendre/Combat.server.luau", "ServerScriptService", { "Givrecendre" }, "Combat", "Script" },
	{
		"rpg/src/StarterPlayer/StarterPlayerScripts/Givrecendre/Combat.client.luau",
		"StarterPlayer",
		{ "StarterPlayerScripts", "Givrecendre" },
		"Combat",
		"LocalScript",
	},
	{ "src/ReplicatedStorage/Partage/Configuration.luau", "ReplicatedStorage", { "Partage" }, "Configuration", "ModuleScript" },
	{ "src/ServerScriptService/Noyau/API.luau", "ServerScriptService", { "Noyau" }, "API", "ModuleScript" },
	{ "src/ServerScriptService/Noyau/Achats.luau", "ServerScriptService", { "Noyau" }, "Achats", "ModuleScript" },
	{ "src/ServerScriptService/Noyau/Profil.luau", "ServerScriptService", { "Noyau" }, "Profil", "ModuleScript" },
	{
		"src/ServerScriptService/Noyau/RecompenseQuotidienne.luau",
		"ServerScriptService",
		{ "Noyau" },
		"RecompenseQuotidienne",
		"ModuleScript",
	},
	{ "src/ServerScriptService/Noyau/Sauvegarde.luau", "ServerScriptService", { "Noyau" }, "Sauvegarde", "ModuleScript" },
	{ "src/ServerScriptService/Principal.server.luau", "ServerScriptService", {}, "Principal", "Script" },
}

local function chaineLongue(texte: string): string
	local n = 0
	while string.find(texte, "]" .. string.rep("=", n) .. "]", 1, true) do
		n += 1
	end
	local e = string.rep("=", n)
	return "[" .. e .. "[\n" .. texte .. "]" .. e .. "]"
end

local sortie = {
	"-- Installateur du combat de Givrecendre (GÉNÉRÉ par rpg/outils/construire-installateur.luau : ne pas modifier).",
	"-- À exécuter dans Roblox Studio, mode Édition (barre de commandes, ou execute_luau du MCP).",
	"-- Installe : règles + IA de l'Ogre, script de combat serveur, interface client, noyau (sauvegarde).",
	"local function installer(service, dossiers, nom, classe, source)",
	"\tlocal parent = game:GetService(service)",
	"\tfor _, d in ipairs(dossiers) do",
	"\t\tlocal f = parent:FindFirstChild(d)",
	"\t\tif not f then f = Instance.new(\"Folder\"); f.Name = d; f.Parent = parent end",
	"\t\tparent = f",
	"\tend",
	"\tlocal ancien = parent:FindFirstChild(nom)",
	"\tif ancien then ancien:Destroy() end",
	"\tlocal s = Instance.new(classe)",
	"\ts.Name = nom",
	"\ts.Source = source",
	"\ts.Parent = parent",
	"end",
}
for _, f in FICHIERS do
	local source = fs.readFile(f[1])
	local dossiers = {}
	for _, d in f[3] do
		table.insert(dossiers, string.format("%q", d))
	end
	table.insert(sortie, string.format("-- %s", f[1]))
	table.insert(
		sortie,
		string.format("installer(%q, {%s}, %q, %q, %s)", f[2], table.concat(dossiers, ", "), f[4], f[5], chaineLongue(source))
	)
end
table.insert(sortie, 'print("Givrecendre : combat installé (" .. ' .. #FICHIERS .. ' .. " scripts)")')
fs.writeFile("rpg/studio/installer-combat.lua", table.concat(sortie, "\n") .. "\n")
print("✔ rpg/studio/installer-combat.lua (" .. #FICHIERS .. " scripts)")
