--------------------------------------------------------------------------------
-- ✦ Escape The Candy Run ✦
--
-- Jeu Roblox créé par la Fabrique (fabrique/README.md).
-- Format : evasion · thème : Bonbon · graine : 77 · étapes : 10
-- Tendances : 21 relevés des classements Roblox, du 2026-10-31 au 2026-11-13 (recherche/rapport-niche.md).
--
-- NE PAS MODIFIER À LA MAIN : ce fichier est réécrit par la Fabrique. Pour le
-- changer, modifier fabrique/gabarits/ ou fabrique/themes.luau puis relancer :
--   lune run fabrique/creer -- --format evasion --theme bonbon --graine 77 --etapes 10 --remplacer
--
-- UTILISATION DANS STUDIO : View → Command Bar, coller TOUT ce script, Entrée, puis Play.
-- Relancer le script reconstruit la map proprement (l'ancienne est supprimée).
--------------------------------------------------------------------------------

local FABRIQUE = {
	etapes = 10,
	format = "evasion",
	graine = 77,
	nom = "evasion-bonbon",
	theme = {
		cle = "bonbon",
		couleurs = {
			accent = { 255, 108, 168 },
			accent2 = { 120, 226, 204 },
			bois = { 146, 96, 70 },
			danger = { 226, 52, 86 },
			piece = { 255, 214, 84 },
			sol = { 255, 196, 216 },
			solAlt = { 190, 232, 255 },
			structure = { 236, 190, 138 },
			structureAlt = { 126, 80, 60 },
			vegetal = { 140, 222, 150 },
		},
		decor = {
			arbre = "sucette",
			lampe = "sucre",
			special = "gateau",
		},
		dessous = {
			couleur = "accent",
			genre = "pointes",
			materiau = "SmoothPlastic",
		},
		emoji = "🍭",
		heure = 13.2,
		lumiere = {
			ambiance = { 176, 160, 176 },
			atmosphere = {
				brume = 1,
				couleur = { 255, 222, 236 },
				decalage = 0.3,
				declin = { 226, 190, 240 },
				densite = 0.28,
				eblouissement = 0.15,
			},
			bloom = {
				intensite = 0.3,
				seuil = 1.4,
				taille = 20,
			},
			correction = {
				contraste = 0.04,
				saturation = 0.18,
				teinte = { 255, 246, 250 },
			},
			exterieur = { 196, 180, 190 },
			luminosite = 3,
			nuages = {
				couleur = { 255, 232, 244 },
				couverture = 0.58,
				densite = 0.28,
			},
		},
		materiaux = {
			bois = "Wood",
			sol = "SmoothPlastic",
			solAlt = "SmoothPlastic",
			structure = "SmoothPlastic",
			structureAlt = "Plastic",
		},
		motsTendance = { "candy", "sweet", "sugar" },
		motsTitre = { "Candy", "Sweet", "Sugar" },
		nom = "Bonbon",
		vide = {
			couleur = { 255, 150, 196 },
			genre = "sirop",
			materiau = "SmoothPlastic",
			transparence = 0,
		},
	},
	titre = "Escape The Candy Run",
}

local SOURCE_JEU = [==[
-- Script de jeu d'un parcours de la Fabrique (installé par le script de construction).
-- Gère : étapes sauvegardées, retour à la dernière borne (chute ou mort), pièges,
-- gemmes, reliques secrètes, chronomètre et record, victoire, traînée des vainqueurs.
--
-- Avec le noyau commun (build du pipeline avec --src src) : les gemmes vont dans
-- le profil sauvegardé du joueur, et l'étape atteinte, les victoires, le record et
-- les reliques trouvées sont conservés entre deux visites. Sans lui (script collé
-- seul dans Studio) : tout marche, sans sauvegarde.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local map = workspace:WaitForChild("Parcours")
local dossierEtapes = map:WaitForChild("Etapes")
local dossierGemmes = map:WaitForChild("Collectibles")
local dossierSecrets = map:WaitForChild("Secrets")
local dossierBijoux = map:WaitForChild("Bijoux")
local dossierDangers = map:WaitForChild("Dangers")
local dossierFragiles = map:WaitForChild("Fragiles")
local dossierTapis = map:WaitForChild("Tapis")
local depart = map:WaitForChild("Depart")
local arrivee = map:WaitForChild("Arrivee")
local ligneDepart = map:FindFirstChild("LigneDepart")

local NOM_JEU = map:GetAttribute("Nom") or "parcours"
local NB_ETAPES = map:GetAttribute("NombreEtapes") or 1
local NB_SECRETS = map:GetAttribute("NombreSecrets") or 0
local MARGE_CHUTE = map:GetAttribute("MargeChute") or 14 -- tombé plus bas que ça sous sa borne : retour à la borne
local TEMPS_REAPPARITION = 25 -- secondes avant qu'une gemme revienne
local DELAI_FRAGILE = 3 -- secondes entre le premier pas sur une dalle de verre et sa disparition
local ABSENCE_FRAGILE = 2.5
local GAIN_ETAPE = 3
local GAIN_VICTOIRE = 50
local GAIN_SECRET = 15
local GAIN_TOUS_SECRETS = 100
-- Traînée derrière le joueur selon ses victoires : une raison visible de regagner.
local TRAINEES = {
	{ victoires = 10, couleurs = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 220, 80), Color3.fromRGB(80, 220, 255) } },
	{ victoires = 5, couleurs = { Color3.fromRGB(255, 205, 80), Color3.fromRGB(255, 240, 180) } },
	{ victoires = 3, couleurs = { Color3.fromRGB(200, 210, 225), Color3.fromRGB(255, 255, 255) } },
	{ victoires = 1, couleurs = { Color3.fromRGB(205, 127, 50), Color3.fromRGB(240, 190, 140) } },
}

local dossierNoyau = game:GetService("ServerScriptService"):FindFirstChild("Noyau")
local API = dossierNoyau and dossierNoyau:FindFirstChild("API") and require(dossierNoyau.API)

local bornes = {} -- [numéro] = zone de contact de l'étape
for _, zone in ipairs(dossierEtapes:GetChildren()) do
	local numero = zone:GetAttribute("Numero")
	if numero then
		bornes[numero] = zone
	end
end

--------------------------------------------------------------------------------
-- Progression de chaque joueur
--------------------------------------------------------------------------------

local progressions = {} -- [joueur] = { jeu, etape, victoires, record, secrets }
local sauvegardees = {} -- [joueur] = true quand la progression est celle du profil sauvegardé
local enVictoire = {}
local debutCourse = {} -- [joueur] = heure de passage de la ligne de départ (course complète en cours)

local function nouvelleProgression()
	return { jeu = NOM_JEU, etape = 0, victoires = 0, record = 0, secrets = {} }
end

local function progression(joueur)
	local p = progressions[joueur]
	if not p then
		p = nouvelleProgression()
		progressions[joueur] = p
	end
	if API and not sauvegardees[joueur] then
		local donnees = API.donneesJeu(joueur)
		if donnees then
			local garde = donnees.parcours
			if type(garde) ~= "table" or garde.jeu ~= NOM_JEU then
				-- Première visite, ou sauvegarde d'un autre parcours publié dans la même expérience.
				local victoires = (type(garde) == "table") and tonumber(garde.victoires) or 0
				garde = nouvelleProgression()
				garde.victoires = victoires or 0
			end
			garde.etape = math.clamp(math.max(tonumber(garde.etape) or 0, p.etape), 0, NB_ETAPES - 1)
			garde.victoires = (tonumber(garde.victoires) or 0) + p.victoires
			garde.record = tonumber(garde.record) or 0
			if p.record > 0 and (garde.record == 0 or p.record < garde.record) then
				garde.record = p.record
			end
			if type(garde.secrets) ~= "table" then
				garde.secrets = {}
			end
			for cle in pairs(p.secrets) do
				garde.secrets[cle] = true
			end
			donnees.parcours = garde
			progressions[joueur] = garde
			sauvegardees[joueur] = true
			p = garde
		end
	end
	return p
end

local function nbSecrets(p)
	local n = 0
	for _ in pairs(p.secrets) do
		n += 1
	end
	return n
end

local function valeurStat(joueur, nom)
	local stats = joueur:FindFirstChild("leaderstats")
	if not stats then
		if API then
			return nil -- le noyau crée le dossier quand le profil est chargé
		end
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = joueur
	end
	local valeur = stats:FindFirstChild(nom)
	if not valeur then
		valeur = Instance.new("IntValue")
		valeur.Name = nom
		valeur.Parent = stats
	end
	return valeur
end

local function majStats(joueur)
	local p = progression(joueur)
	local valeurs = { ["Étape"] = p.etape, Victoires = p.victoires, ["Record (s)"] = math.ceil(p.record), Secrets = nbSecrets(p) }
	for nom, nombre in pairs(valeurs) do
		local valeur = valeurStat(joueur, nom)
		if valeur then
			valeur.Value = nombre
		end
	end
end

local function crediter(joueur, montant, raison)
	if API then
		API.ajouterMonnaie(joueur, montant, raison)
	else
		local gemmes = valeurStat(joueur, "Gemmes")
		if gemmes then
			gemmes.Value += montant
		end
	end
end

-- Message bref en haut de l'écran du joueur.
local function annoncer(joueur, texte)
	local gui = joueur:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return
	end
	local ancien = gui:FindFirstChild("AnnonceParcours")
	if ancien then
		ancien:Destroy()
	end
	local ecran = Instance.new("ScreenGui")
	ecran.Name = "AnnonceParcours"
	ecran.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0.14, 0)
	label.Size = UDim2.new(0.6, 0, 0.09, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = texte
	label.TextColor3 = Color3.fromRGB(255, 240, 190)
	label.TextStrokeColor3 = Color3.fromRGB(30, 24, 30)
	label.TextStrokeTransparency = 0.2
	label.Parent = ecran
	ecran.Parent = gui
	task.delay(2.5, function()
		if ecran.Parent then
			ecran:Destroy()
		end
	end)
end

local function effet(zone, nb)
	local son = zone:FindFirstChildOfClass("Sound")
	if son then
		son:Play()
	end
	local eclat = zone:FindFirstChildOfClass("ParticleEmitter")
	if eclat then
		eclat:Emit(nb)
	end
end

local function chrono(secondes)
	local minutes = math.floor(secondes / 60)
	return string.format("%d:%04.1f", minutes, secondes - minutes * 60)
end

--------------------------------------------------------------------------------
-- Retour à la dernière borne : après une mort, et après une chute
--------------------------------------------------------------------------------

-- Où le joueur doit se retrouver : au-dessus de sa dernière borne, sinon au départ.
local function retour(joueur)
	local zone = bornes[progression(joueur).etape]
	if zone then
		return zone.CFrame * CFrame.new(0, 1, 2)
	end
	return depart.CFrame * CFrame.new(0, 4, 0)
end

local function envoyer(perso, cible)
	local racine = perso:FindFirstChild("HumanoidRootPart")
	if not racine then
		return
	end
	-- PivotTo déplace tout le personnage ; à défaut, on déplace sa pièce racine.
	if not pcall(function()
		perso:PivotTo(cible)
	end) then
		racine.CFrame = cible
	end
	pcall(function()
		racine.AssemblyLinearVelocity = Vector3.zero -- sinon il garde sa vitesse de chute
	end)
end

-- Traînée des vainqueurs, accrochée au personnage.
local function poserTrainee(joueur, perso)
	local racine = perso:FindFirstChild("HumanoidRootPart")
	if not racine then
		return
	end
	local ancienne = racine:FindFirstChild("TraineeVictoire")
	if ancienne then
		ancienne:Destroy()
	end
	local victoires = progression(joueur).victoires
	for _, palier in ipairs(TRAINEES) do
		if victoires >= palier.victoires then
			pcall(function()
				local haut = Instance.new("Attachment")
				haut.Name = "TraineeHaut"
				haut.Position = Vector3.new(0, 0.9, 0)
				haut.Parent = racine
				local bas = Instance.new("Attachment")
				bas.Name = "TraineeBas"
				bas.Position = Vector3.new(0, -0.9, 0)
				bas.Parent = racine
				local trainee = Instance.new("Trail")
				trainee.Name = "TraineeVictoire"
				trainee.Attachment0 = haut
				trainee.Attachment1 = bas
				trainee.Lifetime = 0.7
				trainee.LightEmission = 0.4
				local points = {}
				for i, couleur in ipairs(palier.couleurs) do
					table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#palier.couleurs - 1), couleur))
				end
				trainee.Color = ColorSequence.new(points)
				trainee.Transparency = NumberSequence.new(0.3, 1)
				trainee.Parent = racine
			end)
			return
		end
	end
end

local function personnageArrive(joueur, perso)
	-- Roblox pose le personnage au point de départ un peu après sa création : pendant
	-- trois secondes, tant qu'il est près du départ alors qu'il a déjà passé une
	-- borne, on le remet sur sa borne.
	local fin = os.clock() + 3
	local equipe = false
	while os.clock() < fin and perso.Parent and joueur.Character == perso do
		local racine = perso:FindFirstChild("HumanoidRootPart")
		if racine then
			if not equipe then
				equipe = true
				poserTrainee(joueur, perso)
			end
			local p = progression(joueur)
			if p.etape > 0 and (racine.CFrame.Position - depart.CFrame.Position).Magnitude < 25 then
				envoyer(perso, retour(joueur))
			end
		end
		task.wait(0.1)
	end
end

local function joueurArrive(joueur)
	joueur.CharacterAdded:Connect(function(perso)
		personnageArrive(joueur, perso)
	end)
	task.spawn(function()
		-- Avec le noyau, le profil arrive un peu après le joueur : on attend sa progression sauvegardée.
		local essais = 0
		while API and not sauvegardees[joueur] and joueur.Parent and essais < 60 do
			progression(joueur)
			essais += 1
			task.wait(0.5)
		end
		if not joueur.Parent then
			return
		end
		majStats(joueur)
		if joueur.Character then
			poserTrainee(joueur, joueur.Character)
			if progression(joueur).etape > 0 then
				envoyer(joueur.Character, retour(joueur))
			end
		end
	end)
	if joueur.Character then
		task.spawn(personnageArrive, joueur, joueur.Character)
	end
end

Players.PlayerAdded:Connect(joueurArrive)
for _, joueur in ipairs(Players:GetPlayers()) do
	joueurArrive(joueur)
end
Players.PlayerRemoving:Connect(function(joueur)
	progressions[joueur] = nil
	sauvegardees[joueur] = nil
	enVictoire[joueur] = nil
	debutCourse[joueur] = nil
end)

-- Filet de sécurité contre les chutes : quatre fois par seconde, tout joueur tombé
-- plus bas que MARGE_CHUTE sous sa dernière borne (ou sous le départ) y est ramené,
-- sans mourir. Cela couvre aussi une apparition hors de la map.
task.spawn(function()
	while true do
		task.wait(0.25)
		for _, joueur in ipairs(Players:GetPlayers()) do
			local perso = joueur.Character
			local racine = perso and perso:FindFirstChild("HumanoidRootPart")
			local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
			if racine and humanoide and humanoide.Health > 0 and not enVictoire[joueur] then
				local cible = retour(joueur)
				if racine.CFrame.Position.Y < cible.Position.Y - MARGE_CHUTE then
					envoyer(perso, cible)
					debutCourse[joueur] = (progression(joueur).etape == 0) and nil or debutCourse[joueur]
					annoncer(joueur, "↩")
				end
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Étapes, chronomètre et victoire
--------------------------------------------------------------------------------

local function joueurDe(hit)
	local perso = hit and hit.Parent
	local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(perso), humanoide, perso
end

if ligneDepart then
	ligneDepart.Touched:Connect(function(hit)
		local joueur = joueurDe(hit)
		-- Le chronomètre ne part que pour une course complète (depuis l'étape 0).
		if joueur and not enVictoire[joueur] and progression(joueur).etape == 0 then
			debutCourse[joueur] = os.clock()
		end
	end)
end

for numero, zone in pairs(bornes) do
	zone.Touched:Connect(function(hit)
		local joueur = joueurDe(hit)
		if not joueur or enVictoire[joueur] then
			return
		end
		local p = progression(joueur)
		if numero > p.etape then
			p.etape = numero
			majStats(joueur)
			crediter(joueur, GAIN_ETAPE, "etape")
			effet(zone, 30)
			annoncer(joueur, "✔ " .. numero .. " / " .. NB_ETAPES)
		end
	end)
end

arrivee.Touched:Connect(function(hit)
	local joueur, _, perso = joueurDe(hit)
	if not joueur or enVictoire[joueur] then
		return
	end
	local p = progression(joueur)
	if p.etape < NB_ETAPES - 1 then
		return -- il faut être passé par la dernière borne : pas de raccourci
	end
	enVictoire[joueur] = true
	p.victoires += 1
	p.etape = 0
	local message = "🏆 " .. p.victoires
	local debut = debutCourse[joueur]
	debutCourse[joueur] = nil
	if debut then
		local duree = os.clock() - debut
		message = message .. "   ⏱ " .. chrono(duree)
		if p.record == 0 or duree < p.record then
			p.record = duree
			message = message .. " ★"
		end
	end
	majStats(joueur)
	crediter(joueur, GAIN_VICTOIRE, "victoire")
	effet(arrivee, 80)
	annoncer(joueur, message)
	poserTrainee(joueur, perso)
	task.delay(4, function()
		enVictoire[joueur] = nil
		if perso.Parent then
			envoyer(perso, depart.CFrame * CFrame.new(0, 4, 0))
		end
	end)
end)

--------------------------------------------------------------------------------
-- Pièges
--------------------------------------------------------------------------------

for _, danger in ipairs(dossierDangers:GetChildren()) do
	if danger:IsA("BasePart") then
		danger.Touched:Connect(function(hit)
			local joueur, humanoide = joueurDe(hit)
			if joueur and not enVictoire[joueur] then
				humanoide.Health = 0
			end
		end)
	end
end

-- Dalles de verre : au premier pas elles rougissent (avertissement), puis s'effacent
-- DELAI_FRAGILE secondes plus tard et reviennent après ABSENCE_FRAGILE secondes.
for _, dalle in ipairs(dossierFragiles:GetChildren()) do
	if dalle:IsA("BasePart") then
		local transparence, couleur = dalle.Transparency, dalle.Color
		local active = false
		dalle.Touched:Connect(function(hit)
			if active or not joueurDe(hit) then
				return
			end
			active = true
			dalle.Color = Color3.fromRGB(255, 90, 70)
			task.wait(DELAI_FRAGILE * 0.6)
			dalle.Transparency = math.min(0.75, transparence + 0.35) -- elle pâlit : plus qu'un instant
			task.wait(DELAI_FRAGILE * 0.4)
			dalle.Transparency = 0.95
			dalle.CanCollide = false
			task.wait(ABSENCE_FRAGILE)
			dalle.Transparency = transparence
			dalle.Color = couleur
			dalle.CanCollide = true
			active = false
		end)
	end
end

for _, tapis in ipairs(dossierTapis:GetChildren()) do
	local vitesse = tapis:GetAttribute("VitesseTapis")
	if tapis:IsA("BasePart") and vitesse then
		pcall(function()
			tapis.AssemblyLinearVelocity = vitesse -- une pièce ancrée dotée d'une vitesse entraîne ce qui est posé dessus
		end)
	end
end

--------------------------------------------------------------------------------
-- Gemmes et reliques : modèle visible soudé à la pièce invisible qu'on touche
--------------------------------------------------------------------------------

-- Soude le modèle (dossier Bijoux/<Id>) à son cœur : quand le cœur bouge, tout suit.
-- Renvoie une fonction qui montre ou cache le modèle.
local function monter(coeur)
	local dossier = dossierBijoux:FindFirstChild(coeur:GetAttribute("Bijou") or "")
	local pieces = {}
	if dossier then
		for _, piece in ipairs(dossier:GetChildren()) do
			if piece:IsA("BasePart") then
				local soudure = Instance.new("WeldConstraint")
				soudure.Part0 = coeur
				soudure.Part1 = piece
				soudure.Parent = coeur
				piece.Anchored = false
				table.insert(pieces, { piece = piece, transparence = piece.Transparency })
			end
		end
	end
	return function(visible)
		for _, info in ipairs(pieces) do
			info.piece.Transparency = visible and info.transparence or 1
		end
		local lumiere = coeur:FindFirstChildOfClass("PointLight")
		if lumiere then
			lumiere.Enabled = visible
		end
	end
end

local flottants, basesFlottants = {}, {}

for _, gemme in ipairs(dossierGemmes:GetChildren()) do
	if gemme:IsA("BasePart") then
		local montrer = monter(gemme)
		table.insert(flottants, gemme)
		basesFlottants[gemme] = gemme.CFrame
		gemme.Touched:Connect(function(hit)
			if gemme:GetAttribute("Pris") then
				return
			end
			local joueur = joueurDe(hit)
			if not joueur then
				return
			end
			gemme:SetAttribute("Pris", true)
			crediter(joueur, gemme:GetAttribute("Valeur") or 1, "gemme")
			effet(gemme, 24)
			montrer(false)
			gemme.CanTouch = false
			task.delay(TEMPS_REAPPARITION, function()
				if not gemme.Parent then
					return
				end
				montrer(true)
				gemme.CanTouch = true
				gemme:SetAttribute("Pris", false)
			end)
		end)
	end
end

-- Reliques secrètes : elles restent en place, mais chaque joueur ne les compte qu'une fois, pour toujours.
for _, relique in ipairs(dossierSecrets:GetChildren()) do
	local numero = relique:GetAttribute("Secret")
	if relique:IsA("BasePart") and numero then
		monter(relique)
		table.insert(flottants, relique)
		basesFlottants[relique] = relique.CFrame
		local cle = "s" .. numero
		relique.Touched:Connect(function(hit)
			local joueur = joueurDe(hit)
			if not joueur then
				return
			end
			local p = progression(joueur)
			if p.secrets[cle] then
				return
			end
			p.secrets[cle] = true
			local trouves = nbSecrets(p)
			crediter(joueur, GAIN_SECRET, "secret")
			effet(relique, 40)
			if trouves >= NB_SECRETS then
				crediter(joueur, GAIN_TOUS_SECRETS, "tous-les-secrets")
				annoncer(joueur, "✦ " .. trouves .. " / " .. NB_SECRETS .. " ✦")
			else
				annoncer(joueur, "✦ " .. trouves .. " / " .. NB_SECRETS)
			end
			majStats(joueur)
		end)
	end
end

--------------------------------------------------------------------------------
-- Animations : barres et hologrammes qui tournent, gemmes qui flottent
--------------------------------------------------------------------------------

local rotors, basesRotors = {}, {}
for _, objet in ipairs(map:GetDescendants()) do
	if objet:IsA("BasePart") and objet:GetAttribute("VitesseRotation") then
		table.insert(rotors, objet)
		basesRotors[objet] = objet.CFrame
	end
end

-- Précaution : une barre ancrée déplacée par script peut ne pas déclencher Touched
-- sur un personnage immobile. Les barres mortelles regardent donc elles-mêmes,
-- dix fois par seconde, ce qu'elles recouvrent.
local barres = {}
for _, rotor in ipairs(rotors) do
	if rotor.Parent == dossierDangers then
		table.insert(barres, rotor)
	end
end
local function balayer()
	for _, barre in ipairs(barres) do
		local ok, touches = pcall(function()
			return workspace:GetPartsInPart(barre)
		end)
		if ok then
			for _, piece in ipairs(touches) do
				local joueur, humanoide = joueurDe(piece)
				if joueur and not enVictoire[joueur] then
					humanoide.Health = 0
				end
			end
		end
	end
end

local temps, dernierBalayage = 0, 0
RunService.Heartbeat:Connect(function(dt)
	temps += dt
	for _, rotor in ipairs(rotors) do
		rotor.CFrame = basesRotors[rotor] * CFrame.Angles(0, temps * rotor:GetAttribute("VitesseRotation"), 0)
	end
	if temps - dernierBalayage >= 0.1 then
		dernierBalayage = temps
		balayer()
	end
	for i, objet in ipairs(flottants) do
		objet.CFrame = basesFlottants[objet] * CFrame.new(0, math.sin(temps * 2 + i) * 0.3, 0) * CFrame.Angles(0, temps * 1.2 + i, 0)
	end
end)
]==]

--------------------------------------------------------------------------------
-- KIT DE CONSTRUCTION (commun à tous les formats de la Fabrique)
-- Outils, palette du thème, ambiance et décors. Ne dépend que de `FABRIQUE`.
--------------------------------------------------------------------------------

local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")

local THEME = FABRIQUE.theme

-- Générateur pseudo-aléatoire maison (Park–Miller). Le `Random` de Roblox ne donne
-- pas les mêmes tirages hors de Roblox : avec celui-ci, le jeu construit dans
-- Studio est exactement celui que le pipeline a construit et validé.
local rng = { etat = math.floor(FABRIQUE.graine) % 2147483646 + 1 }
function rng:suivant()
	self.etat = (self.etat * 48271) % 2147483647
	return (self.etat - 1) / 2147483646
end
function rng:NextNumber(a, b)
	local mini, maxi = a or 0, b or 1
	return mini + (maxi - mini) * self:suivant()
end
function rng:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:suivant())
end

