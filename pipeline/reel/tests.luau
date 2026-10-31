--[[
	Tests dans le VRAI moteur Roblox, sur la place publiée, via l'API Open
	Cloud « Luau Execution » : python3 pipeline/opencloud.py tester

	L'environnement, d'après la documentation Roblox
	(create.roblox.com/docs/cloud/reference/features/luau-execution) : un
	serveur charge la place et exécute ce script ; la physique ne tourne pas ;
	les scripts de la place ne démarrent pas d'eux-mêmes ; les modifications
	du modèle de données ne sont pas enregistrées dans la place. Les
	DataStores, eux, sont les vrais : le test de sauvegarde utilise un
	DataStore séparé (Tests_Pipeline) et supprime sa clé à la fin.

	Avant l'envoi, opencloud.py remplace les deux lignes marquées --@@ :
	- ATTENDU : chiffres du rapport du validateur (reports/<map>.json) et
	  version publiée ;
	- testsNoyau : pipeline/tests/noyau.test.luau, exécuté ici tel quel, mais
	  sur les modules de la place publiée et dans le vrai interpréteur Luau.

	Statuts : ok, echec, ignore. « ignore » = impossible à vérifier dans cet
	environnement (la raison est donnée). Un test ignoré n'est PAS réussi.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local ATTENDU = nil --@@ATTENDU@@
local testsNoyau: (() -> { [string]: (any) -> () })? = nil --@@TESTS_NOYAU@@

local PLACE_ID = 116414227319701
local SERVICES_ANALYSES = {
	"Workspace",
	"Lighting",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"SoundService",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
}

--------------------------------------------------------------------------------
-- Mini-lanceur (même vérificateur que pipeline/test.luau)
--------------------------------------------------------------------------------

local tests = {}
local mesures = {}

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

local IGNORE = "__ignore__"

local function ignorer(raison: string)
	error({ [IGNORE] = raison }, 0)
end

local function lancer(groupe: string, nom: string, fonction: (any) -> string?)
	local ok, resultat = pcall(fonction, verificateur())
	local statut, detail = "ok", nil
	if ok then
		detail = resultat
	elseif type(resultat) == "table" and resultat[IGNORE] then
		statut, detail = "ignore", resultat[IGNORE]
	else
		statut, detail = "echec", tostring(resultat)
	end
	table.insert(tests, { groupe = groupe, nom = nom, statut = statut, detail = detail })
	print(`[{statut}] {groupe} — {nom}{if detail then " : " .. detail else ""}`)
end

local function arrondi(x: number, decimales: number): number
	local m = 10 ^ decimales
	return math.floor(x * m + 0.5) / m
end

local function aUnAncetreNomme(objet: Instance, nom: string): boolean
	local parent = objet.Parent
	while parent do
		if parent.Name == nom then
			return true
		end
		parent = parent.Parent
	end
	return false
end

print(`Moteur Roblox {version()} — place {game.PlaceId}, version {game.PlaceVersion}`)
mesures.versionMoteur = version()
mesures.placeVersion = game.PlaceVersion

local Noyau = ServerScriptService:FindFirstChild("Noyau")
local partage = ReplicatedStorage:FindFirstChild("Partage")
local configModule = partage and partage:FindFirstChild("Configuration")

--------------------------------------------------------------------------------
-- 1. La place publiée est bien celle construite par le pipeline
--------------------------------------------------------------------------------

lancer("Place", "c'est la version qui vient d'être publiée", function(t)
	t.egal(game.PlaceId, PLACE_ID)
	if ATTENDU and ATTENDU.placeVersion then
		t.egal(game.PlaceVersion, ATTENDU.placeVersion)
	end
	return `place {game.PlaceId}, version {game.PlaceVersion}`
end)

lancer("Place", "scripts du noyau, de la map et de l'interface présents", function(t)
	local principal = ServerScriptService:FindFirstChild("Principal")
	t.vrai(principal and principal:IsA("Script"))
	local mapScript = ServerScriptService:FindFirstChild("IlesCelestes_Script")
	t.vrai(mapScript and mapScript:IsA("Script"))
	for _, nom in { "API", "Achats", "Profil", "RecompenseQuotidienne", "Sauvegarde" } do
		local module = Noyau and Noyau:FindFirstChild(nom)
		if not (module and module:IsA("ModuleScript")) then
			error(`module du noyau manquant : {nom}`)
		end
	end
	t.vrai(configModule and configModule:IsA("ModuleScript"))
	local sps = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local interface = sps and sps:FindFirstChild("Interface")
	t.vrai(interface and interface:IsA("LocalScript"))
	return nil
end)

lancer("Place", "Configuration : pass et produits ont leur vrai ID Roblox", function(t)
	local Configuration = require(configModule)
	local n = 0
	for _, liste in { Configuration.PASSES, Configuration.PRODUITS } do
		for _, objet in liste do
			if objet.id == 0 then
				error(`« {objet.nom} » a encore l'id 0`)
			end
			n += 1
		end
	end
	t.vrai(n > 0)
	return `{n} objet(s) avec un ID`
end)

lancer("Place", "contenu identique au fichier construit (comptages du validateur)", function(t)
	local c = {
		pieces = 0,
		piecesNonAncrees = 0,
		lumieres = 0,
		emetteursParticules = 0,
		sons = 0,
		collectibles = 0,
		spawns = 0,
	}
	for _, nomService in SERVICES_ANALYSES do
		for _, objet in game:GetService(nomService):GetDescendants() do
			if objet:IsA("Terrain") then
				continue
			elseif objet:IsA("BasePart") then
				c.pieces += 1
				if not objet.Anchored then
					c.piecesNonAncrees += 1
				end
				if objet:GetAttribute("Collectible") == true or aUnAncetreNomme(objet, "Collectibles") then
					c.collectibles += 1
				end
				if objet:IsA("SpawnLocation") then
					c.spawns += 1
				end
			elseif objet:IsA("Light") then
				c.lumieres += 1
			elseif objet:IsA("ParticleEmitter") then
				c.emetteursParticules += 1
			elseif objet:IsA("Sound") then
				c.sons += 1
			end
		end
	end
	for cle, valeur in c do
		mesures[cle] = valeur
	end
	if not ATTENDU then
		ignorer("pas de rapport du validateur à comparer")
	end
	local ecarts = {}
	for cle, valeur in c do
		if ATTENDU[cle] ~= nil and ATTENDU[cle] ~= valeur then
			table.insert(ecarts, `{cle} : moteur {valeur}, validateur {ATTENDU[cle]}`)
		end
	end
	if #ecarts > 0 then
		table.sort(ecarts)
		error(table.concat(ecarts, " ; "))
	end
	t.vrai(true)
	return `{c.pieces} pièces, {c.collectibles} cristaux, {c.lumieres} lumières, {c.spawns} spawn`
end)

lancer("Place", "saut et marche réels ≥ ceux supposés par le test d'accessibilité", function(t)
	local g = workspace.Gravity
	local hauteur = if StarterPlayer.CharacterUseJumpPower
		then StarterPlayer.CharacterJumpPower ^ 2 / (2 * g)
		else StarterPlayer.CharacterJumpHeight
	mesures.gravite = arrondi(g, 2)
	mesures.characterUseJumpPower = StarterPlayer.CharacterUseJumpPower
	mesures.hauteurSaut = arrondi(hauteur, 2)
	mesures.vitesseMarche = StarterPlayer.CharacterWalkSpeed
	mesures.fallenPartsDestroyHeight = workspace.FallenPartsDestroyHeight
	if not ATTENDU then
		ignorer("pas de rapport du validateur à comparer")
	end
	t.vrai(hauteur >= ATTENDU.hauteurSaut - 0.01)
	t.vrai(StarterPlayer.CharacterWalkSpeed >= ATTENDU.vitesseMarche)
	t.egal(workspace.FallenPartsDestroyHeight, ATTENDU.fallenPartsDestroyHeight)
	return `saut {arrondi(hauteur, 2)} studs (validateur {ATTENDU.hauteurSaut}), marche {StarterPlayer.CharacterWalkSpeed}`
end)

lancer("Place", "point d'apparition : sol réel juste dessous, au-dessus de la zone mortelle", function(t)
	local spawn = nil
	for _, objet in workspace:GetDescendants() do
		if objet:IsA("SpawnLocation") then
			spawn = objet
			break
		end
	end
	t.vrai(spawn ~= nil)
	local dessus = spawn.Position.Y + spawn.Size.Y / 2
	t.vrai(dessus > workspace.FallenPartsDestroyHeight)
	-- Lancer de rayon du moteur (requête spatiale, sans simulation physique).
	local parametres = RaycastParams.new()
	parametres.RespectCanCollide = true
	local resultat = workspace:Raycast(spawn.Position + Vector3.new(0, spawn.Size.Y / 2 + 0.5, 0), Vector3.new(0, -5, 0), parametres)
	if not resultat then
		error("le rayon ne touche rien sous le point d'apparition")
	end
	if resultat.Instance ~= spawn then
		error(`le rayon touche {resultat.Instance:GetFullName()} avant le SpawnLocation`)
	end
	return `sol à Y = {arrondi(resultat.Position.Y, 2)}, zone mortelle à Y = {workspace.FallenPartsDestroyHeight}`
end)

--------------------------------------------------------------------------------
-- 1 bis. Terrain réaliste : le plan (ServerStorage.PlanTerrain) rejoué pour de vrai
--------------------------------------------------------------------------------

local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local modulePlan = ServerStorage:FindFirstChild("PlanTerrain")
local plan = nil
local terrainGenere = false

lancer("Terrain", "le plan du Terrain se rejoue sans erreur dans le vrai moteur", function(t)
	if not modulePlan then
		ignorer("pas de ServerStorage.PlanTerrain dans cette place")
	end
	plan = require(modulePlan)
	local debut = os.clock()
	local fait, raison = plan.appliquer(workspace.Terrain)
	if not fait then
		error(`appliquer() a échoué : {raison}`)
	end
	terrainGenere = true
	t.vrai(workspace.Terrain:GetAttribute("PlanApplique") == true)
	mesures.terrainOperations = #plan.OPERATIONS
	mesures.terrainSecondes = arrondi(os.clock() - debut, 2)
	return `{#plan.OPERATIONS} opérations en {arrondi(os.clock() - debut, 2)} s`
end)

-- Dans Luau Execution, la physique ne tourne pas : le Terrain n'a pas de
-- collisions et les rayons le traversent (constaté). On lit donc ses voxels
-- (cubes de 4 studs) : matériau et taux de remplissage (0 à 1).
local VOXEL = 4

-- Dessus du Terrain solide (ni air ni eau, sauf `avecEau`) dans la colonne de voxels contenant (x, z).
local function dessusTerrain(x: number, z: number, yMin: number, yMax: number, avecEau: boolean?)
	local x0, z0 = math.floor(x / VOXEL) * VOXEL, math.floor(z / VOXEL) * VOXEL
	local y0, y1 = math.floor(yMin / VOXEL) * VOXEL, math.ceil(yMax / VOXEL) * VOXEL
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + VOXEL, y1, z0 + VOXEL))
	local materiaux, occupations = workspace.Terrain:ReadVoxels(region, VOXEL)
	for iy = occupations.Size.Y, 1, -1 do
		local o, m = occupations[1][iy][1], materiaux[1][iy][1]
		if o > 0.5 and m ~= Enum.Material.Air and (avecEau or m ~= Enum.Material.Water) then
			return y0 + iy * VOXEL, m
		end
	end
	return nil, nil
