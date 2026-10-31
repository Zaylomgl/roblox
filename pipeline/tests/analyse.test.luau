--[[
	Tests du validateur sur des places artificielles dont on connaît la réponse.

	Physique par défaut de Roblox : saut ≈ 6,37 studs de haut, ≈ 8,15 studs de
	portée à plat. Avec la marge de 90 % du validateur : ≈ 5,7 studs de haut,
	≈ 8,3 studs de vide franchissable à plat (portée × 0,9 + demi-largeur).
]]

local roblox = require("@lune/roblox")

local analyse = require("../lib/analyse")

local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

local M = {}

-- Place minimale : un spawn 6×1×6 dont le dessus est à Y = 0.
local function nouvellePlace(avecSpawn: boolean?)
	local game = Instance.new("DataModel")
	local ws = game:GetService("Workspace")
	ws.FallenPartsDestroyHeight = -50
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = ws
	local collect = Instance.new("Folder")
	collect.Name = "Collectibles"
	collect.Parent = map
	if avecSpawn ~= false then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = CFrame.new(0, -0.5, 0)
		spawn.Parent = map
	end
	return game, map, collect
end

-- Plateforme de taille (sx, 1, sz) dont le dessus est à la hauteur `haut`, centrée en (x, z).
local function plateforme(parent, x: number, haut: number, z: number, sx: number?, sz: number?, classe: string?)
	local p = Instance.new(classe or "Part")
	p.Anchored = true
	p.Size = Vector3.new(sx or 6, 1, sz or 6)
	p.CFrame = CFrame.new(x, haut - 0.5, z)
	p.Parent = parent
	return p
end

local function collectible(dossier, x: number, y: number, z: number)
	local c = Instance.new("Part")
	c.Anchored = true
	c.CanCollide = false
	c.Size = Vector3.new(1, 1, 1)
	c.CFrame = CFrame.new(x, y, z)
	c.Name = "Pièce"
	c.Parent = dossier
	return c
end

local function codes(rapport): { [string]: boolean }
	local t = {}
	for _, p in rapport.problemes do
		t[p.code] = true
	end
	return t
end

local function accessibles(game): (number, number)
	local rapport = analyse.analyser(game, "test")
	return rapport.accessibilite.collectiblesAccessibles, rapport.accessibilite.collectiblesTotal
end

-- Spawn de 6 de large centré en 0 : son bord est en x = 3.
-- Une plateforme de 6 de large centrée en x = 3 + vide + 3.

M["saut de 5 studs de vide à plat : accessible"] = function(t)
	local game, map, collect = nouvellePlace()
	plateforme(map, 3 + 5 + 3, 0, 0)
	collectible(collect, 11, 2, 0)
	t.egal(accessibles(game), 1)
end

M["vide de 12 studs à plat : inaccessible"] = function(t)
	local game, map, collect = nouvellePlace()
	plateforme(map, 3 + 12 + 3, 0, 0)
	collectible(collect, 18, 2, 0)
	local ok, total = accessibles(game)
	t.egal(total, 1)
	t.egal(ok, 0)
end

M["marche de 5 studs collée : accessible"] = function(t)
	local game, map, collect = nouvellePlace()
	plateforme(map, 6, 5, 0)
	collectible(collect, 7, 7, 0)
	t.egal(accessibles(game), 1)
end

M["marche de 7 studs collée : inaccessible"] = function(t)
	local game, map, collect = nouvellePlace()
	plateforme(map, 6, 7, 0)
	collectible(collect, 7, 9, 0)
	t.egal(accessibles(game), 0)
end

