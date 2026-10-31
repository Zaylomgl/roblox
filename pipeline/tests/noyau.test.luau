--[[
	Tests du noyau commun (src/ServerScriptService/Noyau) hors de Roblox,
	avec un DataStore simulé capable de tomber en panne.
]]

local Achats = require("../../src/ServerScriptService/Noyau/Achats")
local Profil = require("../../src/ServerScriptService/Noyau/Profil")
local RecompenseQuotidienne = require("../../src/ServerScriptService/Noyau/RecompenseQuotidienne")
local Sauvegarde = require("../../src/ServerScriptService/Noyau/Sauvegarde")

local M = {}

local JOUR = 86400
local T0 = 20_000 * JOUR + 3600 -- un instant quelconque, 1 h après minuit UTC
local RECOMPENSES = { 10, 20, 30, 50, 75, 100, 200 }

-- DataStore simulé : copie les valeurs comme le vrai (pas de partage de références).
local function nouveauStore()
	local store = { donnees = {}, pannesRestantes = 0, appels = 0 }
	function store:UpdateAsync(cle, transformation)
		self.appels += 1
		if self.pannesRestantes > 0 then
			self.pannesRestantes -= 1
			error("panne simulée du DataStore")
		end
		local nouveau = transformation(Profil.copieProfonde(self.donnees[cle]))
		if nouveau ~= nil then
			self.donnees[cle] = Profil.copieProfonde(nouveau)
		end
		return nouveau
	end
	return store
end

local function horloge(depart: number)
	local h = { t = depart }
	return h, function()
		return h.t
	end
end

local function gestionnaire(store, jobId: string, h)
	return Sauvegarde.nouveau(store, {
		jobId = jobId,
		maintenant = function()
			return h.t
		end,
		attendre = function(s)
			h.t += s -- le temps avance pendant l'attente
		end,
		attenteVerrou = 5,
		essaisChargement = 4,
	})
end

---------------------------------------------------------------- Profil

M["profil : nouveau joueur reçoit les valeurs par défaut"] = function(t)
	local p, nouveau = Profil.reconcilier(nil, T0)
	t.vrai(nouveau)
	t.egal(p.monnaie, 0)
	t.egal(p.recompense.dernierJour, -1)
	t.egal(p.version, Profil.VERSION)
end

M["profil : ancien profil complété sans perdre ses données"] = function(t)
	local ancien = { version = 1, monnaie = 42, recompense = { serie = 3 } }
	local p, nouveau = Profil.reconcilier(ancien, T0)
	t.faux(nouveau)
	t.egal(p.monnaie, 42)
	t.egal(p.recompense.serie, 3)
	t.egal(p.recompense.dernierJour, -1) -- champ manquant complété
	t.egal(type(p.achatsTraites), "table")
	t.egal(type(p.stats.visites), "number")
end

M["profil : monnaie jamais négative, NaN refusé"] = function(t)
	local p = Profil.defaut(T0)
	t.vrai(Profil.ajouterMonnaie(p, 10))
	t.faux(Profil.ajouterMonnaie(p, -11))
	t.egal(p.monnaie, 10)
	t.faux(Profil.ajouterMonnaie(p, 0 / 0))
	t.faux(Profil.ajouterMonnaie(p, math.huge))
	t.egal(p.monnaie, 10)
	t.egal(p.totalGagne, 10)
end

