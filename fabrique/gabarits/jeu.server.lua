-- Script de jeu d'un parcours de la Fabrique (installé par le script de construction).
-- Gère : étapes sauvegardées, retour à la dernière étape, pièges, gemmes, victoire.
--
-- Avec le noyau commun (build du pipeline avec --src src) : les gemmes vont dans
-- le profil sauvegardé du joueur et l'étape atteinte est conservée entre deux
-- visites. Sans lui (script collé seul dans Studio) : tout marche, sans sauvegarde.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local map = workspace:WaitForChild("Parcours")
local dossierEtapes = map:WaitForChild("Etapes")
local dossierGemmes = map:WaitForChild("Collectibles")
local dossierDangers = map:WaitForChild("Dangers")
local dossierFragiles = map:WaitForChild("Fragiles")
local dossierTapis = map:WaitForChild("Tapis")
local depart = map:WaitForChild("Depart")
local arrivee = map:WaitForChild("Arrivee")

local NOM_JEU = map:GetAttribute("Nom") or "parcours"
local NB_ETAPES = map:GetAttribute("NombreEtapes") or 1
local TEMPS_REAPPARITION = 25 -- secondes avant qu'une gemme revienne
local GAIN_ETAPE = 3
local GAIN_VICTOIRE = 50

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

local progressions = {} -- [joueur] = { jeu, etape, victoires }
local sauvegardees = {} -- [joueur] = true quand la progression est celle du profil sauvegardé
local enVictoire = {}

local function progression(joueur)
	local p = progressions[joueur]
	if not p then
		p = { jeu = NOM_JEU, etape = 0, victoires = 0 }
		progressions[joueur] = p
	end
	if API and not sauvegardees[joueur] then
		local donnees = API.donneesJeu(joueur)
		if donnees then
			local garde = donnees.parcours
			if type(garde) ~= "table" then
				garde = { jeu = NOM_JEU, etape = 0, victoires = 0 }
			elseif garde.jeu ~= NOM_JEU then
				-- Sauvegarde d'un autre parcours publié dans la même expérience : on repart du début.
				garde.jeu, garde.etape = NOM_JEU, 0
			end
			garde.etape = math.clamp(math.max(tonumber(garde.etape) or 0, p.etape), 0, NB_ETAPES - 1)
			garde.victoires = (tonumber(garde.victoires) or 0) + p.victoires
			donnees.parcours = garde
			progressions[joueur] = garde
			sauvegardees[joueur] = true
			p = garde
		end
	end
	return p
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
	local etape = valeurStat(joueur, "Étape")
	if etape then
		etape.Value = p.etape
	end
	local victoires = valeurStat(joueur, "Victoires")
	if victoires then
		victoires.Value = p.victoires
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

--------------------------------------------------------------------------------
-- Retour à la dernière étape atteinte
--------------------------------------------------------------------------------

local function placer(joueur, perso)
	local p = progression(joueur)
	local racine = perso:WaitForChild("HumanoidRootPart", 10)
	if not racine then
		return
	end
	local zone = bornes[p.etape]
	if zone then
		racine.CFrame = zone.CFrame * CFrame.new(0, 1, 2)
	end
end

local function joueurArrive(joueur)
	joueur.CharacterAdded:Connect(function(perso)
		task.wait(0.1) -- laisse Roblox poser le personnage au départ avant de le déplacer
		if perso.Parent then
			placer(joueur, perso)
		end
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
		local p = progression(joueur)
		if p.etape > 0 and joueur.Character then
			placer(joueur, joueur.Character)
		end
	end)
end

Players.PlayerAdded:Connect(joueurArrive)
for _, joueur in ipairs(Players:GetPlayers()) do
	joueurArrive(joueur)
end
Players.PlayerRemoving:Connect(function(joueur)
	progressions[joueur] = nil
	sauvegardees[joueur] = nil
	enVictoire[joueur] = nil
end)

--------------------------------------------------------------------------------
-- Étapes et victoire
--------------------------------------------------------------------------------

local function joueurDe(hit)
	local perso = hit and hit.Parent
	local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(perso), humanoide, perso
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
	majStats(joueur)
	crediter(joueur, GAIN_VICTOIRE, "victoire")
	effet(arrivee, 80)
	annoncer(joueur, "🏆 " .. p.victoires)
	task.delay(4, function()
		enVictoire[joueur] = nil
		local racine = perso.Parent and perso:FindFirstChild("HumanoidRootPart")
		if racine then
			racine.CFrame = depart.CFrame * CFrame.new(0, 4, 0)
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

for _, dalle in ipairs(dossierFragiles:GetChildren()) do
	if dalle:IsA("BasePart") then
		local transparence = dalle.Transparency
		local active = false
		dalle.Touched:Connect(function(hit)
			if active or not joueurDe(hit) then
				return
			end
			active = true
			task.wait(0.45)
			dalle.Transparency = 0.9
			dalle.CanCollide = false
			task.wait(2.5)
			dalle.Transparency = transparence
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
-- Gemmes
--------------------------------------------------------------------------------

local gemmes, basesGemmes = {}, {}
for _, gemme in ipairs(dossierGemmes:GetChildren()) do
	if gemme:IsA("BasePart") then
		table.insert(gemmes, gemme)
		basesGemmes[gemme] = gemme.CFrame
		local transparence = gemme.Transparency
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
			effet(gemme, 30)
			local lumiere = gemme:FindFirstChildOfClass("PointLight")
			if lumiere then
				lumiere.Enabled = false
			end
			gemme.Transparency = 1
			gemme.CanTouch = false
			task.delay(TEMPS_REAPPARITION, function()
				if not gemme.Parent then
					return
				end
				gemme.Transparency = transparence
				gemme.CanTouch = true
				if lumiere then
					lumiere.Enabled = true
				end
				gemme:SetAttribute("Pris", false)
			end)
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

local temps = 0
RunService.Heartbeat:Connect(function(dt)
	temps += dt
	for _, rotor in ipairs(rotors) do
		rotor.CFrame = basesRotors[rotor] * CFrame.Angles(0, temps * rotor:GetAttribute("VitesseRotation"), 0)
	end
	for i, gemme in ipairs(gemmes) do
		gemme.CFrame = basesGemmes[gemme] * CFrame.new(0, math.sin(temps * 2 + i) * 0.35, 0) * CFrame.Angles(0, temps * 1.5, 0)
	end
end)
