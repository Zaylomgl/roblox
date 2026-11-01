--[[
	Tests hors ligne du combat de Givrecendre (rpg/src/ReplicatedStorage/Givrecendre).
]]

local IA = require("../../rpg/src/ReplicatedStorage/Givrecendre/IAOgre")
local Regles = require("../../rpg/src/ReplicatedStorage/Givrecendre/Regles")

local M = {}

-- Générateur pseudo-aléatoire déterministe (même interface que Random).
local function rng(valeurs: { number })
	local i = 0
	return {
		NextNumber = function(_)
			i = i % #valeurs + 1
			return valeurs[i]
		end,
	}
end

---------------------------------------------------------------- Géométrie

M["cône : cible devant, dans la portée"] = function(t)
	t.vrai(Regles.dansCone(0, 0, 0, 1, 0, 10, 11, 80))
end

M["cône : cible derrière"] = function(t)
	t.faux(Regles.dansCone(0, 0, 0, 1, 0, -5, 11, 80))
end

M["cône : cible trop loin, sauf si son corps est large"] = function(t)
	t.faux(Regles.dansCone(0, 0, 0, 1, 0, 18, 11, 80))
	t.vrai(Regles.dansCone(0, 0, 0, 1, 0, 18, 11, 80, 9))
end

M["cône : grosse cible sur le côté touchée grâce à sa taille"] = function(t)
	-- 60° hors de l'axe, cône de 80° (±40°) : raté pour un point, touché pour un rayon de 9.
	local x, z = math.sin(math.rad(60)) * 12, math.cos(math.rad(60)) * 12
	t.faux(Regles.dansCone(0, 0, 0, 1, x, z, 13, 80))
	t.vrai(Regles.dansCone(0, 0, 0, 1, x, z, 13, 80, 9))
end

M["segment : distance au couloir de charge"] = function(t)
	t.egal(Regles.distanceSegment(5, 10, 0, 0, 0, 20), 5)
	t.egal(Regles.distanceSegment(0, -3, 0, 0, 0, 20), 3)
end

---------------------------------------------------------------- Joueur

M["endurance : une attaque coûte, puis remonte après le délai"] = function(t)
	local e = Regles.nouvelEtatJoueur(0)
	t.vrai((Regles.peutAgir(e, "lourde", 0)))
	Regles.agir(e, "lourde", 0)
	t.egal(Regles.endurance(e, 0), 65)
	t.egal(Regles.endurance(e, 0.5), 65) -- pas de régénération avant 0,8 s
	t.egal(Regles.endurance(e, 1.8), 65 + 30)
	t.egal(Regles.endurance(e, 10), 100)
end

M["endurance : action refusée à 0, permise avec un reste"] = function(t)
	local e = Regles.nouvelEtatJoueur(0)
	local temps = 0
	for _ = 1, 3 do
		Regles.agir(e, "lourde", temps)
		temps += 1.05 -- récupération écoulée, mais pas le délai de régénération
		e.derniereAction = temps -- (simule des actions enchaînées sans pause)
	end
	t.egal(Regles.endurance(e, temps), 0)
	local ok, raison = Regles.peutAgir(e, "legere", temps)
	t.faux(ok)
	t.egal(raison, "endurance")
end

M["action : impossible pendant la récupération"] = function(t)
	local e = Regles.nouvelEtatJoueur(0)
	Regles.agir(e, "legere", 0)
	local ok, raison = Regles.peutAgir(e, "legere", 0.2)
	t.faux(ok)
	t.egal(raison, "occupe")
	t.vrai((Regles.peutAgir(e, "legere", 0.5)))
end

M["roulade : invulnérable pendant 0,35 s seulement"] = function(t)
	local e = Regles.nouvelEtatJoueur(0)
	Regles.agir(e, "roulade", 10)
	t.egal(Regles.subirDegats(e, 30, 10.2), 0)
	t.egal(e.vie, 100)
	t.egal(Regles.subirDegats(e, 30, 10.4), 30)
	t.egal(e.vie, 70)
