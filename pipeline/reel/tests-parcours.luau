--[[
	Tests dans le VRAI moteur Roblox d'un jeu de la Fabrique (formats « tour »
	et « evasion »), via l'API Open Cloud « Luau Execution » :
	    python3 pipeline/opencloud.py tester --map <nom-du-jeu>

	Même environnement et mêmes limites que pipeline/reel/tests.luau : la
	physique ne tourne pas, les scripts de la place ne démarrent pas d'eux-mêmes
	et il n'y a pas de joueur. On vérifie donc ici ce que le moteur simulé ne
	peut pas garantir :
	- le fichier construit hors de Roblox est bien relu à l'identique par Roblox ;
	- chaque borne, le départ et l'arrivée ont un vrai sol dessous (lancer de rayon) ;
	- les fonctions du moteur dont dépend le script de jeu existent et font ce
	  qu'on attend (PivotTo, GetPartsInPart, vitesse d'un tapis ancré…) ;
	- le script de jeu lui-même s'exécute sans erreur jusqu'au bout.
	Le parcours joueur (contacts, mort, victoire, sauvegarde) reste couvert par
	pipeline/tests/fabrique.test.luau, dans le moteur simulé.

	Avant l'envoi, opencloud.py remplace les lignes marquées --@@ :
	- ATTENDU : chiffres du rapport du validateur, version et place attendues ;
	- scriptDeJeu : fabrique/gabarits/jeu.server.lua, tel quel, dans une fonction.

	Statuts : ok, echec, ignore (« ignore » = impossible à vérifier ici ; ce n'est PAS réussi).
]]