end

-- Remplissage moyen du Terrain (hors eau) dans une boîte orientée, en voxels.
local function remplissage(cf: CFrame, taille: Vector3): number
	local demi = taille / 2
	local mini, maxi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = (cf * CFrame.new(demi.X * sx, demi.Y * sy, demi.Z * sz)).Position
				mini, maxi = mini:Min(p), maxi:Max(p)
			end
		end
	end
	local region = Region3.new(mini, maxi):ExpandToGrid(VOXEL)
	local materiaux, occupations = workspace.Terrain:ReadVoxels(region, VOXEL)
	local total, n = 0, 0
	for ix = 1, occupations.Size.X do
		for iy = 1, occupations.Size.Y do
			for iz = 1, occupations.Size.Z do
				local centre = region.CFrame.Position - region.Size / 2 + Vector3.new(ix - 0.5, iy - 0.5, iz - 0.5) * VOXEL
				local l = cf:PointToObjectSpace(centre)
				-- seulement les voxels dont le centre est dans la boîte orientée
				if math.abs(l.X) <= demi.X and math.abs(l.Y) <= demi.Y and math.abs(l.Z) <= demi.Z then
					n += 1
					if materiaux[ix][iy][iz] ~= Enum.Material.Water then
						total += occupations[ix][iy][iz]
					end
				end
			end
		end
	end
	return if n > 0 then total / n else 0