M["profil : mémoire des achats bornée"] = function(t)
	local p = Profil.defaut(T0)
	for i = 1, Profil.MAX_ACHATS_MEMORISES + 10 do
		Profil.memoriserAchat(p, "achat" .. i)
	end
	t.egal(#p.achatsTraites, Profil.MAX_ACHATS_MEMORISES)
	t.faux(Profil.achatDejaTraite(p, "achat1"))
	t.vrai(Profil.achatDejaTraite(p, "achat" .. (Profil.MAX_ACHATS_MEMORISES + 10)))
end

---------------------------------------------------------------- Récompense quotidienne

M["récompense : première réclamation puis refus le même jour"] = function(t)
	local etat = Profil.defaut(T0).recompense
	t.egal(RecompenseQuotidienne.reclamer(etat, T0, RECOMPENSES), 10)
	t.egal(RecompenseQuotidienne.reclamer(etat, T0 + 3600, RECOMPENSES), nil)
	local e = RecompenseQuotidienne.etat(etat, T0 + 3600, RECOMPENSES)
	t.faux(e.disponible)
	t.egal(e.secondesAvantProchaine, JOUR - 2 * 3600) -- minuit UTC suivant
end

M["récompense : série sur jours consécutifs, puis cycle de 7"] = function(t)
	local etat = Profil.defaut(T0).recompense
	local gains = {}
	for j = 0, 8 do
		table.insert(gains, RecompenseQuotidienne.reclamer(etat, T0 + j * JOUR, RECOMPENSES))
	end
	t.egal(table.concat(gains, ","), "10,20,30,50,75,100,200,10,20")
	t.egal(etat.serie, 9)
end

M["récompense : un jour manqué casse la série"] = function(t)
	local etat = Profil.defaut(T0).recompense
	RecompenseQuotidienne.reclamer(etat, T0, RECOMPENSES)
	RecompenseQuotidienne.reclamer(etat, T0 + JOUR, RECOMPENSES)
	t.egal(RecompenseQuotidienne.reclamer(etat, T0 + 3 * JOUR, RECOMPENSES), 10)
	t.egal(etat.serie, 1)
end

M["récompense : le jour change à minuit UTC, pas 24 h après"] = function(t)
	local etat = Profil.defaut(T0).recompense
	local tard = 20_000 * JOUR + JOUR - 60 -- 23:59 UTC
	RecompenseQuotidienne.reclamer(etat, tard, RECOMPENSES)
	t.egal(RecompenseQuotidienne.reclamer(etat, tard + 120, RECOMPENSES), 20) -- 00:01 UTC
end

---------------------------------------------------------------- Sauvegarde

M["sauvegarde : charger, modifier, sauvegarder, recharger"] = function(t)
	local store = nouveauStore()
	local h = horloge(T0)
	local s = gestionnaire(store, "serveurA", h)
	local donnees, err = s:charger("joueur_1")
	t.egal(donnees, nil)
	t.egal(err, nil)
	local p = Profil.reconcilier(donnees, h.t)
	p.monnaie = 123
	t.vrai(s:sauvegarder("joueur_1", p, true))
	local relu = s:charger("joueur_1")
	t.egal(relu.monnaie, 123)
end

M["sauvegarde : verrou — un 2e serveur attend que le 1er libère"] = function(t)
	local store = nouveauStore()
	local h = horloge(T0)
	local a = gestionnaire(store, "serveurA", h)
	local b = gestionnaire(store, "serveurB", h)
	a:charger("joueur_1")
	local _, err = b:charger("joueur_1")
	t.egal(err, "verrouille") -- A n'a pas libéré
	a:sauvegarder("joueur_1", { monnaie = 7 }, true)
	local donnees, err2 = b:charger("joueur_1")
	t.egal(err2, nil)
	t.egal(donnees.monnaie, 7)
end

M["sauvegarde : un serveur qui a perdu le verrou ne peut plus écraser"] = function(t)
	local store = nouveauStore()
	local h = horloge(T0)
	local a = gestionnaire(store, "serveurA", h)
	local b = gestionnaire(store, "serveurB", h)
	a:charger("joueur_1")
	h.t += 3600 -- A ne donne plus signe de vie : verrou abandonné
	t.egal(select(2, b:charger("joueur_1")), nil)
	b:sauvegarder("joueur_1", { monnaie = 50 }, false)
	t.faux(a:sauvegarder("joueur_1", { monnaie = 1 }, true)) -- A est refusé
	t.egal(store.donnees.joueur_1.donnees.monnaie, 50)
end

M["sauvegarde : pannes passagères du DataStore surmontées"] = function(t)
	local store = nouveauStore()
	local h = horloge(T0)
	local s = gestionnaire(store, "serveurA", h)
	store.pannesRestantes = 2
	local _, err = s:charger("joueur_1")
	t.egal(err, nil)
	store.pannesRestantes = 2
	t.vrai(s:sauvegarder("joueur_1", { monnaie = 3 }, true))
end

M["sauvegarde : panne durable signalée, pas de données inventées"] = function(t)
	local store = nouveauStore()
	local h = horloge(T0)
	local s = gestionnaire(store, "serveurA", h)
	store.pannesRestantes = 100
	local donnees, err = s:charger("joueur_1")
	t.egal(donnees, nil)
	t.vrai(err ~= nil and string.find(err, "panne simulée", 1, true) ~= nil)
	t.faux(s:sauvegarder("joueur_1", { monnaie = 3 }, true))
end

---------------------------------------------------------------- Achats

local function montageAchats(sauvegardeReussit: { boolean })
	local profil = Profil.defaut(T0)
	local sauvegardes = 0
	local traiter = Achats.creerTraitement({
		profilDe = function(userId)
			return if userId == 1 then profil else nil
		end,
		gestionnaires = {
			[111] = function(p)
				return Profil.ajouterMonnaie(p, 100)
			end,
			[222] = function(p)
				p.monnaie += 999
				error("bug dans le gestionnaire")
			end,
		},
		sauvegarderMaintenant = function()
			sauvegardes += 1
			return sauvegardeReussit[1]
		end,
		copieProfonde = Profil.copieProfonde,
		memoriserAchat = Profil.memoriserAchat,
		achatDejaTraite = Profil.achatDejaTraite,
	})
	return traiter, profil, function()
		return sauvegardes
	end
end

M["achats : crédité une seule fois même si Roblox renvoie le reçu"] = function(t)
	local traiter, profil = montageAchats({ true })
	local recu = { PlayerId = 1, PurchaseId = "A1", ProductId = 111 }
	t.egal(traiter(recu), Achats.ACCORDE)
	t.egal(traiter(recu), Achats.ACCORDE)
	t.egal(profil.monnaie, 100)
end

M["achats : sauvegarde en échec → « pas encore », puis accordé sans double crédit"] = function(t)
	local etatSauvegarde = { false }
	local traiter, profil = montageAchats(etatSauvegarde)
	local recu = { PlayerId = 1, PurchaseId = "A2", ProductId = 111 }
	t.egal(traiter(recu), Achats.PAS_ENCORE)
	t.egal(profil.monnaie, 100)
	etatSauvegarde[1] = true
	t.egal(traiter(recu), Achats.ACCORDE)
	t.egal(profil.monnaie, 100)
end

M["achats : joueur absent → « pas encore »"] = function(t)
	local traiter = montageAchats({ true })
	t.egal(traiter({ PlayerId = 2, PurchaseId = "A3", ProductId = 111 }), Achats.PAS_ENCORE)
end

M["achats : produit inconnu → « pas encore », rien crédité"] = function(t)
	local traiter, profil = montageAchats({ true })
	t.egal(traiter({ PlayerId = 1, PurchaseId = "A4", ProductId = 999 }), Achats.PAS_ENCORE)
	t.egal(profil.monnaie, 0)
end

M["achats : gestionnaire qui plante → profil restauré, rien crédité"] = function(t)
	local traiter, profil = montageAchats({ true })
	t.egal(traiter({ PlayerId = 1, PurchaseId = "A5", ProductId = 222 }), Achats.PAS_ENCORE)
	t.egal(profil.monnaie, 0)
	t.faux(Profil.achatDejaTraite(profil, "A5"))
end

return M
