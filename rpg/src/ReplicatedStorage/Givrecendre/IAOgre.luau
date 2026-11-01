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
