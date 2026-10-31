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