M["descente : un vide plus large devient franchissable en tombant"] = function(t)
	-- 9 studs de vide : trop à plat, mais OK en tombant de 10 studs (plus de temps en l'air).
	local game, map, collect = nouvellePlace()
	plateforme(map, 3 + 9 + 3, 0, 0)
	collectible(collect, 15, 2, 0)
	t.egal(accessibles(game), 0)

	local game2, map2, collect2 = nouvellePlace()
	plateforme(map2, 3 + 9 + 3, -10, 0)
	collectible(collect2, 15, -8, 0)
	t.egal(accessibles(game2), 1)
end

M["chaîne de plateformes : accessible de proche en proche"] = function(t)
	local game, map, collect = nouvellePlace()
	for i = 1, 6 do
		plateforme(map, i * 10, i * 3, 0) -- 4 studs de vide, +3 de hauteur à chaque fois
	end
	collectible(collect, 60, 20, 0)
	t.egal(accessibles(game), 1)
end

M["collectible trop haut au-dessus d'une plateforme : inaccessible"] = function(t)
	local game, _, collect = nouvellePlace()
	collectible(collect, 0, 15, 0)
	t.egal(accessibles(game), 0)
end

M["rampe (WedgePart) vers une plateforme haute : accessible"] = function(t)
	local game, map, collect = nouvellePlace()
	local rampe = Instance.new("WedgePart")
	rampe.Anchored = true
	rampe.Size = Vector3.new(6, 12, 20)
	rampe.CFrame = CFrame.new(0, 6, 13) -- de Y=0 à Y=12, collée au spawn
	rampe.Parent = map
	plateforme(map, 0, 12, 26)
	collectible(collect, 0, 14, 26)
	t.egal(accessibles(game), 1)
end

M["pad de saut : rend accessible une plateforme haute"] = function(t)
	local game, map, collect = nouvellePlace()
	plateforme(map, 0, 30, 20)
	collectible(collect, 0, 32, 20)
	t.egal(accessibles(game), 0)

	local game2, map2, collect2 = nouvellePlace()
	plateforme(map2, 0, 30, 20)
	collectible(collect2, 0, 32, 20)
	local pad = plateforme(map2, 0, 0.5, 6, 4, 4)
	-- 110 studs/s vers le haut : sommet ≈ 110² / (2 × 196,2) ≈ 30,8 studs au-dessus du pad.
	pad:SetAttribute("Vitesse", Vector3.new(0, 110, 12))
	t.egal(accessibles(game2), 1)
end

M["plateforme sous FallenPartsDestroyHeight : inaccessible"] = function(t)
	local game, map, collect = nouvellePlace()
	plateforme(map, 6, -60, 0, 30, 30)
	collectible(collect, 6, -58, 0)
	t.egal(accessibles(game), 0)
end

M["pas de spawn : erreur SPAWN_ABSENT"] = function(t)
	local game = nouvellePlace(false)
	t.vrai(codes(analyse.analyser(game, "test")).SPAWN_ABSENT)
end

M["script avec erreur de syntaxe : erreur ERREUR_SYNTAXE"] = function(t)
	local game = nouvellePlace()
	local s = Instance.new("Script")
	s.Source = "local x = = 2"
	s.Parent = game:GetService("ServerScriptService")
	local rapport = analyse.analyser(game, "test")
	t.vrai(codes(rapport).ERREUR_SYNTAXE)
	t.egal(rapport.statut, "A_CORRIGER")
end

M["détection sauvegarde et monétisation"] = function(t)
	local game = nouvellePlace()
	local c = codes(analyse.analyser(game, "test"))
	t.vrai(c.PAS_DE_SAUVEGARDE)
	t.vrai(c.PAS_DE_MONETISATION)

	local s = Instance.new("Script")
	s.Source = 'local DS = game:GetService("DataStoreService")\nlocal MS = game:GetService("MarketplaceService")'
	s.Parent = game:GetService("ServerScriptService")
	local c2 = codes(analyse.analyser(game, "test"))
	t.faux(c2.PAS_DE_SAUVEGARDE)
	t.faux(c2.PAS_DE_MONETISATION)
end

M["Terrain n'est pas compté comme une pièce"] = function(t)
	local game = nouvellePlace()
	local rapport = analyse.analyser(game, "test")
	t.egal(rapport.statistiques.pieces, 1) -- uniquement le spawn
end

return M
