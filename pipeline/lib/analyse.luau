--[[
	Analyse d'une place Roblox : le cœur du validateur.

	analyser(game, nom) -> rapport, scripts
	- rapport : table (statut, résumé, statistiques, accessibilité, problèmes…)
	- scripts : liste { chemin, source } des scripts embarqués (pour le linter)

	Utilisé par pipeline/validate.luau (ligne de commande) et par les tests
	(pipeline/tests/), qui construisent des places artificielles.
]]

local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local config = require("../config")
local geometrie = require("./geometrie")
local physique = require("./physique")

local M = {}

function M.analyser(game, nom: string)
	local workspace = game:GetService("Workspace")

	--------------------------------------------------------------------------------
	-- Outils
	--------------------------------------------------------------------------------

	local problemes = {}
	local function signaler(gravite: string, categorie: string, code: string, message: string, objets: { string }?)
		table.insert(problemes, {
			gravite = gravite, -- "erreur" | "avertissement" | "info"
			categorie = categorie,
			code = code,
			message = message,
			objets = objets,
		})
	end

	local function cheminDe(objet): string
		local morceaux = {}
		local courant = objet
		while courant and courant ~= game do
			table.insert(morceaux, 1, courant.Name)
			courant = courant.Parent
		end
		return table.concat(morceaux, ".")
	end

	local function lire(objet, propriete: string, defaut: any): any
		local ok, valeur = pcall(function()
			return objet[propriete]
		end)
		if ok and valeur ~= nil then
			return valeur
		end
		return defaut
	end

	local function aUnAncetreNomme(objet, noms: { string }): boolean
		local courant = objet.Parent
		while courant and courant ~= game do
			if table.find(noms, courant.Name) then
				return true
			end
			courant = courant.Parent
		end
		return false
	end

	local function attributAncetre(objet, noms: { string }): any
		local courant = objet
		while courant and courant ~= game do
			for _, n in noms do
				local v = courant:GetAttribute(n)
				if v ~= nil then
					return v
				end
			end
			courant = courant.Parent
		end
		return nil
	end

	local function arrondi(x: number, decimales: number?): number
		local f = 10 ^ (decimales or 1)
		return math.floor(x * f + 0.5) / f
	end

	--------------------------------------------------------------------------------
	-- 1. Inventaire
	--------------------------------------------------------------------------------

	local descendants = game:GetDescendants()
	local stats = {
		objets = #descendants,
		pieces = 0,
		piecesNonAncrees = 0,
		meshParts = 0,
		lumieres = 0,
		lumieresAvecOmbres = 0,
		emetteursParticules = 0,
		particulesParSeconde = 0,
		sons = 0,
		scripts = 0,
		collectibles = 0,
		padsDeSaut = 0,
		spawns = 0,
	}

	local pieces = {}
	local collectibles = {}
	local spawns = {}
	local scripts = {}
	local nonAncreesHorsDossier = {}
	local piecesALaRacine = {}
	local assetsExternes = {}

	local PROPRIETES_ASSETS = {
		Sound = { "SoundId" },
		Decal = { "Texture" },
		Texture = { "Texture" },
		ParticleEmitter = { "Texture" },
		Beam = { "Texture" },
		Trail = { "Texture" },
		MeshPart = { "MeshID", "TextureID" },
		SpecialMesh = { "MeshId", "TextureId" },
		Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId" },
		ImageLabel = { "Image" },
		ImageButton = { "Image" },
		Animation = { "AnimationId" },
	}

	local function estCollectible(objet): boolean
		if objet:GetAttribute("Collectible") == true then
			return true
		end
		return aUnAncetreNomme(objet, config.DOSSIERS_COLLECTIBLES)
	end

	for _, objet in descendants do
		if objet:IsA("Terrain") then
			-- Le Terrain voxel n'est pas une pièce ordinaire (et n'est pas analysé, voir README).
			continue
		elseif objet:IsA("BasePart") then
			stats.pieces += 1
			if objet:IsA("MeshPart") then
				stats.meshParts += 1
			end
			if estCollectible(objet) then
				stats.collectibles += 1
				table.insert(collectibles, objet)
			else
				table.insert(pieces, objet)
			end
			if objet:IsA("SpawnLocation") then
				stats.spawns += 1
				table.insert(spawns, objet)
			end
			if not lire(objet, "Anchored", true) then
				stats.piecesNonAncrees += 1
				if not aUnAncetreNomme(objet, config.DOSSIERS_PHYSIQUE_AUTORISEE) then
					table.insert(nonAncreesHorsDossier, cheminDe(objet))
				end
			end
			if objet.Parent == workspace then
				table.insert(piecesALaRacine, cheminDe(objet))
			end
		elseif objet:IsA("Light") then
			stats.lumieres += 1
			if lire(objet, "Shadows", false) and lire(objet, "Enabled", true) then
				stats.lumieresAvecOmbres += 1
			end
		elseif objet:IsA("ParticleEmitter") then
			stats.emetteursParticules += 1
			if lire(objet, "Enabled", true) then
				stats.particulesParSeconde += lire(objet, "Rate", 0)
			end
		elseif objet:IsA("Sound") then
			stats.sons += 1
		elseif objet:IsA("LuaSourceContainer") then
			stats.scripts += 1
			table.insert(scripts, objet)
		end

		local proprietes = PROPRIETES_ASSETS[objet.ClassName]
		if proprietes then
			for _, prop in proprietes do
				local valeur = lire(objet, prop, "")
				local texte = tostring(valeur)
				if string.find(texte, "rbxassetid://") or string.find(texte, "roblox%.com/asset") then
					table.insert(assetsExternes, `{cheminDe(objet)}.{prop} = {texte}`)
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	-- 1 bis. Terrain voxel décrit par un plan (ServerStorage.PlanTerrain)
	--------------------------------------------------------------------------------
	-- Hors de Roblox, le Terrain ne peut pas être rempli : la map enregistre ses
	-- opérations dans un ModuleScript, rejoué au démarrage du serveur. Les dessus
	-- « marchables » (plateaux des îles) deviennent des pièces VIRTUELLES, jamais
	-- ajoutées à la place, utilisées seulement par le test d'accessibilité.

	local terrainPlan = { operations = 0, surfacesMarchables = 0 }
	local serverStorage = game:FindFirstChildOfClass("ServerStorage")
	local modulePlan = serverStorage and serverStorage:FindFirstChild("PlanTerrain")
	if modulePlan and modulePlan:IsA("ModuleScript") then
		local ok, plan = pcall(function()
			return luau.load(modulePlan.Source, { debugName = "PlanTerrain" })()
		end)
		if ok and type(plan) == "table" and type(plan.OPERATIONS) == "table" then
			for _, op in plan.OPERATIONS do
				terrainPlan.operations += 1
				if op[1] == "Cylindre" and op[3] == true then
					local c, parametres = op[4], op[5]
					local virtuelle = roblox.Instance.new("Part")
					virtuelle.Name = "TerrainVirtuel"
					virtuelle.Shape = roblox.Enum.PartType.Cylinder
					-- Terrain:FillCylinder a son axe sur Y ; un cylindre Part, sur X.
					virtuelle.Size = roblox.Vector3.new(parametres[1], parametres[2] * 2, parametres[2] * 2)
					virtuelle.CFrame = roblox.CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
						* roblox.CFrame.Angles(0, 0, math.rad(90))
					table.insert(pieces, virtuelle)
					terrainPlan.surfacesMarchables += 1
				end
			end
		else
			signaler(
				"erreur",
				"Terrain",
				"PLAN_TERRAIN_ILLISIBLE",
				`ServerStorage.PlanTerrain ne renvoie pas de table OPERATIONS : le Terrain ne sera pas généré. ({tostring(plan)})`,
				{ cheminDe(modulePlan) }
			)
		end
	end

	--------------------------------------------------------------------------------
	-- 2. Réglages du personnage et du monde (ceux de la place, sinon défauts Roblox)
	--------------------------------------------------------------------------------

	local starterPlayer = game:FindFirstChildOfClass("StarterPlayer")
	local P = config.PHYSIQUE
	local gravite = lire(workspace, "Gravity", P.GRAVITE)
	local vitesseMarche = if starterPlayer then lire(starterPlayer, "CharacterWalkSpeed", P.VITESSE_MARCHE) else P.VITESSE_MARCHE
	local useJumpPower = if starterPlayer then lire(starterPlayer, "CharacterUseJumpPower", P.USE_JUMP_POWER) else P.USE_JUMP_POWER
	local jumpPower = if starterPlayer then lire(starterPlayer, "CharacterJumpPower", P.JUMP_POWER) else P.JUMP_POWER
	local jumpHeight = if starterPlayer then lire(starterPlayer, "CharacterJumpHeight", P.JUMP_HEIGHT) else P.JUMP_HEIGHT
	local hauteurDestruction = lire(workspace, "FallenPartsDestroyHeight", -500)

	local phys = physique.parametres(gravite, vitesseMarche, useJumpPower, jumpPower, jumpHeight)
	local C = config.PERSONNAGE

	--------------------------------------------------------------------------------
	-- 3. Spawn
	--------------------------------------------------------------------------------

	if #spawns == 0 then
		signaler(
			"erreur",
			"Spawn",
			"SPAWN_ABSENT",
			"Aucun SpawnLocation : les joueurs apparaîtront à une position par défaut, potentiellement dans le vide."
		)
	end
	for _, spawn in spawns do
		if not lire(spawn, "Anchored", true) then
			signaler("erreur", "Spawn", "SPAWN_NON_ANCRE", "Le SpawnLocation n'est pas ancré : il va tomber.", { cheminDe(spawn) })
		end
		if spawn.CFrame.Position.Y <= hauteurDestruction then
			signaler(
				"erreur",
				"Spawn",
				"SPAWN_SOUS_ZONE_MORTELLE",
				`Le spawn (Y={arrondi(spawn.CFrame.Position.Y)}) est sous FallenPartsDestroyHeight ({hauteurDestruction}) : mort instantanée.`,
				{ cheminDe(spawn) }
			)
		end
	end

	--------------------------------------------------------------------------------
	-- 4. Accessibilité : graphe des surfaces marchables + sauts possibles
	--------------------------------------------------------------------------------

	local surfaces = {}
	local surfaceDeLObjet = {}
	for _, objet in pieces do
		if lire(objet, "CanCollide", true) then
			local propulsion = nil
			for _, nomAttr in config.ATTRIBUTS_PROPULSION do
				local v = objet:GetAttribute(nomAttr)
				if typeof(v) == "Vector3" then
					local mult = attributAncetre(objet, { "MultiplicateurPads", "LaunchMultiplier" })
					propulsion = if typeof(mult) == "number" then v * mult else v
					break
				end
			end
			local s = geometrie.surfaceDe(objet, #surfaces + 1, config.PENTE_RAMPE_MAX_DEG, propulsion)
			-- Une surface sous la zone mortelle n'est pas un endroit où l'on peut se tenir.
			if s.haut > hauteurDestruction then
				table.insert(surfaces, s)
				surfaceDeLObjet[objet] = s
			end
		end
	end
	for _, s in surfaces do
		if s.propulsion then
			stats.padsDeSaut += 1
		end
	end

	local grille = geometrie.nouvelleGrille(24)
	for _, s in surfaces do
		grille:inserer(s)
	end

	local CHUTE_MAX = 400
	local rayonRecherche = (physique.porteeSaut(phys, -CHUTE_MAX) or 0) * C.MARGE_SAUT + C.DEMI_LARGEUR

	local function hauteurEffective(a, b): number
		if b.rampe then
			if a.haut < b.bas then
				return b.bas - a.haut
			elseif a.haut > b.haut then
				return b.haut - a.haut
			end
			return 0
		end
		return b.haut - a.haut
	end

	local function peutAller(a, b): boolean
		local dh = hauteurEffective(a, b)
		if dh > phys.hauteurSaut * C.MARGE_SAUT then
			return false
		end
		if dh < -CHUTE_MAX then
			return false
		end
		local portee = physique.porteeSaut(phys, dh)
		if not portee then
			return false
		end
		local d = geometrie.distanceRect(a, b)
		if d > portee * C.MARGE_SAUT + C.DEMI_LARGEUR then
			return false
		end
		-- Impossible de tomber sur une surface entièrement cachée sous celle où l'on est.
		if dh < -0.5 and d == 0 and geometrie.estRecouvert(b, a, 0) then
			return false
		end
		return true
	end

	local function destinationsPropulsion(a): { any }
		local v = a.propulsion
		local resultat = {}
		local vh = math.sqrt(v.X * v.X + v.Z * v.Z)
		for _, b in surfaces do
			if b ~= a then
				local dh = b.haut - a.haut
				local t = physique.tempsDeVol(v.Y, phys.gravite, dh)
				if t and t > 0 then
					-- Point d'atterrissage « balistique pur » et rayon de contrôle en l'air.
					local x2, z2 = a.centreX + v.X * t, a.centreZ + v.Z * t
					local controle = phys.vitesseMarche * t * C.MARGE_SAUT + C.DEMI_LARGEUR
					local d = if vh > 0
						then geometrie.distanceSegmentRect(a.centreX, a.centreZ, x2, z2, b)
						else geometrie.distancePointRect(a.centreX, a.centreZ, b)
					if d <= controle then
						table.insert(resultat, b)
					end
				end
			end
		end
		return resultat
	end

	local atteinte = {} -- surface -> profondeur (nombre de « déplacements » depuis le spawn)
	local file = {}
	for _, spawn in spawns do
		local s = surfaceDeLObjet[spawn]
		if s and atteinte[s] == nil then
			atteinte[s] = 0
			table.insert(file, s)
		end
	end

	local tete = 1
	while tete <= #file do
		local a = file[tete]
		tete += 1
		local profondeur = atteinte[a]
		for _, b in grille:voisins(a, rayonRecherche) do
			if atteinte[b] == nil and b ~= a and peutAller(a, b) then
				atteinte[b] = profondeur + 1
				table.insert(file, b)
			end
		end
		if a.propulsion then
			for _, b in destinationsPropulsion(a) do
				if atteinte[b] == nil then
					atteinte[b] = profondeur + 1
					table.insert(file, b)
				end
			end
		end
	end

	local nbAtteintes = 0
	for _ in atteinte do
		nbAtteintes += 1
	end

	-- Collectibles : peut-on les toucher depuis une surface atteignable ?
	local function peutToucher(c): (boolean, number?)
		local pos = c.CFrame.Position
		local _, hy, _ = geometrie.demiEtendue(c.CFrame, c.Size)
		local hx, _, hz = geometrie.demiEtendue(c.CFrame, c.Size)
		local rayon = C.DEMI_LARGEUR + math.max(hx, hz) + 0.5
		local meilleure: number? = nil
		local faux = { minX = pos.X - rayon, maxX = pos.X + rayon, minZ = pos.Z - rayon, maxZ = pos.Z + rayon }
		for _, s in grille:voisins(faux :: any, 0) do
			local prof = atteinte[s]
			if prof ~= nil and geometrie.distancePointRect(pos.X, pos.Z, s) <= rayon then
				local bas = pos.Y - hy
				local hautC = pos.Y + hy
				if bas <= s.haut + C.HAUTEUR + phys.hauteurSaut * C.MARGE_SAUT and hautC >= s.haut - 0.5 then
					if meilleure == nil or prof < meilleure then
						meilleure = prof
					end
				end
			end
		end
		return meilleure ~= nil, meilleure
	end

	local inaccessibles = {}
	local profondeurs = {}
	for _, c in collectibles do
		local ok, prof = peutToucher(c)
		if ok then
			table.insert(profondeurs, prof)
		else
			table.insert(inaccessibles, `{cheminDe(c)} @ ({arrondi(c.CFrame.Position.X)}, {arrondi(c.CFrame.Position.Y)}, {arrondi(c.CFrame.Position.Z)})`)
		end
	end
	table.sort(profondeurs)

	if #spawns > 0 and #collectibles > 0 then
		if #inaccessibles > 0 then
			signaler(
				"erreur",
				"Accessibilité",
				"COLLECTIBLES_INACCESSIBLES",
				`{#inaccessibles} collectible(s) sur {#collectibles} semblent impossibles à atteindre depuis le spawn (saut max ≈ {arrondi(
					phys.hauteurSaut * C.MARGE_SAUT
				)} studs).`,
				inaccessibles
			)
		end
	end

	if #collectibles < config.SEUILS.COLLECTIBLES_MIN then
		signaler(
			"avertissement",
			"Rétention",
			"PEU_DE_COLLECTIBLES",
			`Seulement {#collectibles} collectible(s) : la boucle d'exploration risque d'être trop courte (seuil interne : {config.SEUILS.COLLECTIBLES_MIN}).`
		)
	end

	-- Grandes surfaces jamais atteintes : souvent une zone coupée du reste (ou un décor).
	local grandesInaccessibles = {}
	for _, s in surfaces do
		local aire = (s.maxX - s.minX) * (s.maxZ - s.minZ)
		if atteinte[s] == nil and aire >= 100 then
			table.insert(grandesInaccessibles, { s = s, aire = aire })
		end
	end
	table.sort(grandesInaccessibles, function(a, b)
		return a.aire > b.aire
	end)
	if #grandesInaccessibles > 0 then
		local liste = {}
		for i = 1, math.min(10, #grandesInaccessibles) do
			local g = grandesInaccessibles[i]
			table.insert(liste, `{cheminDe(g.s.objet)} (≈{math.floor(g.aire)} studs², Y={arrondi(g.s.haut)})`)
		end
		signaler(
			"info",
			"Accessibilité",
			"GRANDES_SURFACES_NON_ATTEINTES",
			`{#grandesInaccessibles} grande(s) surface(s) (≥100 studs²) jamais atteintes depuis le spawn. Décor normal, ou zone coupée du reste : à vérifier. Les 10 plus grandes :`,
			liste
		)
	end

	--------------------------------------------------------------------------------
	-- 5. Scripts embarqués : syntaxe, pratiques, systèmes de rétention / revenus
	--------------------------------------------------------------------------------

	local sourcesScripts = {}
	local services = { DataStoreService = false, MarketplaceService = false, BadgeService = false, AdService = false }
	for _, s in scripts do
		local source = lire(s, "Source", "")
		local chemin = cheminDe(s)
		table.insert(sourcesScripts, { chemin = chemin, source = source })

		local ok, erreur = pcall(luau.compile, source)
		if not ok then
			signaler("erreur", "Scripts", "ERREUR_SYNTAXE", `Erreur de syntaxe : {erreur}`, { chemin })
		end
		if s.ClassName == "LocalScript" and s:FindFirstAncestorOfClass("Workspace") then
			signaler(
				"avertissement",
				"Scripts",
				"LOCALSCRIPT_DANS_WORKSPACE",
				"Un LocalScript dans Workspace ne s'exécute pas (sauf dans le personnage).",
				{ chemin }
			)
		end
		-- Fonctions dépréciées : wait/spawn/delay globaux (remplacés par task.*).
		for _, ancienne in { "wait", "spawn", "delay" } do
			for ligne in string.gmatch(source, "[^\n]+") do
				if
					string.find(ligne, "%f[%w_.:]" .. ancienne .. "%s*%(")
					and not string.find(ligne, "task%." .. ancienne)
					and not string.find(ligne, "^%s*%-%-")
				then
					signaler(
						"info",
						"Scripts",
						"FONCTION_DEPRECIEE",
						`« {ancienne}() » est dépréciée, utiliser « task.{ancienne}() ».`,
						{ chemin }
					)
					break
				end
			end
		end
		for service in services do
			if string.find(source, service, 1, true) then
				services[service] = true
			end
		end
	end

	if not services.DataStoreService then
		signaler(
			"avertissement",
			"Rétention",
			"PAS_DE_SAUVEGARDE",
			"Aucun script n'utilise DataStoreService : la progression des joueurs est perdue à chaque départ, ce qui retire une grosse raison de revenir."
		)
	end
	if not services.MarketplaceService then
		signaler(
			"avertissement",
			"Revenus",
			"PAS_DE_MONETISATION",
			"Aucun script n'utilise MarketplaceService : aucun pass ni produit n'est vendu, le jeu ne peut pas rapporter de Robux par achats."
		)
	end
	if not services.BadgeService then
		signaler("info", "Rétention", "PAS_DE_BADGES", "Aucun badge : les badges donnent des objectifs à long terme aux joueurs.")
	end

	--------------------------------------------------------------------------------
	-- 6. Performance (seuils internes, à recaler avec des mesures réelles)
	--------------------------------------------------------------------------------

	local S = config.SEUILS
	if stats.pieces > S.PIECES_AVERTISSEMENT then
		signaler(
			"avertissement",
			"Performance",
			"TROP_DE_PIECES",
			`{stats.pieces} pièces (seuil interne mobile : {S.PIECES_AVERTISSEMENT}).`
		)
	end
	if stats.lumieresAvecOmbres > S.LUMIERES_OMBRES_AVERTISSEMENT then
		signaler(
			"avertissement",
			"Performance",
			"TROP_DE_LUMIERES_OMBRES",
			`{stats.lumieresAvecOmbres} lumières projettent des ombres (seuil interne : {S.LUMIERES_OMBRES_AVERTISSEMENT}).`
		)
	end
	if stats.particulesParSeconde > S.PARTICULES_PAR_SECONDE_AVERTISSEMENT then
		signaler(
			"avertissement",
			"Performance",
			"TROP_DE_PARTICULES",
			`{math.floor(stats.particulesParSeconde)} particules/s au total (seuil interne : {S.PARTICULES_PAR_SECONDE_AVERTISSEMENT}).`
		)
	end
	if #nonAncreesHorsDossier > 0 then
		local liste = table.move(nonAncreesHorsDossier, 1, math.min(10, #nonAncreesHorsDossier), 1, {})
		signaler(
			"avertissement",
			"Performance",
			"PIECES_NON_ANCREES",
			`{#nonAncreesHorsDossier} pièce(s) non ancrée(s) hors d'un dossier de physique : elles vont tomber et coûter du calcul.`,
			liste
		)
	end
	if #piecesALaRacine > 0 then
		signaler(
			"info",
			"Organisation",
			"PIECES_A_LA_RACINE",
			`{#piecesALaRacine} pièce(s) directement dans Workspace (pas rangées dans un dossier).`,
			table.move(piecesALaRacine, 1, math.min(10, #piecesALaRacine), 1, {})
		)
	end
	if #assetsExternes > 0 then
		signaler(
			"info",
			"Assets",
			"ASSETS_A_VERIFIER",
			`{#assetsExternes} référence(s) à des assets externes (rbxassetid://) : impossible de vérifier hors ligne qu'ils existent et sont publics.`,
			table.move(assetsExternes, 1, math.min(20, #assetsExternes), 1, {})
		)
	end

	--------------------------------------------------------------------------------
	-- 7. Ambiance (présence des effets de lumière qui font la « première impression »)
	--------------------------------------------------------------------------------

	local lighting = game:GetService("Lighting")
	local effets = {}
	for _, classe in { "Atmosphere", "Sky", "BloomEffect", "ColorCorrectionEffect", "SunRaysEffect" } do
		effets[classe] = lighting:FindFirstChildOfClass(classe) ~= nil
		if not effets[classe] then
			signaler("info", "Ambiance", "EFFET_ABSENT", `Pas de {classe} dans Lighting.`)
		end
	end

	--------------------------------------------------------------------------------
	-- 8. Rapport
	--------------------------------------------------------------------------------

	local compte = { erreur = 0, avertissement = 0, info = 0 }
	for _, p in problemes do
		compte[p.gravite] += 1
	end
	local ordre = { erreur = 1, avertissement = 2, info = 3 }
	table.sort(problemes, function(a, b)
		if ordre[a.gravite] ~= ordre[b.gravite] then
			return ordre[a.gravite] < ordre[b.gravite]
		end
		return a.code < b.code
	end)

	local medianeProfondeur = if #profondeurs > 0 then profondeurs[math.ceil(#profondeurs / 2)] else nil

	local rapport = {
		map = nom,
			statut = if compte.erreur > 0 then "A_CORRIGER" else "OK",
		resume = compte,
		statistiques = stats,
		terrain = terrainPlan,
		monde = {
			gravite = gravite,
			vitesseMarche = vitesseMarche,
			hauteurSautTheorique = arrondi(phys.hauteurSaut, 2),
			porteeSautAPlat = arrondi(physique.porteeSaut(phys, 0) or 0, 2),
			fallenPartsDestroyHeight = hauteurDestruction,
		},
		accessibilite = {
			surfacesMarchables = #surfaces,
			surfacesAtteintes = nbAtteintes,
			collectiblesAccessibles = #collectibles - #inaccessibles,
			collectiblesTotal = #collectibles,
			profondeurMedianeCollectibles = medianeProfondeur,
			profondeurMaxCollectibles = profondeurs[#profondeurs],
		},
		systemes = services,
		ambiance = effets,
		problemes = problemes,
	}

	return rapport, sourcesScripts
end

return M
