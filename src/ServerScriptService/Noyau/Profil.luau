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
