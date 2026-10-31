--[[
	Lance tous les tests du pipeline : lune run pipeline/test
	Chaque fichier pipeline/tests/*.test.luau renvoie une table { [nom] = function(t) }.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local echecs, reussites = 0, 0

local function verificateur()
	local t = {}
	function t.egal(obtenu, attendu)
		if obtenu ~= attendu then
			error(`attendu {tostring(attendu)}, obtenu {tostring(obtenu)}`, 2)
		end
	end
	function t.vrai(v)
		if not v then
			error(`attendu vrai, obtenu {tostring(v)}`, 2)
		end
	end
	function t.faux(v)
		if v then
			error(`attendu faux, obtenu {tostring(v)}`, 2)
		end
	end
	return t
end

local fichiers = {}
for _, nom in fs.readDir("pipeline/tests") do
	if string.match(nom, "%.test%.luau$") then
		table.insert(fichiers, nom)
	end
end
table.sort(fichiers)

for _, fichier in fichiers do
	local module = require("./tests/" .. string.gsub(fichier, "%.luau$", ""))
	print(`▶ {fichier}`)
	local noms = {}
	for nom in module do
		table.insert(noms, nom)
	end
	table.sort(noms)
	for _, nom in noms do
		local ok, err = pcall(module[nom], verificateur())
		if ok then
			reussites += 1
			print(`  ✔ {nom}`)
		else
			echecs += 1
			print(`  ✖ {nom}\n      {err}`)
		end
	end
end

print(`\n{reussites} réussi(s), {echecs} échoué(s)`)
if echecs > 0 then
	process.exit(1)
end