end

lancer("Terrain", "chaque île a un sol d'herbe au niveau prévu (lecture des voxels)", function(t)
	if not terrainGenere then
		ignorer("Terrain non généré (test précédent)")
	end
	local MATERIAUX_SOL = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true, [Enum.Material.Water] = true }
	local iles, bilanIles = 0, {}
	for _, op in plan.OPERATIONS do
		if op[1] == "Cylindre" and op[3] == true then
			iles += 1
			local c, hauteur, rayon = op[4], op[5][1], op[5][2]
			local dessus = c[2] + hauteur / 2
			local bons = 0
			for k = 1, 12 do
				local angle = (k / 12) * math.pi * 2
				local x, z = c[1] + math.cos(angle) * rayon * 0.55, c[3] + math.sin(angle) * rayon * 0.55
				local haut, materiau = dessusTerrain(x, z, dessus - 30, dessus + 20, true)
				if haut and MATERIAUX_SOL[materiau] and math.abs(haut - dessus) <= 0.5 then
					bons += 1
				end
			end
			table.insert(bilanIles, `{bons}/12`)
			if bons < 11 then
				error(`île centrée en ({math.floor(c[1])}, {math.floor(c[3])}) : seulement {bons}/12 points d'herbe (ou d'eau) à Y = {dessus}`)
			end
		end
	end
	t.vrai(iles > 0)
	return `{iles} îles, points d'herbe au bon niveau : {table.concat(bilanIles, ", ")}`