local TEXTURE_ETINCELLE = "rbxasset://textures/particles/sparkles_main.dds"
local TEXTURE_FUMEE = "rbxasset://textures/particles/smoke_main.dds"
local TEXTURE_FEU = "rbxasset://textures/particles/fire_main.dds"
local SON_COLLECTE = "rbxasset://sounds/electronicpingshort.wav"

-- Couleurs et matériaux du thème, convertis une fois pour toutes.
local C = {}
for cle, rvb in pairs(THEME.couleurs) do
	C[cle] = Color3.fromRGB(rvb[1], rvb[2], rvb[3])
end
C.blanc = Color3.fromRGB(250, 250, 250)
C.noir = Color3.fromRGB(24, 24, 28)
local MAT = {}
for cle, nom in pairs(THEME.materiaux) do
	MAT[cle] = Enum.Material[nom]
end

local K = {}

function K.rvb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Mélange de deux couleurs (t = 0 → a, t = 1 → b).
function K.melange(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

-- Variation légère d'une couleur, pour éviter les aplats uniformes.
function K.nuance(c, force)
	local d = rng:NextNumber(-force, force)
	return Color3.new(math.clamp(c.R + d, 0, 1), math.clamp(c.G + d, 0, 1), math.clamp(c.B + d, 0, 1))
end

function K.hasard(a, b)
	return rng:NextNumber(a, b)
end

function K.choisir(liste)
	return liste[rng:NextInteger(1, #liste)]
end

--------------------------------------------------------------------------------
-- Nettoyage : le script est relançable (l'ancienne map est supprimée)
--------------------------------------------------------------------------------

do
	local ancienne = workspace:FindFirstChild("Parcours")
	if ancienne then
		ancienne:Destroy()
	end
	local ancienScript = ServerScriptService:FindFirstChild("Parcours_Jeu")
	if ancienScript then
		ancienScript:Destroy()
	end
	for _, enfant in ipairs(Lighting:GetChildren()) do
		if string.sub(enfant.Name, 1, 4) == "Fab_" then
			enfant:Destroy()
		end
	end
	local nuages = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if nuages then
		nuages:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local vieuxSpawn = workspace:FindFirstChild("SpawnLocation")
	if vieuxSpawn then
		vieuxSpawn:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Dossiers
--------------------------------------------------------------------------------

local map = Instance.new("Folder")
map.Name = "Parcours"
map:SetAttribute("Nom", FABRIQUE.nom)
map:SetAttribute("Titre", FABRIQUE.titre)
map:SetAttribute("Format", FABRIQUE.format)
map:SetAttribute("Theme", THEME.cle)
map:SetAttribute("Graine", FABRIQUE.graine)

local D = {}
for _, nom in ipairs({
	"Structure", -- tout ce sur quoi on marche
	"Decor", -- purement visuel
	"Etapes", -- bornes de sauvegarde (attribut Numero)
	"Collectibles", -- gemmes à ramasser (attribut Valeur)
	"Dangers", -- tue au contact
	"Mobiles", -- tournent sur eux-mêmes (attribut VitesseRotation)
	"Fragiles", -- s'effacent quand on marche dessus
	"Tapis", -- tapis roulants (attribut VitesseTapis)
	"Bijoux", -- modèles visibles des gemmes, du trophée et des reliques (un dossier par objet)
	"Secrets", -- reliques cachées (attribut Secret = numéro)
}) do
	local dossier = Instance.new("Folder")
	dossier.Name = nom
	dossier.Parent = map
	D[nom] = dossier
end

--------------------------------------------------------------------------------
-- Pièces de base
--------------------------------------------------------------------------------

function K.piece(props)
	local p = Instance.new(props.Classe or "Part")
	p.Anchored = true
	p.CastShadow = props.CastShadow ~= false
	p.CanCollide = props.CanCollide ~= false
	if props.CanTouch ~= nil then
		p.CanTouch = props.CanTouch
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Size = props.Size or Vector3.new(1, 1, 1)
	p.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	p.Color = props.Color or C.structure
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.Reflectance = props.Reflectance or 0
	p.Name = props.Name or "Decor"
	p.Parent = props.Parent or D.Decor
	return p
end

-- Pièce purement décorative : ni collision ni contact (on ne s'y coince pas).
function K.deco(props)
	props.CanCollide = false
	props.CanTouch = false
	props.Parent = props.Parent or D.Decor
	return K.piece(props)
end

-- Cylindre d'axe vertical (les cylindres Roblox ont leur axe sur X).
function K.cylindre(position, hauteur, diametre, props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(hauteur, diametre, diametre)
	props.CFrame = (props.CFrame or CFrame.new(position)) * CFrame.Angles(0, 0, math.rad(90))
	return K.piece(props)
end

function K.boule(position, diametre, props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diametre, diametre, diametre)
	props.CFrame = CFrame.new(position)
	return K.piece(props)
end

-- Repère posé en `position`, dont l'axe -Z regarde dans la direction `vers`.
function K.repere(position, vers)
	return CFrame.new(position, position + vers)
end

function K.lumiere(parent, couleur, portee, luminosite)
	local l = Instance.new("PointLight")
	l.Color = couleur
	-- Volontairement modérées : trop de lumières fortes noient l'image dans un voile.
	l.Range = portee * 0.8
	l.Brightness = luminosite * 0.5
	l.Shadows = false
	l.Parent = parent
	return l
end

function K.emetteur(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = props.Texture or TEXTURE_ETINCELLE
	e.Color = props.Color or ColorSequence.new(Color3.new(1, 1, 1))
	e.Size = props.Size or NumberSequence.new(1)
	e.Transparency = props.Transparency or NumberSequence.new(0.2, 1)
	e.Lifetime = props.Lifetime or NumberRange.new(2, 3)
	e.Rate = props.Rate or 5
	e.Speed = props.Speed or NumberRange.new(1, 2)
	e.SpreadAngle = props.SpreadAngle or Vector2.new(15, 15)
	e.Acceleration = props.Acceleration or Vector3.zero
	e.LightEmission = props.LightEmission or 0
	e.RotSpeed = props.RotSpeed or NumberRange.new(-40, 40)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = props.EmissionDirection or Enum.NormalId.Top
	e.Enabled = props.Enabled ~= false
	e.Parent = parent
	return e
end

-- Texte affiché sur une face d'une pièce.
function K.texte(piece, face, texte, couleurTexte)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = piece
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = texte
	label.TextColor3 = couleurTexte or C.blanc
	label.TextStrokeColor3 = C.noir
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return gui
end

-- Texte flottant, toujours face à la caméra.
function K.etiquette(piece, texte, hauteur, couleurTexte)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 280, 0, 64)
	gui.StudsOffset = Vector3.new(0, hauteur, 0)
	gui.MaxDistance = 260
	gui.Parent = piece
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = texte
	label.TextColor3 = couleurTexte or C.blanc
	label.TextStrokeColor3 = C.noir
	label.TextStrokeTransparency = 0.25
	label.Parent = gui
	return gui
end

--------------------------------------------------------------------------------
-- Ambiance : éclairage, atmosphère, nuages, étalonnage (tout vient du thème)
--------------------------------------------------------------------------------

function K.ambiance()
	local L = THEME.lumiere
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = THEME.heure
	Lighting.GeographicLatitude = 28
	Lighting.Brightness = L.luminosite
	Lighting.ExposureCompensation = 0
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.Ambient = K.rvb(L.ambiance)
	Lighting.OutdoorAmbient = K.rvb(L.exterieur)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25

	local ciel = Instance.new("Sky") -- ciel physique par défaut de Roblox (pas de texture externe)
	ciel.Name = "Fab_Ciel"
	ciel.StarCount = 3000
	ciel.Parent = Lighting

	-- Netteté d'abord : la brume, l'éblouissement et le halo sont plafonnés, quel que
	-- soit le thème (retour de jeu : « trop de lumière, on ne voit rien »).
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "Fab_Atmosphere"
	atmosphere.Density = math.min(L.atmosphere.densite, 0.26)
	atmosphere.Offset = L.atmosphere.decalage
	atmosphere.Color = K.rvb(L.atmosphere.couleur)
	atmosphere.Decay = K.rvb(L.atmosphere.declin)
	atmosphere.Glare = math.min(L.atmosphere.eblouissement, 0.1)
	atmosphere.Haze = math.min(L.atmosphere.brume, 0.6)
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Fab_Bloom"
	bloom.Intensity = math.min(L.bloom.intensite, 0.12)
	bloom.Size = math.min(L.bloom.taille, 14)
	bloom.Threshold = math.max(L.bloom.seuil, 2)
	bloom.Parent = Lighting

	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "Fab_Couleurs"
	correction.Brightness = 0
	correction.Contrast = L.correction.contraste
	correction.Saturation = L.correction.saturation
	correction.TintColor = K.rvb(L.correction.teinte)
	correction.Parent = Lighting

	local nuages = Instance.new("Clouds")
	nuages.Cover = L.nuages.couverture
	nuages.Density = L.nuages.densite
	nuages.Color = K.rvb(L.nuages.couleur)
	nuages.Parent = workspace.Terrain
end

--------------------------------------------------------------------------------
-- Décors
--------------------------------------------------------------------------------

-- Rocher : trois blocs imbriqués, tournés au hasard.
function K.rocher(position, taille, couleurRoche)
	couleurRoche = couleurRoche or C.structure
	for i = 1, 3 do
		local t = taille * (1.1 - i * 0.2)
		K.deco({
			Size = Vector3.new(t * K.hasard(0.9, 1.3), t * K.hasard(0.6, 1), t * K.hasard(0.9, 1.3)),
			CFrame = CFrame.new(position + Vector3.new(K.hasard(-0.3, 0.3) * taille, t * 0.3, K.hasard(-0.3, 0.3) * taille))
				* CFrame.Angles(K.hasard(-0.4, 0.4), K.hasard(0, 6.28), K.hasard(-0.4, 0.4)),
			Color = K.nuance(couleurRoche, 0.04),
			Material = MAT.structure,
			Name = "Rocher",
		})
	end
end

-- Grappe de cristaux lumineux (verre éclairé de l'intérieur).
function K.cristaux(position, hauteur, couleurCristal)
	couleurCristal = couleurCristal or C.accent
	for i = 1, 4 do
		local h = hauteur * (i == 1 and 1 or K.hasard(0.35, 0.7))
		local incline = (i == 1) and 0.08 or K.hasard(0.25, 0.5)
		local cap = K.hasard(0, 6.28)
		local cristal = K.deco({
			Size = Vector3.new(h * 0.22, h, h * 0.22),
			CFrame = CFrame.new(position)
				* CFrame.Angles(0, cap, 0)
				* CFrame.Angles(incline, 0, 0)
				* CFrame.new(0, h * 0.45, 0)
				* CFrame.Angles(0, math.rad(45), 0),
			Color = K.nuance(couleurCristal, 0.05),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Reflectance = 0.1,
			CastShadow = false,
			Name = "Cristal",
		})
		if i == 1 then
			K.lumiere(cristal, couleurCristal, hauteur * 3 + 6, 1.6)
		end
	end
end

local ARBRES = {}

function ARBRES.feuillu(p, e)
	local h = 6 * e
	K.cylindre(p + Vector3.new(0, h / 2, 0), h, 1.1 * e, { Color = C.bois, Material = MAT.bois, Name = "Tronc", CanCollide = false, CanTouch = false })
	for i = 1, 4 do
		local a = i * 1.6 + K.hasard(0, 1)
		K.boule(
			p + Vector3.new(math.cos(a) * 1.6 * e, h + K.hasard(-0.6, 1.4) * e, math.sin(a) * 1.6 * e),
			K.hasard(3.6, 5) * e,
			{ Color = K.nuance(C.vegetal, 0.05), Material = Enum.Material.LeafyGrass, Name = "Feuillage", CanCollide = false, CanTouch = false }
		)
	end
end

function ARBRES.sapin(p, e)
	local h = 3 * e
	K.cylindre(p + Vector3.new(0, h / 2, 0), h, 0.9 * e, { Color = C.bois, Material = MAT.bois, Name = "Tronc", CanCollide = false, CanTouch = false })
	local y = h
	for i = 1, 4 do
		local d = (6.4 - i * 1.4) * e
		local epaisseur = 2 * e
		K.cylindre(p + Vector3.new(0, y + epaisseur / 2, 0), epaisseur, d, { Color = K.nuance(C.vegetal, 0.04), Material = Enum.Material.LeafyGrass, Name = "Etage", CanCollide = false, CanTouch = false })
		K.cylindre(p + Vector3.new(0, y + epaisseur + 0.1 * e, 0), 0.25 * e, d * 0.82, { Color = C.sol, Material = Enum.Material.Snow, Name = "Neige", CanCollide = false, CanTouch = false, CastShadow = false })
		y += epaisseur * 0.85
	end
end

function ARBRES.palmier(p, e)
	local position = CFrame.new(p) * CFrame.Angles(0, K.hasard(0, 6.28), 0)
	local segment = 2 * e
	for i = 1, 5 do
		position = position * CFrame.Angles(math.rad(5), 0, 0) * CFrame.new(0, segment, 0)
		K.deco({
			Size = Vector3.new((1.2 - i * 0.1) * e, segment * 1.1, (1.2 - i * 0.1) * e),
			CFrame = position * CFrame.new(0, -segment / 2, 0),
			Color = K.nuance(C.bois, 0.04),
			Material = MAT.bois,
			Name = "Tronc",
		})
	end
	for i = 1, 7 do
		local feuille = position * CFrame.Angles(0, i * 0.9, 0) * CFrame.Angles(math.rad(-28), 0, 0)
		K.deco({
			Size = Vector3.new(1.5 * e, 0.25 * e, 6 * e),
			CFrame = feuille * CFrame.new(0, 0, -3 * e),
			Color = K.nuance(C.vegetal, 0.05),
			Material = Enum.Material.LeafyGrass,
			Name = "Palme",
		})
	end
	K.boule(position.Position + Vector3.new(0.5 * e, -0.4 * e, 0), 0.9 * e, { Color = C.bois, Material = MAT.bois, Name = "Noix", CanCollide = false, CanTouch = false })
end

function ARBRES.mort(p, e)
	local h = 5.5 * e
	local tronc = CFrame.new(p) * CFrame.Angles(K.hasard(-0.1, 0.1), K.hasard(0, 6.28), K.hasard(-0.1, 0.1))
	K.deco({ Size = Vector3.new(0.9 * e, h, 0.9 * e), CFrame = tronc * CFrame.new(0, h / 2, 0), Color = C.bois, Material = MAT.bois, Name = "Tronc" })
	for i = 1, 3 do
		local branche = tronc * CFrame.new(0, h * (0.5 + i * 0.15), 0) * CFrame.Angles(0, i * 2.1, 0) * CFrame.Angles(math.rad(48), 0, 0)
		local longueur = (3.4 - i * 0.5) * e
		K.deco({ Size = Vector3.new(0.4 * e, longueur, 0.4 * e), CFrame = branche * CFrame.new(0, longueur / 2, 0), Color = C.bois, Material = MAT.bois, Name = "Branche" })
		K.deco({
			Size = Vector3.new(0.5 * e, 0.5 * e, 0.5 * e),
			CFrame = branche * CFrame.new(0, longueur, 0),
			Color = C.accent,
			Material = Enum.Material.Neon,
			CastShadow = false,
			Name = "Braise",
		})
	end
end

function ARBRES.sucette(p, e)
	local h = 7 * e
	K.cylindre(p + Vector3.new(0, h / 2, 0), h, 0.5 * e, { Color = C.blanc, Name = "Baton", CanCollide = false, CanTouch = false })
	local face = CFrame.new(p + Vector3.new(0, h + 1.6 * e, 0)) * CFrame.Angles(0, K.hasard(0, 6.28), 0)
	local teintes = { K.choisir({ C.accent, C.accent2, C.structureAlt }), C.blanc }
	for i = 1, 4 do
		K.deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.7 * e + i * 0.12 * e, (5 - i * 1.1) * e, (5 - i * 1.1) * e),
			CFrame = face,
			Color = teintes[(i % 2) + 1],
			Name = "Sucette",
		})
	end
end

function ARBRES.antenne(p, e)
	local h = 9 * e
	K.cylindre(p + Vector3.new(0, h / 2, 0), h, 0.5 * e, { Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Mat", CanCollide = false, CanTouch = false })
	for i = 1, 3 do
		K.cylindre(p + Vector3.new(0, h * (0.35 + i * 0.18), 0), 0.25 * e, (3.6 - i * 0.8) * e, {
			Color = (i % 2 == 0) and C.accent2 or C.accent,
			Material = Enum.Material.Neon,
			Name = "Anneau",
			CanCollide = false,
			CanTouch = false,
			CastShadow = false,
		})
	end
	local tete = K.boule(p + Vector3.new(0, h + 0.4 * e, 0), 0.9 * e, { Color = C.accent2, Material = Enum.Material.Neon, Name = "Balise", CanCollide = false, CanTouch = false, CastShadow = false })
	K.lumiere(tete, C.accent2, 16, 1.4)
end

function K.arbre(position, echelle)
	local fabriquer = ARBRES[THEME.decor.arbre] or ARBRES.feuillu
	fabriquer(position, echelle or 1)
end

local LAMPES = {}

function LAMPES.brasero(p)
	K.cylindre(p + Vector3.new(0, 1.5, 0), 3, 1.1, { Color = C.structure, Material = MAT.structure, Name = "Pied", CanCollide = false, CanTouch = false })
	local coupe = K.cylindre(p + Vector3.new(0, 3.3, 0), 0.7, 2.6, { Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Coupe", CanCollide = false, CanTouch = false })
	K.cylindre(p + Vector3.new(0, 3.7, 0), 0.2, 2.1, { Color = C.accent, Material = Enum.Material.Neon, Name = "Braises", CanCollide = false, CanTouch = false, CastShadow = false })
	K.lumiere(coupe, C.accent, 22, 2)
	K.emetteur(coupe, {
		Texture = TEXTURE_FEU,
		Color = ColorSequence.new(C.accent2, C.danger),
		Size = NumberSequence.new(1.6, 0.2),
		Lifetime = NumberRange.new(0.6, 1.1),
		Rate = 9,
		Speed = NumberRange.new(2, 4),
		LightEmission = 1,
	})
end

function LAMPES.cristal(p)
	K.cristaux(p, 4.2, C.accent)
end

function LAMPES.lanterne(p)
	K.deco({ Size = Vector3.new(0.5, 6, 0.5), Position = p + Vector3.new(0, 3, 0), Color = C.bois, Material = MAT.bois, Name = "Poteau" })
	K.deco({ Size = Vector3.new(0.35, 0.35, 2), Position = p + Vector3.new(0, 5.8, 0.8), Color = C.bois, Material = MAT.bois, Name = "Bras" })
	local verre = K.deco({ Size = Vector3.new(0.9, 1.2, 0.9), Position = p + Vector3.new(0, 4.8, 1.6), Color = C.accent, Material = Enum.Material.Neon, CastShadow = false, Name = "Lanterne" })
	K.deco({ Size = Vector3.new(1.2, 0.2, 1.2), Position = p + Vector3.new(0, 5.5, 1.6), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Chapeau" })
	K.lumiere(verre, C.accent, 20, 1.6)
end

function LAMPES.sucre(p)
	for i = 0, 5 do
		K.cylindre(p + Vector3.new(0, 0.5 + i, 0), 1, 0.7, { Color = (i % 2 == 0) and C.danger or C.blanc, Name = "Sucre", CanCollide = false, CanTouch = false })
	end
	local globe = K.boule(p + Vector3.new(0, 6.9, 0), 1.8, { Color = C.accent2, Material = Enum.Material.Neon, Name = "Globe", CanCollide = false, CanTouch = false, CastShadow = false })
	K.lumiere(globe, C.accent2, 18, 1.2)
end

function LAMPES.tube(p)
	K.deco({ Size = Vector3.new(0.6, 7, 0.6), Position = p + Vector3.new(0, 3.5, 0), Color = C.structure, Material = Enum.Material.Metal, Name = "Poteau" })
	local teinte = K.choisir({ C.accent, C.accent2 })
	local tube = K.deco({ Size = Vector3.new(0.3, 5, 0.3), Position = p + Vector3.new(0.45, 4, 0), Color = teinte, Material = Enum.Material.Neon, CastShadow = false, Name = "Tube" })
	K.lumiere(tube, teinte, 20, 1.8)
end

function LAMPES.projecteur(p)
	K.deco({ Size = Vector3.new(0.5, 8, 0.5), Position = p + Vector3.new(0, 4, 0), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Mat" })
	local tete = K.deco({
		Size = Vector3.new(1.4, 1, 1.8),
		CFrame = CFrame.new(p + Vector3.new(0, 8.2, 0.5)) * CFrame.Angles(math.rad(-40), 0, 0),
		Color = C.structureAlt,
		Material = Enum.Material.Metal,
		Name = "Projecteur",
	})
	K.deco({
		Size = Vector3.new(1.1, 0.7, 0.2),
		CFrame = tete.CFrame * CFrame.new(0, 0, -0.95),
		Color = C.accent2,
		Material = Enum.Material.Neon,
		CastShadow = false,
		Name = "Lentille",
	})
	local faisceau = Instance.new("SpotLight")
	faisceau.Color = C.accent2
	faisceau.Range = 34
	faisceau.Angle = 70
	faisceau.Brightness = 2.4
	faisceau.Face = Enum.NormalId.Front
	faisceau.Shadows = false
	faisceau.Parent = tete
end

function K.lampe(position)
	local fabriquer = LAMPES[THEME.decor.lampe] or LAMPES.lanterne
	fabriquer(position)
end

local SPECIAUX = {}

function SPECIAUX.geyser(p)
	for i = 1, 6 do
		local a = i * 1.05
		K.rocher(p + Vector3.new(math.cos(a) * 2.6, -0.4, math.sin(a) * 2.6), 1.8, C.structure)
	end
	local bassin = K.cylindre(p + Vector3.new(0, 0.25, 0), 0.5, 4, { Color = C.danger, Material = Enum.Material.Neon, Name = "Magma", CanCollide = false, CanTouch = false, CastShadow = false })
	K.lumiere(bassin, C.accent, 26, 2.2)
	K.emetteur(bassin, {
		Texture = TEXTURE_FEU,
		Color = ColorSequence.new(C.accent2, C.danger),
		Size = NumberSequence.new(1.4, 0.1),
		Lifetime = NumberRange.new(0.8, 1.6),
		Rate = 12,
		Speed = NumberRange.new(10, 18),
		Acceleration = Vector3.new(0, -24, 0),
		SpreadAngle = Vector2.new(12, 12),
		LightEmission = 1,
	})
end

function SPECIAUX.stalagmite(p)
	K.cristaux(p, 7, C.solAlt)
	K.cristaux(p + Vector3.new(2.4, 0, 1.2), 4, C.accent)
end

function SPECIAUX.idole(p)
	K.deco({ Size = Vector3.new(4.4, 1, 4.4), Position = p + Vector3.new(0, 0.5, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Socle" })
	K.deco({ Size = Vector3.new(3.2, 4.4, 3), Position = p + Vector3.new(0, 3.2, 0), Color = C.structure, Material = MAT.structure, Name = "Tete" })
	K.deco({ Size = Vector3.new(3.8, 0.8, 3.4), Position = p + Vector3.new(0, 5.6, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Coiffe" })
	for _, cote in ipairs({ -0.8, 0.8 }) do
		local oeil = K.deco({ Size = Vector3.new(0.7, 0.5, 0.3), Position = p + Vector3.new(cote, 3.9, -1.5), Color = C.accent, Material = Enum.Material.Neon, CastShadow = false, Name = "Oeil" })
		K.lumiere(oeil, C.accent, 8, 1)
	end
	K.deco({ Size = Vector3.new(1.8, 0.4, 0.3), Position = p + Vector3.new(0, 2.2, -1.5), Color = C.noir, Name = "Bouche" })
	K.deco({ Size = Vector3.new(0.7, 1.4, 0.6), Position = p + Vector3.new(0, 3.1, -1.6), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Nez" })
end

function SPECIAUX.gateau(p)
	local teintes = { C.structure, C.accent, C.structure }
	for i = 1, 3 do
		local d = 6.4 - i * 1.5
		K.cylindre(p + Vector3.new(0, (i - 1) * 1.7 + 0.75, 0), 1.5, d, { Color = teintes[i], Name = "Etage", CanCollide = false, CanTouch = false })
		K.cylindre(p + Vector3.new(0, (i - 1) * 1.7 + 1.6, 0), 0.3, d + 0.3, { Color = C.blanc, Name = "Glacage", CanCollide = false, CanTouch = false, CastShadow = false })
	end
	local cerise = K.boule(p + Vector3.new(0, 5.9, 0), 1.2, { Color = C.danger, Reflectance = 0.2, Name = "Cerise", CanCollide = false, CanTouch = false })
	K.lumiere(cerise, C.accent, 10, 0.6)
end

function SPECIAUX.hologramme(p)
	K.cylindre(p + Vector3.new(0, 0.3, 0), 0.6, 3.4, { Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Socle", CanCollide = false, CanTouch = false })
	K.cylindre(p + Vector3.new(0, 0.65, 0), 0.12, 2.8, { Color = C.accent, Material = Enum.Material.Neon, Name = "Anneau", CanCollide = false, CanTouch = false, CastShadow = false })
	local cube = K.deco({
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = CFrame.new(p + Vector3.new(0, 3.6, 0)) * CFrame.Angles(math.rad(35), 0, math.rad(35)),
		Color = C.accent2,
		Material = Enum.Material.ForceField,
		CastShadow = false,
		Parent = D.Mobiles,
		Name = "Hologramme",
	})
	cube:SetAttribute("VitesseRotation", 0.9)
	K.lumiere(cube, C.accent2, 16, 1.4)
end

function SPECIAUX.mirador(p)
	for _, coin in ipairs({ { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } }) do
		K.deco({ Size = Vector3.new(0.5, 9, 0.5), Position = p + Vector3.new(coin[1], 4.5, coin[2]), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Pied" })
	end
	K.deco({ Size = Vector3.new(4.6, 0.5, 4.6), Position = p + Vector3.new(0, 9.2, 0), Color = C.bois, Material = MAT.bois, Name = "Plancher" })
	for _, cote in ipairs({ { 0, -2.2, 4.6, 0.3 }, { 0, 2.2, 4.6, 0.3 }, { -2.2, 0, 0.3, 4.6 }, { 2.2, 0, 0.3, 4.6 } }) do
		K.deco({ Size = Vector3.new(cote[3], 1.6, cote[4]), Position = p + Vector3.new(cote[1], 10.2, cote[2]), Color = C.structure, Material = MAT.structure, Name = "Garde" })
	end
	K.deco({ Size = Vector3.new(5.6, 0.5, 5.6), Position = p + Vector3.new(0, 13.2, 0), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Toit" })
	for _, coin in ipairs({ { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }) do
		K.deco({ Size = Vector3.new(0.3, 2.6, 0.3), Position = p + Vector3.new(coin[1], 11.8, coin[2]), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Montant" })
	end
	local phare = K.boule(p + Vector3.new(0, 13.9, 0), 1.1, { Color = C.danger, Material = Enum.Material.Neon, Name = "Gyrophare", CanCollide = false, CanTouch = false, CastShadow = false })
	K.lumiere(phare, C.danger, 24, 1.8)
end

function K.special(position)
	local fabriquer = SPECIAUX[THEME.decor.special]
	if fabriquer then
		fabriquer(position)
	else
		K.cristaux(position, 5, C.accent)
	end
end

-- Un décor tiré au hasard parmi ceux du thème, posé sur `position` (au sol).
function K.decorHasard(position)
	local tirage = rng:NextNumber()
	if tirage < 0.34 then
		K.arbre(position, K.hasard(0.8, 1.3))
	elseif tirage < 0.58 then
		K.rocher(position, K.hasard(1.6, 3.2))
	elseif tirage < 0.78 then
		K.lampe(position)
	elseif tirage < 0.9 then
		K.cristaux(position, K.hasard(2.4, 4.2), K.choisir({ C.accent, C.accent2 }))
	else
		K.special(position)
	end
end

--------------------------------------------------------------------------------
-- Formes à facettes
--------------------------------------------------------------------------------

-- Pyramide à base carrée (côté 2 × demi) faite de quatre pièces en coin.
-- `cf` : centre de la base ; la pointe est à `hauteur` au-dessus (en dessous si `inverse`).
-- Orientation vérifiée dans le vrai moteur : le sommet d'une CornerWedgePart est
-- au coin (+X, +Y, -Z) de sa boîte.
function K.pyramide(cf, demi, hauteur, props, inverse)
	local base = inverse and (cf * CFrame.Angles(math.pi, 0, 0)) or cf
	local pieces = {}
	for quart = 0, 3 do
		local p = Instance.new("CornerWedgePart")
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = props.CastShadow == true
		p.Size = Vector3.new(demi, hauteur, demi)
		p.CFrame = base * CFrame.new(0, hauteur / 2, 0) * CFrame.Angles(0, quart * math.pi / 2, 0) * CFrame.new(-demi / 2, 0, demi / 2)
		p.Color = props.Color
		p.Material = props.Material or Enum.Material.Glass
		p.Transparency = props.Transparency or 0
		p.Reflectance = props.Reflectance or 0
		p.Name = props.Name or "Facette"
		p.Parent = props.Parent or D.Decor
		table.insert(pieces, p)
	end
	return pieces
end

-- Gemme taillée : deux pyramides tête-bêche (huit facettes).
function K.joyau(centre, taille, teinte, parent)
	local cf = CFrame.new(centre)
	local haut, bas = taille * 0.75, taille * 1.15
	local demi = taille * 0.62
	K.pyramide(cf * CFrame.new(0, (bas - haut) / 2, 0), demi, haut, { Color = K.melange(teinte, C.blanc, 0.3), Reflectance = 0.25, Parent = parent, Name = "Couronne" })
	K.pyramide(cf * CFrame.new(0, (bas - haut) / 2, 0), demi, bas, { Color = teinte, Reflectance = 0.2, Parent = parent, Name = "Culasse" }, true)
end

-- Coupe de vainqueur : pied, tige, vasque évasée, deux anses, joyau au sommet.
function K.coupe(centre, teinte, parent)
	local function disque(y, hauteur, diametre, couleurDisque, materiau)
		return K.cylindre(centre + Vector3.new(0, y, 0), hauteur, diametre, {
			Color = couleurDisque or teinte,
			Material = materiau or Enum.Material.Metal,
			Reflectance = 0.25,
			CanCollide = false,
			CanTouch = false,
			Parent = parent,
			Name = "Coupe",
		})
	end
	disque(-1.75, 0.4, 2.3, C.structureAlt, MAT.structureAlt)
	disque(-1.45, 0.25, 1.7)
	disque(-0.95, 0.8, 0.5)
	K.boule(centre + Vector3.new(0, -0.5, 0), 0.8, { Color = teinte, Material = Enum.Material.Metal, Reflectance = 0.25, CanCollide = false, CanTouch = false, Parent = parent, Name = "Noeud" })
	disque(-0.15, 0.3, 1.2)
	disque(0.2, 0.5, 1.8)
	disque(0.7, 0.6, 2.3)
	disque(1.25, 0.6, 2.7)
	disque(1.6, 0.14, 2.95, K.melange(teinte, C.blanc, 0.4))
	disque(1.5, 0.1, 2.3, C.noir, Enum.Material.SmoothPlastic) -- l'intérieur, sombre : la vasque paraît creuse
	for _, cote in ipairs({ -1, 1 }) do
		for _, barre in ipairs({ { 1.75, 1.2, 0.9, 0.22 }, { 1.75, 0.3, 0.9, 0.22 }, { 2.1, 0.75, 0.22, 1.1 } }) do
			K.deco({
				Size = Vector3.new(barre[3], barre[4], 0.3),
				Position = centre + Vector3.new(cote * barre[1], barre[2], 0),
				Color = teinte,
				Material = Enum.Material.Metal,
				Reflectance = 0.25,
				Parent = parent,
				Name = "Anse",
			})
		end
	end
	K.joyau(centre + Vector3.new(0, 2.5, 0), 0.7, C.accent, parent)
end

-- Relique secrète : un joyau dans un anneau, sur un petit socle.
function K.relique(centre, parent)
	K.joyau(centre, 0.9, C.accent2, parent)
	for _, angle in ipairs({ 0, math.pi / 2 }) do
		K.deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.14, 2.9, 2.9),
			CFrame = CFrame.new(centre) * CFrame.Angles(0, angle, 0),
			Color = C.piece,
			Material = Enum.Material.Metal,
			Transparency = 0.55,
			Reflectance = 0.2,
			CastShadow = false,
			Parent = parent,
			Name = "Anneau",
		})
	end
end

--------------------------------------------------------------------------------
-- Gemmes à ramasser (1, 5 ou 25 points) et reliques secrètes
--
-- Chaque objet a une pièce invisible dans `Collectibles` (c'est elle qu'on touche)
-- et un modèle visible dans `Bijoux/<Id>`, que le script de jeu soude à la pièce
-- invisible : ainsi tout le modèle tourne et flotte d'un bloc.
--------------------------------------------------------------------------------

local prochainBijou = 0

function K.bijou(position, taille, options)
	prochainBijou += 1
	local id = "B" .. prochainBijou
	local coeur = K.piece({
		Size = taille,
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = options.Parent or D.Collectibles,
		Name = options.Name or "Gemme",
	})
	coeur:SetAttribute("Bijou", id)
	local dossier = Instance.new("Folder")
	dossier.Name = id
	dossier.Parent = D.Bijoux
	local son = Instance.new("Sound")
	son.SoundId = SON_COLLECTE
	son.Volume = 0.22 -- discret : le son d'origine, plus fort et plus grave, était pénible
	son.PlaybackSpeed = options.pitch or 1.8
	son.RollOffMaxDistance = 60
	son.Parent = coeur
	K.emetteur(coeur, {
		Color = ColorSequence.new(options.couleur, Color3.new(1, 1, 1)),
		Size = NumberSequence.new(0.7, 0.1),
		Lifetime = NumberRange.new(0.4, 0.8),
		Rate = 0,
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.6,
		Enabled = false,
	})
	return coeur, dossier
end

function K.gemme(position, valeur)
	local infos = {
		[1] = { couleur = C.piece, taille = 1.15, pitch = 1.9 },
		[5] = { couleur = C.accent2, taille = 1.6, pitch = 1.6 },
		[25] = { couleur = C.piece, taille = 2.6, pitch = 1.25 },
	}
	local info = infos[valeur] or infos[1]
	local boite = (valeur == 25) and Vector3.new(4.4, 5.6, 4.4) or Vector3.new(info.taille * 1.7, info.taille * 2.4, info.taille * 1.7)
	local coeur, dossier = K.bijou(position, boite, { couleur = info.couleur, pitch = info.pitch })
	coeur:SetAttribute("Valeur", valeur)
	if valeur == 25 then
		K.coupe(position, info.couleur, dossier)
		K.lumiere(coeur, info.couleur, 14, 1.6)
	else
		K.joyau(position, info.taille, info.couleur, dossier)
		if valeur > 1 then
			K.lumiere(coeur, info.couleur, 9, 1.4)
		end
	end
	return coeur
end

-- Relique secrète : comptée une fois par joueur, pour toujours (attribut Secret = numéro).
function K.secret(position, numero)
	local coeur, dossier = K.bijou(position, Vector3.new(3, 3.4, 3), { couleur = C.accent2, pitch = 1.05, Parent = D.Secrets, Name = "Relique" })
	coeur:SetAttribute("Secret", numero)
	coeur:SetAttribute("Collectible", true) -- le validateur vérifie ainsi qu'on peut l'atteindre
	K.relique(position, dossier)
	K.lumiere(coeur, C.accent2, 12, 1.6)
	return coeur
end

--------------------------------------------------------------------------------
-- MOTEUR DE PARCOURS (formats « tour » et « evasion »)
--
-- Un TRACÉ donne, pour une distance `s` parcourue, la position du chemin, sa
-- direction et son côté extérieur. Les MODULES d'obstacles posent leurs
-- plateformes le long du tracé : le même module sert donc à la tour (tracé en
-- hélice) et à l'évasion (tracé sinueux).
--
-- Règle de conception : le chemin obligatoire n'utilise QUE des plateformes
-- fixes. Les pièges (barres, braises, tapis, dalles fragiles) ne font
-- qu'ajouter du danger. Le validateur du pipeline, qui ne voit que la
-- géométrie fixe, prouve donc bien que chaque étape est franchissable.
--------------------------------------------------------------------------------

local Y_DEPART = 40 -- altitude du sol de départ
local SAUT_MAX = 6.9 -- plus grand vide à franchir (studs, bord à bord) ; le validateur en accepte ≈ 8,3
local EP_DALLE = 0.6

local P = { etapes = {}, nbPlateformes = 0 }

--------------------------------------------------------------------------------
-- Tracés
--------------------------------------------------------------------------------

local TRACES = {}

-- Hélice autour d'une tour : un tour complet monte de `pasVertical` studs.
function TRACES.tour()
	local rayonTour = 20
	local rayon = rayonTour + 9
	local pente = 22 / (2 * math.pi * rayon)
	local socle = 1.5 -- le chemin démarre un peu au-dessus de l'île : on y monte en sautant (même vers une première marche haute)
	-- margeChute : tombé de cette hauteur sous sa dernière borne, le joueur y est ramené.
	local trace = { rayonTour = rayonTour, rayon = rayon, pente = pente, latBorne = 1.5, latMin = -2.5, latMax = 3.5, coteBonus = 1, margeChute = 14 }
	function trace.point(s)
		-- Sens horaire vu du dessus : ainsi l'axe X des repères pointe vers l'extérieur.
		local angle = -s / rayon
		local dehors = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local avant = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local hauteur = (s > 0) and (socle + pente * s) or 0
		return Vector3.new(0, Y_DEPART + hauteur, 0) + dehors * rayon, avant, dehors
	end
	return trace
end

-- Chemin sinueux vers +Z, avec de légères ondulations de hauteur.
function TRACES.evasion()
	local amplitude, periode = 12, 260
	local vague, periodeVague = 3, 300
	local trace = { latBorne = 0, latMin = -3, latMax = 3, coteBonus = 0, margeChute = 18 }
	function trace.point(s)
		local phase = 2 * math.pi * s / periode
		local x = (s > 0) and amplitude * math.sin(phase) or 0
		local derive = (s > 0) and amplitude * 2 * math.pi / periode * math.cos(phase) or 0
		local avant = Vector3.new(derive, 0, 1).Unit
		local dehors = Vector3.new(-avant.Z, 0, avant.X) -- = axe X du repère
		local y = Y_DEPART + ((s > 0) and vague * math.sin(2 * math.pi * s / periodeVague) or 0)
		return Vector3.new(x, y, s), avant, dehors
	end
	return trace
end

local trace = TRACES[FABRIQUE.format]()

-- Repère d'un point du chemin : `lat` studs vers l'extérieur, `dy` studs au-dessus.
function P.repere(s, lat, dy)
	local position, avant, dehors = trace.point(s)
	return K.repere(position + dehors * (lat or 0) + Vector3.new(0, dy or 0, 0), avant)
end

function P.borner(lat)
	return math.clamp(lat, trace.latMin, trace.latMax)
end

--------------------------------------------------------------------------------
-- Plateformes
--------------------------------------------------------------------------------

local EP_CORPS = 2.5 -- épaisseur du corps sculpté sous le plateau

-- Détail du thème tout en bas d'une plateforme : lueur, poutrelles ou stalactite.
local function dessous(cf, larg, long)
	local genre = THEME.dessous.genre
	local teinte = C[THEME.dessous.couleur] or C.structure
	local bas = cf * CFrame.new(0, -EP_DALLE - EP_CORPS, 0)
	if genre == "lueur" then
		K.deco({
			Size = Vector3.new(larg * 0.36, 0.3, long * 0.36),
			CFrame = bas * CFrame.new(0, -0.15, 0),
			Color = teinte,
			Material = Enum.Material[THEME.dessous.materiau or "Neon"],
			CastShadow = false,
			Name = "Lueur",
		})
	elseif genre == "poutre" then
		K.deco({ Size = Vector3.new(0.6, 0.7, long * 0.7), CFrame = bas * CFrame.new(0, 0.2, 0), Color = teinte, Material = Enum.Material.Metal, Name = "Poutre" })
		K.deco({ Size = Vector3.new(larg * 0.7, 0.5, 0.6), CFrame = bas * CFrame.new(0, 0.3, 0), Color = teinte, Material = Enum.Material.Metal, Name = "Traverse" })
	else -- "pointes" : une vraie pointe (stalactite, racine, coulure), taillée en pyramide
		local demi = math.min(larg, long) * 0.16
		K.pyramide(bas, demi, K.hasard(1.6, 3), {
			Color = K.nuance(teinte, 0.04),
			Material = Enum.Material[THEME.dessous.materiau or "SmoothPlastic"],
			Transparency = THEME.dessous.transparence or 0,
			Name = "Pointe",
		}, true)
	end
end

-- Dalle rectangulaire. `cf` : centre du DESSUS de la dalle. Renvoie la pièce où l'on marche.
-- Modelé : un plateau couleur d'accent dont on ne voit que le pourtour (il sert de
-- cadre, bien visible pour viser le saut), un dessus incrusté, un corps en deux
-- gradins qui se resserrent vers le bas, puis le détail du thème.
function P.dalle(cf, larg, long, options)
	options = options or {}
	P.nbPlateformes += 1
	local teinte = options.Color or K.nuance(C.sol, 0.03)
	local plateau = K.piece({
		Size = Vector3.new(larg, EP_DALLE, long),
		CFrame = cf * CFrame.new(0, -EP_DALLE / 2, 0),
		Color = options.nue and teinte or C.accent,
		Material = options.nue and (options.Material or MAT.sol) or MAT.structureAlt,
		Transparency = options.Transparency or 0,
		Parent = options.Parent or D.Structure,
		Name = options.Name or "Dalle",
	})
	if options.nue then
		return plateau
	end
	K.deco({
		Size = Vector3.new(larg - 0.8, 0.1, long - 0.8),
		CFrame = cf * CFrame.new(0, 0.03, 0),
		Color = teinte,
		Material = options.Material or MAT.sol,
		CastShadow = false,
		Name = "Dessus",
	})
	local gradins = { { 0.9, 1.2, C.structure, MAT.structure }, { 0.56, 1.3, C.structureAlt, MAT.structureAlt } }
	local y = -EP_DALLE
	for _, gradin in ipairs(gradins) do
		K.deco({
			Size = Vector3.new(larg * gradin[1], gradin[2], long * gradin[1]),
			CFrame = cf * CFrame.new(0, y - gradin[2] / 2, 0),
			Color = gradin[3],
			Material = gradin[4],
			Name = "Gradin",
		})
		y -= gradin[2]
	end
	-- Les pointes (quatre pièces chacune) ne garnissent qu'une plateforme sur deux : budget de pièces.
	if THEME.dessous.genre ~= "pointes" or P.nbPlateformes % 2 == 0 then
		dessous(cf, larg, long)
	end
	return plateau
end

-- Dalle posée sur le tracé. `s` : centre de la dalle.
function P.plateforme(s, lat, dy, long, larg, options)
	return P.dalle(P.repere(s, lat, dy), larg, long, options)
end

-- Plateforme ronde (pilier). Renvoie la pièce où l'on marche.
function P.pilier(s, lat, dy, diametre)
	P.nbPlateformes += 1
	local cf = P.repere(s, lat, dy)
	local dessus = K.cylindre(nil, EP_DALLE, diametre, {
		CFrame = cf * CFrame.new(0, -EP_DALLE / 2, 0),
		Color = K.nuance(C.solAlt, 0.03),
		Material = MAT.solAlt,
		Parent = D.Structure,
		Name = "Pilier",
	})
	local etages = { { 0.35, 1.08, C.accent, MAT.structureAlt }, { 4.6, 0.74, C.structure, MAT.structure }, { 0.5, 0.9, C.structureAlt, MAT.structureAlt }, { 3.4, 0.46, C.structureAlt, MAT.structureAlt } }
	local y = -EP_DALLE + 0.1
	for _, etage in ipairs(etages) do
		K.cylindre(nil, etage[1], diametre * etage[2], {
			CFrame = cf * CFrame.new(0, y - etage[1] / 2, 0),
			Color = etage[3],
			Material = etage[4],
			CanCollide = false,
			CanTouch = false,
			Name = "Fut",
		})
		y -= etage[1]
	end
	return dessus
end

-- Gemme flottant au-dessus d'une pièce où l'on marche.
function P.gemmeSur(piece, valeur)
	return K.gemme(piece.CFrame.Position + Vector3.new(0, piece.Size.Y / 2 + 3.4, 0), valeur or 1)
end

--------------------------------------------------------------------------------
-- Modules d'obstacles
-- module(s, d) : `s` = fin de la plateforme précédente, `d` = difficulté (0 → 1).
-- Renvoie le `s` de fin de sa dernière plateforme.
--
-- Retour de jeu sur la version 2 : « des cases partout, on pourrait presque tout
-- faire en marchant ». Les vides vont donc de 4,6 à 6,9 studs (au lieu de 3,4 à
-- 6,5), les dalles sont plus petites, et plus aucun module ne se traverse sans sauter.
--------------------------------------------------------------------------------

local function ecart(d, maxi)
	return math.min(maxi or SAUT_MAX, 4.6 + 2.2 * d + K.hasard(-0.25, 0.25))
end

local function largeur(d)
	return 6 - 2.5 * d
end

-- Lampe du thème posée au bord d'une longue plateforme.
function P.lampeBord(cf, larg, long)
	local cote = K.choisir({ -1, 1 })
	K.lampe((cf * CFrame.new(cote * (larg / 2 - 0.7), 0, cote * (long / 2 - 1.2))).Position)
end

local MODULES = {}

-- Dalles espacées, légèrement décalées d'un côté ou de l'autre.
function MODULES.dalles(s, d)
	local larg = largeur(d)
	local lat = 0
	for i = 1, 4 do
		local long = K.hasard(3.6, 4.6)
		s += ecart(d)
		lat = P.borner(lat + K.hasard(-1, 1) * math.min(1.8, larg - 2))
		local piece = P.plateforme(s + long / 2, lat, 0, long, larg)
		if i == 2 then
			P.gemmeSur(piece)
		end
		s += long
	end
	return s
end

-- Poutre étroite en deux tronçons décalés : il faut viser en sautant dessus.
function MODULES.poutre(s, d)
	local long = 6 + 2 * d
	local larg = 1.8 - 0.6 * d
	local lat = K.hasard(-1, 1)
	s += ecart(d, 5.5)
	local premier = P.plateforme(s + long / 2, lat, 0, long, larg, { Color = C.solAlt, Material = MAT.solAlt })
	P.gemmeSur(premier)
	s += long
	P.plateforme(s + long / 2, lat + K.choisir({ -1, 1 }) * (larg - 0.3), 0, long, larg, { Color = C.solAlt, Material = MAT.solAlt })
	return s + long
end

-- Piliers ronds en quinconce.
function MODULES.piliers(s, d)
	local diametre = 4 - 1.4 * d
	local decalage = 1.4 + 0.8 * d
	local lat = 0
	local nb = 5
	s += ecart(d, 6.2) + diametre / 2
	for i = 1, nb do
		local nouveau = (i == 1 or i == nb) and 0 or ((i % 2 == 0) and decalage or -decalage)
		if i > 1 then
			local vide = ecart(d, 6.2)
			local delta = nouveau - lat
			s += math.sqrt(math.max(1, (vide + diametre) ^ 2 - delta * delta))
		end
		lat = nouveau
		local piece = P.pilier(s, lat, 0, diametre)
		if i == 3 then
			P.gemmeSur(piece)
		end
	end
	return s + diametre / 2
end

-- Marches qui montent puis redescendent.
function MODULES.bosse(s, d)
	local larg = largeur(d)
	local long = 4
	local hauteurs = { 1.8, 3.6, 5, 2.6, 0 }
	for i, dy in ipairs(hauteurs) do
		s += ecart(d, 5.2)
		local piece = P.plateforme(s + long / 2, 0, dy, long, larg, { Color = K.melange(C.sol, C.solAlt, i / #hauteurs), Material = MAT.solAlt })
		if i == 3 then
			P.gemmeSur(piece)
		end
		s += long
	end
	return s
end

-- Petites dalles en zigzag : chaque saut part en diagonale.
function MODULES.zigzag(s, d)
	local cote = 3.4 - 0.6 * d
	local decalage = 2.3
	local lat = 0
	local sens = K.choisir({ -1, 1 })
	for i = 1, 5 do
		local nouveau = (i == 1) and 0 or sens * decalage
		local videLateral = math.max(0, math.abs(nouveau - lat) - cote)
		local vide = ecart(d, 6.2)
		s += math.sqrt(math.max(0.5, vide * vide - videLateral * videLateral))
		lat = nouveau
		sens = -sens
		local piece = P.plateforme(s + cote / 2, lat, 0, cote, cote)
		if i == 3 then
			P.gemmeSur(piece)
		end
		s += cote
	end
	return s
end

-- Plateforme balayée par des barres tournantes mortelles (à sauter).
function MODULES.lames(s, d)
	local long = 18
	local larg = math.max(largeur(d) + 1, 6.5)
	s += ecart(d, 5.5)
	local cf = P.repere(s + long / 2, 0, 0)
	local sol = P.dalle(cf, larg, long, { Color = C.solAlt, Material = MAT.solAlt })
	P.gemmeSur(sol)
	P.lampeBord(cf, larg, long)
	local positions = (d > 0.45) and { -4.5, 4.5 } or { 0 }
	for i, z in ipairs(positions) do
		K.cylindre(nil, 1.7, 1.5, {
			CFrame = cf * CFrame.new(0, 0.85, z),
			Color = C.structureAlt,
			Material = Enum.Material.Metal,
			Name = "Moyeu",
		})
		K.boule((cf * CFrame.new(0, 1.9, z)).Position, 1.1, { Color = C.danger, Material = Enum.Material.Metal, CanCollide = false, CanTouch = false, Name = "Coiffe" })
		local barre = K.piece({
			Size = Vector3.new(larg * 1.15, 1, 0.8),
			CFrame = cf * CFrame.new(0, 0.9, z),
			Color = C.danger,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = D.Dangers,
			Name = "Barre",
		})
		barre:SetAttribute("VitesseRotation", ((i % 2 == 0) and -1 or 1) * (1.1 + 1.1 * d))
	end
	return s + long
end

-- Plateforme coupée de bandes brûlantes (à sauter).
function MODULES.braises(s, d)
	local long = 18
	local larg = math.max(largeur(d), 5)
	s += ecart(d, 5.5)
	local cf = P.repere(s + long / 2, 0, 0)
	local sol = P.dalle(cf, larg, long)
	P.lampeBord(cf, larg, long)
	for i, z in ipairs({ -5, 0, 5 }) do
		local bande = K.piece({
			Size = Vector3.new(larg - 0.8, 0.5, 1.8 + 1.2 * d),
			CFrame = cf * CFrame.new(0, 0.15, z),
			Color = C.danger,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = D.Dangers,
			Name = "Braise",
		})
		if i == 2 then
			K.lumiere(bande, C.danger, 12, 1.2)
		end
	end
	K.gemme(sol.CFrame.Position + Vector3.new(0, 4.6, 0), 1) -- au-dessus de la bande centrale : à prendre en sautant
	return s + long
end

-- Dalles de verre : elles rougissent quand on marche dessus, puis s'effacent.
function MODULES.fragiles(s, d)
	local larg = largeur(d) + 0.5
	for i = 1, 4 do
		local long = 4.6
		s += ecart(d, 5.5)
		local cf = P.repere(s + long / 2, 0, 0)
		local piece = P.dalle(cf, larg, long, {
			Color = C.accent2,
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			Parent = D.Fragiles,
			Name = "Fragile",
			nue = true,
		})
		K.deco({
			Size = Vector3.new(larg + 0.4, 0.25, long + 0.4),
			CFrame = cf * CFrame.new(0, -EP_DALLE - 0.15, 0),
			Color = C.accent2,
			Material = MAT.structureAlt,
			Transparency = 0.2,
			CastShadow = false,
			Name = "Cadre",
		})
		if i == 3 then
			P.gemmeSur(piece)
		end
		s += long
	end
	return s
end

-- Tapis roulant qui pousse vers l'arrière.
function MODULES.tapis(s, d)
	local long = 18
	local larg = math.max(largeur(d), 5)
	s += ecart(d, 5.5)
	local cf = P.repere(s + long / 2, 0, 0)
	local tapis = P.dalle(cf, larg, long, { Color = C.noir, Material = Enum.Material.DiamondPlate, Parent = D.Tapis, Name = "Tapis" })
	local _, avant = trace.point(s + long / 2)
	tapis:SetAttribute("VitesseTapis", avant * -(5 + 5 * d))
	for z = -6, 6, 4 do
		for _, cote in ipairs({ -1, 1 }) do
			K.deco({
				Size = Vector3.new(larg * 0.36, 0.08, 0.45),
				CFrame = cf * CFrame.new(cote * larg * 0.14, 0.05, z) * CFrame.Angles(0, cote * math.rad(32), 0),
				Color = C.accent,
				Name = "Chevron",
			})
		end
	end
	P.gemmeSur(tapis)
	return s + long
end

-- Plateforme barrée de murets à enjamber.
function MODULES.murets(s, d)
	local long = 18
	local larg = math.max(largeur(d), 5.5)
	s += ecart(d, 5.5)
	local cf = P.repere(s + long / 2, 0, 0)
	local sol = P.dalle(cf, larg, long)
	P.lampeBord(cf, larg, long)
	local h = 2.2 + 1.6 * d
	for _, z in ipairs({ -5, 0, 5 }) do
		K.piece({
			Size = Vector3.new(larg, h, 1),
			CFrame = cf * CFrame.new(0, h / 2, z),
			Color = C.structureAlt,
			Material = MAT.structureAlt,
			Parent = D.Structure,
			Name = "Muret",
		})
		K.deco({
			Size = Vector3.new(larg + 0.3, 0.3, 1.3),
			CFrame = cf * CFrame.new(0, h + 0.15, z),
			Color = C.accent,
			Material = MAT.structureAlt,
			Name = "Lisere",
		})
	end
	K.gemme(sol.CFrame.Position + Vector3.new(0, h + 3.6, 0), 1) -- au-dessus du muret central
	return s + long
end

local MODULES_CALMES = { "dalles", "poutre", "piliers", "bosse", "zigzag" }
local MODULES_PIEGES = { "lames", "braises", "fragiles", "tapis", "murets" }

--------------------------------------------------------------------------------
-- Bornes d'étape, arche, arrivée
--------------------------------------------------------------------------------

-- Arche en travers du chemin, avec un texte sur le linteau (des deux côtés).
function P.arche(cf, larg, texte)
	local hauteur = 8.5
	for _, cote in ipairs({ -1, 1 }) do
		local x = cote * (larg / 2 - 0.9)
		K.piece({ Size = Vector3.new(1.6, hauteur, 1.6), CFrame = cf * CFrame.new(x, hauteur / 2, 0), Color = C.structure, Material = MAT.structure, Name = "Montant" })
		K.deco({ Size = Vector3.new(2.1, 0.7, 2.1), CFrame = cf * CFrame.new(x, 0.35, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Base" })
		K.deco({ Size = Vector3.new(2, 0.5, 2), CFrame = cf * CFrame.new(x, hauteur - 1.4, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Chapiteau" })
		local bandeau = K.deco({ Size = Vector3.new(0.3, hauteur - 3, 0.3), CFrame = cf * CFrame.new(x - cote * 0.9, hauteur / 2 - 0.4, 0), Color = C.accent, Material = Enum.Material.Neon, CastShadow = false, Name = "Bandeau" })
		K.lumiere(bandeau, C.accent, 14, 1.2)
	end
	local linteau = K.piece({ Size = Vector3.new(larg + 1.4, 2.2, 1.8), CFrame = cf * CFrame.new(0, hauteur + 1.1, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Linteau" })
	K.deco({ Size = Vector3.new(larg + 2, 0.4, 2.3), CFrame = cf * CFrame.new(0, hauteur + 2.4, 0), Color = C.accent, Material = Enum.Material.Neon, CastShadow = false, Name = "Corniche" })
	K.texte(linteau, Enum.NormalId.Front, texte, C.accent2)
	K.texte(linteau, Enum.NormalId.Back, texte, C.accent2)
end

-- Borne d'étape : grande plateforme, arche numérotée, lampes, petit détour bonus.
function P.borne(s, numero, d)
	local long, larg = 12, 12
	s += ecart(d, 5)
	local milieu = s + long / 2
	local cf = P.repere(milieu, trace.latBorne, 0)
	P.dalle(cf, larg, long, { Color = C.solAlt, Material = MAT.solAlt, Name = "Palier" })
	K.deco({ -- disque lumineux au sol, sous l'arche
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 7, 7),
		CFrame = cf * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.accent,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CastShadow = false,
		Name = "Halo",
	})
	P.arche(cf, larg, tostring(numero))

	local zone = K.piece({ -- zone de contact invisible : c'est elle qui valide l'étape
		Size = Vector3.new(larg - 3.4, 7, 3),
		CFrame = cf * CFrame.new(0, 3.5, 0),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = D.Etapes,
		Name = "Etape" .. numero,
	})
	zone:SetAttribute("Numero", numero)
	K.emetteur(zone, {
		Color = ColorSequence.new(C.accent, C.accent2),
		Size = NumberSequence.new(0.8, 0.1),
		Lifetime = NumberRange.new(0.6, 1.2),
		Rate = 0,
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Enabled = false,
	})
	local son = Instance.new("Sound")
	son.SoundId = SON_COLLECTE
	son.Volume = 0.28
	son.PlaybackSpeed = 1.35
	son.RollOffMaxDistance = 80
	son.Parent = zone

	-- Décor du palier : deux éléments du thème, aux coins de sortie.
	K.lampe((cf * CFrame.new(-(larg / 2 - 1.4), 0, -(long / 2 - 1.4))).Position)
	if numero % 2 == 0 then
		K.special((cf * CFrame.new(larg / 2 - 2.8, 0, long / 2 - 2.8)).Position)
	else
		K.cristaux((cf * CFrame.new(larg / 2 - 1.6, 0, long / 2 - 1.6)).Position, 3.2, C.accent2)
	end

	-- Détour bonus : deux petites dalles sur le côté, une gemme ×5 au bout.
	local cote = (trace.coteBonus ~= 0) and trace.coteBonus or K.choisir({ -1, 1 })
	local x = cote * (larg / 2)
	for i = 1, 2 do
		x += cote * (4.4 + 1.75)
		local dalle = P.dalle(cf * CFrame.new(x, 0.6 * i, 3), 3.5, 3.5, { Color = C.accent2, Material = MAT.solAlt })
		if i == 2 then
			P.gemmeSur(dalle, 5)
		end
		x += cote * 1.75
	end

	P.etapes[numero] = { s = milieu, cf = cf, larg = larg, long = long, cote = cote }
	return s + long
end

-- Cachette : une petite corniche sous un palier, côté détour bonus. On y descend
-- en se laissant tomber entre le palier et la première dalle bonus ; la relique
-- est sous le surplomb, presque invisible d'en haut.
function P.cachette(cf, larg, long, cote, numero)
	local corniche = cf * CFrame.new(cote * (larg / 2 + 0.6), -9, long / 2 - 2.2)
	P.dalle(corniche, 4.2, 4.2, { Color = C.structureAlt, Material = MAT.structureAlt, Name = "Corniche" })
	K.secret((corniche * CFrame.new(-cote * 0.9, 2.4, 0)).Position, numero)
end

-- Terrasse d'arrivée : trophée, zone de victoire, drapeaux.
function P.arrivee(s, numero)
	local long, larg = 26, 22
	s += 4
	local cf = P.repere(s + long / 2, trace.latBorne, 0)
	local sol = P.dalle(cf, larg, long, { Color = C.solAlt, Material = MAT.solAlt, Name = "Terrasse" })
	sol:SetAttribute("Arrivee", true)
	P.arche(cf * CFrame.new(0, 0, long / 2 - 2), larg, "🏁")

	-- Estrade ronde et trophée
	local estrade = cf * CFrame.new(0, 0, -3)
	K.cylindre(nil, 0.8, 11, { CFrame = estrade * CFrame.new(0, 0.4, 0), Color = C.structure, Material = MAT.structure, Parent = D.Structure, Name = "Estrade" })
	K.cylindre(nil, 0.3, 9.6, { CFrame = estrade * CFrame.new(0, 0.95, 0), Color = C.accent, Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Anneau" })
	local socle = K.cylindre(nil, 2.2, 2.6, { CFrame = estrade * CFrame.new(0, 1.9, 0), Color = C.structureAlt, Material = MAT.structureAlt, Parent = D.Structure, Name = "Socle" })
	K.gemme(socle.CFrame.Position + Vector3.new(0, 1.1 + 2.6, 0), 25)

	local zone = K.piece({ -- zone de victoire invisible, sur l'estrade
		Size = Vector3.new(11, 7, 11),
		CFrame = estrade * CFrame.new(0, 4.3, 0),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = map,
		Name = "Arrivee",
	})
	zone:SetAttribute("Numero", numero)
	K.emetteur(zone, {
		Color = ColorSequence.new(C.accent, C.accent2),
		Size = NumberSequence.new(1, 0.2),
		Lifetime = NumberRange.new(1, 2),
		Rate = 0,
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Enabled = false,
	})
	K.etiquette(zone, "🏆", 6, C.accent2)

	-- Drapeaux et lampes aux quatre coins
	for _, coin in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local pied = cf * CFrame.new(coin[1] * (larg / 2 - 1.2), 0, coin[2] * (long / 2 - 1.2))
		K.deco({ Size = Vector3.new(0.4, 9, 0.4), CFrame = pied * CFrame.new(0, 4.5, 0), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Hampe" })
		K.deco({
			Size = Vector3.new(0.15, 2.2, 3.4),
			CFrame = pied * CFrame.new(0, 7.7, -1.9),
			Color = (coin[1] * coin[2] > 0) and C.accent or C.accent2,
			Material = Enum.Material.Fabric,
			Name = "Drapeau",
		})
	end
	K.lampe((cf * CFrame.new(-(larg / 2 - 3), 0, 0)).Position)
	K.lampe((cf * CFrame.new(larg / 2 - 3, 0, 0)).Position)

	P.fin = { s = s + long, cf = cf, hauteur = cf.Position.Y, larg = larg, long = long }
	return s + long
end

-- Ligne de départ : la franchir lance le chronomètre de la course.
function P.ligneDepart(cf, larg)
	return K.piece({
		Size = Vector3.new(larg - 3.6, 7, 2),
		CFrame = cf * CFrame.new(0, 3.5, 0),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = map,
		Name = "LigneDepart",
	})
end

--------------------------------------------------------------------------------
-- Construction du chemin complet
--------------------------------------------------------------------------------

function P.construireChemin()
	local nb = FABRIQUE.etapes
	local s = 6
	local precedent = nil
	for etape = 1, nb do
		local d = 0.05 + 0.85 * (etape - 1) / math.max(1, nb - 1)
		local choix = {}
		-- Première étape sans piège ; ensuite un piège par étape, deux à partir de la mi-parcours.
		-- Toujours deux modules de sauts purs ; un piège dès la 2e étape, deux en fin de parcours.
		local nbPieges = (etape == 1) and 0 or ((d > 0.6) and 2 or 1)
		local nbModules = 2 + math.max(1, nbPieges)
		local calmes, pieges = table.clone(MODULES_CALMES), table.clone(MODULES_PIEGES)
		for i = 1, nbModules do
			local reserve = (i > nbModules - nbPieges) and pieges or calmes
			local nom
			repeat
				nom = table.remove(reserve, rng:NextInteger(1, #reserve))
			until nom ~= precedent or #reserve == 0
			table.insert(choix, nom)
			precedent = nom
		end
		-- On mélange l'ordre (les pièges ne sont pas toujours en fin d'étape).
		for i = #choix, 2, -1 do
			local j = rng:NextInteger(1, i)
			choix[i], choix[j] = choix[j], choix[i]
		end
		precedent = choix[#choix]
		for _, nom in ipairs(choix) do
			s = MODULES[nom](s, d)
		end
		if etape < nb then
			s = P.borne(s, etape, d)
		else
			s = P.arrivee(s, nb)
		end
	end
	map:SetAttribute("NombreEtapes", nb)
	map:SetAttribute("MargeChute", trace.margeChute)

	-- Reliques secrètes : sous quatre paliers répartis le long du parcours, et sous l'arrivée.
	local nbBornes = nb - 1
	local nbCachettes = math.min(4, nbBornes)
	local dejaPrise = {}
	local numero = 0
	for k = 1, nbCachettes do
		local borne = math.clamp(math.floor(k * nbBornes / nbCachettes + 0.5), 1, nbBornes)
		if not dejaPrise[borne] then
			dejaPrise[borne] = true
			numero += 1
			local e = P.etapes[borne]
			P.cachette(e.cf, e.larg, e.long, e.cote, numero)
		end
	end
	numero += 1
	P.cachette(P.fin.cf, P.fin.larg, P.fin.long, (trace.coteBonus ~= 0) and trace.coteBonus or 1, numero)
	map:SetAttribute("NombreSecrets", numero)
	return s
end

--------------------------------------------------------------------------------
-- Vide mortel sous la map
--------------------------------------------------------------------------------

function P.vide(centre, taille)
	local V = THEME.vide
	-- Une pièce Roblox ne dépasse pas 2048 studs de côté : on pave en longueur si besoin.
	local nb = math.ceil(taille.Z / 1800)
	local longueur = taille.Z / nb
	for n = 1, nb do
		local milieu = centre + Vector3.new(0, 0, -taille.Z / 2 + (n - 0.5) * longueur)
		local dalle = Vector3.new(taille.X, taille.Y, longueur)
		K.piece({
			Size = dalle,
			Position = milieu,
			Color = K.rvb(V.couleur),
			Material = Enum.Material[V.materiau],
			Transparency = V.transparence,
			Reflectance = (V.genre == "eau") and 0.25 or 0,
			CanCollide = false,
			CastShadow = false,
			Parent = D.Dangers,
			Name = "Vide",
		})
		if V.genre == "eau" then
			K.deco({ Size = dalle, Position = milieu - Vector3.new(0, 6, 0), Color = K.melange(K.rvb(V.couleur), C.noir, 0.6), Name = "Fond" })
		end
	end
	workspace.FallenPartsDestroyHeight = centre.Y - 30
end

-- Brume qui monte du vide, autour d'un point.
function P.brume(position, teinte)
	local source = K.deco({ Size = Vector3.new(30, 1, 30), Position = position, Transparency = 1, CastShadow = false, Name = "Brume" })
	K.emetteur(source, {
		Texture = TEXTURE_FUMEE,
		Color = ColorSequence.new(teinte),
		Size = NumberSequence.new(9, 14),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(6, 9),
		Rate = 1.5,
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(30, 30),
	})
end

-- Point d'apparition (un seul : les étapes suivantes sont gérées par le script de jeu).
function P.spawn(cf)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Depart"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = cf * CFrame.new(0, 0.5, 0)
	spawn.Color = C.accent
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = map
	K.deco({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 13, 13),
		CFrame = cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.structureAlt,
		Material = MAT.structureAlt,
		Name = "Rosace",
	})
	return spawn
end

--------------------------------------------------------------------------------
-- SCÈNES : le décor propre à chaque format, construit autour du chemin
--------------------------------------------------------------------------------

-- Îlot flottant purement décoratif (sans collision : on ne peut pas s'y coincer).
function P.ilot(centre, rayon)
	K.cylindre(centre + Vector3.new(0, -1.2, 0), 2.4, rayon * 2, { Color = K.nuance(C.sol, 0.03), Material = MAT.sol, CanCollide = false, CanTouch = false, Name = "Ilot" })
	local y = -2.4
	for i, part in ipairs({ { 4, 1.6 }, { 5, 1 }, { 6, 0.45 } }) do
		K.cylindre(centre + Vector3.new(K.hasard(-0.6, 0.6), y - part[1] / 2, K.hasard(-0.6, 0.6)), part[1], rayon * part[2], {
			Color = K.nuance((i == 1) and C.structure or C.structureAlt, 0.04),
			Material = (i == 1) and MAT.structure or MAT.structureAlt,
			CanCollide = false,
			CanTouch = false,
			Name = "Roche",
		})
		y -= part[1] * 0.85
	end
	K.decorHasard(centre)
	if rayon > 8 then
		local a = K.hasard(0, 6.28)
		K.rocher(centre + Vector3.new(math.cos(a) * rayon * 0.6, 0, math.sin(a) * rayon * 0.6), 2.2)
	end
end

local SCENES = {}

--------------------------------------------------------------------------------
-- Tour : île de départ, tour centrale habillée, couronne lumineuse au sommet
--------------------------------------------------------------------------------

function SCENES.tour()
	local rayonTour = trace.rayonTour
	local sommet = P.fin.hauteur + 14
	local centre = Vector3.new(0, Y_DEPART, 0)

	-- Île de départ (on marche dessus) et sa roche en dessous
	K.cylindre(centre + Vector3.new(0, -4, 0), 8, 136, { Color = C.sol, Material = MAT.sol, Parent = D.Structure, Name = "Ile" })
	local y = -8
	for i, part in ipairs({ { 12, 116 }, { 14, 84 }, { 16, 50 }, { 14, 22 } }) do
		K.cylindre(centre + Vector3.new(0, y - part[1] / 2, 0), part[1], part[2], {
			Color = K.nuance((i % 2 == 1) and C.structure or C.structureAlt, 0.03),
			Material = (i % 2 == 1) and MAT.structure or MAT.structureAlt,
			CanCollide = false,
			CanTouch = false,
			Name = "Roche",
		})
		y -= part[1] * 0.9
	end

	-- Départ : rosace, arche, dalles qui mènent au premier obstacle
	local depart = P.repere(-14, 7, 0)
	local spawn = P.spawn(depart)
	P.arche(P.repere(0, 0, 0), 10, "▶")
	P.ligneDepart(P.repere(0, 0, 0), 10)
	for i = 0, 3 do
		K.deco({
			Size = Vector3.new(5, 0.2, 2.4),
			CFrame = P.repere(-10.4 + i * 3.2, 6 - i * 1.6, 0.1),
			Color = C.solAlt,
			Material = MAT.solAlt,
			Name = "Pas",
		})
	end
	local enseigne = K.deco({ Size = Vector3.new(12, 3, 0.6), CFrame = depart * CFrame.new(0, 10.5, 9), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Enseigne" })
	K.texte(enseigne, Enum.NormalId.Front, FABRIQUE.titre, C.accent2)
	for _, cote in ipairs({ -5, 5 }) do
		K.deco({ Size = Vector3.new(0.6, 10, 0.6), CFrame = depart * CFrame.new(cote, 5, 9), Color = C.bois, Material = MAT.bois, Name = "Poteau" })
	end

	-- Corps de la tour : UN seul cylindre plein (aucun rebord ni palier caché où se
	-- tenir) ; les bandes de couleur sont des habillages sans collision.
	K.cylindre(Vector3.new(0, (sommet + Y_DEPART) / 2, 0), sommet - Y_DEPART, rayonTour * 2, { Color = C.structure, Material = MAT.structure, Name = "Tour" })
	local nbBandes = math.ceil((sommet - Y_DEPART) / 18)
	local hauteurBande = (sommet - Y_DEPART) / nbBandes
	for k = 1, nbBandes do
		local bas = Y_DEPART + (k - 1) * hauteurBande
		if k % 2 == 0 then
			K.cylindre(Vector3.new(0, bas + hauteurBande / 2, 0), hauteurBande, rayonTour * 2 + 0.3, {
				Color = K.melange(C.structure, C.structureAlt, 0.35),
				Material = MAT.structure,
				CanCollide = false,
				CanTouch = false,
				Name = "Bande",
			})
		end
		K.cylindre(Vector3.new(0, bas + 0.6, 0), 1.2, rayonTour * 2 + 1.6, { Color = C.structureAlt, Material = MAT.structureAlt, CanCollide = false, CanTouch = false, Name = "Ceinture" })
		K.cylindre(Vector3.new(0, bas + 1.4, 0), 0.3, rayonTour * 2 + 1, { Color = C.accent, Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Filet" })
		for f = 1, 5 do
			local angle = k * 0.7 + f * (2 * math.pi / 5)
			local fenetre = K.deco({
				Size = Vector3.new(0.5, 3, 1.5),
				CFrame = CFrame.new(0, bas + hauteurBande * 0.55, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(rayonTour, 0, 0),
				Color = C.accent2,
				Material = Enum.Material.Neon,
				CastShadow = false,
				Name = "Fenetre",
			})
			K.deco({
				Size = Vector3.new(0.7, 0.4, 2.1),
				CFrame = fenetre.CFrame * CFrame.new(0, -1.7, 0),
				Color = C.structureAlt,
				Material = MAT.structureAlt,
				Name = "Appui",
			})
			if f == 1 then
				K.lumiere(fenetre, C.accent2, 18, 1)
			end
		end
	end
	for n = 1, nbBandes * 2 do -- bannières de tissu accrochées à la tour
		local angle = n * 2.4
		local haut = Y_DEPART + (n / (nbBandes * 2)) * (sommet - Y_DEPART - 16) + 12
		local accroche = CFrame.new(0, haut, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(rayonTour + 0.5, 0, 0)
		K.deco({ Size = Vector3.new(0.9, 0.5, 4.6), CFrame = accroche * CFrame.new(0.2, 0, 0), Color = C.bois, Material = MAT.bois, Name = "Tringle" })
		K.deco({
			Size = Vector3.new(0.15, 9, 3.8),
			CFrame = accroche * CFrame.new(0.3, -4.7, 0),
			Color = (n % 2 == 0) and C.accent or C.accent2,
			Material = Enum.Material.Fabric,
			Name = "Banniere",
		})
		K.deco({
			Size = Vector3.new(0.2, 1.2, 3.8),
			CFrame = accroche * CFrame.new(0.32, -8.6, 0),
			Color = C.blanc,
			Material = Enum.Material.Fabric,
			Name = "Frange",
		})
	end
	for n = 1, 6 do -- contreforts sur toute la hauteur
		K.deco({
			Size = Vector3.new(1.4, sommet - Y_DEPART, 2),
			CFrame = CFrame.new(0, (sommet + Y_DEPART) / 2, 0) * CFrame.Angles(0, n * math.pi / 3, 0) * CFrame.new(rayonTour + 0.2, 0, 0),
			Color = C.structureAlt,
			Material = MAT.structureAlt,
			Name = "Contrefort",
		})
	end

	-- Couronne : créneaux, anneau lumineux, grands cristaux visibles de partout
	K.cylindre(Vector3.new(0, sommet + 1, 0), 2, rayonTour * 2 + 5, { Color = C.structureAlt, Material = MAT.structureAlt, CanCollide = false, CanTouch = false, Name = "Couronne" })
	K.cylindre(Vector3.new(0, sommet + 2.2, 0), 0.4, rayonTour * 2 + 4, { Color = C.accent, Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Anneau" })
	for n = 1, 10 do
		K.deco({
			Size = Vector3.new(3, 3.4, 4),
			CFrame = CFrame.new(0, sommet + 3.7, 0) * CFrame.Angles(0, n * math.pi / 5, 0) * CFrame.new(rayonTour + 0.8, 0, 0),
			Color = C.structure,
			Material = MAT.structure,
			Name = "Creneau",
		})
	end
	K.cristaux(Vector3.new(0, sommet + 2, 0), 26, C.accent)
	for n = 1, 6 do
		local angle = n * math.pi / 3 + 0.4
		K.cristaux(Vector3.new(math.cos(angle) * 10, sommet + 2, math.sin(angle) * 10), K.hasard(9, 15), (n % 2 == 0) and C.accent or C.accent2)
	end
	local fanal = K.boule(Vector3.new(0, sommet + 30, 0), 5, { Color = C.accent2, Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Fanal" })
	K.lumiere(fanal, C.accent2, 60, 3)

	-- Consoles qui relient chaque palier d'étape à la tour
	for _, etape in pairs(P.etapes) do
		K.deco({
			Size = Vector3.new(6.5, 1.2, 3.4),
			CFrame = etape.cf * CFrame.new(-8.4, -1.5, 0),
			Color = C.structureAlt,
			Material = MAT.structureAlt,
			Name = "Console",
		})
		K.deco({
			Size = Vector3.new(1, 5, 2.4),
			CFrame = etape.cf * CFrame.new(-10.6, -3.6, 0) * CFrame.Angles(0, 0, math.rad(-32)),
			Color = C.structureAlt,
			Material = MAT.structureAlt,
			Name = "Jambe",
		})
	end

	-- Sol en deux tons : parvis clair autour de la tour, anneau extérieur
	K.cylindre(centre + Vector3.new(0, 0.06, 0), 0.12, 84, { Color = C.solAlt, Material = MAT.solAlt, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Parvis" })
	K.cylindre(centre + Vector3.new(0, -3.9, 0), 8.3, 138, { Color = C.structureAlt, Material = MAT.structureAlt, CanCollide = false, CanTouch = false, Name = "Bordure" })

	-- Mares (lave, eau, sirop… selon le thème) bordées de rochers
	local mares = {}
	for n = 1, 5 do
		local angle = n * (2 * math.pi / 5) + K.hasard(-0.3, 0.3)
		local position = centre + Vector3.new(math.cos(angle) * K.hasard(49, 57), 0, math.sin(angle) * K.hasard(49, 57))
		if (position - spawn.CFrame.Position).Magnitude > 20 then
			local rayon = K.hasard(4.5, 7.5)
			local mare = K.cylindre(position + Vector3.new(0, 0.1, 0), 0.2, rayon * 2, {
				Color = K.rvb(THEME.vide.couleur),
				Material = Enum.Material[THEME.vide.materiau],
				Transparency = THEME.vide.transparence,
				CanCollide = false,
				CanTouch = false,
				CastShadow = false,
				Name = "Mare",
			})
			K.lumiere(mare, K.rvb(THEME.vide.couleur), rayon * 3, 1)
			for r = 1, 7 do
				local a = r * 0.9 + K.hasard(-0.2, 0.2)
				K.rocher(position + Vector3.new(math.cos(a) * rayon, -0.4, math.sin(a) * rayon), K.hasard(1.4, 2.4))
			end
			table.insert(mares, { position = position, rayon = rayon })
		end
	end

	-- Décor de l'île : arbres, lampes, rochers, cristaux ; rien près du départ ni dans les mares
	local semes, essais = 0, 0
	while semes < 44 and essais < 400 do
		essais += 1
		local angle, distance = K.hasard(0, 6.28), K.hasard(44, 63)
		local position = centre + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local libre = (position - spawn.CFrame.Position).Magnitude > 16
		for _, mare in ipairs(mares) do
			if (position - mare.position).Magnitude < mare.rayon + 3 then
				libre = false
			end
		end
		if libre then
			K.decorHasard(position)
			semes += 1
		end
	end
	for n = 1, 18 do
		local angle = n * (2 * math.pi / 18) + K.hasard(-0.1, 0.1)
		K.rocher(centre + Vector3.new(math.cos(angle) * 65, -0.6, math.sin(angle) * 65), K.hasard(2.4, 4.4))
	end

	-- Îlots flottants au loin, à différentes hauteurs
	for n = 1, 7 do
		local angle = n * 0.9 + K.hasard(-0.2, 0.2)
		local distance = K.hasard(96, 132)
		P.ilot(Vector3.new(math.cos(angle) * distance, Y_DEPART + K.hasard(-8, (sommet - Y_DEPART) * 0.8), math.sin(angle) * distance), K.hasard(7, 12))
	end

	local niveauVide = Y_DEPART - 62
	P.vide(Vector3.new(0, niveauVide, 0), Vector3.new(1800, 2, 1800))
	for n = 1, 4 do
		local angle = n * math.pi / 2
		P.brume(Vector3.new(math.cos(angle) * 90, niveauVide + 3, math.sin(angle) * 90), K.rvb(THEME.vide.couleur))
	end
end

--------------------------------------------------------------------------------
-- Évasion : cour de départ fortifiée, îlots et pitons le long du chemin, porte de sortie
--------------------------------------------------------------------------------

function SCENES.evasion(sFin)
	-- Cour de départ : sol jusqu'au premier obstacle, trois murs crénelés, grille au fond
	local cour = P.repere(-8, 0, 0)
	P.dalle(cour, 18, 28, { Color = C.solAlt, Material = MAT.solAlt, Name = "Cour" })
	P.spawn(P.repere(-13, 0, 0))
	local hauteurMur = 10
	local murs = {
		{ Vector3.new(18, hauteurMur, 1.4), CFrame.new(0, hauteurMur / 2, 13.3) }, -- fond
		{ Vector3.new(1.4, hauteurMur, 20), CFrame.new(-8.3, hauteurMur / 2, 4) },
		{ Vector3.new(1.4, hauteurMur, 20), CFrame.new(8.3, hauteurMur / 2, 4) },
		{ Vector3.new(4.5, hauteurMur, 1.4), CFrame.new(-6.75, hauteurMur / 2, -6) }, -- façade, de part et d'autre de la brèche
		{ Vector3.new(4.5, hauteurMur, 1.4), CFrame.new(6.75, hauteurMur / 2, -6) },
	}
	for _, mur in ipairs(murs) do
		K.piece({ Size = mur[1], CFrame = cour * mur[2], Color = K.nuance(C.structure, 0.03), Material = MAT.structure, Name = "Mur" })
		K.deco({
			Size = mur[1] * Vector3.new(1, 0, 1) + Vector3.new(0.5, 0.5, 0.5),
			CFrame = cour * mur[2] * CFrame.new(0, hauteurMur / 2 + 0.25, 0),
			Color = C.structureAlt,
			Material = MAT.structureAlt,
			Name = "Couronnement",
		})
		local longueur = math.max(mur[1].X, mur[1].Z)
		local selonX = mur[1].X >= mur[1].Z
		for n = 0, math.floor(longueur / 3.4) do
			local t = -longueur / 2 + 1 + n * 3.4
			if t <= longueur / 2 - 1 then
				K.deco({
					Size = Vector3.new(1.6, 1.4, 1.6),
					CFrame = cour * mur[2] * CFrame.new(selonX and t or 0, hauteurMur / 2 + 1.2, selonX and 0 or t),
					Color = C.structure,
					Material = MAT.structure,
					Name = "Creneau",
				})
			end
		end
	end
	-- Grille du fond et enseigne du jeu
	K.deco({ Size = Vector3.new(6, 5, 0.3), CFrame = cour * CFrame.new(0, 4.5, 12.5), Color = C.noir, Name = "Niche" })
	for n = -2, 2 do
		K.cylindre(nil, 5, 0.35, { CFrame = cour * CFrame.new(n * 1.2, 4.5, 12.2), Color = C.structureAlt, Material = Enum.Material.Metal, CanCollide = false, CanTouch = false, Name = "Barreau" })
	end
	local enseigne = K.deco({ Size = Vector3.new(13, 2.6, 0.5), CFrame = cour * CFrame.new(0, 8.4, 12.3), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Enseigne" })
	K.texte(enseigne, Enum.NormalId.Front, FABRIQUE.titre, C.accent2)
	K.lampe((cour * CFrame.new(-6.4, 0, 11)).Position)
	K.lampe((cour * CFrame.new(6.4, 0, 11)).Position)
	for n, caisse in ipairs({ { -6, 1.1, 2 }, { -6.2, 1, 4.4 }, { -5.8, 3, 2.6 }, { 6, 1.2, -2 } }) do
		K.deco({
			Size = Vector3.new(2.2, caisse[2] * 2, 2.2) * ((n == 3) and 0.8 or 1),
			CFrame = cour * CFrame.new(caisse[1], caisse[2], caisse[3]) * CFrame.Angles(0, K.hasard(-0.3, 0.3), 0),
			Color = K.nuance(C.bois, 0.04),
			Material = MAT.bois,
			Name = "Caisse",
		})
	end
	P.arche(P.repere(3.5, 0, 0), 10, "▶")
	P.ligneDepart(P.repere(3.5, 0, 0), 10)

	-- Îlots de chaque côté du chemin, et grands pitons au loin
	local niveauVide = Y_DEPART - 30
	local s = 26
	while s < sFin do
		for _, cote in ipairs({ -1, 1 }) do
			local position = P.repere(s + K.hasard(-8, 8), cote * K.hasard(24, 38), K.hasard(-7, 9)).Position
			P.ilot(position, K.hasard(6, 10))
		end
		s += 62
	end
	-- Massifs étagés qui sortent du vide, de part et d'autre
	s = 0
	local cote = 1
	while s < sFin + 60 do
		local pied = P.repere(s, cote * K.hasard(52, 78), 0).Position
		local hauteur = K.hasard(34, 66)
		local rayon = K.hasard(9, 15)
		local y = niveauVide
		K.cylindre(Vector3.new(pied.X, niveauVide + 1.2, pied.Z), 0.4, rayon * 3.2, { Color = K.melange(K.rvb(THEME.vide.couleur), C.blanc, 0.45), Material = Enum.Material.SmoothPlastic, Transparency = 0.35, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Ecume" })
		for n = 1, 4 do
			local h = hauteur * ({ 0.4, 0.28, 0.2, 0.12 })[n]
			local r = rayon * (1.25 - n * 0.2)
			K.cylindre(Vector3.new(pied.X + K.hasard(-1.5, 1.5), y + h / 2, pied.Z + K.hasard(-1.5, 1.5)), h, r * 2, {
				Color = K.nuance((n % 2 == 1) and C.structure or C.structureAlt, 0.04),
				Material = (n % 2 == 1) and MAT.structure or MAT.structureAlt,
				CanCollide = false,
				CanTouch = false,
				Name = "Massif",
			})
			y += h
			if n < 4 then
				K.cylindre(Vector3.new(pied.X, y + 0.2, pied.Z), 0.4, r * 2 + 0.8, { Color = (n == 2) and C.accent or C.sol, Material = (n == 2) and Enum.Material.Neon or MAT.sol, CanCollide = false, CanTouch = false, CastShadow = n ~= 2, Name = "Corniche" })
			end
		end
		local sommetMassif = Vector3.new(pied.X, y, pied.Z)
		K.cylindre(sommetMassif + Vector3.new(0, 0.2, 0), 0.4, rayon * 0.95, { Color = C.sol, Material = MAT.sol, CanCollide = false, CanTouch = false, Name = "Plateau" })
		K.special(sommetMassif + Vector3.new(0, 0.4, 0))
		K.arbre(sommetMassif + Vector3.new(rayon * 0.28, 0.4, -rayon * 0.2), K.hasard(1, 1.5))
		cote = -cote
		s += 66
	end

	-- Enceinte lointaine : deux murailles à tours qui ferment l'horizon
	local hautMur = Y_DEPART - niveauVide + 12
	for _, bord in ipairs({ -1, 1 }) do
		local z = -60
		local n = 0
		while z < sFin + 120 do
			n += 1
			local x = bord * (118 + 10 * math.sin(n * 1.3))
			K.deco({ Size = Vector3.new(7, hautMur, 112), Position = Vector3.new(x, niveauVide + hautMur / 2, z + 56), Color = K.nuance(C.structure, 0.03), Material = MAT.structure, Name = "Muraille" })
			K.deco({ Size = Vector3.new(8, 1, 112), Position = Vector3.new(x, niveauVide + hautMur + 0.5, z + 56), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Chemin de ronde" })
			K.deco({ Size = Vector3.new(0.4, 0.8, 112), Position = Vector3.new(x - bord * 3.6, niveauVide + hautMur * 0.72, z + 56), Color = C.accent, Material = Enum.Material.Neon, CastShadow = false, Name = "Filet" })
			local hautTour = hautMur + K.hasard(14, 26)
			K.deco({ Size = Vector3.new(16, hautTour, 16), Position = Vector3.new(x, niveauVide + hautTour / 2, z), Color = K.nuance(C.structureAlt, 0.03), Material = MAT.structureAlt, Name = "Tour de guet" })
			K.deco({ Size = Vector3.new(19, 2, 19), Position = Vector3.new(x, niveauVide + hautTour + 1, z), Color = C.structure, Material = MAT.structure, Name = "Chapeau" })
			for etage = 1, 3 do
				K.deco({ Size = Vector3.new(0.4, 3, 2), Position = Vector3.new(x - bord * 8.1, niveauVide + hautTour - etage * 9, z), Color = C.accent2, Material = Enum.Material.Neon, CastShadow = false, Name = "Fenetre" })
			end
			local feu = K.boule(Vector3.new(x, niveauVide + hautTour + 4, z), 3, { Color = C.danger, Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Feu" })
			if n % 2 == 0 then
				K.lumiere(feu, C.danger, 40, 1.6)
			end
			z += 112
		end
	end

	-- Porte de sortie monumentale derrière la terrasse d'arrivée
	local sortie = P.fin.cf * CFrame.new(0, 0, -15)
	for _, x in ipairs({ -15, 15 }) do
		K.deco({ Size = Vector3.new(7, 34, 7), CFrame = sortie * CFrame.new(x, 6, 0), Color = C.structure, Material = MAT.structure, Name = "TourSortie" })
		K.deco({ Size = Vector3.new(8.4, 2, 8.4), CFrame = sortie * CFrame.new(x, 23.5, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Chemin" })
		local phare = K.boule((sortie * CFrame.new(x, 26.5, 0)).Position, 3.2, { Color = C.accent, Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Phare" })
		K.lumiere(phare, C.accent, 40, 2.2)
	end
	K.deco({ Size = Vector3.new(26, 4, 4), CFrame = sortie * CFrame.new(0, 18, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Passerelle" })
	K.deco({ Size = Vector3.new(22, 14, 0.6), CFrame = sortie * CFrame.new(0, 9, 0), Color = C.accent2, Material = Enum.Material.ForceField, CastShadow = false, Name = "Portail" })

	P.vide(Vector3.new(0, niveauVide, sFin / 2), Vector3.new(900, 2, sFin + 700))
	for z = 60, sFin, 220 do
		P.brume(Vector3.new(0, niveauVide + 3, z), K.rvb(THEME.vide.couleur))
	end
end

--------------------------------------------------------------------------------
-- Assemblage final
--------------------------------------------------------------------------------

K.ambiance()
local sFin = P.construireChemin()
SCENES[FABRIQUE.format](sFin)
map.Parent = workspace

local scriptJeu = Instance.new("Script")
scriptJeu.Name = "Parcours_Jeu"
scriptJeu.Source = SOURCE_JEU
scriptJeu.Parent = ServerScriptService

local nbPieces = 0
for _, objet in ipairs(map:GetDescendants()) do
	if objet:IsA("BasePart") then
		nbPieces += 1
	end
end
print("=====================================================")
print("✦ " .. FABRIQUE.titre .. " — construit par la Fabrique ✦")
print("• Format : " .. FABRIQUE.format .. " · thème : " .. THEME.nom .. " · graine : " .. FABRIQUE.graine)
print("• Étapes : " .. FABRIQUE.etapes .. " · plateformes : " .. P.nbPlateformes .. " · longueur : " .. math.floor(sFin) .. " studs")
print("• Pièces : " .. nbPieces .. " · gemmes : " .. #D.Collectibles:GetChildren())
print("• Script de jeu installé : ServerScriptService.Parcours_Jeu")
print("=====================================================")
