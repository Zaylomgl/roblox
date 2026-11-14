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