end

M["fiole : soigne, plafonnée à la vie max, 3 au maximum"] = function(t)
	local e = Regles.nouvelEtatJoueur(0)
	Regles.subirDegats(e, 80, 0)
	Regles.agir(e, "fiole", 1)
	t.egal(e.vie, 65)
	Regles.agir(e, "fiole", 3)
	t.egal(e.vie, 100)
	Regles.agir(e, "fiole", 5)
	local ok, raison = Regles.peutAgir(e, "fiole", 7)
	t.faux(ok)
	t.egal(raison, "plus de fiole")
end

M["mort : plus aucune action, plus de dégâts"] = function(t)
	local e = Regles.nouvelEtatJoueur(0)
	t.egal(Regles.subirDegats(e, 500, 0), 100)
	t.faux((Regles.peutAgir(e, "fiole", 1)))
	t.egal(Regles.subirDegats(e, 10, 2), 0)
end

M["action inconnue refusée (message client trafiqué)"] = function(t)
	local ok, raison = Regles.peutAgir(Regles.nouvelEtatJoueur(0), "tuerBoss", 0)
	t.faux(ok)
	t.egal(raison, "inconnue")
end

---------------------------------------------------------------- Récompenses

M["boss : +10 % de dégâts par boss vaincu, cumulable"] = function(t)
	t.egal(Regles.multiplicateurDegats(nil), 1)
	t.egal(Regles.degatsAttaque("lourde", {}), 34)
	t.egal(Regles.degatsAttaque("lourde", { bossVaincus = { ogre = true } }), 37) -- 34 × 1,1 = 37,4
	local jeu = { bossVaincus = { ogre = true, hippogriffe = true, tisseuse = true } }
	t.egal(math.floor(Regles.multiplicateurDegats(jeu) * 100 + 0.5), 130)
end

M["boss : première victoire = XP, 3 points, boost d'XP 1 h"] = function(t)
	local jeu = {}
	local r = Regles.recompenserBoss(jeu, "ogre", 1000)
	t.vrai(r.premiereFois)
	t.egal(jeu.xp, 500)
	t.egal(jeu.pointsCompetence, 3)
	t.egal(jeu.boostXpFin, 4600)
	t.egal(Regles.multiplicateurXp(jeu, 4599), 2)
	t.egal(Regles.multiplicateurXp(jeu, 4600), 1)
end

M["boss : une seconde victoire ne redonne que de l'XP"] = function(t)
	local jeu = {}
	Regles.recompenserBoss(jeu, "ogre", 0)
	local r = Regles.recompenserBoss(jeu, "ogre", 100)
	t.faux(r.premiereFois)
	t.egal(jeu.xp, 600)
	t.egal(jeu.pointsCompetence, 3)
	t.egal(jeu.boostXpFin, 3600)
end

---------------------------------------------------------------- IA de l'Ogre