end)

lancer("Terrain", "les 50 cristaux ont un sol réel juste dessous (pièces ou Terrain)", function(t)
	if not terrainGenere then
		ignorer("Terrain non généré (test précédent)")
	end
	local dossier = workspace:FindFirstChild("MapIlesCelestes") and workspace.MapIlesCelestes:FindFirstChild("Collectibles")
	t.vrai(dossier ~= nil)
	local parametres = RaycastParams.new()
	parametres.FilterType = Enum.RaycastFilterType.Exclude
	parametres.FilterDescendantsInstances = { dossier }
	parametres.RespectCanCollide = true
	local sansSol, surTerrain, surPieces = {}, 0, 0
	for _, cristal in dossier:GetChildren() do
		-- une sphère de 1 stud de rayon ≈ les pieds d'un personnage (un rayon fin passerait entre deux planches)
		local r = workspace:Spherecast(cristal.Position, 1, Vector3.new(0, -12, 0), parametres)
		local hautTerrain = dessusTerrain(cristal.Position.X, cristal.Position.Z, cristal.Position.Y - 12, cristal.Position.Y, false)
		if r then
			surPieces += 1
		elseif hautTerrain and hautTerrain <= cristal.Position.Y then
			surTerrain += 1
		else
			local p = cristal.Position
			table.insert(sansSol, `({math.floor(p.X)}, {math.floor(p.Y)}, {math.floor(p.Z)})`)
		end
	end
	if #sansSol > 0 then
		error(`{#sansSol} cristal(aux) sans sol à moins de 12 studs : {table.concat(sansSol, " ")}`)
	end
	t.egal(surPieces + surTerrain, #dossier:GetChildren())
	return `{surTerrain} au-dessus du Terrain, {surPieces} au-dessus de pièces (ponts, pierres, grotte…)`
end)

lancer("Terrain", "la grotte secrète et son passage ne sont pas bouchés par le Terrain", function(t)
	if not terrainGenere then
		ignorer("Terrain non généré (test précédent)")
	end
	local ile = workspace.MapIlesCelestes.Iles:FindFirstChild("Ile des Cascades")
	t.vrai(ile ~= nil)
	local sol, palier = nil, nil
	for _, p in ile:GetChildren() do
		if p.Name == "Grotte" and p:IsA("BasePart") then
			if (p.Size - Vector3.new(13, 1, 11)).Magnitude < 0.01 and (not sol or p.Position.Y < sol.Position.Y) then
				sol = p
			elseif (p.Size - Vector3.new(5.5, 0.8, 4.5)).Magnitude < 0.01 then
				palier = p
			end
		end
	end
	t.vrai(sol ~= nil and palier ~= nil)
	local interieur = remplissage(sol.CFrame * CFrame.new(0, 3.8, 0), Vector3.new(11, 6, 9))
	local passage = remplissage(palier.CFrame * CFrame.new(0, 7, 0), Vector3.new(5, 12, 4))
	mesures.grotteRemplissageTerrain = arrondi(interieur, 2)
	mesures.passageRemplissageTerrain = arrondi(passage, 2)
	if interieur > 0.2 then
		error(`intérieur de la grotte rempli à {math.floor(interieur * 100)} % par le Terrain`)
	end
	if passage > 0.2 then
		error(`passage vers le palier rempli à {math.floor(passage * 100)} % par le Terrain`)
	end
	-- et aucune pièce ne bloque la chute vers le palier
	local parametres = RaycastParams.new()
	parametres.RespectCanCollide = true
	local r = workspace:Raycast(palier.Position + Vector3.new(0, 20, 0), Vector3.new(0, -25, 0), parametres)
	if not r or r.Instance ~= palier then
		error(`la chute vers le palier est bloquée par {if r then r.Instance:GetFullName() else "rien ?"}`)
	end
	return `Terrain : grotte remplie à {math.floor(interieur * 100)} %, passage à {math.floor(passage * 100)} % ; chute libre jusqu'au palier`
end)

lancer("Terrain", "éclairage réaliste actif (lumière tirée du ciel, herbe animée)", function(t)
	mesures.environmentDiffuseScale = Lighting.EnvironmentDiffuseScale
	mesures.environmentSpecularScale = Lighting.EnvironmentSpecularScale
	t.egal(Lighting.EnvironmentDiffuseScale, 1)
	t.egal(Lighting.EnvironmentSpecularScale, 1)
	local okTech, technologie = pcall(function()
		return Lighting.Technology
	end)
	mesures.technologie = if okTech then technologie.Name else "illisible ici"
	if okTech then
		t.egal(technologie, Enum.Technology.Future)
	end
	local okDeco, decoration = pcall(function()
		return workspace.Terrain.Decoration
	end)
	if okDeco then
		t.egal(decoration, true)
	end
	return `Technology {mesures.technologie}, EnvironmentDiffuse/Specular 1/1, herbe animée {if okDeco then tostring(decoration) else "illisible ici"}`
end)

--------------------------------------------------------------------------------
-- 2. Les tests du noyau (pipeline/tests/noyau.test.luau) dans le vrai Luau
--------------------------------------------------------------------------------

if testsNoyau then
	local okChargement, suite = pcall(testsNoyau)
	if okChargement then
		local noms = {}
		for nom in suite do
			table.insert(noms, nom)
		end
		table.sort(noms)
		for _, nom in noms do
			lancer("Noyau", nom, function(t)
				suite[nom](t)
				return nil
			end)
		end
	else
		lancer("Noyau", "chargement des tests du noyau", function()
			error(suite)
		end)
	end
else
	lancer("Noyau", "tests du noyau", function()
		ignorer("script envoyé sans les tests du noyau (opencloud.py ne les a pas insérés)")
	end)
end

--------------------------------------------------------------------------------
-- 3. Le module Sauvegarde sur un VRAI DataStore (DataStore séparé, clé supprimée)
--------------------------------------------------------------------------------

lancer("DataStore réel", "sauvegarde, verrou de session entre 2 serveurs, libération", function(t)
	local Sauvegarde = require(Noyau.Sauvegarde)
	local okStore, store = pcall(function()
		return DataStoreService:GetDataStore("Tests_Pipeline")
	end)
	if not okStore then
		ignorer(`DataStoreService indisponible : {store}`)
	end
	local cle = "test_" .. HttpService:GenerateGUID(false)
	local function serveur(jobId: string)
		return Sauvegarde.nouveau(store, {
			jobId = jobId,
			maintenant = os.time,
			attendre = task.wait,
			essaisChargement = 2,
			attenteVerrou = 1,
			essaisSauvegarde = 2,
		})
	end
	local A, B = serveur("serveur-A"), serveur("serveur-B")

	local debut = os.clock()
	local okTest, erreur = pcall(function()
		local donnees, err = A:charger(cle)
		if err and string.sub(err, 1, 7) == "erreur:" then
			ignorer(`DataStore inaccessible depuis Luau Execution : {err}`)
		end
		t.egal(err, nil)
		t.egal(donnees, nil) -- nouveau joueur
		t.vrai(A:sauvegarder(cle, { monnaie = 42 }, false))

		local d2, err2 = B:charger(cle) -- A tient le verrou
		t.egal(d2, nil)
		t.egal(err2, "verrouille")

		t.vrai(A:sauvegarder(cle, { monnaie = 43 }, true)) -- départ du joueur : verrou rendu
		local d3, err3 = B:charger(cle)
		t.egal(err3, nil)
		t.egal(d3 and d3.monnaie, 43)

		t.faux(A:sauvegarder(cle, { monnaie = 0 }, false)) -- A n'a plus le verrou : refus
		local brut = store:GetAsync(cle)
		t.egal(brut.donnees.monnaie, 43)
		t.egal(brut.verrou.jobId, "serveur-B")
	end)
	local okNettoyage = pcall(function()
		store:RemoveAsync(cle)
	end)
	if not okTest then
		error(erreur, 0)
	end
	mesures.dureeTestDataStore = arrondi(os.clock() - debut, 2)
	return `clé {cle} {if okNettoyage then "supprimée" else "NON supprimée"} ; {arrondi(os.clock() - debut, 1)} s`
end)

--------------------------------------------------------------------------------
-- 4. La boutique : les IDs de Configuration sont de vrais objets Roblox
--------------------------------------------------------------------------------

do
	local okConfig, Configuration = pcall(require, configModule)
	local objets = {}
	if okConfig then
		for _, pass in Configuration.PASSES do
			table.insert(objets, { objet = pass, type = Enum.InfoType.GamePass, genre = "pass" })
		end
		for _, produit in Configuration.PRODUITS do
			table.insert(objets, { objet = produit, type = Enum.InfoType.Product, genre = "produit" })
		end
	end
	for _, o in objets do
		lancer("Boutique", `{o.genre} « {o.objet.nom} » (id {o.objet.id}) en vente au prix prévu`, function(t)
			local ok, infos = pcall(function()
				return MarketplaceService:GetProductInfo(o.objet.id, o.type)
			end)
			if not ok then
				ignorer(`GetProductInfo indisponible ici : {infos}`)
			end
			t.vrai(type(infos) == "table")
			if infos.IsForSale ~= nil then
				t.egal(infos.IsForSale, true)
			end
			if o.objet.prix then
				t.egal(infos.PriceInRobux, o.objet.prix)
			end
			return `« {infos.Name} », {infos.PriceInRobux} Robux, en vente : {tostring(infos.IsForSale)}`
		end)
	end
end

--------------------------------------------------------------------------------
-- 5. Démarrage réel des scripts serveur (s'ils peuvent tourner ici)
--------------------------------------------------------------------------------

local erreursJournal = {}
local messagesJournal = {}
local connexion = LogService.MessageOut:Connect(function(message, typeMessage)
	table.insert(messagesJournal, message)
	if typeMessage == Enum.MessageType.MessageError then
		table.insert(erreursJournal, message)
	end
end)

local function demarrerCopie(nom: string): Script?
	local original = ServerScriptService:FindFirstChild(nom)
	if not original then
		return nil
	end
	local copie = original:Clone()
	copie.Name = nom .. "_TestMoteurReel"
	copie.Enabled = true
	copie.Parent = ServerScriptService
	return copie
end

local function erreursDe(nomScript: string): { string }
	local liste = {}
	for _, message in erreursJournal do
		if string.find(message, nomScript, 1, true) then
			table.insert(liste, message)
		end
	end
	return liste
end

lancer("Scripts serveur", "Principal démarre sans erreur et branche le DataStore", function(t)
	local copie = demarrerCopie("Principal")
	t.vrai(copie ~= nil)
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	local erreurs = erreursDe("Principal_TestMoteurReel")
	if #erreurs > 0 then
		error(table.concat(erreurs, " | "))
	end
	if not remotes then
		ignorer("le script cloné n'a pas démarré en 10 s (les scripts ne tournent pas dans Luau Execution)")
	end
	for _, nom in { "EtatJoueur", "ReclamerRecompense", "MiseAJour" } do
		if not remotes:FindFirstChild(nom) then
			error(`Remote manquant : {nom}`)
		end
	end
	local pret = nil
	local debut = os.clock()
	while not pret and os.clock() - debut < 10 do
		for _, message in messagesJournal do
			if string.find(message, "[Noyau] Prêt", 1, true) then
				pret = message
			end
		end
		if not pret then
			task.wait(0.2)
		end
	end
	t.vrai(pret ~= nil)
	t.vrai(string.find(pret, "DataStore", 1, true) ~= nil) -- et pas « en mémoire »
	return pret
end)

lancer("Scripts serveur", "script de la map démarre sans erreur et anime les cristaux", function(t)
	local map = workspace:FindFirstChild("MapIlesCelestes")
	local collectibles = map and map:FindFirstChild("Collectibles")
	t.vrai(collectibles ~= nil)
	local cristal = collectibles:FindFirstChildWhichIsA("BasePart")
	local avant = cristal.CFrame
	local copie = demarrerCopie("IlesCelestes_Script")
	t.vrai(copie ~= nil)
	task.wait(3)
	local erreurs = erreursDe("IlesCelestes_Script_TestMoteurReel")
	if #erreurs > 0 then
		error(table.concat(erreurs, " | "))
	end
	if cristal.CFrame == avant then
		ignorer("aucun mouvement en 3 s : script non démarré ou Heartbeat arrêté dans cet environnement")
	end
	return "cristal déplacé de " .. arrondi((cristal.Position - avant.Position).Magnitude, 2) .. " studs en 3 s"
end)

connexion:Disconnect()
mesures.erreursJournal = #erreursJournal

--------------------------------------------------------------------------------
-- Bilan (renvoyé en JSON par Luau Execution)
--------------------------------------------------------------------------------

local bilan = { reussis = 0, echoues = 0, ignores = 0, tests = tests, mesures = mesures }
for _, test in tests do
	if test.statut == "ok" then
		bilan.reussis += 1
	elseif test.statut == "echec" then
		bilan.echoues += 1
	else
		bilan.ignores += 1
	end
end
print(`Bilan : {bilan.reussis} réussi(s), {bilan.echoues} échoué(s), {bilan.ignores} non vérifiable(s)`)
return bilan
