--[[
	Combat de Givrecendre, côté serveur (fait autorité : anti-triche).

	- Vie, endurance, roulade, fioles des joueurs (règles : Givrecendre.Regles)
	- IA de Grimmulf, l'Ogre du Col (cerveau : Givrecendre.IAOgre) : déplacement,
	  télégraphes au sol, balayage, onde de choc, charge, rochers en phase 2
	- Récompenses à la victoire (profil sauvegardé via Noyau.API si présent)

	Ne fait rien si workspace.Givrecendre.Ogre n'existe pas.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local dossier = workspace:FindFirstChild("Givrecendre")
local ogre = dossier and dossier:FindFirstChild("Ogre")
if not (ogre and ogre:IsA("Model")) then
	warn("[Combat] workspace.Givrecendre.Ogre introuvable : combat désactivé")
	return
end

local Partage = ReplicatedStorage:WaitForChild("Givrecendre")
local Regles = require(Partage:WaitForChild("Regles"))
local IA = require(Partage:WaitForChild("IAOgre"))

local API = nil
do
	local noyau = ServerScriptService:FindFirstChild("Noyau")
	if noyau and noyau:FindFirstChild("API") then
		API = require(noyau.API)
	else
		warn("[Combat] Noyau absent : les récompenses ne seront PAS sauvegardées")
	end
end

-- Hauteur du sol (terrain) en (x, z) : mesurée, jamais supposée
-- (le sol pavé de la cour est à y ≈ 1,8 et non 0 : mesuré en jeu le 01/11/2026).
local paramsSol = RaycastParams.new()
paramsSol.FilterType = Enum.RaycastFilterType.Include
paramsSol.FilterDescendantsInstances = { workspace.Terrain }
local function hauteurSol(x: number, z: number, defaut: number): number
	local r = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -240, 0), paramsSol)
	return r and r.Position.Y or defaut
end

local CENTRE = Vector3.new(0, hauteurSol(0, 0, 0), 0) -- centre de la cour, au niveau du sol
local RAYON_COUR = 46 -- un joueur à moins de cette distance (et au sol) est « dans l'arène »
local RAYON_OGRE_MAX = 39 -- l'Ogre ne sort pas de la cour
local DELAI_REAPPARITION = 45

--------------------------------------------------------------------------------
-- Communication
--------------------------------------------------------------------------------

local remotes = Partage:FindFirstChild("Reseau")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Reseau"
	remotes.Parent = Partage
end
local function remote(nom: string): RemoteEvent
	local r = remotes:FindFirstChild(nom)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = nom
		r.Parent = remotes
	end
	return r :: RemoteEvent
end
local evAction = remote("Action") -- client → serveur : "legere" | "lourde" | "roulade" | "fiole"
local evEtat = remote("Etat") -- serveur → client : barres de vie / endurance / boss
local evMessage = remote("Message") -- serveur → client : textes (victoire, phase 2…)

local effets = dossier:FindFirstChild("EffetsCombat") or Instance.new("Folder")
effets.Name = "EffetsCombat"
effets.Parent = dossier

--------------------------------------------------------------------------------
-- Joueurs
--------------------------------------------------------------------------------

local etats: { [Player]: Regles.EtatJoueur } = {}
local jeuxMemoire: { [Player]: { [any]: any } } = {} -- si le Noyau est absent
local contributions: { [Player]: number } = {}

local function donneesJeu(joueur: Player)
	local jeu = API and API.donneesJeu(joueur)
	if jeu then
		return jeu
	end
	jeuxMemoire[joueur] = jeuxMemoire[joueur] or {}
	return jeuxMemoire[joueur]
end

local function racine(joueur: Player): BasePart?
	local perso = joueur.Character
	return perso and perso:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoide(joueur: Player): Humanoid?
	local perso = joueur.Character
	return perso and perso:FindFirstChildOfClass("Humanoid")
end

local function appliquerVie(joueur: Player)
	local h, e = humanoide(joueur), etats[joueur]
	if h and e and h.Health > 0 then
		h.Health = e.vie
	end
end