M["IA : attend tant que personne n'entre"] = function(t)
	local ia = IA.nouveau(rng({ 0.1 }))
	t.egal(#IA.mettreAJour(ia, 0, nil), 0)
	t.egal(ia.etat, "attente")
	t.egal(IA.subirDegats(ia, 50), 0) -- invulnérable avant le combat
end

M["IA : avance quand la cible est entre portée de mêlée et de charge"] = function(t)
	local ia = IA.nouveau(rng({ 0.1 }))
	local o = IA.mettreAJour(ia, 0, 25) -- > 24 (balayage) et < 26 (charge)
	t.egal(o[1].type, "avancer")
	t.egal(o[1].vitesse, Regles.OGRE.vitesse)
end

M["IA : télégraphie, frappe, puis récupère"] = function(t)
	local ia = IA.nouveau(rng({ 0.01 }))
	local o = IA.mettreAJour(ia, 0, 10)
	t.egal(o[1].type, "preparer")
	t.egal(o[1].attaque, "balayage")
	local B = Regles.OGRE.attaques.balayage
	t.egal(#IA.mettreAJour(ia, B.preparation - 0.1, 10), 0) -- encore en préparation
	o = IA.mettreAJour(ia, B.preparation, 10)
	t.egal(o[1].type, "frapper")
	t.egal(ia.etat, "recuperation")
	t.egal(#IA.mettreAJour(ia, B.preparation + B.recuperation - 0.1, 10), 0) -- fenêtre pour punir le boss
	o = IA.mettreAJour(ia, B.preparation + B.recuperation, 10)
	t.egal(o[1].type, "preparer")
end

M["IA : charge de loin, jamais de rocher en phase 1"] = function(t)
	for _, v in { 0.01, 0.5, 0.99 } do
		local ia = IA.nouveau(rng({ v }))
		local o = IA.mettreAJour(ia, 0, 50)
		t.egal(o[1].attaque, "charge")
	end
end

M["IA : jamais trois fois de suite la même attaque"] = function(t)
	local ia = IA.nouveau(rng({ 0.01 })) -- tire toujours la première candidate
	local suite = {}
	local temps = 0
	while #suite < 8 do
		for _, o in IA.mettreAJour(ia, temps, 10) do
			if o.type == "preparer" then
				table.insert(suite, o.attaque)
			end
		end
		temps += 5 -- assez pour finir chaque préparation et récupération
	end
	for i = 3, #suite do
		t.vrai(not (suite[i] == suite[i - 1] and suite[i] == suite[i - 2]))
	end
end

M["IA : phase 2 à 50 % : rage, puis attaques plus rapides et rochers"] = function(t)
	local ia = IA.nouveau(rng({ 0.99 }))
	IA.mettreAJour(ia, 0, 50) -- entre en combat (prépare une charge)
	IA.subirDegats(ia, 800)
	IA.mettreAJour(ia, 2, 50) -- frappe
	local o = IA.mettreAJour(ia, 2.1, 50)
	t.egal(o[1].type, "rage")
	t.egal(ia.phase, 2)
	t.egal(#IA.mettreAJour(ia, 3, 50), 0)
	o = IA.mettreAJour(ia, 2.1 + Regles.OGRE.rage, 50)
	t.egal(o[1].type, "preparer")
	t.egal(o[1].attaque, "rocher") -- 0,99 → dernière candidate
	t.egal(o[1].duree, Regles.OGRE.attaques.rocher.preparation * Regles.OGRE.accelerationPhase2)
end

M["IA : meurt une seule fois"] = function(t)
	local ia = IA.nouveau(rng({ 0.5 }))
	IA.mettreAJour(ia, 0, 10)
	IA.subirDegats(ia, 99999)
	t.egal(IA.mettreAJour(ia, 1, 10)[1].type, "mort")
	t.egal(#IA.mettreAJour(ia, 2, 10), 0)
	t.egal(IA.subirDegats(ia, 10), 0)
end

M["IA : si tout le monde meurt ou part, il rentre sans se soigner"] = function(t)
	local ia = IA.nouveau(rng({ 0.5 }))
	IA.mettreAJour(ia, 0, 10)
	IA.subirDegats(ia, 300)
	local o = IA.mettreAJour(ia, 1, nil)
	t.egal(o[1].type, "retour")
	t.egal(ia.vie, 1300)
	t.egal(ia.etat, "attente")
	-- Le joueur revient : le combat reprend là où il en était.
	IA.mettreAJour(ia, 2, 10)
	t.egal(ia.etat, "preparation")
	t.egal(ia.vie, 1300)
end

M["IA : se tourne vers la cible avant un balayage"] = function(t)
	local ia = IA.nouveau(rng({ 0.01 })) -- tirerait le balayage
	local o = IA.mettreAJour(ia, 0, 10, false)
	t.egal(o[1].type, "avancer")
	o = IA.mettreAJour(ia, 0.1, 10, true)
	t.egal(o[1].attaque, "balayage")
end

return M
