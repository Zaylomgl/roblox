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