-- Épée de chevalier (en attendant les vrais modèles d'armes), soudée à la main droite.
local function donnerEpee(perso: Model)
	local main = perso:WaitForChild("RightHand", 3) or perso:FindFirstChild("Right Arm")
	if not (main and main:IsA("BasePart")) then
		return
	end
	local r6 = main.Name == "Right Arm"
	local epee = Instance.new("Model")
	epee.Name = "EpeeChevalier"
	local function piece(nom, taille, decalageY, couleur, matiere, forme)
		local p = Instance.new("Part")
		p.Name = nom
		p.Size = taille
		p.Color = couleur
		p.Material = matiere
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		if forme then
			p.Shape = forme
		end
		p:SetAttribute("Y", decalageY)
		p.Parent = epee
		return p
	end
	local poignee = piece("Poignee", Vector3.new(0.28, 1.2, 0.28), 0, Color3.fromRGB(52, 36, 28), Enum.Material.Wood)
	piece("Pommeau", Vector3.new(0.45, 0.45, 0.45), -0.7, Color3.fromRGB(120, 112, 100), Enum.Material.Metal, Enum.PartType.Ball)
	piece("Garde", Vector3.new(1.5, 0.22, 0.32), 0.7, Color3.fromRGB(110, 104, 95), Enum.Material.Metal)
	piece("Lame", Vector3.new(0.32, 4.2, 0.08), 2.9, Color3.fromRGB(170, 175, 182), Enum.Material.Metal)
	-- La lame part vers l'avant de la main (axe -Z de la main).
	local prise = main.CFrame * CFrame.new(0, r6 and -1 or -0.3, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	for _, p in epee:GetChildren() do
		p.CFrame = prise * CFrame.new(0, p:GetAttribute("Y"), 0)
		if p ~= poignee then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = poignee, p
			w.Parent = p
		end
	end
	local soudure = Instance.new("Weld")
	soudure.Part0, soudure.Part1 = main, poignee
	soudure.C0 = main.CFrame:Inverse() * prise
	soudure.Parent = poignee
	epee.Parent = perso
end

local function personnageArrive(joueur: Player, perso: Model)
	etats[joueur] = Regles.nouvelEtatJoueur(os.clock())
	task.spawn(donnerEpee, perso)
	local h = perso:WaitForChild("Humanoid", 10) :: Humanoid?
	if h then
		h.MaxHealth = Regles.JOUEUR.vieMax
		h.Health = Regles.JOUEUR.vieMax
	end
	-- Pas de régénération automatique : on se soigne avec les fioles.
	local regen = perso:WaitForChild("Health", 3)
	if regen then
		regen:Destroy()
	end
end

local function joueurArrive(joueur: Player)
	joueur.CharacterAdded:Connect(function(perso)
		personnageArrive(joueur, perso)
	end)
	if joueur.Character then
		task.spawn(personnageArrive, joueur, joueur.Character)
	end
end
Players.PlayerAdded:Connect(joueurArrive)
for _, j in Players:GetPlayers() do
	joueurArrive(j)
end
Players.PlayerRemoving:Connect(function(j)
	etats[j] = nil
	jeuxMemoire[j] = nil
	contributions[j] = nil
end)

local function blesser(joueur: Player, montant: number)
	local e = etats[joueur]
	if not e then
		return
	end
	local subi = Regles.subirDegats(e, montant, os.clock())
	if subi > 0 then
		local h = humanoide(joueur)
		if h then
			h.Health = e.vie
		end
	end
end

local function dansArene(joueur: Player): boolean
	local r, e = racine(joueur), etats[joueur]
	if not (r and e and e.vie > 0) then
		return false
	end
	local p = r.Position
	return (Vector3.new(p.X, 0, p.Z) - CENTRE).Magnitude <= RAYON_COUR and p.Y < CENTRE.Y + 25
end

--------------------------------------------------------------------------------
-- L'Ogre : position, orientation, télégraphes
--------------------------------------------------------------------------------

local pivotDepart = ogre:GetPivot()
-- Au départ, le modèle regarde le portail (+Z) : on tourne autour de l'axe vertical
-- de l'écart entre la direction voulue et +Z, en gardant sa rotation d'origine.
local function lacet(v: Vector3): number
	return math.atan2(-v.X, -v.Z)
end
-- Poser les pieds de l'Ogre sur le sol (le modèle était enfoncé de ~1,8 stud).
do
	local boite, taille = ogre:GetBoundingBox()
	local pieds = boite.Position.Y - taille.Y / 2
	local sol = hauteurSol(boite.Position.X, boite.Position.Z, pieds)
	pivotDepart = pivotDepart + Vector3.new(0, sol - pieds, 0)
end
local position = pivotDepart.Position
local direction = Vector3.new(0, 0, 1)
-- Pose du corps (animation procédurale : le modèle est d'un seul bloc) :
-- lacet = torsion, hauteur = saut / écrasement, inclinaison = avant / arrière.
local pose = { lacet = 0, hauteur = 0, inclinaison = 0 }
local coupDepuis = -math.huge -- instant du dernier coup (claquement rapide)
local attaqueEnCours: string? = nil
local enfoncement = 0 -- descente dans le sol à la mort

local function placerOgre()
	ogre:PivotTo(
		CFrame.new(position + Vector3.new(0, pose.hauteur - enfoncement, 0))
			* CFrame.Angles(0, lacet(direction) - lacet(Vector3.new(0, 0, 1)) + pose.lacet, 0)
			* CFrame.Angles(pose.inclinaison, 0, 0)
			* pivotDepart.Rotation
	)
end

local function telegraphe(forme: string, cf: CFrame, taille: Vector3, duree: number)
	local p = Instance.new("Part")
	p.Name = "Telegraphe"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(220, 40, 25)
	p.Transparency = 0.6
	if forme == "disque" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.2, taille.X * 2, taille.X * 2)
		p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	else
		p.Size = taille
		p.CFrame = cf
	end
	p.Parent = effets
	TweenService:Create(p, TweenInfo.new(duree, Enum.EasingStyle.Linear), { Transparency = 0.2 }):Play()
	task.delay(duree + 0.15, function()
		p:Destroy()
	end)
end

local function secousse(centre: Vector3, rayon: number)
	-- Gerbe de neige/poussière à l'impact.
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(rayon * 2, 1, rayon * 2)
	p.Position = centre + Vector3.new(0, 1, 0)
	p.Parent = effets
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(220, 228, 240))
	e.Size = NumberSequence.new(4, 9)
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = 0
	e.Parent = p
	e:Emit(math.clamp(math.floor(rayon * 2), 10, 60))
	task.delay(2, function()
		p:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Combat
--------------------------------------------------------------------------------

local ia = IA.nouveau(Random.new())
local cible: Player? = nil
local attaqueVisee: Vector3? = nil -- point visé (charge / rocher), fixé à la préparation
local charge: { direction: Vector3, restant: number, touches: { [Player]: boolean } }? = nil
local mortA: number? = nil

local function choisirCible(): Player?
	local meilleure, dMin = nil, math.huge
	for _, j in Players:GetPlayers() do
		if dansArene(j) then
			local d = ((racine(j) :: BasePart).Position - position).Magnitude
			if d < dMin then
				meilleure, dMin = j, d
			end
		end
	end
	return meilleure
end

local function distanceSol(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function preparer(nom: string, duree: number)
	local A = Regles.OGRE.attaques
	local sol = Vector3.new(position.X, hauteurSol(position.X, position.Z, CENTRE.Y) + 0.25, position.Z)
	local c = cible and racine(cible)
	if c then
		local v = Vector3.new(c.Position.X - position.X, 0, c.Position.Z - position.Z)
		-- Seule la charge se verrouille droit sur la cible ; le reste garde
		-- l'orientation (il se tourne lentement en marchant).
		if nom == "charge" and v.Magnitude > 0.1 then
			direction = v.Unit
		end
		attaqueVisee = Vector3.new(c.Position.X, hauteurSol(c.Position.X, c.Position.Z, CENTRE.Y), c.Position.Z)
	end
	if nom == "balayage" then
		local a = A.balayage
		telegraphe(
			"boite",
			CFrame.lookAt(sol, sol + direction) * CFrame.new(0, 0, -a.portee / 2),
			Vector3.new(a.portee * 1.6, 0.2, a.portee),
			duree
		)
	elseif nom == "onde" then
		telegraphe("disque", CFrame.new(sol), Vector3.new(A.onde.rayon, 0, 0), duree)
	elseif nom == "charge" then
		local a = A.charge
		local longueur = math.min(a.porteeMax, ((attaqueVisee or sol) - sol).Magnitude + 15)
		telegraphe(
			"boite",
			CFrame.lookAt(sol, sol + direction) * CFrame.new(0, 0, -longueur / 2),
			Vector3.new(a.largeur, 0.2, longueur),
			duree
		)
	elseif nom == "rocher" and attaqueVisee then
		telegraphe("disque", CFrame.new(attaqueVisee + Vector3.new(0, 0.25, 0)), Vector3.new(A.rocher.rayon, 0, 0), duree)
	end
end

local function frapper(nom: string)
	local A = Regles.OGRE.attaques
	coupDepuis = os.clock()
	if nom == "balayage" then
		local a = A.balayage
		for _, j in Players:GetPlayers() do
			local r = racine(j)
			if
				r
				and Regles.dansCone(
					position.X,
					position.Z,
					direction.X,
					direction.Z,
					r.Position.X,
					r.Position.Z,
					a.portee,
					a.angle
				)
			then
				blesser(j, a.degats)
			end
		end
		secousse(position + direction * (a.portee / 2), a.portee / 2)
	elseif nom == "onde" then
		local a = A.onde
		for _, j in Players:GetPlayers() do
			local r = racine(j)
			-- L'onde court au sol : sauter au bon moment l'évite aussi.
			if r and distanceSol(r.Position, position) <= a.rayon and r.Position.Y < CENTRE.Y + 7 then
				blesser(j, a.degats)
			end
		end
		secousse(position, a.rayon)
	elseif nom == "charge" then
		local a = A.charge
		local longueur = attaqueVisee and math.min(a.porteeMax, distanceSol(attaqueVisee, position) + 15) or a.porteeMax
		charge = { direction = direction, restant = longueur, touches = {} }
	elseif nom == "rocher" and attaqueVisee then
		local a = A.rocher
		local point = attaqueVisee
		local roc = Instance.new("Part")
		roc.Name = "Rocher"
		roc.Shape = Enum.PartType.Ball
		roc.Size = Vector3.new(7, 7, 7)
		roc.Material = Enum.Material.Slate
		roc.Color = Color3.fromRGB(90, 92, 98)
		roc.Anchored = true
		roc.CanCollide = false
		roc.Position = point + Vector3.new(0, 60, 0)
		roc.Parent = effets
		local chute = TweenService:Create(roc, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = point + Vector3.new(0, 3, 0),
		})
		chute:Play()
		chute.Completed:Once(function()
			for _, j in Players:GetPlayers() do
				local r = racine(j)
				if r and distanceSol(r.Position, point) <= a.rayon then
					blesser(j, a.degats)
				end
			end
			secousse(point, a.rayon)
			task.delay(4, function()
				roc:Destroy()
			end)
		end)
	end
end

local function victoire()
	mortA = os.clock()
	evMessage:FireAllClients("victoire", Regles.OGRE.nom)
	for j, degats in contributions do
		if degats > 0 and j.Parent then
			local r = Regles.recompenserBoss(donneesJeu(j), Regles.OGRE.id, os.time())
			evMessage:FireClient(j, "recompense", r)
		end
	end
	table.clear(contributions)
end

local function reapparaitre()
	IA.reinitialiser(ia)
	position = pivotDepart.Position
	direction = Vector3.new(0, 0, 1)
	enfoncement = 0
	pose.lacet, pose.hauteur, pose.inclinaison = 0, 0, 0
	attaqueEnCours = nil
	charge, mortA, cible = nil, nil, nil
	placerOgre()
end

-- Attaques du joueur
evAction.OnServerEvent:Connect(function(joueur: Player, action: any)
	local e = etats[joueur]
	if type(action) ~= "string" or not e then
		return
	end
	local t = os.clock()
	local ok = Regles.peutAgir(e, action, t)
	if not ok then
		return
	end
	local fiche = Regles.agir(e, action, t)
	if action == "fiole" then
		task.delay(0.4, appliquerVie, joueur)
		return
	end
	if action == "roulade" then
		return -- déplacement fait par le client ; le serveur accorde l'invulnérabilité
	end
	task.delay(fiche.impact, function()
		local r = racine(joueur)
		if not r or ia.etat == "mort" or ia.etat == "attente" or e.vie <= 0 then
			return
		end
		local look = r.CFrame.LookVector
		if
			Regles.dansCone(
				r.Position.X,
				r.Position.Z,
				look.X,
				look.Z,
				position.X,
				position.Z,
				fiche.portee,
				fiche.angle,
				Regles.OGRE.rayonCorps
			)
		then
			local pris = IA.subirDegats(ia, Regles.degatsAttaque(action, donneesJeu(joueur)))
			contributions[joueur] = (contributions[joueur] or 0) + pris
		end
	end)
end)

-- Pose visée selon l'attaque : préparation (lente, lisible) puis coup (claquement).
local POSES = {
	balayage = { prep = { lacet = -0.8, hauteur = 0, inclinaison = -0.06 }, coup = { lacet = 1.0, hauteur = 0, inclinaison = 0.08 } },
	onde = { prep = { lacet = 0, hauteur = 6, inclinaison = -0.22 }, coup = { lacet = 0, hauteur = -1.2, inclinaison = 0.18 } },
	charge = { prep = { lacet = 0, hauteur = -1, inclinaison = 0.12 }, coup = { lacet = 0, hauteur = 0, inclinaison = 0.3 } },
	rocher = { prep = { lacet = -0.4, hauteur = 0, inclinaison = -0.35 }, coup = { lacet = 0.3, hauteur = 0, inclinaison = 0.28 } },
}
local REPOS = { lacet = 0, hauteur = 0, inclinaison = 0 }

local function animer(dt: number, t: number)
	local cibleP, vitesse = REPOS, 3
	local p = attaqueEnCours and POSES[attaqueEnCours]
	if ia.etat == "rage" then
		-- Rugissement : se dresse et tremble.
		cibleP = { lacet = math.sin(t * 40) * 0.04, hauteur = 2, inclinaison = -0.25 }
		vitesse = 8
	elseif p and ia.etat == "preparation" then
		cibleP, vitesse = p.prep, 2.5
	elseif p and (charge or t - coupDepuis < 0.3) then
		cibleP, vitesse = p.coup, 22
	elseif ia.etat == "poursuite" then
		-- Marche lourde : balancement.
		cibleP = { lacet = math.sin(t * 3) * 0.06, hauteur = math.abs(math.sin(t * 3)) * 0.8, inclinaison = 0.04 }
		vitesse = 6
	end
	local k = math.min(1, dt * vitesse)
	for cle, v in cibleP do
		pose[cle] += (v - pose[cle]) * k
	end
end

-- Tourne progressivement `direction` vers `voulu` (vitesse limitée).
local function tourner(voulu: Vector3, dt: number)
	local O = Regles.OGRE
	local maxi = (ia.phase == 2 and O.rotationPhase2 or O.rotation) * dt
	local ecart = lacet(voulu) - lacet(direction)
	ecart = (ecart + math.pi) % (2 * math.pi) - math.pi
	local a = lacet(direction) + math.clamp(ecart, -maxi, maxi)
	direction = Vector3.new(-math.sin(a), 0, -math.cos(a))
	return math.abs(ecart) <= maxi
end

-- Boucle principale
local dernierEnvoi = 0
RunService.Heartbeat:Connect(function(dt)
	local t = os.clock()

	if mortA then
		enfoncement = math.min(40, enfoncement + dt * 6)
		placerOgre()
		if t - mortA >= DELAI_REAPPARITION then
			reapparaitre()
		end
	else
		if not (cible and dansArene(cible)) then
			cible = choisirCible()
		end
		local c = cible and racine(cible)
		local distance = c and math.max(0, distanceSol(c.Position, position) - Regles.OGRE.rayonCorps * 0.5) or nil

		if charge then
			local pas = math.min(charge.restant, Regles.OGRE.attaques.charge.vitesse * dt)
			local depart = position
			local suivant = position + charge.direction * pas
			if (Vector3.new(suivant.X, 0, suivant.Z) - CENTRE).Magnitude > RAYON_OGRE_MAX then
				pas = 0 -- contre la palissade : la charge s'arrête
				charge.restant = 0
			else
				position = suivant
				charge.restant -= pas
			end
			local a = Regles.OGRE.attaques.charge
			for _, j in Players:GetPlayers() do
				local r = racine(j)
				if
					r
					and not charge.touches[j]
					and Regles.distanceSegment(r.Position.X, r.Position.Z, depart.X, depart.Z, position.X, position.Z)
						<= a.largeur / 2 + 2
				then
					charge.touches[j] = true
					blesser(j, a.degats)
				end
			end
			if charge.restant <= 0 then
				charge = nil
				secousse(position, 10)
			end
		end

		-- Se tourner vers la cible (vitesse limitée) hors préparation et charge.
		local deFace = true
		if c and not charge and ia.etat ~= "preparation" and ia.etat ~= "attente" then
			local v = Vector3.new(c.Position.X - position.X, 0, c.Position.Z - position.Z)
			if v.Magnitude > 0.1 then
				local vitesseTour = ia.etat == "recuperation" and 0.35 or 1 -- lent à se retourner après un coup
				deFace = tourner(v.Unit, dt * vitesseTour) or direction:Dot(v.Unit) > math.cos(math.rad(30))
			end
		end

		for _, ordre in IA.mettreAJour(ia, t, distance, deFace) do
			if ordre.type == "avancer" and c and not charge then
				local v = Vector3.new(c.Position.X - position.X, 0, c.Position.Z - position.Z)
				if v.Magnitude > Regles.OGRE.attaques.balayage.portee * 0.5 then
					local suivant = position + direction * ordre.vitesse * dt
					if (Vector3.new(suivant.X, 0, suivant.Z) - CENTRE).Magnitude <= RAYON_OGRE_MAX then
						position = suivant
					end
				end
			elseif ordre.type == "preparer" then
				attaqueEnCours = ordre.attaque
				preparer(ordre.attaque, ordre.duree)
			elseif ordre.type == "frapper" then
				frapper(ordre.attaque)
			elseif ordre.type == "rage" then
				evMessage:FireAllClients("rage", Regles.OGRE.nom)
				secousse(position, 30)
			elseif ordre.type == "mort" then
				victoire()
			end
		end

		-- Sans cible : il rentre lentement à sa place, avec ses blessures.
		if ia.etat == "attente" and not charge then
			local v = Vector3.new(pivotDepart.Position.X - position.X, 0, pivotDepart.Position.Z - position.Z)
			if v.Magnitude > 1 then
				tourner(v.Unit, dt)
				position += direction * math.min(v.Magnitude, Regles.OGRE.vitesse * dt)
			else
				tourner(Vector3.new(0, 0, 1), dt)
			end
		end

		animer(dt, t)
		placerOgre()
	end

	-- Envoi de l'état aux clients (10 fois par seconde).
	if t - dernierEnvoi >= 0.1 then
		dernierEnvoi = t
		local actif = ia.etat ~= "attente" and ia.etat ~= "mort"
		for _, j in Players:GetPlayers() do
			local e = etats[j]
			if e then
				evEtat:FireClient(j, {
					vie = e.vie,
					endurance = Regles.endurance(e, t),
					fioles = e.fioles,
					boss = actif and { nom = Regles.OGRE.nom, vie = ia.vie, vieMax = Regles.OGRE.vieMax, phase = ia.phase }
						or nil,
				})
			end
		end
	end
end)

print("[Combat] Grimmulf est prêt")
