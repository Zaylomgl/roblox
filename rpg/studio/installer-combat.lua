-- Installateur du combat de Givrecendre (GÉNÉRÉ par rpg/outils/construire-installateur.luau : ne pas modifier).
-- À exécuter dans Roblox Studio, mode Édition (barre de commandes, ou execute_luau du MCP).
-- Installe : règles + IA de l'Ogre, script de combat serveur, interface client, noyau (sauvegarde).
local function installer(service, dossiers, nom, classe, source)
	local parent = game:GetService(service)
	for _, d in ipairs(dossiers) do
		local f = parent:FindFirstChild(d)
		if not f then f = Instance.new("Folder"); f.Name = d; f.Parent = parent end
		parent = f
	end
	local ancien = parent:FindFirstChild(nom)
	if ancien then ancien:Destroy() end
	local s = Instance.new(classe)
	s.Name = nom
	s.Source = source
	s.Parent = parent
end
-- rpg/src/ReplicatedStorage/Givrecendre/Regles.luau
installer("ReplicatedStorage", {"Givrecendre"}, "Regles", "ModuleScript", [=[
--[[
	Règles du combat de Givrecendre : chiffres d'équilibrage et calculs.

	Module PUR (aucune dépendance à Roblox) : testé hors ligne par
	pipeline/tests/givrecendre-regles.test.luau. Le serveur s'en sert pour
	tout calculer (anti-triche) ; le client seulement pour l'affichage.

	Les positions sont passées en nombres (x, z) : le combat se joue au sol.
]]

local Regles = {}

Regles.JOUEUR = {
	vieMax = 100,
	enduranceMax = 100,
	regenEndurance = 30, -- par seconde
	delaiRegen = 0.8, -- secondes sans action avant que l'endurance remonte
	attaques = {
		legere = { cout = 15, degats = 14, portee = 11, angle = 80, impact = 0.2, recuperation = 0.5 },
		lourde = { cout = 35, degats = 34, portee = 13, angle = 100, impact = 0.55, recuperation = 1.05 },
	},
	roulade = { cout = 25, duree = 0.45, invulnerabilite = 0.35, vitesse = 42, recuperation = 0.6 },
	fiole = { nombre = 3, soin = 45, duree = 1.1 },
}

Regles.OGRE = {
	id = "ogre",
	nom = "Grimmulf, l'Ogre du Col",
	vieMax = 1600,
	rayonCorps = 9, -- studs : les coups du joueur touchent jusqu'à portée + rayonCorps
	seuilPhase2 = 0.5,
	vitesse = 8,
	vitessePhase2 = 10.5,
	rotation = 1.6, -- radians par seconde (il ne se retourne pas instantanément)
	rotationPhase2 = 2.1,
	rage = 2.2, -- secondes de rugissement au passage en phase 2 (pas d'attaque)
	accelerationPhase2 = 0.85, -- préparations raccourcies en phase 2
	attaques = {
		balayage = { portee = 22, angle = 150, degats = 20, preparation = 1.25, recuperation = 1.5 },
		onde = { portee = 18, rayon = 24, degats = 24, preparation = 1.7, recuperation = 2.0 },
		charge = {
			porteeMin = 26,
			porteeMax = 80,
			largeur = 12,
			vitesse = 46,
			degats = 28,
			preparation = 1.4,
			recuperation = 2.2,
		},
		rocher = { porteeMin = 30, porteeMax = 90, rayon = 9, degats = 22, preparation = 1.5, recuperation = 1.6 },
	},
}

-- Récompenses d'un boss (voir rpg/CONCEPTION.md, section 3).
Regles.RECOMPENSE_BOSS = {
	xp = 500,
	xpRepetition = 100, -- un boss déjà vaincu ne redonne que de l'XP
	bonusDegats = 0.10, -- +10 % permanent et cumulable
	pointsCompetence = 3,
	dureeBoostXp = 3600, -- secondes
	multiplicateurBoostXp = 2,
}

--------------------------------------------------------------------------------
-- Géométrie au sol
--------------------------------------------------------------------------------

-- La cible (cx, cz) est-elle dans le cône partant de (ox, oz), orienté (dx, dz) ?
-- `rayonCible` élargit la portée (corps volumineux).
function Regles.dansCone(
	ox: number,
	oz: number,
	dx: number,
	dz: number,
	cx: number,
	cz: number,
	portee: number,
	angleDeg: number,
	rayonCible: number?
): boolean
	local vx, vz = cx - ox, cz - oz
	local dist = math.sqrt(vx * vx + vz * vz)
	local r = rayonCible or 0
	if dist > portee + r then
		return false
	end
	if dist <= r then
		return true -- collé à la cible : touché quel que soit l'angle
	end
	local nd = math.sqrt(dx * dx + dz * dz)
	if nd == 0 then
		return false
	end
	local cos = (vx * dx + vz * dz) / (dist * nd)
	-- Tolérance angulaire due à la taille de la cible.
	local demiAngle = math.rad(angleDeg / 2) + math.asin(math.min(1, r / dist))
	return cos >= math.cos(math.min(math.pi, demiAngle))
end

-- Distance du point (px, pz) au segment [(ax, az), (bx, bz)].
function Regles.distanceSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local abx, abz = bx - ax, bz - az
	local l2 = abx * abx + abz * abz
	local t = 0
	if l2 > 0 then
		t = math.clamp(((px - ax) * abx + (pz - az) * abz) / l2, 0, 1)
	end
	local qx, qz = ax + abx * t - px, az + abz * t - pz
	return math.sqrt(qx * qx + qz * qz)
end

--------------------------------------------------------------------------------
-- Joueur : endurance, actions, invulnérabilité, dégâts
--------------------------------------------------------------------------------

export type EtatJoueur = {
	vie: number,
	endurance: number, -- valeur au moment `tEndurance`
	tEndurance: number,
	derniereAction: number,
	occupeJusqua: number,
	invulnerableJusqua: number,
	fioles: number,
}

function Regles.nouvelEtatJoueur(t: number): EtatJoueur
	local J = Regles.JOUEUR
	return {
		vie = J.vieMax,
		endurance = J.enduranceMax,
		tEndurance = t,
		derniereAction = -math.huge,
		occupeJusqua = -math.huge,
		invulnerableJusqua = -math.huge,
		fioles = J.fiole.nombre,
	}
end

-- Endurance à l'instant t (la régénération est calculée à la demande).
function Regles.endurance(etat: EtatJoueur, t: number): number
	local J = Regles.JOUEUR
	local debutRegen = math.max(etat.tEndurance, etat.derniereAction + J.delaiRegen)
	local gagne = math.max(0, t - debutRegen) * J.regenEndurance
	return math.min(J.enduranceMax, etat.endurance + gagne)
end

local function coutDe(action: string): number
	local J = Regles.JOUEUR
	if J.attaques[action] then
		return J.attaques[action].cout
	elseif action == "roulade" then
		return J.roulade.cout
	end
	return 0
end

-- Peut-on faire cette action maintenant ? Renvoie (ok, raison).
function Regles.peutAgir(etat: EtatJoueur, action: string, t: number): (boolean, string?)
	local J = Regles.JOUEUR
	if etat.vie <= 0 then
		return false, "mort"
	end
	if not (J.attaques[action] or action == "roulade" or action == "fiole") then
		return false, "inconnue"
	end
	if t < etat.occupeJusqua then
		return false, "occupe"
	end
	if action == "fiole" then
		if etat.fioles <= 0 then
			return false, "plus de fiole"
		end
		return true, nil
	end
	-- Comme dans le genre : on peut agir dès qu'il reste un peu d'endurance (> 0).
	if Regles.endurance(etat, t) <= 0 then
		return false, "endurance"
	end
	return true, nil
end

-- Applique l'action (à appeler seulement si peutAgir). Renvoie la fiche de l'action.
function Regles.agir(etat: EtatJoueur, action: string, t: number)
	local J = Regles.JOUEUR
	local e = Regles.endurance(etat, t)
	etat.endurance = math.max(0, e - coutDe(action))
	etat.tEndurance = t
	if action == "fiole" then
		etat.fioles -= 1
		etat.vie = math.min(J.vieMax, etat.vie + J.fiole.soin)
		etat.occupeJusqua = t + J.fiole.duree
		return J.fiole
	end
	etat.derniereAction = t
	if action == "roulade" then
		etat.occupeJusqua = t + J.roulade.recuperation
		etat.invulnerableJusqua = t + J.roulade.invulnerabilite
		return J.roulade
	end
	local a = J.attaques[action]
	etat.occupeJusqua = t + a.recuperation
	return a
end

function Regles.estInvulnerable(etat: EtatJoueur, t: number): boolean
	return t < etat.invulnerableJusqua
end

-- Inflige des dégâts au joueur. Renvoie les dégâts réellement subis (0 si esquivé).
function Regles.subirDegats(etat: EtatJoueur, montant: number, t: number): number
	if etat.vie <= 0 or Regles.estInvulnerable(etat, t) then
		return 0
	end
	local reel = math.min(etat.vie, math.max(0, montant))
	etat.vie -= reel
	return reel
end

-- Multiplicateur de dégâts du joueur : +10 % par boss vaincu (cumulable).
function Regles.multiplicateurDegats(jeu: { [any]: any }?): number
	local n = 0
	if jeu and type(jeu.bossVaincus) == "table" then
		for _, vaincu in jeu.bossVaincus do
			if vaincu then
				n += 1
			end
		end
	end
	return 1 + Regles.RECOMPENSE_BOSS.bonusDegats * n
end

function Regles.degatsAttaque(action: string, jeu: { [any]: any }?): number
	local a = Regles.JOUEUR.attaques[action]
	assert(a, "attaque inconnue : " .. tostring(action))
	return math.floor(a.degats * Regles.multiplicateurDegats(jeu) + 0.5)
end

--------------------------------------------------------------------------------
-- Récompenses de boss (table `jeu` du profil sauvegardé)
--------------------------------------------------------------------------------

-- Crédite la victoire. Renvoie un résumé : { premiereFois, xp, points }.
function Regles.recompenserBoss(jeu: { [any]: any }, bossId: string, t: number)
	local R = Regles.RECOMPENSE_BOSS
	jeu.bossVaincus = jeu.bossVaincus or {}
	jeu.xp = jeu.xp or 0
	jeu.pointsCompetence = jeu.pointsCompetence or 0
	jeu.boostXpFin = jeu.boostXpFin or 0
	local premiereFois = not jeu.bossVaincus[bossId]
	local xp = premiereFois and R.xp or R.xpRepetition
	jeu.xp += xp
	local points = 0
	if premiereFois then
		jeu.bossVaincus[bossId] = true
		points = R.pointsCompetence
		jeu.pointsCompetence += points
		jeu.boostXpFin = math.max(jeu.boostXpFin, t) + R.dureeBoostXp
	end
	return { premiereFois = premiereFois, xp = xp, points = points }
end

-- Multiplicateur d'XP en cours (boost d'1 h après un boss).
function Regles.multiplicateurXp(jeu: { [any]: any }?, t: number): number
	if jeu and type(jeu.boostXpFin) == "number" and t < jeu.boostXpFin then
		return Regles.RECOMPENSE_BOSS.multiplicateurBoostXp
	end
	return 1
end

return Regles
]=])
-- rpg/src/ReplicatedStorage/Givrecendre/IAOgre.luau
installer("ReplicatedStorage", {"Givrecendre"}, "IAOgre", "ModuleScript", [=[
--[[
	Cerveau de l'Ogre : machine à états PURE (aucune dépendance à Roblox),
	testée hors ligne par pipeline/tests/givrecendre-ia.test.luau.

	Le serveur appelle IA.mettreAJour(ia, t, distanceCible) à chaque image et
	exécute les ordres renvoyés :
		{ type = "avancer", vitesse }          se rapprocher de la cible
		{ type = "preparer", attaque, duree }  début d'une attaque (télégraphe)
		{ type = "frapper", attaque }          l'attaque part : appliquer les dégâts
		{ type = "rage", duree }               passage en phase 2 (rugissement)
		{ type = "mort" }                      une seule fois
	États : attente, poursuite, preparation, recuperation, rage, mort.
]]

local Regles = require(script and script.Parent and script.Parent:FindFirstChild("Regles") or "./Regles")

local IA = {}

export type IA = {
	etat: string,
	finEtat: number,
	attaque: string?,
	vie: number,
	phase: number,
	rng: Random | any,
	derniere: string?, -- dernière attaque (évite de répéter la même trois fois)
	repetitions: number,
}

function IA.nouveau(rng: any): IA
	return {
		etat = "attente",
		finEtat = 0,
		attaque = nil,
		vie = Regles.OGRE.vieMax,
		phase = 1,
		rng = rng,
		derniere = nil,
		repetitions = 0,
	}
end

function IA.reinitialiser(ia: IA)
	ia.etat = "attente"
	ia.attaque = nil
	ia.vie = Regles.OGRE.vieMax
	ia.phase = 1
	ia.derniere = nil
	ia.repetitions = 0
end

local function aleatoire(ia: IA): number
	return ia.rng:NextNumber()
end

-- Attaques possibles à cette distance, avec leur poids.
function IA.candidates(ia: IA, distance: number): { { nom: string, poids: number } }
	local A = Regles.OGRE.attaques
	local liste = {}
	if distance <= A.balayage.portee then
		table.insert(liste, { nom = "balayage", poids = 3 })
	end
	if distance <= A.onde.portee then
		table.insert(liste, { nom = "onde", poids = ia.phase == 2 and 3 or 2 })
	end
	if distance >= A.charge.porteeMin and distance <= A.charge.porteeMax then
		table.insert(liste, { nom = "charge", poids = 2 })
	end
	if ia.phase == 2 and distance >= A.rocher.porteeMin and distance <= A.rocher.porteeMax then
		table.insert(liste, { nom = "rocher", poids = 2 })
	end
	-- Pas trois fois de suite la même attaque.
	if ia.repetitions >= 2 and #liste > 1 then
		for i = #liste, 1, -1 do
			if liste[i].nom == ia.derniere then
				table.remove(liste, i)
			end
		end
	end
	return liste
end

function IA.choisir(ia: IA, distance: number): string?
	local liste = IA.candidates(ia, distance)
	local total = 0
	for _, c in liste do
		total += c.poids
	end
	if total == 0 then
		return nil
	end
	local tirage = aleatoire(ia) * total
	for _, c in liste do
		tirage -= c.poids
		if tirage < 0 then
			return c.nom
		end
	end
	return liste[#liste].nom
end

local function duree(ia: IA, base: number): number
	return ia.phase == 2 and base * Regles.OGRE.accelerationPhase2 or base
end

-- Le boss subit des dégâts. Renvoie les dégâts réellement pris.
function IA.subirDegats(ia: IA, montant: number): number
	if ia.etat == "mort" or ia.etat == "attente" then
		return 0
	end
	local reel = math.min(ia.vie, math.max(0, montant))
	ia.vie -= reel
	return reel
end

-- Un pas de simulation. `distance` = nil si aucune cible (personne dans l'arène).
-- `deFace` = false si l'Ogre ne regarde pas encore sa cible : il se tourne d'abord
-- (sauf pour l'onde de choc et la charge, qui n'en ont pas besoin).
function IA.mettreAJour(ia: IA, t: number, distance: number?, deFace: boolean?): { any }
	local ordres = {}
	local O = Regles.OGRE

	if ia.etat == "mort" then
		return ordres
	end
	if ia.vie <= 0 then
		ia.etat = "mort"
		table.insert(ordres, { type = "mort" })
		return ordres
	end
	if distance == nil then
		if ia.etat ~= "attente" then
			-- Tout le monde est mort ou parti : il retourne à sa place SANS se
			-- soigner (choix du propriétaire, 01/11/2026). Sa phase est conservée.
			ia.etat = "attente"
			ia.attaque = nil
			table.insert(ordres, { type = "retour" })
		end
		return ordres
	end
	if ia.etat == "attente" then
		ia.etat = "poursuite"
	end

	-- Passage en phase 2 (une seule fois), seulement entre deux attaques.
	if ia.phase == 1 and ia.vie <= O.vieMax * O.seuilPhase2 and (ia.etat == "poursuite" or ia.etat == "recuperation") then
		ia.phase = 2
		ia.etat = "rage"
		ia.finEtat = t + O.rage
		table.insert(ordres, { type = "rage", duree = O.rage })
		return ordres
	end

	if ia.etat == "rage" or ia.etat == "recuperation" then
		if t >= ia.finEtat then
			ia.etat = "poursuite"
		else
			return ordres
		end
	end

	if ia.etat == "preparation" then
		if t >= ia.finEtat then
			local nom = ia.attaque :: string
			table.insert(ordres, { type = "frapper", attaque = nom })
			ia.etat = "recuperation"
			ia.finEtat = t + duree(ia, O.attaques[nom].recuperation)
		end
		return ordres
	end

	-- Poursuite : attaquer si possible, sinon avancer.
	local nom = IA.choisir(ia, distance)
	if (nom == "balayage" or nom == "rocher") and deFace == false then
		nom = nil -- se tourner d'abord
	end
	if nom then
		if nom == ia.derniere then
			ia.repetitions += 1
		else
			ia.repetitions = 1
		end
		ia.derniere = nom
		ia.attaque = nom
		ia.etat = "preparation"
		local d = duree(ia, O.attaques[nom].preparation)
		ia.finEtat = t + d
		table.insert(ordres, { type = "preparer", attaque = nom, duree = d })
	else
		table.insert(ordres, { type = "avancer", vitesse = ia.phase == 2 and O.vitessePhase2 or O.vitesse })
	end
	return ordres
end

return IA
]=])
-- rpg/src/ServerScriptService/Givrecendre/Combat.server.luau
installer("ServerScriptService", {"Givrecendre"}, "Combat", "Script", [=[
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

-- La massue est une pièce séparée du corps (vérifié dans la place le 01/11/2026) :
-- on la fait tourner autour de la poignée (extrémité basse de son axe le plus long).
local massue = ogre:FindFirstChild("Massue")
local massueRel: CFrame? = nil -- position de la massue dans le repère de l'Ogre
local repereMain: CFrame? = nil -- repère de la main : -Z = avant de l'Ogre, Y = haut
if massue and massue:IsA("Model") then
	local cf, taille = massue:GetBoundingBox()
	local axe = cf.UpVector * taille.Y / 2
	if taille.X > taille.Y and taille.X >= taille.Z then
		axe = cf.RightVector * taille.X / 2
	elseif taille.Z > taille.Y then
		axe = cf.LookVector * taille.Z / 2
	end
	if axe.Y > 0 then
		axe = -axe -- vers l'extrémité basse = la poignée
	end
	local poignee = cf.Position + axe - axe.Unit * 3
	massueRel = pivotDepart:Inverse() * massue:GetPivot()
	local mainLocale = pivotDepart:PointToObjectSpace(poignee)
	repereMain = CFrame.lookAt(
		mainLocale,
		mainLocale + pivotDepart:VectorToObjectSpace(Vector3.new(0, 0, 1)),
		pivotDepart:VectorToObjectSpace(Vector3.new(0, 1, 0))
	)
else
	massue = nil
end
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
local pose = { lacet = 0, hauteur = 0, inclinaison = 0, massueP = 0, massueY = 0 }
local coupDepuis = -math.huge -- instant du dernier coup (claquement rapide)
local attaqueEnCours: string? = nil
local enfoncement = 0 -- descente dans le sol à la mort

local function placerOgre()
	local corps = CFrame.new(position + Vector3.new(0, pose.hauteur - enfoncement, 0))
		* CFrame.Angles(0, lacet(direction) - lacet(Vector3.new(0, 0, 1)) + pose.lacet, 0)
		* CFrame.Angles(pose.inclinaison, 0, 0)
		* pivotDepart.Rotation
	ogre:PivotTo(corps)
	if massue and massueRel and repereMain then
		-- massueP > 0 : la tête part en arrière (armer) ; < 0 : vers l'avant (abattre).
		-- massueY : rotation horizontale (balayage).
		local rotation = repereMain
			* CFrame.Angles(0, pose.massueY, 0)
			* CFrame.Angles(pose.massueP, 0, 0)
			* repereMain:Inverse()
		massue:PivotTo(corps * rotation * massueRel)
	end
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
	for cle in pose do
		pose[cle] = 0
	end
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
local function P(lacet_, hauteur, inclinaison, massueP, massueY)
	return { lacet = lacet_, hauteur = hauteur, inclinaison = inclinaison, massueP = massueP, massueY = massueY }
end
-- prep : position armée (lente, lisible) ; coup : fin du geste (rapide).
local POSES = {
	-- Massue tendue sur le côté droit, puis balayée d'un coup vers la gauche.
	balayage = { prep = P(-0.5, 0, -0.04, -1.35, -1.4), coup = P(0.7, 0, 0.06, -1.35, 1.8) },
	-- Massue levée loin derrière la tête, puis écrasée au sol devant lui.
	onde = { prep = P(0, 1.2, -0.18, 1.3, 0), coup = P(0, -0.6, 0.2, -2.25, 0) },
	-- Massue pointée vers l'avant comme un bélier.
	charge = { prep = P(0, -0.6, 0.1, -0.6, 0.2), coup = P(0, 0, 0.25, -1.1, 0) },
	-- Bras armé en arrière, puis lancer vers l'avant.
	rocher = { prep = P(-0.35, 0, -0.3, 1.6, -0.3), coup = P(0.25, 0, 0.22, -0.7, 0.2) },
}
local REPOS = P(0, 0, 0, 0, 0)

local function animer(dt: number, t: number)
	local cibleP, vitesse = REPOS, 3
	local p = attaqueEnCours and POSES[attaqueEnCours]
	if ia.etat == "rage" then
		-- Rugissement : se dresse et tremble.
		cibleP = P(math.sin(t * 40) * 0.04, 1, -0.2, 0.9 + math.sin(t * 25) * 0.15, 0)
		vitesse = 8
	elseif p and ia.etat == "preparation" then
		cibleP, vitesse = p.prep, 2.5
	elseif p and (charge or t - coupDepuis < 0.3) then
		cibleP, vitesse = p.coup, 22
	elseif ia.etat == "poursuite" then
		-- Marche lourde : balancement.
		cibleP = P(math.sin(t * 3) * 0.06, math.abs(math.sin(t * 3)) * 0.6, 0.04, 0.25 + math.sin(t * 3) * 0.15, 0)
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
]=])
-- rpg/src/StarterPlayer/StarterPlayerScripts/Givrecendre/Combat.client.luau
installer("StarterPlayer", {"StarterPlayerScripts", "Givrecendre"}, "Combat", "LocalScript", [=[
--[[
	Combat de Givrecendre, côté client : commandes (PC, manette, mobile),
	animations du chevalier, roulade, barres de vie / endurance / boss, messages.

	Le serveur fait autorité ; ce script garde une copie locale des règles
	pour ne pas envoyer d'actions impossibles et réagir sans attendre.

	Commandes :
		Attaque légère : clic gauche · R1 · bouton « Coup »
		Attaque lourde : F · R2 · bouton « Lourd »
		Roulade        : Q · B · bouton « Roulade »
		Fiole de soin  : R · X · bouton « Fiole »
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Partage = ReplicatedStorage:WaitForChild("Givrecendre")
local Regles = require(Partage:WaitForChild("Regles"))
local Reseau = Partage:WaitForChild("Reseau")
local evAction = Reseau:WaitForChild("Action") :: RemoteEvent
local evEtat = Reseau:WaitForChild("Etat") :: RemoteEvent
local evMessage = Reseau:WaitForChild("Message") :: RemoteEvent

local joueur = Players.LocalPlayer
local local_ = Regles.nouvelEtatJoueur(os.clock())

--------------------------------------------------------------------------------
-- Interface : barres façon « métal patiné », traînée qui montre les dégâts subis
--------------------------------------------------------------------------------

local OR = Color3.fromRGB(176, 150, 98)
local POLICE = Font.fromEnum(Enum.Font.Merriweather)
POLICE.Weight = Enum.FontWeight.Bold

local gui = Instance.new("ScreenGui")
gui.Name = "GivrecendreCombat"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = joueur:WaitForChild("PlayerGui")

-- Taille adaptée à l'écran (téléphone → grand écran).
local echelle = Instance.new("UIScale")
echelle.Parent = gui
local function adapter()
	local camera = workspace.CurrentCamera
	local h = camera and camera.ViewportSize.Y or 720
	echelle.Scale = math.clamp(h / 900, 0.6, 1.4)
end
adapter()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(adapter)
end

local function coins(objet: GuiObject, rayon: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, rayon)
	c.Parent = objet
end

local function degrade(objet: GuiObject, haut: Color3, bas: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(haut, bas)
	g.Rotation = 90
	g.Parent = objet
end

-- Crée une barre ; renvoie une fonction de mise à jour (valeur, max).
local function creerBarre(parent: Instance, nom: string, taille: UDim2, position: UDim2, haut: Color3, bas: Color3)
	local cadre = Instance.new("Frame")
	cadre.Name = nom
	cadre.Size = taille
	cadre.Position = position
	cadre.BackgroundColor3 = Color3.fromRGB(12, 11, 13)
	cadre.BackgroundTransparency = 0.15
	cadre.BorderSizePixel = 0
	cadre.Parent = parent
	coins(cadre, 3)
	local contour = Instance.new("UIStroke")
	contour.Color = OR
	contour.Thickness = 1.5
	contour.Transparency = 0.25
	contour.Parent = cadre

	local trainee = Instance.new("Frame")
	trainee.Name = "Trainee"
	trainee.Size = UDim2.fromScale(1, 1)
	trainee.BackgroundColor3 = Color3.fromRGB(220, 190, 120)
	trainee.BorderSizePixel = 0
	trainee.Parent = cadre
	coins(trainee, 3)

	local plein = Instance.new("Frame")
	plein.Name = "Plein"
	plein.Size = UDim2.fromScale(1, 1)
	plein.BackgroundColor3 = Color3.new(1, 1, 1)
	plein.BorderSizePixel = 0
	plein.Parent = cadre
	coins(plein, 3)
	degrade(plein, haut, bas)

	-- Reflet en haut de la barre.
	local reflet = Instance.new("Frame")
	reflet.Size = UDim2.new(1, 0, 0.35, 0)
	reflet.BackgroundColor3 = Color3.new(1, 1, 1)
	reflet.BackgroundTransparency = 0.85
	reflet.BorderSizePixel = 0
	reflet.Parent = plein
	coins(reflet, 3)

	local texte = Instance.new("TextLabel")
	texte.Size = UDim2.fromScale(1, 1)
	texte.BackgroundTransparency = 1
	texte.FontFace = POLICE
	texte.TextScaled = true
	texte.TextColor3 = Color3.fromRGB(240, 232, 215)
	texte.TextStrokeTransparency = 0.3
	texte.ZIndex = 3
	texte.Parent = cadre
	local limite = Instance.new("UITextSizeConstraint")
	limite.MaxTextSize = 14
	limite.Parent = texte

	local precedent = 1
	return function(valeur: number, max: number, afficherNombre: boolean?)
		local f = math.clamp(valeur / max, 0, 1)
		plein.Size = UDim2.fromScale(f, 1)
		if f < precedent then
			-- La traînée dorée rattrape la barre après un court instant.
			TweenService:Create(
				trainee,
				TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.35),
				{ Size = UDim2.fromScale(f, 1) }
			):Play()
		else
			trainee.Size = UDim2.fromScale(f, 1)
		end
		precedent = f
		texte.Text = afficherNombre and ("%d / %d"):format(math.ceil(valeur), max) or ""
	end,
		cadre
end

-- Bloc du joueur, en haut à gauche.
local blocJoueur = Instance.new("Frame")
blocJoueur.Name = "Joueur"
blocJoueur.Position = UDim2.new(0, 28, 0, 28)
blocJoueur.Size = UDim2.new(0, 360, 0, 80)
blocJoueur.BackgroundTransparency = 1
blocJoueur.Parent = gui

local majVie = creerBarre(
	blocJoueur,
	"Vie",
	UDim2.new(0, 340, 0, 20),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(196, 44, 36),
	Color3.fromRGB(110, 16, 14)
)
local majEndurance = creerBarre(
	blocJoueur,
	"Endurance",
	UDim2.new(0, 260, 0, 12),
	UDim2.new(0, 0, 0, 27),
	Color3.fromRGB(120, 176, 92),
	Color3.fromRGB(52, 98, 40)
)

-- Fioles : petites pastilles.
local fioles = {}
for i = 1, Regles.JOUEUR.fiole.nombre do
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, 14, 0, 20)
	f.Position = UDim2.new(0, (i - 1) * 20, 0, 48)
	f.BackgroundColor3 = Color3.fromRGB(214, 120, 44)
	f.BorderSizePixel = 0
	f.Parent = blocJoueur
	coins(f, 5)
	local c = Instance.new("UIStroke")
	c.Color = OR
	c.Parent = f
	fioles[i] = f
end

-- Barre du boss, en bas au centre.
local blocBoss = Instance.new("Frame")
blocBoss.Name = "Boss"
blocBoss.AnchorPoint = Vector2.new(0.5, 1)
blocBoss.Position = UDim2.new(0.5, 0, 1, -48)
blocBoss.Size = UDim2.new(0, 640, 0, 46)
blocBoss.BackgroundTransparency = 1
blocBoss.Visible = false
blocBoss.Parent = gui

local nomBoss = Instance.new("TextLabel")
nomBoss.Size = UDim2.new(1, 0, 0, 24)
nomBoss.BackgroundTransparency = 1
nomBoss.FontFace = POLICE
nomBoss.TextSize = 22
nomBoss.TextXAlignment = Enum.TextXAlignment.Left
nomBoss.TextColor3 = Color3.fromRGB(236, 226, 204)
nomBoss.TextStrokeTransparency = 0.25
nomBoss.Parent = blocBoss

local majBoss = creerBarre(
	blocBoss,
	"Vie",
	UDim2.new(1, 0, 0, 16),
	UDim2.new(0, 0, 0, 28),
	Color3.fromRGB(170, 30, 24),
	Color3.fromRGB(86, 10, 8)
)

local function texteCentral(taille: number, y: number)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.new(1, 0, 0, taille + 20)
	l.BackgroundTransparency = 1
	l.FontFace = POLICE
	l.TextSize = taille
	l.TextColor3 = Color3.fromRGB(230, 200, 120)
	l.TextTransparency = 1
	l.TextStrokeTransparency = 1
	l.Parent = gui
	return l
end
local grandTexte = texteCentral(56, 0.42)
local petitTexte = texteCentral(26, 0.5)

local function annoncer(grand: string, petit: string?, couleur: Color3?)
	grandTexte.Text = grand
	grandTexte.TextColor3 = couleur or Color3.fromRGB(230, 200, 120)
	petitTexte.Text = petit or ""
	for _, l in { grandTexte, petitTexte } do
		l.TextTransparency = 0
		l.TextStrokeTransparency = 0.2
		TweenService:Create(l, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 3.5), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end
end

evEtat.OnClientEvent:Connect(function(e)
	-- Le serveur fait foi : on recale la copie locale.
	local_.vie = e.vie
	local_.endurance = e.endurance
	local_.tEndurance = os.clock()
	local_.fioles = e.fioles
	majVie(e.vie, Regles.JOUEUR.vieMax, true)
	majEndurance(e.endurance, Regles.JOUEUR.enduranceMax)
	for i, f in fioles do
		f.BackgroundTransparency = i <= e.fioles and 0 or 0.8
	end
	if e.boss then
		blocBoss.Visible = true
		nomBoss.Text = e.boss.nom
		majBoss(e.boss.vie, e.boss.vieMax)
	else
		blocBoss.Visible = false
	end
end)

evMessage.OnClientEvent:Connect(function(type_: string, donnees: any)
	if type_ == "victoire" then
		annoncer("LE COL EST LIBÉRÉ", tostring(donnees) .. " est tombé")
	elseif type_ == "rage" then
		annoncer("", "Grimmulf entre dans une rage folle !", Color3.fromRGB(200, 60, 40))
	elseif type_ == "recompense" and type(donnees) == "table" then
		local texte = ("+%d XP"):format(donnees.xp)
		if donnees.premiereFois then
			texte ..= ("  ·  +%d points de compétence  ·  +10 %% de dégâts  ·  XP ×2 pendant 1 h"):format(
				donnees.points
			)
		end
		task.delay(2, annoncer, "", texte)
	end
end)

--------------------------------------------------------------------------------
-- Animations procédurales du chevalier (épaule droite et bassin)
--------------------------------------------------------------------------------

-- Courbe d'une attaque : armer (lever l'épée), frapper (vers le bas), revenir.
local COURBES = {
	legere = { arme = 2.3, fin = 0.2 },
	lourde = { arme = 3.0, fin = -0.3 },
}
local animation: { type: string, debut: number, impact: number, duree: number }? = nil

local function lisse(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Angle d'épaule (radians, vers l'avant) à l'instant t de l'animation.
local function angleEpaule(a, t: number): number
	local c = COURBES[a.type]
	local u = t - a.debut
	local armer = a.impact * 0.7
	if u < armer then
		return c.arme * lisse(u / armer)
	elseif u < a.impact + 0.08 then
		return c.arme + (c.fin - c.arme) * lisse((u - armer) / (a.impact + 0.08 - armer))
	end
	return c.fin * (1 - lisse((u - a.impact - 0.08) / (a.duree - a.impact - 0.08)))
end

-- Les avatars R15 récents utilisent des AnimationConstraint (vérifié dans le moteur
-- le 01/11/2026), les anciens des Motor6D : les deux ont une propriété Transform.
local function articulable(j: Instance?): boolean
	return j ~= nil and (j:IsA("Motor6D") or j:IsA("AnimationConstraint"))
end

local function articulations()
	local perso = joueur.Character
	if not perso then
		return nil, nil, false
	end
	local brasR15 = perso:FindFirstChild("RightUpperArm")
	if brasR15 then
		local bassin = perso:FindFirstChild("LowerTorso")
		return brasR15:FindFirstChild("RightShoulder"), bassin and bassin:FindFirstChild("Root"), false
	end
	local torse = perso:FindFirstChild("Torso")
	local racine = perso:FindFirstChild("HumanoidRootPart")
	return torse and torse:FindFirstChild("Right Shoulder"), racine and racine:FindFirstChild("RootJoint"), true
end

RunService.PreSimulation:Connect(function()
	local a = animation
	if not a then
		return
	end
	local t = os.clock()
	if t >= a.debut + a.duree then
		animation = nil
		return
	end
	local epaule, bassin, r6 = articulations()
	if a.type == "roulade" then
		if articulable(bassin) then
			local tour = -2 * math.pi * lisse((t - a.debut) / a.duree)
			bassin.Transform = bassin.Transform * CFrame.new(0, -1, 0) * CFrame.Angles(tour, 0, 0)
		end
	elseif articulable(epaule) then
		local angle = angleEpaule(a, t)
		-- R15 : lever le bras vers l'avant = rotation autour de X ; R6 : autour de Z.
		epaule.Transform = epaule.Transform * (r6 and CFrame.Angles(0, 0, angle) or CFrame.Angles(angle, 0, 0))
	end
end)

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function racine(): BasePart?
	local perso = joueur.Character
	return perso and perso:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function rouler(fiche)
	local r = racine()
	local perso = joueur.Character
	local h = perso and perso:FindFirstChildOfClass("Humanoid")
	if not (r and h) then
		return
	end
	local dir = h.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = r.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local fin = os.clock() + fiche.duree
	local connexion
	connexion = RunService.Heartbeat:Connect(function()
		if os.clock() >= fin or not r.Parent then
			connexion:Disconnect()
			return
		end
		r.AssemblyLinearVelocity = dir * fiche.vitesse + Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
	end)
end

local function sillage(fiche)
	-- Sillage bref au moment de l'impact (lisibilité du coup).
	local r = racine()
	if not r then
		return
	end
	task.delay(fiche.impact * 0.85, function()
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(225, 232, 245)
		p.Transparency = 0.55
		p.Size = Vector3.new(0.15, fiche.portee * 0.7, 2.2)
		p.CFrame = r.CFrame * CFrame.new(0.8, 0.6, -fiche.portee * 0.35) * CFrame.Angles(math.rad(-70), 0, 0)
		p.Parent = workspace
		TweenService:Create(p, TweenInfo.new(0.18), { Transparency = 1 }):Play()
		task.delay(0.2, function()
			p:Destroy()
		end)
	end)
end

local function agir(action: string)
	local t = os.clock()
	if not Regles.peutAgir(local_, action, t) then
		return
	end
	local fiche = Regles.agir(local_, action, t)
	evAction:FireServer(action)
	if action == "roulade" then
		animation = { type = "roulade", debut = t, impact = 0, duree = fiche.duree }
		rouler(fiche)
	elseif action ~= "fiole" then
		animation = { type = action, debut = t, impact = fiche.impact, duree = fiche.recuperation }
		sillage(fiche)
	end
end

local function lier(action: string, titre: string, position: UDim2, ...)
	ContextActionService:BindAction("Givrecendre_" .. action, function(_, etat)
		if etat == Enum.UserInputState.Begin then
			agir(action)
		end
		return Enum.ContextActionResult.Pass
	end, true, ...)
	ContextActionService:SetTitle("Givrecendre_" .. action, titre)
	ContextActionService:SetPosition("Givrecendre_" .. action, position)
end

lier("legere", "Coup", UDim2.new(1, -95, 1, -170), Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR1)
lier("lourde", "Lourd", UDim2.new(1, -170, 1, -120), Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
lier("roulade", "Roulade", UDim2.new(1, -170, 1, -200), Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
lier("fiole", "Fiole", UDim2.new(1, -95, 1, -250), Enum.KeyCode.R, Enum.KeyCode.ButtonX)

joueur.CharacterAdded:Connect(function()
	local_ = Regles.nouvelEtatJoueur(os.clock())
	animation = nil
end)
]=])
-- src/ReplicatedStorage/Partage/Configuration.luau
installer("ReplicatedStorage", {"Partage"}, "Configuration", "ModuleScript", [=[
--[[
	Configuration partagée serveur + client.

	Les identifiants des passes et produits valent 0 tant qu'ils n'ont pas été
	créés sur Roblox (Creator Hub ou API Open Cloud). Un objet à 0 n'est ni
	affiché dans la boutique ni vendable : rien ne casse s'il manque.

	`python3 pipeline/opencloud.py boutique` crée sur Roblox les objets à 0
	(nom, description, `prix` en Robux, mis en vente) et écrit leur ID ici.
	`prix` ne sert qu'à la création : le jeu affiche toujours le prix réel lu
	sur Roblox (il peut avoir été changé depuis sur le Creator Hub).
]]

return {
	-- Changer ce nom repart d'une sauvegarde vide : ne le modifier qu'en connaissance de cause.
	NOM_DATASTORE = "Joueurs_v1",
	PREFIXE_CLE = "joueur_",

	MONNAIE = {
		nom = "Cristaux",
		icone = "🔮",
	},

	-- Gains de la récompense quotidienne (jour 1 → 7, puis le cycle recommence).
	RECOMPENSES_QUOTIDIENNES = { 10, 20, 30, 50, 75, 100, 200 },

	SAUVEGARDE_AUTO_SECONDES = 120,

	-- Game Passes (achat unique, définitif).
	PASSES = {
		{
			cle = "DoubleMonnaie",
			id = 2062597704,
			nom = "Cristaux x2",
			description = "Chaque cristal ramassé compte double, pour toujours.",
			prix = 99,
			multiplicateurMonnaie = 2,
		},
	},

	-- Developer Products (achats répétables).
	PRODUITS = {
		{
			cle = "PackPetit",
			id = 3725192416,
			nom = "Sac de cristaux",
			description = "+100 cristaux",
			prix = 25,
			monnaie = 100,
		},
		{
			cle = "PackGrand",
			id = 3725192420,
			nom = "Coffre de cristaux",
			description = "+600 cristaux",
			prix = 99,
			monnaie = 600,
		},
	},
}
]=])
-- src/ServerScriptService/Noyau/API.luau
installer("ServerScriptService", {"Noyau"}, "API", "ModuleScript", [=[
--[[
	Point d'entrée du noyau pour les scripts de map / de jeu (côté serveur).

	Exemple, dans un script de map :
		local noyau = game:GetService("ServerScriptService"):FindFirstChild("Noyau")
		local API = noyau and require(noyau.API)
		if API then API.ajouterMonnaie(joueur, 5, "cristal") end

	Le script Principal branche les implémentations au démarrage. Tant qu'il
	ne l'a pas fait (ou si le profil du joueur n'est pas encore chargé), les
	fonctions renvoient false sans erreur.
]]

local API = {}

local implementation = nil

function API._brancher(impl)
	implementation = impl
end

-- Ajoute de la monnaie (multiplicateurs des passes appliqués). Renvoie le montant réellement gagné, ou false.
function API.ajouterMonnaie(joueur: Player, montant: number, raison: string?): number | false
	if not implementation then
		return false
	end
	return implementation.ajouterMonnaie(joueur, montant, raison)
end

-- Dépense de la monnaie. Renvoie true si le joueur avait assez.
function API.depenserMonnaie(joueur: Player, montant: number, raison: string?): boolean
	if not implementation then
		return false
	end
	return implementation.depenserMonnaie(joueur, montant, raison)
end

-- Table `jeu` du profil (progression propre au jeu, sauvegardée automatiquement), ou nil.
function API.donneesJeu(joueur: Player): { [any]: any }?
	if not implementation then
		return nil
	end
	return implementation.donneesJeu(joueur)
end

-- Le joueur possède-t-il ce pass ? (clé définie dans Configuration.PASSES)
function API.possedePass(joueur: Player, cle: string): boolean
	if not implementation then
		return false
	end
	return implementation.possedePass(joueur, cle)
end

return API
]=])
-- src/ServerScriptService/Noyau/Achats.luau
installer("ServerScriptService", {"Noyau"}, "Achats", "ModuleScript", [=[
--[[
	Traitement des achats de Developer Products (MarketplaceService.ProcessReceipt).

	Module PUR : toutes les dépendances Roblox sont injectées, ce qui permet de
	tester les cas difficiles hors ligne (sauvegarde qui échoue, reçu rejoué,
	joueur parti…).

	Garanties :
	- un même achat (PurchaseId) n'est JAMAIS crédité deux fois ;
	- on ne répond « accordé » à Roblox qu'une fois le crédit SAUVEGARDÉ.
	  Sinon on répond « pas encore » et Roblox renverra le reçu plus tard.
]]

local Achats = {}

Achats.ACCORDE = "Accorde"
Achats.PAS_ENCORE = "PasEncore"

export type Dependances = {
	profilDe: (userId: number) -> any?, -- profil chargé du joueur, nil s'il n'est pas (ou plus) là
	gestionnaires: { [number]: (profil: any) -> boolean? }, -- ProductId -> fonction qui crédite
	sauvegarderMaintenant: (userId: number) -> boolean,
	copieProfonde: (any) -> any,
	memoriserAchat: (profil: any, purchaseId: string) -> (),
	achatDejaTraite: (profil: any, purchaseId: string) -> boolean,
	journal: ((string) -> ())?,
}

function Achats.creerTraitement(deps: Dependances)
	local journal = deps.journal or function() end
	-- Achats crédités en mémoire mais pas encore confirmés par une sauvegarde.
	local enAttenteDeSauvegarde: { [string]: boolean } = {}

	return function(recu): string
		local userId, purchaseId, productId = recu.PlayerId, recu.PurchaseId, recu.ProductId
		local profil = deps.profilDe(userId)
		if not profil then
			-- Joueur absent ou profil pas encore chargé : Roblox réessaiera.
			return Achats.PAS_ENCORE
		end

		if deps.achatDejaTraite(profil, purchaseId) then
			if not enAttenteDeSauvegarde[purchaseId] then
				return Achats.ACCORDE
			end
			-- Déjà crédité mais la sauvegarde avait échoué : on retente juste la sauvegarde.
			if deps.sauvegarderMaintenant(userId) then
				enAttenteDeSauvegarde[purchaseId] = nil
				return Achats.ACCORDE
			end
			return Achats.PAS_ENCORE
		end

		local gestionnaire = deps.gestionnaires[productId]
		if not gestionnaire then
			journal(`Achat {purchaseId} : produit inconnu {productId}`)
			return Achats.PAS_ENCORE
		end

		-- Le gestionnaire travaille sur le profil ; en cas d'erreur on restaure l'état d'avant.
		local avant = deps.copieProfonde(profil)
		local ok, resultat = pcall(gestionnaire, profil)
		if not ok or resultat == false then
			for cle in profil do
				profil[cle] = nil
			end
			for cle, valeur in avant do
				profil[cle] = valeur
			end
			journal(`Achat {purchaseId} : échec du crédit ({if ok then "refusé" else tostring(resultat)})`)
			return Achats.PAS_ENCORE
		end

		deps.memoriserAchat(profil, purchaseId)
		if deps.sauvegarderMaintenant(userId) then
			return Achats.ACCORDE
		end
		enAttenteDeSauvegarde[purchaseId] = true
		journal(`Achat {purchaseId} : crédité, sauvegarde en échec, Roblox réessaiera`)
		return Achats.PAS_ENCORE
	end
end

return Achats
]=])
-- src/ServerScriptService/Noyau/Profil.luau
installer("ServerScriptService", {"Noyau"}, "Profil", "ModuleScript", [=[
--[[
	Profil d'un joueur : structure des données sauvegardées.

	Module PUR (aucune dépendance à Roblox) : testé hors ligne par
	pipeline/tests/noyau.test.luau.

	Règle d'or : on n'enlève jamais un champ et on ne change jamais son sens.
	Pour une évolution, on incrémente VERSION et on ajoute une étape dans
	MIGRATIONS. reconcilier() complète toujours les champs manquants avec les
	valeurs par défaut, ce qui permet d'ajouter des champs sans migration.
]]

local Profil = {}

Profil.VERSION = 1
Profil.MAX_ACHATS_MEMORISES = 50

local function copieProfonde(valeur)
	if type(valeur) ~= "table" then
		return valeur
	end
	local copie = {}
	for k, v in valeur do
		copie[k] = copieProfonde(v)
	end
	return copie
end
Profil.copieProfonde = copieProfonde

-- Valeurs par défaut d'un nouveau joueur.
function Profil.defaut(maintenant: number)
	return {
		version = Profil.VERSION,
		monnaie = 0,
		totalGagne = 0, -- tout ce qui a été gagné depuis le début (statistique)
		recompense = {
			dernierJour = -1, -- numéro du dernier jour réclamé (jours depuis 1970, UTC)
			serie = 0, -- jours consécutifs
		},
		achatsTraites = {}, -- PurchaseId des derniers achats déjà crédités (anti double-crédit)
		stats = {
			premiereVisite = maintenant,
			derniereVisite = maintenant,
			visites = 0,
			tempsDeJeu = 0, -- secondes
		},
		jeu = {}, -- données propres au jeu (progression, objets…)
	}
end

-- Étapes de migration : MIGRATIONS[n] transforme une version n en version n + 1.
local MIGRATIONS: { [number]: (any) -> () } = {}

-- Complète récursivement `cible` avec les champs absents de `modele`.
local function completer(cible, modele)
	for cle, valeurDefaut in modele do
		local valeur = cible[cle]
		if valeur == nil then
			cible[cle] = copieProfonde(valeurDefaut)
		elseif type(valeur) == "table" and type(valeurDefaut) == "table" then
			-- On ne complète pas les listes (ex. achatsTraites) : seulement les sous-tables à clés nommées.
			if next(valeurDefaut) ~= nil then
				completer(valeur, valeurDefaut)
			end
		end
	end
end

--[[
	Rend un profil utilisable à partir de données chargées (ou nil pour un
	nouveau joueur) : migrations, puis champs manquants complétés.
	Renvoie le profil et un booléen « nouveau joueur ».
]]
function Profil.reconcilier(donnees: any, maintenant: number)
	if type(donnees) ~= "table" then
		return Profil.defaut(maintenant), true
	end
	local version = tonumber(donnees.version) or 1
	while version < Profil.VERSION do
		local etape = MIGRATIONS[version]
		if etape then
			etape(donnees)
		end
		version += 1
	end
	donnees.version = Profil.VERSION
	completer(donnees, Profil.defaut(maintenant))
	return donnees, false
end

-- Mémorise un PurchaseId traité, en gardant seulement les plus récents.
function Profil.memoriserAchat(profil, purchaseId: string)
	local liste = profil.achatsTraites
	table.insert(liste, purchaseId)
	while #liste > Profil.MAX_ACHATS_MEMORISES do
		table.remove(liste, 1)
	end
end

function Profil.achatDejaTraite(profil, purchaseId: string): boolean
	return table.find(profil.achatsTraites, purchaseId) ~= nil
end

-- Ajoute (ou retire si négatif) de la monnaie. Refuse de passer sous zéro.
function Profil.ajouterMonnaie(profil, montant: number): boolean
	if montant ~= montant or montant == math.huge or montant == -math.huge then
		return false -- NaN ou infini
	end
	montant = math.floor(montant)
	if profil.monnaie + montant < 0 then
		return false
	end
	profil.monnaie += montant
	if montant > 0 then
		profil.totalGagne += montant
	end
	return true
end

return Profil
]=])
-- src/ServerScriptService/Noyau/RecompenseQuotidienne.luau
installer("ServerScriptService", {"Noyau"}, "RecompenseQuotidienne", "ModuleScript", [=[
--[[
	Récompense quotidienne avec série de jours consécutifs.

	Module PUR : le temps est passé en paramètre (os.time() côté serveur),
	ce qui permet de tester « demain », « dans 3 jours », etc.

	Les jours sont comptés en UTC (minuit UTC = nouveau jour), pour que tous
	les serveurs soient d'accord quelle que soit leur région.
]]

local RecompenseQuotidienne = {}

local SECONDES_PAR_JOUR = 86400

function RecompenseQuotidienne.jour(horodatage: number): number
	return math.floor(horodatage / SECONDES_PAR_JOUR)
end

--[[
	État pour l'affichage. `etat` = profil.recompense, `recompenses` = liste
	cyclique des gains (jour 1, jour 2, …).
	Renvoie { disponible, serieSiReclamee, gainSiReclamee, secondesAvantProchaine }.
]]
function RecompenseQuotidienne.etat(etat, maintenant: number, recompenses: { number })
	local aujourdhui = RecompenseQuotidienne.jour(maintenant)
	local disponible = aujourdhui > etat.dernierJour
	local serie
	if not disponible then
		serie = etat.serie
	elseif aujourdhui == etat.dernierJour + 1 then
		serie = etat.serie + 1 -- série continue
	else
		serie = 1 -- première fois, ou série cassée
	end
	local indice = ((serie - 1) % #recompenses) + 1
	return {
		disponible = disponible,
		serieSiReclamee = serie,
		gainSiReclamee = recompenses[indice],
		secondesAvantProchaine = if disponible then 0 else (aujourdhui + 1) * SECONDES_PAR_JOUR - maintenant,
	}
end

--[[
	Réclame la récompense du jour : modifie `etat` et renvoie le gain,
	ou nil si elle a déjà été réclamée aujourd'hui.
]]
function RecompenseQuotidienne.reclamer(etat, maintenant: number, recompenses: { number }): number?
	local e = RecompenseQuotidienne.etat(etat, maintenant, recompenses)
	if not e.disponible then
		return nil
	end
	etat.dernierJour = RecompenseQuotidienne.jour(maintenant)
	etat.serie = e.serieSiReclamee
	return e.gainSiReclamee
end

return RecompenseQuotidienne
]=])
-- src/ServerScriptService/Noyau/Sauvegarde.luau
installer("ServerScriptService", {"Noyau"}, "Sauvegarde", "ModuleScript", [=[
--[[
	Sauvegarde des profils dans un DataStore, avec verrou de session.

	Le DataStore est INJECTÉ (n'importe quel objet qui a une méthode
	UpdateAsync(cle, fonction) comme un vrai DataStore Roblox). Cela permet de
	tester hors ligne avec un DataStore simulé, y compris les pannes.

	Verrou de session : quand un serveur charge un profil, il y inscrit son
	identifiant (JobId). Un autre serveur qui voudrait le charger en même temps
	(joueur qui change vite de serveur) attend que le premier l'ait libéré.
	Sans ce verrou, deux serveurs peuvent s'écraser mutuellement les données
	(perte de progression, objets dupliqués). Un verrou plus vieux que
	DUREE_VERROU est considéré comme abandonné (serveur planté).

	Format stocké : { donnees = <profil>, verrou = { jobId, heure } | nil }
]]

local Sauvegarde = {}
Sauvegarde.__index = Sauvegarde

export type Options = {
	jobId: string,
	maintenant: () -> number,
	attendre: (number) -> (),
	dureeVerrou: number?, -- secondes avant de considérer un verrou abandonné (défaut 1800)
	essaisChargement: number?, -- défaut 6
	attenteVerrou: number?, -- secondes entre deux essais si verrouillé (défaut 5)
	essaisSauvegarde: number?, -- défaut 3
	journal: ((string) -> ())?,
}

function Sauvegarde.nouveau(store, options: Options)
	return setmetatable({
		_store = store,
		_jobId = options.jobId,
		_maintenant = options.maintenant,
		_attendre = options.attendre,
		_dureeVerrou = options.dureeVerrou or 1800,
		_essaisChargement = options.essaisChargement or 6,
		_attenteVerrou = options.attenteVerrou or 5,
		_essaisSauvegarde = options.essaisSauvegarde or 3,
		_journal = options.journal or function() end,
	}, Sauvegarde)
end

--[[
	Charge les données et prend le verrou.
	Renvoie (donnees | nil, nil) en cas de succès (nil = nouveau joueur),
	ou (nil, "verrouille" | "erreur: …") en cas d'échec.
]]
function Sauvegarde:charger(cle: string): (any, string?)
	local derniereErreur = "inconnue"
	for essai = 1, self._essaisChargement do
		local verrouille = false
		local donnees = nil
		local ok, erreur = pcall(function()
			self._store:UpdateAsync(cle, function(ancien)
				-- UpdateAsync peut rappeler cette fonction : on repart de zéro à chaque appel.
				verrouille = false
				donnees = nil
				local enregistrement = if type(ancien) == "table" then ancien else {}
				local verrou = enregistrement.verrou
				if
					verrou
					and verrou.jobId ~= self._jobId
					and self._maintenant() - (verrou.heure or 0) < self._dureeVerrou
				then
					verrouille = true
					return nil -- annule l'écriture
				end
				enregistrement.verrou = { jobId = self._jobId, heure = self._maintenant() }
				donnees = enregistrement.donnees
				return enregistrement
			end)
		end)
		if ok and not verrouille then
			return donnees, nil
		end
		derniereErreur = if ok then "verrouille" else `erreur: {erreur}`
		self._journal(`Chargement {cle} : essai {essai} échoué ({derniereErreur})`)
		if essai < self._essaisChargement then
			self._attendre(if verrouille then self._attenteVerrou else essai)
		end
	end
	return nil, derniereErreur
end

--[[
	Sauvegarde les données. Si `liberer` est vrai, rend le verrou (départ du joueur).
	Refuse d'écrire si le verrou appartient désormais à un autre serveur.
	Renvoie true si la sauvegarde a réussi.
]]
function Sauvegarde:sauvegarder(cle: string, donnees, liberer: boolean?): boolean
	for essai = 1, self._essaisSauvegarde do
		local verrouPerdu = false
		local ok, erreur = pcall(function()
			self._store:UpdateAsync(cle, function(ancien)
				verrouPerdu = false
				local enregistrement = if type(ancien) == "table" then ancien else {}
				local verrou = enregistrement.verrou
				if verrou and verrou.jobId ~= self._jobId then
					verrouPerdu = true
					return nil
				end
				enregistrement.donnees = donnees
				enregistrement.verrou = if liberer then nil else { jobId = self._jobId, heure = self._maintenant() }
				return enregistrement
			end)
		end)
		if ok and not verrouPerdu then
			return true
		end
		if verrouPerdu then
			self._journal(`Sauvegarde {cle} refusée : un autre serveur a pris le verrou`)
			return false
		end
		self._journal(`Sauvegarde {cle} : essai {essai} échoué ({erreur})`)
		if essai < self._essaisSauvegarde then
			self._attendre(essai)
		end
	end
	return false
end

return Sauvegarde
]=])
-- src/ServerScriptService/Principal.server.luau
installer("ServerScriptService", {}, "Principal", "Script", [=[
--[[
	Script serveur principal : branche le noyau (modules purs testés hors
	ligne) sur les services Roblox.

	- Chargement / sauvegarde des profils (DataStore + verrou de session)
	- leaderstats (monnaie visible dans le classement)
	- Récompense quotidienne (RemoteFunctions)
	- Achats : Developer Products (ProcessReceipt) et Game Passes
	- API pour les scripts de map (Noyau.API)
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Noyau = script.Parent:WaitForChild("Noyau")
local Achats = require(Noyau.Achats)
local API = require(Noyau.API)
local Profil = require(Noyau.Profil)
local RecompenseQuotidienne = require(Noyau.RecompenseQuotidienne)
local Sauvegarde = require(Noyau.Sauvegarde)
local Configuration = require(ReplicatedStorage:WaitForChild("Partage"):WaitForChild("Configuration"))

local function journal(message: string)
	print("[Noyau] " .. message)
end

--------------------------------------------------------------------------------
-- DataStore (ou mémoire en Studio si l'accès aux API n'est pas activé)
--------------------------------------------------------------------------------

local function storeMemoire()
	local donnees = {}
	return {
		UpdateAsync = function(_, cle, transformation)
			local nouveau = transformation(donnees[cle])
			if nouveau ~= nil then
				donnees[cle] = nouveau
			end
			return nouveau
		end,
	}
end

local store
local sauvegardeReelle = true
do
	local ok, resultat = pcall(function()
		return DataStoreService:GetDataStore(Configuration.NOM_DATASTORE)
	end)
	if ok then
		store = resultat
	else
		sauvegardeReelle = false
		store = storeMemoire()
		warn("[Noyau] DataStore indisponible, progression NON sauvegardée : " .. tostring(resultat))
	end
end

local sauvegarde = Sauvegarde.nouveau(store, {
	jobId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false),
	maintenant = os.time,
	attendre = task.wait,
	-- En Studio sans accès aux API, inutile d'attendre longtemps avant le profil temporaire.
	essaisChargement = if RunService:IsStudio() then 2 else 6,
	journal = journal,
})

--------------------------------------------------------------------------------
-- Profils chargés
--------------------------------------------------------------------------------

type Session = {
	profil: any,
	passes: { [string]: boolean },
	arrivee: number,
	sauvegardable: boolean, -- false si le chargement a échoué en Studio (profil temporaire)
}

local sessions: { [Player]: Session } = {}

local function cleDe(joueur: Player): string
	return Configuration.PREFIXE_CLE .. joueur.UserId
end

local function passParCle(cle: string)
	for _, pass in Configuration.PASSES do
		if pass.cle == cle then
			return pass
		end
	end
	return nil
end

-- Remotes (créés par le serveur, utilisés par l'interface).
local dossierRemotes = Instance.new("Folder")
dossierRemotes.Name = "Remotes"
local remoteEtat = Instance.new("RemoteFunction")
remoteEtat.Name = "EtatJoueur"
remoteEtat.Parent = dossierRemotes
local remoteReclamer = Instance.new("RemoteFunction")
remoteReclamer.Name = "ReclamerRecompense"
remoteReclamer.Parent = dossierRemotes
local remoteMiseAJour = Instance.new("RemoteEvent")
remoteMiseAJour.Name = "MiseAJour"
remoteMiseAJour.Parent = dossierRemotes
dossierRemotes.Parent = ReplicatedStorage

local function etatPourClient(joueur: Player)
	local session = sessions[joueur]
	if not session then
		return nil
	end
	local p = session.profil
	return {
		monnaie = p.monnaie,
		recompense = RecompenseQuotidienne.etat(p.recompense, os.time(), Configuration.RECOMPENSES_QUOTIDIENNES),
		passes = session.passes,
		sauvegardeActive = sauvegardeReelle and session.sauvegardable,
	}
end

local function rafraichir(joueur: Player)
	local session = sessions[joueur]
	if not session then
		return
	end
	local stats = joueur:FindFirstChild("leaderstats")
	local valeur = stats and stats:FindFirstChild(Configuration.MONNAIE.nom)
	if valeur then
		valeur.Value = session.profil.monnaie
	end
	remoteMiseAJour:FireClient(joueur, etatPourClient(joueur))
end

local function sauvegarderJoueur(joueur: Player, liberer: boolean): boolean
	local session = sessions[joueur]
	if not session or not session.sauvegardable then
		return false
	end
	local p = session.profil
	p.stats.derniereVisite = os.time()
	p.stats.tempsDeJeu += os.time() - session.arrivee
	session.arrivee = os.time()
	return sauvegarde:sauvegarder(cleDe(joueur), p, liberer)
end

local function verifierPasses(joueur: Player, session: Session)
	for _, pass in Configuration.PASSES do
		if pass.id ~= 0 then
			local ok, possede = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(joueur.UserId, pass.id)
			end)
			session.passes[pass.cle] = ok and possede == true
		end
	end
end

local function joueurArrive(joueur: Player)
	local donnees, erreur = sauvegarde:charger(cleDe(joueur))
	if not joueur.Parent then
		-- Parti pendant le chargement : on rend le verrou tout de suite.
		if not erreur then
			sauvegarde:sauvegarder(cleDe(joueur), donnees, true)
		end
		return
	end

	local sauvegardable = true
	if erreur then
		if RunService:IsStudio() then
			-- En Studio sans accès aux API : on joue quand même, sans sauvegarde.
			warn("[Noyau] Chargement impossible (" .. erreur .. ") : profil temporaire en Studio.")
			sauvegardable = false
			donnees = nil
		else
			-- En ligne : mieux vaut refuser que risquer d'écraser la progression.
			joueur:Kick("Tes données n'ont pas pu être chargées. Réessaie dans une minute, ta progression est en sécurité.")
			return
		end
	end

	local profil = Profil.reconcilier(donnees, os.time())
	profil.stats.visites += 1
	local session: Session = { profil = profil, passes = {}, arrivee = os.time(), sauvegardable = sauvegardable }
	sessions[joueur] = session

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local valeur = Instance.new("IntValue")
	valeur.Name = Configuration.MONNAIE.nom
	valeur.Value = profil.monnaie
	valeur.Parent = stats
	stats.Parent = joueur

	verifierPasses(joueur, session)
	rafraichir(joueur)
end

local function joueurPart(joueur: Player)
	if sessions[joueur] then
		sauvegarderJoueur(joueur, true)
		sessions[joueur] = nil
	end
end

Players.PlayerAdded:Connect(joueurArrive)
Players.PlayerRemoving:Connect(joueurPart)
for _, joueur in Players:GetPlayers() do
	task.spawn(joueurArrive, joueur)
end

-- Sauvegarde automatique.
task.spawn(function()
	while true do
		task.wait(Configuration.SAUVEGARDE_AUTO_SECONDES)
		for joueur in sessions do
			task.spawn(sauvegarderJoueur, joueur, false)
		end
	end
end)

-- Arrêt du serveur : on sauvegarde tout le monde en parallèle avant la fermeture.
game:BindToClose(function()
	local restants = 0
	for joueur in sessions do
		restants += 1
		task.spawn(function()
			sauvegarderJoueur(joueur, true)
			restants -= 1
		end)
	end
	local debut = os.clock()
	while restants > 0 and os.clock() - debut < 25 do
		task.wait(0.1)
	end
end)

--------------------------------------------------------------------------------
-- Récompense quotidienne
--------------------------------------------------------------------------------

local derniereDemande: { [Player]: number } = {}

remoteEtat.OnServerInvoke = function(joueur: Player)
	return etatPourClient(joueur)
end

remoteReclamer.OnServerInvoke = function(joueur: Player)
	-- Anti-spam : une demande par seconde maximum.
	local maintenant = os.clock()
	if derniereDemande[joueur] and maintenant - derniereDemande[joueur] < 1 then
		return { ok = false, raison = "trop_rapide" }
	end
	derniereDemande[joueur] = maintenant

	local session = sessions[joueur]
	if not session then
		return { ok = false, raison = "pas_charge" }
	end
	local gain = RecompenseQuotidienne.reclamer(session.profil.recompense, os.time(), Configuration.RECOMPENSES_QUOTIDIENNES)
	if not gain then
		return { ok = false, raison = "deja_reclamee", etat = etatPourClient(joueur) }
	end
	Profil.ajouterMonnaie(session.profil, gain)
	task.spawn(sauvegarderJoueur, joueur, false)
	rafraichir(joueur)
	return { ok = true, gain = gain, serie = session.profil.recompense.serie, etat = etatPourClient(joueur) }
end

Players.PlayerRemoving:Connect(function(joueur)
	derniereDemande[joueur] = nil
end)

--------------------------------------------------------------------------------
-- Achats
--------------------------------------------------------------------------------

local gestionnaires = {}
for _, produit in Configuration.PRODUITS do
	if produit.id ~= 0 and produit.monnaie then
		gestionnaires[produit.id] = function(profil)
			return Profil.ajouterMonnaie(profil, produit.monnaie)
		end
	end
end

local traiterRecu = Achats.creerTraitement({
	profilDe = function(userId: number)
		local joueur = Players:GetPlayerByUserId(userId)
		local session = joueur and sessions[joueur]
		return session and session.profil
	end,
	gestionnaires = gestionnaires,
	sauvegarderMaintenant = function(userId: number)
		local joueur = Players:GetPlayerByUserId(userId)
		if not joueur then
			return false
		end
		local ok = sauvegarderJoueur(joueur, false)
		if ok then
			rafraichir(joueur)
		end
		return ok
	end,
	copieProfonde = Profil.copieProfonde,
	memoriserAchat = Profil.memoriserAchat,
	achatDejaTraite = Profil.achatDejaTraite,
	journal = journal,
})

MarketplaceService.ProcessReceipt = function(recu)
	local decision = traiterRecu(recu)
	if decision == Achats.ACCORDE then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(joueur: Player, passId: number, achete: boolean)
	if not achete then
		return
	end
	local session = sessions[joueur]
	if not session then
		return
	end
	for _, pass in Configuration.PASSES do
		if pass.id == passId then
			session.passes[pass.cle] = true
		end
	end
	rafraichir(joueur)
end)

--------------------------------------------------------------------------------
-- API pour les scripts de map
--------------------------------------------------------------------------------

local function multiplicateur(session: Session): number
	local m = 1
	for cle, possede in session.passes do
		local pass = possede and passParCle(cle)
		if pass and pass.multiplicateurMonnaie then
			m *= pass.multiplicateurMonnaie
		end
	end
	return m
end

API._brancher({
	ajouterMonnaie = function(joueur: Player, montant: number, _raison: string?)
		local session = sessions[joueur]
		if not session or type(montant) ~= "number" or montant <= 0 then
			return false
		end
		local gain = math.floor(montant * multiplicateur(session))
		if not Profil.ajouterMonnaie(session.profil, gain) then
			return false
		end
		rafraichir(joueur)
		return gain
	end,
	depenserMonnaie = function(joueur: Player, montant: number, _raison: string?)
		local session = sessions[joueur]
		if not session or type(montant) ~= "number" or montant <= 0 then
			return false
		end
		local ok = Profil.ajouterMonnaie(session.profil, -montant)
		if ok then
			rafraichir(joueur)
		end
		return ok
	end,
	donneesJeu = function(joueur: Player)
		local session = sessions[joueur]
		return session and session.profil.jeu
	end,
	possedePass = function(joueur: Player, cle: string)
		local session = sessions[joueur]
		return session ~= nil and session.passes[cle] == true
	end,
})

journal(`Prêt (sauvegarde {if sauvegardeReelle then "DataStore" else "en mémoire"})`)
]=])
print("Givrecendre : combat installé (" .. 11 .. " scripts)")