local LogService = game:GetService("LogService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local ATTENDU = nil --@@ATTENDU@@
local scriptDeJeu: (() -> ())? = nil --@@SCRIPT_JEU@@

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

local map = workspace:FindFirstChild("Parcours")

-- Sol réel sous un point : lancer de rayon vers le bas, en ignorant les zones invisibles et les gemmes.
local function solSous(position: Vector3, profondeur: number)
	local parametres = RaycastParams.new()
	parametres.FilterType = Enum.RaycastFilterType.Exclude
	parametres.FilterDescendantsInstances = { map.Etapes, map.Collectibles, map.Dangers, map:FindFirstChild("Arrivee") }
	parametres.RespectCanCollide = true -- on cherche un sol où l'on tient debout, pas un décor traversable
	return workspace:Raycast(position, Vector3.new(0, -profondeur, 0), parametres)
end

--------------------------------------------------------------------------------
-- 1. La place chargée par Roblox est bien celle construite par le pipeline
--------------------------------------------------------------------------------

lancer("Place", "c'est la version qui vient d'être envoyée", function(t)
	if ATTENDU and ATTENDU.placeId then
		t.egal(game.PlaceId, ATTENDU.placeId)
	end
	if ATTENDU and ATTENDU.placeVersion then
		t.egal(game.PlaceVersion, ATTENDU.placeVersion)
	end
	return `place {game.PlaceId}, version {game.PlaceVersion}`
end)

lancer("Place", "le jeu de la Fabrique est là, avec ses dossiers et son script", function(t)
	t.vrai(map ~= nil)
	for _, nom in { "Structure", "Decor", "Etapes", "Collectibles", "Dangers", "Mobiles", "Fragiles", "Tapis" } do
		t.vrai(map:FindFirstChild(nom) ~= nil)
	end
	t.vrai(map:FindFirstChild("Depart") and map.Depart:IsA("SpawnLocation"))
	t.vrai(map:FindFirstChild("Arrivee") ~= nil)
	local scriptJeu = game:GetService("ServerScriptService"):FindFirstChild("Parcours_Jeu")
	t.vrai(scriptJeu and scriptJeu:IsA("Script"))
	t.vrai(game:GetService("ServerScriptService"):FindFirstChild("Noyau") ~= nil)
	if ATTENDU and ATTENDU.nom then
		t.egal(map:GetAttribute("Nom"), ATTENDU.nom)
	end
	return `{map:GetAttribute("Titre")} — format {map:GetAttribute("Format")}, thème {map:GetAttribute("Theme")}, {map:GetAttribute(
		"NombreEtapes"
	)} étapes`
end)

lancer("Place", "contenu identique au fichier construit (comptages du validateur)", function(_t)
	if not ATTENDU or not ATTENDU.pieces then
		ignorer("pas de rapport du validateur pour ce jeu")
	end
	local compte = {
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
				compte.pieces += 1
				if objet:GetAttribute("Collectible") == true or aUnAncetreNomme(objet, "Collectibles") then
					compte.collectibles += 1
				end
				if objet:IsA("SpawnLocation") then
					compte.spawns += 1
				end
				if not objet.Anchored then
					compte.piecesNonAncrees += 1
				end
			elseif objet:IsA("Light") then
				compte.lumieres += 1
			elseif objet:IsA("ParticleEmitter") then
				compte.emetteursParticules += 1
			elseif objet:IsA("Sound") then
				compte.sons += 1
			end
		end
	end
	for cle, valeur in compte do
		mesures[cle] = valeur
		if ATTENDU[cle] ~= nil and ATTENDU[cle] ~= valeur then
			error(`{cle} : {valeur} dans Roblox, {ATTENDU[cle]} d'après le validateur`)
		end
	end
	return `{compte.pieces} pièces, {compte.collectibles} gemmes, {compte.lumieres} lumières, {compte.spawns} spawn`
end)

lancer("Place", "matériaux, tailles et attributs relus tels qu'ils ont été écrits", function(t)
	local materiaux, nbMateriaux = {}, 0
	local plusGrande = 0
	for _, objet in map:GetDescendants() do
		if objet:IsA("BasePart") then
			if not materiaux[objet.Material] then
				materiaux[objet.Material] = true
				nbMateriaux += 1
			end
			plusGrande = math.max(plusGrande, objet.Size.X, objet.Size.Y, objet.Size.Z)
		end
	end
	t.vrai(nbMateriaux >= 5) -- un fichier mal relu retomberait sur le matériau par défaut partout
	t.vrai(plusGrande <= 2048)
	mesures.plusGrandePiece = arrondi(plusGrande, 1)
	for _, zone in map.Etapes:GetChildren() do
		t.egal(type(zone:GetAttribute("Numero")), "number")
		t.faux(zone.CanCollide)
		t.egal(zone.Transparency, 1)
	end
	for _, tapis in map.Tapis:GetChildren() do
		t.egal(typeof(tapis:GetAttribute("VitesseTapis")), "Vector3")
	end
	for _, gemme in map.Collectibles:GetChildren() do
		t.egal(type(gemme:GetAttribute("Valeur")), "number")
	end
	t.egal(map.Depart.Duration, 0)
	t.vrai(map.Depart.Neutral)
	return `{nbMateriaux} matériaux différents, plus grande pièce : {arrondi(plusGrande, 1)} studs`
end)

lancer("Place", "ambiance du thème en place (atmosphère, nuages, étalonnage)", function(t)
	t.vrai(Lighting:FindFirstChild("Fab_Atmosphere") ~= nil)
	t.vrai(Lighting:FindFirstChild("Fab_Bloom") ~= nil)
	t.vrai(Lighting:FindFirstChild("Fab_Couleurs") ~= nil)
	t.vrai(workspace.Terrain:FindFirstChildOfClass("Clouds") ~= nil)
	local okTechno, techno = pcall(function()
		return Lighting.Technology.Name
	end)
	mesures.technologie = if okTechno then techno else "illisible ici"
	return `heure {arrondi(Lighting.ClockTime, 1)}, technologie {mesures.technologie}`
end)

lancer("Place", "textes des arches lisibles (numéros d'étape sur les linteaux)", function(t)
	local numeros = {}
	for _, objet in map.Decor:GetDescendants() do
		if objet:IsA("TextLabel") and tonumber(objet.Text) then
			numeros[tonumber(objet.Text)] = true
		end
	end
	local nb = map:GetAttribute("NombreEtapes")
	for n = 1, nb - 1 do
		t.vrai(numeros[n])
	end
	return `arches numérotées de 1 à {nb - 1}`
end)

--------------------------------------------------------------------------------
-- 2. Géométrie réelle : un vrai sol sous chaque point clé
--------------------------------------------------------------------------------

lancer("Géométrie", "point d'apparition : sol réel juste dessous, au-dessus de la zone mortelle", function(t)
	local position = map.Depart.Position
	t.vrai(position.Y > workspace.FallenPartsDestroyHeight)
	local parametres = RaycastParams.new()
	parametres.FilterType = Enum.RaycastFilterType.Exclude
	parametres.FilterDescendantsInstances = { map.Depart, map.Dangers }
	parametres.RespectCanCollide = true
	local sol = workspace:Raycast(position, Vector3.new(0, -6, 0), parametres)
	t.vrai(sol ~= nil)
	t.vrai(sol.Instance.CanCollide)
	return `sol « {sol.Instance.Name} » à Y = {arrondi(sol.Position.Y, 1)}, zone mortelle à Y = {workspace.FallenPartsDestroyHeight}`
end)

lancer("Géométrie", "chaque borne d'étape est posée sur un vrai sol", function(t)
	local nb = 0
	for _, zone in map.Etapes:GetChildren() do
		local sol = solSous(zone.Position, 8)
		if not sol or not sol.Instance.CanCollide then
			error(`pas de sol sous {zone.Name}`)
		end
		nb += 1
	end
	t.egal(nb, map:GetAttribute("NombreEtapes") - 1)
	return `{nb} bornes, chacune sur un sol solide`
end)

lancer("Géométrie", "la zone d'arrivée est posée sur l'estrade", function(t)
	local sol = solSous(map.Arrivee.Position, 8)
	t.vrai(sol ~= nil)
	t.vrai(sol.Instance.CanCollide)
	return `sol « {sol.Instance.Name} »`
end)

lancer("Géométrie", "chaque gemme a un sol réel à portée en dessous", function(_t)
	local nb, plusLoin = 0, 0
	for _, gemme in map.Collectibles:GetChildren() do
		local sol = solSous(gemme.Position, 14)
		if not sol or not sol.Instance.CanCollide then
			error(
				`pas de sol sous la gemme en ({arrondi(gemme.Position.X, 0)}, {arrondi(gemme.Position.Y, 0)}, {arrondi(
					gemme.Position.Z,
					0
				)})`
			)
		end
		plusLoin = math.max(plusLoin, gemme.Position.Y - sol.Position.Y)
		nb += 1
	end
	return `{nb} gemmes, la plus haute à {arrondi(plusLoin, 1)} studs du sol`
end)

lancer("Géométrie", "les pièges mortels ne sont pas solides, les sols le sont", function(t)
	local dangers = 0
	for _, danger in map.Dangers:GetChildren() do
		t.faux(danger.CanCollide)
		t.vrai(danger.CanTouch)
		dangers += 1
	end
	for _, dalle in map.Fragiles:GetChildren() do
		t.vrai(dalle.CanCollide)
	end
	return `{dangers} pièges`
end)

--------------------------------------------------------------------------------
-- 3. Fonctions du moteur dont dépend le script de jeu
--------------------------------------------------------------------------------

lancer("Moteur", "PivotTo déplace un personnage entier sur une borne", function(t)
	local perso = Instance.new("Model")
	local racine = Instance.new("Part")
	racine.Name = "HumanoidRootPart"
	racine.Anchored = true
	racine.Parent = perso
	local tete = Instance.new("Part")
	tete.Name = "Head"
	tete.Anchored = true
	tete.CFrame = CFrame.new(0, 1.5, 0)
	tete.Parent = perso
	perso.PrimaryPart = racine
	perso.Parent = workspace
	local zone = map.Etapes:FindFirstChildWhichIsA("BasePart")
	local cible = zone.CFrame * CFrame.new(0, 1, 2)
	perso:PivotTo(cible)
	local ecartRacine = (racine.Position - cible.Position).Magnitude
	local ecartTete = (tete.Position - (cible.Position + Vector3.new(0, 1.5, 0))).Magnitude
	perso:Destroy()
	t.vrai(ecartRacine < 0.01)
	t.vrai(ecartTete < 0.01)
	return "racine et tête déplacées ensemble"
end)

lancer("Moteur", "GetPartsInPart voit une pièce qui recouvre une barre ou un piège", function(t)
	local piege = map.Dangers:FindFirstChild("Barre") or map.Dangers:FindFirstChild("Braise")
	if not piege then
		ignorer("ce parcours n'a ni barre ni braise")
	end
	local temoin = Instance.new("Part")
	temoin.Name = "TemoinTest"
	temoin.Anchored = true
	temoin.Size = Vector3.new(2, 2, 2)
	temoin.CFrame = piege.CFrame
	temoin.Parent = workspace
	local touches = workspace:GetPartsInPart(piege)
	local vu = false
	for _, piece in touches do
		if piece == temoin then
			vu = true
		end
	end
	temoin:Destroy()
	t.egal(type(touches), "table")
	if not vu then
		ignorer("GetPartsInPart existe mais ne renvoie rien ici (la physique ne tourne pas dans cet environnement)")
	end
	return `pièce témoin détectée dans « {piege.Name} »`
end)

lancer("Moteur", "un tapis ancré accepte une vitesse (AssemblyLinearVelocity)", function(t)
	local tapis = map.Tapis:FindFirstChildWhichIsA("BasePart")
	if not tapis then
		ignorer("ce parcours n'a pas de tapis roulant")
	end
	t.vrai(tapis.Anchored)
	local vitesse = tapis:GetAttribute("VitesseTapis")
	tapis.AssemblyLinearVelocity = vitesse
	local relue = tapis.AssemblyLinearVelocity
	tapis.AssemblyLinearVelocity = Vector3.zero
	t.vrai((relue - vitesse).Magnitude < 0.01)
	return `vitesse {arrondi(vitesse.Magnitude, 1)} studs/s acceptée et relue`
end)

lancer("Moteur", "Humanoid : mettre la vie à 0, et annonce dans un PlayerGui", function(t)
	local perso = Instance.new("Model")
	local humanoide = Instance.new("Humanoid")
	humanoide.Parent = perso
	t.vrai(humanoide.Health > 0)
	humanoide.Health = 0
	t.egal(humanoide.Health, 0)
	perso:Destroy()
	local ecran = Instance.new("ScreenGui")
	ecran.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "✔ 1 / 10"
	label.Parent = ecran
	ecran:Destroy()
	return "ok"
end)

--------------------------------------------------------------------------------
-- 4. Le script de jeu, exécuté tel quel dans le vrai interpréteur
--------------------------------------------------------------------------------

local erreursJournal = {}
local connexion = LogService.MessageOut:Connect(function(message, genre)
	if genre == Enum.MessageType.MessageError then
		table.insert(erreursJournal, message)
	end
end)

lancer("Script de jeu", "s'exécute jusqu'au bout sans erreur dans le vrai moteur", function(t)
	if not scriptDeJeu then
		ignorer("script de jeu non fourni")
	end
	local tapis = map.Tapis:FindFirstChildWhichIsA("BasePart")
	local termine, erreur = false, nil
	task.spawn(function()
		local ok, message = pcall(scriptDeJeu)
		termine, erreur = ok, if ok then nil else tostring(message)
	end)
	local debut = os.clock()
	while not termine and not erreur and os.clock() - debut < 15 do
		task.wait(0.2)
	end
	if erreur then
		error(erreur)
	end
	t.vrai(termine)
	if #erreursJournal > 0 then
		error(table.concat(erreursJournal, " | "))
	end
	if tapis then
		-- Le script donne leur vitesse aux tapis à son démarrage : preuve qu'il a bien tourné.
		t.vrai((tapis.AssemblyLinearVelocity - tapis:GetAttribute("VitesseTapis")).Magnitude < 0.01)
		return "terminé en " .. arrondi(os.clock() - debut, 1) .. " s ; tapis mis en vitesse par le script"
	end
	return "terminé en " .. arrondi(os.clock() - debut, 1) .. " s"
end)

lancer("Script de jeu", "les animations tournent (barres, gemmes) sans erreur", function(t)
	local gemme = map.Collectibles:FindFirstChildWhichIsA("BasePart")
	local avant = gemme.CFrame
	local images = 0
	local ecoute = RunService.Heartbeat:Connect(function()
		images += 1
	end)
	task.wait(3)
	ecoute:Disconnect()
	if #erreursJournal > 0 then
		error(table.concat(erreursJournal, " | "))
	end
	mesures.imagesEn3s = images
	if images == 0 then
		ignorer("Heartbeat ne tourne pas dans cet environnement")
	end
	t.vrai(gemme.CFrame ~= avant)
	return `{images} images en 3 s, la gemme a bougé de {arrondi((gemme.Position - avant.Position).Magnitude, 2)} studs`
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
