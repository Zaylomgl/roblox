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
	vitesse = 13,
	vitessePhase2 = 17,
	rage = 2.2, -- secondes de rugissement au passage en phase 2 (pas d'attaque)
	accelerationPhase2 = 0.75, -- préparations raccourcies en phase 2
	attaques = {
		balayage = { portee = 24, angle = 150, degats = 28, preparation = 0.9, recuperation = 1.2 },
		onde = { portee = 20, rayon = 26, degats = 34, preparation = 1.3, recuperation = 1.7 },
		charge = {
			porteeMin = 26,
			porteeMax = 80,
			largeur = 12,
			vitesse = 70,
			degats = 38,
			preparation = 1.0,
			recuperation = 1.9,
		},
		rocher = { porteeMin = 30, porteeMax = 90, rayon = 9, degats = 30, preparation = 1.1, recuperation = 1.3 },
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
